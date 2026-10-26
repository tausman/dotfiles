{
  description = "Simple Nix config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, nixgl, ... }:
  let
    # Build a home-manager configuration for a given system + host entry module. Each
    # host file (./hosts/*.nix) sets its identity and imports a profile of shared
    # modules; mac additionally imports the GUI/kmonad modules. The target NAME below is
    # what selects the host file at switch time (see README).
    mkHome = system: hostModule: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ hostModule ];
      extraSpecialArgs = { inherit nixgl; };
    };

    mkHomePersonal = system: hostModule: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ hostModule ];
      extraSpecialArgs = { inherit nixgl; };
    };
  in {
    homeConfigurations = {
      # macOS laptop — kept as `default` so the existing flow/README are unchanged.
      default = mkHome "aarch64-darwin" ./hosts/mac.nix;
      # Headless Ubuntu VM (user: bits). Both arches share ./hosts/linux.nix; pick the
      # one matching `uname -m`. install_nix.sh selects this automatically.
      "ubuntu-aarch64" = mkHome "aarch64-linux" ./hosts/linux.nix;
      "ubuntu-x86_64"  = mkHome "x86_64-linux"  ./hosts/linux.nix;
      # Same VM, plus the VNC remote desktop (profiles/remote-desktop.nix). Opt-in per
      # machine: install_nix.sh picks these only when the desktop marker is set, so a
      # plain VM stays headless.
      "ubuntu-aarch64-desktop" = mkHome "aarch64-linux" ./hosts/linux-desktop.nix;
      "ubuntu-x86_64-desktop"  = mkHome "x86_64-linux"  ./hosts/linux-desktop.nix;
      # personal install
      "ubuntu-x86_64-desktop-personal"  = mkHomePersonal "x86_64-linux"  ./hosts/linux-desktop-personal.nix;
    };

    # Existing personal NixOS machine: one rebuild applies the OS and t's home.
    # The flake target is `personal`; the machine keeps its existing hostname `nixos`.
    nixosConfigurations.personal = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos/personal/configuration.nix
        home-manager.nixosModules.home-manager
        {
          # Retain HM's package set: modules/claude.nix owns its unfree predicate.
          # Enabling useGlobalPkgs would ignore that HM-level package policy.
          home-manager.useGlobalPkgs = false;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "before-home-manager";
          home-manager.users.t = import ./hosts/nixos-personal.nix;
        }
      ];
    };

    # Evaluate the Linux system on any supported development host, without building
    # its Linux closure. The check itself is a tiny native derivation.
    checks = nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ]
      (system: {
        personal = import ./tests/personal.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          flake = self;
        };
      });

    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin.nix
      ];
    };
  };
}
