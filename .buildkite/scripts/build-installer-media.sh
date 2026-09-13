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

# Copy out of the nix store (result is often a symlink) so hosted Docker steps
# and artifact_paths can see files on the mounted checkout after the step ends.
out_dir="installer-artifacts/${target}"
rm -rf "${out_dir}"
mkdir -p "${out_dir}"
for path in "${artifacts[@]}"; do
  cp -L "${path}" "${out_dir}/$(basename "${path}")"
done

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent artifact upload "${out_dir}/*"
fi

echo "+++ :white_check_mark: ${target} build and artifact upload succeeded"
