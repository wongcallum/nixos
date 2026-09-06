terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.4.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

locals {
  coder_internal_url = "http://10.0.0.3:3000"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

provider "coder" {
  url = local.coder_internal_url
}

provider "docker" {}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    #!/bin/sh
    set -eu
    curl -fsS ${local.coder_internal_url}/healthz >/dev/null
    nix --version

    nix profile add \
      --profile "$HOME/.nix-profile" \
      path:/etc/coder/nix-environment#default
    nix profile upgrade \
      --profile "$HOME/.nix-profile" \
      nix-environment

    mkdir -p "$HOME/.claude"
    if [ ! -f "$HOME/.claude/settings.json" ]; then
      cat >"$HOME/.claude/settings.json" <<'JSON'
    {
      "theme": "dark",
      "model": "opus",
      "effortLevel": "xhigh",
      "tui": "fullscreen",
      "disableBundledSkills": true,
      "disableWorkflows": true,
      "disableRemoteControl": true,
      "disableClaudeAiConnectors": true,
      "disableArtifact": true,
      "awaySummaryEnabled": false,
      "autoCompactEnabled": false,
      "promptSuggestionEnabled": false,
      "autoContinueAtUsageLimit": false,
      "switchModelsOnFlag": false,
      "env": {
        "CLAUDE_CODE_SHELL": "/bin/bash"
      },
      "permissions": {
        "defaultMode": "bypassPermissions"
      },
      "attribution": {
        "commit": "",
        "pr": ""
      }
    }
    JSON
    fi

    if [ ! -f "$HOME/.claude.json" ]; then
      echo '{"hasCompletedOnboarding": true}' >"$HOME/.claude.json"
    elif ! jq -e '.hasCompletedOnboarding' "$HOME/.claude.json" >/dev/null 2>&1; then
      claude_json_tmp="$(mktemp)"
      jq '.hasCompletedOnboarding = true' "$HOME/.claude.json" >"$claude_json_tmp"
      mv "$claude_json_tmp" "$HOME/.claude.json"
    fi

    sudo chsh --shell "$HOME/.nix-profile/bin/fish" coder
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

module "claude_code" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/claude-code/coder"
  version  = "5.4.0"
  agent_id = coder_agent.main.id
}

module "codex" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder-labs/codex/coder"
  version  = "5.3.2"
  agent_id = coder_agent.main.id
}

resource "coder_app" "zed" {
  agent_id     = coder_agent.main.id
  slug         = "zed"
  display_name = "Zed"
  external     = true
  url          = "zed://ssh/coder.${data.coder_workspace.me.name}"
  icon         = "/icon/zed.svg"
}

resource "docker_image" "workspace" {
  name = "coder-nix-${data.coder_workspace.me.id}"

  build {
    context = "${path.module}/build"
  }

  triggers = {
    dockerfile = filesha256("${path.module}/build/Dockerfile")
    flake      = filesha256("${path.module}/build/flake.nix")
    flake_lock = filesha256("${path.module}/build/flake.lock")
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"

  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "nix" {
  name = "coder-${data.coder_workspace.me.id}-nix"

  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image    = docker_image.workspace.name
  name     = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  restart  = "unless-stopped"

  entrypoint = ["sh", "-c", coder_agent.main.init_script]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  volumes {
    container_path = "/nix"
    volume_name    = docker_volume.nix.name
    read_only      = false
  }
}
