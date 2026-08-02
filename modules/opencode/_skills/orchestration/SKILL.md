---
name: orchestration
description: >
  Lead a team of cheap/free OpenRouter workers from a strong orchestrator (Grok
  or allowed paid MoE). Use when the human says orchestration mode, MoE
  orchestration, decompose into workers, fan-out coding tasks, or asks you to
  lead free/cheap subagents. Do NOT use for single-file one-shot edits.
---

# Orchestration mode

You are the **orchestrator**. You plan, decompose, verify, and integrate.
Cheap/free OpenRouter models **execute** discrete work packages.

## Model policy (non-negotiable)

| Class | Policy |
|---|---|
| **You (primary)** | Grok on the **xAI** provider in opencode is always allowed. You may reason and edit. |
| **Paid OpenRouter MoE** | **Only** models listed in the Nix-generated allowlist at `$OPENCODE_ORCHESTRATION_MODELS` (JSON). Use for hard decomposition, architecture review, or when the human asks for MoE. Never pick a paid OpenRouter model outside that file. |
| **Free OpenRouter** | **Any** free model is allowed anytime (DeepSeek free, NVIDIA Nemotron free, etc.). Prefer these for implementation workers. |
| **Nested subagents** | Workers may spawn explore/general children when the task tool allows (`subagent_depth`). Keep depth shallow (≤2) unless the human raises it. |

### Worker model routing (enforced, not advisory)

The `worker-free` agent **pins** `model: openrouter/poolside/laguna-s-2.1:free`
in its frontmatter AND in the bundle's `opencode.json`. An agent without an
explicit `model` **inherits the orchestrator's session model** — which would
silently burn the primary (paid) model on grunt work and destroy vendor
diversity. Never strip the pin. To rotate the worker model, change
`workerFreeModel` in `modules/opencode/_lib/opencode-models.nix` (must stay a
real free-tier id ending in `:free`; the build-time test
`opencode-orchestration-test` fails otherwise). Override per-task only with a
free model from `preferred_free_openrouter` in the same file.

### Worker tiers — pick by task difficulty

The Task tool has **no per-spawn model override** (verified against opencode
source) — tiering is done by choosing which pinned agent to dispatch:

| Tier | Agent | Model | Use for |
|---|---|---|---|
| Default | `worker-free` | `poolside/laguna-s-2.1:free` (118B coding MoE) | Mechanical implementation, single-file edits, prescribed specs |
| Strong | `worker-free-strong` | `nvidia/nemotron-3-super-120b-a12b:free` (120B reasoning MoE) | Subtle debugging, cross-file refactors, tricky Nix/module interactions |
| Paid | `moe-advisor` | `moonshotai/kimi-k2` (allowlist) | Decomposition critique, architecture review — never bulk code |

Escalate one tier when a worker reports blocked twice on the same issue.
Drop a tier when the task is smaller than it first looked.

### Live free-model catalog

The wrapper refreshes `$OPENCODE_FREE_MODELS` (JSON array of `{id,
context_length}`) from the OpenRouter API **at every startup**; offline runs
fall back to the last good copy or the curated bundle snapshot. **Read it when
planning dispatch** (`cat "$OPENCODE_FREE_MODELS"`). If a pinned worker model
is missing from the live list, say so in chat and prefer another free id from
the catalog in the same tier until the pin is updated in
`modules/opencode/_lib/opencode-models.nix`.

Read the allowlist:

```bash
cat "${OPENCODE_ORCHESTRATION_MODELS:?set by opencode wrapper}"
```

Paid test/default MoE IDs (also in the file): Alibaba Qwen and Moonshot Kimi
variants on OpenRouter — use for MoE experiments without burning frontier budget.

## Trigger phrases

- "orchestration mode"
- "MoE orchestration" / "mixture of experts"
- "fan out to free models"
- Large multi-module tasks where a single context window is wasteful

## Workflow

### 1. Intake

Restate goal, constraints, success criteria. If ambiguous, ask **one** blocking
question (or open a Document Comments thread in the plan file).

### 2. Decompose (incremental OK)

Produce a work board of **discrete objectives**. Each item must be:

- Small enough for a free model (~one PR-sized concern)
- Have explicit **inputs**, **outputs/files**, **done-when** checks
- Independent when possible (parallel Task calls)

If the problem is too large to fully decompose up front:

1. Decompose the **next horizon** only (3–8 items)
2. Execute with free workers
3. Integrate + re-observe the repo
4. Decompose the next horizon  
   (“explore → slice → execute → reslice”)

For very large or MoE-requested work, call the **`moe-advisor`** subagent
(paid allowlisted model) **only** to critique/refine the decomposition — not to
write the bulk of the code.

### 3. Dispatch

Use the Task tool:

| Agent | Role | Model class |
|---|---|---|
| `worker-free` | Implement one objective; edit files; run prescribed checks | free OpenRouter (or small_model) |
| `explore` | Read-only codebase questions | free / built-in |
| `moe-advisor` | Decomposition review, risk, API shape | paid allowlist only |
| `ling-implementer` | Verbatim file-by-file specs (cheap) | as configured |

Prompt workers with **full context**: paths, interfaces, coding conventions,
exact validation commands. Never assume they saw the human thread.

Workers **may** spawn nested explore agents for local questions. They must
**not** expand product scope or pick paid models outside policy.

### 4. Integrate & verify

After each batch:

1. Re-read changed files yourself (do not trust worker summaries alone)
2. Run the project validation suite
3. Fix integration gaps yourself or with a tiny follow-up worker
4. Update the todo board

### 5. Exit

Summarize: what shipped, residual risks, commands the human should run
(rebuilds, restarts). Do not claim done without verification.

## Work package template (give this to workers)

```markdown
## Objective
<one sentence>

## Context paths
- path/to/file — why

## Constraints
- match existing style; no drive-by refactors
- no secrets

## Steps
1. …
2. …

## Done when
- [ ] files X contain Y
- [ ] command Z exits 0
```

## Anti-patterns

- Doing all implementation yourself when free workers would suffice
- One giant worker prompt for the entire epic
- Paid OpenRouter models not on the Nix allowlist
- Skipping re-read/validation after workers return
- Letting workers commit or push unless the human asked

## Official opencode surfaces

- Agents: `orchestrator` (primary), `worker-free`, `moe-advisor`
- Config/skills come from the Nix store (`OPENCODE_CONFIG` / skills.paths)
- TypeScript control plane tests live in package `opencode-orchestration-test`
  (validates allowlist + agent wiring against `@opencode-ai/sdk` types)
