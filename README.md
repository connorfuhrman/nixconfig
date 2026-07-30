# asahi-linux

[![Nix flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](./flake.nix)
[![dendritic flake-parts](https://img.shields.io/badge/structure-dendritic-2aa889)](https://github.com/mightyiam/dendritic)
[![checks: nix flake check](https://img.shields.io/badge/checks-nix%20flake%20check-brightgreen)](./modules/checks.nix)
[![built with opencode](https://img.shields.io/badge/built%20with-opencode-1f425f)](https://opencode.ai)
[![open-weight models: Kimi](https://img.shields.io/badge/open--weight%20models-Kimi-blueviolet)](https://github.com/MoonshotAI)

Nix monorepo (dendritic flake-parts): NixOS, nix-darwin, and home-manager definitions.

## Hosts

| Host | Platform | Type | Notes |
|---|---|---|---|
| `mbp14` | `aarch64-linux` | NixOS | Asahi Linux on MacBook Pro 14" M2 Pro/Max |
| `nuc` | `x86_64-linux` | NixOS | Intel Nuc, headless server |
| `macbook` | `aarch64-darwin` | nix-darwin | macOS device |
| `mac-mini` | `aarch64-darwin` | nix-darwin | Always-on server: aarch64-linux builder (`nix.linux-builder`) + Roon Server |

All machines run Tailscale (`flake.modules.generic.tailscale`) and have
1Password installed. After each machine's first rebuild, run
`sudo tailscale up` once and sign in (credentials are in 1Password);
machines then resolve by hostname via MagicDNS (e.g. `ssh connor@mac-mini`).

Every home configuration also runs `opencode` inside the
[nono](https://github.com/nolabs-ai/nono) sandbox with the official
least-privilege profile (`nolabs-ai/opencode`): read/write access to the
current directory and nothing else. One-time per machine:
`nono pull nolabs-ai/opencode`.

## Home configurations

Standalone [home-manager](https://github.com/nix-community/home-manager)
configurations for user `connor`, each installing Emacs wired to
[connorfuhrman/emacs](https://github.com/connorfuhrman/emacs):

| Home configuration | System | Emacs |
|---|---|---|
| `connor@mbp14` | `aarch64-linux` | GUI (nixpkgs, wrapped) |
| `connor@nuc` | `x86_64-linux` | `emacs-nox` (nixpkgs, wrapped) |
| `connor@macbook` | `aarch64-darwin` | emacs-plus-app (Homebrew) + flake config |
| `connor@mac-mini` | `aarch64-darwin` | emacs-plus-app (Homebrew) + flake config |

On macOS, Emacs is [Emacs Plus](https://github.com/d12frosted/homebrew-emacs-plus)
(prebuilt, native-compiled; one-time `brew trust d12frosted/emacs-plus`), and
home-manager links `~/.config/emacs` to the flake's `emacs-config` package.

```sh
# first time (bootstraps home-manager itself):
nix run home-manager/master -- switch --flake .#connor@macbook
# thereafter:
home-manager switch --flake .#connor@macbook
```

## Layout

Dendritic pattern: every `.nix` file under `modules/` is a flake-parts module,
auto-imported by [import-tree](https://github.com/denful/import-tree). Reusable
modules are registered under `flake.modules.nixos.*` / `flake.modules.darwin.*` /
`flake.modules.homeManager.*` / `flake.modules.generic.*` and composed by
name — no relative-path imports between modules.

- `modules/systems.nix` — the flake's target systems list.
- `modules/checks.nix` — eval-only checks for every configuration (`nix flake check`).
- `modules/nixos/` — NixOS feature modules (`system`, `desktop`, `server`, `asahi`, `onepassword`).
- `modules/darwin/` — nix-darwin feature modules (`system`, `linux-builder`, `server`, `roon-server`, `onepassword`, `emacs-plus`).
- `modules/home/` — home-manager feature modules (`base`, `emacs` (gui/nox/plus), `nono-opencode`).
- `modules/generic/` — class-agnostic modules (`tailscale`, `mac-mini-builder`), usable by NixOS and nix-darwin alike.
- `modules/hosts/<name>.nix` — host definitions: system + home configurations.
- `modules/hosts/<name>/_hardware-configuration.nix` — generated hardware config
  (the `_` prefix excludes it from auto-import).
- `firmware/` — Asahi peripheral firmware (vendored; do not publish).

## Checks

`nix flake check` verifies that **every** configuration's derivations evaluate
— both NixOS toplevels, both nix-darwin systems, and all four home-manager
activation packages — without building anything. Each check is a trivial text
file embedding one configuration's `.drv` path; computing that path forces a
full evaluation of the closure. Defined once in `modules/checks.nix`, exposed
on every system.

```sh
nix --extra-experimental-features 'nix-command flakes' flake check
```

## Mac mini as a remote builder

The mini runs a `nix.linux-builder` VM (aarch64-linux). The
`flake.modules.generic.mac-mini-builder` module — already imported by
`macbook`, `mbp14`, and `nuc` — points those machines at the mini over SSH,
using its Tailscale name. One-time setup per client machine:

```sh
sudo ssh-keygen -t ed25519 -f /etc/nix/mac-mini-builder-key -N ''
ssh-copy-id -i /etc/nix/mac-mini-builder-key.pub connor@mac-mini
sudo ssh -i /etc/nix/mac-mini-builder-key connor@mac-mini true   # seed root's known_hosts
```

(If the client is not on the tailnet yet, substitute `mac-mini.local`. The
mini builds `aarch64-linux` only; the entry is inert on the x86_64 nuc until
an x86_64-capable builder exists.)

## Roon Server on the Mac mini

Roon no longer ships a standalone headless Roon Server for macOS — Roon.app is
the Core. The `roon-server` module installs Roon.app via Homebrew. One-time
setup (details in the module comments):

1. Install Homebrew on the mini if missing.
2. Open Roon.app, sign in, choose this Mac as the Roon Server (Core), and
   enable launch at login (Roon manages its own `RoonServer` login item).
3. For start-on-boot without logging in: System Settings → Users & Groups →
   Automatic login → connor. The `server` module keeps the mini awake and
   restarts it after power failures.

## Rebuild

```sh
# on mbp14 or nuc (NixOS):
sudo nixos-rebuild switch --flake .#mbp14
sudo nixos-rebuild switch --flake .#nuc

# on macbook or mac-mini (first time, bootstraps nix-darwin):
nix run nix-darwin -- switch --flake .#macbook
nix run nix-darwin -- switch --flake .#mac-mini
# thereafter:
darwin-rebuild switch --flake .#macbook
darwin-rebuild switch --flake .#mac-mini
```

## Installing Asahi Linux on the mbp14

See [INSTALL.md](./INSTALL.md) for the full step-by-step guide (Mac mini as
the aarch64-linux builder, ISO creation, partitioning, firmware, install).
PLAN.md is the older historical runbook.

## Built with

This repository is maintained with [opencode](https://opencode.ai) and
open-weight models ([Kimi](https://github.com/MoonshotAI) by Moonshot AI),
using a plan → delegate → verify workflow: the primary model plans and
verifies every change, while mechanical implementation is delegated to a
small open-weight model subagent.
