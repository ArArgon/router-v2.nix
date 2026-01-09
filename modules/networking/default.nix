{
  config,
  lib,
  ...
}:
{
  imports = [
    ./firewall.nix
    ./proxy.nix
    ./vrrp.nix
  ];

  options.router = {
    lan = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "br-lan";
        description = "Name of the LAN bridge interface.";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of physical interfaces to include in the LAN bridge.";
      };
      addresses = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options.address = lib.mkOption {
              type = lib.types.str;
              description = "IP address assigned to the LAN bridge.";
            };
            options.prefixLength = lib.mkOption {
              type = lib.types.int;
              description = "Prefix length for the IP address.";
            };
            options.version = lib.mkOption {
              type = lib.types.enum [
                4
                6
              ];
              default = 4;
              description = "IP version (4 or 6).";
            };
          }
        );
        default = [ ];
        description = "List of IP addresses for the LAN bridge.";
      };
      dhcp = lib.mkOption {
        type = lib.types.enum [
          "server"
          "client"
          "none"
        ];
        default = "none";
        description = "DHCP configuration for the LAN bridge.";
      };
    };
    wan = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Name of the WAN interface.";
      };
      addresses = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options.address = lib.mkOption {
              type = lib.types.str;
              description = "IP address assigned to the WAN interface.";
            };
            options.prefixLength = lib.mkOption {
              type = lib.types.int;
              description = "Prefix length for the IP address.";
            };
            options.version = lib.mkOption {
              type = lib.types.enum [
                4
                6
              ];
              default = 4;
              description = "IP version (4 or 6).";
            };
          }
        );
        default = [ ];
        description = "List of IP addresses for the WAN interface.";
      };
      dhcp = lib.mkOption {
        type = lib.types.enum [
          "client"
          "none"
        ];
        default = "client";
        description = "DHCP configuration for the WAN interface.";
      };
    };
  };

  config =
    let
      mkAddrs =
        addrs: version:
        builtins.map (
          addr: with addr; {
            inherit address prefixLength;
          }
        ) (builtins.filter (addr: addr.version == version) addrs);
    in
    {
      # Enable forwarding
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      # Configure interfaces
      networking.useNetworkd = true;
      systemd.network = {
        enable = true;
        # Create LAN bridge
        netdevs."10-${config.router.lan.name}" = {
          netdevConfig = {
            Kind = "bridge";
            Name = config.router.lan.name;
          };
        };

        networks = {
          # LAN bridge interface
          "20-${config.router.lan.name}" = {
            matchConfig.Name = config.router.lan.name;
            address = builtins.map (
              addr: "${addr.address}/${toString addr.prefixLength}"
            ) config.router.lan.addresses;
            networkConfig = {
              DHCP = if config.router.lan.dhcp == "client" then "yes" else "no";
              ConfigureWithoutCarrier = true;
            };
            dhcpV4Config.RouteMetric = 200;
            dhcpV6Config.RouteMetric = 200;
          };

          # WAN interface
          "30-${config.router.wan.interface}" = {
            matchConfig.Name = config.router.wan.interface;
            address = builtins.map (
              addr: "${addr.address}/${toString addr.prefixLength}"
            ) config.router.wan.addresses;
            networkConfig.DHCP = if config.router.wan.dhcp == "client" then "yes" else "no";
            dhcpV4Config.RouteMetric = 100;
            dhcpV6Config.RouteMetric = 100;
          };
        }
        // (lib.listToAttrs (
          lib.imap0 (i: iface: {
            name = "40-${iface}";
            value = {
              matchConfig.Name = iface;
              networkConfig.Bridge = config.router.lan.name;
              linkConfig.RequiredForOnline = "enslaved";
            };
          }) config.router.lan.interfaces
        ));
      };
    };
}
