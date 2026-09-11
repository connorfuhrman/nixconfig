# Firmware blobs

The file `firmware.cpio` contains non-redistributable firmware (Broadcom Wi-Fi/
Bluetooth, ASMedia xHCI, Apple multitouch) extracted by the Asahi installer from
Apple's IPSW into `<ESP>/vendorfw/firmware.cpio`.

This repo copies the blob into the flake so that NixOS evaluation stays pure
and deterministic across flake rebuilds. The blob is non-redistributable.

## Important

- **Never push this file to a public repository.** Keep this repo private.
- The placeholder file committed here is a stand-in only; replace it with the
  real `firmware.cpio` during installation (see INSTALL.md).
- Firmware is refreshed by re-running the Asahi installer's "Rebuild vendor
  firmware package" option (from macOS), then recopying the new
  `firmware.cpio` into this directory and rebuilding.