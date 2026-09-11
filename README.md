# nixconfig

Declarative system and home configurations for every machine I run — NixOS,
nix-darwin, and home-manager — in one flake.

Built with the [dendritic flake-parts](https://github.com/mightyiam/dendritic)
pattern: features are modules under `modules/`, composed by name per host.

[![Nix flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](./flake.nix)
[![dendritic](https://img.shields.io/badge/structure-dendritic-2aa889)](https://github.com/mightyiam/dendritic)
[![checks](https://img.shields.io/badge/checks-nix%20flake%20check-brightgreen)](./modules/checks.nix)

## Hosts

| Host | System | Role | Status |
|---|---|---|---|
| `mbp14` | `aarch64-linux` (NixOS / Asahi) | MacBook Pro 14" M2 — desktop (KDE Plasma 6) | **experimental** |
| `nuc` | `x86_64-linux` (NixOS) | Intel NUC — headless server (plain, no clustering) | **experimental** |
| `nuc-cluster-head` | `x86_64-linux` (NixOS) | Role closure on the NUC — Ray head node | **experimental** |
| `nuc-cluster-worker` | `x86_64-linux` (NixOS) | Role closure on the second NUC — Ray worker | **experimental** |
| `rpi-cluster-head` | `aarch64-linux` (NixOS) | Prototype Raspberry Pi 4 — alternate Ray head | **experimental** |
| `macbook` | `aarch64-darwin` (nix-darwin) | macOS laptop | tested |
| `mac-mini` | `aarch64-darwin` (nix-darwin) | Always-on Mac mini — Linux builder + Roon Core | tested |
| `cursor-cloud` | `x86_64-linux` (home-manager only) | Cursor Cloud Agent home — user `ubuntu` | **experimental** |

Each hardware host has a matching standalone home-manager config: `connorfuhrman@<host>`.
`cursor-cloud` is home-only (`ubuntu@cursor-cloud`; app `cursor-cloud-setup`).
Cluster role closures are **mutually exclusive** with the plain closure on the
same hardware (distinct `networking.hostName` / Tailscale identity) — boot
`nuc` *or* `nuc-cluster-head` on the first NUC, never both.

**Experimental** hosts (`mbp14`, all NUC closures, `rpi-cluster-head`, `cursor-cloud`) are
evaluated in CI via `nix flake check` but have **not** been validated on real
hardware yet. Metadata lives in `modules/hosts/status.nix` (`flake.hostStatus`).

**Shared across hosts**

- [Tailscale](https://tailscale.com/) (MagicDNS hostnames after one-time `sudo tailscale up`)
- [1Password](https://1password.com/) CLI everywhere; GUI on `mbp14` and Darwin (nixpkgs)
- Weekly Nix garbage collection (store paths older than 30 days)
- Common CLI tools, git, gh (GitHub CLI), zsh, Emacs

## Quick start

```sh
# Validate every configuration evaluates (no full system builds)
nix flake check

# NixOS — experimental hosts; verify on hardware before relying on them
sudo nixos-rebuild switch --flake .#mbp14
sudo nixos-rebuild switch --flake .#nuc
sudo nixos-rebuild switch --flake .#nuc-cluster-head
sudo nixos-rebuild switch --flake .#nuc-cluster-worker
sudo nixos-rebuild switch --flake .#rpi-cluster-head

# nix-darwin (first bootstraps with `nix run nix-darwin -- …`)
darwin-rebuild switch --flake .#macbook
darwin-rebuild switch --flake .#mac-mini

# home-manager (first bootstraps with `nix run home-manager/master -- …`)
home-manager switch --flake .#connorfuhrman@macbook
```

## Layout

```
flake.nix                 inputs + mkFlake only
pkgs/                     custom packages (callPackage); overlay = pkgs/default.nix
modules/
  systems.nix             target systems
  checks.nix              eval-only checks for all configs
  pkgs.nix                overlay export + packages.* + lib.pkgsFor
  nixos/                  NixOS features (system, desktop, server, asahi,
                          nuc-cluster, ray-cluster, onepassword, …)
  darwin/                 nix-darwin features (system, linux-builder, roon, …)
  home/                   home-manager (standard = base+emacs+coreutils+mosh+obsidian-config)
  generic/                shared features (tailscale, mac-mini-builder)
  hosts/<name>.nix        per-host composition + home config
  hosts/status.nix        host maturity metadata (experimental vs tested)
  hosts/<name>/_*.nix     generated hardware (NixOS; not auto-imported)
docs/                     human-facing notes (plans/, rfcs/, research/)
firmware/                 Asahi peripheral firmware (private — do not publish)
INSTALL.md                Asahi / mbp14 install runbook
```

Every `.nix` file under `modules/` is auto-imported. Register reusable modules as
`flake.modules.<class>.<name>` and import them by name from a host module.
Classes: `nixos`, `darwin`, `homeManager`, `generic`.

## Home environment

Standalone home-manager for user `connorfuhrman` on every hardware host.
Cloud Agents use `ubuntu@cursor-cloud`.

| | Linux | macOS |
|---|---|---|
| **Emacs** | GUI from [connorfuhrman/emacs](https://github.com/connorfuhrman/emacs) | same flake (emacs-macport + packages + `--init-directory`) |
| **Shell / CLI** | zsh, eza, bat, fzf, ydiff, dust, jq, gtop, gping, gh | same |
| **Git** | name/email, `master` default branch, auto upstream on push, ydiff pager | same |

## Infrastructure notes

### Dual-NUC cluster (`nuc-cluster-head` + `nuc-cluster-worker`)

Per [RFC 0001](./docs/rfcs/0001-dual-nuc-cluster.md): the two NUCs form a
generalized compute pool. A point-to-point Thunderbolt link carries a /30
private LAN (`10.200.0.1`/`10.200.0.2`, LAN-agnostic — any fast link works);
each NUC builds for the other (`nix.buildMachines`, LAN preferred, Tailscale
fallback). `nuc-cluster-head` runs the **Ray head** (GCS 6379, dashboard 8265,
client 10001), `nuc-cluster-worker` runs a **Ray worker**; both run Podman
(dockerCompat) for task isolation. Jobs declare all dependencies via Nix — no
host-global packages. Secrets come from 1Password at runtime, never baked into
job environments. The head role is a single switch point
(`flake.cluster.headName` in `modules/nixos/cluster.nix`) — e.g. promote the
`rpi-cluster-head` prototype by changing one string; workers repoint on rebuild.

### Mac mini remote builder

The mini runs `nix.linux-builder` (aarch64-linux VM with qemu-user binfmt, so
it advertises **both** `aarch64-linux` and `x86_64-linux`). Clients (`macbook`,
`mbp14`, `nuc`, the cluster role closures) offload via
`generic.mac-mini-builder` over SSH host
`mac-mini` (existing key / SSH config as `connorfuhrman`).

### Roon Core (mac-mini)

Roon.app is the Core on macOS (no headless server package). Installed via
Homebrew. After install: sign in, enable this Mac as Core, turn on launch at
login. Optional auto-login for unattended boot.

### Asahi install (mbp14)

See [INSTALL.md](./INSTALL.md) for dual-boot NixOS on Apple Silicon (ISO,
partitioning, firmware, first rebuild).

## Privacy

Keep this repository private. `firmware/` contains extracted Apple device
firmware and must not be published.
