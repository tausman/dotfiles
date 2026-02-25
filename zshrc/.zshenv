# Load cargo/rust environment
. "$HOME/.cargo/env"

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Load homebrew shell variables
# Force certain more-secure behaviours from homebrew
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha

if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export HOMEBREW_DIR=/opt/homebrew
    export HOMEBREW_BIN=/opt/homebrew/bin
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
elif [[ "$(uname)" == "Linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
    export HOMEBREW_DIR=/home/linuxbrew/.linuxbrew
    export HOMEBREW_BIN=/home/linuxbrew/.linuxbrew/bin
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    export PATH="~/.local/bin:$PATH"
fi

