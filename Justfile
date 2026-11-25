# Darwin rebuilds: build as your user (git+https flake inputs use your credential
# helper), then register the generation and activate with sudo.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Short hostname (macOS LocalHostName when available).
host := `sh -c 'h=$(scutil --get LocalHostName 2>/dev/null || hostname -s); echo "${h%%.*}"'`

# List recipes (default).
default:
    @just --list

# Non-root darwin system build (pass extra flags to nix build).
build host=host *ARGS:
    nix build ".#darwinConfigurations.{{host}}.system" --out-link result {{ARGS}}

# Depends on build, then registers the system profile and activates.
switch host=host *ARGS: (build host ARGS)
    store_path="$(readlink -f ./result 2>/dev/null || nix path-info ./result)"
    sudo nix-env -p /nix/var/nix/profiles/system --set "$store_path"
    if [[ -x ./result/sw/bin/darwin-rebuild ]]; then
      sudo ./result/sw/bin/darwin-rebuild activate
    elif [[ -x ./result/activate ]]; then
      sudo ./result/activate
    else
      echo "error: no activate entrypoint under ./result" >&2
      exit 1
    fi

check *ARGS:
    nix flake check . {{ARGS}}