{
  config,
  lib,
  ...
}:
{
  imports = [
    ./firewall.nix
    ./proxy.nix
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
        default = [
          "eth0"
          "eth1"
        ];
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
        default = [
          {
            address = "192.168.88.3";
            prefixLength = 24;
          }
        ];
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
        default = "eth2";
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
      networking = {
        # LAN bridge
        bridges.${config.router.lan.name}.interfaces = config.router.lan.interfaces;

        interfaces = {
          # LAN bridge interface
          ${config.router.lan.name} = {
            ipv4.addresses = mkAddrs config.router.lan.addresses 4;
            ipv6.addresses = mkAddrs config.router.lan.addresses 6;
            useDHCP = config.router.lan.dhcp == "client";
          };

          # WAN interface
          ${config.router.wan.interface} = {
            ipv4.addresses = mkAddrs config.router.wan.addresses 4;
            ipv6.addresses = mkAddrs config.router.wan.addresses 6;
            useDHCP = config.router.wan.dhcp == "client";
          };
        };
      };
    };
}
