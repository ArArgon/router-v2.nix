# Router Config

A NixOS module for configuring a router with LAN/WAN networking, VRRP high availability, and sing-box proxy capabilities.

## Features

-   **Router**: Configure LAN bridge and WAN interface with IPv4/IPv6 support
-   **VRRP**: High availability gateway with keepalived
-   **Proxy**: sing-box with TUN interface, SOCKS5, and subscription support
-   **Firewall**: nftables-based firewall with automatic VRRP protocol support

## Usage

To use this module, reference it in your `/etc/nix/flake.nix`:

```nix
{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-25.11";
    router-v2.url = "github:ArArgon/router-v2.nix";
    router-v2.inputs.nixpkgs.follows = "nixpkgs";  # Use main flake's nixpkgs
  };

  outputs = { nixpkgs, router-v2, ... }:
    let
      hostName = "my-router";
      user = "admin";
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          router-v2.nixosModules.router-v2
          ./hardware-configuration.nix
          {
            basic = {
              inherit hostName user;
            };

            # Router configuration
            router = {
              lan = {
                interfaces = [ "eth0" "eth1" ];
                addresses = [
                  {
                    address = "192.168.1.1";
                    prefixLength = 24;
                  }
                ];
                dhcp = "server";
              };
              wan = {
                interface = "eth2";
                dhcp = "client";
              };
            };

            # Optional: Enable VRRP for high availability gateway
            vrrp = {
              enable = true;
              virtualRouterId = 1;
              priority = 100;
              virtualIpAddress = "192.168.1.2";
            };

            # Optional: Enable sing-box proxy
            proxy = {
              enable = true;
              socksPort = 7890;
              subscription.url = "https://example.com/subscription.json";
            };
          }
        ];
      };
    };
}
```

## Configuration Options

### Router (`router`)

-   `lan.name` - LAN bridge interface name
-   `lan.interfaces` - List of physical interfaces to bridge
-   `lan.addresses` - List of IP addresses with `address`, `prefixLength`, and `version` (4 or 6)
-   `lan.dhcp` - DHCP mode: `"server"`, `"client"`, or `"none"`
-   `wan.interface` - WAN interface name
-   `wan.addresses` - List of static IP addresses (optional)
-   `wan.dhcp` - DHCP mode: `"client"` or `"none"`

### VRRP (`vrrp`)

-   `enable` - Enable VRRP (default: `false`)
-   `virtualRouterId` - VRRP Virtual Router ID (1-255)
-   `priority` - Router priority (higher = master)
-   `virtualIpAddress` - Shared virtual IP address

### Proxy (`proxy`)

-   `enable` - Enable sing-box proxy (default: `false`)
-   `logLevel` - Log level: `"debug"`, `"info"`, `"warn"`, `"error"` (default: `"warn"`)
-   `socksPort` - SOCKS5 proxy port
-   `tun.interface` - TUN interface name (default: `"singbox0"`)
-   `tun.networks` - IP networks for TUN interface
-   `subscription` - Proxy subscription configuration (optional)

## Development

Test the configuration:

```bash
nix flake check
```
