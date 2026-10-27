# nix-config

Nix-based machine setup for macOS, Ubuntu workspaces, and the personal NixOS machine.
`flake.nix` exposes separate Darwin system/Home Manager targets, Ubuntu Home Manager
targets, and a NixOS target with integrated [Home Manager](https://github.com/nix-community/home-manager).
macOS system configuration is managed by [nix-darwin](https://github.com/nix-darwin/nix-darwin).

The home-manager config is layered **modules → profiles → hosts**:

- `modules/` — one leaf per tool (git, zsh, tmux, neovim, jj, claude, codex, dev, alacritty,
  kmonad, aerospace, vnc, …).
- `profiles/` — bundles: `base.nix` (shared leaves + the `liveLink` helper), `darwin.nix`
  (alacritty + ghostty + kmonad + aerospace), `desktop.nix` (= base + darwin), `linux.nix`
  (Linux-only packages), `headless.nix` (= base + linux), `linux-desktop.nix`
  (= headless + shared desktop applications/settings), and `remote-desktop.nix`
  (= linux-desktop + VNC server/compatibility add-on).
  `darwin.nix` and `linux.nix` are the two platform layers: anything nixpkgs builds for only
  one OS goes in one of them instead of an `optionals isLinux`-style guard in `modules/`.
- `hosts/` — pure identity (username/home) + one profile import: `mac.nix` → `desktop`,
  `linux.nix` → `headless`, `linux-desktop.nix` → `remote-desktop`,
  `nixos-personal.nix` → `linux-desktop`.
- `nixos/<machine>/` — NixOS **system** modules and generated hardware configuration.
  These are separate from the Home Manager modules above.

`darwin.nix` was `gui.nix`. Nothing in it was ever about *having a display* — alacritty and
ghostty are installed as apps by Homebrew and those modules only link configs, and kmonad's
launchd daemon is macOS-only — so it's named for the axis it actually tracks. Linux
reuses config-only leaves such as `alacritty.nix`, not the Darwin-specific bundle.

The flake maps each target name to a host file: `default` → `hosts/mac.nix`,
`ubuntu-{aarch64,x86_64}` → `hosts/linux.nix`, `ubuntu-{aarch64,x86_64}-desktop` →
`hosts/linux-desktop.nix`. Role differences (GUI vs headless) are
expressed by *which profile a host imports* — no `if` branches. The one genuine platform
gate is Homebrew's shellenv, guarded on `pkgs.stdenv.isDarwin` inside `modules/zsh.nix`
(empty on Linux).

On the **headless Ubuntu VM** it's home-manager only (no nix-darwin) and is bootstrapped
by `../install_nix.sh` — see [Ubuntu / Linux (headless VM)](#ubuntu--linux-headless-vm)
at the bottom. The rest of this doc (Parts 1–3, kmonad, etc.) is the macOS flow.

- Flake lives in: `/Users/tausif.rahman/dotfiles/nix-config`
- Both **macOS** outputs use the `default` target: `darwinConfigurations.default`, `homeConfigurations.default`

**The flow:** do everything you install/build up front (**Part 1**), then apply the
config with two switches (**Part 2**), then a small cleanup (**Part 3**). After Part 2,
everything — dotfiles, packages, Homebrew, and the kmonad + Karabiner launchd daemons —
is live.

> **Status:** living document. Steps marked **TODO** aren't wired into Nix yet.

---

## NixOS — personal machine

**Target: `nixosConfigurations.personal`.** One rebuild applies the operating system
and the shared dotfiles/packages for user `t`. The flake target name is `personal`;
the machine's existing hostname remains `nixos`.

```text
flake.nix → nixosConfigurations.personal
  ├── nixos/personal/configuration.nix          # boot, networking, users, LightDM/i3
  │   └── hardware-configuration.nix            # this machine's disks and hardware
  └── hosts/nixos-personal.nix                  # Home Manager: t, /home/t
      └── profiles/linux-desktop.nix           # shared Linux CLI tools + desktop apps/config
```

### Apply on the existing NixOS machine

This is **not** a disk installer and does not convert Ubuntu into NixOS. It preserves
the imported machine's encrypted root/EFI mounts, latest-kernel selection, Intel NPU,
and `system.stateVersion = "26.05"`. The flake's existing lockfile supplies the Nixpkgs
version; `stateVersion` is a compatibility setting, not a release selector.

1. Log in as `t` and put the **whole repository** at **`/home/t/dotfiles`**. The shared
   `liveLink` helper points there; moving/deleting the checkout breaks those live config
   links. Do not copy only `nix-config/` or force a `path:.../nix-config` flake reference:
   the shared Git module also reads the repository-level `git/.git-template/config`.
   Use the normal checkout paths shown below so Nix includes the full Git source.
2. Back up `/etc/nixos` and any existing home config you care about. Home Manager uses
   `.before-home-manager` backups for ordinary unmanaged-file conflicts, but some existing
   shared agent modules explicitly force their own files. If a backup already exists,
   resolve that collision rather than deleting it blindly.
3. Build first, then apply:

   ```sh
   cd ~/dotfiles
   sudo nixos-rebuild build --flake "$HOME/dotfiles/nix-config#personal"
   sudo nixos-rebuild switch --flake "$HOME/dotfiles/nix-config#personal"
   ```

   `nixos-rebuild` enables the flake features for its own invocation; the new system
   configuration also enables `nix-command` and `flakes` persistently.
4. Log out and back in to pick up the Zsh login shell, user-package PATH, and i3 config.
   Reboot when ready to load the configured kernel/boot changes.

Subsequent changes use the same `switch` command. Do **not** additionally run a standalone
`home-manager switch` for this user: the system rebuild owns that activation. Do not run
`install_nix.sh` or `install_nix_personal.sh` here; those are Ubuntu bootstrap paths and
are unnecessary on NixOS. Existing account credentials are not changed by this config.

Home Manager deliberately retains its own package set (`useGlobalPkgs = false`), so
`modules/claude.nix`'s unfree-package predicate continues to apply. User packages are
installed through NixOS (`useUserPackages = true`). The shared base still includes work
Git/SSH/agent settings; this target does not create a separate personal/work identity or
run the Datadog repository/auth bootstrap.

Neovim is declared once, in `modules/neovim.nix`, together with its user configuration.
`useUserPackages` exposes that Home Manager environment through NixOS; it is not a
second Neovim declaration. There is no separate NixOS system-package entry for it.

### Native desktop

NixOS owns LightDM/Xorg/i3 and supplies the fallback/UI fonts (including DejaVu and
emoji). Both native and Ubuntu/VNC desktops use the same `linux-desktop.nix` bundle:
xterm, Alacritty, Ghostty, Firefox, Chromium, i3 utilities, and shared CLI tools.
The NixOS i3 service starts the session; its optional user utilities come from Home
Manager rather than a second system package list. Native NixOS needs no VNC/nixGL add-on.

`modules/alacritty.nix` only links settings/themes and supplies Hack Nerd Font; it does
**not** install the application. The Linux profile installs the Alacritty binary once;
on macOS Homebrew installs it. There is no duplicate Alacritty installation.

Native and VNC sessions use **one complete i3 file**, `config/.config/i3/config`,
live-linked by `modules/i3.nix`. There are no include fragments, generated entry points,
or terminal overrides. xterm is the default everywhere; Chromium is the browser shortcut.
Alacritty, Ghostty, and Firefox remain available from the launcher. Apply the relevant
Home Manager/NixOS target once after this layout change, then restart i3.

- `Alt+Enter`: xterm; `Alt+b`: Chromium; `Alt+d`: launcher.
- `Alt+h/j/k/l`: Vim-style focus; add Shift to move a window.
- `Alt+1..5`: workspaces; `Alt+Shift+r`: reload via i3 restart.

### C/C++ build tools

The shared Home Manager `modules/dev.nix` installs GNU Make (`make`), CMake, GCC
(`gcc`/`g++`), and Clang (`clang`/`clang++`) on NixOS, Ubuntu, and macOS. There are no
separate NixOS system-package declarations for them.

Both compiler wrappers provide `cc`/`c++` with the same default package priority,
which conflicts when Home Manager builds the user profile. A single `lib.hiPrio gcc`
resolves those shared names in favor of GCC; it does not disable Clang. Use `clang`
and `clang++` explicitly when a project needs them.

Both compilers are optional alternatives, not a requirement to use together. For a
project that should use Clang, select `CC=clang CXX=clang++` or set CMake's compiler
options in a fresh build directory. Project-specific libraries still belong in that
project's development environment rather than this general tool list.

### KMonad — built-in keyboard

The `personal` target enables NixOS's native KMonad service for
`/dev/input/by-path/platform-i8042-serio-0-event-kbd` only. External keyboards are not
remapped. No extra flake input, custom service, or membership in `input`/`uinput` for
user `t` is needed; the NixOS module manages its own service permissions and device watcher.

`kmonad/kmonad.kbd` remains the single source of mappings. The NixOS configuration
replaces only its macOS input/output backends with Linux `device-file`/`uinput-sink`
backends, preserving the layers, timings, modifier swaps, `fallthrough true`, and
`allow-cmd false`. The macOS file and launchd setup are unchanged.

Unlike the macOS live link, the Linux service uses a built snapshot. After editing the
keymap, apply it with the usual command:

```sh
sudo nixos-rebuild switch --flake "$HOME/dotfiles/nix-config#personal"
```

The NixOS build runs `kmonad -d` against the generated file before installing it. For
the first activation, keep an SSH session or an external keyboard available. Check:

```sh
systemctl status kmonad-builtin.path kmonad-builtin.service --no-pager
sudo journalctl -u kmonad-builtin.service -b --no-pager -n 50
```

The path unit starts the service when the keyboard device exists. To temporarily turn
off remapping, stop **both** the watcher and service; stopping only the service can
cause the watcher to start it again:

```sh
sudo systemctl stop kmonad-builtin.path
sudo systemctl stop kmonad-builtin.service
# Re-enable after troubleshooting:
sudo systemctl start kmonad-builtin.path
```

The shared mapping's `lp`/`mctl` actions are macOS Launchpad/Mission Control keys, not
Linux desktop actions. Fn behavior also depends on whether the keyboard exposes it to
Linux. Existing modifier remaps are preserved, with Meta meaning Super on Linux;
verify those keys/layers on the actual machine rather than assuming macOS desktop behavior.

### A different NixOS machine

**Do not apply `#personal` unchanged to another machine:** its hardware file contains
specific encrypted-disk and EFI identifiers. Create another `nixos/<machine>/` entry
using that machine's generated hardware/boot configuration, declare its matching user
and home entry, and add another `nixosConfigurations` target. Preserve each machine's
original `system.stateVersion` independently of Home Manager's `home.stateVersion`.

### Validation without activation

These extra tests are **opt-in**: `nixos-rebuild build` and `switch` select the system
output, not `checks`, so they do not run this regression suite. Normal NixOS module
assertions still apply. `nix flake check` evaluates the checks and builds them for the
current platform; `--no-build` only evaluates them, including the assertions in this suite.
Nix can reuse an already-built check result when its inputs have not changed.

From the repo root, evaluate all regression checks and the full NixOS system derivation:

```sh
nix flake check --no-build --all-systems --no-write-lock-file ./nix-config
nix eval --raw --no-write-lock-file \
  ./nix-config#nixosConfigurations.personal.config.system.build.toplevel.drvPath
```

Add `--offline` when the locked inputs are already cached. The check covers machine
settings, integrated Home Manager, the common desktop app list and single i3 config,
VNC-only compatibility flags, package/font ownership, compiler availability/priority,
the KMonad device/backends and service permissions, and preservation of all existing
Darwin/Ubuntu target names. It also runs as a tiny native check on an ARM Mac:

```sh
nix build --no-link --no-write-lock-file ./nix-config#checks.aarch64-darwin.personal
```

That check only evaluates the Linux system; it does not build or activate its Linux
closure. A real system build, boot/decryption, login, and desktop check must run on the
target NixOS machine (or an appropriate Linux builder for the build).

---

## Part 1 — macOS prerequisites (install/build everything first)

### 1. Apple Command Line Tools

Provides `git`, compilers, and headers the rest of the bootstrap needs (and is enough
to build kmonad — full Xcode is not required).

```sh
xcode-select --install
```

### 2. Install Nix

Required for everything below. Determinate Systems installer (robust on macOS):

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Open a new shell afterward so `nix` is on `PATH`.

### 3. Install `gh` (temporary bootstrap)

Via Nix so we don't need Homebrew yet. `modules/git.nix` installs `gh` permanently at Part 2;
we remove this bootstrap copy in Part 3.

```sh
nix profile install nixpkgs#gh
```

### 4. Clone the dotfiles

The `tausman/dotfiles` repo is public, so clone over HTTPS — no auth needed yet:

```sh
git clone https://github.com/tausman/dotfiles.git ~/dotfiles
```

### 5. GitHub auth + signing keys (`install.sh auth`)

`install.sh auth` is the one and only auth step. It logs in **both** accounts through
`gh` (`tausman` and the Datadog-managed `tausif-rahman_ddog`), generates/uploads
per-account SSH keys, sets up commit **signing** on `tausman`, and walks you through
SSO authorization.

```sh
cd ~/dotfiles
./install.sh auth
```

Keys created:
- `~/.ssh/id_ed25519_tausman` — auth **and** commit signing (has DataDog org access)
- `~/.ssh/id_ed25519_ddog` — auth for the managed account

Complete the browser SSO authorization for the `tausman` key against the `DataDog` org.

### 6. Make sure Git-over-SSH authenticates as `tausman`

Biggest gotcha of the setup: **`gh auth switch` does NOT change which account raw
`git@github.com` SSH uses** — that's decided by which key the agent offers. With both
keys loaded, SSH may pick `ddog` and authenticate as the wrong account. The DataDog tap
(step 9) and most DataDog repos need the **`tausman`** identity.

```sh
ssh -T git@github.com          # want: "Hi tausman!"  (not tausif-rahman_ddog)
```

If it greets the wrong account, force `tausman`:

```sh
ssh-add -D                                              # drop all keys
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_tausman  # add tausman only
# (or just remove the other: ssh-add -d ~/.ssh/id_ed25519_ddog)
```

> **Note:** `zshrc/.zshrc` re-adds both keys to the (keychain-backed) agent on shell
> startup (agent doesn't persist across reboots) — **tausman first** so it's offered
> first to `github.com`. If a fresh shell still can't auth:
> `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_tausman ~/.ssh/id_ed25519_ddog`.

### 7. Install `git-config-tool` (Datadog devtools)

Datadog's `git-config-tool` — exports git/SSH config for workspaces, and is required by
`install.sh init`'s precheck. It's a vendor `curl | sh` installer, so it's **not** managed
by Nix (self-updating internal binary); run it once here, after GitHub auth:

```sh
curl -fsSL https://binaries.ddbuild.io/devtools/apps/git-config-tool/install.sh | sh
git-config-tool setup --no-signing --no-1password
```

`--no-signing` because commit signing is already handled by the `tausman` key from
step 5; `--no-1password` skips the 1Password integration. Needs Datadog network/VPN access.

### 8. Install Homebrew

nix-darwin *manages* Homebrew packages/taps but does **not** install Homebrew itself.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 9. Pre-tap the DataDog Homebrew tap

The tap is declared in `darwin.nix` (`ddtool` is a **cask**, not a formula). The Part 2
darwin switch would clone it, but doing that under `sudo` tends to fail with "Permission
denied (publickey)" for two reasons — so tap it manually now as your **normal user**:

```sh
brew tap datadog/tap git@github.com:DataDog/homebrew-tap.git
```

If it still fails, the two root causes (relevant again at Part 2 under `sudo`):
- **root can't see your SSH agent** — pass it through at switch time (`--preserve-env=SSH_AUTH_SOCK`).
- **root has never trusted `github.com`** — pre-warm its known_hosts:
  ```sh
  sudo mkdir -p /var/root/.ssh
  ssh-keyscan github.com | sudo tee -a /var/root/.ssh/known_hosts >/dev/null
  ```

### 10. Build kmonad from source (with dext)

The **nixpkgs kmonad is built without macOS DriverKit (`dext`) support and segfaults on
device access**, so build the binary yourself. It installs to `~/.local/bin/kmonad` —
exactly where `launchd.daemons.kmonad` (in `darwin.nix`) expects it.

```sh
nix profile install nixpkgs#stack                        # Haskell build tool
git clone --recursive https://github.com/kmonad/kmonad.git   # --recursive pulls the Karabiner submodule
cd kmonad
stack install --flag kmonad:dext                         # → ~/.local/bin/kmonad
~/.local/bin/kmonad --version                            # sanity check
```

- First build downloads its own GHC + deps — expect 10–30 min. GHC's installer prints
  harmless `ld: unknown options: --version` / `ranlib` warnings — ignore them.
- **Command Line Tools are sufficient.** Only if it fails on missing frameworks/SDK do
  you need full Xcode (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
  + `sudo xcodebuild -license accept`, then re-run).

### 11. Install + approve the Karabiner-VirtualHIDDevice driver (v5.0.0)

kmonad injects keys through this driver. **Use v5.0.0** (matches kmonad's dext) — not
the latest release. The matching `.pkg` is in the kmonad clone from step 10:

```sh
open ~/kmonad/c_src/mac/Karabiner-DriverKit-VirtualHIDDevice/dist/Karabiner-DriverKit-VirtualHIDDevice-5.0.0.pkg
# or: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/tag/v5.0.0
```

Activate the driver extension, then approve it:

```sh
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
```

- Approve under **System Settings → General → Login Items & Extensions → Driver
  Extensions** (toggle on Karabiner). If it hangs at *"requires user approval,"* `Ctrl-C`
  and approve there. (The **Privacy & Security → Security** block is Gatekeeper — not this.)
- If nothing to approve ever appears, corporate **MDM** is blocking it — have IT
  allowlist pqrs.org team ID **`G43BCU2T37`**.
- Verify (`[activated enabled]`): `systemextensionsctl list | grep -i karabiner`

> The Karabiner *daemon* is started automatically by `launchd.daemons.karabiner-vhid`
> (in `darwin.nix`) at Part 2 — you don't start it by hand.

### 12. Grant kmonad Input Monitoring

Without this, kmonad connects to the driver but can't read the keyboard
(`IOHIDDeviceOpen error: (iokit/common) not permitted`). In **System Settings → Privacy
& Security → Input Monitoring**, add and enable the kmonad binary (permissions attach to
the path, so this also covers the root daemon at Part 2):

```
/Users/tausif.rahman/.local/bin/kmonad
```

Click `+`, `Cmd+Shift+G`, paste that path. Also enable your terminal (Alacritty) if you
plan to run kmonad in the foreground for debugging.

### 13. Grant AeroSpace Accessibility

AeroSpace (tiling window manager) needs **Accessibility** to move and resize windows —
without it, it starts, sees your windows, and silently can't touch them. In **System
Settings → Privacy & Security → Accessibility**, add and enable:

```
/Applications/AeroSpace.app
```

Do this *after* the first `darwin-rebuild` in Part 2 — Homebrew installs the app there,
so it doesn't exist until then. macOS usually prompts on first launch, in which case
just approve and skip this step.

> Installing AeroSpace as a **cask** rather than `pkgs.aerospace` is deliberate: the
> Accessibility grant is keyed to the binary's path, and a nix store path changes on
> every version bump, so a nix-installed AeroSpace has to be re-granted each time.
> `/Applications/AeroSpace.app` is stable.

---

## Part 2 — Apply the config (the two switches)

Run **home-manager first** (deploys your user env, including `~/.config/kmonad.kbd` and
`~/.config/aerospace/aerospace.toml`), **then darwin-rebuild** (system: Homebrew — which
is what installs AeroSpace — plus the kmonad + Karabiner launchd daemons). Ordering it
this way means both configs already exist when the things that read them appear, so they
come up cleanly.

**First-time bootstrap** (tools not yet installed) — via `nix run`:

```sh
# user (home-manager)
nix run home-manager -- switch --flake /Users/tausif.rahman/dotfiles/nix-config#default

# system (nix-darwin) — --preserve-env so the tap clone can auth under sudo
sudo --preserve-env=SSH_AUTH_SOCK nix run nix-darwin -- switch --flake /Users/tausif.rahman/dotfiles/nix-config#default
```

**Subsequent rebuilds**:

```sh
home-manager switch --flake /Users/tausif.rahman/dotfiles/nix-config#default
sudo --preserve-env=SSH_AUTH_SOCK darwin-rebuild switch --flake /Users/tausif.rahman/dotfiles/nix-config#default
```

After this, both launchd daemons are loaded and running — see **Verifying the kmonad
services** below. Key repeat and caps-lock→escape are handled by `darwin.nix` (no manual
`krp` tuning — that's what `krp.txt` documented).

## Part 3 — Cleanup

Remove the bootstrap `gh` (home-manager now provides it):

```sh
nix profile remove nixpkgs#gh
which gh                          # should resolve under ~/.nix-profile
```

---

## Verifying the kmonad services

After Part 2, kmonad should run automatically as a system launchd daemon (talking to the
Karabiner daemon, also managed). Check both:

```sh
# both daemons loaded?
sudo launchctl print system/org.nixos.kmonad        | grep -iE 'state|path'
sudo launchctl print system/org.nixos.karabiner-vhid | grep -iE 'state|path'

# the plists nix-darwin generated
ls -l /Library/LaunchDaemons/org.nixos.kmonad.plist /Library/LaunchDaemons/org.nixos.karabiner-vhid.plist

# kmonad's own logs — should NOT show "not permitted" or a version mismatch
tail -n 20 /tmp/kmonad.err.log
```

Want `state = running` for both. If kmonad isn't up (e.g. it started before its config
existed), kick it once:

```sh
sudo launchctl kickstart -k system/org.nixos.kmonad
```

Then just **test a remapped key**. If it's still not remapping, debug in the foreground
(the daemon fails silently otherwise):

```sh
sudo ~/.local/bin/kmonad ~/.config/kmonad.kbd
```

- `IOHIDDeviceOpen error: (iokit/common) not permitted` → Input Monitoring (step 12).
- `driver_version_mismatched 1` → wrong Karabiner driver version (step 11, must be 5.0.0).
- `driver_connected 0` (never 1) → Karabiner daemon not running (`org.nixos.karabiner-vhid`).

---

## How kmonad is wired

- `darwin.nix` → `launchd.daemons.kmonad` runs `~/.local/bin/kmonad` (hand-built, step 10)
  against `~/.config/kmonad.kbd`, and `launchd.daemons.karabiner-vhid` runs the driver
  daemon. Both `RunAtLoad` + `KeepAlive`.
- `modules/kmonad.nix` (imported via `profiles/darwin.nix`, so only on the mac) → links
  `~/.config/kmonad.kbd` → `../kmonad/kmonad.kbd`.
- `../kmonad/com.example.kmonad.plist` is a manual-install reference for **non-nix**
  machines only — do not load it here (nix-darwin already manages the daemon).

## How AeroSpace is wired

- `darwin.nix` → the `nikitabobko/tap` tap + the `nikitabobko/tap/aerospace` cask. The
  cask also installs the `aerospace` CLI and its shell completions. AeroSpace starts
  itself (`start-at-login = true` in the TOML), so there's no launchd job — unlike
  kmonad, nix doesn't own its lifecycle. That's the trade for a stable
  `/Applications/AeroSpace.app` and an Accessibility grant that survives upgrades.
- `modules/aerospace.nix` (via `profiles/darwin.nix`, mac only) → links
  `~/.config/aerospace/aerospace.toml` → `../config/.config/aerospace/aerospace.toml`.
  That's one of the two paths AeroSpace checks by default, so nothing has to point at it.
- Deliberately **not** nix-darwin's `services.aerospace`, which renders the TOML into
  `/nix/store` — every keybinding tweak would then need a `darwin-rebuild`. With the live
  symlink, edit the file and hit `alt-shift-c` (`reload-config`).
- The keymap is a port of `config/.config/i3/config` (shared Linux/VNC config): `alt` as the
  modifier, vim keys for focus/move, workspaces 1–5, `alt-r` for resize mode. Keeping the
  two in sync means the muscle memory transfers.
- `system.defaults.dock.mru-spaces = false` is required — macOS reordering Spaces by
  recency desyncs AeroSpace's workspace-to-monitor mapping.
- Replaced Rectangle (`pkgs.rectangle`, now removed from `environment.systemPackages`).
  Two window managers fighting over the same windows glitches; `/Applications/Rectangle.app`
  is an MDM/manual install and is not nix-managed — remove it by hand if you want it gone.

Check it:

```sh
aerospace list-windows --all      # talks to the running instance; errors if it's down
aerospace list-workspaces --all
brew info --cask nikitabobko/tap/aerospace
```

### On `alt` and special characters

Bound combos are safe. AeroSpace registers its hotkeys through Carbon's
`RegisterEventHotKey` (verified: the binary imports `_RegisterEventHotKey`, not
`CGEventTapCreate`), and the system consumes a registered hotkey before it reaches the
focused app — so `alt-l` moves focus and does *not* type `¬`.

The Option layer is still live for combos AeroSpace **doesn't** bind (`alt-p` → `π`, etc.),
and macOS has no global switch to turn that off — it's a property of the keyboard layout.
If you ever want it truly gone, the route is a custom layout with the Option layer
stripped (build one with Ukelele, drop the `.bundle` in `~/Library/Keyboard Layouts`, then
select it under Input Sources — the file could be nix-managed, but selecting it is manual).
kmonad can't do it: it sits upstream of the layout, so it remaps *which* key arrives, not
what the layout composes from it.

## How the zsh config is wired (don't edit dotfiles in `$HOME` directly)

home-manager **owns** `~/.zshenv`, `~/.zprofile`, `~/.zshrc` — generated symlinks into
the read-only nix store. Edit the repo files instead:

- `modules/zsh.nix` `programs.zsh.envExtra`  → sources `~/.config/zsh/dotfiles.zshenv`
- `modules/zsh.nix` `programs.zsh.initExtra` → sources `~/.config/zsh/dotfiles.zshrc`
- `modules/zsh.nix` `programs.zsh.profileExtra` → `eval "$(/opt/homebrew/bin/brew shellenv zsh)"`,
  guarded on `pkgs.stdenv.isDarwin` (empty on the Linux VM)

Edit `zshrc/.zshrc` / `zshrc/.zshenv`, then `home-manager switch`. Oh My Zsh works because
`modules/zsh.nix` installs it and links `~/.oh-my-zsh` to `$ZSH`. `~/.local/bin` is on PATH
via `modules/core.nix`'s `home.sessionPath`.

> home-manager session vars (PATH, etc.) are applied **once per login session** (guarded
> by `__HM_SESS_VARS_SOURCED`). After a switch that changes them, open a fresh terminal /
> `tmux kill-server` — an existing session keeps the stale values.

## Troubleshooting

- **`brew tap` "could not read Username for https://github.com"** → tap tried HTTPS;
  `clone_target` SSH URL is set in `darwin.nix` (it is). Pre-tap manually (step 9).
- **"Permission denied (publickey)" on the tap clone** → wrong SSH account (step 6) or
  root known_hosts / `sudo` agent (step 9). Fastest: manual `brew tap` as your user.
- **`ddtool` "No available formula"** → it's a **cask**, keep it under `casks`.
- **`ssh -T git@github.com` greets the wrong account** → `gh auth switch` doesn't affect
  SSH; fix the key the agent offers (step 6).
- **`git clone`/`git init` "could not lock config file .git/config"** → a read-only
  symlinked git template. `modules/git.nix` copies `~/.git-template/config` in as a real file
  (activation), so this shouldn't recur; if it does, ensure that path isn't a store symlink.
- **A renamed `home.file` target leaves a stale symlink** → home-manager only deletes its
  own generation symlinks. Remove the old path manually, then re-switch.
- **`darwin-rebuild` not found under sudo** → use `/run/current-system/sw/bin/darwin-rebuild`.

## Notes

- After the first run: open a fresh shell (`exec zsh -l`) so session vars/PATH refresh.
- The broader dotfiles bootstrap (repos, stow, claude, etc.) is `../install.sh` — run with
  no args for stow, or `./install.sh {all|init|auth|stow|base|repos|...}`.

---

## Ubuntu / Linux (headless VM)

The Linux path is **home-manager only** — no nix-darwin (macOS-only), no kmonad, no
Homebrew/casks. It shares all the `modules/` tool leaves with the mac via
`hosts/linux.nix` → `profiles/headless.nix` → `profiles/base.nix`; it just doesn't pull in
`profiles/darwin.nix` (it gets `profiles/linux.nix` instead), and the brew `profileExtra` in
`modules/zsh.nix` is empty off Darwin. Four flake outputs exist — two arches × two roles — identical apart from the
`system` string and the profile:

- `homeConfigurations."ubuntu-aarch64"` / `."ubuntu-x86_64"` — headless
- `homeConfigurations."ubuntu-aarch64-desktop"` / `."ubuntu-x86_64-desktop"` — headless
  plus the VNC remote desktop

User is `bits`, home `/home/bits`.

### Remote desktop (VNC)

`profiles/remote-desktop.nix` = `linux-desktop.nix` + `modules/vnc.nix`.
`linux-desktop.nix` already includes `headless.nix`, so the layers are:

```text
headless → shared CLI tools
linux-desktop → headless + common desktop apps and one i3 config
remote-desktop → linux-desktop + VNC server/compatibility add-on
```

`modules/vnc.nix` adds TigerVNC, the virtual i3 session, `vnc-start` / `vnc-stop`, and
Ubuntu-specific graphics/font support. It only adds workspace-safe flags to the shared
Chromium declaration; it does not install a second browser. The general apps and i3
config live in the common desktop profile, not in this add-on.

The existing `ubuntu-<arch>-desktop` targets still select this VNC role. `DESKTOP=1` and
its persistent marker in `install_nix.sh` are unchanged; no new target names or installer
flags are needed. Plain `ubuntu-<arch>` targets remain headless. Xvnc is a *virtual* X
server — no display hardware — which is why it suits a headless box.

`vnc-start` drives `Xvnc` directly rather than going through TigerVNC's `vncserver`
wrapper. As of 1.16 that wrapper takes a display and nothing else (options come from a
config file), ignores `~/.vnc/xstartup` entirely, and finds the session through a
hardcoded `/usr/share/xsessions/$name.desktop` — no XDG search path, no home directory.
That directory doesn't exist on the VM and creating it needs root, which would put the
session outside nix. Xvnc accepts every option on the command line, so driving it directly
keeps everything in user space. Nothing is written to `~/.vnc`; TigerVNC 1.16 treats that
as legacy and warns if it merely exists.

Logs and the pidfile live in `~/.local/state/vnc`. `vnc-stop` kills Xvnc, and every client
(i3, terminals, chromium) exits with the display.

Opt in per machine; the choice is sticky via `~/.config/dotfiles/desktop`, so a later
plain re-run won't revert the VM to headless:

```sh
DESKTOP=1 ./install_nix.sh nix     # on the VM; rm ~/.config/dotfiles/desktop to undo
vnc-start                          # brings up :1
```

From the mac:

```sh
ssh -L 5901:localhost:5901 workspace-tausman1    # 5900 + display number
open vnc://localhost:5901
```

The server binds loopback only (`-localhost yes`), so the SSH tunnel is the only way in
and the SSH key is the real authentication. `vnc-stop` kills the session; it otherwise
survives disconnects, tmux-style.

**Password: optional for TigerVNC Viewer, required for macOS Screen Sharing.**
`vnc-start` picks `-SecurityTypes` from whether `~/.config/tigervnc/passwd` exists: absent
→ `None`, present → `VncAuth`. Over the tunnel a password adds little (8 chars, DES,
reversibly stored) and only guards against other local users on that box, so in principle
it's optional.

In practice macOS's built-in Screen Sharing client does **not** support the `None`
security type — it prompts for a password and then cannot connect. If that's your viewer:

```sh
mkdir -p ~/.config/tigervnc
vncpasswd ~/.config/tigervnc/passwd    # max 8 chars; answer "n" to view-only
vnc-stop && vnc-start                  # SecurityTypes is read at Xvnc startup
```

TigerVNC Viewer handles `None` and needs none of this.

Notes: no GPU, so rendering is software (fine for DOM/CSS, sluggish for WebGL and video).
The session runs at 1920x1080 rather than the mac's retina size on purpose — 2x pixels
would quadruple the bandwidth for no gain. The shared i3 default is xterm, which works
without GLX/EGL on both native and virtual displays. Alacritty/Ghostty remain installed,
but their GPU requirements can prevent them from running in the VNC session.

### Do these by hand first

1. **Clone the dotfiles** (public repo, HTTPS — no auth needed yet):
   ```sh
   git clone https://github.com/tausman/dotfiles.git ~/dotfiles
   ```
2. **GitHub auth** — the one mandatory prereq. Uses the `gh` already on the box:
   ```sh
   cd ~/dotfiles && ./install.sh auth
   ```
   Then confirm SSH authenticates as `tausman` (same gotcha as macOS §6):
   ```sh
   ssh -T git@github.com          # want: "Hi tausman!"
   ```
3. **git-config-tool export** — required for the `ddoghq-sandbox/datadog-pi-packages`
   clone in the repo step; without it that clone fails with "Repository not found":
   ```sh
   curl -fsSL https://binaries.ddbuild.io/devtools/apps/git-config-tool/install.sh | sh
   git-config-tool setup --no-signing --no-1password
   ```

### Then run the bootstrap

```sh
cd ~/dotfiles && ./install_nix.sh
```

`install_nix.sh` is idempotent and does the rest hands-off:

1. Installs Nix (Determinate installer) **only if it isn't already present**.
2. `home-manager switch` for this machine's arch (auto-detected from `uname -m`) —
   installs the tools (git, gh, curl, tmux, nvim, jj, rust, go, node, …) and links the
   dotfiles. The nix-managed git/gh/curl/tmux shadow any pre-existing system copies on
   `PATH`, so they become nix-managed with no manual uninstall.
3. Configures the DD repos (`install.sh repos`), Claude plugins, and pi (node from nix,
   no volta).

Open a fresh shell (`exec zsh -l`) afterward so PATH/session vars refresh. Subsequent
config changes: just re-run `./install_nix.sh`, or the switch directly —
`home-manager switch --flake ~/dotfiles/nix-config#ubuntu-<arch>`.

### Notes / current limitations

- **Big monorepos** (`dd-source`, `dd-go`, `dogweb`, `web-ui`) are *not* cloned here —
  `install.sh repos` only configures them if they already exist. Clone them yourself if
  the VM needs them.
- **`web-ui` / `dogweb` setup** is left manual (`./install.sh web-ui|dogweb`): those flows
  are workspace-specific (watchman, volta, `dd-compose`, the localhost cert).
- **Shell-startup noise:** `zshrc/.zshrc` still unconditionally evals `/opt/homebrew`,
  `pyenv`, `rbenv`, and `direnv`. On the VM those binaries are absent, so each prints a
  harmless "not found" to stderr on shell start (non-fatal — the command substitution is
  empty). Deferred as a later dotfiles cleanup.
