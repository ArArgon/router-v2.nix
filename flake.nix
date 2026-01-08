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

      testHostName = "test";
      testUser = "user";
    in
    {
      nixosModules = {
        router-v2 = import ./modules {
          inherit pkgs;
          lib = pkgs.lib;
        };
      };

      # This is just for testing/CI - doesn't affect the module export
      nixosConfigurations.${testHostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules
          ./test.nix
          {
            basic = {
              hostName = testHostName;
              user = testUser;
            };
          }
        ];
      };
    };
}
