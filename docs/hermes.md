---
title: Hermes concierge (Nono-wrapped)
author: grok
date: 2026-08-24
status: implemented
---

# Hermes concierge

Native Hermes Agent on Darwin, **always under Nono**. This is not the old
QEMU/NixOS VM on branch `hermes-agent`.

## Universal rule

**Every** Hermes agent, profile, bot, CLI invocation, Bot Mode launch, and
gateway process runs inside Nono. The store wrapper is the only supported
`hermes` on PATH.

| Binary | What it runs |
|---|---|
| `hermes` | `nono run --profile /nix/store/…/nono-profile.json -- <unwrapped> …` |
| `concierge` | same, with `-p concierge` |
| `food` | same, with `-p food` |
| `travel` | same, with `-p travel` |
| `hermes-tutor` | same, with `-p hermes-tutor` |
| `hermes-gateway` | Nono-wrapped `hermes -p concierge gateway start` |

There is no convenient unsandboxed `hermes`. An upstream installer binary at
`~/.local/bin/hermes` is renamed to `hermes-upstream-unwrapped` on HM
activation.

## Architecture

```
user / Discord / Telegram / Desktop
        │
        ▼
  hermes-gateway  ──Nono──►  hermes -p concierge
                                │
                   trip-context.json (shared)
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
         food (Nono)            travel (Nono)
              │
              ▼
     data/restaurants.json
```

| Bot | Role |
|---|---|
| `concierge` | Front door. Owns high-level prefs, trip packets, synthesis. |
| `food` | Restaurants. Structured store + preference loop. |
| `travel` | Lodging, itineraries, outdoor/ski. |
| `hermes-tutor` | Meta-assistant for Hermes, Nono, Nix, this team. |

Home base: **Aliso Viejo / Orange County, CA**.

Preference ownership and the `trip-context.v1` packet are in
`~/.hermes/shared/CONVENTIONS.md` (seeded from
`modules/hermes/_lib/conventions.md`).

## Flake layout

- Input: `hermes-agent` (NousResearch/hermes-agent, **no** nixpkgs follows).
- Unwrapped: `inputs.hermes-agent.packages.<system>.messaging`
- Wrapper: `pkgs/hermes-nix-bundle.nix` → `packages.hermes`
- HM: `homeManager.nono-hermes` on mac-mini and macbook
- Gateway: `homeManager.nono-hermes-gateway` on mac-mini (launchd
  `ai.x.hermes.concierge-gateway`)
- Nono profile: least-privilege FS (`~/.hermes` + tmp), network allowlist
  (xAI, search, Telegram/Discord), optional phantom `XAI_API_KEY` via
  `custom_credentials.xai` (enable by adding `"xai"` to `network.credentials`
  when using an API key instead of OAuth)

Sleep prevention for the mini is already `darwin.server` (`pmset sleep 0`).

## Talk to the team

```sh
concierge chat          # front door (Desktop Bot Mode or CLI)
food chat               # restaurant specialist (internal)
travel chat             # lodging / itinerary (internal)
hermes-tutor chat       # Hermes + Nono + flake help
hermes -p concierge …   # equivalent
```

Gateway: one front door on `concierge`. Specialists stay internal.

```sh
# start/stop (HM launchd on mac-mini, or CLI)
hermes-gateway                          # waits until a bot token exists
launchctl kickstart -k gui/$(id -u)/ai.x.hermes.concierge-gateway
launchctl bootout gui/$(id -u)/ai.x.hermes.concierge-gateway
```

Put `TELEGRAM_BOT_TOKEN` or `DISCORD_BOT_TOKEN` in
`~/.hermes/profiles/concierge/.env`. Do not commit that file.

<!--c:a1b2c3-->Complete SuperGrok OAuth before expecting Grok chat to work.<!--/c:a1b2c3-->
<!--co:a1b2c3 by:grok at:2026-08-24T20:00:00.000Z status:open quote:"Complete SuperGrok OAuth before expecting Grok chat to work."
grok (2026-08-24T20:00:00.000Z): Run `concierge auth add xai-oauth --no-browser`, open the printed accounts.x.ai URL, approve, then `concierge doctor`. Repeat per profile or copy `auth.json` into each profile home. Reply here when done.
-->

<!--c:d4e5f6-->Add a Discord or Telegram bot token if the 24/7 gateway should accept messages.<!--/c:d4e5f6-->
<!--co:d4e5f6 by:grok at:2026-08-24T20:00:00.000Z status:open quote:"Add a Discord or Telegram bot token if the 24/7 gateway should accept messages."
grok (2026-08-24T20:00:00.000Z): One front door on concierge. Put TELEGRAM_BOT_TOKEN or DISCORD_BOT_TOKEN in ~/.hermes/profiles/concierge/.env. launchd waits until a token appears. Which platform?
-->

## Grok (SuperGrok OAuth)

Preferred provider: `xai-oauth`, model `grok-4.6`. Seeded in each profile
`config.yaml`. OAuth tokens live in that profile's `auth.json` (inside the
allowed `~/.hermes` tree). For API-key mode, store `XAI_API_KEY` in the host
environment and enable Nono `network.credentials: ["xai"]` so the sandbox
only sees a phantom token.

## Restaurant loop

`food` skill `restaurant-preference`: search → 3-option shortlist → feedback
→ `data/restaurants.json` + `memories/MEMORY.md`. Later shortlists must
reflect `liked` / `disliked`. Two rounds before claiming a taste model.

## Add a specialist later (keep Nono)

1. Add `modules/hermes/_profiles/<name>/{SOUL.md,config.yaml,profile.yaml}`.
2. Append the name to the `profiles` list in `modules/hermes/nono-hermes.nix`.
3. Add a `wrap <name> "-p <name>"` line in `pkgs/hermes-nix-bundle.nix`.
4. Do **not** install a raw hermes binary. Do **not** widen the Nono profile
   without stating the risk in `docs/hermes.md`.
5. `git add` the new files, then `nix flake check` / `nix build .#hermes`.

## Tests

```sh
nix build .#hermes
./result/bin/hermes --help
PROFILE=$(cat ./result/share/hermes-nix-root)/nono-profile.json \
  HERMES_BIN=./result/bin/hermes \
  bash modules/hermes/_test/test-nono-hermes.sh
```

Isolation: `~/.ssh` reads fail; `https://example.com` fails; xAI hosts are
allowlisted.

## Validation

```sh
nix eval .#packages.aarch64-darwin.hermes.drvPath
nix eval .#homeConfigurations."connorfuhrman@mac-mini".config.home.packages --apply \
  'ps: map (p: p.pname or p.name) ps'
```
