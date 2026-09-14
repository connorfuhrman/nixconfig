---
name: pi-plan-mode
description: How to use the /plan command and plan-mode tools (plan_mode_question, plan_mode_complete) from the pi-plan-mode extension. Use when the user asks for a plan, wants to plan before code changes, says /plan, or when a multi-file or risky change should be designed and approved before implementation.
license: MIT
---

# Plan Mode (pi-plan-mode)

Plan mode puts exploration and implementation on opposite sides of an explicit
review boundary: the agent explores the codebase, asks material questions, and
submits a decision-ready plan; the user reviews it and chooses how (or
whether) to implement.

## When to use

- The user asks to plan, design, or review before making changes.
- A change touches multiple files, has architectural implications, or is risky
  to get wrong.
- The user runs `/plan` or asks for an implementation plan.

Do NOT use plan mode for ordinary TODO/progress tracking, roadmaps, or
checklists — `update_plan` and prose are fine for those. Plan mode is only
active while an explicit Plan contract is in force.

## Starting and controlling

- `/plan <prompt>` — enter Plan mode and start planning with the prompt.
- `/plan start` — enter Plan mode without sending a message.
- `/plan` — state-aware menu (start, review ready plan, implement, save,
  export, settings).
- `/plan show`, `/plan save`, `/plan export [path]`, `/plan implement`,
  `/plan exit` (alias `off`) — direct routes.

## What Plan mode changes

While active, Plan mode blocks mutation tools (`edit`, `write`) and unsafe
shell forms. Only safe inspection remains: `read`, `grep`, `find`, `ls`, and a
fail-closed limited `bash` (inspection commands, read-only git/npm queries,
tests/typechecks like `npm test`, `cargo test`). Redirects, shell expansions,
subshells, and mutating commands are rejected.

## The two helper tools

### `plan_mode_question`

Ask 1–3 structured questions ONLY when a preference or tradeoff materially
changes the plan. Each question: one sentence, 2–4 mutually exclusive options
(recommended first), plus the implicit free-form "Other" path. Never use it
for ordinary clarification outside Plan mode.

### `plan_mode_complete`

Call it ALONE, as your FINAL action, with the complete Markdown plan
(`plan_mode_complete({ plan })`). Requirements:

- Empty or whitespace-only plans are rejected; max 50,000 characters.
- Only call it after discoverable facts are resolved and high-impact user
  decisions are made.
- Do not batch it with other tool calls — the completion call must be
  standalone and last.
- Never infer completion from prose ("I will present the plan"); only the
  explicit `plan_mode_complete` call ends planning.

## After completion

The user reviews the ready plan and picks a handoff:

- **Implement here** — implementation starts in the current session, planning
  context retained.
- **Start fresh and implement** — a fresh session receives the approved plan
  (optionally a different model/thinking level).
- **Save** — one plan saved in the session for later (`plan saved`).
- **Export** — write the plan to Markdown (default `PLAN.md`, never
  overwrites).

Revision feedback starts another planning turn; a clarification-only follow-up
should be answered and the unchanged complete plan resubmitted.

## Interaction with other modes

Plan mode and Goal mode (`pi-goal`) are mutually exclusive workflows; the
active one holds the workflow mutex and the other refuses to start while it is
running.