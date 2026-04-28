let
  networkName = "development";
in
{
  flake.modules.nixos.quadlet-development =
    { config, ... }:
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      virtualisation.quadlet = {
        networks.${networkName}.networkConfig = {
          subnets = [ "172.23.0.0/16" ];
          disableDns = true;
        };

        containers.jenkins = {
          serviceConfig = {
            Restart = "always";
            RestartSec = "10";
          };
          containerConfig = {
            image = "jenkins/jenkins:lts-jdk21";
            networks = [ networks.${networkName}.ref ];
            ip = "172.23.0.2";
            volumes = [
              "${config.utils.dataDir "jenkins"}:/var/jenkins_home"
            ];
          };
        };
      };
    };

  flake.modules.nixos.gateway = {
    modules.gateway.localServices = [
      {
        name = "Jenkins";
        domainName = "jenkins";
        iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jenkins.png";
        addr = "172.23.0.2:8080";
        category = "Development";
      }
    ];
  };
}
