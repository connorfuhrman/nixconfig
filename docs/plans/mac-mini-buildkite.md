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
- **Permissions (host):** `0640`, `root:buildkite-agent-macos` (agent user must read the token)
- **Permissions (linux-builder guest):** `0640`, `root:buildkite-agent-linux` (installed by token-sync)
- **Never** commit the token value or put it in the Nix store
- One cluster-scoped token; each agent selects its queue via `tags.queue`

### 1Password item layout

Store the cluster agent token (prefix `bkct_`) in 1Password — not a personal API
token:

| Property | Value |
|---|---|
| Account shorthand | `aztec_fuhrmans` (`op account list`) |
| Account email | `connorfuhrman@outlook.com` |
| Account URL | `https://aztec-fuhrmans.1password.com` |
| Vault | `Private` |
| Item title | `Buildkite` |
| Field | `credential` (Password item) or `password` (Login item) |

Discover layout on mac-mini (readonly — does not print secret values):

```sh
op account list
eval "$(op signin --account aztec_fuhrmans)"   # or omit --account when only one is signed in
op vault list
op item list --vault Private | rg -i buildkite
op item get Buildkite --vault Private --format json \
  | jq '{title, vault, fields: [.fields[] | {id, label, purpose, type}]}'
```

If no Buildkite item exists, create a **Password** item titled `Buildkite` in
vault `Private` and paste the `bkct_…` cluster agent token into the password
field (Buildkite → Agents → Default cluster → Agent tokens).

Verify read access before install (desktop app unlock is enough — no `op whoami` check):

```sh
op read "op://Private/Buildkite/credential" \
  || op read "op://Private/Buildkite/password"
# should print a bkct_… token
# if read fails: eval "$(op signin --account aztec_fuhrmans)"
```

Install to the host (mac-mini only). Both paths use Homebrew `op`
(`/opt/homebrew/bin/op` or `$OP`) and write via `mktemp` + `install -g wheel`
(BSD `install` rejects `/dev/stdin`).

```sh
nix run .#mac-mini-buildkite-install-token
```

After install or if agents show exit 78 / "waiting for agent", fix permissions
and restart launchd (mac-mini only):

```sh
nix run .#mac-mini-buildkite-fix-perms
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
op read "op://Private/Buildkite/credential"   # sanity check (desktop unlock is enough)
./scripts/mac-mini-buildkite-bootstrap.sh
```

The bootstrap script calls `install_cluster_token` (shell `op`, direct `op read`,
`mktemp` + `install -g wheel`) when the file is missing, then `darwin-rebuild switch`.

**Token only** (skip darwin-rebuild):

```sh
nix run .#mac-mini-buildkite-install-token
```

**Manual fallback** (if bootstrap / `nix run` is unavailable):

From 1Password (BSD `install` on macOS does not accept `/dev/stdin` — use a temp file):

```sh
op_bin=${OP:-/opt/homebrew/bin/op}
sudo mkdir -p /etc/buildkite-agent
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null) \
  || token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null) \
  || { echo "op read failed"; exit 1; }
printf '%s' "$token" | tr -d '[:space:]' > "$tmp"
sudo install -m 600 -o root -g wheel "$tmp" /etc/buildkite-agent/cluster.token
rm -f "$tmp"
trap - EXIT
```

Or from a saved token file:

1. Create a cluster agent token in Buildkite → Agents → Default cluster → Agent tokens
2. `sudo mkdir -p /etc/buildkite-agent && sudo install -m 600 -o root -g wheel /path/to/token /etc/buildkite-agent/cluster.token`
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
