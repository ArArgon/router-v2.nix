{ config, ... }:
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

            # Allow SSH from specific sources (adjust as needed)
            iifname "${config.router.lan.name}" tcp dport 22 accept comment "Allow SSH from LAN"
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
          # chain prerouting {
          #   type nat hook prerouting priority 0;
          #   policy accept;

          #   # DNS redirection
          #   iifname "${config.router.lan.name}" meta l4proto {tcp, udp} th dport 53 redirect to ports ${toString config.proxy.dns_server_port} comment "Redirect DNS to local proxy"
          # }

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
