---
name: pi-plan-mode
description: Pointer for the pi-plan-mode extension (/plan command, plan_mode_question and plan_mode_complete tools). Use when the user asks for a plan or a design review before implementation.
license: MIT
---

# Plan Mode (pi-plan-mode)

Plan mode puts exploration and implementation on opposite sides of an explicit
review boundary: the agent explores, asks material questions via
`plan_mode_question`, and submits a decision-ready plan via
`plan_mode_complete`. Plan mode is only active while an explicit Plan contract
is in force.

**Authoritative documentation**: this machine's packages are Nix store paths —
locate them and read the upstream README rather than guessing semantics:

```sh
jq -r '.packages[]' ~/.pi/agent/settings.json | grep plan-mode
# → <dir>/README.md
```

Everything else — commands (`/plan`, `/plan start/show/save/export/implement`),
tool schemas, safety limits — is documented there and is authoritative over
this skill.
