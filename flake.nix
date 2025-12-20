{
  description = "Router configuration with NixOS";

  # To use Tsinghua mirror, replace the nixpkgs.url in the main flake inputs with:
  # nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-25.11";
  # The inputs below will follow that nixpkgs.url automatically.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
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
          }
        ];
      };
    };
}
