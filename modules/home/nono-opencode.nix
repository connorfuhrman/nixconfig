{ ... }:
let
  # Shared with project-root opencode.json — keep them identical.
  # nono owns real isolation; opencode interactive prompts are skipped.
  opencodePermission = {
    "*" = "allow";
    external_directory = "allow";
    doom_loop = "allow";
  };

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    permission = opencodePermission;
    # Binary is flake-pinned; never self-update out from under the wrapper.
    autoupdate = false;
    plugin = [ "@prevalentware/opencode-goal-plugin" ];
  };

  supported = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  mkNono = pkgs:
    let system = pkgs.stdenv.hostPlatform.system;
    in pkgs.stdenv.mkDerivation {
      pname = "nono";
      version = "0.69.0";
      src = pkgs.fetchurl {
        url = {
          "aarch64-darwin" = "https://github.com/nolabs-ai/nono/releases/download/v0.69.0/nono-v0.69.0-aarch64-apple-darwin.tar.gz";
          "aarch64-linux" = "https://github.com/nolabs-ai/nono/releases/download/v0.69.0/nono-v0.69.0-aarch64-unknown-linux-gnu.tar.gz";
          "x86_64-linux" = "https://github.com/nolabs-ai/nono/releases/download/v0.69.0/nono-v0.69.0-x86_64-unknown-linux-gnu.tar.gz";
        }.${system};
        hash = {
          "aarch64-darwin" = "sha256-gf9O/2Wpds2hAu+B7pb/n4Zo95iA++tr/g+QNd+QPwU=";
          "aarch64-linux" = "sha256-rcBz9c2gFBHEZnNF9PBN1AAv2rSswcNEvYba4d4hkWA=";
          "x86_64-linux" = "sha256-PHn7DcKpFxt9RBAmllZm9WUsQvZ7xXEKJ9jp+Sgi9hk=";
        }.${system};
      };
      sourceRoot = ".";
      # Linux builds are glibc-linked; macOS needs nothing.
      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
      buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];
      installPhase = ''
        runHook preInstall
        bin="$(find . -maxdepth 3 -type f -name nono | head -n 1)"
        test -n "$bin"
        install -Dm755 "$bin" $out/bin/nono
        runHook postInstall
      '';
      meta = {
        description = "Zero-latency AI agent sandbox";
        homepage = "https://github.com/nolabs-ai/nono";
        license = pkgs.lib.licenses.asl20;
        platforms = supported;
        sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
      };
    };

  mkOpencodeBin = pkgs:
    let system = pkgs.stdenv.hostPlatform.system;
    in pkgs.stdenv.mkDerivation {
      pname = "opencode-bin";
      version = "1.18.5";
      src = pkgs.fetchurl {
        url = {
          "aarch64-darwin" = "https://github.com/anomalyco/opencode/releases/download/v1.18.5/opencode-darwin-arm64.zip";
          "aarch64-linux" = "https://github.com/anomalyco/opencode/releases/download/v1.18.5/opencode-linux-arm64-musl.tar.gz";
          "x86_64-linux" = "https://github.com/anomalyco/opencode/releases/download/v1.18.5/opencode-linux-x64-musl.tar.gz";
        }.${system};
        hash = {
          "aarch64-darwin" = "sha256-hfb57s4XTTvwySWICGplKEOIuJElbI9BAtwxfUdv/KY=";
          "aarch64-linux" = "sha256-1JP20VvUwstCnVnFIT6iNxKPTdiJqUJpg7TG5dLAR64=";
          "x86_64-linux" = "sha256-8WToUsf/mK/5nv0DnzrCrN0XF+Jfa5TEceLIJ1IvZyw=";
        }.${system};
      };
      sourceRoot = ".";
      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.unzip ];
      installPhase = ''
        runHook preInstall
        bin="$(find . -maxdepth 3 -type f -name opencode | head -n 1)"
        test -n "$bin"
        install -Dm755 "$bin" $out/bin/opencode
        runHook postInstall
      '';
      meta = {
        description = "AI coding agent (upstream binary)";
        homepage = "https://opencode.ai";
        platforms = supported;
        sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
      };
    };

  # Profile extends the registry pack; CWD r/w + nix user-state for flake eval.
  # Plugin npm installs write under ~/.cache/opencode (already allowed) via
  # NPM_CONFIG_CACHE in the wrapper — do not grant ~/.npm (node_runtime is read-only).
  # Goal-plugin state is redirected under ~/.local/share/opencode via
  # OPENCODE_GOAL_STATE_PATH (default ~/.local/share/opencode-goal-plugin is blocked).
  mkProfile = pkgs: pkgs.writeText "opencode-nix.json" (builtins.toJSON {
    extends = [ "nolabs-ai/opencode" ];
    meta = {
      name = "opencode-nix";
      version = "1.2.0";
      description = "opencode + CWD r/w + nix user-state for flake eval/check";
    };
    workdir = {
      access = "readwrite";
    };
    filesystem = {
      allow = [ "~/.local/share/nix" ];
    };
  });

  # Absolute store paths — no PATH recursion through the wrapper name.
  # Env redirects keep npm plugin installs + goal-plugin state inside the
  # sandbox-allowed opencode XDG dirs (see nono pack nolabs-ai/opencode).
  mkOpencode = pkgs: nono: opencode-bin:
    pkgs.writeShellScriptBin "opencode" ''
      export NPM_CONFIG_CACHE="''${NPM_CONFIG_CACHE:-$HOME/.cache/opencode/npm}"
      export BUN_INSTALL_CACHE_DIR="''${BUN_INSTALL_CACHE_DIR:-$HOME/.cache/opencode/bun}"
      export OPENCODE_GOAL_STATE_PATH="''${OPENCODE_GOAL_STATE_PATH:-$HOME/.local/share/opencode/goal-plugin/goals.json}"
      exec ${nono}/bin/nono run \
        --profile opencode-nix \
        -- ${opencode-bin}/bin/opencode "$@"
    '';
in
{
  # Run `opencode` inside nono (https://github.com/nolabs-ai/nono) with a
  # flake-managed profile extending nolabs-ai/opencode.
  #
  # Bump: version + url tag + three hashes (`nix store prefetch-file <url>`).
  # One-time per machine: `nono pull nolabs-ai/opencode`
  #
  # Project-root opencode.json must match opencodeConfig below (permissions +
  # autoupdate). HM installs the user copy; the repo file is for this flake.

  # All systems in modules/systems.nix are supported; do not gate on pkgs
  # (accessing pkgs to decide module attrs causes infinite recursion).
  perSystem = { pkgs, ... }: {
    packages = rec {
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
      opencode = mkOpencode pkgs nono opencode-bin;
    };
  };

  flake.modules.homeManager.nono-opencode = { pkgs, ... }:
    let
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
    in
    {
      home.file.".config/nono/profiles/opencode-nix.json".source = mkProfile pkgs;
      home.file.".config/opencode/opencode.json".text = builtins.toJSON opencodeConfig;

      home.packages = [
        nono
        (mkOpencode pkgs nono opencode-bin)
      ];
    };
}
