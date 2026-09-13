#!/usr/bin/env bash
# Evaluate flake checks in separate nix processes.
#
# A single `nix flake check` retains the evaluator heap across every
# configuration. One invocation per check lets the heap drop between
# closures (needed on native mac-mini as well as smaller Linux VMs).
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
  wait_for_linux_builder
fi

system=$(nix eval --raw --impure --expr builtins.currentSystem)

echo "--- :nix: flake apps (${system})"
app_names=$(nix eval --accept-flake-config --raw \
  ".#apps.${system}" \
  --apply 'a: builtins.concatStringsSep "\n" (builtins.attrNames a)')
while IFS= read -r app; do
  [[ -z "${app}" ]] && continue
  echo "checking app ${app}"
  nix eval --accept-flake-config --raw ".#apps.${system}.${app}.program" >/dev/null
done <<< "${app_names}"

echo "--- :nix: flake checks (${system}), one nix process each"
names=$(nix eval --accept-flake-config --raw \
  ".#checks.${system}" \
  --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  echo "--- check ${name}"
  nix build --accept-flake-config --show-trace -L --no-link \
    ".#checks.${system}.${name}"
done <<< "${names}"
