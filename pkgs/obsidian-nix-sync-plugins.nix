{ writeShellScriptBin, obsidian-plugins }:
writeShellScriptBin "obsidian-nix-sync-plugins" ''
  set -euo pipefail
  vault="''${1:-}"
  if [ -z "$vault" ]; then
    echo "usage: obsidian-nix-sync-plugins /path/to/vault" >&2
    exit 2
  fi
  dest="$vault/.obsidian"
  mkdir -p "$dest/plugins"
  cp -f ${obsidian-plugins}/share/obsidian/community-plugins.json "$dest/community-plugins.json"
  for id in document-comments track-changes remote-ssh ghostty-terminal; do
    rm -rf "$dest/plugins/$id"
    mkdir -p "$dest/plugins/$id"
    # Copy not symlink: Obsidian on some platforms rejects store symlinks.
    cp -a ${obsidian-plugins}/share/obsidian/plugins/$id/. "$dest/plugins/$id/"
  done
  echo "Synced Nix Obsidian plugins into $dest"
''
