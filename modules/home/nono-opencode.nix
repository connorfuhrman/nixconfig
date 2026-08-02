{ lib, ... }:
let
  models = import ./_lib/opencode-models.nix { inherit lib; };

  # Shared with project-root opencode.json — keep them identical.
  # nono owns real isolation; opencode interactive prompts are skipped.
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
      meta = {
        description = "opencode skill: ${name}";
        license = pkgs.lib.licenses.mit;
      };
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
        # npm pack tarball has package/ prefix
        if [ -d package ]; then
          cp -a package/. $out/lib/node_modules/${pname}/
        else
          cp -a . $out/lib/node_modules/${pname}/
        fi
        runHook postInstall
      '';
      meta = {
        description = "opencode plugin ${pname} (store-vendored npm)";
      };
    };

  # Entire opencode config tree in the Nix store — no ephemeral config writes.
  mkOpencodeConfigRoot = pkgs: skills: agentsDir: plugins: modelsFile:
    let
      skillNames = builtins.attrNames skills;
      # Plugin path as file:// URL for opencode
      goalPlugin = plugins.goal;
      goalPluginEntry = "file://${goalPlugin}/lib/node_modules/@prevalentware/opencode-goal-plugin";

      opencodeConfig = {
        "$schema" = "https://opencode.ai/config.json";
        permission = opencodePermission;
        autoupdate = false;
        # Raise nesting so workers can spawn explore children.
        subagent_depth = 2;
        default_agent = "orchestrator";
        small_model = "openrouter/deepseek/deepseek-chat";
        plugin = [ goalPluginEntry ];
        skills = {
          paths = map (n: "${skills.${n}}/share/opencode/skills") skillNames;
        };
        agent = {
          orchestrator = {
            description = "Primary orchestrator — leads free/cheap workers";
            mode = "primary";
            # model left default (session / xAI grok)
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
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "opencode-config-root";
      version = "1.0.0";
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        root=$out/share/opencode
        mkdir -p $root/agent $root/skills $root/bin

        cp ${pkgs.writeText "opencode.json" (builtins.toJSON opencodeConfig)} $root/opencode.json

        # Agents (markdown prompts) — store-backed
        cp -a ${agentsDir}/. $root/agent/

        # Skills mirrored for discovery + OPENCODE_CONFIG_DIR layouts
        ${pkgs.lib.concatMapStrings (n: ''
          mkdir -p $root/skills/${n}
          cp -a ${skills.${n}}/share/opencode/skills/${n}/. $root/skills/${n}/
        '') skillNames}

        cp ${modelsFile} $root/orchestration-models.json

        # Convenience: path file for wrappers
        echo "$root" > $out/share/opencode-root-path
        runHook postInstall
      '';
      meta.description = "Fully store-backed opencode config, agents, skills";
    };

  # Profile is a pure store object. The wrapper passes its ABSOLUTE store path
  # to `nono run --profile <path>` so runtime never depends on the mutable
  # ~/.config/nono/profiles/ tree (nono can rewrite named profiles on deny).
  # NEVER grant "~/" — overlaps protected ~/.local/state/nono.
  mkProfile = pkgs: pkgs.writeText "opencode-nix.json" (builtins.toJSON {
    extends = [ "nolabs-ai/opencode" ];
    meta = {
      name = "opencode-nix";
      version = "1.4.0";
      description = "store-backed nono profile for flake opencode wrapper";
    };
    workdir = {
      access = "readwrite";
    };
    # Disable interactive save-profile flows when possible.
    interactive = false;
    filesystem = {
      allow = [ "~/.local/share/nix" ];
      read = [ "/nix/store" ];
      read_file = [
        "~/.gitconfig"
        "~/.config/git/config"
      ];
      # Do not prompt to widen profile when $HOME itself is probed.
      # Never grant "~/" or "~/.local/state/nono" — both are protected by nono.
      suppress_save_prompt = [ "~/" ];
    };
  });

  mkOpencode = pkgs: nono: opencode-bin: configRoot: modelsFile: cm: profile:
    pkgs.writeShellScriptBin "opencode" ''
      export NPM_CONFIG_CACHE="''${NPM_CONFIG_CACHE:-$HOME/.cache/opencode/npm}"
      export BUN_INSTALL_CACHE_DIR="''${BUN_INSTALL_CACHE_DIR:-$HOME/.cache/opencode/bun}"
      export OPENCODE_GOAL_STATE_PATH="''${OPENCODE_GOAL_STATE_PATH:-$HOME/.local/share/opencode/goal-plugin/goals.json}"
      # Store-backed config (sessions/logs remain under XDG state — ephemeral OK)
      export OPENCODE_CONFIG="${configRoot}/share/opencode/opencode.json"
      export OPENCODE_CONFIG_DIR="${configRoot}/share/opencode"
      export OPENCODE_ORCHESTRATION_MODELS="${modelsFile}"
      export OPENCODE_AGENTS_DIR="${configRoot}/share/opencode/agent"
      export PATH="${cm}/bin:$PATH"
      # Immutable profile: absolute store path (not name lookup under ~/.config/nono).
      # --allow-cwd: workdir already readwrite in profile; skip interactive CWD prompt.
      # --suppress-save-prompt ~/: never offer to grant full home into a mutable profile.
      exec ${nono}/bin/nono run \
        --profile ${profile} \
        --allow-cwd \
        --suppress-save-prompt "$HOME" \
        --suppress-save-prompt "$HOME/" \
        --no-rollback \
        -- ${opencode-bin}/bin/opencode "$@"
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
        # tarball extracts to package/
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
      meta.description = "SDK smoke test for orchestration allowlist + agents";
    };

in
{
  # Run `opencode` inside nono with a flake-managed profile.
  # Config, skills, agents, plugins, and tools are Nix store paths only.
  # Ephemeral: session logs, goal-plugin state under XDG share/cache.

  perSystem = { pkgs, ... }:
    let
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
      modelsFile = pkgs.writeText "orchestration-models.json" models.orchestrationModelsJson;
      skills = {
        document-comments = mkSkill pkgs "document-comments" ./_skills/document-comments;
        document-review = mkSkill pkgs "document-review" ./_skills/document-review;
        orchestration = mkSkill pkgs "orchestration" ./_skills/orchestration;
      };
      agentsDir = ./_agents;
      goalPlugin = mkNpmPlugin pkgs {
        pname = "@prevalentware/opencode-goal-plugin";
        version = "0.1.29";
        url = "https://registry.npmjs.org/@prevalentware/opencode-goal-plugin/-/opencode-goal-plugin-0.1.29.tgz";
        hash = "sha256-7kFgin0luOREk56fx8KsANEHcYp7rFcm/rQiJxJRj+I=";
      };
      cm = pkgs.buildGoModule {
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
      profile = mkProfile pkgs;
      configRoot = mkOpencodeConfigRoot pkgs skills agentsDir { goal = goalPlugin; } modelsFile;
      orchTest = mkOrchestrationTest pkgs modelsFile agentsDir;
    in
    {
      packages = {
        inherit nono;
        opencode-bin = opencode-bin;
        opencode = mkOpencode pkgs nono opencode-bin configRoot modelsFile cm profile;
        opencode-config = configRoot;
        opencode-nix-profile = profile;
        opencode-orchestration-models = modelsFile;
        opencode-orchestration-test = orchTest;
        opencode-skill-document-comments = skills.document-comments;
        opencode-skill-document-review = skills.document-review;
        opencode-skill-orchestration = skills.orchestration;
      };
    };

  flake.modules.homeManager.nono-opencode = { pkgs, lib, ... }:
    let
      nono = mkNono pkgs;
      opencode-bin = mkOpencodeBin pkgs;
      modelsFile = pkgs.writeText "orchestration-models.json" models.orchestrationModelsJson;
      skills = {
        document-comments = mkSkill pkgs "document-comments" ./_skills/document-comments;
        document-review = mkSkill pkgs "document-review" ./_skills/document-review;
        orchestration = mkSkill pkgs "orchestration" ./_skills/orchestration;
      };
      agentsDir = ./_agents;
      goalPlugin = mkNpmPlugin pkgs {
        pname = "@prevalentware/opencode-goal-plugin";
        version = "0.1.29";
        url = "https://registry.npmjs.org/@prevalentware/opencode-goal-plugin/-/opencode-goal-plugin-0.1.29.tgz";
        hash = "sha256-7kFgin0luOREk56fx8KsANEHcYp7rFcm/rQiJxJRj+I=";
      };
      cm = pkgs.buildGoModule {
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
      profile = mkProfile pkgs;
      configRoot = mkOpencodeConfigRoot pkgs skills agentsDir { goal = goalPlugin; } modelsFile;
      opencode = mkOpencode pkgs nono opencode-bin configRoot modelsFile cm profile;
    in
    {
      # Convenience symlink only — wrapper does NOT use this path.
      # Activation forces store symlink if nono previously wrote a mutable file.
      home.file.".config/nono/profiles/opencode-nix.json".source = profile;

      home.activation.forceNonoProfileSymlink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.config/nono/profiles/opencode-nix.json"
        desired="${profile}"
        mkdir -p "$(dirname "$target")"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          rm -f "$target"
        fi
        ln -sfn "$desired" "$target"
      '';

      # Point HM at the store tree so ~/.config/opencode is not hand-edited.
      home.file.".config/opencode/opencode.json".source =
        "${configRoot}/share/opencode/opencode.json";
      home.file.".config/opencode/orchestration-models.json".source =
        "${configRoot}/share/opencode/orchestration-models.json";
      home.file.".config/opencode/agent".source =
        "${configRoot}/share/opencode/agent";
      home.file.".config/opencode/skills".source =
        "${configRoot}/share/opencode/skills";

      home.packages = [
        nono
        opencode
        cm
        skills.document-comments
        skills.document-review
        skills.orchestration
        configRoot
      ];

      home.sessionVariables = {
        OPENCODE_ORCHESTRATION_MODELS = "${modelsFile}";
      };
    };
}
