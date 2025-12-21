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
  tunTag = "tun_inbound";
  socksTag = "socks_inbound";

  directSiteRuleSets = [
    "geosite-cn"
    "geosite-apple"
  ];
  directIpRuleSets = [
    "geoip-cn"
    "geoip-apple"
    "geoip-cloudflare"
    "geoip-private"
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
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo-lite/geoip/apple.srs";
    }
    {
      name = "geosite-apple";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/apple.srs";
    }
    {
      name = "geoip-cloudflare";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cloudflare.srs";
    }
    {
      name = "geoip-private";
      url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/private.srs";
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
    mkDns server proxiedDnsTag "udp"
    // {
      detour = proxiedRouteTag;
    };

  hasSubscription = !isNull config.proxy.subscription;
in
{
  options.proxy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable sing-box proxy service.";
    };
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

  config = lib.mkIf config.proxy.enable {
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
          default_interface = config.router.wan.interface;
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
        outbounds = [
          {
            type = "direct";
            tag = directRouteTag;
          }
        ];
        inbounds = [
          {
            type = "tun";
            tag = tunTag;
            interface_name = config.proxy.tun.interface;
            address = config.proxy.tun.networks;
            auto_route = true;
            strict_route = true;
            auto_redirect = true;
            route_exclude_address_set = directIpRuleSets;
          }
          {
            type = "socks";
            tag = socksTag;
            listen_port = config.proxy.socks_port;
          }
        ];
      };
    };

    # systemd timer for proxy subscription updates
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/networking/sing-box.nix
    systemd = lib.mkIf hasSubscription (
      let
        subscriptionService = "sing-box-proxy-subscription";
        singboxWorkingDir = "/run/sing-box";
        subscriptionJson = "subscription.json";
        updateScript = pkgs.writeShellScript "update-sing-box-subscription" ''
          set -euo pipefail
          ${pkgs.curl}/bin/curl -s '${config.proxy.subscription}' \
          | ${pkgs.jq}/bin/jq '.["outbounds"] | map(select(has("server"))) | {outbounds: [.[], {type: "urltest", tag: "${proxiedRouteTag}", interrupt_exist_connections: false, outbounds: . | map(.["tag"])}]}' \
          | ${pkgs.coreutils}/bin/tee ${singboxWorkingDir}/${subscriptionJson}
          ${pkgs.coreutils}/bin/chown --reference=${singboxWorkingDir} ${singboxWorkingDir}/${subscriptionJson}
          ${pkgs.procps}/bin/pkill -HUP sing-box || true
        '';
      in
      {
        timers.${subscriptionService} = {
          description = "Update sing-box proxy subscriptions";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "${subscriptionService}.service";
          };
        };
        services = {
          ${subscriptionService} = {
            serviceConfig = {
              Type = "oneshot";
              User = "sing-box";
              Group = "sing-box";
            };
            script = "+${updateScript}";
            requires = [
              "sing-box.service"
              "network-online.target"
            ];
          };
          sing-box.serviceConfig.ExecStartPre = [ "+${updateScript}" ];
        };
      }
    );
  };
}
