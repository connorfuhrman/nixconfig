# Home-manager: install store-backed opencode bundle + activation.
# Package definitions live in pkgs/ (see modules/pkgs.nix overlay).
{ ... }:
{
  flake.modules.homeManager.nono-opencode =
    {
      pkgs,
      lib,
      ...
    }:
    let
      bundle = pkgs.opencode;
    in
    {
      # Only the store bundle on PATH — no hand-maintained config trees required.
      home.packages = [ bundle ];

      home.sessionVariables = {
        OPENCODE_ORCHESTRATION_MODELS = "${bundle}/share/opencode-nix/orchestration-models.json";
      };

      # Ephemeral state dirs + remove any mutable nono profile that could shadow truth.
      # Config is NOT installed under ~/.config/opencode — OPENCODE_CONFIG points at store.
      home.activation.opencodeNixStoreOnly = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p \
          "$HOME/.cache/opencode" \
          "$HOME/.local/share/opencode" \
          "$HOME/.local/state/opencode" \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/nono/profile-drafts"

        # Kill mutable profile copies nono may have written (never use them).
        prof="''${XDG_CONFIG_HOME:-$HOME/.config}/nono/profiles/opencode-nix.json"
        if [ -e "$prof" ] && [ ! -L "$prof" ]; then
          rm -f "$prof"
        fi
        # Optional discovery symlink → store (read-only); wrapper ignores this path.
        mkdir -p "$(dirname "$prof")"
        ln -sfn "${bundle}/share/opencode-nix/nono-profile.json" "$prof"

        # Point ~/.config/opencode at store tree for tools that ignore OPENCODE_CONFIG.
        # Replace any mixed HM/mutable tree with pure symlinks into the bundle.
        oc="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
        mkdir -p "$oc"
        ln -sfn "${bundle}/share/opencode-nix/opencode.json" "$oc/opencode.json"
        ln -sfn "${bundle}/share/opencode-nix/orchestration-models.json" "$oc/orchestration-models.json"
        ln -sfn "${bundle}/share/opencode-nix/agent" "$oc/agent"
        ln -sfn "${bundle}/share/opencode-nix/skills" "$oc/skills"
        ln -sfn "${bundle}/share/opencode-nix/plugins" "$oc/plugins"
      '';
    };
}
