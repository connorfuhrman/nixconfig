{
  writeShellApplication,
  nono,
  hermes-unwrapped,
  hermes-share,
  agent-tools,
}:
writeShellApplication {
  name = "hermes";
  runtimeInputs = [
    nono
    agent-tools
  ];
  text = ''
    root="${hermes-share}/share/hermes-nix"
    hh="''${HERMES_HOME:-$HOME/.hermes}"
    xdg_cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
    mkdir -p \
      "$hh/profiles" \
      "$hh/shared" \
      "$HOME/.cache/hermes" \
      "$HOME/.local/share/hermes" \
      "$HOME/.local/state/hermes" \
      "$xdg_cfg/nono/profile-drafts" 2>/dev/null || true
    ln -sfn "$root/nono-profile.json" "$xdg_cfg/nono/profiles/hermes-nix.json" 2>/dev/null || true
    cp -f "$root/conventions.md" "$hh/shared/CONVENTIONS.md" 2>/dev/null || true

    seed_file() {
      local src="$1" dst="$2" mode="''${3:-if-missing}"
      mkdir -p "$(dirname "$dst")"
      if [ "$mode" = "always" ]; then
        cp -f "$src" "$dst"
      elif [ ! -e "$dst" ]; then
        cp -f "$src" "$dst"
      fi
    }

    for n in concierge food travel hermes-tutor; do
      src="$root/profiles/$n"
      dst="$hh/profiles/$n"
      mkdir -p "$dst/memories" "$dst/skills" "$dst/data"
      seed_file "$src/SOUL.md" "$dst/SOUL.md" always
      seed_file "$src/config.yaml" "$dst/config.yaml" if-missing
      seed_file "$src/profile.yaml" "$dst/profile.yaml" always
      if [ -f "$src/memories/MEMORY.md" ]; then
        seed_file "$src/memories/MEMORY.md" "$dst/memories/MEMORY.md" if-missing
        chmod u+w "$dst/memories/MEMORY.md" 2>/dev/null || true
      fi
      if [ -d "$src/skills" ]; then
        cp -a "$src/skills/." "$dst/skills/" 2>/dev/null || true
        chmod -R u+w "$dst/skills" 2>/dev/null || true
      fi
      if [ -f "$src/data/restaurants.json" ]; then
        seed_file "$src/data/restaurants.json" "$dst/data/restaurants.json" if-missing
        chmod u+w "$dst/data/restaurants.json" 2>/dev/null || true
      fi
    done

    extra=()
    if [ "$#" -ge 1 ]; then
      case "$1" in
        concierge|food|travel|hermes-tutor)
          extra=(-p "$1")
          shift
          ;;
      esac
    fi

    exec ${nono}/bin/nono run \
      --profile "$root/nono-profile.json" \
      --allow-cwd \
      --suppress-save-prompt "$HOME" \
      --suppress-save-prompt "$HOME/" \
      -- ${hermes-unwrapped}/bin/hermes "''${extra[@]}" "$@"
  '';
}
