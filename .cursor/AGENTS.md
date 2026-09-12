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
- VM **without** Nix: `.cursor/nix-home.sh` (installs Determinate Nix, waits
  until `nix-daemon` accepts connections, then the app). Do not `nix run`
  until `nix` is on PATH and the daemon is up. The installer returning
  success is not enough — a following `nix` as `ubuntu` fails with
  `big-lock: Permission denied` if the daemon is not listening yet.

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

## CI (Buildkite)

The [nixconfig](https://buildkite.com/connor-m-fuhrman/nixconfig) pipeline
runs on PRs and pushes to `develop` / `main`:

| Step | What it checks |
| --- | --- |
| `flake-check` | `nix flake check` (eval-only) |
| `cursor-env-schema` | `.cursor/environment.json` vs Cursor public schema |
| `cursor-closure` | `nix build` of `ubuntu@cursor-cloud.activationPackage` and `cursor-cloud-setup` |
| `cursor-env-build` | Cloud Agent requests a **draft** environment Build of the commit SHA |

The merge gate is GitHub check `buildkite/nixconfig` (all steps green). After
the first green run on `develop` / `main`, require that check in branch
protection.

**Secrets:** store `CURSOR_API_KEY` (Cursor Dashboard → API Keys) as a
Buildkite cluster secret on the Default cluster. Confirm the team has Cursor
Cloud MCP enabled.

Agents in normal development should **not** trigger environment Builds; CI
owns that path via `.buildkite/scripts/cursor-env-build.sh` and
`.buildkite/prompts/cursor-env-build.md`.

## Do not put this procedure in `docs/` or README
