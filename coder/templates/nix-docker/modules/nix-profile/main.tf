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

variable "flake_uri" {
  type        = string
  description = "Flake installable to keep in the profile, e.g. path:/etc/coder/nix-environment#default. Must be an unlocked reference so it can be upgraded on each start."
}

variable "profile" {
  type        = string
  description = "Nix profile to manage."
  default     = "$HOME/.nix-profile"
}

locals {
  sync_unit = "nix-profile-${substr(sha1(var.flake_uri), 0, 8)}"
}

resource "coder_script" "nix_profile" {
  agent_id     = var.agent_id
  display_name = "Nix Profile"
  icon         = "/icon/nix.svg"
  run_on_start = true

  script = <<-EOT
    #!/bin/sh
    set -eu

    trap 'coder exp sync complete ${local.sync_unit}' EXIT
    coder exp sync start ${local.sync_unit}

    profile="${var.profile}"
    flake_uri='${var.flake_uri}'
    flake_ref="$${flake_uri%%#*}"

    # Element names are derived by Nix; look the flake up by its original URL.
    element="$(nix profile list --profile "$profile" --json \
      | jq -r --arg url "$flake_ref" \
        '.elements | to_entries[] | select(.value.originalUrl == $url) | .key')"

    if [ -n "$element" ]; then
      nix profile upgrade --profile "$profile" "$element"
    else
      nix profile add --profile "$profile" "$flake_uri"
    fi
  EOT
}

output "sync_unit" {
  description = "coder exp sync unit name; `coder exp sync want <self> <this>` blocks a script until the profile is ready."
  value       = local.sync_unit
}
