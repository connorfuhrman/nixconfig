---
title: How Hermes stores memory and runtime files
author: grok
date: 2026-08-25
status: research
---

# How Hermes stores memory and runtime files

This is how **upstream Hermes** writes state, plus how **this flake** scopes it per bot. Every write happens inside Nono, under `~/.hermes` only.

## One home per agent

A profile **is** a Hermes home. `hermes -p food` sets `HERMES_HOME=~/.hermes/profiles/food`. Config, memory, sessions, skills, and `state.db` all resolve through that variable. Two processes must not share one home: both auto-write memory and each loads the other's entries next session.

| Process | `HERMES_HOME` |
|---|---|
| `concierge` | `~/.hermes/profiles/concierge` |
| `food` | `~/.hermes/profiles/food` |
| `travel` | `~/.hermes/profiles/travel` |
| `hermes-tutor` | `~/.hermes/profiles/hermes-tutor` |
| bare `hermes` (unused front door) | `~/.hermes` |

Shared hand-off only: `~/.hermes/shared/trip-context.json` and `CONVENTIONS.md` (Nono allows the whole `~/.hermes` tree).

## Built-in memory (the curated prompt)

Two small markdown stores, injected **once** at session start (frozen so the prefix cache stays warm):

| File | Role | Default cap |
|---|---|---|
| `$HERMES_HOME/memories/MEMORY.md` | Agent notes (env, lessons, completed work) | 2,200 chars |
| `$HERMES_HOME/memories/USER.md` | User prefs / style | 1,375 chars |

The model does **not** edit those files by path as its primary API. It calls the `memory` tool:

- `add` — new entry
- `replace` / `remove` — substring match on `old_text`

Writes hit disk immediately. They do **not** appear in the current system prompt; the next session reloads the snapshot. Exact duplicates are rejected. Overflow returns an error (no silent truncate); the agent must consolidate in the same turn. Entries are scanned for injection / exfiltration before accept.

After a turn, a **background review** may add more memory or patch a skill (`💾 Memory updated`). Optional `memory.write_approval: true` stages writes for `/memory pending` instead.

This flake seeds `MEMORY.md` **if missing** (HM never overwrites it). `USER.md` is created by Hermes on first profile write.

## Extra durable stores in this fleet

These are ordinary files the SOUL/skill tells the agent to maintain with file tools — **not** the `memory` tool:

| Path | Owner | What |
|---|---|---|
| `profiles/food/data/restaurants.json` | `food` | Structured likes/dislikes, rounds |
| `shared/trip-context.json` | `concierge` writes; specialists read | `trip-context.v1` hand-off |

Restaurant feedback must update **both** the JSON store and `food`'s `MEMORY.md`. Chat transcript is not canonical.

## Everything else on disk while running

All under that profile's `HERMES_HOME` unless noted:

| Path | Kind | Who writes |
|---|---|---|
| `config.yaml` | Model, tools, memory limits | Seeded once; `hermes config set` / agent |
| `.env` | Secrets (bot tokens, optional `XAI_API_KEY`) | You / `hermes config set` |
| `auth.json` | SuperGrok OAuth tokens | `hermes auth add xai-oauth` |
| `SOUL.md` / `profile.yaml` | Persona (flake-managed) | HM activation **always** refreshes from the store |
| `skills/` | Bundled + agent-created skills | Seed copy; `skill_manage` / review |
| `sessions/` + `state.db` | Full chat history, FTS5 search | Every turn |
| `logs/` | `errors.log`, `gateway.log` (redacted) | Runtime |
| `cron/` | Routines / Bot Mode jobs | `hermes cron` / Desktop |
| `pending/` | Staged memory/skill writes if approval on | Runtime |

`session_search` reads `state.db` for “did we talk about X?” — unlimited, not in the prompt. `MEMORY.md` is the tiny always-on subset.

Nix store holds templates and the wrapper only. Live state is the home directory. `hermes update` is not the path; bump the `hermes-agent` flake input.

## Mid-session vs next session

```
turn → memory tool / file write → disk now
     → system prompt still has the old snapshot
next session → reread MEMORY.md + USER.md (+ SOUL, skills)
```

Inspect: `~/.hermes/profiles/<name>/memories/` and `food/data/restaurants.json`. CLI: `hermes -p food journey list`.
