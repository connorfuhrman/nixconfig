---
title: "Hermes agent branch — what was done"
author: grok
date: 2026-08-24
status: research
---

# Hermes agent branch — what was done

Branch: `hermes-agent` (also `origin/hermes-agent`). Tip: `90b4a25` (2026-07-30).
Not merged into `develop`. Nothing Hermes-related exists on current `develop`.

Upstream: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent).

## Intent

Run Hermes as an isolated **NixOS guest VM on mac-mini**. The VM *is* the
sandbox: the agent gets a local shell and smart approvals inside the guest;
host blast radius is a workspace 9p share plus two localhost port forwards.
Guest never joins Tailscale. Egress is Nord WireGuard (± Tor).

## Commits (on top of merge-base `7107dfb`)

| Commit | What |
|---|---|
| `4e72f08` | Initial QEMU/HVF VM + `hermes-agent` module scaffolding |
| `a4b6ac1` | Security hardening v1 (SSH, sudo, 9p split, WG+Tor, policy) |
| `f520177` | Security-status comments (claimed complete; push blocked by nono) |
| `7cba204` | OKR KR board filled with PASS evidence |
| `a29913d` | Dashboard unit, localhost-only hostfwd, kill-switch, secrets re-merge |
| `90b4a25` | Architecture guide `docs/hermes.md` + Obsidian vault bits |

All six commits are from **2026-07-30**. Authors treated the security OKR as
**eval-complete**; live `darwin-rebuild` / first-boot on mac-mini was **not**
done from the laptop (AGENTS.md eval-only rule).

## Modules added

| File | Class | Role |
|---|---|---|
| `modules/darwin/hermes-vm.nix` | `darwin.hermes-vm` | QEMU/HVF VM, 9p shares, launchd, `hermes-vm` helper |
| `modules/hosts/hermes.nix` | `nixos.host-hermes` + `nixosConfigurations.hermes` | Guest OS + eval skeleton |
| `modules/nixos/hermes-agent.nix` | `nixos.hermes-agent` | Upstream `services.hermes-agent` + dashboard + secrets merge |
| `modules/nixos/hermes-egress.nix` | `nixos.hermes-egress` | WG, Tor, blackhole kill-switch, `hermes-egress-switch` |

`modules/hosts/mac-mini.nix` on that branch imports `darwin.hermes-vm`.
`flake.nix` adds input `hermes-agent.url = "github:NousResearch/hermes-agent"`
**without** `inputs.nixpkgs.follows` (upstream uv2nix lock).
`modules/checks.nix` adds `eval-nixos-hermes`.

## Architecture (from `docs/hermes.md` on the branch)

```
tailnet ── tailscale serve :443 ── mac-mini (darwin)
                                     launchd org.nixos.hermes-vm
                                     QEMU/HVF
                                       hostfwd 127.0.0.1:9119 → guest :9119
                                       hostfwd 127.0.0.1:31023 → guest :22
                                     ~/hermes-state/{workspace,ssh,secrets,net}  ──9p──► guest
                                          │
                                     hermes (NixOS aarch64-linux)
                                       hermes-agent (gateway)
                                       hermes-dashboard :9119
                                       hermes-killswitch (blackhole default @ metric 42)
                                       wg-quick-wg0 (Nord config from 9p)
                                       tor SOCKS 127.0.0.1:9050
                                       NO Tailscale
```

Locked design decisions (security plan D1–D8):

- Sandbox = whole VM; `terminal.backend = "local"` (no nested Podman)
- `approvals.mode = "smart"`; no deny list
- 9p is workspace-only for general rw; ssh/secrets/net are narrow mounts
- SSH keys at runtime from host file; never in the flake
- Secrets: manual `op inject` of `secrets.env.tpl` (OpenRouter + xAI)
- Egress: WG required; default app path Tor-over-WG; `vpn-only` fallback
- Web: guest :9119; Tailscale Serve on host is the only non-VPN *ingress*
- Guest firewall: 22 + 9119 only

Helpers on the host: `hermes-vm {ssh|hermes|status|serve-hint}`.

## Docs on the branch (not on develop)

- `docs/hermes.md` — architecture + ops
- `docs/plans/hermes-operator-runbook.md` — first-boot on mac-mini
- `docs/plans/hermes-security-hardening-plan.md` — locked decisions
- `docs/plans/hermes-security-implementer-spec.md` — file-level spec
- `docs/plans/hermes-security-okr-workplan.md` — O1–O5 KRs marked PASS (eval)

## Collateral on the same branch (not Hermes)

`modules/home/nono-opencode.nix` gained a store-backed
`opencode-skill-document-comments` package + HM symlink. Current `develop`
already has a more mature opencode/nono layout under `modules/opencode/` —
**do not cherry-pick that hunk**. Same for the `.obsidian/` plugin copies.

## Status vs current `develop`

- **Not merged.** Handoff note in `docs/HANDOFF_fleet-opencode-nix.md` already
  flags this as a separate history.
- Merge-base is `7107dfb` (pre-cluster, pre-rpi, pre-fleet-opencode). `develop`
  has since rewritten hosts, pkgs overlay, home `pkgsFor`, opencode bundle,
  cluster roles, etc.
- Shared files that **will conflict**: `flake.nix`, `flake.lock`,
  `modules/checks.nix`, `modules/hosts/mac-mini.nix`, `AGENTS.md`, `README.md`.
- Hermes-only files (`hermes-vm.nix`, `hermes.nix`, `hermes-agent.nix`,
  `hermes-egress.nix`, `docs/hermes.md`, plans) can be brought over cleanly
  *if* rebased onto current dendritic conventions (host composition, checks
  naming, overlay/`pkgsFor` if any guest packages need it).

## Not done

- Live deploy on mac-mini (`darwin-rebuild`, first boot, WG handshake, dashboard
  via `https://mac-mini`).
- Runtime KRs: curl to OpenRouter/xAI through the tunnel; prove guest cannot
  reach other tailnet IPs.
- Messaging gateways (Telegram/Discord/…).
- Nested container terminal backend.
- Using NUCs as Hermes compute (called out as future in RFC 0001).
- Rebase/merge onto current `develop`.
