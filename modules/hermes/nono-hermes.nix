# Home-manager: Nono-wrapped Hermes. Importing enables it (no mkEnableOption).
{ ... }:
{
  flake.modules.homeManager.nono-hermes =
    {
      pkgs,
      lib,
      ...
    }:
    let
      bundle = pkgs.hermes;
    in
    {
      home.packages = [ bundle ];

      home.sessionVariables = {
        HERMES_NIX_ROOT = "${bundle}/share/hermes-nix";
        HERMES_OP_VAULT = "op://Private/hermes";
      };

      home.activation.hermesNixStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        xdg_cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
        mkdir -p \
          "$HOME/.hermes/profiles" \
          "$HOME/.hermes/shared" \
          "$HOME/.cache/hermes" \
          "$xdg_cfg/nono/profiles" \
          "$xdg_cfg/nono/profile-drafts"

        ln -sfn "${bundle}/share/hermes-nix/nono-profile.json" \
          "$xdg_cfg/nono/profiles/hermes-nix.json"

        if [ -e "$HOME/.local/bin/hermes" ] && [ ! -L "$HOME/.local/bin/hermes" ]; then
          mv -f "$HOME/.local/bin/hermes" "$HOME/.local/bin/hermes-upstream-unwrapped"
        fi
        mkdir -p "$HOME/.local/bin"
        ln -sfn "${bundle}/bin/hermes" "$HOME/.local/bin/hermes"
        ln -sfn "${bundle}/bin/hermes-gateway" "$HOME/.local/bin/hermes-gateway"
        rm -f \
          "$HOME/.local/bin/concierge" \
          "$HOME/.local/bin/food" \
          "$HOME/.local/bin/travel" \
          "$HOME/.local/bin/hermes-tutor"
      '';
    };
}
