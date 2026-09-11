# Cursor Cloud — first-time Nix home (agents only)

For Cursor coding agents. Not a human README. Human architecture note:
`docs/plans/cursor-cloud-home.md`.

## What this is

Standalone **home-manager** for Cloud Agent VMs (`ubuntu` / `/home/ubuntu`).
No NixOS, no Dockerfile, no `homeManager.standard`, no `homeManager.cursor`
(the Cloud Agent already is Cursor).

Home target: `ubuntu@cursor-cloud`  
App: `nix run .#cursor-cloud-setup`

## This repo (nixconfig)

`.cursor/environment.json` and `.cursor/nix-home.sh` are already committed.
**Do not re-run `init` here.**

- VM **with** Nix: `nix run .#cursor-cloud-setup`
- VM **without** Nix: `.cursor/nix-home.sh` (installs Determinate Nix, then
  the app). Do not `nix run` until `nix` is on PATH.

## Consumer repo (e.g. t-hex) — first time only when asked

```sh
nix run github:connorfuhrman/nixconfig/develop#cursor-cloud-setup -- init --dir <repo>
```

Then commit the generated `.cursor/environment.json` and `.cursor/nix-home.sh`.
`--force` overwrites; `--extra-install '<cmd>'` appends a second `install` line.

Do not write those files into a consumer repo unless the human asked to
configure that repo.

## Flake resolution

1. `$NIXCONFIG_FLAKE` if set
2. `.` when `flake.nix` and `modules/home` exist (this repo)
3. else `github:connorfuhrman/nixconfig/develop`

Consumer `environment.json` must list
`repositoryDependencies: ["github.com/connorfuhrman/nixconfig"]` so Cursor's
GitHub token can fetch the private flake. Escape hatch: `NIXCONFIG_FLAKE` or
nix `extra-access-tokens`.

## After changing Nix modules

`git add` new files (flakes only see tracked files), then `nix eval` /
`nix flake check`. Never `nixos-rebuild`, `darwin-rebuild`, or
`home-manager switch` from a Cloud agent on this repo. Do not trigger a
Cursor environment Build unless the human asked.

## Do not put this procedure in `docs/` or README
