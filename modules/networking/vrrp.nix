{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.vrrp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VRRP (Virtual Router Redundancy Protocol) for high availability.";
    };
    virtualRouterId = lib.mkOption {
      type = lib.types.int;
      description = "VRRP Virtual Router ID (VRID). Must be between 1 and 255.";
    };
    priority = lib.mkOption {
      type = lib.types.int;
      description = "VRRP priority for this router. Higher values indicate higher priority.";
    };
    virtualIpAddress = lib.mkOption {
      type = lib.types.str;
      description = "The virtual IP address shared among VRRP routers.";
    };
  };

  config = lib.mkIf config.vrrp.enable {
    environment.systemPackages = with pkgs; [
      keepalived
    ];

    services.keepalived = {
      enable = true;
      # Don't use openFirewall - we'll handle it with nftables
      openFirewall = false;
      # Non-optional: enforce NixOS compatibility
      # https://nixos.wiki/wiki/Keepalived
      extraGlobalDefs = ''
        use_symlink_paths true
      '';

      vrrpInstances."VIP_${builtins.toString config.vrrp.virtualRouterId}" = {
        interface = config.router.lan.name;
        virtualRouterId = config.vrrp.virtualRouterId;
        priority = config.vrrp.priority;
        virtualIps = [
          {
            addr = config.vrrp.virtualIpAddress;
          }
        ];
        extraConfig = "
        version 3
        ";
      };
    };
  };
}
