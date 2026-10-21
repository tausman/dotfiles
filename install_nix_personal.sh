# Install xorg
sudo apt update
sudo apt install -y xorg

# Install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 

# Apply home-manager
nix run home-manager -- switch -b backup --flake ~/dotfiles/nix-config#ubuntu-x86_64-desktop-personal --impure

