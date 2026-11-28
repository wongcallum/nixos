{ inputs, ... }:
{
  flake.modules.nixos.adbpool-coordinator =
    { config, ... }:
    let
      inherit (config.security.nix-secrets) secrets templates;
      user = "adbpool-coordinator";
      secret = {
        owner = user;
        restartUnits = [ "adbpool-coordinator.service" ];
      };
    in
    {
      imports = [ inputs.adbpool.nixosModules.default ];

      security.nix-secrets = {
        secrets = {
          "adbpool/ts-authkey" = secret;
          "adbpool/ts-oauth-secret" = secret;
          "adbpool/oci-api-key" = secret;
          "adbpool/oci-user" = secret;
          "adbpool/oci-tenancy" = secret;
        };
        templates."adbpool-oci-config" = {
          owner = user;
          content = ''
            [adbpool]
            user=${secrets."adbpool/oci-user"}
            tenancy=${secrets."adbpool/oci-tenancy"}
            fingerprint=ce:b8:e1:da:0a:12:f7:b8:36:1d:a9:a3:cc:ee:65:58
            region=ap-sydney-1
            key_file=${secrets."adbpool/oci-api-key".path}
          '';
        };
      };

      services.adbpool.coordinator = {
        enable = true;
        settings = {
          # Used for the first login only; the node then keeps its own in the state directory.
          network.tsnet.auth_key_file = secrets."adbpool/ts-authkey".path;
          cloud = {
            enabled = true;
            max_instances = 1;
            coordinator_address = "adbpool-coordinator:7420";
            # rate_per_hour is USD for the whole VM and only feeds the cost `adbpool status` shows.
            shapes = [
              {
                name = "VM.Standard.A2.Flex";
                abi = "arm64-v8a";
                cpus = 4;
                memory_gb = 24;
                only_64bit = true;
                max_concurrent = 8;
                rate_per_hour = 0.10;
              }
              {
                name = "VM.Standard.E5.Flex";
                abi = "x86_64";
                cpus = 4;
                memory_gb = 24;
                max_concurrent = 8;
                rate_per_hour = 0.17;
              }
            ];
            launcher.settings = {
              region = "ap-sydney-1";
              compartment = "ocid1.compartment.oc1..aaaaaaaa6fneq4xoxspjjbz3d4mbxpbdiwgwgnysjq42hm5wfztvdy65xbfq";
              subnet = "ocid1.subnet.oc1.ap-sydney-1.aaaaaaaaj4ems3jzrusee6z3gvpwzuzuw3kgsamu4ona3d35hzfhdz4ipgja";
              availability_domain = "wIjJ:AP-SYDNEY-1-AD-1";
              config_file = templates."adbpool-oci-config".path;
              profile = "adbpool";
            };
            joiner.settings = {
              oauth_client_id = "k7goKkB4So11CNTRL";
              oauth_client_secret_file = secrets."adbpool/ts-oauth-secret".path;
            };
          };
        };
      };

      environment.persistence.${config.modules.persistence.persistDir}.directories = [
        {
          directory = "/var/lib/adbpool-coordinator";
          inherit user;
          group = user;
          mode = "0700";
        }
      ];
    };

  flake.modules.nixos.adbpool-client =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.adbpool.packages.${pkgs.stdenv.hostPlatform.system}.adbpool
      ];
    };
}
