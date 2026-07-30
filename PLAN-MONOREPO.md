# PLAN-MONOREPO — Extend asahi-linux into a Nix monorepo (NixOS + nix-darwin)

**Executor:** `ling-implementer` subagent (openrouter/inclusionai/ling-3.0-flash:free)
**Planner/supervisor:** primary opencode agent
**Repo root:** `/Users/connorfuhrman/asahi-linux` (NOT a git repo — no git commands)

This plan is a precise, file-by-file specification. Apply it **exactly**. Do not
add, remove, or improvise anything beyond what is written here.

---

## 1. Goals

- Keep the dendritic flake-parts pattern (`flake.nix` → `systems/<arch>/` → modules + hosts).
- Add a new NixOS host: **nuc** (Intel Nuc, `x86_64-linux`, headless server).
- Add a new nix-darwin host: **macbook** (`aarch64-darwin`).
- Restructure `modules/` into `modules/nixos/` + `modules/darwin/`.
- Fix two latent bugs in the current tree (see §3).

## 2. User decisions (already made — do not revisit)

| Decision | Value |
|---|---|
| Darwin architectures | `aarch64-darwin` only |
| Nuc role | Headless server (no GUI) |
| Module layout | `modules/nixos/` + `modules/darwin/` |
| Hostnames | `nuc`, `macbook` |

## 3. Latent bugs being fixed (context, do not skip)

1. **`hosts/mbp14/hardware-configuration.nix` is never imported.** Neither
   `systems/aarch64-linux/default.nix` nor `hosts/mbp14/default.nix` imports it,
   so `fileSystems."/"` is undefined and full system evaluation fails with
   "The 'fileSystems' option does not specify your root file system."
   Fixed in §5 by adding `./hardware-configuration.nix` to the host imports.
2. **`hardware.asahi.peripheralFirmwareDirectory = ../../firmware` in
   `modules/asahi.nix` resolves one level too high** (to `~/firmware`).
   After the file moves to `modules/nixos/asahi.nix`, the same literal text
   `../../firmware` resolves correctly to `<repo>/firmware`. So the line's
   **text stays identical** — the move itself is the fix. Validation check #4
   proves it resolves.

## 4. Target tree after this plan

```
asahi-linux/
├── flake.nix                            # MODIFIED
├── systems/
│   ├── default.nix                      # MODIFIED
│   ├── aarch64-linux/default.nix        # MODIFIED
│   ├── x86_64-linux/default.nix         # NEW
│   └── aarch64-darwin/default.nix       # NEW
├── modules/
│   ├── nixos/
│   │   ├── asahi.nix                    # MOVED from modules/asahi.nix (text unchanged)
│   │   ├── desktop.nix                  # MOVED from modules/desktop.nix (unchanged)
│   │   ├── system.nix                   # MOVED from modules/system.nix (unchanged)
│   │   └── server.nix                   # NEW
│   └── darwin/
│       └── system.nix                   # NEW
├── hosts/
│   ├── mbp14/default.nix                # MODIFIED (paths + hw-config import)
│   ├── mbp14/hardware-configuration.nix # unchanged
│   ├── nuc/default.nix                  # NEW
│   ├── nuc/hardware-configuration.nix   # NEW (template)
│   └── macbook/default.nix              # NEW
├── firmware/                            # unchanged
├── lib/                                 # unchanged
├── PLAN.md                              # unchanged (Asahi install runbook)
├── README.md                            # MODIFIED
└── .gitignore                           # unchanged
```

## 5. Exact file contents

### 5.1 `flake.nix` — REPLACE ENTIRE FILE

```nix
{
  description = "Nix monorepo — NixOS (Asahi Linux M2 MacBook Pro, Intel Nuc) + nix-darwin — dendritic flake-parts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon/release-2025-11-18";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, nixos-apple-silicon, nix-darwin, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import ./systems;

      perSystem = { system, pkgs, ... }: {
        packages = { };
      };

      flake = {
        nixosConfigurations.mbp14 = (import ./systems/aarch64-linux {
          inherit nixpkgs nixos-apple-silicon;
          inherit (nixpkgs) lib;
          inputs = inputs;
        }).nixosConfigurations.mbp14;

        nixosConfigurations.nuc = (import ./systems/x86_64-linux {
          inherit nixpkgs;
          inherit (nixpkgs) lib;
          inputs = inputs;
        }).nixosConfigurations.nuc;

        darwinConfigurations.macbook = (import ./systems/aarch64-darwin {
          inherit nixpkgs nix-darwin;
          inherit (nixpkgs) lib;
          inputs = inputs;
        }).darwinConfigurations.macbook;
      };
    };
}
```

### 5.2 `systems/default.nix` — REPLACE ENTIRE FILE

```nix
[ "aarch64-linux" "x86_64-linux" "aarch64-darwin" ]
```

### 5.3 `systems/aarch64-linux/default.nix` — REPLACE ENTIRE FILE

Module list shrinks: the host dir imports its own modules (dendritic style).

```nix
{ nixpkgs, nixos-apple-silicon, lib, inputs, ... }: {
  nixosConfigurations.mbp14 = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      nixos-apple-silicon.nixosModules.apple-silicon-support
      ../../hosts/mbp14
    ];
  };
}
```

### 5.4 `systems/x86_64-linux/default.nix` — NEW FILE

```nix
{ nixpkgs, lib, inputs, ... }: {
  nixosConfigurations.nuc = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ../../hosts/nuc
    ];
  };
}
```

### 5.5 `systems/aarch64-darwin/default.nix` — NEW FILE

```nix
{ nixpkgs, nix-darwin, lib, inputs, ... }: {
  darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = { inherit inputs; };
    modules = [
      ../../hosts/macbook
    ];
  };
}
```

### 5.6 Move modules (no content edits)

```sh
mkdir -p modules/nixos modules/darwin
mv modules/asahi.nix modules/nixos/asahi.nix
mv modules/desktop.nix modules/nixos/desktop.nix
mv modules/system.nix modules/nixos/system.nix
```

**Do not edit the contents of these three files.** In particular,
`modules/nixos/asahi.nix` keeps the line
`hardware.asahi.peripheralFirmwareDirectory = ../../firmware;`
verbatim — at its new depth that path now correctly resolves to `<repo>/firmware`.

### 5.7 `modules/nixos/server.nix` — NEW FILE

```nix
{ pkgs, ... }:

{
  # Headless server baseline. Layered on top of modules/nixos/system.nix.

  services.openssh = {
    enable = true;
    settings = {
      # Password auth stays enabled until SSH keys are deployed
      # (users.users.connor.initialPassword in system.nix is the bootstrap path).
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    curl
    wget
  ];
}
```

### 5.8 `modules/darwin/system.nix` — NEW FILE

```nix
{ pkgs, ... }:

{
  # Shared nix-darwin baseline for all macOS hosts.

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # nix-darwin manages the Nix daemon. Set to false if macOS Nix was
  # installed with the Determinate Systems installer instead.
  nix.enable = true;

  # Required by nix-darwin for user-scoped options; must be the macOS username.
  system.primaryUser = "connor";

  users.users.connor.home = "/Users/connor";

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    htop
  ];
}
```

### 5.9 `hosts/mbp14/default.nix` — REPLACE ENTIRE FILE

```nix
{ ... }:

{
  imports = [
    ../../modules/nixos/asahi.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/system.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "mbp14";
  system.stateVersion = "25.11";
}
```

### 5.10 `hosts/nuc/default.nix` — NEW FILE

```nix
{ ... }:

{
  imports = [
    ../../modules/nixos/system.nix
    ../../modules/nixos/server.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "nuc";
  system.stateVersion = "25.11";
}
```

### 5.11 `hosts/nuc/hardware-configuration.nix` — NEW FILE (template)

```nix
# TEMPLATE — replace with `nixos-generate-config` output on the Nuc.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partuuid/REPLACE-WITH-ESP-PARTUUID";
    fsType = "vfat";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
```

### 5.12 `hosts/macbook/default.nix` — NEW FILE

```nix
{ ... }:

{
  imports = [
    ../../modules/darwin/system.nix
  ];

  networking.hostName = "macbook";

  # nix-darwin state version is an integer (unlike NixOS's string).
  system.stateVersion = 5;
}
```

### 5.13 `README.md` — REPLACE ENTIRE FILE

```markdown
# asahi-linux

Nix monorepo (dendritic flake-parts): NixOS and nix-darwin host definitions.

## Hosts

| Host | Platform | Type | Notes |
|---|---|---|---|
| `mbp14` | `aarch64-linux` | NixOS | Asahi Linux on MacBook Pro 14" M2 Pro/Max |
| `nuc` | `x86_64-linux` | NixOS | Intel Nuc, headless server |
| `macbook` | `aarch64-darwin` | nix-darwin | macOS device |

## Layout

- `systems/<arch>/default.nix` — one file per platform, declares the configurations for that architecture.
- `modules/nixos/` — shared NixOS modules (`system.nix` base, `desktop.nix`, `server.nix`, `asahi.nix`).
- `modules/darwin/` — shared nix-darwin modules.
- `hosts/<name>/` — per-host config; imports the modules it needs.
- `firmware/` — Asahi peripheral firmware (vendored; keep repo private).

## Rebuild

```sh
# on mbp14 or nuc (NixOS):
sudo nixos-rebuild switch --flake .#mbp14
sudo nixos-rebuild switch --flake .#nuc

# on macbook (first time, bootstraps nix-darwin):
nix run nix-darwin -- switch --flake .#macbook
# thereafter:
darwin-rebuild switch --flake .#macbook
```

See [PLAN.md](./PLAN.md) for the Asahi hardware install runbook.
```

## 6. Non-goals — DO NOT do any of these

- Do NOT modify `PLAN.md`, `firmware/`, `lib/`, `.gitignore`, or
  `hosts/mbp14/hardware-configuration.nix`.
- Do NOT change any option values inside the moved modules
  (`asahi.nix`, `desktop.nix`, `system.nix`) — move only.
- Do NOT add home-manager, sops-nix, deploy-rs, disko, or any other inputs.
- Do NOT rename the repo directory.
- Do NOT run `git init`, `git add`, `git commit`, or any git mutation.
- Do NOT run `nixos-rebuild`, `darwin-rebuild`, `nix build`, or any build
  command. Evaluation only (`flake show`, `nix eval`).
- Do NOT touch `flake.lock` by hand — it is updated automatically by the
  validation commands below.
- Do NOT edit `.opencode/` files (that is tooling config, not repo content).

## 7. Validation (run from `/Users/connorfuhrman/asahi-linux`)

Nix on this machine needs experimental features enabled per-command. Run
exactly these, in order. Checks 1–8 MUST pass.

```sh
NIX="nix --extra-experimental-features nix-command\ flakes"
```
(If your shell cannot set that variable, paste the flags literally into each
command: `nix --extra-experimental-features 'nix-command flakes' ...`)

```sh
# 1. Flake structure — output must show nixosConfigurations.mbp14,
#    nixosConfigurations.nuc, and darwinConfigurations.macbook.
nix --extra-experimental-features 'nix-command flakes' flake show .

# 2. Asahi regression check → must print: true
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.mbp14.config.hardware.asahi.enable

# 3. hardware-configuration import bug fix → must print: "/dev/disk/by-label/nixos"
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.mbp14.config.fileSystems."/".device

# 4. Firmware path resolves → must print a "/nix/store/..." path (NOT an error)
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.mbp14.config.hardware.asahi.peripheralFirmwareDirectory

# 5. Nuc hostname → must print: "nuc"
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.nuc.config.networking.hostName

# 6. Nuc platform → must print: "x86_64-linux"
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.nuc.config.nixpkgs.hostPlatform

# 7. Mac hostname → must print: "macbook"
nix --extra-experimental-features 'nix-command flakes' eval .#darwinConfigurations.macbook.config.networking.hostName

# 8. Darwin state version → must print: 5
nix --extra-experimental-features 'nix-command flakes' eval .#darwinConfigurations.macbook.config.system.stateVersion
```

Optional (report result, failure acceptable — full system closure evaluation
is heavy and may hit unrelated issues):

```sh
nix --extra-experimental-features 'nix-command flakes' eval .#darwinConfigurations.macbook.config.system.build.toplevel.drvPath
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.nuc.config.system.build.toplevel.drvPath
```

## 8. Failure handling

- If a MUST-pass check (1–8) fails: read the error, fix ONLY the file(s)
  implicated, re-run. Maximum 3 fix attempts per check.
- If still failing after 3 attempts: STOP. Do not redesign. Report the exact
  command, the exact error output, and what you tried.
- Note: `flake show`/`eval` will fetch the new `nix-darwin` input from GitHub
  and update `flake.lock` automatically — that is expected, not an error.

## 9. Final report (what the executor must return)

1. List of files created / modified / moved.
2. Output of validation checks 1–8 (the actual printed values).
3. Output (or error) of the optional checks.
4. Any deviations from this plan (there should be none — if a deviation was
   necessary, justify it explicitly).
