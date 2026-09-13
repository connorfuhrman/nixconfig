#!/usr/bin/env bash
# Realize generic installer boot media and upload artifacts to Buildkite.
# Usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>
set -euo pipefail

target="${1:?usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>}"

case "${target}" in
  iso)
    attr=".#iso"
    ;;
  asahi-iso)
    attr=".#asahi-iso"
    ;;
  rpi-iso)
    attr=".#rpi-iso"
    ;;
  *)
    echo "unknown installer target: ${target}" >&2
    exit 1
    ;;
esac

echo "--- :nix: build ${attr}"
nix build --accept-flake-config -L -o result "${attr}"

mapfile -t artifacts < <(
  find result -type f \( -name '*.iso' -o -name '*.img.zst' \) | sort
)

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "+++ :x: no *.iso or *.img.zst under result/" >&2
  find result -type f >&2 || true
  exit 1
fi

echo "+++ :package: artifacts"
printf '  %s\n' "${artifacts[@]}"

for path in "${artifacts[@]}"; do
  buildkite-agent artifact upload "${path}"
done

echo "+++ :white_check_mark: ${target} build and artifact upload succeeded"
