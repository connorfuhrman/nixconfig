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
out_path=$(nix build --accept-flake-config -L --no-link --print-out-paths "${attr}")
echo "out path: ${out_path}"

mapfile -t artifacts < <(
  find -L "${out_path}" -type f \( -name '*.iso' -o -name '*.img.zst' -o -name '*.img' \) | sort
)

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "+++ :x: no installer media under ${out_path}" >&2
  find -L "${out_path}" -type f >&2 || true
  exit 1
fi

echo "+++ :package: artifacts"
printf '  %s\n' "${artifacts[@]}"

# Copy out of the nix store so hosted Docker steps and artifact_paths can
# see files on the mounted checkout after the container exits.
out_dir="installer-artifacts/${target}"
rm -rf "${out_dir}"
mkdir -p "${out_dir}"
df -h . >&2 || true
for path in "${artifacts[@]}"; do
  dest="${out_dir}/$(basename "${path}")"
  echo "copying ${path} -> ${dest}"
  cp -L "${path}" "${dest}"
done

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent artifact upload "${out_dir}/*"
fi

echo "+++ :white_check_mark: ${target} build and artifact upload succeeded"
