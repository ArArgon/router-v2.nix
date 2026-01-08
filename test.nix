# Test configuration with all capabilities enabled for comprehensive test coverage
{ ... }:
{
  # Basic system configuration for testing
  fileSystems."/".device = "/dev/null";
  fileSystems."/".fsType = "ext4";

  # Router configuration with comprehensive settings
  router = {
    lan = {
      interfaces = [
        "eth0"
        "eth1"
        "eth2"
      ];
      addresses = [
        {
          address = "192.168.88.1";
          prefixLength = 24;
          version = 4;
        }
        {
          address = "fd00:192:168:88::1";
          prefixLength = 64;
          version = 6;
        }
      ];
      dhcp = "server";
    };
    wan = {
      interface = "eth3";
      addresses = [
        {
          address = "203.0.113.10";
          prefixLength = 24;
          version = 4;
        }
        {
          address = "2001:db8::10";
          prefixLength = 64;
          version = 6;
        }
      ];
      dhcp = "client";
    };
  };

  # VRRP configuration - enabled with comprehensive settings
  vrrp = {
    enable = true;
    virtualRouterId = 51;
    priority = 200;
    virtualIpAddress = "192.168.88.254";
  };

  # Proxy configuration - enabled with comprehensive settings
  proxy = {
    enable = true;
    log_level = "info";
    socks_port = 1080;
    tun = {
      interface = "singbox-tun";
      networks = [
        "172.19.0.1/30"
        "fd00:abcd::/64"
      ];
    };
    subscription = {
      url = "http://example.com/proxy-config";
      fetch_proxy = "http://proxy.example.com:8080";
    };
  };
}
