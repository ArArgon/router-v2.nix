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
  subscriptionRouteTag = "subscription";
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
      url = "https://testingcf.jsdelivr.net/gh/coco-yan/proxy_ruleset@main/rule/ip_private.srs";
    }
  ];

  mkRuleSet = rs: {
    tag = rs.name;
    type = "remote";
    format = "binary";
    url = rs.url;
  };
  mkDns =
    {
      address,
      protocol,
      port,
      ...
    }:
    tag: {
      tag = tag;
      type = protocol;
      server = address;
      server_port = port;
    };
  mkDirectDns = server: mkDns server directDnsTag;
  mkProxiedDns =
    server:
    (mkDns server proxiedDnsTag)
    // {
      detour = proxiedRouteTag;
    };

  hasSubscription = !isNull config.proxy.subscription;
in
{
  options.proxy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sing-box proxy service.";
    };
    logLevel = lib.mkOption {
      type = lib.types.enum [
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "warn";
      description = "Log level for sing-box service.";
    };
    socksPort = lib.mkOption {
      type = lib.types.int;
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
          "172.19.0.1/30"
          "fd00:abcd::/64"
        ];
      };
    };
    subscription = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Subscription URL for sing-box proxy configuration.";
            };
            fetchProxy = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Proxy URL to use when fetching the subscription.";
              default = null;
            };
            onCalendar = lib.mkOption {
              type = lib.types.str;
              description = "OnCalendar setting for the subscription update timer.";
              default = "daily";
            };
          };
        }
      );
    };
    customOutbounds = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        freeformType = with lib.types; attrsOf anything;
        options.tag = lib.mkOption {
          type = lib.types.str;
          description = "Unique tag for this outbound. Takes priority over subscription outbounds with the same tag.";
        };
      });
      default = [];
      description = "List of custom static proxy outbound configurations. Custom outbounds with the same tag as subscription outbounds take priority.";
    };
    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional custom settings to merge (override) into the sing-box configuration.";
    };
  };

  config = lib.mkIf config.proxy.enable {
    environment.systemPackages = with pkgs; [
      sing-box
      jq
      curl
      procps
    ];

    services.sing-box = {
      enable = true;
      settings = {
        log = {
          level = config.proxy.logLevel;
          timestamp = true;
        };
        experimental = {
          cache_file = {
            enabled = true;
          };
        };
        dns = {
          servers =
            (builtins.map mkDirectDns config.dns.directServers)
            ++ (builtins.map mkProxiedDns config.dns.proxiedServers);
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
              action = "sniff";
            }
            {
              protocol = "dns";
              action = "hijack-dns";
            }
            {
              ip_is_private = true;
              action = "route";
              outbound = directRouteTag;
            }
            {
              domain_suffix = [
                "tailscale.com"
                "jsdelivr.net"
              ];
              action = "route";
              outbound = directRouteTag;
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
        outbounds =
          let
            customOutbounds = config.proxy.customOutbounds;
            customOutboundTags = map (ob: ob.tag) customOutbounds;
            proxiedOutboundTags = customOutboundTags ++ lib.optional hasSubscription subscriptionRouteTag;
          in
          [
            {
              type = "direct";
              tag = directRouteTag;
            }
          ]
          ++ customOutbounds
          ++ lib.optionals (proxiedOutboundTags != [ ]) [
            {
              type = "urltest";
              tag = proxiedRouteTag;
              interrupt_exist_connections = false;
              outbounds = proxiedOutboundTags;
            }
          ];
        inbounds = [
          {
            type = "tun";
            tag = tunTag;
            stack = "system";
            interface_name = config.proxy.tun.interface;
            address = config.proxy.tun.networks;
            auto_route = true;
            strict_route = true;
            auto_redirect = true;
            route_exclude_address_set = directIpRuleSets;
            exclude_uid = [ 0 ]; # exclude root user
          }
          {
            type = "socks";
            tag = socksTag;
            listen_port = config.proxy.socksPort;
          }
        ];
      }
      // config.proxy.extraSettings;
    };

    # systemd timer for proxy subscription updates
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/networking/sing-box.nix
    systemd = lib.mkIf hasSubscription (
      let
        subscription = config.proxy.subscription;
        serviceName = "sing-box-proxy-subscription";
        singboxWorkingDir = "/run/sing-box";
        jsonFile = "subscription.json";
        proxy = subscription.fetchProxy;
        url = subscription.url;
        onCalendar = subscription.onCalendar;
        updateScript = pkgs.writeShellScript "update-sing-box-subscription" ''
          set -euo pipefail
          ${pkgs.curl}/bin/curl -s '${url}' ${lib.optionalString (proxy != null) "-x ${proxy}"} \
          | ${pkgs.jq}/bin/jq '.["outbounds"] | map(select(has("server"))) | {outbounds: [.[], {type: "urltest", tag: "${subscriptionRouteTag}", interrupt_exist_connections: false, outbounds: . | map(.["tag"])}]}' \
          > ${singboxWorkingDir}/${jsonFile}
          ${pkgs.coreutils}/bin/chown --reference=${singboxWorkingDir} ${singboxWorkingDir}/${jsonFile}
          ${pkgs.procps}/bin/pkill -HUP sing-box || true
        '';
      in
      {
        timers.${serviceName} = {
          description = "Update sing-box proxy subscriptions";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = onCalendar;
            Persistent = true;
            Unit = "${serviceName}.service";
          };
        };
        services = {
          ${serviceName} = {
            serviceConfig = {
              Type = "oneshot";
              User = "sing-box";
              Group = "sing-box";
              ExecStart = [ "+${updateScript}" ];
            };
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
