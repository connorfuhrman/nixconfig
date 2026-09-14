# AGENTS.md

Nix monorepo: NixOS + nix-darwin + home-manager, structured with the **dendritic
flake-parts pattern**. This file is the authoritative orientation for agents
working in this repo.

## Hosts

| Host | Platform | Type | Status | Notes |
|---|---|---|---|---|
| `mbp14` | `aarch64-linux` | NixOS | **experimental** | Asahi Linux, MacBook Pro 14" M2 Pro/Max (KDE Plasma 6) |
| `nuc` | `x86_64-linux` | NixOS | **experimental** | Intel Nuc, headless server (plain — no clustering) |
| `nuc-cluster-head` | `x86_64-linux` | NixOS | **experimental** | Role closure on the nuc hardware — Ray head node |
| `nuc-cluster-worker` | `x86_64-linux` | NixOS | **experimental** | Role closure on the second Nuc — Ray worker |
| `rpi-cluster-head` | `aarch64-linux` | NixOS | **experimental** | Prototype Raspberry Pi head node (generalized `hosts/rpi/` template) |
| `macbook` | `aarch64-darwin` | nix-darwin | tested | macOS device |
| `mac-mini` | `aarch64-darwin` | nix-darwin | tested | Always-on server: Buildkite agent (`mac-mini-macos`), aarch64-linux builder (`nix.linux-builder`) + Roon Server |
| `cursor-cloud` | `x86_64-linux` | home-manager | **experimental** | Cursor Cloud Agent home only — user `ubuntu` |
| `connorfuhrman@mbp14` / `@nuc` / `@macbook` / `@mac-mini` | per host | home-manager | per host | standalone via `homeManager.standard` |
| `ubuntu@cursor-cloud` | `x86_64-linux` | home-manager | **experimental** | `homeManager.cursor-cloud` (base + coreutils + emacs) |

All hardware hosts run Tailscale and have 1Password installed (CLI everywhere;
GUI on mbp14 and darwin via nixpkgs). System and home username is
**`connorfuhrman`** on those machines. Exception: Cloud Agent home
`ubuntu@cursor-cloud` (`ubuntu` / `/home/ubuntu`). First-time Cloud Nix setup
for agents: [`.cursor/AGENTS.md`](.cursor/AGENTS.md).

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
- Home hosts import **`homeManager.standard`** (base + emacs + coreutils + gh +
  mosh + obsidian-config) — do not re-list those modules per host. Exception:
  `ubuntu@cursor-cloud` imports `homeManager.cursor-cloud` (base + coreutils +
  emacs only; no mosh / obsidian-config).
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
pkgs/                   custom packages (callPackage); overlay = pkgs/default.nix
                        (obsidian-*, cursor-cloud-setup, origin)
modules/pkgs.nix        flake.overlays.default + packages.* + lib.pkgsFor
modules/systems.nix     systems list: aarch64-linux, x86_64-linux, aarch64-darwin
modules/checks.nix      eval-only checks for every configuration (nix flake check)
modules/nixos/          NixOS features: system, desktop, server, asahi, onepassword, iso
modules/darwin/         nix-darwin features: system, linux-builder, buildkite, server, roon-server, onepassword, emacs-plus
modules/home/           homeManager: base, emacs, coreutils, gh, cursor, cursor-cloud, obsidian-config, standard
modules/generic/        class-agnostic features: tailscale, mac-mini-builder
modules/hosts/          host definitions, status metadata (+ _hardware-configuration.nix per NixOS host)
.cursor/AGENTS.md       AI-only Cursor Cloud first-time Nix setup (not human docs)
docs/                   human-facing notes (plans/, rfcs/, research/) — long answers go here
firmware/               vendored Asahi firmware — PRIVATE, never publish
INSTALL.md              human-facing Asahi install runbook for mbp14
README.md               human-facing overview (this repo is multi-host, not Asahi-only)
```

### Custom packages (`pkgs/` + overlay)

- **Package bodies** live in top-level `pkgs/<name>.nix` (callPackage style).
  Do **not** put `mkDerivation` builders inside home/system modules.
- **`pkgs/default.nix`** is the overlay (`final: prev: { … callPackage … }`).
- **`modules/pkgs.nix`** (flake-parts) exposes:
  - `flake.overlays.default`
  - `flake.lib.pkgsFor <system>` — nixpkgs + overlay (used by home configs)
  - `packages.<system>.*` — same attrs for `nix build .#…`
- **HM hosts** use `pkgs = config.flake.lib.pkgsFor "<system>"` (not bare
  `legacyPackages`) so modules can reference overlay packages.
- **NixOS/darwin** apply `nixpkgs.overlays = [ self.overlays.default ]` in
  `modules/{nixos,darwin}/system.nix`.

## Working in this repo

- **Flakes and `nix-command` are enabled** in system config
  (`nix.settings.experimental-features`). Use plain `nix flake` / `nix eval`.
- **Evaluation only — never build system closures.** No `nixos-rebuild`,
  `darwin-rebuild`, or `home-manager` from the dev machine. `nix flake check`
  and `nix eval` are the validation tools. CI (Buildkite) additionally
  **realizes** the three generic installer media (`.#iso`, `.#asahi-iso`,
  `.#rpi-iso`); x86_64 `.#iso` runs on hosted `linux-medium`, aarch64 images
  on `mac-mini-macos`.
- This **is** a git repo. Use feature branches targeting `main` (see Workflow). Do not
  force-push or commit secrets / `firmware/` blobs to a public remote.
- `flake show` displays `darwinConfigurations`, `homeConfigurations`,
  `homeModules`, and `modules` as type "unknown" — normal Nix behavior, not an
  error. Verify those outputs with `nix eval` instead.

### Standard validation suite (run after any structural change)

```sh
cd /Users/connorfuhrman/nixconfig
# primary gate: proves every configuration's derivations evaluate
# (live closures + installer ISO/SD variants).
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
nix eval .#nixosConfigurations.iso.config.system.build.isoImage.drvPath      # x86_64 installer ISO (eval only — do not nix build the image)
nix eval .#packages.x86_64-linux.iso.drvPath                                 # same derivation via packages.*
nix eval .#packages.aarch64-linux.asahi-iso.drvPath                          # Apple Silicon installer (eval only)
nix eval .#nixosConfigurations.rpi-iso.config.system.build.sdImage.drvPath   # Pi SD image (eval only)
nix eval .#nixosConfigurations.nuc.config.nix.buildMachines --apply 'ms: map (m: m.hostName) ms'  # ["mac-mini"]
nix eval .#nixosConfigurations.nuc-cluster-head.config.systemd.services --apply 's: builtins.filter (n: builtins.match "ray.*" n != null) (builtins.attrNames s)'  # ["ray-head"]
nix eval .#darwinConfigurations.macbook.config.system.stateVersion         # 5
nix eval .#darwinConfigurations.macbook.config.homebrew.enable             # true
nix eval .#darwinConfigurations.macbook.config.nix.distributedBuilds       # true
nix eval .#darwinConfigurations.mac-mini.config.nix.linux-builder.enable   # true
nix eval .#darwinConfigurations.mac-mini.config.users.users.buildkite-agent-macos.home  # "/private/var/lib/buildkite-agent-macos"
nix eval .#darwinConfigurations.mac-mini.config.services.buildkite-agents.macos.dataDir  # "/private/var/lib/buildkite-agent-macos"
nix eval .#homeConfigurations.\"ubuntu@cursor-cloud\".config.home.username # "ubuntu"
nix eval .#apps.x86_64-linux.cursor-cloud-setup.program
nix eval .#packages.x86_64-linux.origin.meta.mainProgram   # "origin"
```

## Gotchas (learned the hard way)

- **Flakes only see git-tracked files.** New files created by subagents are
  invisible to `nix flake check`/`nix eval` (import-tree runs against the
  store copy) until staged. Symptom: `attribute 'foo' missing` even though
  the file exists on disk. Always `git add` new files before validating.
- **Never force `config` in a top-level `assert` of a module.** A module whose
  attrset is gated behind `assert lib.assertMsg (config.x == …)` recurses
  infinitely: the assert forces `config.x` while the module fixpoint that
  defines it is still being computed. Use the lazy `assertions` option
  instead (checked after the fixpoint). See `modules/nixos/nuc-cluster.nix`.
- **Cluster roles are generalized; topology is one switch point.**
  `nixos.ray-head` / `nixos.ray-worker` (in `modules/nixos/cluster.nix`) are
  importable by ANY host; the worker joins `flake.cluster.headName` over
  Tailscale MagicDNS — change that one string to promote a different head.
  Pairwise LAN IPs and `nix.buildMachines` live in the role *host* closures
  (`nuc-cluster-head`, `nuc-cluster-worker`), not in the role modules. Plain
  `nuc` has NO clustering; booting a role closure on the same box is
  mutually exclusive with the plain closure (distinct hostName/Tailscale
  identity). The Thunderbolt iface is assumed `thunderbolt0` — verify on
  hardware with `ip link`.
- **`flake check` asserts evaluation, not buildability.** The checks in
  `modules/checks.nix` embed each configuration's `.drvPath` in a text file —
  they instantiate (fully evaluate) every closure but build nothing. Realizing
  closures happens on target hardware or the mac-mini builder. Check names must
  not contain `@` (invalid in store paths), hence `eval-home-connorfuhrman-mbp14`
  etc. Installer media checks use `isoImage.drvPath` / `sdImage.drvPath` the
  same way — eval only, except when explicitly asked to realize `.#iso`.
- **Installer media are generic**, not per-host variants. Three outputs in
  `modules/installer-media.nix`: `.#iso` (x86_64 `installation-cd-minimal`),
  `.#asahi-iso` (`nixos-apple-silicon` `installer-bootstrap`), `.#rpi-iso`
  (aarch64 `sd-image-aarch64-installer`). Helper: `flake.lib.mkGenericInstaller`
  in `modules/nixos/iso.nix`. Live host closures unchanged; pick the host at
  `nixos-install --flake /etc/nixconfig#<host>`.
- **Unfree packages:** 1Password is unfree; each platform's onepassword
  module sets a scoped `nixpkgs.config.allowUnfreePredicate` (must appear
  exactly once per configuration — multiple definitions of that option
  conflict). Do not add unfree packages without extending the predicate;
  never work around it with `--impure`/`NIXPKGS_ALLOW_UNFREE` in the
  validation suite.
- **Obsidian:** system package on all hosts; plugins (document-comments,
  track-changes, remote-ssh, ghostty-terminal) are Nix-pinned —
  `obsidian-nix-sync-plugins <vault>` or HM activation into `~/nixconfig`.
- **Cursor:** `homeManager.cursor` on `macbook` and `mac-mini` only — installs
  `pkgs.code-cursor` via `home.packages` (no `programs.vscode`). Unfree
  predicate scoped in the cursor HM module; Darwin system predicate extended in
  `darwin.onepassword`. Settings/extensions stay in Cursor's UI.
- **mosh:** client on all systems; `programs.mosh.enable` on NixOS servers
  (nuc); package on darwin server (mac-mini).
- **mac-mini linux-builder** advertises `aarch64-linux` + `x86_64-linux`
  (qemu-user binfmt in the builder VM). Clients use
  `generic.mac-mini-builder` with both systems.
  **VM parallelism:** `nix build --cores N` on the macOS Buildkite agent does
  not cap compiles inside `nix.linux-builder` — the guest's
  `nix.settings.cores` / `max-jobs` in `modules/darwin/linux-builder.nix` do
  (kernel builds use `$NIX_BUILD_CORES` from the builder VM). After changing
  that module, run `sudo darwin-rebuild switch --flake .#mac-mini` on the mini
  and `sudo launchctl kickstart -k system/org.nixos.linux-builder` so the VM
  picks up the new nix.conf (build #120 OOM'd with unset `cores` → make -j 8+).
- **mac-mini Buildkite** runs one self-hosted agent (`spawn=2`, names
  `%hostname-macos-%spawn`) on the Default cluster: `mac-mini-macos`
  (Darwin jobs). Linux Nix builds offload to `nix.linux-builder`
  as a remote builder (aarch64-linux native; x86_64-linux via qemu-user binfmt in
  the VM) — not a separate Buildkite agent. `docker#` / `docker run -v $PWD`
  works on this queue: jobs check out under `/Users/Shared/buildkite-agent-macos`
  (`build-path` / `plugins-path`) on the default applehv `/Users` virtiofs share so
  `docker run -v $PWD` works with no guest symlink. Agent home / `dataDir` stay
  `/private/var/lib/buildkite-agent-macos` — nix-darwin will not move an existing
  user's home (`/var` → `/private/var` on Darwin). Do not put checkout under
  `/var/lib` (guest ls/umount of `/private/var` hangs virtiofs) and do not add a
  nested virtiofs of the checkout. Origin SSH / `.gitconfig` live in that home.
  Job API is off (`bootstrap --no-job-api` + launchd `BUILDKITE_AGENT_NO_JOB_API=true`)
  because unix sockets cannot ride virtiofs and docker-buildkite-plugin
  bind-mounts `BUILDKITE_AGENT_JOB_API_SOCKET` when that env is set.
  `job-api=false` in extraConfig is not an agent-start key. Cluster agent token path:
  `/etc/buildkite-agent/cluster.token` (never in the Nix store). Install on
  mac-mini via `nix run .#mac-mini-buildkite-install-token` (reads `bkct_`
  token from 1Password account `aztec_fuhrmans`,
  `op://Private/Buildkite/credential`).
  Runbook: [`docs/plans/mac-mini-buildkite.md`](docs/plans/mac-mini-buildkite.md).
- **Homebrew modules must set `homebrew.enable = true`.** nix-darwin ignores
  taps/casks otherwise. `darwin.roon-server` enables it (and any other
  host that needs brew).
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
- **Emacs:** single `homeManager.emacs` module on every host — installs the
  flake-wrapped `emacs` (emacsWithPackages + `--init-directory`) and links
  `~/.config/emacs` to `emacs-config`. Darwin uses emacs-macport under that
  wrapper; do **not** rely on brew emacs-plus (package.el installs are
  disabled in the Nix prelude config). The emacs flake names ALL wrapped
  variants `emacs` (symlinkJoin) — distinguishable only by drvPath, not
  `p.name`. Consumed self-contained (does NOT follow our nixpkgs).
- **Remote builder:** `flake.modules.generic.mac-mini-builder` (client side)
  assumes existing passwordless SSH to host `mac-mini` as `connorfuhrman`
  (including for root / the Nix daemon). No dedicated `/etc/nix/*` key. The
  mini builds `aarch64-linux` and `x86_64-linux` (linux-builder + binfmt).
  Interactive SSH keys → 1Password agent long-term; see
  `docs/plans/1password-ssh-workplan.md`. Dual-NUC scale-out:
  `docs/rfcs/0001-dual-nuc-cluster.md`.
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

## Branch & commit discipline

- **Always work on a side branch.** Never commit directly to `master` or `main`.
  If the human does not specify a branch name, ask before creating one.
  Create feature branches (`feat/<name>`, `cursor/<name>`, etc.) from `main`.
  Open PRs from your branch into `main` when the human asks to merge.
- **Commit at discrete milestones.** Each commit should represent a complete,
  coherent unit of work — not half-finished edits. Resist the urge to commit
  after every tiny change; batch related changes together.
- **Attribute authorship correctly.** When committing, set your author identity
  to match the model you are, using an email at your organization's domain:
  - Claude → `Claude <claude@anthropic.com>`
  - Grok → `Grok <grok@xai.com>`
  - Qwen → `Qwen <qwen@alibaba-inc.com>`
  - Ling → `Ling <ling@inclusionai.com>`
  - Kimi → `Kimi <kimi@moonshot.cn>`
  Use `--author="Name <slug@org-domain>"` with `git commit --amend` when fixing
  prior commits that have wrong authorship.

## Workflow convention (user preference)

- Primary agent **plans and verifies**; mechanical implementation can be
  delegated to subagents with exact file-by-file specs.
- After delegation, the primary agent re-reads changed files and re-runs the
  validation suite itself. Never trust a subagent's report without verification.
- **Always work on a feature branch from `main`.** Never commit directly to
  `master`/`main`. Open PRs into `main` when the user asks to merge.
- **Long-form human output → Obsidian doc, not chat.** If the answer is more
  than a short paragraph / a few bullets (research, comparisons, runbooks,
  architecture notes, multi-section explanations), write a Markdown file under
  `docs/` (use `docs/plans/` for actionable workplans, `docs/rfcs/` for
  decisions, `docs/research/` for surveys and deep-dives) and reply in chat
  with **only** the path plus a 1–3 line summary. Use Document Comments
  (skill `document-comments`) when the human must decide or approve. Do **not**
  paste the full document body into the chat.
