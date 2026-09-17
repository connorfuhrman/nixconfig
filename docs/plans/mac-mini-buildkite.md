# Mac mini Buildkite self-hosted compute

Runbook for the Mac mini (`mac-mini`) as Buildkite self-hosted compute: one
launchd agent on queue `mac-mini-macos` with `spawn=2` (two connected agents,
`mac-mini-macos-1` / `-2`). Linux Nix builds are offloaded to the persistent
`nix.linux-builder` VM as a remote builder — not a separate CI host.

**Concurrency:** `spawn=2` in `extraConfig`, agent name `%hostname-macos-%spawn`
(Buildkite requires `%spawn` when `--spawn` / `spawn=` shares `build-path`).
Stay at 2: the host is 16 GiB, `nix.linux-builder` is already ~8 GiB, and
Podman Machine is 10 GiB. Higher spawn oversubscribes RAM when jobs use the
builder or containers. One launchd process — do not add a second
`services.buildkite-agents.*` entry.

## Queues (Default cluster)

| Queue | Where jobs run | Use for |
|---|---|---|
| `mac-mini-macos` | macOS (aarch64-darwin) | Native Darwin `nix flake check`, **docker-buildkite-plugin** via Podman Machine, Linux Nix offload through `nix.linux-builder` |

Hosted `linux-small` / `linux-medium` remain for native x86_64 speed and
pipeline upload. Queue `mac-mini-macos` is a general Docker runner: any job
may use `docker#` / `docker run -v $PWD:...` the same way as on Linux. Linux
Nix *without* containers still offloads to `nix.linux-builder`.

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

- `modules/darwin/buildkite.nix` — host `services.buildkite-agents.macos`
  (`spawn=2`, name `%hostname-macos-%spawn`, `dataDir` / user home =
  `/private/var/lib/buildkite-agent-macos`, `build-path` / `plugins-path` =
  `/Users/Shared/buildkite-agent-macos/{builds,plugins}`), `trusted-users`,
  home + checkout dirs + token permissions via `postActivation`,
  Origin `insteadOf` gitconfig + pinned `known_hosts`, launchd
  `GIT_CONFIG_GLOBAL` / `GIT_SSH_COMMAND`, headless `ProcessType = Standard`,
  and launchd kickstart of the macOS agent after activation
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

   Origin SSH deploy key (once, if Origin HTTPS checkout fails):

   ```sh
   nix run .#mac-mini-buildkite-install-origin-ssh
   ```

2. Apply nix-darwin — this is the only system command needed:

   ```sh
   cd ~/nixconfig && git pull
   sudo darwin-rebuild switch --flake .#mac-mini
   ```

   `postActivation` creates `/Users/Shared/buildkite-agent-macos` (`build-path`),
   keeps Origin SSH under the existing home
   `/private/var/lib/buildkite-agent-macos`, fixes token permissions, and
   kickstarts the macOS Buildkite launchd daemon.

3. Confirm **two** agents connected on queue `mac-mini-macos` in
   Buildkite → Agents → Default cluster (`mac-mini-macos-1` and `-2`).
   If launchd still looks like a single process, that is expected (`spawn`
   forks inside one daemon). Check `spawn=` and `bootstrap-script=… --no-job-api`
   landed in `/private/var/lib/buildkite-agent-macos/buildkite-agent.cfg` (do not paste
   the token from that file). After kickstart, `launchctl print
   system/org.nixos.buildkite-agent-macos` should show
   `BUILDKITE_AGENT_NO_JOB_API=true`.

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
- **Origin** (t-hex and any `https://origin.cursor.com/git/…` clone): the Darwin
  agent rewrites HTTPS to SSH via git `insteadOf` and a **file-based** deploy
  key. Connor’s interactive `origin auth login` / keychain does not apply to
  `buildkite-agent-macos`. Do **not** put Origin credentials in pipeline YAML.

| Piece | Value |
|---|---|
| insteadOf | `https://origin.cursor.com/git/` → `git@origin.cursor.com:` |
| SSH clone | `git@origin.cursor.com:connor-fuhrman/t-hex.git` (no `/git/` prefix) |
| Private key | `/private/var/lib/buildkite-agent-macos/.ssh/origin_cursor` (mode 600, agent-owned; **never** the Nix store or git) |
| Agent gitconfig | `/private/var/lib/buildkite-agent-macos/.gitconfig` (also `GIT_CONFIG_GLOBAL` on the launchd job) |

Install (or rotate) the key on mac-mini. Registers the public key with Origin
(`origin ssh-key add`, title `mac-mini-buildkite-agent`) and writes gitconfig +
`~/.ssh/config` for the agent. Source order: existing agent key, then optional
1Password item `Buildkite Origin SSH` (private key field), then
`~/.ssh/buildkite-agent-origin` if present, otherwise a new ed25519 key:

```sh
nix run .#mac-mini-buildkite-install-origin-ssh
```

`sudo -n` is not enough — this prompts for Connor’s password, like the cluster
token installer. After install (no darwin-rebuild required for the key itself):

```sh
sudo -u buildkite-agent-macos -H git ls-remote \
  https://origin.cursor.com/git/connor-fuhrman/t-hex.git HEAD
```

Durable copies of gitconfig / ssh_config / known_hosts are also written by
nix-darwin `postActivation` on `darwin-rebuild switch`. Rebuild **is** required
for launchd `GIT_CONFIG_GLOBAL` / `GIT_SSH_COMMAND` (jobs started after the
switch). The private key is never replaced by a rebuild.

## Pipelines

### nixconfig

`.buildkite/pipeline.yml` includes two sequential steps, both on queue
`mac-mini-macos` (no docker-plugin steps in this pipeline and no hosted queue):

- `flake-check-mac-mini-macos` — native Darwin Nix; evaluates apps + the
  eval-only checks for **every** exported system (aarch64-darwin natively;
  x86_64-linux / aarch64-linux offloaded to `nix.linux-builder`)
- `build-packages-mac-mini-macos` — autodiscover `.#packages` and build
  (`depends_on: flake-check-mac-mini-macos`, so the two eval-heavy steps never
  run concurrently on the 16 GiB host)

The NixOS toplevel realization step (`rpi-cluster-head`) was dropped: every
configuration is still fully *evaluated* by the eval-only checks, just not
*realized* in CI. The queue itself remains a docker runner (Podman) for other
repos — this repo's pipeline simply has no container steps.

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

**One-time setup** if the machine already exists rootless:

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
ls -l /var/run/docker.sock   # root socat listen sock (660, group docker) → Podman API
sudo tail -20 /var/log/podman-machine.log
```

`podman machine init` is **not** automated — launchd ensures rootful mode,
sets machine memory to 10240 MiB, starts the VM, and maintains
`/var/run/docker.sock`. After reboot, the root `org.nixos.podman-machine`
daemon runs without a login session (`RunAtLoad` + `StartInterval`;
`KeepAlive.SuccessfulExit = false` so a finished ensure does not restart-loop).

Agent **home** stays `/private/var/lib/buildkite-agent-macos` (`dataDir`, Origin
SSH, `.gitconfig`). nix-darwin will not change an existing user's home — do
not set `users.users.buildkite-agent-macos.home` to `/Users/Shared/...`.
Agent **checkout** is `/Users/Shared/buildkite-agent-macos` (`build-path` /
`plugins-path`) on the default applehv `/Users` virtiofs share, owned by
`buildkite-agent-macos:docker`. `docker run -v $PWD` works there with no guest
symlink. Darwin `/var` is `/private/var`; put checkout under `/Users`, not
`/var/lib`. Guest `ls`/`umount` of `/private/var/lib/...` hangs that virtiofs
share. Nested virtiofs of the checkout or home is unused (applehv already
shares `/Users`) — launchd ensure **prunes** those extra JSON mounts. Never
umount guest virtiofs shares.

Unix sockets cannot ride virtiofs. docker-buildkite-plugin bind-mounts
`BUILDKITE_AGENT_JOB_API_SOCKET` when that env is set, so Job API is off
agent-wide: `bootstrap-script=… bootstrap --no-job-api` plus launchd
`BUILDKITE_AGENT_NO_JOB_API=true`. `job-api=false` is not an agent-start key.
nix-darwin has no `commandLine` option. Do not rely on step env (the agent
overwrites an empty `BUILDKITE_AGENT_JOB_API_SOCKET`).

Memory is 10240 MiB (host 16 GiB, linux-builder already 8 GiB; a full
`nix flake check` in `nixos/nix` needs ~8 GiB RSS for emacs overlay unpack).
Idle builder pages compress, so a second full 8 GiB VM is unnecessary. Do
not `podman machine set --memory` by hand — rebuild so launchd applies it.

If `podman machine stop` hangs, kill vfkit/gvproxy (`pgrep -lf 'vfkit|gvproxy'`)
then `launchctl kickstart -k system/org.nixos.podman-machine`. Confirm default
shares only (`/Users` `/private` `/var/folders`) and that a bind-mount of the
checkout returns immediately:

```sh
python3 -c 'import json; m=json.load(open("/Users/connorfuhrman/.config/containers/podman/machine/applehv/podman-machine-default.json"))["Mounts"]; print([ (x["Source"], x["Target"]) for x in m ])'
podman machine ssh -- 'ls /Users/Shared/buildkite-agent-macos | head'
podman run --rm -v /Users/Shared/buildkite-agent-macos:/workdir alpine:3.20 ls /workdir
```

## Validation

Eval gates (from any machine with the flake):

```sh
nix flake check .
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.enable
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.tags.queue
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.name
nix eval .#darwinConfigurations.mac-mini.config.users.users.buildkite-agent-macos.home
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.dataDir
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.extraConfig
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.environment.BUILDKITE_AGENT_NO_JOB_API
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.serviceConfig.ProcessType
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.environment.DOCKER_HOST
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.path # includes *-podman-docker-compat-*/bin
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.podman-machine.serviceConfig.KeepAlive
nix eval .#apps.aarch64-darwin.mac-mini-buildkite-install-token.program
nix eval .#apps.aarch64-darwin.mac-mini-buildkite-install-origin-ssh.program
nix eval .#darwinConfigurations.mac-mini.config.launchd.daemons.buildkite-agent-macos.environment.GIT_CONFIG_GLOBAL
```

On mac-mini after `darwin-rebuild switch`:

```sh
sudo launchctl print system/org.nixos.buildkite-agent-macos | grep -E 'state =|last exit'
sudo tail -20 /private/var/lib/buildkite-agent-macos/buildkite-agent.log
```

**Done** means Buildkite jobs actually passed on queue `mac-mini-macos` — not
eval-only success.
