{
  description = "Router configuration with NixOS";
  inputs = {
    system = "x86_64-linux";
    # Tsinghua Nixpkgs mirror
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-25.11";
    nixpkgs-unstable.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, system, ... }:
    {
      nixosModules = {
        router-v2 = import ./modules {
          pkgs = import nixpkgs { system = system; };
        };
      };
    };
}
