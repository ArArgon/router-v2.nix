{ config, lib, ... }:
let
  utils = import ./utils.nix { inherit lib; };
in
{
  options.dns = {
    proxiedServers = lib.mkOption {
      type = lib.types.listOf utils.dnsServerType;
      description = "List of proxied DNS servers for restricted domains";
      default = [
        (utils.mkTlsDns {
          address = "1.1.1.1";
          domain = "cloudflare-dns.com";
        })
        (utils.mkTlsDns {
          address = "8.8.8.8";
          domain = "dns.google";
        })
      ];
    };
    directServers = lib.mkOption {
      type = lib.types.listOf utils.dnsServerType;
      description = "List of direct DNS servers";
      default = [
        (utils.mkTlsDns {
          address = "223.5.5.5";
          domain = "dns.alidns.com";
        })
        (utils.mkUdpDns { address = "114.114.114.114"; })
      ];
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 53;
      description = "Port for the DNS resolver to listen on.";
    };
  };

  config = {
    services.resolved.enable = false;
    networking = {
      nameservers = [ "127.0.0.1" ];
      resolvconf.useLocalResolver = true;
    };

    services.coredns = {
      enable = true;
      config =
        let
          allAddrs = builtins.map (s: s.address) (config.dns.directServers ++ config.dns.proxiedServers);
          forwardList = builtins.concatStringsSep " " allAddrs;
        in
        ''
          .:${toString config.dns.port} {
            whoami
            cache
            forward . ${forwardList}
            log
            errors
          }
        '';
    };
  };
}
