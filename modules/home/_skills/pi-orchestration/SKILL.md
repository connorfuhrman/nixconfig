---
name: pi-orchestration
description: How to orchestrate nested sub-agents with allowed_subagents in pi-subagents — opt-in delegation from custom agents, depth limits, hidden children, and the background-worker collect/steer pattern. Use when a subagent itself must delegate work or when designing multi-level agent fan-out.
license: MIT
---

# Nested Sub-agent Orchestration (pi-subagents)

A subagent can itself spawn subagents — but only when explicitly opted in.
This skill covers the opt-in mechanism, the depth/width bounds, and the
orchestrator pattern. Model choice for spawned workers follows the
ability-to-cost policy in the pi-subagents skill — see
[pi-subagents/SKILL.md](../pi-subagents/SKILL.md), "Model-selection policy".

## Opt-in: `allowed_subagents` frontmatter

Nesting is default-off. A custom agent file must declare `allowed_subagents`
for the subagent to receive its own scoped `Agent`, `get_subagent_result`, and
`steer_subagent` tools:

```yaml
---
name: orchestrator
description: Fans out research to nested workers and consolidates results
allowed_subagents: all            # or a comma list: "support-file-finder, support-callsite-tracer"
max_turns: 30                    # width ceiling for fan-out
---
```

- Omitted / empty / `none` / `false` = no nested tools injected at all.
- **Built-in default agents (`general-purpose`, `Explore`, `Plan`) and
  isolated/worktree agents never get nested tools** — write a custom agent file
  (`.pi/agents/<name>.md` or `~/.pi/agent/agents/<name>.md`).
- The allowlist is a **privilege boundary, not a routing hint**: a child runs
  with its own `tools:` / `extensions:` (parent restrictions are NOT
  inherited), so delegation grants the parent the union of what the listed
  agents can do. Pick the list as carefully as `tools:` itself.

Unknown, disabled, or out-of-list nested types are rejected outright (no
fallback agent).

## Depth and width bounds

- `maxSubagentDepth` (in `~/.pi/agent/subagents.json`, or `/agents → Settings →
  Nested depth`) defaults to **2** — main session (0) → subagent (1) → nested
  child (2). Ceiling is 16; `0` or `1` disables nesting entirely. This Nix
  config seeds a depth of **3**.
- Depth bounds how *deep* delegation goes, never how *wide*: a parent's only
  limit on concurrent children is that each spawn costs it a turn — pair
  `allowed_subagents` with `max_turns` for a hard fan-out ceiling.
- An agent already at the depth cap gets no nested tools at all — not even
  `get_subagent_result`, since it can never own a child.
- Nested children **skip `maxConcurrent` slots** — their parent already holds
  one, and queueing a child behind its waiting parent would self-deadlock.
- A child must independently set `allowed_subagents` to delegate again.

## Nested child lifecycle

- Hidden from every top-level surface: no widget, FleetView, `@` mentions,
  `/agents` menu, or top-level lifecycle events. Only their owner may steer
  or collect them (ownership-scoped `get_subagent_result` /
  `steer_subagent`).
- Stopped with their parent: when the parent finishes, is stopped, or ends a
  resumed turn, its nested children are stopped too.
- Token spend rolls up the ancestor chain into every ancestor's totals.
- Transcripts (`.output` files) land in the **root session's** `tasks/`
  directory alongside their ancestors', so nested runs remain inspectable.
- Results ending `stopped`/`aborted`/`steered` are labelled partial, and
  model-scope allowlists (`/agents → Settings → Scope models`) apply to nested
  spawns exactly as to top-level ones. `resume` works for nested agents too.

## Orchestrator pattern

Two levels, both backed by the same three tools:

1. **Primary session as orchestrator**: spawn background workers with
   `run_in_background: true` (collect the returned agent IDs), continue other
   work, collect results with `get_subagent_result({ agent_id, wait })`, and
   redirect a running worker with `steer_subagent({ agent_id, message })` —
   the message lands after the worker's current tool call.
2. **Custom orchestrator agent as recursive fan-out**: define a custom agent
   with `allowed_subagents: all` (or a curated list) and `max_turns`; it
   decomposes its assignment, spawns its own children, consolidates their
   results, and reports one merged answer upward. Nested spend stays
   attributable to it, and its children die with it — no orphans.