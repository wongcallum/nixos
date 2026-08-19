FROM ubuntu:24.04

ARG USER=coder
ARG NIX_VERSION=2.34.8

ENV USER=${USER}
ENV HOME=/home/${USER}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    sudo \
    xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --user-group --shell /bin/bash "${USER}" \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
  && chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

RUN curl --proto '=https' --tlsv1.2 -L \
      "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon

ENV PATH=/home/coder/.nix-profile/bin:/home/coder/.nix-profile/sbin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

RUN nix --version
