# AGENTS.md

Nix monorepo: NixOS + nix-darwin + home-manager, structured with the **dendritic
flake-parts pattern**. This file is the authoritative orientation for agents
working in this repo.

## Hosts

| Host | Platform | Type | Notes |
|---|---|---|---|
| `mbp14` | `aarch64-linux` | NixOS | Asahi Linux, MacBook Pro 14" M2 Pro/Max (KDE Plasma 6) |
| `nuc` | `x86_64-linux` | NixOS | Intel Nuc, headless server |
| `macbook` | `aarch64-darwin` | nix-darwin | macOS device |
| `mac-mini` | `aarch64-darwin` | nix-darwin | Always-on server: aarch64-linux builder (`nix.linux-builder`) + Roon Server |
| `connorfuhrman@mbp14` / `@nuc` / `@macbook` / `@mac-mini` | per host | home-manager | standalone via `homeManager.standard` |

All hosts run Tailscale and have 1Password installed (CLI everywhere; GUI on
mbp14 and darwin via nixpkgs). System and home username is **`connorfuhrman`**
everywhere.

## Architecture (dendritic pattern — follow it)

- `flake.nix` is thin: a `nixConfig` block (nixos-apple-silicon binary cache),
  inputs, and `mkFlake` with `flakeModules.modules`,
  `home-manager.flakeModules.home-manager`,
  `nix-darwin.flakeModules.default`, and `(inputs.import-tree ./modules)`.
  **It only changes when inputs (or the cache config) change.**
- **Every `.nix` file under `modules/` is a flake-parts module**, auto-imported
  by [import-tree](https://github.com/denful/import-tree). Adding a file = adding
  a feature. No wiring anywhere.
- Reusable modules are registered under `flake.modules.<class>.<name>`
  (classes: `nixos`, `darwin`, `homeManager`, `generic`) and **composed by name**
  (`config.flake.modules.nixos.foo`). Never use relative-path imports between
  modules. `generic` modules (e.g. `tailscale`, `mac-mini-builder`) can be
  imported by any configuration class.
- Configurations live in `modules/hosts/<name>.nix`: a `host-<name>` module that
  composes features by name, plus the `<name>` configuration (and
  `connorfuhrman@<name>` home configuration) built from it.
- Home hosts import **`homeManager.standard`** (base + emacs + coreutils +
  nono-opencode) — do not re-list those four modules per host.
- **No `specialArgs`/`extraSpecialArgs`** — dendritic anti-pattern. Values flow
  through the top-level module system; lower-level modules close over `inputs`
  lexically where needed.
- Files/dirs prefixed with `_` are excluded from auto-import (import-tree
  convention). Used for `modules/hosts/<name>/_hardware-configuration.nix` —
  generated templates, imported explicitly by their host module.
- Do not add `mkEnableOption`-gated modules; importing a module enables it.

### Repo layout

```
flake.nix               nixConfig (binary cache) + inputs + mkFlake only
modules/systems.nix     systems list: aarch64-linux, x86_64-linux, aarch64-darwin
modules/checks.nix      eval-only checks for every configuration (nix flake check)
modules/nixos/          NixOS features: system, desktop, server, asahi, onepassword
modules/darwin/         nix-darwin features: system, linux-builder, server, roon-server, onepassword, emacs-plus
modules/home/           homeManager: base, emacs, coreutils, nono-opencode, standard
modules/generic/        class-agnostic features: tailscale, mac-mini-builder
modules/hosts/          host definitions (+ _hardware-configuration.nix per NixOS host)
opencode.json           project opencode permissions (keep in sync with nono-opencode.nix)
.opencode/              project agents (e.g. ling-implementer)
firmware/               vendored Asahi firmware — PRIVATE, never publish
INSTALL.md              human-facing Asahi install runbook for mbp14
README.md               human-facing overview (this repo is multi-host, not Asahi-only)
```

## Working in this repo

- **Flakes and `nix-command` are enabled** in system config
  (`nix.settings.experimental-features`). Use plain `nix flake` / `nix eval`.
- **Evaluation only — never build system closures.** No `nixos-rebuild`,
  `darwin-rebuild`, or `home-manager` from the dev machine. `nix flake check`
  and `nix eval` are the validation tools; building the small pinned binary
  packages (nono, opencode) for the CURRENT system is allowed for validation
  (`nix build .#nono`, `nix build .#opencode`).
- This **is** a git repo. Prefer `develop` for commits (see Workflow). Do not
  force-push or commit secrets / `firmware/` blobs to a public remote.
- `flake show` displays `darwinConfigurations`, `homeConfigurations`,
  `homeModules`, and `modules` as type "unknown" — normal Nix behavior, not an
  error. Verify those outputs with `nix eval` instead.

### Standard validation suite (run after any structural change)

```sh
cd /Users/connorfuhrman/nixconfig
# primary gate: proves every configuration's derivations evaluate (8 closures).
# Runs PURE (no --impure, no env vars) — unfree allowance is scoped in onepassword modules.
nix flake check .
# module registries:
nix eval .#modules.nixos --apply 'm: builtins.attrNames m'
nix eval .#modules.darwin --apply 'm: builtins.attrNames m'
nix eval .#modules.homeManager --apply 'm: builtins.attrNames m'
nix eval .#modules.generic --apply 'm: builtins.attrNames m'
# per-host spot checks (when touching the implicated option):
nix eval .#nixosConfigurations.mbp14.config.hardware.asahi.enable          # true
nix eval .#nixosConfigurations.mbp14.config.services.tailscale.enable      # true
nix eval .#nixosConfigurations.mbp14.config.nix.distributedBuilds          # true
nix eval .#nixosConfigurations.nuc.config.networking.hostName              # "nuc"
nix eval .#darwinConfigurations.macbook.config.system.stateVersion         # 5
nix eval .#darwinConfigurations.macbook.config.homebrew.enable             # true
nix eval .#darwinConfigurations.macbook.config.nix.distributedBuilds       # true
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.enable   # true
```

## Gotchas (learned the hard way)

- **`flake check` asserts evaluation, not buildability.** The checks in
  `modules/checks.nix` embed each configuration's `.drvPath` in a text file —
  they instantiate (fully evaluate) every closure but build nothing. Realizing
  closures happens on target hardware or the mac-mini builder. Check names must
  not contain `@` (invalid in store paths), hence `eval-home-connorfuhrman-mbp14`
  etc.
- **Unfree packages:** 1Password is unfree; each platform's onepassword
  module sets a scoped `nixpkgs.config.allowUnfreePredicate` (must appear
  exactly once per configuration — multiple definitions of that option
  conflict). Do not add unfree packages without extending the predicate;
  never work around it with `--impure`/`NIXPKGS_ALLOW_UNFREE` in the
  validation suite.
- **nono/opencode are NOT in nixpkgs.** `modules/home/nono-opencode.nix`
  packages both from pinned upstream release binaries (nono v0.69.0,
  nolabs-ai/nono; opencode v1.18.5, anomalyco/opencode — the repo moved from
  sst/opencode) and exposes `packages.nono` / `opencode-bin` / `opencode` for
  the current system. Bumping = new version + 3 hashes
  (`nix store prefetch-file`). nono Linux builds are glibc-linked
  (autoPatchelfHook); opencode Linux builds are musl (static). The `opencode`
  wrapper execs via absolute store paths — no PATH recursion — using
  flake-managed profile `opencode-nix` (extends `nolabs-ai/opencode`, CWD
  readwrite via `workdir`, grants `~/.local/share/nix` so agents can
  `nix eval` / `flake check`). One-time per machine:
  `nono pull nolabs-ai/opencode`. HM ships `~/.config/opencode/opencode.json`
  with broad `permission` allow + `autoupdate = false` because nono already
  sandboxes (do not weaken the nono profile). Keep repo-root `opencode.json`
  identical to that config object.
- **Homebrew modules must set `homebrew.enable = true`.** nix-darwin ignores
  taps/casks otherwise. `darwin.emacs-plus` and `darwin.roon-server` both enable it.
- **Remote builder clients need `nix.distributedBuilds = true`.** Setting only
  `nix.buildMachines` leaves `builders =` empty in nix.conf.
  `generic.mac-mini-builder` sets both.
- **Relative paths are depth-sensitive.** `peripheralFirmwareDirectory` in
  `modules/nixos/asahi.nix` is `../../firmware` — correct only at its current
  depth. Eval does not force path options; verify with:
  `nix eval .#nixosConfigurations.mbp14.config.hardware.asahi.peripheralFirmwareDirectory`
  (must print a `/nix/store/...-firmware` path under `--json`, or a path into
  the flake source).
- **Every NixOS host module must import its `_hardware-configuration.nix`** or
  the root-filesystem assertion fails at eval time.
- **Asahi boot:** `boot.loader.efi.canTouchEfiVariables = false` is mandatory;
  systemd-boot; no `boot.kernelPackages` override; firmware via
  `hardware.asahi.peripheralFirmwareDirectory`.
- **Firmware directory contents:** real installs need `all_firmware.tar.gz` and
  `kernelcache*` copied from the ESP into `firmware/` (the `firmware.cpio`
  placeholder is replaced during install — see INSTALL.md).
- **The nixos-apple-silicon binary cache** is configured twice, on purpose:
  flake-level `nixConfig` (used at install time / by trusted users) and
  `nix.settings` in `modules/nixos/asahi.nix` (permanent system config).
- **Tailscale:** one-time `sudo tailscale up` per machine (credentials in
  1Password); MagicDNS short names (e.g. `mac-mini`) are used for
  machine-to-machine references. Exception: the Asahi installer's live ISO is
  NOT on the tailnet — INSTALL.md correctly uses `mac-mini.local` there.
  On macOS the module runs headless tailscaled — do not also install the
  Tailscale.app cask.
- **1Password:** CLI everywhere (`programs._1password`), GUI via `programs._1password-gui` on NixOS and nixpkgs on darwin (same official 1Password.app as the Homebrew cask). On macOS, nixpkgs provides both CLI and GUI — no Homebrew cask needed.
- **Emacs:** single `homeManager.emacs` module — Darwin links the XDG config dir (`~/.config/emacs`) to the flake's `emacs-config` package (binary supplied by brew emacs-plus-app via `darwin.emacs-plus`); Linux installs GUI Emacs from the emacs flake. No separate gui/nox/plus distinction for home modules. The emacs flake names ALL wrapped variants `emacs` (symlinkJoin) — variants are distinguishable only by drvPath, not by `p.name`. It is consumed self-contained (does NOT follow our nixpkgs).
- **Remote builder:** `flake.modules.generic.mac-mini-builder` (client side)
  assumes existing passwordless SSH to host `mac-mini` as `connorfuhrman`
  (including for root / the Nix daemon). No dedicated `/etc/nix/*` key. The
  mini only builds `aarch64-linux`; on the x86_64 nuc the entry is inert.
- **Roon on macOS:** nixpkgs `roon-server` is x86_64-linux only and Roon ships
  no standalone headless macOS server — Roon.app (brew cask) IS the Core and
  manages its own `RoonServer` login item. No nix launchd unit; autostart =
  Roon's login item (+ optional auto-login). Homebrew must be installed.
- **Determinate Nix's native Linux builder** (Virtualization.framework) was
  evaluated for the mini and rejected: developer-preview status and it replaces
  the Nix installation. `nix.linux-builder` stays. Revisit if it matures.
- **stateVersion types differ:** NixOS/home-manager use strings (`"25.11"`),
  nix-darwin uses an integer (`5`).
- `_hardware-configuration.nix` files are TEMPLATES — real values come from
  `nixos-generate-config` on target hardware (see INSTALL.md).
- Keep this repo **private**: `firmware/` contains extracted Apple firmware.
  (README badges notwithstanding — exclude `firmware/` if ever publishing.)

## Workflow convention (user preference)

- Primary agent **plans and verifies**; mechanical implementation is delegated
  to the `ling-implementer` subagent (cheap model, defined in
  `.opencode/agents/ling-implementer.md`) with exact file-by-file specs.
- After delegation, the primary agent re-reads changed files and re-runs the
  validation suite itself. Never trust a subagent's report without verification.
- New opencode config (agents, etc.) requires an opencode restart to load.
- **Always work and commit on the `develop` branch.** Never commit directly to
  `master`/`main`. Create or check out `develop` before staging commits; open
  PRs from `develop` into the default branch when the user asks to merge.
