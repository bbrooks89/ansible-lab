# Provisions the same lab as compose.yaml, with Terraform instead of Compose:
#   network + 2 volumes + 1 control node + N managed nodes (systemd + sshd).
# Terraform owns the infrastructure; Ansible (on the control node) owns the
# configuration. Nothing is fixed by hand: `./lab-tf reset` rebuilds it all.

locals {
  repo_root = abspath("${path.module}/..")

  # Dockerfile for each managed-node image, relative to ./nodes
  node_dockerfiles = {
    ubuntu = "ubuntu/Dockerfile"
    rocky  = "rocky/Dockerfile"
  }

  # Content hashes of each build context, so an edited Dockerfile or script
  # triggers a rebuild on the next apply.
  control_context_sha = sha1(join("", [
    for f in sort(fileset("${local.repo_root}/control", "**")) : filesha1("${local.repo_root}/control/${f}")
  ]))
  nodes_context_sha = sha1(join("", [
    for f in sort(fileset("${local.repo_root}/nodes", "**")) : filesha1("${local.repo_root}/nodes/${f}")
  ]))

  node_images = toset([for n in values(var.managed_nodes) : n.image])
}

# ---------------------------------------------------------------- network + storage

resource "docker_network" "lab" {
  name = "${var.name_prefix}-net"
}

# Private key: only the control node mounts this.
resource "docker_volume" "lab_secret" {
  name = "${var.name_prefix}-secret"
}

# Public key: control writes it, managed nodes read it.
resource "docker_volume" "lab_pubkey" {
  name = "${var.name_prefix}-pubkey"
}

# ---------------------------------------------------------------- images

resource "docker_image" "control" {
  name = "${var.name_prefix}/control:latest"

  build {
    context = "${local.repo_root}/control"
    build_args = {
      LAB_UID = tostring(var.lab_uid)
      LAB_GID = tostring(var.lab_gid)
    }
  }

  triggers = {
    context = local.control_context_sha
    uid     = tostring(var.lab_uid)
    gid     = tostring(var.lab_gid)
  }
}

resource "docker_image" "node" {
  for_each = local.node_images

  name = "${var.name_prefix}/${each.key}:latest"

  build {
    context    = "${local.repo_root}/nodes"
    dockerfile = local.node_dockerfiles[each.key]
  }

  triggers = {
    context = local.nodes_context_sha
  }
}

# ---------------------------------------------------------------- control node

resource "docker_container" "control" {
  name        = "${var.name_prefix}-control"
  image       = docker_image.control.image_id
  hostname    = "control"
  working_dir = "/home/ansible/lab"
  must_run    = true

  # Don't report success until the keypair exists (see healthcheck), so the
  # managed nodes below never boot without a public key to install.
  wait         = true
  wait_timeout = 90

  networks_advanced {
    name    = docker_network.lab.name
    aliases = ["control"]
  }

  # Playbooks are edited on the host and run here
  volumes {
    host_path      = "${local.repo_root}/workspace"
    container_path = "/home/ansible/lab"
  }

  volumes {
    volume_name    = docker_volume.lab_secret.name
    container_path = "/lab-secret"
  }

  volumes {
    volume_name    = docker_volume.lab_pubkey.name
    container_path = "/lab-pubkey"
  }

  healthcheck {
    test     = ["CMD", "test", "-s", "/lab-pubkey/id_ed25519.pub"]
    interval = "2s"
    timeout  = "2s"
    retries  = 30
  }
}

# ---------------------------------------------------------------- managed nodes

resource "docker_container" "node" {
  for_each = var.managed_nodes

  name     = "${var.name_prefix}-${each.key}"
  image    = docker_image.node[each.value.image].image_id
  hostname = each.key
  must_run = true

  # systemd needs its own view of the cgroup tree and a writable /run
  cgroupns_mode = "host"
  tmpfs = {
    "/run"      = ""
    "/run/lock" = ""
    "/tmp"      = ""
  }
  destroy_grace_seconds = 15

  networks_advanced {
    name    = docker_network.lab.name
    aliases = [each.key] # the inventory reaches nodes by these names
  }

  volumes {
    host_path      = "/sys/fs/cgroup"
    container_path = "/sys/fs/cgroup"
    read_only      = false
  }

  volumes {
    volume_name    = docker_volume.lab_pubkey.name
    container_path = "/lab-pubkey"
    read_only      = true
  }

  dynamic "ports" {
    for_each = each.value.http_port == null ? [] : [each.value.http_port]
    content {
      internal = 80
      external = ports.value
    }
  }

  depends_on = [docker_container.control]
}
