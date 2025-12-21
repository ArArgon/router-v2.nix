{
  config,
  lib,
  pkgs,
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
  mkDirectDns = server: mkDns server directDnsTag "udp";
  mkProxiedDns =
    server:
    mkDirectDns server
    // {
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
    dns = {
      proxied = lib.mkOption {
        type = lib.types.listOf (
          lib.types.str # Will allow passing attributes as well
        );
        description = "List of proxied DNS servers for sing-box";
        default = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      direct = lib.mkOption {
        type = lib.types.listOf (
          lib.types.str # Will allow passing attributes as well
        );
        description = "List of direct DNS servers for sing-box";
        default = [
          "114.114.114.114"
          "223.5.5.5"
        ];
      };
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
        default = [
          "192.168.200.1/30"
          "fd00:abcd::/64"
        ];
      };
    };
    subscription = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Subscription URL for sing-box proxy configuration.";
      default = null;
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
            ++ (builtins.map mkProxiedDns config.proxy.dns.proxied);
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
              rule_set = directSiteRuleSets ++ directIpRuleSets;
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
    systemd.timers.sing-box-proxy-subscription-timer = lib.mkIf (!isNull config.proxy.subscription) {
      description = "Update sing-box proxy subscriptions";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "sing-box-proxy-subscription-update.service";
      };
    };

    systemd.services.sing-box-proxy-subscription-update = lib.mkIf (!isNull config.proxy.subscription) {
      description = "Update sing-box proxy subscriptions";
      serviceConfig = {
        Type = "oneshot";
        User = "sing-box";
        Group = "sing-box";
      };
      script =
        let
          workingDir = "/run/sing-box";
          jsonPath = "${workingDir}/subscription.json";
        in
        ''
          curl ${config.proxy.subscription} \
          | jq '.["outbounds"] | map(."tag" = "${proxiedRouteTag}") | {outbounds: .}' \
          | tee ${jsonPath}
          chown --reference=/${workingDir} ${jsonPath}
        '';
      wantedBy = [ "multi-user.target" ];
    };
  };
}
