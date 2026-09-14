---
name: pi-orchestration
description: Nested sub-agent orchestration with pi-subagents (allowed_subagents opt-in, depth bounds, background-worker pattern). Tool mechanics defer to the upstream README; this skill carries the machine-specific depth configuration and cross-references.
license: MIT
---

# Nested Sub-agent Orchestration (pi-subagents)

A subagent can itself spawn subagents — but only when explicitly opted in via
`allowed_subagents` frontmatter in a custom agent file. Model choice for
spawned workers follows the ability-to-cost policy in the
[pi-subagents skill](../pi-subagents/SKILL.md).

**Authoritative documentation** (opt-in mechanics, privilege boundary rules,
depth/width bounds, nested child lifecycle, orchestrator patterns): this
machine's packages are Nix store paths — locate them and read the upstream
README rather than guessing semantics:

```sh
jq -r '.packages[]' ~/.pi/agent/settings.json | grep pi-subagents
# → <dir>/README.md
```

## Machine-specific configuration

- `maxSubagentDepth` lives in `~/.pi/agent/subagents.json` (not
  settings.json). This Nix config seeds it to **3** (seed-if-absent, never
  clobbers user edits) — see the `seedPiSubagentsDepth` activation script in
  the nixconfig repo.
