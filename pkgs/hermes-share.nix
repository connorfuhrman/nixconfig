{
  lib,
  runCommand,
  writeText,
}:
let
  profile = writeText "hermes-nix.json" (builtins.toJSON {
    extends = [ "default" ];
    meta = {
      name = "hermes-nix";
      version = "1.1.0";
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
      read = [ "/nix/store" ];
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
in
runCommand "hermes-share"
  {
    passthru = {
      inherit profile;
    };
    meta.description = "Hermes profile templates and Nono policy";
  }
  ''
    root=$out/share/hermes-nix
    mkdir -p $root/profiles
    cp ${profile} $root/nono-profile.json
    cp ${../modules/hermes/_lib/conventions.md} $root/conventions.md
    cp -a ${../modules/hermes/_profiles}/. $root/profiles/
    echo "$root" > $out/share/hermes-nix-root
  ''
