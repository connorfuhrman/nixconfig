{ ... }:
let
  # Immutable Obsidian community plugins (store-backed).
  # "Ghotty" → Ghostty Terminal (community id: ghostty-terminal).
  pluginSpecs = {
    document-comments = {
      owner = "kylemcd";
      repo = "obsidian-document-comments";
      rev = "0.1.12";
      hash = "sha256-Gmh/L2T+ZxPR5+YbqY1J7gez5+sIJwnp5FNO4IainDU=";
      id = "document-comments";
    };
    track-changes = {
      owner = "philphilphil";
      repo = "obsidian-track-changes";
      rev = "1.9.0";
      hash = "sha256-WvXfrhamMmwuy3h3uQf12FTm96ZJJhGJZWQ8RCEXBBI=";
      id = "track-changes";
    };
    remote-ssh = {
      owner = "sotashimozono";
      repo = "obsidian-remote-ssh";
      rev = "1.1.7";
      hash = "sha256-Abvi1h4jq0SmHdFBXPL9qwph//nQl+SPqWrCEP/1U0k=";
      id = "remote-ssh";
    };
    ghostty-terminal = {
      owner = "lavs9";
      repo = "obsidian-ghostty-terminal";
      rev = "0.2.1";
      hash = "sha256-0gRgKI1eDtrQZ/LMbnBNgz2oN8ORp6p9DgFO/N43I+s=";
      id = "ghostty-terminal";
    };
  };

  communityPluginsJson = builtins.toJSON [
    "document-comments"
    "track-changes"
    "remote-ssh"
    "ghostty-terminal"
  ];

  mkPlugin = pkgs: name: spec:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "obsidian-plugin-${spec.id}";
      version = spec.rev;
      src = pkgs.fetchurl {
        url = "https://github.com/${spec.owner}/${spec.repo}/archive/refs/tags/${spec.rev}.tar.gz";
        hash = spec.hash;
      };
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/obsidian/plugins/${spec.id}
        # GitHub archive root is repo-rev/
        shopt -s dotglob nullglob
        for f in main.js manifest.json styles.css; do
          if [ -f "$f" ]; then cp "$f" $out/share/obsidian/plugins/${spec.id}/; fi
        done
        # some archives nest one directory
        if [ ! -f $out/share/obsidian/plugins/${spec.id}/manifest.json ]; then
          d="$(find . -maxdepth 2 -name manifest.json | head -n1)"
          test -n "$d"
          cp "$(dirname "$d")/main.js" $out/share/obsidian/plugins/${spec.id}/ 2>/dev/null || true
          cp "$(dirname "$d")/manifest.json" $out/share/obsidian/plugins/${spec.id}/
          cp "$(dirname "$d")/styles.css" $out/share/obsidian/plugins/${spec.id}/ 2>/dev/null || true
        fi
        test -f $out/share/obsidian/plugins/${spec.id}/manifest.json
        runHook postInstall
      '';
      meta = {
        description = "Obsidian plugin ${spec.id} (immutable)";
        homepage = "https://github.com/${spec.owner}/${spec.repo}";
      };
    };

  mkPluginsRoot = pkgs:
    let
      plugins = builtins.mapAttrs (n: spec: mkPlugin pkgs n spec) pluginSpecs;
    in
    pkgs.symlinkJoin {
      name = "obsidian-plugins-nix";
      paths = builtins.attrValues plugins;
      postBuild = ''
        mkdir -p $out/share/obsidian
        cp ${pkgs.writeText "community-plugins.json" communityPluginsJson} \
          $out/share/obsidian/community-plugins.json
      '';
    };

  # Install plugins into a vault's .obsidian/ (symlinks to store).
  mkSyncScript = pkgs: root:
    pkgs.writeShellScriptBin "obsidian-nix-sync-plugins" ''
      set -euo pipefail
      vault="''${1:-}"
      if [ -z "$vault" ]; then
        echo "usage: obsidian-nix-sync-plugins /path/to/vault" >&2
        exit 2
      fi
      dest="$vault/.obsidian"
      mkdir -p "$dest/plugins"
      cp -f ${root}/share/obsidian/community-plugins.json "$dest/community-plugins.json"
      for id in document-comments track-changes remote-ssh ghostty-terminal; do
        rm -rf "$dest/plugins/$id"
        mkdir -p "$dest/plugins/$id"
        # Copy not symlink: Obsidian on some platforms rejects store symlinks.
        cp -a ${root}/share/obsidian/plugins/$id/. "$dest/plugins/$id/"
      done
      echo "Synced Nix Obsidian plugins into $dest"
    '';
in
{
  perSystem = { pkgs, ... }: {
    packages.obsidian-plugins = mkPluginsRoot pkgs;
    packages.obsidian-nix-sync-plugins = mkSyncScript pkgs (mkPluginsRoot pkgs);
  };

  flake.modules.homeManager.obsidian-config = { pkgs, lib, ... }:
    let
      root = mkPluginsRoot pkgs;
      sync = mkSyncScript pkgs root;
    in
    {
      # Canonical store mirror under XDG data — transportable reference tree.
      home.file.".local/share/obsidian-nix/community-plugins.json".source =
        "${root}/share/obsidian/community-plugins.json";
      home.file.".local/share/obsidian-nix/plugins".source =
        "${root}/share/obsidian/plugins";

      home.packages = [ root sync ];

      # On activation, refresh plugins in known vaults if present.
      home.activation.obsidianNixPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for vault in "$HOME/nixconfig" "$HOME/Documents/nixconfig"; do
          if [ -d "$vault/.obsidian" ]; then
            ${sync}/bin/obsidian-nix-sync-plugins "$vault" || true
          fi
        done
      '';
    };
}
