# Load cargo/rust environment (rustup's ~/.cargo/env — only exists on the rustup/stow
# box; nix installs cargo on PATH directly, so source it only if present).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# On nix-managed machines, programs.nnn (nix-config/modules/core.nix) bakes NNN_PLUG into
# the wrapped nnn binary itself, with plugins fetched declaratively — no export needed here.
# Non-nix machines (install.sh + brew) still rely on `getplugs` + this export.
[ -e "$HOME/.nix-profile/bin/nnn" ] || export NNN_PLUG='z:fzcd;o:fzopen'

# Load homebrew shell variables
# Force certain more-secure behaviours from homebrew
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

if [[ "$(uname)" == "Darwin" && -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    export HOMEBREW_DIR=/opt/homebrew
    export HOMEBREW_BIN=/opt/homebrew/bin
fi

# Also needed by non-interactive shells (e.g. tmux run-shell). The static hook
# orders shims/bin before bin and exposes completions without launching Dogbrew.
[ -f "/opt/dogbrew/share/etc/dogbrew/init.zsh" ] && . "/opt/dogbrew/share/etc/dogbrew/init.zsh"
