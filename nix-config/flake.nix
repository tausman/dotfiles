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
  };

  outputs = { nixpkgs, home-manager, nix-darwin, ... }:
  let
    # Build a home-manager configuration for a given system. home.nix is shared
    # across every host; it branches on pkgs.stdenv.isDarwin for the mac/linux
    # differences, so the only per-host input here is the system string.
    mkHome = system: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ ./home.nix ];
    };
  in {
    homeConfigurations = {
      # macOS laptop — kept as `default` so the existing flow/README are unchanged.
      default = mkHome "aarch64-darwin";
      # Headless Ubuntu VM (user: bits). Both arches use the SAME config; pick the
      # one matching `uname -m`. install_nix.sh selects this automatically.
      "ubuntu-aarch64" = mkHome "aarch64-linux";
      "ubuntu-x86_64"  = mkHome "x86_64-linux";
    };

    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin.nix
      ];
    };
  };
}
