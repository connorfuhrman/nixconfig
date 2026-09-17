#!/usr/bin/env bash
# Evaluate flake checks for EVERY system the flake exports (not just the
# host's), in separate nix processes.
#
# A single `nix flake check` retains the evaluator heap across every
# configuration. The Podman Machine guest is 10 GiB with no swap, and a
# full eval of this flake (emacs overlay unpack) needs ~8 GiB RSS. One
# invocation per check lets the heap drop between closures.
#
# Systems other than the host's (aarch64-darwin on mac-mini) offload their
# trivial per-check derivations to nix.linux-builder (x86_64-linux via
# qemu-user binfmt), so this restores x86_64-linux eval coverage and adds
# aarch64-linux coverage at near-zero cost.
set -euo pipefail

echo "--- :nix: flake apps (all systems)"
app_systems=$(nix eval --accept-flake-config --raw \
  ".#apps" \
  --apply 'a: builtins.concatStringsSep "\n" (builtins.attrNames a)') || app_systems=""
while IFS= read -r system; do
  [[ -z "${system}" ]] && continue
  app_names=$(nix eval --accept-flake-config --raw \
    ".#apps.${system}" \
    --apply 'a: builtins.concatStringsSep "\n" (builtins.attrNames a)')
  while IFS= read -r app; do
    [[ -z "${app}" ]] && continue
    echo "checking app ${system}.${app}"
    nix eval --accept-flake-config --raw ".#apps.${system}.${app}.program" >/dev/null
  done <<< "${app_names}"
done <<< "${app_systems}"

echo "--- :nix: flake checks (all systems), one nix process each"
systems=$(nix eval --accept-flake-config --raw \
  ".#checks" \
  --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
while IFS= read -r system; do
  [[ -z "${system}" ]] && continue
  names=$(nix eval --accept-flake-config --raw \
    ".#checks.${system}" \
    --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    echo "--- check ${system}.${name}"
    nix build --accept-flake-config --show-trace -L --no-link \
      ".#checks.${system}.${name}"
  done <<< "${names}"
done <<< "${systems}"
