---
title: "How a restaurant agent can know your location"
author: grok
date: 2026-08-24
status: research
---

# How a restaurant agent can know your location

Question: ways for a personalized eat-out agent to know where you are (home
vs vacation), and whether Apple Location Services can be used inside the
Hermes NixOS VM on mac-mini.

**Short answers:** Apple Location **cannot** be used inside the VM. Even on
the Mac mini itself it would only ever report **home**. Vacation location has
to come from the phone (or you saying so), not from the always-on box.

Hermes has **no built-in geolocation tool**. It can search the web once it
*has* a place name or lat/lon.

---

## Can the VM use Apple Location?

No.

| Layer | Why it fails |
|---|---|
| Guest OS | NixOS / Linux. No Core Location, no `CLLocationManager`, no Location Services TCC prompt. |
| Hypervisor | QEMU + Apple HVF does not pass through Location Services. There is no virtio-gps. |
| Hardware | Mac mini has **no GPS**. macOS Location Services there is Wi-Fi triangulation of the house. |
| Egress | Guest default route is Nord WG ± Tor. IP geolocation of the VM is a VPN exit, not you. |

A host-side helper (`CoreLocation` on mac-mini → HTTP on `127.0.0.1` → QEMU
forward into the guest) is possible. It would still only ever say “home.”
Not worth building for this use case.

Native Hermes on the mini does not fix vacation: the mini does not travel.

---

## What “current location” actually means here

Two different facts:

1. **Home** — stable address. Put it in Hermes memory (`MEMORY.md` / profile).
   Enough for “near where I live.”
2. **Where you are now** — phone GPS / you telling it. Needed for vacation
   and for “what’s walkable from here.”

The always-on agent on mac-mini knows (1) for free. It never knows (2)
unless something that *moves with you* sends it.

Tailscale Serve does not help: the dashboard connection is over the tailnet,
so the server never sees your cellular/Wi-Fi public IP.

---

## Sources (best first for this agent)

| Source | Home | Vacation | In the VM? | Notes |
|---|---|---|---|---|
| Static home in memory | yes | no | yes | Do this regardless. |
| You name the city/neighborhood | yes | yes | yes | Zero plumbing; `clarify` if omitted. |
| Calendar / itinerary (flights, hotel) | — | yes | yes, if calendars reachable | Infer “this week I’m in Lisbon.” |
| Browser Geolocation in the dashboard (phone) | yes | yes | yes* | *Client* (`navigator.geolocation`) sends lat/lon in the chat. VM never talks to Apple. Best automatic path while v1 UX is the web UI. |
| iPhone Shortcut → webhook / file | yes | yes | yes, if webhook hits host Serve or a 9p drop | Shortcuts “Get Current Location” is real GPS. |
| Telegram/WhatsApp live location | yes | yes | only if messaging gateway is on | Deferred in Hermes v1 (web-only). |
| Home Assistant `device_tracker` | yes | yes | only if HA is reachable from guest | Hermes has `ha_*` tools. Guest has no Tailscale; needs a host proxy or HA on the VPN path. |
| IP geolocation of the VM | lies | lies | useless | Nord/Tor exit. |
| Apple Location on mac-mini | home only | no | not in guest | See above. |
| Find My / Significant Locations APIs | fragile | fragile | no | Unofficial, breaks, privacy-heavy. Skip. |

---

## Practical recipe

1. Store home (and dietary prefs) in Hermes memory.
2. If the user doesn’t specify a place, ask (`clarify`) or treat as home.
3. For “near me” while traveling: have the **phone** attach coordinates —
   dashboard Geolocation, or a Shortcut that posts lat/lon, or just type the
   neighborhood.
4. Then `web_search` / Maps (Google, Apple Maps web, Yelp, etc.) as usual.

Do not try to plumb Core Location into the VM.

---

## If you later want automatic phone location

Smallest build that respects the VM sandbox:

- iOS Shortcut (or dashboard JS) → `POST` lat/lon to a host localhost
  endpoint published only via Tailscale Serve, **or** write
  `~/hermes-state/workspace/location.json` (already 9p-mounted).
- Agent reads that file; TTL it (e.g. 30–60 min) so stale vacation pins
  don’t look like home.

Keep Apple Location on the **iPhone**, never on the mini or the guest.
