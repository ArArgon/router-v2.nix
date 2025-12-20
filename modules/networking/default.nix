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
      subnet = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "Subnet prefix length for the LAN network.";
      };
      addresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "192.168.88.3" ];
        description = "List of IP addresses for the LAN bridge.";
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
      bridges.${config.router.lan.name} = {
        interfaces = config.router.lan.interfaces;
        ipv4.addresses = [
          {
            address = config.router.lan.addresses;
            prefixLength = config.router.lan.subnet;
          }
        ];
        ipv4.dhcp = config.router.lan.dhcp;
      };

      # WAN interface
      interfaces.${config.router.wan.interface} = {
        ipv4.dhcp = config.router.wan.dhcp;
      };
    };
  };
}
