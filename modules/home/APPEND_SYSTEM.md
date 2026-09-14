# Agent addendum — this machine's pi environment

This file is appended to pi's default system prompt. It is Nix-managed;
edit it in the nixconfig repo (`modules/home/APPEND_SYSTEM.md`), not in
`~/.pi/agent/`.

## Installed extensions

All extensions below are pre-installed and load at startup. For the
authoritative, up-to-date documentation of any of them, read the
`README.md` inside its package directory. Discover the current package
directories with:

```sh
jq -r '.packages[]' ~/.pi/agent/settings.json
```

| Extension | Surface | Use for |
|---|---|---|
| `@narumitw/pi-plan-mode` | `/plan` + `plan_mode_question` / `plan_mode_complete` tools | Interactive planning workflow before implementation |
| `@tintinweb/pi-subagents` | `Agent` tool (spawn/resume/steer subagents) | Delegation, parallel research, context isolation |
| `@narumitw/pi-goal` | `/goal` + `goal_complete` / `goal_blocked` / `goal_wait` tools | Long-running objectives with evidence-based completion |
| `@tintinweb/pi-tasks` | `TaskCreate` / `TaskList` / `TaskGet` / `TaskUpdate` tools | Task/todo tracking for multi-step work |
| `@narumitw/pi-usage` | `/usage` command | Provider quota/balance dashboard |
| `@johnfodero/pi-diff-review` | `/diff` command (TUI) | Interactive diff review with inline comments |
| `@narumitw/pi-worktree` | `/worktree` command (TUI) | Git worktree isolation for parallel work |
| `@narumitw/pi-lsp` | `lsp_diagnostics` / `lsp_fix` tools | Targeted language-server diagnostics; server catalog in the package `docs/` |

The exact feature behavior — flags, frontmatter, limitations — lives in
each package's README, not here. Read it before first serious use of a
feature; do not guess tool semantics.

## Skills

Skills are loaded from the directories listed in `settings.json`:

```sh
jq -r '.skills[]' ~/.pi/agent/settings.json 2>/dev/null
# plus the default: ~/.pi/agent/skills/
```

Skills under the Nix-managed skill directories are setup-specific
workflow glue (e.g. model-routing policy, orchestration conventions)
maintained in the nixconfig repo. They intentionally do not duplicate
extension documentation — when a skill and a package README disagree
about how a feature works, the package README wins.

## Housekeeping

- `~/.pi/agent/settings.json` is Nix-managed — never hand-edit it; it
  is overwritten on rebuild.
- After changing Nix-managed pi resources, restart pi or run `/reload`.
- Project trust: pi asks before loading project-local `.pi/` resources;
  approvals are saved in `~/.pi/agent/trust.json`.
