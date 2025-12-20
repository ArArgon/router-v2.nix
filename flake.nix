{
  description = "Router configuration with NixOS";
  inputs = {
    # Tsinghua Nixpkgs mirror
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-25.11";
    nixpkgs-unstable.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    {
      nixosModules = {
        router-v2 = import ./modules {
          pkgs = import nixpkgs { system = "x86_64-linux"; };
        };
      };

      # This is just for testing/CI - doesn't affect the module export
      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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
