# Personal NixOS machine. User packages and dotfiles are managed by Home Manager
# through hosts/nixos-personal.nix; boot, hardware, and login sessions belong here.
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Native desktop: unlike the Ubuntu remote-desktop profile, no Xvnc or nixGL.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    displayManager.lightdm.enable = true;
    windowManager.i3 = {
      enable = true;
      # User-facing i3 utilities come from the shared Home Manager desktop profile.
      extraPackages = [ ];
    };
  };

  programs.zsh.enable = true;
  users.users.t = {
    isNormalUser = true;
    description = "t";
    home = "/home/t";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];
    # Preserve the existing account/password; do not put credentials in this repo.
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;
  programs.ssh.startAgent = true;

  # Original installation's compatibility version, not the current Nixpkgs release.
  # Do not bump this just because the flake inputs are updated.
  system.stateVersion = "26.05";
}
