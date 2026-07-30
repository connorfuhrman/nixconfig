# Work journal — feat/fleet-opencode-nix

High-level status for Connor.  
**Branch:** `feat/fleet-opencode-nix` (from `develop`)  
**Tip:** `73d60a0` — opencode TUI opens successfully  
**Agent handoff (detailed):** `docs/HANDOFF_fleet-opencode-nix.md`

---

## Where we left off (2026-08-02)

opencode is **working again** on mac-mini after a startup crash. Root cause was setting `OPENCODE_CONFIG_DIR` to a **read-only Nix store path**; it must stay under writable `~/.config/opencode`, while immutable config still comes from the store via `OPENCODE_CONFIG` + symlinks.

Session ending here. Next agent should read the handoff doc above.

---

## Timeline

| When | What |
|------|------|
| 2026-08-01 | Place-marker on `develop`; cut `feat/fleet-opencode-nix` |
| 2026-08-01 | Full fleet workstream implemented; `nix flake check` green |
| 2026-08-02 | Store-only `opencode-nix-bundle` (no `nono pull`, no mutable profile) |
| 2026-08-02 | Fixed nono `~/` profile corruption; then fixed CONFIG_DIR crash |
| 2026-08-02 | **You confirmed:** opencode opens |

---

## What’s in this branch (done)

1. **Orchestration** — agents `orchestrator` / `worker-free` / `moe-advisor`; skill; paid OpenRouter allowlist in Nix  
2. **Document review** — Document Comments resolve + CriticMarkup CLI `cm` + skills  
3. **opencode fully Nix-defined** — one store bundle: profile, config, agents, skills, plugins, launcher  
4. **mac-mini linux-builder** — config for `aarch64-linux` + `x86_64-linux` (binfmt); **needs your `darwin-rebuild`** to go live  
5. **mosh** — all systems; server enable on NixOS server (nuc)  
6. **Obsidian plugins** — Document Comments, Track Changes, Remote SSH, Ghostty Terminal (“Ghotty”) via Nix + `obsidian-nix-sync-plugins`  
7. **Docs** — `docs/plans/1password-ssh-workplan.md`, `docs/rfcs/0001-dual-nuc-cluster.md`  
8. **Nimbus sandbox plan** — `docs/plans/nimbus-sandbox-godot-plan.md` (earlier; open margin threads)

---

## What you still need to run

```bash
# Per machine (example: mini)
home-manager switch --flake ~/nixconfig#connorfuhrman@mac-mini
hash -r
opencode   # already confirmed OK once

# Enable live x86_64-linux builder on mini
darwin-rebuild switch --flake ~/nixconfig#mac-mini

# Optional vault plugins
obsidian-nix-sync-plugins ~/nixconfig
```

**Not done by the agent:** git push / PR into `develop`; merge with `hermes-agent`; live x86_64 build test after rebuild; 1Password SSH IdentityAgent module (plan only); dual-NUC implementation (RFC only).

---

## Design notes (short)

- **Config** = Nix store. **State** (sessions, DB, cache, logs) = XDG under home — ephemeral is fine.  
- nono profile is always `--profile /nix/store/…/nono-profile.json` (never let nono rewrite a named home profile with full `~/`).  
- Do **not** grant nono `read: ["~/"]` — breaks sandbox init.  
- “Ghotty” = Ghostty Terminal Obsidian plugin.

---

## Validation already run

- `nix flake check .` (after bundle work)  
- `nix build .#opencode .#cm .#obsidian-plugins .#opencode-orchestration-test`  
- Human: opencode TUI starts  

Re-run check after further edits.
