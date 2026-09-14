---
name: pi-goal
description: How to run long-running autonomous objectives with the /goal command and the goal_complete, goal_wait, and goal_blocked tools from the pi-goal extension. Use when the user starts a goal with /goal or asks for autonomous, multi-turn unattended completion of an objective. Includes the known goal_complete error caveat.
license: MIT
---

# Goal Mode (pi-goal)

Goal mode gives pi one session-scoped objective and lets it continue working
autonomously after each turn settles: pi keeps dispatching continuation
prompts from its idle boundary until the work completes, pauses, waits for an
external event, or hits a safety limit.

## When to use

- `/goal <objective>` — start a goal (e.g. `/goal implement snake game`,
  `/goal --tokens 100k fix the failing test and verify it`).
- Long-running tasks that need many tool cycles without the user driving every
  turn: finishing an implementation, debugging until the bug is verified fixed,
  multi-step refactors with test/lint/typecheck verification.
- `/goal pause` / `/goal resume` / `/goal edit <objective>` / `/goal clear` /
  `/goal status` manage the active goal.

Objectives are capped at 4,000 characters — for longer instructions, put them
in a file and reference the path from the objective.

## Safety limits (defaults)

- **Automatic-work limit**: 25 model responses per epoch, then the goal pauses
  (`paused · automatic limit 25/25`) and awaits review.
- **No-progress guard**: 3 consecutive runs with identical/empty output pause
  the goal.
- **Token budget** (optional, `/goal --tokens 100k`): stops Goal-owned work
  when exhausted. Not a dollar cap.

## The three terminal tools

While a goal is active, the system prompt shows the current `goal_id`. The
tools only accept the exact current goal id — stale ids are rejected.

### `goal_complete({ goal_id, summary })`

Call ONLY when every requirement of the goal is verified — treat completion as
unproven until evidence matches each named deliverable, test, gate, and
invariant. `summary` is the completion evidence (what was done, what verified
it). Paused/blocked/limited goals cannot complete until resumed.

**Known bug (fixed in patched builds)**: pi-goal imported
`stripTerminalSequences` from pi-tui ≥ 0.84, which pi 0.80.10 lacks —
`goal_complete` crashed in the TUI after delivering the result. The nix
package now redirects that import to a polyfill, so current generations
complete cleanly. If the active generation predates the patch and
`goal_complete` errors: attempt it once when the goal is genuinely done;
if it errors, state the completion and its evidence in prose and stop —
do not retry the tool repeatedly.

### `goal_wait({ goal_id, reason, resume_after_ms })`

Call ALONE when progress depends on an external event (a scheduled monitor, a
CI run, a human review). Only after you have ARRANGED a wake source that will
inject a message when external state changes. `resume_after_ms` is an optional
safety deadline (min effective 10,000 ms; prefer minutes). Waiting keeps the
goal active but quiet; any non-Goal message wakes it. Do not use goal_wait for
ordinary unfinished work.

### `goal_blocked({ goal_id, reason, evidence, repeated_turns })`

Only for a true external impasse that has recurred for at least **three
consecutive goal turns** (same blocker, failed resolution attempts documented
in `evidence`). Not for work that is merely difficult, incomplete, uncertain,
or awaiting normal clarification — keep working in those cases.

## States and recovery

Goal states: `active`, `paused`, `blocked`, `usage` (provider limit),
`budget` (token budget exhausted), `waiting`, `complete`. Users recover with
`/goal` (review and continue), `/goal resume`, or `/goal clear`. Direct
non-`/goal` user input reclassifies the in-flight run as manual and resets the
safety epoch.

## Interaction with other modes

Goal mode and Plan mode (`pi-plan-mode`) are mutually exclusive workflows; the
active one holds the workflow mutex and the other refuses to start until it
reaches a terminal state.