# nixconfig

Declarative system and home configurations for every machine I run — NixOS,
nix-darwin, and home-manager — in one flake.

Built with the [dendritic flake-parts](https://github.com/mightyiam/dendritic)
pattern: features are modules under `modules/`, composed by name per host.

[![Nix flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](./flake.nix)
[![dendritic](https://img.shields.io/badge/structure-dendritic-2aa889)](https://github.com/mightyiam/dendritic)
[![checks](https://img.shields.io/badge/checks-nix%20flake%20check-brightgreen)](./modules/checks.nix)

## Hosts

| Host | System | Role |
|---|---|---|
| `mbp14` | `aarch64-linux` (NixOS / Asahi) | MacBook Pro 14" M2 — desktop (KDE Plasma 6) |
| `nuc` | `x86_64-linux` (NixOS) | Intel NUC — headless server |
| `macbook` | `aarch64-darwin` (nix-darwin) | macOS laptop |
| `mac-mini` | `aarch64-darwin` (nix-darwin) | Always-on Mac mini — Linux builder + Roon Core |

Each host has a matching standalone home-manager config: `connorfuhrman@<host>`.

**Shared across hosts**

- [Tailscale](https://tailscale.com/) (MagicDNS hostnames after one-time `sudo tailscale up`)
- [1Password](https://1password.com/) CLI everywhere; GUI on `mbp14` and Darwin (nixpkgs)
- Weekly Nix garbage collection (store paths older than 30 days)
- Common CLI tools, git, zsh, Emacs, and sandboxed [opencode](https://opencode.ai)

## Quick start

```sh
# Validate every configuration evaluates (no full system builds)
nix flake check

# NixOS
sudo nixos-rebuild switch --flake .#mbp14
sudo nixos-rebuild switch --flake .#nuc

# nix-darwin (first bootstraps with `nix run nix-darwin -- …`)
darwin-rebuild switch --flake .#macbook
darwin-rebuild switch --flake .#mac-mini

# home-manager (first bootstraps with `nix run home-manager/master -- …`)
home-manager switch --flake .#connorfuhrman@macbook
```

## Layout

```
flake.nix                 inputs + mkFlake only
modules/
  systems.nix             target systems
  checks.nix              eval-only checks for all configs
  nixos/                  NixOS features (system, desktop, server, asahi, …)
  darwin/                 nix-darwin features (system, linux-builder, roon, …)
  home/                   home-manager features (base, emacs, coreutils, …)
  generic/                shared features (tailscale, mac-mini-builder)
  hosts/<name>.nix        per-host composition + home config
  hosts/<name>/_*.nix     generated hardware (NixOS; not auto-imported)
firmware/                 Asahi peripheral firmware (private — do not publish)
INSTALL.md                Asahi / mbp14 install runbook
```

Every `.nix` file under `modules/` is auto-imported. Register reusable modules as
`flake.modules.<class>.<name>` and import them by name from a host module.
Classes: `nixos`, `darwin`, `homeManager`, `generic`.

## Home environment

Standalone home-manager for user `connorfuhrman` on every host:

| | Linux | macOS |
|---|---|---|
| **Emacs** | GUI from [connorfuhrman/emacs](https://github.com/connorfuhrman/emacs) | [Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus) (Homebrew) + same XDG config |
| **Shell / CLI** | zsh, eza, bat, fzf, ydiff, dust, jq, gtop, gping | same |
| **Git** | name/email, `master` default branch, auto upstream on push, ydiff pager | same |
| **opencode** | Runs inside [nono](https://github.com/nolabs-ai/nono); one-time `nono pull nolabs-ai/opencode` | same |

## Infrastructure notes

### Mac mini remote builder

The mini runs `nix.linux-builder` (aarch64-linux). Clients (`macbook`, `mbp14`,
`nuc`) offload via `generic.mac-mini-builder` over SSH host `mac-mini` (your
existing key / SSH config as `connorfuhrman`). Builds `aarch64-linux` only; the
entry is inert on the x86_64 NUC.

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
