{ lib, ... }:
{
  dnsServerType = lib.types.submodule {
    options.address = lib.mkOption {
      type = lib.types.str;
      description = "DNS server address.";
    };
    options.port = lib.mkOption {
      type = lib.types.int;
      default = 53;
      description = "DNS server port.";
    };
    options.protocol = lib.mkOption {
      type = lib.types.enum [
        "udp"
        "tcp"
        "tls"
        # DoH is not supported by CoreDNS forward plugin
      ];
      default = "udp";
      description = "DNS server protocol. Supported protocols are udp, tcp, and tls.";
    };
    options.tlsDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "TLS domain name for DNS-over-TLS servers.";
    };
  };

  mkUdpDns =
    {
      address,
      port ? 53,
    }:
    {
      address = address;
      port = port;
      protocol = "udp";
    };
  mkTlsDns =
    {
      address,
      domain,
    }:
    {
      address = address;
      port = 853;
      protocol = "tls";
      tlsDomain = domain;
    };
}
