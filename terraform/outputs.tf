output "control_container" {
  description = "Name of the control node container (lab-tf runs Ansible through it)."
  value       = docker_container.control.name
}

output "managed_nodes" {
  description = "Each managed node's container name and, where published, its web URL on the host."
  value = {
    for k, c in docker_container.node : k => {
      container = c.name
      url       = var.managed_nodes[k].http_port == null ? null : "http://localhost:${var.managed_nodes[k].http_port}"
    }
  }
}
