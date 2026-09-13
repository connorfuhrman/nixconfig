# Mac mini Buildkite self-hosted compute

Runbook for the Mac mini (`mac-mini`) as Buildkite self-hosted compute: a single
Darwin agent on queue `mac-mini-macos`. Linux Nix builds are offloaded to the
persistent `nix.linux-builder` VM as a remote builder — not a separate CI host.

## Queues (Default cluster)

| Queue | Where jobs run | Use for |
|---|---|---|
| `mac-mini-macos` | macOS (aarch64-darwin) | Native Darwin `nix flake check`, macOS-only work; can offload `aarch64-linux` / `x86_64-linux` via `nix.linux-builder` when jobs need Linux Nix |

Hosted `linux-small` / `linux-medium` remain for native x86_64 speed and
pipeline upload. Self-hosted steps use **native Nix** — no Docker plugin.

## Linux builds (remote builder, not a CI agent)

`modules/darwin/linux-builder.nix` runs a persistent NixOS VM
(`nix.linux-builder`) that advertises `aarch64-linux` and `x86_64-linux` (via
qemu-user binfmt). When a job runs on the macOS agent and invokes Nix for a
Linux system, Nix dispatches builds to that VM automatically — no Buildkite
agent runs inside the guest.

Other hosts (e.g. `nuc`) use `generic.mac-mini-builder` as a remote builder
client over Tailscale; the macOS agent uses the same VM locally.

## Cluster agent token

- **Path on host:** `/etc/buildkite-agent/cluster.token`
- **Permissions:** `0640`, `root:buildkite-agent-macos` (set by nix-darwin `postActivation`)
- **Never** commit the token value or put it in the Nix store
- One cluster-scoped token; the macOS agent selects queue `mac-mini-macos` via `tags.queue`

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

Install to the host (mac-mini only). Uses Homebrew `op`
(`/opt/homebrew/bin/op` or `$OP`) and writes via `mktemp` + `install`.

```sh
nix run .#mac-mini-buildkite-install-token
```

## Nix modules

- `modules/darwin/buildkite.nix` — host `services.buildkite-agents.macos`,
  `trusted-users`, agent workdir + token permissions via `postActivation`,
  headless `ProcessType = Standard`, and launchd kickstart of the macOS agent
  after activation
- `modules/darwin/linux-builder.nix` — persistent VM (`ephemeral = false`) used
  as a Nix remote builder (not a Buildkite agent host)
- `modules/darwin/podman.nix` — nixpkgs Podman + docker compat + launchd machine
  helper (see **Podman** below)
- Imported from `modules/hosts/mac-mini.nix`

All agent setup (user workdir, token permissions, launchd ProcessType, service
reload) is handled by nix-darwin. **No manual `chgrp`, `chmod`, or
`launchctl kickstart` is required.**

## Bootstrap order

Queue `mac-mini-macos` already exists on the Default cluster. Remaining steps on
mac-mini:

1. Install the cluster agent token (once, if missing):

   ```sh
   nix run .#mac-mini-buildkite-install-token
   ```

2. Apply nix-darwin — this is the only system command needed:

   ```sh
   cd ~/nixconfig && git pull
   sudo darwin-rebuild switch --flake .#mac-mini
   ```

   `postActivation` creates `/var/lib/buildkite-agent-macos`, fixes token
   permissions, and kickstarts the macOS Buildkite launchd daemon.

3. Confirm the agent connected in Buildkite → Agents → Default cluster.

**Token-only reinstall** (skip darwin-rebuild if config unchanged):

```sh
nix run .#mac-mini-buildkite-install-token
sudo darwin-rebuild switch --flake .#mac-mini   # re-applies permissions + kickstarts agent
```

Or use the bootstrap script:

```sh
./scripts/mac-mini-buildkite-bootstrap.sh
```

### Manual token fallback

If `nix run .#mac-mini-buildkite-install-token` is unavailable, write the token
with a temp file (BSD `install` on macOS does not accept `/dev/stdin`):

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
sudo darwin-rebuild switch --flake .#mac-mini
```

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
- `flake-check-mac-mini-macos` — queue `mac-mini-macos`

### t-hex

For Linux Nix work from the macOS agent, rely on `nix.linux-builder` remote
builds rather than a dedicated Linux Buildkite queue.

## Podman (mac-mini-macos Linux containers)

nix-darwin has no `virtualisation.podman` — `modules/darwin/podman.nix` installs
nixpkgs `podman` (vfkit + gvproxy on Apple Silicon), a `docker` → `podman` compat
alias, a **rootful-only** launchd `podman-machine` job (start VM + symlink socket),
and a `docker` group so `buildkite-agent-macos` can reach the socket.

**Rootless Podman is not compatible with Buildkite on this host.** The docker
plugin and agent expect `/var/run/docker.sock` (or `DOCKER_HOST`); rootless mode
puts the API socket under the primary user's `/var/folders/…/T/podman/` temp dir,
which `buildkite-agent-macos` cannot access. Privileged ports and some images
also fail rootless.

**One-time setup** (machine already exists from a rootless trial — no re-init):

```sh
# as connorfuhrman
podman machine stop podman-machine-default
podman machine set --rootful podman-machine-default
sudo darwin-rebuild switch --flake .#mac-mini   # kickstarts podman-machine launchd job
```

If the machine does not exist yet, init rootful once (~500 MiB VM download):

```sh
podman machine init --rootful podman-machine-default
sudo darwin-rebuild switch --flake .#mac-mini
```

Verify:

```sh
podman machine inspect podman-machine-default --format '{{.Rootful}}'   # true
podman machine list
docker run --rm quay.io/podman/hello
ls -l /var/run/docker.sock   # symlink → Podman API socket (ConnectionInfo.PodmanSocket.Path)
sudo tail -20 /var/log/podman-machine.log
```

`podman machine init` is **not** automated — launchd only ensures rootful mode,
starts the VM, and maintains `/var/run/docker.sock`. After reboot, the root
`org.nixos.podman-machine` daemon runs without a login session (`RunAtLoad` +
`StartInterval` + retry on failure).

## Validation

Eval gates (from any machine with the flake):

```sh
nix flake check .
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.enable
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.tags.queue
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.serviceConfig.ProcessType
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.environment.DOCKER_HOST
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.path # includes *-podman-docker-compat-*/bin
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.podman-machine.serviceConfig.KeepAlive
nix eval .#apps.aarch64-darwin.mac-mini-buildkite-install-token.program
```

On mac-mini after `darwin-rebuild switch`:

```sh
sudo launchctl print system/org.nixos.buildkite-agent-macos | grep -E 'state =|last exit'
sudo tail -20 /var/lib/buildkite-agent-macos/buildkite-agent.log
```

**Done** means Buildkite jobs actually passed on queue `mac-mini-macos` — not
eval-only success.
