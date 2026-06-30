{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "onlyboxes-worker-docker";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "Coooolfan";
    repo = "onlyboxes";
    tag = finalAttrs.version;
    hash = "sha256-8CHlPYIZZKHH/0bhtSt84vxIpyVout4LChgjk8jDOZA=";
  };

  # The repo is a Go workspace; the docker worker is its own module that
  # `replace`s the sibling `api` module via a relative path, so build from the
  # whole tree with the worker module as the root.
  modRoot = "worker/worker-docker";
  subPackages = [ "cmd/worker-docker" ];

  vendorHash = "sha256-HMLuJahNRZ8x8YE3NiAQPjgn6cKehFvmCN3PpzwL1kk=";

  # Pure-Go gRPC worker that only shells out to the `docker` CLI; build a static
  # binary so it runs from a host systemd service without extra runtime deps.
  env.CGO_ENABLED = "0";

  meta = {
    description = "OnlyBoxes docker-runtime worker node";
    homepage = "https://onlybox.es";
    license = lib.licenses.agpl3Only;
    mainProgram = "worker-docker";
    platforms = lib.platforms.linux;
  };
})
