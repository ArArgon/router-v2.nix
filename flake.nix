{
  description = "Router configuration with NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosModules = {
        router-v2 = import ./modules {
          inherit pkgs;
          lib = pkgs.lib;
        };
      };

      # This is just for testing/CI - doesn't affect the module export
      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules
          {
            fileSystems."/".device = "/dev/null";
            fileSystems."/".fsType = "ext4";
            basic = {
              hostName = "test";
              user = "router";
            };
          }
        ];
      };
    };
}
