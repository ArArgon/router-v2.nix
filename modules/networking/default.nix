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
              description = "IPv4 address assigned to the LAN bridge.";
            };
            options.prefixLength = lib.mkOption {
              type = lib.types.int;
              description = "Prefix length for the IPv4 address.";
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
      dhcp = {
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

  config = {
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
          ipv4.addresses = builtins.map (addr: {
            address = addr.address;
            prefixLength = addr.prefixLength;
          }) config.router.lan.addresses;
          useDHCP = config.router.lan.dhcp == "client";
        };

        # WAN interface
        ${config.router.wan.interface} = {
          useDHCP = config.router.wan.dhcp == "client";
        };
      };
    };
  };
}
