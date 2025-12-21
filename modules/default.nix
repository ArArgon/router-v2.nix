{ lib, ... }:
{
  options.basic = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the router.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "The main user account on the router.";
    };
  };

  imports = [
    ./networking
    ./configuration.nix
  ];
}
