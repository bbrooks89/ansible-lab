terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Talks to the local Docker Engine (unix:///var/run/docker.sock by default,
# or whatever DOCKER_HOST points at).
provider "docker" {}
