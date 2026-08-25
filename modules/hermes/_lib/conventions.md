# Concierge team conventions

These rules apply to `concierge`, `food`, `travel`, and `hermes-tutor`.
Every agent in this fleet runs **only** under Nono. Do not suggest an
unsandboxed `hermes` invocation.

## Universal Nono rule

- Invoke via the Nix-wrapped `hermes` (or `concierge` / `food` / `travel` /
  `hermes-tutor` aliases). Those binaries always `exec nono run --profile …`.
- Do not expand filesystem or network scope without stating the risk and
  updating the store-backed Nono profile.
- Denied paths include SSH keys and 1Password data. Treat EPERM as a Nono
  boundary, not a bug.

## Preference ownership

| Owner | Owns | Does not own |
|---|---|---|
| `concierge` | High-level prefs (party size, budget band, home base, hard constraints, trip intent) | Per-restaurant ratings, lodging amenity matrices |
| `food` | Restaurant/cuisine detail, structured `data/restaurants.json` | Global trip dates, lodging |
| `travel` | Lodging, day plans, outdoor/ski detail | Restaurant shortlists |
| `hermes-tutor` | Hermes/Nix/Nono operations knowledge | User dining or travel taste |

## Home base

Default geography is **Aliso Viejo / Orange County, California**. If the user
does not name a place, treat the request as home-base. Vacation location comes
from the user (or a trip packet), never from this Mac mini.

## Trip context packet (`trip-context.v1`)

Write/read `$HOME/.hermes/shared/trip-context.json`:

```json
{
  "version": 1,
  "id": "iso-timestamp-or-slug",
  "from": "concierge",
  "to": "food",
  "origin": "Aliso Viejo, CA",
  "destination": null,
  "dates": null,
  "party": 2,
  "budget": null,
  "constraints": [],
  "handoff": "food",
  "notes": ""
}
```

- `concierge` writes the packet before a specialist hand-off.
- Specialists read it at session start when present.
- `to` is `food`, `travel`, or `concierge` (return for synthesis).
- After the specialist finishes, set `to` to `concierge` and summarize in `notes`.

## Hand-off rules

1. User talks to `concierge` as the front door.
2. Dining detail → packet `to: food`, then `food` works the restaurant loop.
3. Lodging / multi-day / ski / road-trip detail → packet `to: travel`.
4. Specialists do **not** speak as the front door. They return a shortlist plus
   reasons to `concierge` for synthesis.
5. In Bot Mode, `message_agent` is allowed; the packet file is the durable
   source of truth across CLI, gateway, and restart.

## Feedback → memory (mandatory)

Every accepted or rejected recommendation must:

1. Update the owner's durable memory (`memories/MEMORY.md`).
2. For dining, also update `food`'s structured store (`data/restaurants.json`).
3. Stay conservative until at least one real feedback round exists.

## Restart

Preferences and the trip packet must survive process restart. Do not keep
canonical state only in the chat transcript.
