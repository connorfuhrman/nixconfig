# Cursor Cloud home (human)

Standalone home-manager for Cursor Cloud Agent VMs. Not NixOS: those VMs are
Ubuntu this repo does not own. The home is `ubuntu@cursor-cloud` (`x86_64-linux`,
user `ubuntu`): `base` + `coreutils` + `emacs` only.

The flake app is `cursor-cloud-setup`. Agent first-time setup lives in
[`.cursor/AGENTS.md`](../../.cursor/AGENTS.md), not here.

Status: experimental (`flake.hostStatus.cursor-cloud`).
