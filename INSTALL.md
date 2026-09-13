# Installing NixOS (Asahi Linux) on the MacBook Pro 14" (mbp14)

This guide is **Asahi / mbp14 only**. For Intel NUC and other x86_64 targets,
build the generic installer `nix build .#iso` — see README. Do not use
`installation-cd-minimal` on Apple Silicon.

This guide installs NixOS with Apple Silicon support ("Asahi Linux") on the
MacBook Pro 14" M2 Pro/Max, alongside macOS (dual boot), using this flake.

**Read this first.** Partitioning mistakes on Apple Silicon Macs can make the
machine unbootable and unrecoverable without a second computer and a DFU
restore. Make a full backup of macOS (Time Machine) before you start.

## What you need

| Item | Notes |
|---|---|
| MacBook Pro 14" M2 Pro/Max (the target, "mbp14") | macOS 12.3+, admin account, ≥ 60 GB free disk |
| Mac mini ("mac-mini") on the same network | Apple Silicon; serves as the aarch64-linux builder |
| USB flash drive ≥ 1 GB | Will be fully erased |
| This repository | On the dev machine; copied to the Mac mini in step 1 |
| ~2 hours | Most of it is waiting |

**Why the Mac mini?** Everything for Asahi (installer ISO, the NixOS system
closure, the Asahi kernel) is `aarch64-linux`. Until the installer boots on the
MacBook, no `aarch64-linux` machine exists — so the Mac mini runs a small
NixOS VM (`nix.linux-builder`) that builds those artifacts on demand. The
installer ISO itself can also simply be downloaded (step 2, Option A), but the
builder remains useful for rebuilding ISOs and pre-building the laptop's
system closure later.

## 1. One-time: set up the Mac mini builder

1. **Install Nix** on the Mac mini using the official installer (NOT the
   Determinate Systems installer — nix-darwin manages the Nix daemon itself):

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. **Enable Remote Login** on the Mac mini: System Settings → General →
   Sharing → Remote Login → on (allow your user).

3. **Copy this repo to the Mac mini** (it is not a git repo — copy the files),
   run on the dev machine:

   ```sh
   rsync -a --exclude '.opencode' ~/nixconfig/ connorfuhrman@mac-mini:~/nixconfig/
   (`mac-mini` is the Tailscale name; before Tailscale is set up on both machines, use `mac-mini.local` or the mini's LAN IP.)
   ```

4. **Apply the mac-mini configuration** (installs nix-darwin and enables the
   linux-builder VM), on the Mac mini:

   ```sh
    cd ~/nixconfig
    nix run nix-darwin -- switch --flake .#mac-mini
    ```

 5. **Smoke-test the builder** — this compiles a Linux binary inside the VM:

    ```sh
    nix build --system aarch64-linux nixpkgs#hello
    ```

   If that prints a store path, the Mac mini can build anything for
   `aarch64-linux`.

## 2. Get the NixOS installer ISO (choose one)

**Option A — download the prebuilt ISO (recommended, nothing to build).**
The `nixos-apple-silicon` project publishes automatically built,
bit-for-bit reproducible installer ISOs on its
[Releases page](https://github.com/nix-community/nixos-apple-silicon/releases).
Download the latest ISO (this flake pins `release-2025-11-18`; a newer ISO is
fine — the ISO only needs to boot, the installed system comes from this
flake). Unzip it if necessary.

**Option B — build the ISO on the Mac mini** (uses the builder from step 1):

```sh
cd ~/nixconfig
nix build --system aarch64-linux .#asahi-iso -o installer -L
```

The ISO appears at `installer/iso/nixos-*.iso`. Expect this to take a while
on first run (the builder VM downloads or compiles the Asahi kernel and
friends; the nixos-apple-silicon binary cache is used automatically).

`.#asahi-iso` re-exports `nixos-apple-silicon`'s `installer-bootstrap`
(`packages.aarch64-linux.asahi-iso`). Do not use the generic x86_64
`.#iso` on Apple Silicon.

## 3. Write the ISO to the USB drive (on any Mac)

```sh
diskutil list                     # identify the USB drive, e.g. /dev/disk4 — CHECK TWICE
diskutil unmountDisk /dev/diskN
sudo dd if=/path/to/nixos-*.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

Write to the whole device (`/dev/rdiskN`), not a partition. Do not use
balenaEtcher, unetbootin, or similar — only `dd` produces a bootable result.

## 4. Prepare the MacBook: the Asahi UEFI environment

In **macOS Terminal** on the MacBook (admin account):

```sh
curl https://alx.sh | sh
```

1. Enter your admin password; do **not** enable expert mode.
2. Choose **r** (resize an existing partition): shrink macOS, leaving at
   least 60 GB of free space for NixOS. Wait — resizing takes minutes.
3. Choose **f** (install an OS into free space) → **UEFI environment only**
   → name it **NixOS**.
4. Let it finish, read the final advice, and let it shut down.
5. Hold the power button to enter the boot picker, select **NixOS**, follow
   the recovery prompts (admin password), and choose to set a custom boot
   object / permissive security when asked. Reboot when prompted.

You should land in **U-Boot** (Asahi Linux and U-Boot logos). Hold the power
button to shut down.

## 5. Boot the installer and partition the disk

1. Insert the USB drive, power on. U-Boot boots from USB automatically. If it
   doesn't: press a key when prompted to stop autoboot, run `bootmenu`, and
   pick `usb 0` (if empty: `bootmenu -e`).
2. Let GRUB's default entry boot. At the console, run `sudo su`.
   (If the font is tiny: `setfont ter-v32n`.)

> **DANGER.** Do not touch the first partition (`iBootSystemContainer`) or
> the last (`RecoveryOSContainer`), and do not reformat the EFI partition.
> Damaging them can brick the Mac without a DFU restore from a second
> computer.

3. Create the root partition in the free space and note its number:

   ```sh
   sgdisk /dev/nvme0n1 -n 0:0 -s
   sgdisk /dev/nvme0n1 -p        # find the new 8300-type partition, e.g. p5
   ```

4. Format it — the label **must** be `nixos` (this flake mounts
   `/dev/disk/by-label/nixos`):

   ```sh
   mkfs.ext4 -L nixos /dev/nvme0n1pX     # replace X with your partition number
   ```

5. Mount everything:

   ```sh
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot
   ```

   The second mount is the EFI system partition the Asahi installer created.
   **Do not format it** — it contains m1n1, U-Boot, and the firmware.

## 6. Firmware, this repo, and the hardware configuration

Still on the installer, as root:

1. **Network** — WiFi via `iwctl` (or plug in Ethernet/USB tethering):

   ```sh
   iwctl
   [iwd]# station wlan0 scan
   [iwd]# station wlan0 connect <SSID>
   [iwd]# quit
   ```

2. **Get this repo onto the installer** (pick one):

   ```sh
# from the Mac mini (over the LAN — the installer is not on the tailnet):
    scp -r connorfuhrman@mac-mini.local:~/nixconfig /root/nixconfig
   # or: copy it to a second USB stick on the Mac mini, plug it in,
   #     then: mkdir /media && mount /dev/sdX1 /media && cp -r /media/nixconfig /root/
   ```

3. **Replace the placeholder firmware with the real files.** The Asahi
   installer extracted them onto the EFI partition in step 4; flakes cannot
   reference the ESP impurely, so they are vendored into the repo:

   ```sh
   rm /root/nixconfig/firmware/firmware.cpio   # placeholder
   cp /mnt/boot/asahi/all_firmware.tar.gz /mnt/boot/asahi/kernelcache* /root/nixconfig/firmware/
   ```

4. **Generate the real hardware configuration** and replace the template:

   ```sh
   nixos-generate-config --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix /root/nixconfig/modules/hosts/mbp14/_hardware-configuration.nix
   ```

   No edits are needed: the bootloader, firmware path, and Apple Silicon
   support all come from this flake's modules.

## 7. Install NixOS

```sh
cd /root/nixconfig
nixos-install --flake .#mbp14
```

This downloads a lot. The flake's `nixConfig` automatically enables the
nixos-apple-silicon binary cache (you run as root, which is trusted), so the
Asahi kernel is downloaded rather than compiled. Set a root password when
prompted, then:

```sh
reboot
```

Remove the USB drive. The machine now boots NixOS by default.

## 8. First boot and post-install

1. Log in as **connorfuhrman** with password **changeme**, then immediately run
   `passwd` and set a real password.
2. WiFi: `nmtui` (or the KDE Network applet). KDE Plasma 6 starts via SDDM.
3. Copy this repo to the laptop (from the Mac mini again, or git-init it
   locally) and rebuild from it:

   ```sh
   sudo nixos-rebuild switch --flake .#mbp14
   ```

4. Install the home configuration (Emacs + user env):

   ```sh
   nix run home-manager/master -- switch --flake .#connorfuhrman@mbp14
   # thereafter:
   home-manager switch --flake .#connorfuhrman@mbp14
   ```

5. To boot macOS: shut down, hold the power button for the boot picker,
   select macOS. (Hold Option and click "Always Use" to change the default.)

## 9. Optional: use the builder later

From the dev machine or the Mac mini, pre-build the laptop's full system
(for example to test changes without touching the laptop):

```sh
cd ~/nixconfig
nix build \
  --system aarch64-linux .#nixosConfigurations.mbp14.config.system.build.toplevel
```

## 10. Rescue, rollback, removal

- **Rollback:** pick a previous generation in the systemd-boot menu.
- **Reinstall without losing data:** boot the installer USB, remount the
  partitions as in step 5 (no reformatting), fix the config, then
  `nixos-install --no-root-password --no-channel-copy`.
- **Full removal** (restore disk to macOS-only): delete the stub, EFI, and
  root partitions from macOS `diskutil` and re-expand the APFS container —
  follow the "Removal" section of the upstream guide:
  <https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md>
