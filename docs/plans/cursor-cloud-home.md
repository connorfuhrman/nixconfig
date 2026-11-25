# Cursor Cloud home (human)

Standalone home-manager for Cursor Cloud Agent VMs. Not NixOS: those VMs are
Ubuntu this repo does not own. The home is `ubuntu@cursor-cloud` (`x86_64-linux`,
user `ubuntu`): `base` + `coreutils` + `emacs` only.

The flake app is `cursor-cloud-setup`. Agent first-time setup lives in
[`.cursor/AGENTS.md`](../../.cursor/AGENTS.md), not here.

## Nix bootstrap (Determinate, no systemd)

Cursor Cloud VMs are plain Ubuntu without systemd. `pkgs/cursor-cloud/nix-home.sh`
(and the committed `.cursor/` copy) installs Determinate Nix with
`install linux --init none --no-confirm` when `systemctl` is absent; otherwise
`install linux --no-confirm`. It sources `nix-daemon.sh`, ensures the store
responds to `nix store ping` (removing a stale daemon socket when needed, then
starting `nix-daemon` manually), and runs `cursor-cloud-setup`. Templates set
`environment.json` **`start`** to `.cursor/nix-home.sh start-daemon` so each
snapshot boot revives the daemon before work.

Status: experimental (`flake.hostStatus.cursor-cloud`).
