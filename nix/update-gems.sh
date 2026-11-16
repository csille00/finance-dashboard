#!/usr/bin/env bash
# Regenerates nix/gems/{Gemfile,Gemfile.lock,gemset.nix} from the root Gemfile
# and Gemfile.lock. Run it (`nix run .#update-gems`) after any Gemfile change;
# CI fails the build when the committed files are out of date.
#
# Why the Nix build has its own copy of the lockfile:
#   - The root lockfile pins precompiled platform gems (nokogiri, ffi, ...) and
#     lists no plain `ruby` platform for some of them. bundlerEnv builds every
#     gem from source against Nix libraries, so the copy is re-locked for the
#     `ruby` platform only. Gem versions are unchanged; Bundler only adds the
#     source variants (and mini_portile2, which source nokogiri depends on).
#   - `ruby file: ".ruby-version"` is dropped, because nixpkgs carries a newer
#     patch release of the same Ruby minor than the one pinned there.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
out=nix/gems
mkdir -p "$out"

sed '/^ruby file:/d' Gemfile > "$out/Gemfile"
awk '/^RUBY VERSION/ { skip = 1; next } skip && /^$/ { skip = 0; next } !skip' \
  Gemfile.lock > "$out/Gemfile.lock"

cd "$out"
export BUNDLE_GEMFILE="$PWD/Gemfile"
bundle lock --add-platform ruby >/dev/null
platforms=$(awk '/^PLATFORMS/ { f = 1; next } f && /^$/ { exit } f { print $1 }' Gemfile.lock)
while read -r platform; do
  [ "$platform" = ruby ] || bundle lock --remove-platform "$platform" >/dev/null
done <<< "$platforms"

bundix --lockfile=Gemfile.lock --gemfile=Gemfile --gemset=gemset.nix
echo "Updated $out"
