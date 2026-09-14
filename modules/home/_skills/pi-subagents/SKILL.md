---
name: pi-subagents
description: How to spawn and manage sub-agents with the Agent, get_subagent_result, and steer_subagent tools (pi-subagents extension) — tool usage defers to the upstream README; this skill carries the machine-specific model-selection policy. Use when a task should be delegated, parallelized, or researched without polluting the main context.
license: MIT
---

# Sub-agents (pi-subagents)

Sub-agents run in isolated sessions with their own tools, system prompt,
model, and thinking level. Use them to parallelize independent work, protect
the main context window, and delegate research. Delegate when a task genuinely
benefits (heavy research, parallel independent queries, mechanical bulk work)
— not for trivial lookups.

**Authoritative documentation** (tool schemas, built-in agent types,
foreground/background semantics, custom agent files, frontmatter): this
machine's packages are Nix store paths — locate them and read the upstream
README rather than guessing semantics:

```sh
jq -r '.packages[]' ~/.pi/agent/settings.json | grep pi-subagents
# → <dir>/README.md
```

## Model-selection policy (machine-specific, ability-to-cost ratio)

Pick subagent models by **ability-to-cost ratio**: the most efficient model
that can reliably do the task. Most subagent work is mechanical tool-use — do
not pay frontier-model prices for it.

| Task class | Route to |
|---|---|
| Routine tool-use / implementation: file edits, commands, grepping, summarizing, mechanical refactors, codebase exploration | `openrouter/z-ai/glm-5.3-flash` |
| Complex architecture, cross-cutting design, careful technical writing | `openrouter/z-ai/glm-5.3` (or stronger only if genuinely needed) |
| Cheap bulk / parallel smoke tests, throwaway verification runs | Free-tier models, e.g. `openrouter/nvidia/nemotron-3-super-120b-a12b:free` |

Rules:

1. **Prefer GLM over Gemini/Claude at equivalent ability** — same capability
   class, lower cost.
2. **Never route mechanical work to expensive frontier models** (Claude
   Opus/Sonnet-class, GPT-5-class, Gemini Pro-class) unless the task truly
   demands their ability.
3. Read-only research (Explore/Plan-style) and routine implementation spawns
   default to `z-ai/glm-5.3-flash`.
4. Wide parallel fan-outs for cheap bulk checks use free-tier models — cost
   scales with agent count.
5. Pass full `openrouter/...` model IDs.
