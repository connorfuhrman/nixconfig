{ inputs, ... }: {
  # Run `opencode` inside the nono sandbox (https://github.com/nolabs-ai/nono)
  # with a flake-managed profile that extends the official least-privilege pack
  # and grants the nix user state dir (trusted-settings.json for flake nixConfig).
  # Works identically on macOS and Linux: both tools are pinned binary packages
  # fetched from upstream releases, and `opencode` resolves to a wrapper that
  # execs nono with the pinned opencode binary (absolute store paths — no PATH
  # recursion).
  #
  # To bump versions: update `version`, the url tag, and the three hashes
  # (nix store prefetch-file <url>).
  #
  # One-time per machine (downloads the sandbox pack the profile extends):
  #   nono pull nolabs-ai/opencode
  #
  # The sandbox already enforces isolation; opencode's interactive permission
  # prompts are skipped via ~/.config/opencode/opencode.json with
  # permission."*" = "allow" (do not weaken the nono profile).
  flake.modules.homeManager.nono-opencode = { pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;

      nono = pkgs.stdenv.mkDerivation {
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
        # The Linux builds are glibc-linked and need patching; the macOS and
        # musl builds need nothing.
        nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
        buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];
        installPhase = ''
          runHook preInstall
          install -Dm755 "$(find . -maxdepth 3 -type f -name nono | head -n 1)" $out/bin/nono
          runHook postInstall
        '';
      };

      opencode-bin = pkgs.stdenv.mkDerivation {
        pname = "opencode";
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
          install -Dm755 "$(find . -maxdepth 3 -type f -name opencode | head -n 1)" $out/bin/opencode
          runHook postInstall
        '';
      };

      # Extends the pack profile; grants ~/.local/share/nix so `nix flake`
      # can stat/write trusted-settings.json (flake nixConfig acceptance),
      # and auto-shares CWD read+write (no interactive prompt).
      opencode-profile = pkgs.writeText "opencode-nix.json" (builtins.toJSON {
        extends = [ "nolabs-ai/opencode" ];
        meta = {
          name = "opencode-nix";
          version = "1.0.0";
          description = "opencode + CWD r/w + nix user-state for flake eval/check";
        };
        workdir = {
          access = "readwrite";
        };
        filesystem = {
          allow = [ "~/.local/share/nix" ];
        };
      });
    in
    {
      # Installed as a named user profile; wrapper selects it by name.
      home.file.".config/nono/profiles/opencode-nix.json".source = opencode-profile;

      # Sandbox already enforces isolation; skip opencode's interactive
      # permission prompts (do not weaken the nono profile).
      home.file.".config/opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        permission = {
          "*" = "allow";
        };
      };

      home.packages = [
        nono
        (pkgs.writeShellScriptBin "opencode" ''
          exec ${nono}/bin/nono run \
            --profile opencode-nix \
            --allow-cwd \
            -- ${opencode-bin}/bin/opencode "$@"
        '')
      ];
    };
}
