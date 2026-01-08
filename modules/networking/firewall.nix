{
  config,
  lib,
  ...
}:
{
  networking = {
    nftables = {
      enable = true;
      ruleset = ''
        table ip filter {
          chain input {
            type filter hook input priority 0;
            policy drop;

            # Allow established and related connections
            ct state established,related accept comment "Allow established and related connections"

            # Drop invalid packets
            ct state invalid drop comment "Drop invalid packets"

            # Allow loopback interface
            iifname "lo" accept comment "Allow loopback interface"

            # Allow LAN traffic
            iifname "${config.router.lan.name}" accept comment "Allow LAN traffic"

            # Allow ICMP (ping)
            ip protocol icmp accept comment "Allow ICMP"

            # Allow SSH
            tcp dport 22 accept comment "Allow SSH from LAN"

            # Tailscale traffic
            ip protocol udp udp dport 41641 accept comment "Allow Tailscale traffic"
            ip protocol udp udp dport 3478 accept comment "Allow Tailscale STUN traffic"

            ${lib.optionalString config.vrrp.enable ''
              # Allow VRRP (protocol 112) for keepalived
              ip protocol 112 accept comment "Allow VRRP"

              # Allow AH (protocol 51) for keepalived
              ip protocol 51 accept comment "Allow AH"
            ''}
          }

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
