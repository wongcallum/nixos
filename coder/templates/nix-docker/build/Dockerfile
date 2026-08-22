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

COPY flake.nix flake.lock /etc/coder/nix-environment/

USER ${USER}
WORKDIR /home/${USER}

RUN curl --proto '=https' --tlsv1.2 -L \
      "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon

RUN sudo mkdir -p /etc/nix \
  && printf '%s\n' \
       'extra-substituters = https://cache.numtide.com' \
       'extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=' \
     | sudo tee -a /etc/nix/nix.conf >/dev/null

RUN printf '%s\n' 'eval "$(direnv hook bash)"' >> "/home/${USER}/.bashrc"

ENV PATH=/home/coder/.nix-profile/bin:/home/coder/.nix-profile/sbin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV NIX_PROFILES="/nix/var/nix/profiles/default /home/coder/.nix-profile"
ENV TERMINFO_DIRS=/home/coder/.nix-profile/share/terminfo:/usr/share/terminfo

RUN nix --version
