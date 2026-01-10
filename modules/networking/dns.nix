{ config, lib, ... }:
let
  isProxyEnabled = config.proxy.enable;
  utils = import ./utils.nix { inherit lib; };
  render = server: ''
    forward . ${
      if server.protocol == "tls" then "tls://" else ""
    }${server.address}:${toString server.port} {
      ${lib.optionalString (server.protocol == "tls") "tls_servername ${server.tlsDomain}"}
      ${lib.optionalString (server.protocol == "tcp") "force_tcp"}
      ${lib.optionalString (server.protocol == "udp") "prefer_udp"}
    }
  '';
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
    hijackDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hijack all DNS requests to go through the local DNS resolver.";
    };
  };

  config = {
    networking.nameservers = [ "127.0.0.1" ];
    services.coredns = {
      enable = true;
      config = ''
        .:${toString config.dns.port} {
          cache
          ${
            if isProxyEnabled then
              ''
                forward . ${config.proxy.dnsListens.address}:${toString config.proxy.dnsListens.port} {
                  health_check 5s
                }
              ''
            else
              ""
          }

          ${builtins.concatStringsSep "\n" (builtins.map render config.dns.directServers)}
          ${builtins.concatStringsSep "\n" (builtins.map render config.dns.proxiedServers)}

          log
          errors {
            consolidate 5m ".* i/o timeout$" warning show_first
            consolidate 30s "^Failed to .+" error show_first
          }
        }
      '';
    };
  };
}
