# Overlay: custom packages for this monorepo.
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
  nono = final.callPackage ./nono.nix { };
  nono-profiles = final.callPackage ./nono-profiles.nix { };
  pi-plan-mode = final.callPackage ./pi-plan-mode.nix { };
  pi-subagents = final.callPackage ./pi-subagents.nix { };
  pi-goal = final.callPackage ./pi-goal.nix { };
  pi-nono = final.callPackage ./pi-nono.nix { };
  pi-tasks = final.callPackage ./pi-tasks.nix { };
  pi-usage = final.callPackage ./pi-usage.nix { };
  pi-diff-review = final.callPackage ./pi-diff-review.nix { };
  pi-worktree = final.callPackage ./pi-worktree.nix { };
  pi-lsp = final.callPackage ./pi-lsp.nix { };
}
