#!/usr/bin/env bash
# Run flake-check inside nixos/nix via Podman/Docker without Darwin bind-mounts.
# Podman Machine cannot statfs host paths, so docker-buildkite-plugin's
# `-v $PWD:/workdir` fails; copy the checkout into the Linux VM instead.
set -euo pipefail

IMAGE="${NIX_CONTAINER_IMAGE:-nixos/nix:2.28.2}"
WORKDIR="/workdir"
cid=""

cleanup() {
  local rc=$?
  if [[ -n "${cid:-}" ]]; then
    docker rm -f "$cid" >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

echo "--- :docker: pull ${IMAGE}"
docker pull "$IMAGE"

echo "--- :docker: create container"
# Same NIX_CONFIG the docker plugin previously injected; flake-check.sh is
# unchanged (nix flake check --accept-flake-config --show-trace -L).
cid=$(docker create \
  --workdir "$WORKDIR" \
  --entrypoint bash \
  --env "NIX_CONFIG=experimental-features = nix-command flakes" \
  "$IMAGE" \
  .buildkite/scripts/flake-check.sh)
echo "container ${cid}"

echo "--- :docker: copy checkout into ${WORKDIR}"
docker cp "${PWD}/." "${cid}:${WORKDIR}"

echo "--- :docker: start (attach)"
docker start -a "$cid"
