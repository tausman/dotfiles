#!/usr/bin/env bash
# Called by the Nix-generated dogbrew-sync command. An explicit prefix lets the
# regression tests use a fake Dogbrew without touching the real installation.
set -euo pipefail

prefix=$1
shift
dogbrew="$prefix/bin/dogbrew"

if [[ ! -x "$dogbrew" ]]; then
  echo "Dogbrew is not installed at $dogbrew. Bootstrap it using the Dogbrew User Guide, then rerun: nix run ~/dotfiles/nix-config#dogbrew" >&2
  exit 1
fi

# Install hooks may invoke other internal CLIs. Prefer Dogbrew while preserving
# the caller's environment on both macOS and Ubuntu.
export PATH="$prefix/bin:$PATH"

# Dogbrew handles installation, updates and repair itself. No local inventory or
# separate upgrade policy: each declared CLI gets its latest allowed release.
for name in "$@"; do
  echo "Installing/updating Dogbrew package: $name" >&2
  "$dogbrew" install "$name"
done
