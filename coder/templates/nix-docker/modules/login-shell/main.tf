terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.4.1"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "shell" {
  type        = string
  description = "Path of the login shell."
}

variable "user" {
  type        = string
  description = "User whose login shell to set."
  default     = "coder"
}

variable "wait_for" {
  type        = list(string)
  description = "coder exp sync units to wait for before changing the shell."
  default     = []
}

locals {
  sync_unit = "login-shell-${substr(sha1(var.shell), 0, 8)}"
}

resource "coder_script" "login_shell" {
  agent_id     = var.agent_id
  display_name = "Login Shell"
  icon         = "/icon/terminal.svg"
  run_on_start = true

  script = <<-EOT
    #!/bin/sh
    set -eu

    trap 'coder exp sync complete ${local.sync_unit}' EXIT
    coder exp sync start ${local.sync_unit}
    %{for unit in var.wait_for~}
    coder exp sync want ${local.sync_unit} ${unit}
    %{endfor~}

    shell="${var.shell}"
    user='${var.user}'

    if [ ! -x "$shell" ]; then
      echo "login shell $shell is missing or not executable" >&2
      exit 1
    fi

    current="$(getent passwd "$user" | cut -d: -f7)"
    if [ "$current" != "$shell" ]; then
      sudo chsh --shell "$shell" "$user"
    fi
  EOT
}

output "sync_unit" {
  description = "coder exp sync unit name; `coder exp sync want <self> <this>` blocks a script until the shell is set."
  value       = local.sync_unit
}
