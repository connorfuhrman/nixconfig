# NUC Buildkite self-hosted compute

Runbook for the Intel NUC (`nuc`) as Buildkite self-hosted compute: one
systemd agent on queue `nuc-linux` with `spawn=2` (two connected agents,
`nuc-linux-1` / `-2`). Native x86_64-linux Nix — no linux-builder VM.

**Concurrency:** `spawn=2` in `extraConfig`, agent name `%hostname-linux-%spawn`
(Buildkite requires `%spawn` when `--spawn` / `spawn=` shares `build-path`).
Stay at 2 until hardware RAM is confirmed; there is no linux-builder VM on
this host so spawn can go higher later. One systemd unit — do not add a
second `services.buildkite-agents.*` entry.

Container / `docker#` on `nuc-linux` (Podman) is a follow-up and is not part
of this landing. Cluster role closures (`nuc-cluster-head` /
`nuc-cluster-worker`) do **not** import this module.

## Queues (Default cluster)

| Queue | Where jobs run | Use for |
|---|---|---|
| `nuc-linux` | NixOS (x86_64-linux) | Native Linux `nix flake check`, x86_64 package builds, NixOS toplevel |
| `mac-mini-macos` | macOS (aarch64-darwin) | Native Darwin jobs (existing) |

Hosted `linux-small` / `linux-medium` remain for pipeline upload and as a
soft-fail backup. Create queue `nuc-linux` on the Default cluster (Agents →
Default cluster → Queues) before the agent can pick up jobs.

## Cluster agent token

- **Path on host:** `/etc/buildkite-agent/cluster.token`
- **Permissions:** `0640`, `root:buildkite-agent-linux` (set by NixOS activation)
- **Never** commit the token value or put it in the Nix store
- Same cluster-scoped token as mac-mini; the NUC agent selects queue
  `nuc-linux` via `tags.queue`

### 1Password item layout

Store the cluster agent token (prefix `bkct_`) in 1Password — not a personal API
token. Headless NUC has no 1Password desktop app; sign in the CLI first.

| Property | Value |
|---|---|
| Account shorthand | `aztec_fuhrmans` (`op account list`) |
| Account email | `connorfuhrman@outlook.com` |
| Account URL | `https://aztec-fuhrmans.1password.com` |
| Vault | `Private` |
| Item title | `Buildkite` |
| Field | `credential` (Password item) or `password` (Login item) |

```sh
eval "$(op signin --account aztec_fuhrmans)"
op read "op://Private/Buildkite/credential" \
  || op read "op://Private/Buildkite/password"
# should print a bkct_… token
```

Install to the host (nuc only):

```sh
nix run .#nuc-buildkite-install-token
```

## Nix modules

- `modules/nixos/buildkite.nix` — host `services.buildkite-agents.linux`
  (`spawn=2`, name `%hostname-linux-%spawn`), `trusted-users`, agent workdir +
  token permissions via activation, Origin `insteadOf` gitconfig + pinned
  `known_hosts`, systemd `GIT_CONFIG_GLOBAL` / `GIT_SSH_COMMAND`
- Imported from `modules/hosts/nuc.nix` only (plain `nuc`, not cluster roles)

All agent setup (user, workdir, token permissions) is handled by NixOS.
**No manual `chgrp`, `chmod`, or `systemctl enable` is required.**

## Bootstrap order

Create queue `nuc-linux` on the Default cluster first. Remaining steps on nuc:

1. Install the cluster agent token (once, if missing):

   ```sh
   eval "$(op signin --account aztec_fuhrmans)"
   nix run .#nuc-buildkite-install-token
   ```

   Origin SSH deploy key (once, if Origin HTTPS checkout fails):

   ```sh
   nix run .#nuc-buildkite-install-origin-ssh
   ```

2. Apply NixOS — this is the only system command needed:

   ```sh
   cd ~/nixconfig && git pull
   sudo nixos-rebuild switch --flake .#nuc
   ```

   Activation creates `/var/lib/buildkite-agent-linux`, fixes token
   permissions, and systemd starts `buildkite-agent-linux`.

3. Confirm **two** agents connected on queue `nuc-linux` in
   Buildkite → Agents → Default cluster (`nuc-linux-1` and `-2`).
   If systemd still looks like a single process, that is expected (`spawn`
   forks inside one unit). Check `spawn=` landed in
   `/var/lib/buildkite-agent-linux/buildkite-agent.cfg` (do not paste the
   token from that file).

**Token-only reinstall** (skip nixos-rebuild if config unchanged):

```sh
nix run .#nuc-buildkite-install-token
sudo nixos-rebuild switch --flake .#nuc   # re-applies permissions + restarts agent
```

Or use the bootstrap script:

```sh
./scripts/nuc-buildkite-bootstrap.sh
```

### Manual token fallback

```sh
eval "$(op signin --account aztec_fuhrmans)"
sudo mkdir -p /etc/buildkite-agent
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
token=$(op read "op://Private/Buildkite/credential" 2>/dev/null) \
  || token=$(op read "op://Private/Buildkite/password" 2>/dev/null) \
  || { echo "op read failed"; exit 1; }
printf '%s' "$token" | tr -d '[:space:]' > "$tmp"
sudo install -m 600 -o root -g root "$tmp" /etc/buildkite-agent/cluster.token
rm -f "$tmp"
trap - EXIT
sudo nixos-rebuild switch --flake .#nuc
```

## Git checkout for self-hosted jobs

- **GitHub** (nixconfig, emacs): rely on the Buildkite GitHub app first. If clone
  fails, add a deploy key and store as a cluster secret.
- **Origin** (t-hex and any `https://origin.cursor.com/git/…` clone): the Linux
  agent rewrites HTTPS to SSH via git `insteadOf` and a **file-based** deploy
  key. Connor’s interactive `origin auth login` does not apply to
  `buildkite-agent-linux`. Do **not** put Origin credentials in pipeline YAML.

| Piece | Value |
|---|---|
| insteadOf | `https://origin.cursor.com/git/` → `git@origin.cursor.com:` |
| SSH clone | `git@origin.cursor.com:connor-fuhrman/t-hex.git` (no `/git/` prefix) |
| Private key | `/var/lib/buildkite-agent-linux/.ssh/origin_cursor` (mode 600, agent-owned; **never** the Nix store or git) |
| Agent gitconfig | `/var/lib/buildkite-agent-linux/.gitconfig` (also `GIT_CONFIG_GLOBAL` on the systemd unit) |

Install (or rotate) the key on nuc. Registers the public key with Origin
(`origin ssh-key add`, title `nuc-buildkite-agent`) and writes gitconfig +
`~/.ssh/config` for the agent. Source order: existing agent key, then optional
1Password item `Buildkite Origin SSH` (private key field), then
`~/.ssh/buildkite-agent-origin` if present, otherwise a new ed25519 key:

```sh
nix run .#nuc-buildkite-install-origin-ssh
```

After install (no nixos-rebuild required for the key itself):

```sh
sudo -u buildkite-agent-linux -H git ls-remote \
  https://origin.cursor.com/git/connor-fuhrman/t-hex.git HEAD
```

Durable copies of gitconfig / ssh_config / known_hosts are also written by
NixOS activation on `nixos-rebuild switch`. Rebuild **is** required for
systemd `GIT_CONFIG_GLOBAL` / `GIT_SSH_COMMAND` (jobs started after the
switch). The private key is never replaced by a rebuild.

## Pipelines

`.buildkite/pipeline.yml` includes:

- `flake-check-hosted-linux-medium` — hosted `linux-medium` + Docker (existing backup)
- `flake-check-mac-mini-macos` / packages / NixOS — existing Darwin queue
- `flake-check-nuc-linux` — queue `nuc-linux` (native x86_64 Nix)
- `build-packages-nuc-linux` — `.#packages.x86_64-linux` only (`NIX_PACKAGE_SYSTEMS`)
- `build-nixos-nuc` — realize the `nuc` toplevel natively

Steps run on `main` and pull requests targeting `main`.

**Apply this branch on the NUC and confirm the agent is connected before
those steps can pass.** Until then, jobs on `nuc-linux` wait for an agent.

## Validation

Eval gates (from any machine with the flake):

```sh
nix flake check .
nix eval .#nixosConfigurations.nuc.config.services.buildkite-agents.linux.tags.queue
nix eval .#nixosConfigurations.nuc.config.services.buildkite-agents.linux.name
nix eval .#nixosConfigurations.nuc.config.services.buildkite-agents.linux.extraConfig
nix eval .#apps.x86_64-linux.nuc-buildkite-install-token.program
nix eval .#apps.x86_64-linux.nuc-buildkite-install-origin-ssh.program
nix eval .#nixosConfigurations.nuc.config.systemd.services.buildkite-agent-linux.environment.GIT_CONFIG_GLOBAL
```

On nuc after `nixos-rebuild switch`:

```sh
systemctl status buildkite-agent-linux --no-pager
sudo journalctl -u buildkite-agent-linux -n 40 --no-pager
```

**Done** means Buildkite jobs actually passed on queue `nuc-linux` — not
eval-only success.
