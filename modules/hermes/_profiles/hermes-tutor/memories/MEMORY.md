# Hermes tutor memory

## Architecture (seed)

This machine runs Hermes **only under Nono**. There is no supported unsandboxed `hermes` on PATH.

- Wrapper: Nix package `hermes` (`pkgs/hermes.nix`) execs `nono run --profile $store/nono-profile.json -- <hermes-unwrapped> …`. Use `hermes food` / `hermes concierge chat`; there is no `food` binary.
- Inner binary comes from flake input `hermes-agent` (`packages.messaging`).
- Profiles (Bot Mode bots), each isolated under `~/.hermes/profiles/<name>/`:
  - `concierge` — front door for outings and travel
  - `food` — restaurants + `data/restaurants.json` preference store
  - `travel` — lodging, itineraries, outdoor/ski
  - `hermes-tutor` — this agent
- Shared conventions: `~/.hermes/shared/CONVENTIONS.md`
- Trip packets: `~/.hermes/shared/trip-context.json`
- Model: `xai-oauth` / `grok-4.6` (SuperGrok). Tokens live in each profile `auth.json` (OAuth) or Nono phantom credentials for `XAI_API_KEY`.
- Gateway: Nono-wrapped `hermes -p concierge gateway start` (mac-mini launchd). Specialists stay internal.
- Flake: `homeManager.nono-hermes` on darwin homes; gateway module on mac-mini.
- Do not use the old Hermes NixOS VM from branch `hermes-agent`.
