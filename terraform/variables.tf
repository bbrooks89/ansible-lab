variable "name_prefix" {
  description = "Prefix for every container, volume, network and image this stack creates. Keeps it from colliding with the Compose lab."
  type        = string
  default     = "tflab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "lab_uid" {
  description = "UID for the 'ansible' user on the control node, so files it writes in ./workspace stay owned by you. lab-tf passes your UID automatically."
  type        = number
  default     = 1000
}

variable "lab_gid" {
  description = "GID for the 'ansible' user on the control node."
  type        = number
  default     = 1000
}

variable "managed_nodes" {
  description = "Managed nodes to create. image is 'ubuntu' or 'rocky'; http_port publishes the node's port 80 on the host (null = not published)."
  type = map(object({
    image     = string
    http_port = optional(number)
  }))
  default = {
    ubuntu1 = { image = "ubuntu", http_port = 8091 }
    ubuntu2 = { image = "ubuntu" }
    rocky1  = { image = "rocky", http_port = 8092 }
  }

  validation {
    condition     = alltrue([for n in values(var.managed_nodes) : contains(["ubuntu", "rocky"], n.image)])
    error_message = "Each managed node's image must be \"ubuntu\" or \"rocky\"."
  }
}
