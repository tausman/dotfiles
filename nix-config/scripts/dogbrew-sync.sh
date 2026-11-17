#!/usr/bin/env bash
# Called by the Nix-generated dogbrew-sync command. An explicit prefix lets the
# regression tests use a fake Dogbrew without touching the real installation.
set -euo pipefail

prefix=$1
shift
dogbrew="$prefix/bin/dogbrew"

if [[ ! -x "$dogbrew" ]]; then
  echo "Dogbrew is not installed at $dogbrew. Bootstrap it using the Dogbrew User Guide, then rerun dogbrew-sync." >&2
  exit 1
fi

# Install hooks may invoke other internal CLIs. Do not depend on a login shell
# being present (nix-darwin activation uses sudo, not an interactive shell).
export PATH="$prefix/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Dogbrew handles installation, updates and repair itself. No local inventory or
# separate upgrade policy: each declared CLI gets its latest allowed release.
for name in "$@"; do
  echo "Installing/updating Dogbrew package: $name" >&2
  "$dogbrew" install "$name"
done
