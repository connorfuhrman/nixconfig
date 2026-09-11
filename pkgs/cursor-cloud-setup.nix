{ writeShellScriptBin, jq }:
writeShellScriptBin "cursor-cloud-setup" ''
  set -euo pipefail

  template_json="${./cursor-cloud/environment.json}"
  template_sh="${./cursor-cloud/nix-home.sh}"
  jq="${jq}/bin/jq"

  usage() {
    cat <<'EOF'
  usage: cursor-cloud-setup
         cursor-cloud-setup init [--dir DIR] [--force] [--extra-install CMD]

  Default: realize ubuntu@cursor-cloud activationPackage and run activate.
  init:    write .cursor/environment.json and .cursor/nix-home.sh into DIR.
  EOF
  }

  resolve_flake() {
    if [ -n "''${NIXCONFIG_FLAKE:-}" ]; then
      printf '%s' "$NIXCONFIG_FLAKE"
    elif [ -f flake.nix ] && [ -d modules/home ]; then
      printf '%s' "."
    else
      printf '%s' "github:connorfuhrman/nixconfig/develop"
    fi
  }

  activate() {
    local flake out
    flake="$(resolve_flake)"
    out="$(nix build --no-link --print-out-paths \
      "''${flake}#homeConfigurations.\"ubuntu@cursor-cloud\".activationPackage")"
    "$out/activate"
  }

  init_cmd() {
    local dir="." force=0 extra=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --dir)
          if [ "$#" -lt 2 ]; then
            echo "cursor-cloud-setup: --dir requires a path" >&2
            exit 2
          fi
          dir="$2"
          shift 2
          ;;
        --force)
          force=1
          shift
          ;;
        --extra-install)
          if [ "$#" -lt 2 ]; then
            echo "cursor-cloud-setup: --extra-install requires a command" >&2
            exit 2
          fi
          extra="$2"
          shift 2
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "cursor-cloud-setup init: unknown argument: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
    done

    local dest_json dest_sh
    dest_json="$dir/.cursor/environment.json"
    dest_sh="$dir/.cursor/nix-home.sh"

    if [ -e "$dest_json" ] || [ -e "$dest_sh" ]; then
      if [ "$force" -ne 1 ]; then
        echo "cursor-cloud-setup: refusing to overwrite $dir/.cursor (pass --force)" >&2
        exit 1
      fi
    fi

    mkdir -p "$dir/.cursor"
    # Templates are store-copied 0444; drop dest first so --force can rewrite.
    rm -f "$dest_json" "$dest_sh"
    if [ -n "$extra" ]; then
      "$jq" --arg extra "$extra" \
        '.install = (.install + "\n" + $extra)' \
        "$template_json" >"$dest_json"
    else
      cp -f "$template_json" "$dest_json"
      chmod u+w "$dest_json"
    fi
    cp -f "$template_sh" "$dest_sh"
    chmod 0755 "$dest_sh"
    echo "wrote $dest_json"
    echo "wrote $dest_sh"
  }

  case "''${1:-}" in
    "" )
      activate
      ;;
    init)
      shift
      init_cmd "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "cursor-cloud-setup: unknown command: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
''
