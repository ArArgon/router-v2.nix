{
  pkgs,
  ...
}:
let
  hostName = "home-router-v2";
  user = "router";
in
{
  # Reference: https://github.com/mitchellh/nixos-config/blob/main/machines/vm-shared.nix
  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # VMware, Parallels both only support this being 0 otherwise you see
  # "error switching console mode" on boot.
  boot.loader.systemd-boot.consoleMode = "0";

  # Define your hostname.
  networking.hostName = hostName;

  # Set your time zone.
  time.timeZone = "Asia/Hong_Kong";

  # Don't require password for sudo
  security.sudo.wheelNeedsPassword = false;

  # Enable tailscale. We manually authenticate when we want with
  # "sudo tailscale up". If you don't use tailscale, you should comment
  # out or delete all of this.
  services.tailscale.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAO1//3XGnTf28dsuupRyTA/Zj1S1IICkEPxmymEEAk0"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPF3kG/mLJDfclVHhWXDI2tBpzXwwb1jpz4glRkv+JFG"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL2ZJi0rJNTtaTRUmRFbN7PvPJjhDEA1G5FAhVT1BrVW"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    git
    jq
    gnumake
    htop
    sysstat
    strace

    # Proxy
    sing-box
    mihomo
    v2ray

    # Networking tools
    iproute2
    net-tools
    mtr
    iputils
    bind
    tcpdump
    iperf3
    nmap
  ];

  services.openssh = {
    enable = true;
    settings = {
      UseDns = true;
      PasswordAuthentication = false;
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
