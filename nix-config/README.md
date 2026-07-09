# nix-config

Nix-based machine setup. On macOS this is driven by [nix-darwin](https://github.com/nix-darwin/nix-darwin)
(system-level: `darwin.nix`) and [home-manager](https://github.com/nix-community/home-manager)
(user-level), wired together in `flake.nix`.

The home-manager config is layered **modules → profiles → hosts**:

- `modules/` — one leaf per tool (git, zsh, tmux, neovim, jj, claude, dev, alacritty, kmonad, …).
- `profiles/` — bundles: `base.nix` (shared leaves + the `liveLink` helper), `gui.nix`
  (alacritty + kmonad), `desktop.nix` (= base + gui), `headless.nix` (= base).
- `hosts/` — pure identity (username/home) + one profile import: `mac.nix` → `desktop`,
  `linux.nix` → `headless`.

The flake maps each target name to a host file: `default` → `hosts/mac.nix`,
`ubuntu-{aarch64,x86_64}` → `hosts/linux.nix`. Role differences (GUI vs headless) are
expressed by *which profile a host imports* — no `if` branches. The one genuine platform
gate is Homebrew's shellenv, guarded on `pkgs.stdenv.isDarwin` inside `modules/zsh.nix`
(empty on Linux).

On the **headless Ubuntu VM** it's home-manager only (no nix-darwin) and is bootstrapped
by `../install_nix.sh` — see [Ubuntu / Linux (headless VM)](#ubuntu--linux-headless-vm)
at the bottom. The rest of this doc (Parts 1–3, kmonad, etc.) is the macOS flow.

- Flake lives in: `/Users/tausif.rahman/dotfiles/nix-config`
- Both outputs use the `default` target: `darwinConfigurations.default`, `homeConfigurations.default`

**The flow:** do everything you install/build up front (**Part 1**), then apply the
config with two switches (**Part 2**), then a small cleanup (**Part 3**). After Part 2,
everything — dotfiles, packages, Homebrew, and the kmonad + Karabiner launchd daemons —
is live.

> **Status:** living document. Steps marked **TODO** aren't wired into Nix yet.

---

## Part 1 — Prerequisites (install/build everything first)

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

---

## Part 2 — Apply the config (the two switches)

Run **home-manager first** (deploys your user env, including `~/.config/kmonad.kbd`),
**then darwin-rebuild** (system: Homebrew, and the kmonad + Karabiner launchd daemons).
Ordering it this way means the kmonad config already exists when the daemon is created,
so it comes up cleanly.

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
- `modules/kmonad.nix` (imported via `profiles/gui.nix`, so only on the mac) → links
  `~/.config/kmonad.kbd` → `../kmonad/kmonad.kbd`.
- `../kmonad/com.example.kmonad.plist` is a manual-install reference for **non-nix**
  machines only — do not load it here (nix-darwin already manages the daemon).

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
Homebrew/casks, no GUI apps (Alacritty). It shares all the `modules/` tool leaves with the
mac via `hosts/linux.nix` → `profiles/headless.nix` → `profiles/base.nix`; it just doesn't
pull in `profiles/gui.nix`, and the brew `profileExtra` in `modules/zsh.nix` is empty off
Darwin. Two arch-specific flake outputs exist, both mapping to `hosts/linux.nix`, identical
apart from the `system` string:

- `homeConfigurations."ubuntu-aarch64"` — ARM64
- `homeConfigurations."ubuntu-x86_64"` — Intel/AMD

User is `bits`, home `/home/bits`.

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
