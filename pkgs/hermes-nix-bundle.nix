# Store-backed hermes+nono wrapper. Inner CLI is hermes-unwrapped (flake input).
# Every PATH entry named hermes / concierge / food / travel / hermes-tutor
# execs nono — there is no convenient unsandboxed hermes.
{
  lib,
  runCommand,
  writeText,
  runtimeShell,
  nono,
  hermes-unwrapped,
  agent-tools,
}:
let
  profile = writeText "hermes-nix.json" (builtins.toJSON {
    extends = [ "default" ];
    meta = {
      name = "hermes-nix";
      version = "1.0.0";
      description = "Least-privilege Nono profile for all Hermes agents";
    };
    interactive = false;
    security = {
      signal_mode = "isolated";
      capability_elevation = false;
    };
    groups = {
      include = [
        "python_runtime"
        "node_runtime"
        "nix_runtime"
        "unlink_protection"
        {
          name = "user_caches_macos";
          when = "macos";
        }
        {
          name = "user_caches_linux";
          when = "linux";
        }
      ];
    };
    workdir = {
      access = "readwrite";
    };
    filesystem = {
      allow = [
        "$HOME/.hermes"
        "$HOME/.cache/hermes"
        "$HOME/.local/share/hermes"
        "$HOME/.local/state/hermes"
        "$HOME/.local/bin"
        "$NONO_CONFIG/profile-drafts"
        "$TMPDIR"
      ];
      read = [
        "/nix/store"
      ];
      suppress_save_prompt = [
        "~/"
        "$HOME"
      ];
    };
    network = {
      block = false;
      allow_domain = [
        "api.x.ai"
        "accounts.x.ai"
        "auth.x.ai"
        "x.ai"
        "www.x.ai"
        "grok.com"
        "www.grok.com"
        "x.com"
        "api.x.com"
        "models.dev"
        "hermes-agent.nousresearch.com"
        "nousresearch.com"
        "portal.nousresearch.com"
        "duckduckgo.com"
        "html.duckduckgo.com"
        "www.google.com"
        "google.com"
        "www.bing.com"
        "api.search.brave.com"
        "search.brave.com"
        "api.telegram.org"
        "core.telegram.org"
        "discord.com"
        "gateway.discord.gg"
        "cdn.discordapp.com"
        "discordapp.com"
        "media.discordapp.net"
        "github.com"
        "api.github.com"
        "objects.githubusercontent.com"
      ];
      custom_credentials = {
        xai = {
          upstream = "https://api.x.ai/v1";
          credential_key = "env://XAI_API_KEY";
          env_var = "XAI_API_KEY";
          inject_header = "Authorization";
          credential_format = "Bearer {}";
        };
      };
      credentials = [ ];
    };
    open_urls = {
      allow_origins = [
        "https://accounts.x.ai"
        "https://auth.x.ai"
        "https://grok.com"
        "https://x.ai"
        "https://x.com"
      ];
      allow_localhost = true;
    };
    allow_launch_services = true;
    platform_overrides = {
      macos = {
        network = {
          open_port = [ 0 ];
        };
      };
    };
  });

  profilesDir = ../modules/hermes/_profiles;
  conventions = ../modules/hermes/_lib/conventions.md;
in
runCommand "hermes-nix-bundle-1.0.0"
  {
    passthru = {
      inherit profile hermes-unwrapped;
    };
    meta = {
      description = "Nono-wrapped Hermes Agent (all profiles)";
      mainProgram = "hermes";
    };
  }
  ''
    root=$out/share/hermes-nix
    mkdir -p $root/profiles $out/bin
    cp ${profile} $root/nono-profile.json
    cp ${conventions} $root/conventions.md
    cp -a ${profilesDir}/. $root/profiles/

    wrap() {
      local name="$1"
      local extra="$2"
      cat > $out/bin/$name <<EOF
    #!${runtimeShell}
    set -euo pipefail
    export PATH="${nono}/bin:${agent-tools}/bin:\$PATH"
    root="$root"
    xdg_cfg="\''${XDG_CONFIG_HOME:-\$HOME/.config}"
    mkdir -p \
      "\$HOME/.hermes/profiles" \
      "\$HOME/.hermes/shared" \
      "\$HOME/.cache/hermes" \
      "\$HOME/.local/share/hermes" \
      "\$HOME/.local/state/hermes" \
      "\$xdg_cfg/nono/profile-drafts" 2>/dev/null || true
    ln -sfn "\$root/nono-profile.json" "\$xdg_cfg/nono/profiles/hermes-nix.json" 2>/dev/null || true
    exec ${nono}/bin/nono run \
      --profile "\$root/nono-profile.json" \
      --allow-cwd \
      --suppress-save-prompt "\$HOME" \
      --suppress-save-prompt "\$HOME/" \
      -- ${hermes-unwrapped}/bin/hermes $extra "\$@"
    EOF
      chmod +x $out/bin/$name
    }

    wrap hermes ""
    wrap concierge "-p concierge"
    wrap food "-p food"
    wrap travel "-p travel"
    wrap hermes-tutor "-p hermes-tutor"

    cat > $out/bin/hermes-gateway <<EOF
    #!${runtimeShell}
    set -euo pipefail
    envf="\$HOME/.hermes/profiles/concierge/.env"
    has_token=0
    if [ -f "\$envf" ]; then
      if grep -qE '^(TELEGRAM_BOT_TOKEN|DISCORD_BOT_TOKEN|DISCORD_TOKEN)=' "\$envf"; then
        has_token=1
      fi
    fi
    if [ "\$has_token" -ne 1 ]; then
      echo "hermes-gateway: no Telegram/Discord token in \$envf; waiting" >&2
      while true; do
        if [ -f "\$envf" ] && grep -qE '^(TELEGRAM_BOT_TOKEN|DISCORD_BOT_TOKEN|DISCORD_TOKEN)=' "\$envf"; then
          break
        fi
        sleep 60
      done
    fi
    exec $out/bin/hermes -p concierge gateway start "\$@"
    EOF
    chmod +x $out/bin/hermes-gateway

    echo "$root" > $out/share/hermes-nix-root
  ''
