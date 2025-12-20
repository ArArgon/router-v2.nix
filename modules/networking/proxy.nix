{
  config,
  lib,
  ...
}:
let
  proxiedDnsTag = "dns_proxied";
  directDnsTag = "dns_direct";
  proxiedRouteTag = "proxied";
  directRouteTag = "direct";

  directSiteRuleSets = [
    "geosite-cn"
    "geosite-apple"
  ];
  directIpRuleSets = [
    "geoip-cn"
    "geoip-apple"
    "geoip-cloudflare"
  ];

  ruleSets = [
    {
      name = "geoip-cn";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs";
    }
    {
      name = "geosite-cn";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs";
    }
    {
      name = "geoip-apple";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/apple.srs";
    }
    {
      name = "geosite-apple";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/apple.srs";
    }
    {
      name = "geoip-cloudflare";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cloudflare.srs";
    }
  ];

  mkRuleSet = rs: {
    tag = rs.name;
    type = "remote";
    format = "binary";
    url = rs.url;
  };
  mkDns = server: tag: protocol: {
    tag = tag;
    type = protocol;
    server = server;
  };
  mkDirectDns = server: if builtins.isString server then mkDns server directDnsTag "udp" else server;
  mkProxiedDns =
    server:
    let
      server = mkDirectDns server;
    in
    {
      inherit server;
      detour = proxiedRouteTag;
    };
in
{
  options.proxy = {
    log_level = lib.mkOption {
      type = lib.types.enum [
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "warn";
      description = "Log level for sing-box service.";
    };
    socks_port = lib.mkOption {
      type = lib.types.int;
      default = 7890;
      description = "Port for the SOCKS5 proxy server.";
    };
    tun = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "singbox0";
        description = "Name of the TUN interface created by sing-box.";
      };
      networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of IP networks assigned to the TUN interface.";
      };
      dns = {
        proxied = lib.mkOption {
          type = lib.types.listOf (
            lib.types.oneOf [
              lib.types.str # Will allow passing attributes as well
            ]
          );
          description = "List of proxied DNS servers for sing-box";
        };
        direct = lib.mkOption {
          type = lib.types.listOf (
            lib.types.oneOf [
              lib.types.str # Will allow passing attributes as well
            ]
          );
          description = "List of direct DNS servers for sing-box";
        };
      };
    };
  };

  config = {
    services.sing-box = {
      enable = true;
      settings = {
        log = {
          level = config.proxy.log_level;
          timestamp = true;
        };
        experimental = {
          cache_file = {
            enabled = true;
          };
        };
        dns = {
          servers =
            (builtins.map mkDirectDns config.proxy.dns.direct)
            + (builtins.map mkProxiedDns config.proxy.dns.proxied);
          rules = [
            {
              rule_set = directSiteRuleSets;
              invert = true;
              action = "route";
              server = proxiedDnsTag;
            }
          ];
        };
        route = {
          default_domain_resolver = {
            server = directDnsTag;
          };
          final = directRouteTag;
          rules = [
            {
              port = 53;
              action = "hijack-dns";
            }
            {
              rule_set = directSiteRuleSets + directIpRuleSets;
              invert = true;
              action = "route";
              outbound = proxiedRouteTag;
            }
          ];
          rule_set = builtins.map mkRuleSet ruleSets;
        };
      };
    };

    # systemd timer for proxy subscription updates
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/networking/sing-box.nix
    systemd.timers.sing-box-proxy-subscription-timer = {
      description = "Update sing-box proxy subscriptions";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "sing-box-proxy-subscription-update.service";
      };
    };

    systemd.services.sing-box-proxy-subscription-update = {
      description = "Update sing-box proxy subscriptions";
      serviceConfig = {
        Type = "oneshot";
        User = "sing-box";
        Group = "sing-box";
      };
      script = ''
        # TODO
      '';
      wantedBy = [ "multi-user.target" ];
    };
  };
}
