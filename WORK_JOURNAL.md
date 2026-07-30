# Work journal — feat/fleet-opencode-nix

High-level progress. Branch: `feat/fleet-opencode-nix` (from `develop`).

| When (UTC) | Status |
|---|---|
| 2026-08-01 | Place-marker on `develop`; branch cut. |
| 2026-08-01 | Implemented full workstream; `nix flake check .` **all passed**. |

## Done

1. **Orchestration** — skill + agents (`orchestrator`, `worker-free`, `moe-advisor`); paid OpenRouter allowlist in Nix (`modules/home/_lib/opencode-models.nix`); MoE test models Moonshot/Qwen; SDK smoke test package `opencode-orchestration-test` **PASS**.
2. **Document review** — Document Comments resolve protocol; CriticMarkup Go CLI `cm`; skill `document-review`.
3. **opencode = Nix store** — `packages.opencode-config` holds config/agents/skills; goal plugin vendored from npm tarball; wrapper sets `OPENCODE_CONFIG` + models path. Sessions/logs still XDG (ephemeral OK).
4. **mac-mini x86_64-linux** — `linux-builder.systems = [ aarch64-linux x86_64-linux ]` + binfmt qemu-user. **Needs `darwin-rebuild` on mini** before live builders advertise x86_64 (current machine still old config).
5. **mosh** — all systems; `programs.mosh.enable` on NixOS server (nuc).
6. **Obsidian** — app already on hosts; plugins pinned (document-comments, track-changes, remote-ssh, ghostty-terminal aka “Ghotty”); `obsidian-nix-sync-plugins`.
7. **1Password SSH** — `docs/plans/1password-ssh-workplan.md`.
8. **Dual-NUC RFC** — `docs/rfcs/0001-dual-nuc-cluster.md` (Thunderbolt IP + Nix builders P0).

## You need to run

```bash
# After merge/switch on each machine:
darwin-rebuild switch --flake .#mac-mini   # enables x86 builder systems
home-manager switch --flake .#connorfuhrman@mac-mini
nono pull nolabs-ai/opencode   # if needed
# restart opencode

# Optional: sync Obsidian plugins into a vault
obsidian-nix-sync-plugins ~/nixconfig
```

## Validation already run

- `nix flake check .` — all 15 checks passed (incl. cm-go-test, opencode-config, skills, homes, darwin/nixos evals).
- `nix build .#cm .#opencode .#opencode-config .#obsidian-plugins .#opencode-orchestration-test`
- Live x86_64 build failed until rebuild: builder still only `aarch64-linux` on running system.

| 2026-08-02 | Store-only opencode-nix-bundle v2; no mutable nono profile; no pack pull. |
