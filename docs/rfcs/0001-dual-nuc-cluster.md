# RFC 0001: Dual-NUC compute scaling for agent workloads

- **Status:** Draft  
- **Author:** grok  
- **Created:** 2026-08-01  
- **Hosts:** 2× ASUS NUC (x86_64-Linux NixOS), {~~direct high-speed link (Thunderbolt) ~> high-speed private LAN (Thunderbolt as L2/L3 path; tools are LAN-agnostic)~~}  
- **Related:** Tailscale mesh, opencode orchestration, mac-mini builder, {++Ray, 1Password++}

---

## 1. Problem

AI agents on a single NUC can exhaust CPU, RAM, or local scratch (large builds,
parallel godot/nix/eval, multi-agent fan-out). A second identical NUC sits
nearby with a **Thunderbolt** port. Goal: when the primary is saturated,
workloads **spill** to the peer automatically or with minimal policy.
{++Both nodes form a **generalized compute pool** (arbitrary jobs + Nix builds),
not a Nix-only builder pair.++}

---

## 2. Goals / non-goals

**Goals**

- {~~<!--c:cmpo4-->Share compute for Nix builds and long-running agent jobs<!--/c:cmpo4-->. ~> <!--c:cmpo4-->Generalized compute pool across both NUCs: arbitrary agent workloads **and** Nix builds<!--/c:cmpo4-->.~~}
- {~~Prefer the direct TB link for bulk data (store paths, artifacts) over Wi‑Fi/LAN. ~> Prefer the fastest available LAN path for bulk data (store paths, artifacts); Thunderbolt is one such path, not a special-cased protocol in app code.~~}
- Keep security model explicit (who can schedule what).
- Fit dendritic NixOS modules (no snowflake SSH hacks undocumented).
- {++**Ray** as the job submission and autoscaling engine between NUCs.++}
- {++Every job assumes **all dependencies are defined in Nix** (reproducible env / store paths / `nix shell` / derivations).++}
- {++Container runtime on both nodes for isolated spill (Podman or equivalent under Ray).++}
<!--co:cmpo4 by:Connor_Fuhr at:2026-08-02T06:10:12.265Z status:resolved quote:"Share compute for Nix builds and long-running agent jobs"
Connor Fuhr (2026-08-02T06:10:12.265Z): grok - I want this to be more generalized than this. The other NUC should be available for generalized compute. It should also be available for nix builds but it needs to be also able to be used for arbitrary workloads
grok (2026-08-02T08:33:08.000Z): Incorporated. Goal rewritten to generalized compute pool (arbitrary workloads + Nix). See §2 and §4–5 CriticMarkup.
-->

**Non-goals (v1)**

- Full Kubernetes-style multi-tenant cluster.
- Transparent process migration (CRIU) of live agent PIDs.
- GPU fabric (unless both NUCs gain identical GPUs later).
- {++Hermes / mac-mini scheduling onto the NUC pool (deferred; see §9).++}

---

## 3. {~~Thunderbolt on NixOS — can we use it for “super high-speed” data? ~> Private LAN path (Thunderbolt as Ethernet)~~}

{~~**Yes, with the right mode.** ~> **Yes — treat Thunderbolt networking as a normal high-speed LAN segment.** App/scheduler code addresses hosts by IP/DNS on “the LAN”; it must not hard-code Thunderbolt-specific APIs.~~}

Thunderbolt 3/4 on Linux can operate as:

| Mode                                      | What you get                                                                                                                                   | Good for                                             |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Networking (ThunderboltIP / USB4 net)** | A high-bandwidth point-to-point Ethernet-like interface (`thunderbolt0` / `enp…`) often **10–40 Gb/s class** depending on controller and cable | Nix store copy, rsync artifacts, Ray object store, iperf |
| **PCIe tunnel**                           | Expose devices (rare for NUC–NUC)                                                                                                         | Special hardware                                     |
| **Display / USB only**                    | Not a data plane between two hosts                                                                                                             | —                                                    |

### Practical NixOS path {++(infra only — not part of the job API)++}

1. Cable NUC-A ↔ NUC-B with TB4/USB4 cable (or TB dock chain — prefer direct).
2. Kernel: `thunderbolt`, `thunderbolt-net` (often in-tree on recent kernels).
3. {~~Authorize devices (Thunderbolt security levels: none/user/secure/dponly). For
   a homelab pair, **user** or **none** on a physically controlled desk is common;
   production should use secure UUID allowlisting. ~> Authorize the TB link so it comes up as a normal L3 interface (security level chosen for a physically controlled desk; prefer UUID allowlisting if firmware allows). Once up, it is just LAN.~~}
4. NetworkManager or systemd-networkd: static IPs on the TB iface, e.g.
   `10.200.0.1/30` and `10.200.0.2/30`, **no default route** on that iface.
5. Measure: `iperf3` over TB vs Tailscale vs 2.5GbE. {++Ray and Nix use whichever route the kernel picks (or explicit bind to the private subnet).++}

**Caveats**

- ASUS NUC firmware must expose TB correctly under Linux (test on each unit).
- Some “Thunderbolt” ports are USB4 with partial features — verify link speed
  in `journalctl -k | grep -i thunderbolt`.
- Sleep/peer disconnect can drop the link; {~~agent schedulers must retry. ~> Ray / job clients must retry on network failure like any LAN blip.~~}

**Answer:** Thunderbolt is a strong **private LAN backhaul** for store traffic,
{++Ray object/gRPC traffic,++} and artifact sync. It is not magic clustering by
itself — you still need a **{~~scheduler + identity + Nix trust~~ ~> Ray cluster + identity + Nix-defined job envs + trust~~}** layer on top.

---

## 4. Options for “agent ran out of resources → use the other NUC”

### Option A — Nix distributed builds (foundation)

- Each NUC lists the other in `nix.buildMachines` over **{~~TB IP~~ ~> private LAN IP~~}** (and Tailscale
  fallback).
- When local load is high, Nix already offloads derivations if `max-jobs` and
  builder slots are configured.
- **Agent impact:** free — any `nix build` spills automatically.

**Pros:** Native, proven, fits this monorepo.  
**Cons:** Only helps Nix builds, not arbitrary agent CPU (pytest, godot, etc.).
{++**Role in plan:** keep as underlay for derivation builds; not the agent job API.++}

### Option B — <!--c:qgfuf-->Shared remote builder pool + queue<!--/c:qgfuf--> {++(**chosen** — Ray)++}
<!--co:qgfuf by:Connor_Fuhr at:2026-08-02T06:14:08.141Z status:resolved quote:"Shared remote builder pool + queue"
Connor Fuhr (2026-08-02T06:14:08.141Z): grok - I want to implement this
grok (2026-08-02T08:33:08.000Z): Adopted as primary path with Ray. See revised recommendation and §5.
-->

- {~~Both NUCs run `nix-daemon` as builders; a tiny queue (e.g. `buildkite` agent,
  `nsncd`-less simple HTTP, or `harmonia` + manual) accepts jobs.
- Orchestrator skill <!--c:tuyje-->submits heavy jobs to the pool<!--/c:tuyje-->. ~> Both NUCs join a **Ray** cluster (head + workers, or multi-worker with fixed head). Agents / orchestrator <!--c:tuyje-->submit jobs to Ray<!--/c:tuyje-->. Each job entrypoint is launched inside a **Nix-defined environment** (flake app, `nix develop`/`nix shell` drv, or container image built by Nix). Nix distributed builds (Option A) remain for pure derivation work.~~}
<!--co:tuyje by:Connor_Fuhr at:2026-08-02T06:19:46.905Z status:resolved quote:"submits heavy jobs to the pool"
Connor Fuhr (2026-08-02T06:19:46.905Z): grok - I chose to use Ray as the job submission and scaling engine
Connor Fuhr (2026-08-02T06:20:48.284Z): agents should be able to submit a job to run that assumes all dependencies will be defined in nix
grok (2026-08-02T08:33:08.000Z): Ray adopted as job engine. Contract: jobs declare Nix deps only (no ad-hoc host packages). Reflected in goals and architecture.
-->

**Pros:** Explicit agent integration{++; autoscaling / placement across nodes++}.  
**Cons:** More moving parts{++ (Ray daemon lifecycle, head HA later)++}.

### Option C — <!--c:0gtpl-->Container/VM spill (Podman/Nomad)<!--/c:0gtpl--> {++(**chosen** as Ray runtime, not Nomad-first)++}
<!--co:0gtpl by:Connor_Fuhr at:2026-08-02T06:13:59.847Z status:resolved quote:"Container/VM spill (Podman/Nomad)"
Connor Fuhr (2026-08-02T06:13:59.847Z): grok - I want to implement this
grok (2026-08-02T08:33:08.000Z): Kept container isolation (Podman/Nix-built images) under Ray. Nomad deferred unless Ray placement proves insufficient. See §5 runtime notes.
-->

- {~~Nomad or Podman quadlets on both nodes; TB network as `host_network` or CNI.
- Agent detects memory pressure (`/proc/meminfo`, cgroup) and schedules the next
  worker container on the peer. ~> Podman (or Nix-built OCI images) on both nodes as the **isolation boundary** for Ray tasks that need a clean filesystem / cgroup. Ray schedules the task; the container is the unit of isolation. Network = host LAN (private subnet and/or Tailscale) — no Thunderbolt-specific CNI.~~}

**Pros:** General workloads{++ with reproducible Nix images++}.  
**Cons:** Ops complexity; {~~<!--c:1ny2b-->secrets<!--/c:1ny2b-->/network policy harder. ~> <!--c:1ny2b-->secrets<!--/c:1ny2b--> via **1Password on every host** (CLI/`op` / agent); network policy is LAN + Tailscale ACLs, not a second secret plane.~~}
<!--co:1ny2b by:Connor_Fuhr at:2026-08-02T06:13:50.957Z status:resolved quote:"secrets"
Connor Fuhr (2026-08-02T06:13:50.957Z): let's assume that 1password is the core secret storage and is configured on all machines
grok (2026-08-02T08:33:08.000Z): Assumed. §6 updated: 1Password is the sole secret store; no parallel secret sync.
-->

### Option D — Single logical hostname (active/passive)

- Keepalived/CARP VIP for “nuc-compute”; only one accepts new agent sessions.
- Failover on crash, not load-balance.

**Pros:** Simple mental model.  
**Cons:** Does not use second NUC for scale-out under load.
{++**Role in plan:** out of scope for v1 scale-out.++}

### Recommendation (phased)

1. {~~**P0:** Option A on Thunderbolt IP + Tailscale backup.  
2. **P1:** Orchestration skill hook: if local loadavg/mem > threshold, Task
   workers SSH/`nono` to peer for non-Nix jobs (Option B-lite).  
3. **P2:** Evaluate Nomad only if agents regularly need non-Nix spill. ~> **P0:** Private LAN between NUCs (Thunderbolt-as-Ethernet) + Tailscale fallback; Option A mutual `nix.buildMachines`; `nuc2` host module; both always-on.  
2. **P1:** Ray cluster on both NUCs; agent job API = “submit to Ray with Nix-defined deps”; container runtime for isolated tasks (B+C).  
3. **P2:** mac-mini Hermes → NUC Ray pool (future). Nomad only if Ray placement/ops fail.~~}

---

## 5. Proposed architecture ({~~P0/P1 ~> P0 LAN+Nix / P1 Ray~~})

```
{~~                     Thunderbolt /30
          ┌──────────────────────────────┐
          │ 10.200.0.1        10.200.0.2 │
       ┌──┴───┐                      ┌───┴──┐
       │ nuc  │  ← nix.buildMachines →│ nuc2 │
       │      │  ← Tailscale mesh  →  │      │
       └──┬───┘                      └───┬──┘
          │  agents / opencode            │
          └──────── orchestration ────────┘ ~>              private LAN /30 (e.g. TB)     Tailscale mesh
          ┌──────────────────────────────┐        │
          │ 10.200.0.1        10.200.0.2 │←───────┘
       ┌──┴───┐                      ┌───┴──┐
       │ nuc  │  ← nix.buildMachines →│ nuc2 │   (both always-on)
       │      │  ← Ray head/workers  →│      │
       └──┬───┘                      └───┬──┘
          │  agents submit jobs (Nix env) │
          └──────── Ray placement ────────┘~~}
```

### NixOS module sketch (future `generic.nuc-pair` {++/ `nixos.ray-worker`++})

```nix
# Pseudocode — not implemented in this RFC alone
networking.interfaces.thunderbolt0.ipv4.addresses = [{
  address = "10.200.0.1"; prefixLength = 30;
}];
nix.distributedBuilds = true;
nix.buildMachines = [{
  hostName = "10.200.0.2";  # private LAN IP — not a TB-specific API
  systems = [ "x86_64-linux" ];
  protocol = "ssh-ng";
  sshUser = "connorfuhrman";
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
}];
# services.ray = { enable = true; ... };  # P1
# virtualisation.podman.enable = true;   # P1 isolation
```

### {~~Agent policy sketch ~> Job submission contract (P1)~~}

```
{~~if loadavg_1m > CPUS or mem_available < 2GiB:
  dispatch worker with host=nuc2 (TB SSH)
else:
  local worker ~> # Agents do not pick hosts by SSH.
# Submit to Ray; Ray places on nuc | nuc2 by resources.
ray.submit(
  entrypoint = nix_defined_command,  # flake app / nix shell drv / OCI from Nix
  resources  = { cpu, mem, ... },
  # deps: only what Nix provides — no host-global pip/apt assumption
)~~}
```

Orchestrator remains on the machine where the human opened the session unless
explicitly remote. {++Ray workers run on the NUC pair; the human session host is a client.++}

---

## 6. Security

- {~~TB link is physical-local; still run SSH with keys (1Password agent for users;
  dedicated builder keys for nix-daemon). ~> Private LAN is physical-local; still authenticate services (SSH for Nix builders; Ray with explicit auth/network bind). User SSH keys via 1Password agent; dedicated builder keys for nix-daemon.~~}
- Do **not** expose nix-daemon TCP unsigned on {~~TB~~ ~> the private LAN~~} without SSH tunnel.
- Tailscale ACLs: nuc↔nuc allow; no accidental {~~LAN~~ ~> untrusted LAN~~} builder exposure.
- {~~Secrets stay in 1Password; never rsync `~/.config/opencode` credentials. ~> **1Password is the core secret store on all machines.** Jobs pull secrets at runtime via `op` / injected env from 1Password — never rsync credential dirs or bake secrets into Ray object store.~~}

---

## 7. Naming second NUC

Today the flake has one `nuc` host. Scaling requires:

- `nuc` + `nuc2` (or `nuc-a` / `nuc-b`) host modules
- Distinct `networking.hostName`, hardware-configuration, Tailscale identities
- Shared `nixos.server` + optional `nixos.nuc-cluster` feature module
- {++Both hosts **always-on** (same operational expectation as today’s `nuc`).++}

---

## 8. Success metrics

| Metric | Target |
|---|---|
| iperf3 {~~TB~~ ~> private LAN~~} | ≥ 10 Gbit/s unidirectional sustained |
| `nix build` offload | Peer store receives paths via preferred route |
| {~~Agent spill | Orchestrator log shows worker host=nuc2 under synthetic load~~ ~> Ray job | Job submitted with Nix env runs on peer when local resources exhausted~~} |
| Failure | Unplug TB → {~~builds fall back to Tailscale or local~~ ~> Nix + Ray fall back to Tailscale routes or local; no hard dependency on TB in app code~~} |

---

## 9. Open questions

1. {~~<!--c:jmylr-->Thunderbolt security level policy (user vs secure)?<!--/c:jmylr--> ~> <!--c:jmylr-->Resolved: Thunderbolt is configured as LAN; tools are LAN-agnostic.<!--/c:jmylr-->~~}
2. {~~<!--c:l85xh-->Is nuc2 always-on like nuc?<!--/c:l85xh--> ~> <!--c:l85xh-->Resolved: yes — nuc2 always-on.<!--/c:l85xh-->~~}
3. {~~<!--c:n6ijr-->Should Hermes/agent VMs also schedule across NUCs or only bare-metal jobs?<!--/c:n6ijr--> ~> <!--c:n6ijr-->Deferred: Hermes on mac-mini → NUC pool is a **future** goal; v1 is NUC↔NUC Ray + Nix only.<!--/c:n6ijr-->~~}
4. Homogeneous hardware (same RAM/CPU) assumed — confirm ASUS SKUs.
5. {++Ray head placement: fixed on `nuc`, or simple HA later?++}
6. {++Exact Nix→job packaging: flake `apps` vs `mkShell` vs OCI via `nix2container` / `dockerTools`?++}
<!--co:l85xh by:Connor_Fuhr at:2026-08-02T06:15:19.291Z status:resolved quote:"Is nuc2 always-on like nuc?"
Connor Fuhr (2026-08-02T06:15:19.291Z): yes
grok (2026-08-02T08:33:08.000Z): Recorded. §7 and architecture state both NUCs always-on.
-->
<!--co:jmylr by:Connor_Fuhr at:2026-08-02T06:16:28.791Z status:resolved quote:"Thunderbolt security level policy (user vs secure)?"
Connor Fuhr (2026-08-02T06:16:28.791Z): grok - let's assume that there is a LAN and lets' configure thunderbolt to be a LAN. We should then build the tools to assume a general LAN rather than build the tools assuming some specific protocol
grok (2026-08-02T08:33:08.000Z): Agreed. §3 reframed: TB is infra for a private LAN; Ray/Nix/agents use generic host/IP. No TB-specific job APIs.
-->
<!--co:n6ijr by:Connor_Fuhr at:2026-08-02T06:18:01.834Z status:resolved quote:"Should Hermes/agent VMs also schedule across NUCs or only bare-metal jobs?"
Connor Fuhr (2026-08-02T06:18:01.834Z): grok - I want the hermes agent that runs on the mac mini to use the nuc(s) as general compute when needed. But for now let's consider that as a future goal. i want to focus now on the compute sharing/scaling and job execution between the NUCs first
grok (2026-08-02T08:33:08.000Z): Scoped. Hermes→NUC = P2/future non-goal for v1. Focus = NUC pair Ray + Nix job execution.
-->

---

## 10. Decision

{~~<!--c:n0c1-->Adopt P0 Nix builders over Thunderbolt IP + Tailscale fallback; add nuc2 host module when hardware is online.<!--/c:n0c1--> ~> <!--c:n0c1-->Adopt: (1) private LAN between always-on `nuc`/`nuc2` (TB-as-Ethernet, tools LAN-agnostic), (2) mutual Nix builders, (3) Ray as job engine with Nix-defined dependencies and container isolation, (4) 1Password for secrets, (5) Hermes→NUC deferred.<!--/c:n0c1-->~~}
<!--co:n0c1 by:grok at:2026-08-01T00:00:00.000Z status:open quote:"Adopt P0 Nix builders over Thunderbolt IP + Tailscale fallback; add nuc2 host module when hardware is online."
grok (2026-08-01T00:00:00.000Z): Approve P0 / want Nomad-first / defer until second NUC imaged.
Connor Fuhr (2026-08-02T06:08:05.195Z): grok - why are you not using track-changes to talk to me!? I told you to always use that and the human will use documentcomments
grok (2026-08-02T08:33:08.000Z): Correct — agent prose edits now use CriticMarkup (track-changes); you keep Document Comments. Decision text updated to match your Ray + generalized compute choices. Please approve / amend the new decision anchor in Obsidian Track Changes + this thread.
-->

---

## 11. References

- Linux Thunderbolt networking: kernel `thunderbolt-net`
- Nix distributed builds: https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html
- This repo: `modules/generic/mac-mini-builder.nix` (pattern for buildMachines)
- {++Ray: https://docs.ray.io/ (cluster / jobs API)++}
- {++1Password CLI on fleet hosts (existing `onepassword` modules)++}
