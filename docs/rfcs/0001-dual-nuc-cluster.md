# RFC 0001: Dual-NUC compute scaling for agent workloads

- **Status:** Draft  
- **Author:** grok  
- **Created:** 2026-08-01  
- **Hosts:** 2× ASUS NUC (x86_64-Linux NixOS), direct high-speed link (Thunderbolt)  
- **Related:** Tailscale mesh, opencode orchestration, mac-mini builder  

---

## 1. Problem

AI agents on a single NUC can exhaust CPU, RAM, or local scratch (large builds,
parallel godot/nix/eval, multi-agent fan-out). A second identical NUC sits
nearby with a **Thunderbolt** port. Goal: when the primary is saturated,
workloads **spill** to the peer automatically or with minimal policy.

---

## 2. Goals / non-goals

**Goals**

- Share compute for Nix builds and long-running agent jobs.
- Prefer the direct TB link for bulk data (store paths, artifacts) over Wi‑Fi/LAN.
- Keep security model explicit (who can schedule what).
- Fit dendritic NixOS modules (no snowflake SSH hacks undocumented).

**Non-goals (v1)**

- Full Kubernetes-style multi-tenant cluster.
- Transparent process migration (CRIU) of live agent PIDs.
- GPU fabric (unless both NUCs gain identical GPUs later).

---

## 3. Thunderbolt on NixOS — can we use it for “super high-speed” data?

**Yes, with the right mode.**

Thunderbolt 3/4 on Linux can operate as:

| Mode | What you get | Good for |
|---|---|---|
| **Networking (ThunderboltIP / USB4 net)** | A high-bandwidth point-to-point Ethernet-like interface (`thunderbolt0` / `enp…`) often **10–40 Gb/s class** depending on controller and cable | Nix store copy, rsync artifacts, Ceph/Gluster, iperf |
| **PCIe tunnel** | Expose devices (eBGP rare for NUC–NUC) | Special hardware |
| **Display / USB only** | Not a data plane between two hosts | — |

### Practical NixOS path

1. Cable NUC-A ↔ NUC-B with TB4/USB4 cable (or TB dock chain — prefer direct).
2. Kernel: `thunderbolt`, `thunderbolt-net` (often in-tree on recent kernels).
3. Authorize devices (Thunderbolt security levels: none/user/secure/dponly). For
   a homelab pair, **user** or **none** on a physically controlled desk is common;
   production should use secure UUID allowlisting.
4. NetworkManager or systemd-networkd: static IPs on the TB iface, e.g.
   `10.200.0.1/30` and `10.200.0.2/30`, **no default route** on that iface.
5. Measure: `iperf3` over TB vs Tailscale vs 2.5GbE.

**Caveats**

- ASUS NUC firmware must expose TB correctly under Linux (test on each unit).
- Some “Thunderbolt” ports are USB4 with partial features — verify link speed
  in `journalctl -k | grep -i thunderbolt`.
- Sleep/peer disconnect can drop the link; agent schedulers must retry.

**Answer:** Thunderbolt is a strong **private backhaul** for store traffic and
artifact sync. It is not magic clustering by itself — you still need a
**scheduler + identity + Nix trust** layer on top.

---

## 4. Options for “agent ran out of resources → use the other NUC”

### Option A — Nix distributed builds (smallest step)

- Each NUC lists the other in `nix.buildMachines` over **TB IP** (and Tailscale
  fallback).
- When local load is high, Nix already offloads derivations if `max-jobs` and
  builder slots are configured.
- **Agent impact:** free — any `nix build` spills automatically.

**Pros:** Native, proven, fits this monorepo.  
**Cons:** Only helps Nix builds, not arbitrary agent CPU (pytest, godot, etc.).

### Option B — Shared remote builder pool + queue

- Both NUCs run `nix-daemon` as builders; a tiny queue (e.g. `buildkite` agent,
  `nsncd`-less simple HTTP, or `harmonia` + manual) accepts jobs.
- Orchestrator skill submits heavy jobs to the pool.

**Pros:** Explicit agent integration.  
**Cons:** More moving parts.

### Option C — Container/VM spill (Podman/Nomad)

- Nomad or Podman quadlets on both nodes; TB network as `host_network` or CNI.
- Agent detects memory pressure (`/proc/meminfo`, cgroup) and schedules the next
  worker container on the peer.

**Pros:** General workloads.  
**Cons:** Ops complexity; secrets/network policy harder.

### Option D — Single logical hostname (active/passive)

- Keepalived/CARP VIP for “nuc-compute”; only one accepts new agent sessions.
- Failover on crash, not load-balance.

**Pros:** Simple mental model.  
**Cons:** Does not use second NUC for scale-out under load.

### Recommendation (phased)

1. **P0:** Option A on Thunderbolt IP + Tailscale backup.  
2. **P1:** Orchestration skill hook: if local loadavg/mem > threshold, Task
   workers SSH/`nono` to peer for non-Nix jobs (Option B-lite).  
3. **P2:** Evaluate Nomad only if agents regularly need non-Nix spill.

---

## 5. Proposed architecture (P0/P1)

```
                    Thunderbolt /30
         ┌──────────────────────────────┐
         │ 10.200.0.1        10.200.0.2 │
      ┌──┴───┐                      ┌───┴──┐
      │ nuc  │  ← nix.buildMachines →│ nuc2 │
      │      │  ← Tailscale mesh  →  │      │
      └──┬───┘                      └───┬──┘
         │  agents / opencode            │
         └──────── orchestration ────────┘
```

### NixOS module sketch (future `generic.nuc-pair`)

```nix
# Pseudocode — not implemented in this RFC alone
networking.interfaces.thunderbolt0.ipv4.addresses = [{
  address = "10.200.0.1"; prefixLength = 30;
}];
nix.distributedBuilds = true;
nix.buildMachines = [{
  hostName = "10.200.0.2";
  systems = [ "x86_64-linux" ];
  protocol = "ssh-ng";
  sshUser = "connorfuhrman";
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
}];
```

### Agent policy sketch

```
if loadavg_1m > CPUS or mem_available < 2GiB:
  dispatch worker with host=nuc2 (TB SSH)
else:
  local worker
```

Orchestrator remains on the machine where the human opened the session unless
explicitly remote.

---

## 6. Security

- TB link is physical-local; still run SSH with keys (1Password agent for users;
  dedicated builder keys for nix-daemon).
- Do **not** expose nix-daemon TCP unsigned on TB without SSH tunnel.
- Tailscale ACLs: nuc↔nuc allow; no accidental LAN builder exposure.
- Secrets stay in 1Password; never rsync `~/.config/opencode` credentials.

---

## 7. Naming second NUC

Today the flake has one `nuc` host. Scaling requires:

- `nuc` + `nuc2` (or `nuc-a` / `nuc-b`) host modules
- Distinct `networking.hostName`, hardware-configuration, Tailscale identities
- Shared `nixos.server` + optional `nixos.nuc-cluster` feature module

---

## 8. Success metrics

| Metric | Target |
|---|---|
| iperf3 TB | ≥ 10 Gbit/s unidirectional sustained |
| `nix build` offload | Peer store receives paths without LAN |
| Agent spill | Orchestrator log shows worker host=nuc2 under synthetic load |
| Failure | Unplug TB → builds fall back to Tailscale or local |

---

## 9. Open questions

1. Thunderbolt security level policy (user vs secure)?
2. Is nuc2 always-on like nuc?
3. Should Hermes/agent VMs also schedule across NUCs or only bare-metal jobs?
4. Homogeneous hardware (same RAM/CPU) assumed — confirm ASUS SKUs.

---

## 10. Decision

<!--c:n0c1-->Adopt P0 Nix builders over Thunderbolt IP + Tailscale fallback; add nuc2 host module when hardware is online.<!--/c:n0c1-->
<!--co:n0c1 by:grok at:2026-08-01T00:00:00.000Z status:open quote:"Adopt P0 Nix builders over Thunderbolt IP + Tailscale fallback; add nuc2 host module when hardware is online."
grok (2026-08-01T00:00:00.000Z): Approve P0 / want Nomad-first / defer until second NUC imaged.
-->

---

## 11. References

- Linux Thunderbolt networking: kernel `thunderbolt-net`
- Nix distributed builds: https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html
- This repo: `modules/generic/mac-mini-builder.nix` (pattern for buildMachines)
