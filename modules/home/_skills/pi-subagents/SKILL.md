---
name: pi-subagents
description: How to spawn and manage sub-agents with the Agent, get_subagent_result, and steer_subagent tools from the pi-subagents extension, including the model-selection policy for picking subagent models by ability-to-cost ratio. Use when a task should be delegated, parallelized, or researched without polluting the main context.
license: MIT
---

# Sub-agents (pi-subagents)

Sub-agents run in isolated sessions with their own tools, system prompt,
model, and thinking level. Use them to parallelize independent work, protect
the main context window from excessive results, and delegate research.

## The Agent tool

```
Agent({
  subagent_type: "Explore",            // required: general-purpose, Explore, Plan, or custom
  prompt: "Find all files that handle authentication",
  description: "Find auth files",      // required: short 3-5 word summary
  model: "openrouter/z-ai/glm-5.3-flash",  // optional: per-spawn model (agent frontmatter pins win over this)
  run_in_background: true,             // optional: detach, get ID, notified on completion
  max_turns: 30,                       // optional
  name: "auth-audit",                  // optional: addressable as @auth-audit
  inherit_context: false,              // optional: fork parent conversation
  resume: "<agent-id>",                // optional: resume a previous session
})
```

Built-in types:

| Type | Tools | Role |
|------|-------|------|
| `general-purpose` | all | Parent twin — inherits the parent's full system prompt |
| `Explore` | read, bash, grep, find, ls | Fast read-only codebase exploration |
| `Plan` | read, bash, grep, find, ls | Read-only implementation planning |

Note: if an agent's frontmatter pins `model`, the frontmatter is authoritative
— the `model` parameter only fills fields the agent config leaves unspecified.

## Foreground vs background

- **Foreground** (default): blocks until done, result returned inline. Use for
  a single decisive result the next step depends on.
- **Background** (`run_in_background: true`): returns an agent ID
  immediately; a completion notification arrives later. Default concurrency
  limit is 4; excess agents queue. Use for parallel independent tasks.

Results: `get_subagent_result({ agent_id, wait, verbose })` checks status or
waits for a background agent. Redirection mid-run:
`steer_subagent({ agent_id, message })` injects a message that interrupts
after the agent's current tool call.

Do not spawn subagents excessively: delegate when a task genuinely benefits
(heavy research, parallel independent queries, mechanical bulk work) — not for
trivial lookups.

## Model-selection policy (ability-to-cost ratio)

Pick subagent models by **ability-to-cost ratio**: use the most efficient
model that can reliably do the task. Most subagent work is mechanical
tool-use — do not pay frontier-model prices for it.

| Task class | Route to |
|---|---|
| Routine tool-use / implementation: file edits, running commands, grepping, summarizing, mechanical refactors, codebase exploration | `openrouter/z-ai/glm-5.3-flash` |
| Complex architecture, cross-cutting design, careful technical writing | `openrouter/z-ai/glm-5.3` (or stronger only if the task genuinely needs it) |
| Cheap bulk / parallel smoke tests, throwaway verification runs | Free NVIDIA models, e.g. `openrouter/nvidia/nemotron-3-super-120b-a12b:free` |

Rules:

1. **Prefer GLM over Gemini/Claude at equivalent ability** — GLM is the
   cheaper model of the same capability class.
2. **Never route mechanical work to expensive frontier models** (Claude
   Opus/Sonnet-class, GPT-5-class, Gemini Pro-class) unless the task truly
   demands their ability.
3. Explore/Plan-style read-only research and routine implementation spawn
   should default to `z-ai/glm-5.3-flash`.
4. When fanning out many parallel agents for cheap bulk checks, prefer the
   free-tier models — cost scales with agent count.
5. Model names resolve tolerantly (fuzzy `provider/modelId` matching with
   provider fallback), but pass full `openrouter/...` IDs to be safe.

## Custom agent types

Define agents as Markdown files with YAML frontmatter in
`.pi/agents/<name>.md` (project) or `~/.pi/agent/agents/<name>.md` (global).
Frontmatter fields include `tools`, `model`, `thinking`, `max_turns`,
`prompt_mode`, `allowed_subagents`, and more; the body is the system prompt
(`replace` mode) or appended to the parent's (`append` mode).

## Interaction with other modes

Plan mode (`pi-plan-mode`) and Goal mode (`pi-goal`) are mutually exclusive
workflows — while one holds the workflow mutex, the other refuses to start.