# Home-manager: immutable Obsidian community plugins.
# Package bodies: pkgs/obsidian-plugins.nix, pkgs/obsidian-nix-sync-plugins.nix
{ ... }:
{
  flake.modules.homeManager.obsidian-config =
    {
      pkgs,
      lib,
      ...
    }:
    let
      root = pkgs.obsidian-plugins;
      sync = pkgs.obsidian-nix-sync-plugins;
    in
    {
      # Canonical store mirror under XDG data — transportable reference tree.
      home.file.".local/share/obsidian-nix/community-plugins.json".source =
        "${root}/share/obsidian/community-plugins.json";
      home.file.".local/share/obsidian-nix/plugins".source = "${root}/share/obsidian/plugins";

      home.packages = [
        root
        sync
      ];

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
