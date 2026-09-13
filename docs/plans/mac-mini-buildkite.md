# Mac mini Buildkite self-hosted compute

Runbook for the Mac mini (`mac-mini`) as Buildkite self-hosted compute: a Darwin
agent plus a Linux agent inside the persistent `linux-builder` NixOS VM.

## Queues (Default cluster)

| Queue | Where jobs run | Use for |
|---|---|---|
| `mac-mini-macos` | macOS (aarch64-darwin) | Native Darwin `nix flake check`, macOS-only work |
| `mac-mini-aarch64-linux` | linux-builder VM (aarch64 Linux) | Native `aarch64-linux` Nix; `x86_64-linux` via qemu-user binfmt on the same VM |

Hosted `linux-small` / `linux-medium` remain for native x86_64 speed and
pipeline upload. Self-hosted steps use **native Nix** — no Docker plugin.

## Cluster agent token

- **Path on host and guest:** `/etc/buildkite-agent/cluster.token`
- **Permissions:** `0600`, root-owned
- **Never** commit the token value or put it in the Nix store
- One cluster-scoped token; each agent selects its queue via `tags.queue`

### 1Password item layout

Store the cluster agent token (prefix `bkct_`) in 1Password — not a personal API
token:

| Property | Value |
|---|---|
| Account | Fuhrmans |
| Vault | Private |
| Item title | Buildkite |
| Field | `credential` (or `password` on a Login item) |

Verify read access before install:

```sh
eval "$(op signin --account Fuhrmans)"
op read --account Fuhrmans "op://Private/Buildkite/credential"
# should print a bkct_… token
```

Install to the host (mac-mini only):

```sh
nix run .#mac-mini-buildkite-install-token
```

## Nix modules

- `modules/darwin/buildkite.nix` — host `services.buildkite-agents.macos`,
  guest `services.buildkite-agents.linux` (merged into `nix.linux-builder.config`),
  `trusted-users`, and launchd `buildkite-token-sync` (scp token into VM)
- `modules/darwin/linux-builder.nix` — persistent VM (`ephemeral = false`),
  sized for agent + Nix store (8 cores, 8 GiB RAM, 124 GiB disk, `maxJobs = 8`)
- Imported from `modules/hosts/mac-mini.nix`

## Bootstrap order

Queues `mac-mini-macos` and `mac-mini-aarch64-linux` already exist on the Default
cluster. Remaining steps on mac-mini:

**One-shot (recommended):**

```sh
cd ~/nixconfig && git pull origin main   # or your feature branch until merged
eval "$(op signin --account Fuhrmans)"
./scripts/mac-mini-buildkite-bootstrap.sh
```

The bootstrap script calls `nix run .#mac-mini-buildkite-install-token` when the
token file is missing, then `darwin-rebuild switch`.

**Token only** (skip darwin-rebuild):

```sh
nix run .#mac-mini-buildkite-install-token
```

**Manual fallback** (if 1Password is unavailable):

1. Create a cluster agent token in Buildkite → Agents → Default cluster → Agent tokens
2. `sudo install -m 600 -o root -g root /path/to/token /etc/buildkite-agent/cluster.token`
3. `sudo darwin-rebuild switch --flake .#mac-mini`
4. Confirm agents connected; token sync copies token into the VM
5. Re-run or trigger nixconfig / t-hex builds on the correct queues

## Git checkout for self-hosted jobs

- **GitHub** (nixconfig, emacs): rely on the Buildkite GitHub app first. If clone
  fails, add a deploy key and store as a cluster secret.
- **t-hex** (Origin `https://origin.cursor.com/git/connor-fuhrman/t-hex.git`):
  use Origin CLI (`origin auth status` / `origin auth login`). Store runtime
  credentials outside the Nix store; hooks read from a host file if needed.

## Pipelines

### nixconfig

`.buildkite/pipeline.yml` includes:

- `flake-check` — hosted `linux-medium` + Docker (existing)
- `flake-check-mac-mini-linux` — queue `mac-mini-aarch64-linux`
- `flake-check-mac-mini-macos` — queue `mac-mini-macos`

### t-hex

Add `flake-check-aarch64` on queue `mac-mini-aarch64-linux` (parallel to hosted
x86 step). Nested virt: do not run NixOS tests requiring KVM inside the VM on
Apple Silicon.

## Podman fallback

Only if `darwin-rebuild switch` fails with “a `aarch64-linux` … is required” or
the ephemeral disk cannot realize the new image. See plan in
`.cursor/plans/mac_mini_buildkite_*.plan.md`. Steady state stays `nix.linux-builder`.

## Validation

Eval gates (from any machine with the flake):

```sh
nix flake check .
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.enable
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.ephemeral
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.tags.queue
nix eval .#apps.aarch64-darwin.mac-mini-buildkite-install-token.program
```

**Done** means Buildkite jobs actually passed on both self-hosted queues — not
eval-only success.
