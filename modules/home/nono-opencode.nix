{ lib, ... }:
let
  models = import ./_lib/opencode-models.nix { inherit lib; };

  # Shared with project-root opencode.json — keep permission surface identical.
  opencodePermission = {
    "*" = "allow";
    external_directory = "allow";
    doom_loop = "allow";
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

  mkSkill = pkgs: name: src:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "opencode-skill-${name}";
      version = "1.0.0";
      inherit src;
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/opencode/skills/${name}
        cp -a . $out/share/opencode/skills/${name}/
        runHook postInstall
      '';
      meta.description = "opencode skill: ${name}";
    };

  mkNpmPlugin = pkgs: { pname, version, url, hash }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;
      src = pkgs.fetchurl { inherit url hash; };
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/node_modules/${pname}
        if [ -d package ]; then
          cp -a package/. $out/lib/node_modules/${pname}/
        else
          cp -a . $out/lib/node_modules/${pname}/
        fi
        runHook postInstall
      '';
    };

  mkCm = pkgs:
    pkgs.buildGoModule {
      pname = "cm";
      version = "1.0.0";
      src = ./_tools/criticmarkup;
      vendorHash = null;
      meta.mainProgram = "cm";
      postInstall = ''
        if [ ! -e $out/bin/cm ]; then
          b="$(find $out/bin -type f -perm -111 | head -n1)"
          mv "$b" $out/bin/cm
        fi
      '';
    };

  # Self-contained nono profile: extends built-in `default` only.
  # Inlines the former nolabs-ai/opencode pack grants so `nono pull` is NOT required.
  # NEVER grant "~/" or "~/.local/state/nono" (protected; breaks sandbox init).
  mkProfile = pkgs: pkgs.writeText "opencode-nix.json" (builtins.toJSON {
    extends = [ "default" ];
    meta = {
      name = "opencode-nix";
      version = "2.0.0";
      description = "Fully store-backed opencode profile (no registry pack dependency)";
    };
    interactive = false;
    security = {
      signal_mode = "isolated";
      capability_elevation = false;
    };
    groups = {
      include = [
        "node_runtime"
        "rust_runtime"
        "python_runtime"
        { name = "user_caches_macos"; when = "macos"; }
        { name = "user_caches_linux"; when = "linux"; }
        { name = "linux_sysfs_read"; when = "linux"; }
        "nix_runtime"
        "git_config"
        "unlink_protection"
        { name = "opencode_linux"; when = "linux"; }
      ];
    };
    workdir = { access = "readwrite"; };
    filesystem = {
      # Ephemeral runtime state only under XDG — not configuration.
      allow = [
        "$HOME/.opencode"
        "$HOME/.config/opencode"
        "$HOME/.cache/opencode"
        "$HOME/.local/share/opencode"
        "$HOME/.local/share/opentui"
        "$HOME/.local/state/opencode"
        "$NONO_CONFIG/profile-drafts"
        "$TMPDIR"
        "$HOME/.local/share/nix"
      ];
      read = [
        "/nix/store"
        "$HOME/.agents"
      ];
      read_file = [
        { path = "$HOME/Library/Keychains/login.keychain-db"; when = "macos"; }
        "$HOME/.gitconfig"
        "$HOME/.config/git/config"
      ];
      bypass_protection = [
        { path = "$HOME/Library/Keychains/login.keychain-db"; when = "macos"; }
      ];
      suppress_save_prompt = [ "~/" "$HOME" ];
    };
    network = {
      block = false;
      allow_domain = [ ];
      credentials = [ ];
    };
    open_urls = {
      allow_origins = [
        "https://auth.openai.com"
        "https://claude.ai"
        "https://github.com"
      ];
      allow_localhost = true;
    };
    allow_launch_services = true;
  });

  mkBundleFixed = pkgs: nono: opencode-bin: cm:
    let
      modelsFile = pkgs.writeText "orchestration-models.json" models.orchestrationModelsJson;
      skills = {
        document-comments = mkSkill pkgs "document-comments" ./_skills/document-comments;
        document-review = mkSkill pkgs "document-review" ./_skills/document-review;
        orchestration = mkSkill pkgs "orchestration" ./_skills/orchestration;
        nono-sandbox = mkSkill pkgs "nono-sandbox" ./_skills/nono-sandbox;
      };
      agentsDir = ./_agents;
      goalPlugin = mkNpmPlugin pkgs {
        pname = "@prevalentware/opencode-goal-plugin";
        version = "0.1.29";
        url = "https://registry.npmjs.org/@prevalentware/opencode-goal-plugin/-/opencode-goal-plugin-0.1.29.tgz";
        hash = "sha256-7kFgin0luOREk56fx8KsANEHcYp7rFcm/rQiJxJRj+I=";
      };
      nonoPlugin = pkgs.runCommand "opencode-plugin-nono-sandbox" { } ''
        mkdir -p $out/share/opencode/plugins
        cp ${./_plugins/nono-sandbox.ts} $out/share/opencode/plugins/nono-sandbox.ts
      '';
      profile = mkProfile pkgs;
      skillNames = builtins.attrNames skills;
      goalPluginEntry = "file://${goalPlugin}/lib/node_modules/@prevalentware/opencode-goal-plugin";
      nonoPluginEntry = "file://${nonoPlugin}/share/opencode/plugins/nono-sandbox.ts";
      opencodeConfig = {
        "$schema" = "https://opencode.ai/config.json";
        permission = opencodePermission;
        autoupdate = false;
        subagent_depth = 2;
        default_agent = "orchestrator";
        small_model = "openrouter/deepseek/deepseek-chat";
        plugin = [ goalPluginEntry nonoPluginEntry ];
        skills.paths = map (n: "${skills.${n}}/share/opencode/skills") skillNames;
        agent = {
          orchestrator = {
            description = "Primary orchestrator — leads free/cheap workers";
            mode = "primary";
          };
          worker-free = {
            description = "Implements one discrete free-model objective";
            mode = "subagent";
          };
          moe-advisor = {
            description = "Paid MoE decomposition advisor (allowlist only)";
            mode = "subagent";
            model = models.moeAdvisorModel;
            permission = {
              edit = "deny";
              bash = "ask";
            };
          };
        };
        instructions = [ "AGENTS.md" ];
      };
      configJson = pkgs.writeText "opencode.json" (builtins.toJSON opencodeConfig);
    in
    pkgs.runCommand "opencode-nix-bundle-2.0.0"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        passthru = {
          inherit profile modelsFile skills configJson;
          nono = nono;
          opencode-bin = opencode-bin;
          cm = cm;
        };
        meta = {
          description = "Deterministic store-backed opencode+nono+skills+profile";
          mainProgram = "opencode";
        };
      } ''
      root=$out/share/opencode-nix
      mkdir -p $root/agent $root/skills $root/plugins $out/bin

      cp ${configJson} $root/opencode.json
      cp ${profile} $root/nono-profile.json
      cp ${modelsFile} $root/orchestration-models.json
      cp -a ${agentsDir}/. $root/agent/

      ${pkgs.lib.concatMapStrings (n: ''
        mkdir -p $root/skills/${n}
        cp -a ${skills.${n}}/share/opencode/skills/${n}/. $root/skills/${n}/
      '') skillNames}

      cp ${nonoPlugin}/share/opencode/plugins/nono-sandbox.ts $root/plugins/

      # Wrapper script (makeWrapper + dynamic $HOME for suppress-save-prompt)
      cat > $out/bin/opencode <<EOF
      #!${pkgs.runtimeShell}
      set -euo pipefail
      export PATH="${cm}/bin:${nono}/bin:\$PATH"
      export OPENCODE_CONFIG="$root/opencode.json"
      export OPENCODE_CONFIG_DIR="$root"
      export OPENCODE_ORCHESTRATION_MODELS="$root/orchestration-models.json"
      export OPENCODE_AGENTS_DIR="$root/agent"
      export NPM_CONFIG_CACHE="\''${NPM_CONFIG_CACHE:-\$HOME/.cache/opencode/npm}"
      export BUN_INSTALL_CACHE_DIR="\''${BUN_INSTALL_CACHE_DIR:-\$HOME/.cache/opencode/bun}"
      export OPENCODE_GOAL_STATE_PATH="\''${OPENCODE_GOAL_STATE_PATH:-\$HOME/.local/share/opencode/goal-plugin/goals.json}"
      # Ensure ephemeral state dirs exist (not config — OK to create at runtime)
      mkdir -p "\$HOME/.cache/opencode" "\$HOME/.local/share/opencode" "\$HOME/.local/state/opencode" \
               "\$HOME/.config/opencode" "\''${XDG_CONFIG_HOME:-\$HOME/.config}/nono/profile-drafts"
      exec ${nono}/bin/nono run \
        --profile "$root/nono-profile.json" \
        --allow-cwd \
        --suppress-save-prompt "\$HOME" \
        --suppress-save-prompt "\$HOME/" \
        -- ${opencode-bin}/bin/opencode "\$@"
      EOF
      chmod +x $out/bin/opencode

      ln -s ${nono}/bin/nono $out/bin/nono
      ln -s ${cm}/bin/cm $out/bin/cm
      ln -s ${opencode-bin}/bin/opencode $out/bin/opencode-bin
      echo "$root" > $out/share/opencode-nix-root
    '';

  mkOrchestrationTest = pkgs: modelsFile: agentsDir:
    let
      sdk = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@opencode-ai/sdk/-/sdk-1.18.11.tgz";
        hash = "sha256-EmHTx2xUJpc1tP6bYOrEpnz5SC8ZpvIIWL+LnjQCCeE=";
      };
      testSrc = ./_test/opencode-orchestration-test;
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "opencode-orchestration-test";
      version = "1.0.0";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.nodejs ];
      buildPhase = ''
        mkdir -p $out/lib/test/node_modules/@opencode-ai
        tar -xzf ${sdk} -C $out/lib/test/node_modules/@opencode-ai
        if [ -d $out/lib/test/node_modules/@opencode-ai/package ]; then
          mv $out/lib/test/node_modules/@opencode-ai/package $out/lib/test/node_modules/@opencode-ai/sdk
        fi
        cp ${testSrc}/test.mjs $out/lib/test/test.mjs
      '';
      installPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/opencode-orchestration-test <<EOF
        #!${pkgs.runtimeShell}
        export NODE_PATH=$out/lib/test/node_modules
        export OPENCODE_ORCHESTRATION_MODELS=${modelsFile}
        export OPENCODE_AGENTS_DIR=${agentsDir}
        exec ${pkgs.nodejs}/bin/node $out/lib/test/test.mjs
        EOF
        chmod +x $out/bin/opencode-orchestration-test
      '';
      doInstallCheck = true;
      installCheckPhase = ''
        export NODE_PATH=$out/lib/test/node_modules
        export OPENCODE_ORCHESTRATION_MODELS=${modelsFile}
        export OPENCODE_AGENTS_DIR=${agentsDir}
        ${pkgs.nodejs}/bin/node $out/lib/test/test.mjs
      '';
    };

in
{
  # Configuration is 100% Nix store. Ephemeral only: sessions, caches, logs under XDG.
  perSystem = { pkgs, ... }:
    let
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
      cm = mkCm pkgs;
      bundle = mkBundleFixed pkgs nono opencode-bin cm;
      modelsFile = bundle.passthru.modelsFile;
      orchTest = mkOrchestrationTest pkgs modelsFile ./_agents;
    in
    {
      packages = {
        inherit nono;
        opencode-bin = opencode-bin;
        opencode = bundle;
        opencode-config = bundle; # bundle root = full store config
        opencode-nix-profile = bundle.passthru.profile;
        opencode-orchestration-models = modelsFile;
        opencode-orchestration-test = orchTest;
        opencode-skill-document-comments = bundle.passthru.skills.document-comments;
        opencode-skill-document-review = bundle.passthru.skills.document-review;
        opencode-skill-orchestration = bundle.passthru.skills.orchestration;
        opencode-skill-nono-sandbox = bundle.passthru.skills.nono-sandbox;
      };
    };

  flake.modules.homeManager.nono-opencode = { pkgs, lib, ... }:
    let
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
      cm = mkCm pkgs;
      bundle = mkBundleFixed pkgs nono opencode-bin cm;
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
