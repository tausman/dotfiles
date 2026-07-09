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
    # Build a home-manager configuration for a given system + host entry module. Each
    # host file (./hosts/*.nix) sets its identity and imports the shared modules under
    # ./home; mac additionally imports the GUI/kmonad modules. The target NAME below is
    # what selects the host file at switch time (see README).
    mkHome = system: hostModule: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ hostModule ];
    };
  in {
    homeConfigurations = {
      # macOS laptop — kept as `default` so the existing flow/README are unchanged.
      default = mkHome "aarch64-darwin" ./hosts/mac.nix;
      # Headless Ubuntu VM (user: bits). Both arches share ./hosts/linux.nix; pick the
      # one matching `uname -m`. install_nix.sh selects this automatically.
      "ubuntu-aarch64" = mkHome "aarch64-linux" ./hosts/linux.nix;
      "ubuntu-x86_64"  = mkHome "x86_64-linux"  ./hosts/linux.nix;
    };

    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin.nix
      ];
    };
  };
}
