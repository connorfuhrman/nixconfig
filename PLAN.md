# NixOS on Asahi Linux — MacBook Pro 14" (M2 Pro/Max)

**Full plan: flake-based NixOS definition + hardware installation runbook**

- Target machine: MacBook Pro 14" 2023, M2 Pro (t6020 / Mac14,9 / Mac14,5) or M2 Max (t6021 / Mac14,10 / Mac14,6)
- Config style: Nix flake, KDE Plasma 6 (Wayland)
- Support layer: [`nix-community/nixos-apple-silicon`](https://github.com/nix-community/nixos-apple-silicon)
- Sources this plan is built from: the repo's README, `docs/uefi-standalone.md` (2025-11-18 guide), `docs/release-notes.md`, the module sources under `apple-silicon-support/`, the Asahi Linux docs site (feature support M2, partitioning cheatsheet, open-OS interop, m1n1 user guide, broken-software/16K-pages), and the Asahi installer source.

---

## Part 0 — How this all fits together (read first)

### The boot chain on Apple Silicon

```
SecureROM → iBoot1 → iBoot2 (per-OS Preboot)
  → m1n1 stage 1   (lives in a 2.5 GB "stub" macOS APFS container; enrolled as a
                    "fully untrusted OS" boot object under Permissive Security)
    → m1n1 stage 2 + device trees + U-Boot   (one file: m1n1/boot.bin on the ESP)
      → systemd-boot (\EFI\BOOT\BOOTAA64.EFI on the ESP)
        → Linux kernel (linux-asahi) → NixOS
```

Consequences that shape everything in this plan:

1. **macOS must stay installed.** The Asahi installer, m1n1 updates/repair, and
   future resizes all require an internal macOS. You cannot boot Apple Silicon
   purely from USB.
2. **One EFI System Partition per OS** (no EFI variable store exists on this
   platform, so no shared-ESP boot entries). The Asahi installer creates a
   dedicated 500 MB ESP for NixOS; we mount it at `/boot`.
   `boot.loader.efi.canTouchEfiVariables` must be `false`.
3. **Peripheral firmware** (Wi-Fi, Bluetooth, trackpad multitouch, ASMedia xHCI)
   is non-redistributable. The Asahi installer extracts it from Apple's IPSW into
   `vendorfw/firmware.cpio` on the ESP. Our flake must reference it explicitly
   (the module's default auto-detection is impure and breaks under flakes).
4. **Two partitions must never be touched**: the first (`Apple_APFS_ISC` /
   `iBootSystemContainer`, ~524 MB) and the last (`Apple_APFS_Recovery` /
   `RecoveryOSContainer`, ~5.4 GB). Damaging either can require a DFU restore
   from a second computer and may wipe all data.
5. **The installer leaves 38 GB free inside macOS** for future macOS upgrades.
   You need disk space for Linux *on top of* that reserve.

### What the `nixos-apple-silicon` module does for you

Importing `nixos-apple-silicon.nixosModules.apple-silicon-support` and setting
`hardware.asahi.enable = true` gives you, automatically:

- `boot.kernelPackages = linux-asahi` (currently 7.0.x, 16K pages, Rust enabled)
  — set unconditionally, **do not set `boot.kernelPackages` yourself**
- U-Boot + m1n1 stage 2 installed to the ESP via the bootloader's `extraFiles`,
  re-installed per NixOS generation (rollback-safe)
- Its package overlay injected via `nixpkgs.overlays` (`mkBefore`) — **do not
  add the overlay manually**
- Peripheral firmware extraction from `vendorfw/firmware.cpio` into
  `hardware.firmware`
- Sound: PipeWire + WirePlumber + `asahi-audio` UCM config + `speakersafetyd`
  (speaker protection daemon) — **it force-disables PulseAudio; never enable it**
- Ambient light sensor (`hardware.sensor.iio.enable`, iio-sensor-proxy)
- `boot.loader.efi.canTouchEfiVariables = mkForce false`, `schedutil` governor,
  required initrd modules, Asahi kernel params

Things that used to need options and **no longer do** (they are removed and will
hard-error): GPU/Mesa (`useExperimentalGPUDriver`, `experimentalGPUInstallMode`),
`withRust`, `addEdgeKernelConfig`. Mainline Mesa (≥25.1) ships the Asahi GPU
driver; `hardware.graphics.enable = true` is all you need.

### Hardware reality check — MBP 14" M2 Pro/Max

| Works (on `linux-asahi`) | Does NOT work |
|---|---|
| Internal mini-LED display (local dimming; **no ProMotion/HDR**) | Thunderbolt / USB4 devices |
| GPU accel (OpenGL 4.6 / Vulkan via Mesa) | **Any external display over USB-C / DP alt-mode** |
| **HDMI port** (video; audio is preview-quality, needs a kernel param) | Studio Display (it's a Thunderbolt display) |
| Wi-Fi, Bluetooth | Touch ID (blocked on SEP driver) |
| Speakers (with speakersafetyd DSP), 3.5 mm jack, mics | Hardware video decode/encode (WIP/TBA) |
| Webcam, keyboard + backlight, trackpad, battery, brightness | Wake-on-LAN |
| Suspend (s2idle), good idle power (Asahi cpuidle hack) | |
| SD card reader | |

Also: **Xorg is effectively unsupported — Wayland only.** Plasma 6 on Wayland is
the flagship Asahi desktop. And the machine runs **16K page** kernels: some
prebuilt/Electron-ish binaries segfault instantly; nixpkgs-built software is
fine. (`muvm` is the escape hatch for 4K-page-only software.)

---

## Part 1 — Key design decisions (and why)

| # | Decision | Rationale |
|---|---|---|
| D1 | Flake input pinned to `github:nix-community/nixos-apple-silicon/release-2025-11-18`, the **same tag as the installer ISO** you will boot | If your config's `linux-asahi` derivation is bit-identical to the one in the ISO's store, `nixos-install` reuses it instead of compiling a kernel in the RAM-constrained live environment. This is the single biggest install-time risk reducer. |
| D2 | `nixpkgs.follows = "nixos-apple-silicon/nixpkgs"` | Your whole system uses exactly the nixpkgs the Asahi module was tested against (required for D1 to work; avoids module/nixpkgs skew). Post-install you can decouple. |
| D3 | Vendor `firmware.cpio` into the flake at `firmware/` and set `hardware.asahi.peripheralFirmwareDirectory` explicitly | The module's default detection (`builtins.pathExists /boot/vendorfw`) is impure and fails flake evaluation. **The blob is non-redistributable: keep the repo private, never push it publicly.** |
| D4 | systemd-boot, ESP mounted at `/boot` | Matches the upstream guide; U-Boot chainloads `\EFI\BOOT\BOOTAA64.EFI`; generations appear in the systemd-boot menu for rollback. |
| D5 | Single ext4 root partition in the free space the Asahi installer leaves | Simplest safe layout. LUKS is possible (optional sidebar in Part 4) but adds initrd complexity; skip for first bring-up. |
| D6 | KDE Plasma 6 + SDDM (Wayland), NetworkManager with **iwd** backend | Wayland-only platform; wpa_supplicant can't do WPA3-SAE on Broadcom chips. |
| D7 | `zramSwap` + temporary swapfile during install | Kernel builds are RAM-hungry; base M2 Pro ships 16 GB. |
| D8 | Prebuilt installer ISO from GitHub Releases, transferred with `dd` | Building the ISO yourself requires a Linux builder; the releases are bit-reproducible. `unetbootin` et al. are unsupported. |

---

## Part 2 — AI coding agent work plan (build the NixOS definition)

The agent builds this repository (suggested root: the current `~/asahi-linux`
directory). Everything in Part 2 is doable **without the hardware**, on the
macOS host, as long as Nix with flakes is installed (`nix --version`,
`nix.settings.experimental-features = [ nix-command flakes ]`).

### Task 0 — Ground rules (violating any of these breaks eval or the machine)

1. **Never** set `boot.kernelPackages` (module forces `linux-asahi`).
2. **Never** set `services.pulseaudio.enable = true` (module forces it off; PipeWire is set up for you).
3. **Never** add the Asahi overlay to `nixpkgs.overlays` yourself (module injects it).
4. **Never** use removed options: `hardware.asahi.useExperimentalGPUDriver`, `experimentalGPUInstallMode`, `withRust`, `addEdgeKernelConfig`.
5. **Always** set `hardware.asahi.enable = true` explicitly (default emits an eval warning).
6. Keep `boot.loader.efi.canTouchEfiVariables = false`.
7. Wi-Fi backend: `iwd`, not wpa_supplicant.
8. No X11 display/desktop managers. Wayland only.
9. No `services.fprintd` — Touch ID does not work.
10. Do not enable `hardware.apple.touchBar` — the 14" has no Touch Bar (that option is for the 13" M2 MBP only).
11. Do not pin/override Mesa yourself; the module's overlay already carries the one needed Mesa pin.
12. `firmware/firmware.cpio` must exist and be **git-tracked** before any `nix flake` command (flakes ignore untracked files). A placeholder is committed now; the real blob replaces it on the target during install (dirty worktree is fine; untracked is not).

### Task 1 — Repository layout

```
asahi-linux/
├── PLAN.md                      # this file
├── README.md                    # short: what this repo is + pointer to PLAN.md
├── flake.nix
├── flake.lock                   # generated in Task 5
├── firmware/
│   ├── README.md                # explains the blob, provenance, license warning
│   └── firmware.cpio            # PLACEHOLDER until install; replaced on target
├── hosts/
│   └── mbp14/
│       ├── default.nix
│       └── hardware-configuration.nix   # template; regenerated on target
└── modules/
    ├── asahi.nix
    ├── desktop.nix
    └── system.nix
```

### Task 2 — `flake.nix`

```nix
{
  description = "NixOS (Asahi Linux) for MacBook Pro 14\" M2 Pro/Max";

  inputs = {
    # D1: pin to the same release as the installer ISO that gets dd'ed to USB.
    # Post-install, this can be moved to a newer tag or `main`.
    nixos-apple-silicon.url =
      "github:nix-community/nixos-apple-silicon/release-2025-11-18";

    # D2: use the nixpkgs revision the Asahi module was tested with.
    nixpkgs.follows = "nixos-apple-silicon/nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-apple-silicon }: {
    nixosConfigurations.mbp14 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-apple-silicon.nixosModules.apple-silicon-support
        ./hosts/mbp14
      ];
    };
  };
}
```

### Task 3 — `hosts/mbp14/default.nix`

```nix
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/asahi.nix
    ../../modules/desktop.nix
    ../../modules/system.nix
  ];

  networking.hostName = "mbp14";

  # Set to the NixOS release current at first install; NEVER change afterwards.
  system.stateVersion = "25.11";
}
```

### Task 4 — `modules/asahi.nix` (the Apple Silicon core)

```nix
{ ... }:

{
  # Explicitly enable Apple Silicon support (kernel, boot chain, firmware,
  # sound stack are all pulled in by the module).
  hardware.asahi.enable = true;

  # D3: non-redistributable peripheral firmware (Wi-Fi, BT, multitouch, xHCI),
  # vendored into this flake. Replaced with the real blob during installation
  # (see PLAN.md Part 4). Keep this repo private.
  hardware.asahi.peripheralFirmwareDirectory = ../../firmware;

  # Bootloader on the Asahi-created ESP (mounted at /boot by
  # hardware-configuration.nix). U-Boot has no EFI variable store.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # GPU: mainline Mesa has shipped the Asahi driver for ages. Nothing else
  # is required (no overlays, no removed experimental options).
  hardware.graphics.enable = true;

  # Sound: DO NOT configure PipeWire/PulseAudio here — the module sets up
  # PipeWire + WirePlumber + asahi-audio UCM + speakersafetyd, and hard-forces
  # services.pulseaudio.enable = false.

  # ---- Optional hardware tunables (uncomment deliberately) ----

  # Reclaim the full panel height at the cost of the notch covering the top
  # of the screen (default: notch area is cropped off). Renamed from
  # apple_dcp.show_notch in kernel 6.18.
  # boot.kernelParams = [ "appledrm.show_notch=1" ];

  # HDMI audio over the built-in HDMI port (preview quality, can be glitchy).
  # boot.kernelParams = [ "appledrm.hdmi_audio=1" ];

  # If ` and < are swapped on your keyboard layout:
  # boot.extraModprobeConfig = ''
  #   options hid_apple iso_layout=0
  # '';
}
```

### Task 5 — `modules/desktop.nix`

```nix
{ pkgs, ... }:

{
  # KDE Plasma 6 on Wayland. Xorg is unsupported on Apple Silicon.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Wi-Fi via NetworkManager + iwd (wpa_supplicant lacks WPA3-SAE on Broadcom).
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  hardware.bluetooth.enable = true;

  # Ambient light sensor is already enabled by the Asahi module
  # (hardware.sensor.iio.enable), used by Plasma auto-brightness.

  environment.systemPackages = with pkgs; [
    firefox
    kdePackages.kate
    kdePackages.ark
    git
    vim
    htop
  ];
}
```

### Task 6 — `modules/system.nix`

```nix
{ ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # D7: compressed RAM swap — noticeably helps on 16 GB during kernel rebuilds.
  zramSwap.enable = true;

  time.timeZone = "America/New_York";      # adjust
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.connor = {                    # adjust username
    isNormalUser = true;
    description = "Connor";
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "changeme";           # change immediately on first login
  };

  services.openssh.enable = true;           # optional but handy for rescue
}
```

### Task 7 — `hosts/mbp14/hardware-configuration.nix` (template)

Commit this template; the install runbook **regenerates it on the target** and
overwrites the file. Do not hand-invent UUIDs.

```nix
# TEMPLATE — overwritten by nixos-generate-config output during installation
# (PLAN.md Part 4, Phase C). Committed only so the flake evaluates beforehand.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # The Asahi-created 500 MB ESP. PARTUUID is discovered on target via
  # /proc/device-tree/chosen/asahi,efi-system-partition.
  fileSystems."/boot" = {
    device = "/dev/disk/by-partuuid/REPLACE-ON-TARGET";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" "nofail" ];
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
```

### Task 8 — `firmware/README.md` and placeholder

- `firmware/README.md`: state that `firmware.cpio` is extracted from Apple's
  IPSW by the Asahi installer onto the ESP (`vendorfw/firmware.cpio`), is
  **non-redistributable**, must never be pushed to a public remote, and is
  refreshed via the Asahi installer's "Rebuild vendor firmware package" option.
- Create a small placeholder `firmware/firmware.cpio` (any content — it only
  needs to exist for pre-install evaluation). It is replaced in Phase C.
- `git init`, `git add -A` (the placeholder must be tracked — flakes ignore
  untracked files). Do **not** gitignore `firmware.cpio`; instead keep the
  whole repo private.

### Task 9 — Validate without the hardware (on the macOS host)

```sh
cd ~/asahi-linux
nix flake lock                 # resolves + pins inputs (no builds needed)
nix flake show                 # sanity: shows nixosConfigurations.mbp14
# Full evaluation of the system closure (does NOT build anything; works on
# aarch64-darwin despite targeting aarch64-linux):
nix eval .#nixosConfigurations.mbp14.config.system.build.toplevel.drvPath
# Confirm the right kernel/bootloader got selected:
nix eval .#nixosConfigurations.mbp14.config.boot.kernelPackages.kernel.version
nix eval .#nixosConfigurations.mbp14.config.boot.loader.efi.canTouchEfiVariables   # must be false
```

Acceptance criteria for the agent:

- [ ] All eval commands succeed; no warnings about `hardware.asahi.enable` defaulting
- [ ] Kernel version reported is an `asahi` kernel (7.0.x era)
- [ ] `canTouchEfiVariables` evaluates to `false`
- [ ] No option errors mentioning removed options or pulseaudio conflicts
- [ ] `flake.lock` committed

---

## Part 3 — Human prerequisites (before touching the Mac)

1. **Backup the Mac** (Time Machine). Partition-table mistakes can wipe everything.
2. macOS **13.5 or later**, logged in as an **admin** user, on the local console
   (not SSH-only). Update macOS first if needed.
3. Free disk space: the Asahi installer enforces a **38 GB reserve for macOS**,
   and you want **≥ 100 GB for NixOS** with a desktop (the Nix store grows;
   kernel rebuilds happen locally). So plan for ≈ 140 GB of currently-free space.
   If the installer complains about missing space, Time Machine snapshots are
   usually the cause (`tmutil listlocalsnapshots /`).
4. A **USB flash drive ≥ 1 GB** you can fully erase.
5. Optional but recommended: a second USB stick (FAT32) carrying this repo, or
   network access to a private git remote.
6. Know that external displays only work via the **HDMI port**. USB-C/DisplayPort
   monitors will not work — don't plan the install around one.

---

## Part 4 — Installation runbook (human, on the hardware)

### Phase A — Prepare the installer USB (on any computer)

1. Download the ISO asset from
   `https://github.com/nix-community/nixos-apple-silicon/releases/tag/release-2025-11-18`
   (the `nixos-*.iso`; grab the checksum file too if present and verify).
2. Write it to the flash drive — raw `dd` to the **whole disk device**, nothing else:
   ```sh
   diskutil list                      # identify the USB stick, e.g. /dev/disk4
   diskutil unmountDisk /dev/disk4
   sudo dd if=nixos-*.iso of=/dev/rdisk4 bs=4m status=progress
   ```
   (`rdisk` = raw device, much faster. `unetbootin`/Etcher-style tools are unsupported.)

### Phase B — Create the UEFI boot environment (in macOS)

1. In Terminal.app:
   ```sh
   curl https://alx.sh | sh
   ```
2. Choose **r** (resize an existing partition): enter the new macOS size such
   that ≥ 100 GB is freed for Linux (the installer keeps its own 38 GB macOS
   reserve logic; follow its prompts, wait patiently — resizing takes minutes,
   don't touch the machine).
3. Choose **f** (install an OS into free space) → **UEFI environment only**
   (m1n1 + U-Boot + ESP) → name it **NixOS**.
4. Let it finish; note the printed **APFS VGID** and **EFI PARTUUID**. Press
   enter to shut down.
5. **Boot into 1TR (One True recoveryOS)**: with the machine fully off, press
   and **hold** the power button; release at "Loading startup options…".
   Select the **NixOS** volume → you'll get a recovery dialog; authenticate with
   your macOS admin credentials → when prompted, choose to **set a custom boot
   object / Permissive Security**, enter the same credentials again → reboot.
6. Success looks like: the machine reboots into **U-Boot** (Asahi + U-Boot logos
   on screen). Hold power to shut down. If you boot-loop into recovery instead,
   shut fully down and redo step 5 carefully (single sustained hold; pick the
   NixOS volume; authenticate).

> What this did: created a 2.5 GB stub macOS container (m1n1 stage 1 enrolled
> as the boot object, Permissive Security), a 500 MB ESP (m1n1 stage 2 + DTBs +
> U-Boot + `vendorfw/firmware.cpio`), and left the rest of the freed space empty.
> Your real macOS is untouched and still boots normally.

### Phase C — Install NixOS (booting the USB installer)

1. Insert the installer USB stick. Power on — U-Boot should boot from USB
   automatically. If it tries the internal disk instead: press a key to stop
   autoboot → `bootmenu` → select `usb 0` (if empty: `bootmenu -e`; if that
   command is missing:
   `setenv boot_targets "usb" ; setenv bootmeths "efi" ; boot`).
   GRUB appears; take the default entry. A mount race occasionally fails boot —
   just reboot and retry.
2. At the console: `sudo su`. Optional bigger font: `setfont ter-v32n`.
3. Connect Wi-Fi (iwd is running):
   ```
   iwctl
   [iwd]# station wlan0 scan
   [iwd]# station wlan0 connect <SSID>
   [iwd]# quit
   ```
   Fix the clock (TLS breaks otherwise): `systemctl restart systemd-timesyncd`
4. **Partition — DANGER ZONE.** Create exactly one partition in the free space.
   Never touch partition 1 (`iBootSystemContainer`) or the last one
   (`RecoveryOSContainer`); no automated partitioners.
   ```
   sgdisk /dev/nvme0n1 -n 0:0 -s      # use all free space for one new partition
   sgdisk /dev/nvme0n1 -p             # find the NEW partition: type 8300,
                                      # typically second-to-last, e.g. p5
   mkfs.ext4 -L nixos /dev/nvme0n1pX  # X = the new partition number
   ```
5. Mount root and the Asahi ESP:
   ```
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot
   ```
6. **Add swap for the build** (kernel may compile locally; 16 GB RAM is tight):
   ```
   dd if=/dev/zero of=/mnt/.swapfile bs=1M count=16384 status=progress
   chmod 600 /mnt/.swapfile && mkswap /mnt/.swapfile && swapon /mnt/.swapfile
   ```
7. Generate hardware config and place the flake:
   ```
   nixos-generate-config --root /mnt          # writes /mnt/etc/nixos/*
   ```
   Now get this repo onto the target — either `git clone` your **private**
   remote, or copy it from the second USB stick — to
   `/mnt/etc/nixos/asahi-nixos`. Then:
   ```
   # a) Real peripheral firmware into the flake (replaces the placeholder):
   cp /mnt/boot/vendorfw/firmware.cpio /mnt/etc/nixos/asahi-nixos/firmware/firmware.cpio
   # b) Real hardware configuration into the flake:
   cp /mnt/etc/nixos/hardware-configuration.nix \
      /mnt/etc/nixos/asahi-nixos/hosts/mbp14/hardware-configuration.nix
   ```
   Notes: if the repo arrived as a git checkout, modified-but-tracked files are
   fine (flakes only reject *untracked* files) — `firmware.cpio` was committed
   as a placeholder, so you're good. The generated `configuration.nix` is NOT
   used; only `hardware-configuration.nix`. (The non-flake guide's step of
   copying `apple-silicon-support` into `/etc/nixos` does not apply — the flake
   input provides it.)
8. Install (this downloads several GB; with the pinned inputs the kernel should
   be reused from the ISO's store rather than compiled):
   ```
   cd /mnt/etc/nixos/asahi-nixos
   export NIX_CONFIG="experimental-features = nix-command flakes"
   nixos-install --flake .#mbp14
   ```
   Set the root password when prompted. Errors are safe — fix the config and
   re-run the same command.
9. `reboot`. U-Boot → systemd-boot → NixOS → SDDM. Log in as your user
   (`changeme` — change it now: `passwd`), Plasma Wayland session.

### Phase D — First-boot verification checklist

| Check | How | Expected |
|---|---|---|
| Kernel | `uname -r` | `7.0.x-asahi` |
| Wi-Fi | Plasma applet / `iwctl station wlan0 show` | connects, stable |
| Sound (start at LOW volume) | `systemctl status speakersafetyd`, play audio | daemon active; speaker + headphone jack work |
| GPU | `glxinfo -B` (`mesa-utils`) / `vulkaninfo --summary` | Apple AGX M2 Pro/Max renderer |
| Suspend | close lid, or `systemctl suspend`, then wake | sleeps and resumes; battery drain low |
| Brightness/keyboard backlight | Fn keys | work |
| Webcam | e.g. `kamoso` or a browser test | works |
| Bluetooth | Plasma applet | pairs |
| Battery | `upower -d` | sane values, discharging/charging |
| HDMI | plug a monitor into the HDMI port | picture (audio needs the optional kernel param) |
| Ambient light | `monitor-sensor` | ALS readings change |
| Rollback | reboot, systemd-boot menu | older generations listed |

### Phase E — Post-install setup & maintenance

1. Move the repo somewhere user-owned, e.g. `~/src/asahi-nixos`, and commit the
   real firmware blob locally: `git add firmware/firmware.cpio && git commit`.
   **Keep the repo private — the blob is non-redistributable.** Rebuilds:
   `sudo nixos-rebuild switch --flake ~/src/asahi-nixos#mbp14`.
2. Delete the install-time swapfile if you don't want it
   (`swapoff / .swapfile && rm /.swapfile`; zram remains).
3. **Updating NixOS + Asahi support together:** bump the `nixos-apple-silicon`
   input (newer `release-*` tag, or `main` for bleeding edge), then
   `nix flake update && sudo nixos-rebuild switch --flake .#mbp14 && sudo reboot`.
   Kernel/U-Boot/m1n1-stage-2 updates take effect after reboot; the kernel will
   compile natively on the M2 (fast enough with zram). If a boot goes wrong,
   pick a previous generation in the systemd-boot menu.
4. **Peripheral firmware refresh** (occasionally needed after macOS updates):
   in macOS run `curl https://alx.sh | sh` → "Rebuild vendor firmware package"
   → reboot into NixOS → copy `/boot/vendorfw/firmware.cpio` over the repo's
   `firmware/firmware.cpio` → rebuild.
5. **m1n1 stage 1** updates (rare): Asahi installer's `m` option from macOS.
6. **Dual boot:** hold the power button at power-on for the boot picker; click
   an OS → Continue (boot once) or hold Option → Always Use (set default).
7. **Rescue:** boot the installer USB (`bootmenu` in U-Boot), mount the root and
   ESP partitions (Phase C step 5, without reformatting), then `nixos-enter` or
   re-run `nixos-install --flake ... --no-root-password`. Generations make this
   non-destructive to user data.
8. **Catastrophic** (won't boot anything, SOS light / exclamation screen): DFU
   restore from a second computer with `idevicerestore --latest`
   (`sudo idevicerestore --latest`, device in DFU per Apple's docs). Erases
   everything if a plain revive fails — hence backups.

### Optional variant — LUKS encryption

Only if you want it from day one (harder to retrofit): in Phase C step 4,
`cryptsetup luksFormat /dev/nvme0n1pX`, `cryptsetup open` it as `cryptroot`,
put ext4 inside, and add to `hardware-configuration.nix`:
`boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-label/...";`
`/boot` (the ESP) always stays unencrypted; there is no Secure-Boot analogue on
this platform, so LUKS protects data at rest only.

---

## Part 5 — Gotchas reference (for both agent and human)

- **16K pages:** some prebuilt binaries (old Chrome/Electron, Android tooling,
  `hardened_malloc`, Waydroid, `trezord`) segfault instantly. Prefer
  nixpkgs-built software; `muvm` (4K-page microVM, in nixpkgs) is the escape hatch.
- **USB-C ports are USB2/USB3 only.** No DP alt-mode, no Thunderbolt devices.
  The HDMI port is your only external display path.
- **No ProMotion/HDR** on the internal mini-LED; local dimming works.
- **Notch:** default crops the top rows; `appledrm.show_notch=1` reclaims them
  (notch then covers your panel's top area).
- **U-Boot USB quirks:** fancy hubs/multi-function devices may not work
  pre-boot; a hub with an empty integrated SD reader can hard-reset the machine.
  Plug the installer stick in directly.
- **After kernel/Mesa upgrades, reboot** before judging GPU problems.
- **Electron apps blank after update:** delete their `GPUCache` dir.
- **Volume safety:** never bypass/omit speakersafetyd; uncalibrated full-scale
  output can physically damage the speakers.
- **Install-loop into recovery** during Phase B: shut down fully and redo the
  1TR step precisely; recovery path is the installer's `p` (repair) option.
- **`apple_dcp.*` params are renamed `appledrm.*`** (kernel 6.18+). Old blog
  posts use the former.

## Done-when definition

The project is complete when: the repo in Part 2 evaluates cleanly (Part 2
Task 9 checklist), the runbook in Part 4 has been executed through Phase E, the
Phase D verification table is fully green, and the system rebuilds from its own
flake with `nixos-rebuild switch` on the machine itself.
