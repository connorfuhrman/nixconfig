# Overlay: custom packages for this monorepo.
# final is the fixed-point — callPackage auto-wires sibling attrs (nono, cm, …).
final: prev: {
  nono = final.callPackage ./nono.nix { };
  opencode-bin = final.callPackage ./opencode-bin.nix { };
  cm = final.callPackage ./cm.nix { };

  opencode-goal-plugin = final.callPackage ./opencode-goal-plugin.nix { };

  opencode = final.callPackage ./opencode-nix-bundle.nix { };
  # Alias kept for AGENTS.md / muscle memory (same derivation as opencode).
  opencode-config = final.opencode;

  opencode-nix-profile = final.opencode.passthru.profile;
  opencode-orchestration-models = final.opencode.passthru.modelsFile;
  opencode-orchestration-test = final.callPackage ./opencode-orchestration-test.nix { };

  opencode-skill-document-comments = final.opencode.passthru.skills.document-comments;
  opencode-skill-document-review = final.opencode.passthru.skills.document-review;
  opencode-skill-orchestration = final.opencode.passthru.skills.orchestration;
  opencode-skill-nono-sandbox = final.opencode.passthru.skills.nono-sandbox;

  obsidian-plugins = final.callPackage ./obsidian-plugins.nix { };
  obsidian-nix-sync-plugins = final.callPackage ./obsidian-nix-sync-plugins.nix { };

  agent-tools = final.symlinkJoin {
    name = "agent-tools";
    paths = with final; [
      ripgrep fd jq ast-grep fzf tree delta bat gh
    ];
  };

  hermes-share = final.callPackage ./hermes-share.nix { };
  hermes-cli = final.callPackage ./hermes.nix { };
  hermes-gateway = final.callPackage ./hermes-gateway.nix { hermes = final.hermes-cli; };
  hermes = final.callPackage ./hermes-nix-bundle.nix { };
}
