# Router Config

To use it, replace `/etc/nix/flake.nix`:

```nix
{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-25.11";
    router-v2.url = "github:ArArgon/router-v2.nix";
    router-v2.inputs.nixpkgs.follows = "nixpkgs";  # Use main flake's nixpkgs
  };
  outputs = inputs@{ self, nixpkgs, router-v2, ... }: {
    nixosConfigurations."router-v2" = nixpkgs.lib.nixosSystem {
      modules = [
        router-v2.nixosModules.router-v2
        ./hardware-configuration.nix

        # Overrides
        {
            # Fill the right interfaces
            router.lan.interfaces = ["enp2s3"];
            router.wan.interface = "enp2s2";
        }
      ];
    };
  };
}
```