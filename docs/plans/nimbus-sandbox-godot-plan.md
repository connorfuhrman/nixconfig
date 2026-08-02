# Nimbus USV: nono sandbox + Godot Metal path

%% Brainstorm / review plan. Source brief: repo-root `18_SANDBOX_AGENT_BRIEF.md` (copy of nimbus-usv `docs/18_SANDBOX_AGENT_BRIEF.md`). Implementation waits on §6 decisions. %%

Status: **draft — awaiting review**  
Repos: `nimbus-usv` (product) · sandbox profile may touch `nixconfig` nono packaging  
Author: grok · Date: 2026-07-30  
Related brief success IDs: S-A … S-E (GPU multicam readback + agent autonomy)

This note uses [Document Comments](https://community.obsidian.md/plugins/document-comments). Open margin threads are blocking; reply in Obsidian or chat.

---

## 1. Goal

Unblock the Nimbus orchestrator so an OpenCode session under nono can produce **real** Godot 4 multicam evidence:

1. Godot with **macos display driver + Metal** (not headless dummy).
2. `spike_multicam.tscn` ~30s with `readback_ok > 0` and logged `avg_fps` (4×1280×720).
3. Results written under the nimbus repo; re-runnable without a human clicking a GUI each time (S-D), within agreed constraints.
4. No secrets committed; nono profile drafts only (no pack edits, no broad `~/` allow).

**Out of scope:** Nimbus product/RL features, Unity, disabling nono, wide Library grants.

---

## 2. Two problems (do not conflate)

### 2.1 Problem A — nono filesystem

Active profile appears to be **`opencode-nix`** (pack opencode + `~/.local/share/nix` + workdir r/w). Caps grant repo, `/tmp`, opencode XDG, some Library Caches/Logs — **not** `~/Library/Application Support`.

Godot default userdata: `~/Library/Application Support/Godot/...`.

Already used workaround: `HOME=/tmp/nimbus-godot-home` (allowed). Sufficient for S-A **if** every Godot invoke sets it.

Also seen: EPERM on `~/.local/state/nono` (`nono ps` / session state).

### 2.2 Problem B — no Aqua / Metal over SSH

Godot 4.7 nix editor: `--headless` → display driver **headless** → renderer **dummy only** → CPU texture readback fails (`readback_ok=0`).

Orchestrator was **SSH + tmux** (`DISPLAY` empty). Windowed Godot needs a **console GUI session**. nono shims `open`/`BROWSER`; launching Terminal.app from SSH failed.

<!--c:a1b2c3-->Filesystem allow alone does not create Metal windows over SSH.<!--/c:a1b2c3-->
<!--co:a1b2c3 by:grok at:2026-07-30T23:32:34.000Z status:open quote:"Filesystem allow alone does not create Metal windows over SSH."
grok (2026-07-30T23:32:34.000Z): Confirm you agree Problem B is environment/GUI attachment, not another nono path grant. If you disagree, say what path you think unlocks Metal.
-->

---

## 3. Options for A (sandbox FS)

| ID | Approach | Pros | Cons |
|----|----------|------|------|
| A1 | **HOME jail only** — force `HOME=/tmp/...` (or `NIMBUS_GODOT_HOME`); minimal extra profile | Smallest capability surface; matches existing `NimbusClient` | Breaks if any tool ignores HOME |
| A2 | **Narrow allow** `~/Library/Application Support/Godot` (+ maybe `~/.local/state/nono`) on profile `opencode-nimbus-godot` extends `opencode-nix` | Real userdata path; `nono ps` works | Slightly wider FS; parent-path quirks possible |
| A3 | Godot **user-data CLI/env** if binary supports it → project-local or `/tmp` | No Library grant | Must verify on pinned Godot |

Recommendation: **A1 as default + A2 residual** (draft profile for Godot dir and nono state only if diagnostics still EPERM). Never `allow: ["~/Library"]` or `~/`.

<!--c:d4e5f6-->Preferred FS strategy: A1 HOME jail default, A2 only for residual EPERM paths.<!--/c:d4e5f6-->
<!--co:d4e5f6 by:grok at:2026-07-30T23:32:34.000Z status:open quote:"Preferred FS strategy: A1 HOME jail default, A2 only for residual EPERM paths."
grok (2026-07-30T23:32:34.000Z): Approve A1+A2, A2-only, A1-only, or other. If A2, OK to name profile `opencode-nimbus-godot`?
-->

---

## 4. Options for B (GUI / Metal)

| ID | Approach | Pros | Cons |
|----|----------|------|------|
| B1 | **Local console agent** — start OpenCode from Terminal.app on the Mac (not SSH-only) with new profile | Real Aqua + Metal; simplest green S-C | Human starts session on console once (or leaves it up) |
| B2 | **`launchctl asuser $(id -u)`** Godot from SSH | Automatable if it works | Often fails Seatbelt/TCC; nono may still block |
| B3 | **Sidecar job runner** — agent writes `jobs/*.json` under allowed tree; console **LaunchAgent** (outside nono) runs windowed Godot, writes `results/` | Best S-D; sandbox stays tight; agent never needs GUI | One-time LaunchAgent install (nix-darwin friendly on mac-mini) |
| B4 | Trigger file + `launchctl kickstart` fixed spike script | Thinner than full job protocol | Less flexible than B3 |
| B5 | Linux GPU CI (Vulkan headless elsewhere) | CI-friendly | Not ref Mac HW; does not close Mac S1 alone |
| B6 | Screen Sharing + osascript / `open` | Possible in theory | Fragile; nono shims often block |

<!--c:7a8b9c-->Recommended primary path: B3 sidecar; B1 as bootstrap until LaunchAgent exists.<!--/c:7a8b9c-->
<!--co:7a8b9c by:grok at:2026-07-30T23:32:34.000Z status:open quote:"Recommended primary path: B3 sidecar; B1 as bootstrap until LaunchAgent exists."
grok (2026-07-30T23:32:34.000Z): Pick B1 / B2 / B3 / B3+B1 / B5 waiver / other. If B3, is mac-mini console always logged in as connorfuhrman?
-->

### 4.1 Target Godot invocation (windowed Metal)

```bash
cd /Users/connorfuhrman/nimbus-usv
export HOME=/tmp/nimbus-godot-home
mkdir -p "$HOME"
GODOT="${NIMBUS_GODOT:-$(nix build .#godot --print-out-paths --no-link | awk 'END{print}')/bin/godot4}"

NIMBUS_SPIKE_SECONDS=30 \
NIMBUS_SPIKE_FORCE_READBACK=1 \
  "$GODOT" --path godot \
  --display-driver macos \
  --rendering-driver metal \
  res://scenes/spike_multicam.tscn
```

Pass markers: `readback_ok=<N>` with N>0, `avg_fps=…`, `cams=4 res=1280x720`.

---

## 5. Phased plan (after decisions)

### Phase 1 — Profile + HOME (A)

1. Run brief §4 diagnostics; paste into `nimbus-usv/docs/spikes/SANDBOX_DIAG.md`.
2. Draft `~/.config/nono/profile-drafts/opencode-nimbus-godot.json` extending `opencode-nix` only if A2 needed.
3. User: `nono profile promote opencode-nimbus-godot` then `nono run --profile opencode-nimbus-godot -- opencode`.
4. Keep `HOME=/tmp/...` in Nimbus client/scripts as defense-in-depth.

### Phase 2 — GUI path (B)

Implement the chosen B option; document the single supported command path.

If **B3**, sketch:

- Watch dir: e.g. `nimbus-usv/.agent-jobs/` (gitignored) or under `/tmp/nimbus-jobs`.
- Job: `{ "cmd": "multicam-spike", "id": "…", "env": {…} }`.
- Result: `{ "id": "…", "ok": true, "log_tail": "…", "readback_ok": N, "avg_fps": … }`.
- LaunchAgent: runs as console user, **not** inside nono; absolute nix Godot path or `nix run`.
- Agent poll/wait with timeout; never claims S-C without parsing result file.

### Phase 3 — Nimbus wiring (small patches, ≤400 LOC)

1. `tools/run_multicam_spike.sh` — HOME, NIMBUS_*, nix Godot, refuse `--headless` for S1 mode.
2. Docs: `docs/spikes/multicam.md`, `AGENTS.md` — S1 must be windowed macos/Metal.
3. Optional flake `apps.multicam-spike`.
4. Note in `docs/17_ASYNC_STATUS.md`: profile name + start method + S1 command.

### Phase 4 — Handoff checklist

```bash
# Green path (shape depends on B choice)
nono run --profile opencode-nimbus-godot -- bash -lc '
  cd /Users/connorfuhrman/nimbus-usv && ./tools/run_multicam_spike.sh
'
# Expect readback_ok > 0
```

Do not claim full v1 product exit until S-C evidence is real.

---

## 6. Blocking decisions (summary)

| # | Topic | Options |
|---|--------|---------|
| D1 | Problem B framing | Agree split A vs B |
| D2 | FS strategy | A1 / A2 / A1+A2 |
| D3 | GUI strategy | B1 / B2 / B3 / B3+B1 / B5 / other |
| D4 | S-D strictness | Fully unattended from SSH vs human starts console session once per day/boot |
| D5 | Profile packaging | Hand-promoted nono draft only vs also encode in nixconfig `nono-opencode` |
| D6 | Plan status | approved / approved-with-changes / rejected |

<!--c:e1f2a3-->S-D strictness: fully unattended from SSH, or human starts console session once per boot/day is OK.<!--/c:e1f2a3-->
<!--co:e1f2a3 by:grok at:2026-07-30T23:32:34.000Z status:open quote:"S-D strictness: fully unattended from SSH, or human starts console session once per boot/day is OK."
grok (2026-07-30T23:32:34.000Z): Reply unattended-ssh / console-once-ok / other. Drives B3 vs B1 weight.
-->

<!--c:b4c5d6-->Where should opencode-nimbus-godot live long-term: hand promote only, or nixconfig-managed nono profile too?<!--/c:b4c5d6-->
<!--co:b4c5d6 by:grok at:2026-07-30T23:32:34.000Z status:open quote:"Where should opencode-nimbus-godot live long-term: hand promote only, or nixconfig-managed nono profile too?"
grok (2026-07-30T23:32:34.000Z): hand-only / nixconfig / defer-until-green. nixconfig keeps machines in sync; hand-only is faster for P0.
-->

<!--c:f7a8b9-->Plan status: approved / approved-with-changes / rejected.<!--/c:f7a8b9-->
<!--co:f7a8b9 by:grok at:2026-07-30T23:32:34.000Z status:open quote:"Plan status: approved / approved-with-changes / rejected."
grok (2026-07-30T23:32:34.000Z): Resolve when review is done. Implementation waits for approved*.
-->

---

## 7. Explicit non-goals

- Broad `allow: ["~/"]` or full `~/Library` write without justification.
- Disabling nono unless you explicitly order it.
- Claiming headless + `NIMBUS_SPIKE_FORCE_READBACK` can satisfy S-C on this macOS binary.
- Committing API keys or machine serials.

---

## 8. References

| Path | Why |
|------|-----|
| `18_SANDBOX_AGENT_BRIEF.md` (this repo copy) | Full agent brief |
| nimbus-usv `docs/18_SANDBOX_AGENT_BRIEF.md` | Canonical brief |
| `~/.config/opencode/skills/nono-sandbox/SKILL.md` | nono rules |
| nimbus-usv `python/nimbus_usv/client.py` | Godot launch + HOME |
| nimbus-usv `godot/scripts/spike_multicam.gd` | Readback / FPS |
| `modules/home/skills/document-comments/SKILL.md` | This comment format |

---

**End of plan.** Reply in margin threads; then implementation can start.
