![lab](https://github.com/bbrooks89/ansible-lab/actions/workflows/lab.yml/badge.svg)
# ansible-lab

An immutable, disposable Ansible practice lab that runs on one Linux machine with Docker.

- **1 control node** with a pinned `ansible-core` and common collections
- **3 managed nodes** that boot real **systemd** and **sshd**: two Ubuntu 24.04 and one Rocky Linux 9, so you practice against both the Debian and RHEL families
- **Key-only SSH** with a keypair generated fresh on every rebuild; nothing secret is committed
- **One command** (`./lab reset`) wipes it all and brings back a clean lab in about a minute
- **Two ways to provision:** Docker Compose (`./lab`) or **Terraform** (`./lab-tf`), same lab either way
- **CI** lints every playbook and the Terraform, provisions the lab both ways, and proves `site.yml` is idempotent (and Terraform shows no drift) on every push

> **Immutable means:** you never repair a node by hand. If you break something, rebuild it.
> Your playbooks live in `./workspace` on the host and survive every reset.

```mermaid
flowchart LR
  subgraph host["Host (brad-lab)"]
    ws["./workspace<br/>playbooks, inventory, roles"]
  end
  subgraph net["Docker network: lab"]
    ctl["control<br/>ansible-core 2.18"]
    u1["ubuntu1<br/>Ubuntu 24.04<br/>groups: ubuntu, web"]
    u2["ubuntu2<br/>Ubuntu 24.04<br/>groups: ubuntu, db"]
    r1["rocky1<br/>Rocky Linux 9<br/>groups: rocky, web"]
  end
  ws -- bind mount --> ctl
  ctl -- SSH key auth --> u1
  ctl -- SSH key auth --> u2
  ctl -- SSH key auth --> r1
  u1 -. ":8081" .-> host
  r1 -. ":8082" .-> host
```

## 1. Requirements

- Linux host with Docker Engine and the Compose v2 plugin (`docker compose version`)
- cgroup v2 (default on Linux Mint 21+, Ubuntu 22.04+)
- About 2 GB of free RAM and 3 GB of disk for the images
- Your user in the `docker` group (`sudo usermod -aG docker $USER`, then log out and back in)

## 2. Quick start

```bash
git clone git@github.com:bbrooks89/ansible-lab.git
cd ansible-lab
./lab up          # first build takes a few minutes
./lab ping        # every node should say SUCCESS
./lab run site.yml
./lab run site.yml   # run it again: changed=0 everywhere
```

Then open <http://localhost:8081> (ubuntu1) and <http://localhost:8082> (rocky1).

## 3. Commands

| Command | What it does |
|---|---|
| `./lab up` | Build if needed, start, wait until every node answers Ansible ping |
| `./lab shell` | Bash on the control node as `ansible`, in `~/lab` (your `./workspace`) |
| `./lab ping` | `ansible all -m ping` |
| `./lab run <playbook> [args]` | Run `playbooks/<playbook>`; extra args pass through (`--check --diff`, `-l rocky`, `-t tag`) |
| `./lab ssh <node>` | SSH from the control node into a managed node, the way Ansible does |
| `./lab console <node>` | Root shell via `docker exec`, for when SSH itself is broken |
| `./lab reset` | Destroy containers and volumes, rebuild, wait for ready |
| `./lab down` | Stop the lab (keeps images) |
| `./lab destroy` | Remove containers, volumes and lab images |
| `./lab status` / `./lab logs [svc]` | Container status and logs |

## 4. Layout

```text
ansible-lab/
├── lab                     # helper CLI (Compose)
├── lab-tf                  # helper CLI (Terraform)
├── compose.yaml            # control + 3 managed nodes
├── terraform/              # the same lab as Terraform (Docker provider)
│   ├── versions.tf         # Terraform + provider pins
│   ├── variables.tf        # name prefix, UID/GID, managed node map
│   ├── main.tf             # network, volumes, images, containers
│   └── outputs.tf          # container names, URLs
├── control/                # control node image (Ansible, pinned)
│   ├── Dockerfile
│   ├── entrypoint.sh       # generates the lab keypair on first start
│   ├── requirements.txt    # ansible-core version pin
│   └── requirements.yml    # collections
├── nodes/                  # managed node images (systemd + sshd)
│   ├── common/             # first-boot unit, sshd hardening
│   ├── ubuntu/Dockerfile
│   └── rocky/Dockerfile
├── workspace/              # mounted at ~/lab on the control node
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   ├── playbooks/          # 00-ping, 01-facts, 02-baseline, 03-webserver, site
│   └── roles/webserver/
├── EXERCISES.md            # numbered practice tasks
└── .github/workflows/lab.yml
```

## 5. How it works

1. **Control node starts first.** Its entrypoint generates an ed25519 keypair if the volumes are empty. The private key goes in the `lab-secret` volume, which only the control node mounts. The public key goes in `lab-pubkey`.
2. **Managed nodes wait** on the control node's healthcheck, so they never boot before a key exists.
3. **Each managed node boots systemd.** A `lab-firstboot` unit runs before sshd: it generates unique SSH host keys (the images ship with none) and installs the public key for the `ansible` user from the read-only `lab-pubkey` volume.
4. **`./lab reset`** runs `docker compose down -v`, which deletes both volumes. Next start means a new keypair, new host keys and fresh containers. `host_key_checking` is off in `ansible.cfg` for this reason only; never do that on real servers.

The `ansible` user on each node has passwordless sudo and no password, so SSH keys are the only way in.

## 6. Adding a node

1. Add a service to `compose.yaml` using the `<<: *managed-node` anchor (copy `ubuntu2`).
2. Add the host to `workspace/inventory/hosts.yml`.
3. `./lab up`

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Node exits right away, or `./lab console` shows systemd errors about cgroups | Check `stat -fc %T /sys/fs/cgroup` prints `cgroup2fs`. If it does and it still fails, uncomment `privileged: true` in the `x-managed-node` block of `compose.yaml`. |
| `UNREACHABLE` after a reset | Give it a few seconds; `./lab ping`. Then `./lab console <node>` and `systemctl status lab-firstboot ssh` (`sshd` on Rocky). |
| `Bind for 0.0.0.0:8081 failed: port is already allocated` | `UBUNTU1_HTTP_PORT=9081 ROCKY1_HTTP_PORT=9082 ./lab up` |
| Files in `workspace/` owned by the wrong user | `./lab` passes your UID into the image. If you built with plain `docker compose`, run `./lab reset`. |
| `permission denied ... docker.sock` | Add yourself to the `docker` group and log in again. |

## 8. Limits (it's containers, not VMs)

The nodes share the host kernel, so these won't behave like a real server: kernel modules, `sysctl` on most keys, `reboot` (it stops the container), mounts and block devices, SELinux, firewalld/ufw rules, and `timedatectl`. For those, use VMs (Vagrant or KVM). Packages, files, templates, users, services, handlers, roles, facts, loops, conditionals, vault, check mode and idempotence all behave as they do on real hosts.

## 9. Provisioning with Terraform

`./lab-tf` builds the same lab with Terraform and the
[kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider
instead of Compose. Terraform provisions the infrastructure; Ansible, running on the control
node, configures it. That split is the same one real platforms use with cloud VMs.

Requires Terraform 1.6+ on the host. It uses its own names (`tflab-*`) and ports (8091, 8092),
so it can run beside the Compose lab.

```bash
./lab-tf plan        # see what will be created
./lab-tf up          # terraform apply, then wait for Ansible ping
./lab-tf run site.yml
./lab-tf run site.yml   # again: changed=0
./lab-tf destroy
```

Then open <http://localhost:8091> (ubuntu1) and <http://localhost:8092> (rocky1).

| Command | What it does |
|---|---|
| `./lab-tf plan` | `terraform plan` |
| `./lab-tf up` | `terraform apply`, then wait until every node answers Ansible ping |
| `./lab-tf reset` | `terraform destroy` then `apply`: new containers, volumes and keys |
| `./lab-tf destroy` | Remove containers, volumes, network and images |
| `./lab-tf shell` / `ssh <node>` / `ping` / `run <playbook>` | Same as `./lab` |
| `./lab-tf status` / `output` | Terraform state, container status, outputs |

**Adding a node** is one map entry: add it to `managed_nodes` (in `terraform/variables.tf`, or a
`terraform.tfvars` file), add it to `workspace/inventory/hosts.yml`, then `./lab-tf up`. Terraform
creates only the new container.

What CI checks on every push: `terraform fmt` and `validate`, a full `apply`, a second `plan`
that must be empty (no drift), `site.yml` twice with `changed=0` the second time, both web pages
answering, and `destroy`.

State is kept in `terraform/terraform.tfstate` on your machine and is git-ignored. After your first
`./lab-tf up`, commit `terraform/.terraform.lock.hcl` so every machine uses the same provider build.

## License

MIT
