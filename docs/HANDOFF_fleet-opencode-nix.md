# Agent handoff: `feat/fleet-opencode-nix`

**Audience:** Next AI agent continuing this monorepo work.  
**Human journal:** repo-root `WORK_JOURNAL.md` (high-level only).  
**Date:** 2026-08-02  
**Branch tip:** `73d60a0` on `feat/fleet-opencode-nix` (branched from `develop` @ `5798303`).  
**Host last used:** mac-mini (`aarch64-darwin`).  
**Not pushed** (as of handoff) — check `git status` / remotes.

---

## 1. Mission context

Large autonomous workstream (user request) covering:

1. Orchestration skill/agents + paid OpenRouter MoE allowlist in Nix  
2. Document Comments + CriticMarkup (`cm`) review loop  
3. **Fully Nix-store-defined opencode** (config/skills/agents/plugins/profile)  
4. mac-mini `x86_64-linux` via linux-builder binfmt  
5. mosh everywhere; server on nuc (+ package on mac-mini server)  
6. Obsidian plugins immutable via Nix  
7. 1Password SSH workplan  
8. Dual-NUC + Thunderbolt RFC  

Plus later fixes for nono profile mutation and opencode startup crash.

---

## 2. Current git state

```
feat/fleet-opencode-nix  73d60a0  fix(opencode): writable OPENCODE_CONFIG_DIR
develop                  5798303  docs: nimbus plan place-marker (ahead of origin by 1)
hermes-agent             90b4a25  separate line of work (Hermes VM) — do not confuse
main                     f8bbc7a
```

**Untracked / dirty (leave alone unless asked):**

- `18_SANDBOX_AGENT_BRIEF.md` (copy of nimbus brief — not part of fleet work)  
- `.obsidian/plugins/`, `.obsidian/user/` (local vault noise)  
- Possible local edits to `.obsidian/community-plugins.json`, `docs/rfcs/0001-dual-nuc-cluster.md`

**Workflow:** work/commit on `develop` or this feature branch; never commit straight to `main`. Prefer `develop` for merges. Primary agent plans; `ling-implementer` for mechanical edits. **Eval only** for system closures (`nix flake check` / `nix eval`) — no `nixos-rebuild` / `darwin-rebuild` / `home-manager` unless human runs them (or explicitly asks). Small package builds OK: `nix build .#opencode`, `.#cm`, etc.

---

## 3. What works now (verified)

| Item | Evidence |
|------|----------|
| `nix flake check .` | Passed after store-bundle work (re-run after your edits) |
| `nix build .#opencode` | Builds `opencode-nix-bundle-2.0.0` |
| Human can open opencode TUI | Confirmed 2026-08-02 after CONFIG_DIR fix |
| Orchestration SDK smoke test | `opencode-orchestration-test` installCheck PASS |
| `cm` CriticMarkup CLI | Builds + unit tests via `checks.cm-go-test` |
| Profile is store path | Wrapper: `nono run --profile $root/nono-profile.json` |
| No `nono pull` required | Profile `extends: ["default"]` with inlined former pack grants |

---

## 4. Architecture (opencode / nono) — **read this before editing**

### Bundle

`modules/home/nono-opencode.nix` → `mkBundleFixed` → `packages.opencode` (`opencode-nix-bundle`).

Store layout:

```
$out/bin/opencode          # launcher
$out/bin/nono, cm, opencode-bin
$out/share/opencode-nix/
  nono-profile.json        # immutable nono policy
  opencode.json            # OPENCODE_CONFIG
  orchestration-models.json
  agent/*.md
  skills/{orchestration,document-comments,document-review,nono-sandbox}/
  plugins/nono-sandbox.ts
```

Sources under `modules/home/` with `_` prefix are **excluded from import-tree** auto-import:

- `_lib/opencode-models.nix` — paid OpenRouter allowlist only  
- `_agents/`, `_skills/`, `_tools/criticmarkup/`, `_plugins/`, `_test/`

### Launcher rules (hard-won)

1. **`--profile /nix/store/.../nono-profile.json`** — never rely on named `~/.config/nono/profiles/opencode-nix.json` (nono rewrote it with `read:["~/"]` → sandbox init refused: overlaps `~/.local/state/nono`).  
2. **Never grant `"~/"` or `~/.local/state/nono`** in profile.  
3. **`OPENCODE_CONFIG`** = store `opencode.json` (immutable).  
4. **`OPENCODE_CONFIG_DIR`** = **writable** `$XDG_CONFIG_HOME/opencode` (default `~/.config/opencode`). Setting it to the store causes:  
   `Error: Unexpected server error`  
5. Launcher creates XDG state dirs and **symlinks** agent/skills/plugins/json into `OPENCODE_CONFIG_DIR` from the bundle.  
6. `--allow-cwd` + `--suppress-save-prompt $HOME` reduce interactive nono prompts.  
7. Ephemeral OK: `~/.cache/opencode`, `~/.local/share/opencode` (db, logs), sessions.  
8. Nested nono (agent inside nono running `opencode`) may log `Snapshot error: .../.local/state/nono/audit` — expected; human Terminal is fine.

### HM module

`flake.modules.homeManager.nono-opencode`:

- `home.packages = [ bundle ]` only  
- activation: state dirs + wipe mutable profile file + discovery symlinks  
- Imported via `homeManager.standard`

### Agents / skills

| Name | Role |
|------|------|
| `orchestrator` | default primary — orchestration mode |
| `worker-free` | free/cheap implementer subagent |
| `moe-advisor` | paid allowlist MoE, edit deny |
| skill `orchestration` | workflow + model policy |
| skill `document-review` | Document Comments resolve + CriticMarkup/`cm` |
| skill `document-comments` | HTML comment thread format |
| skill `nono-sandbox` | vendored pack skill |

Paid models: `modules/home/_lib/opencode-models.nix`. Free OpenRouter + xAI Grok always allowed by policy text.

### CriticMarkup

- Go tool: `modules/home/_tools/criticmarkup/` → `packages.cm` via `modules/home/criticmarkup.nix`  
- Do not also export `packages.cm` from `nono-opencode.nix` (duplicate attr conflict).

---

## 5. Other delivered modules / docs

| Path | Purpose |
|------|---------|
| `modules/darwin/linux-builder.nix` | `systems = [ aarch64-linux x86_64-linux ]` + binfmt |
| `modules/generic/mac-mini-builder.nix` | clients: both systems |
| `modules/generic/mosh.nix` | optional mosh modules |
| `modules/nixos/system.nix` + `server.nix` | mosh client; `programs.mosh.enable` on servers |
| `modules/darwin/system.nix` + `server.nix` | mosh package |
| `modules/home/obsidian-config.nix` | pinned plugins + `obsidian-nix-sync-plugins` |
| `docs/plans/1password-ssh-workplan.md` | 1P SSH agent plan (open DC threads) |
| `docs/rfcs/0001-dual-nuc-cluster.md` | dual NUC + Thunderbolt (open DC threads) |
| `docs/plans/nimbus-sandbox-godot-plan.md` | earlier nimbus sandbox brainstorm (on develop) |
| `scripts/fix-opencode-nix-profile.sh` | legacy recovery; prefer store wrapper now |
| `AGENTS.md` | updated for bundle model |

**Ghotty** = Obsidian plugin **ghostty-terminal** (`lavs9/obsidian-ghostty-terminal`).

---

## 6. Human interaction conventions (standing)

From user + skills (load when relevant):

1. **Document Comments** (Obsidian): human leaves instructions in `<!--c:ID-->` / `<!--co:ID-->` threads. When acted on: **`status:resolved`**, append signed message, **do not delete**.  
2. **Prose edits** for human review: **CriticMarkup** via `cm` / skill `document-review`, logical chunks.  
3. Author tag for this model family: `grok`.  
4. Load `nono-sandbox` skill on EPERM inside nono — never suggest sudo/chmod/FDA.  
5. Load `customize-opencode` when editing opencode config/agents/skills.

---

## 7. Open / incomplete (next agent)

### P0 / ops (human must run)

```bash
# On mac-mini (and other hosts as needed):
home-manager switch --flake ~/nixconfig#connorfuhrman@<host>
darwin-rebuild switch --flake ~/nixconfig#mac-mini   # x86_64 builder live
# optional:
obsidian-nix-sync-plugins ~/nixconfig
```

- Live **x86_64-linux** builder not verified after rebuild (eval only showed config; running machine was still aarch64-only builders).  
- **Push / PR** `feat/fleet-opencode-nix` → `develop` not done.  
- Merge **hermes-agent** vs this branch is unresolved (separate histories).

### P1 product gaps

- Live **MoE orchestration** end-to-end with real Task/subagent fan-out not exercised in production session.  
- `@opencode-ai/sdk` test validates package metadata + allowlist, **not** a live API session (deps not fully vendored).  
- 1Password SSH: plan only; no IdentityAgent HM module shipped yet (open threads in plan).  
- Dual-NUC: RFC only; no `nuc2` host module.  
- Obsidian plugins: Nix packages + sync script; human may still need Community Plugins enabled once per vault.  
- `default_agent = orchestrator` — confirm human likes that vs `build`.  
- Goal plugin + nono-sandbox plugin load paths: store `file://` — watch for plugin install side effects under `~/.cache/opencode`.

### P2 polish

- Remove obsolete commits noise / squash optional.  
- `packages.cm` only from criticmarkup.nix — keep it that way.  
- Nested-nono audit snapshot noise if agents spawn `opencode` inside nono.  
- Consider vendoring full SDK node_modules if stronger TS tests required.

### Do not regress

- Writable `OPENCODE_CONFIG_DIR`  
- Store absolute `--profile`  
- No full-home filesystem grants  
- Dendritic pattern: no relative module imports; no specialArgs  
- Unfree predicates once per config (obsidian already on onepassword lists)

---

## 8. Validation commands

```bash
cd ~/nixconfig
git checkout feat/fleet-opencode-nix
nix flake check .
nix build .#opencode .#cm .#obsidian-plugins .#opencode-orchestration-test
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.systems
# expect: [ "aarch64-linux" "x86_64-linux" ]
nix eval .#nixosConfigurations.nuc.config.programs.mosh.enable  # true
# After human darwin-rebuild, try:
# nix build .#packages.x86_64-linux.cm
```

Smoke opencode (human Terminal):

```bash
hash -r
opencode --version
opencode   # TUI should open; no "Unexpected server error"
```

---

## 9. Key failure log (for debugging)

| Symptom | Cause | Fix |
|---------|--------|-----|
| `Refusing to grant '/Users/...' overlaps .../.local/state/nono` | Profile had `read:["~/"]` | Store profile; never grant `~/` |
| `Unexpected server error` on TUI start | `OPENCODE_CONFIG_DIR` = nix store | Writable `~/.config/opencode` + store `OPENCODE_CONFIG` |
| nono auto-updates named profile | `--profile opencode-nix` by name | `--profile /nix/store/...json` |
| Nested Snapshot error on audit path | Outer nono blocks nono state | Ignore when nested; OK on bare Terminal |
| `packages.cm` defined multiple times | dual perSystem | Only criticmarkup.nix exports `cm` |

---

## 10. Suggested first steps for next agent

1. `git status` / `git log feat/fleet-opencode-nix --oneline -20`  
2. Read `WORK_JOURNAL.md` + this file  
3. Ask human what they want next: PR to develop, darwin-rebuild x86 test, 1P SSH module, nimbus sandbox plan, hermes merge, etc.  
4. Re-run `nix flake check .` before claiming green  
5. Do not force-push; do not commit secrets/`firmware/`

---

**End of handoff.** Human-facing summary lives in `WORK_JOURNAL.md`.
