# Home-manager: Nono-wrapped Hermes + concierge/food/travel/tutor profiles.
# Importing this module enables it (dendritic: no mkEnableOption).
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
      profiles = [
        "concierge"
        "food"
        "travel"
        "hermes-tutor"
      ];
    in
    {
      home.packages = [ bundle ];

      home.sessionVariables = {
        HERMES_NIX_ROOT = "${bundle}/share/hermes-nix";
      };

      home.activation.hermesNixStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        root="${bundle}/share/hermes-nix"
        hh="$HOME/.hermes"
        mkdir -p "$hh/profiles" "$hh/shared" "$HOME/.cache/hermes" \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/nono/profiles" \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/nono/profile-drafts"

        cp -f "$root/conventions.md" "$hh/shared/CONVENTIONS.md"
        ln -sfn "$root/nono-profile.json" \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/nono/profiles/hermes-nix.json"

        # Shadow any upstream installer `hermes` so PATH cannot pick unsandboxed.
        if [ -e "$HOME/.local/bin/hermes" ] && [ ! -L "$HOME/.local/bin/hermes" ]; then
          mv -f "$HOME/.local/bin/hermes" "$HOME/.local/bin/hermes-upstream-unwrapped"
        fi
        mkdir -p "$HOME/.local/bin"
        ln -sfn "${bundle}/bin/hermes" "$HOME/.local/bin/hermes"
        ln -sfn "${bundle}/bin/concierge" "$HOME/.local/bin/concierge"
        ln -sfn "${bundle}/bin/food" "$HOME/.local/bin/food"
        ln -sfn "${bundle}/bin/travel" "$HOME/.local/bin/travel"
        ln -sfn "${bundle}/bin/hermes-tutor" "$HOME/.local/bin/hermes-tutor"
        ln -sfn "${bundle}/bin/hermes-gateway" "$HOME/.local/bin/hermes-gateway"

        seed_file() {
          local src="$1"
          local dst="$2"
          local mode="''${3:-if-missing}"
          mkdir -p "$(dirname "$dst")"
          if [ "$mode" = "always" ]; then
            cp -f "$src" "$dst"
          elif [ ! -e "$dst" ]; then
            cp -f "$src" "$dst"
          fi
        }

        ${lib.concatMapStrings (n: ''
          pdir="$hh/profiles/${n}"
          src="$root/profiles/${n}"
          mkdir -p "$pdir/memories" "$pdir/skills" "$pdir/data"
          seed_file "$src/SOUL.md" "$pdir/SOUL.md" always
          seed_file "$src/config.yaml" "$pdir/config.yaml" if-missing
          seed_file "$src/profile.yaml" "$pdir/profile.yaml" always
          if [ -f "$src/memories/MEMORY.md" ]; then
            seed_file "$src/memories/MEMORY.md" "$pdir/memories/MEMORY.md" if-missing
            chmod u+w "$pdir/memories/MEMORY.md" 2>/dev/null || true
          fi
          if [ -d "$src/skills" ]; then
            cp -a "$src/skills/." "$pdir/skills/"
          fi
          if [ -f "$src/data/restaurants.json" ]; then
            seed_file "$src/data/restaurants.json" "$pdir/data/restaurants.json" if-missing
            chmod u+w "$pdir/data/restaurants.json" 2>/dev/null || true
          fi
        '') profiles}

        # Default HERMES_HOME gets Grok config if empty, but is not the front door.
        if [ ! -f "$hh/config.yaml" ]; then
          cp -f "$root/profiles/concierge/config.yaml" "$hh/config.yaml"
        fi
        if [ ! -f "$hh/SOUL.md" ]; then
          cat > "$hh/SOUL.md" <<'HERMES_DEFAULT_SOUL'
        # Default profile

        Do not use this profile as the front door. Run concierge (Nono-wrapped).
        All Hermes agents on this machine run under Nono.
        HERMES_DEFAULT_SOUL
        fi
      '';
    };
}
