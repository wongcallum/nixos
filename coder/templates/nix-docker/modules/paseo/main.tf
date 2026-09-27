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

variable "install_version" {
  type        = string
  description = "Version or dist-tag of @getpaseo/cli to install."
  default     = "0.9.2"
}

variable "install_prefix" {
  type        = string
  description = "Directory to install Paseo and its Node.js runtime into."
  default     = "$HOME/.coder-modules/paseo"
}

variable "node_installable" {
  type        = string
  description = "Nix installable providing Node.js, used when node is not already on PATH."
  default     = "nixpkgs#nodejs"
}

variable "port" {
  type        = number
  description = "Loopback port for the Paseo daemon and web UI."
  default     = 6767
}

variable "hostnames" {
  type        = list(string)
  description = "Extra Host headers the daemon accepts, e.g. \".coder.example.com\" for Coder's wildcard app domain. Loopback and IPs are always allowed."
  default     = []
}

variable "wait_for_scripts" {
  type        = list(string)
  description = "`coder exp sync` names that must complete before the daemon starts. Paseo caches provider availability, so agent CLIs installed after it would stay unavailable."
  default     = []
}

variable "slug" {
  type        = string
  description = "Slug of the Coder app."
  default     = "paseo"
}

variable "display_name" {
  type        = string
  description = "Display name of the Coder app."
  default     = "Paseo"
}

variable "order" {
  type        = number
  description = "Position of the app in the dashboard."
  default     = null
}

locals {
  # Paseo serves its UI and WebSocket from the site root, so it cannot sit
  # behind Coder's path-based proxy.
  subdomain = true
  sync_name = "${var.slug}-start_script"
}

resource "coder_script" "paseo" {
  agent_id     = var.agent_id
  display_name = var.display_name
  icon         = "https://paseo.sh/favicon.svg"
  run_on_start = true

  script = <<-EOT
    #!/bin/sh
    set -eu

    trap 'coder exp sync complete ${local.sync_name}' EXIT
    %{if length(var.wait_for_scripts) > 0~}
    coder exp sync want ${local.sync_name} ${join(" ", var.wait_for_scripts)}
    %{endif~}
    coder exp sync start ${local.sync_name}

    prefix="${var.install_prefix}"
    version='${var.install_version}'
    mkdir -p "$prefix" "$HOME/.local/bin"

    if ! command -v node >/dev/null 2>&1; then
      nix build --out-link "$prefix/node" '${var.node_installable}'
      export PATH="$prefix/node/bin:$PATH"
    fi
    node_bin="$(dirname "$(command -v node)")"

    installed="$(node -p "require('$prefix/node_modules/@getpaseo/cli/package.json').version" 2>/dev/null || true)"
    if [ "$installed" != "$version" ]; then
      npm install --prefix "$prefix" --no-fund --no-audit --loglevel=error "@getpaseo/cli@$version"
    fi

    # The daemon hints the web UI's initial connection from the Host header,
    # which lacks a port behind Coder's proxy, so the hint fails to parse and
    # the UI falls back to the browser's own localhost. Derive the hint from
    # the page URL instead; this runs after the daemon's injected <head> hint.
    index="$prefix/node_modules/@getpaseo/server/dist/server/web-ui/index.html"
    if ! grep -q coder-connection-hint "$index"; then
      sed -i 's#<body>#<body><script id="coder-connection-hint">(function(l){var s=l.protocol==="https:";window.__PASEO_INITIAL_DAEMON_CONNECTION__={listen:l.hostname+":"+(l.port||(s?443:80)),useTls:s}})(location)</script>#' "$index"
    fi

    # Wrapper so `paseo` works from terminals without Node.js on PATH.
    cat >"$HOME/.local/bin/paseo" <<WRAPPER
    #!/bin/sh
    PATH="$node_bin:\$PATH" exec "$prefix/node_modules/.bin/paseo" "\$@"
    WRAPPER
    chmod +x "$HOME/.local/bin/paseo"

    # Agents are launched by the daemon, so it needs the claude and codex
    # installs from ~/.local/bin on PATH.
    export PATH="$HOME/.local/bin:$node_bin:$PATH"
    export PASEO_LISTEN='127.0.0.1:${var.port}'
    export PASEO_WEB_UI_ENABLED=true
    export PASEO_HOSTNAMES='${join(",", var.hostnames)}'
    export PASEO_RELAY_ENABLED=false

    nohup "$prefix/node_modules/.bin/paseo" daemon run >>"$prefix/daemon.log" 2>&1 &
  EOT
}

resource "coder_app" "paseo" {
  agent_id     = var.agent_id
  slug         = var.slug
  display_name = var.display_name
  url          = "http://localhost:${var.port}"
  icon         = "https://paseo.sh/favicon.svg"
  subdomain    = local.subdomain
  share        = "owner"
  order        = var.order

  healthcheck {
    url       = "http://localhost:${var.port}/api/health"
    interval  = 5
    threshold = 6
  }
}
