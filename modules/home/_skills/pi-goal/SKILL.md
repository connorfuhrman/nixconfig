---
name: pi-goal
description: Pointer for the pi-goal extension (/goal command, goal_complete / goal_wait / goal_blocked tools). Use when the user starts a goal with /goal or wants autonomous multi-turn completion of an objective.
license: MIT
---

# Goal Mode (pi-goal)

Goal mode gives pi one session-scoped objective (`/goal <objective>`) and lets
it continue working autonomously across turns until complete, paused, blocked,
or waiting on an external event. While active, the system prompt shows the
current `goal_id`; the terminal tools (`goal_complete`, `goal_wait`,
`goal_blocked`) only accept that exact id.

**Authoritative documentation**: this machine's packages are Nix store paths —
locate them and read the upstream README rather than guessing semantics:

```sh
jq -r '.packages[]' ~/.pi/agent/settings.json | grep pi-goal
# → <dir>/README.md
```

Everything else — tool schemas, safety limits, states and recovery, the
goal/plan-mode workflow mutex — is documented there and is authoritative over
this skill.
