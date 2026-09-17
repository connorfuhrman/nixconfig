# Overlay: custom packages for this monorepo.
# pi, nono, and the pi-* extension packages come from the pi-config flake
# (inputs.pi-config.overlays.default) — do not duplicate them here.
final: prev: {
  obsidian-plugins = final.callPackage ./obsidian-plugins.nix { };
  obsidian-nix-sync-plugins = final.callPackage ./obsidian-nix-sync-plugins.nix { };
  cursor-cloud-setup = final.callPackage ./cursor-cloud-setup.nix { };
  mac-mini-buildkite-install-token = final.callPackage ./mac-mini-buildkite-install-token.nix { };
  mac-mini-buildkite-install-origin-ssh =
    final.callPackage ./mac-mini-buildkite-install-origin-ssh.nix
      { };
  origin = final.callPackage ./origin.nix { };
  podman-docker-compat = final.callPackage ./podman-docker-compat.nix { };
}
