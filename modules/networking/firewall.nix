{
  config,
  lib,
  ...
}:
{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 53 ];
      allowedUDPPorts = [ 53 41641 3478 ];
      trustedInterfaces = [ config.router.lan.name ];
      extraInputRules = lib.optionalString config.vrrp.enable ''
        ip protocol 112 accept comment "Allow VRRP"
        ip protocol 51 accept comment "Allow AH"
      '';
    };

    nftables = {
      enable = true;
      ruleset = ''
        table ip filter {
          chain forward {
            type filter hook forward priority 0;
            policy drop;

            # Allow established and related connections
            ct state established,related accept comment "Allow established and related connections"

            # Drop invalid packets
            ct state invalid drop comment "Drop invalid packets"

            # Allow forwarding from LAN to WAN
            iifname "${config.router.lan.name}" oifname "${config.router.wan.interface}" accept comment "Allow LAN to WAN forwarding"
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100;
            policy accept;

            # Masquerade LAN traffic going out via WAN
            oifname "${config.router.wan.interface}" masquerade comment "Masquerade LAN traffic"
          }
        }
      '';
    };
  };
}
