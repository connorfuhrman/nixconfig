---
title: Hermes (Nono-wrapped)
author: grok
date: 2026-08-25
status: implemented
---

# Hermes

Nono-wrapped Hermes Agent. The store wrapper is the only `hermes` on PATH.

## Packaging

| Derivation | Role |
|---|---|
| `hermes-unwrapped` | Flake input `hermes-agent` (`packages.messaging`) |
| `hermes-share` | Nono profile JSON + SOUL/config templates |
| `hermes-cli` | `writeShellApplication` driver named `hermes` |
| `hermes-gateway` | `writeShellApplication`; `op` then `hermes concierge gateway start` |
| `hermes` | `symlinkJoin` of cli + gateway + share |

HM: `homeManager.nono-hermes` and `homeManager.nono-hermes-gateway` on mac-mini only.

Nono profile: least-privilege FS (`~/.hermes` + tmp), network allowlist (xAI, search, Telegram/Discord). Optional phantom `XAI_API_KEY` via `custom_credentials.xai`.

## Driver

```sh
hermes                      # upstream CLI under Nono
hermes concierge chat       # front door
hermes food chat            # restaurant specialist
hermes travel chat          # lodging / itinerary
hermes hermes-tutor chat    # meta-assistant
hermes gateway              # not the supervised unit; use hermes-gateway
hermes-gateway              # concierge messaging gateway
```

`hermes <profile>` inserts `-p <profile>` for `concierge`, `food`, `travel`, `hermes-tutor`. Anything else is passed through to upstream.

## Secrets

`HERMES_OP_VAULT` (default `op://Private/hermes`) is set by the HM module. `hermes-gateway` reads `TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN` / `DISCORD_TOKEN` from that item via `op read` before entering the sandbox.

## Runtime tree (`~/.hermes`)

The `hermes` driver seeds profiles on each start (SOUL/profile.yaml always; config/memory/store if missing). HM activation only creates XDG dirs, a discovery symlink for the Nono profile, and PATH links for `hermes` / `hermes-gateway`.

```
~/.hermes/
  shared/
    CONVENTIONS.md          # copied from store
    trip-context.json       # runtime
  profiles/<name>/          # concierge, food, travel, hermes-tutor
    SOUL.md                 # copied from store each run
    profile.yaml            # copied from store each run
    config.yaml             # seeded once
    memories/MEMORY.md      # seeded once; Hermes memory tool
    memories/USER.md        # created by Hermes
    data/restaurants.json   # food only; seeded once
    skills/                 # copied from store
    auth.json .env          # runtime secrets / OAuth
    sessions/ state.db      # runtime
  config.yaml SOUL.md       # default home (not the front door)

~/.config/nono/profiles/hermes-nix.json  →  /nix/store/…/nono-profile.json
~/.local/bin/hermes                      →  /nix/store/…/bin/hermes
~/.local/bin/hermes-gateway              →  /nix/store/…/bin/hermes-gateway
```

Live state is not in the Nix store. See `docs/research/hermes-memory.md`.

## Add a specialist

1. Add `modules/hermes/_profiles/<name>/{SOUL.md,config.yaml,profile.yaml}`.
2. Add `<name>` to the profile case in `pkgs/hermes.nix` and the seed loop.
3. Do not add a second binary on PATH.
4. `git add` then `nix build .#hermes`.

## Tests

```sh
nix build .#hermes
PROFILE=$(cat ./result/share/hermes-nix-root)/nono-profile.json \
  HERMES_BIN=./result/bin/hermes \
  bash modules/hermes/_test/test-nono-hermes.sh
```
