# Deterministic store-backed opencode+nono+skills+profile bundle.
# callPackage resolves nono / opencode-bin / cm / opencode-goal-plugin from the overlay.
{
  lib,
  runCommand,
  writeText,
  runtimeShell,
  nono,
  opencode-bin,
  cm,
  opencode-goal-plugin,
  agent-tools,
  callPackage,
}:
let
  models = import ../modules/opencode/_lib/opencode-models.nix { inherit lib; };

  opencodePermission = {
    "*" = "allow";
    external_directory = "allow";
    doom_loop = "allow";
  };

  modelsFile = writeText "orchestration-models.json" models.orchestrationModelsJson;
  # Absolute store path — loaded for every session on every host (not cwd-dependent).
  fleetInstructions = writeText "opencode-fleet-instructions.md" (
    builtins.readFile ../modules/opencode/_instructions/fleet.md
  );

  mkSkill =
    name: src:
    callPackage ./opencode-skill.nix {
      inherit name src;
    };

  skills = {
    document-comments = mkSkill "document-comments" ../modules/opencode/_skills/document-comments;
    document-review = mkSkill "document-review" ../modules/opencode/_skills/document-review;
    orchestration = mkSkill "orchestration" ../modules/opencode/_skills/orchestration;
    nono-sandbox = mkSkill "nono-sandbox" ../modules/opencode/_skills/nono-sandbox;
  };

  agentsDir = ../modules/opencode/_agents;

  nonoPlugin = runCommand "opencode-plugin-nono-sandbox" { } ''
    mkdir -p $out/share/opencode/plugins
    cp ${../modules/opencode/_plugins/nono-sandbox.ts} $out/share/opencode/plugins/nono-sandbox.ts
  '';

  # Self-contained nono profile: extends built-in `default` only.
  # Inlines the former nolabs-ai/opencode pack grants so `nono pull` is NOT required.
  # NEVER grant "~/" or "~/.local/state/nono" (protected; breaks sandbox init).
  profile = writeText "opencode-nix.json" (builtins.toJSON {
    extends = [ "default" ];
    meta = {
      name = "opencode-nix";
      version = "2.1.0";
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
        {
          name = "user_caches_macos";
          when = "macos";
        }
        {
          name = "user_caches_linux";
          when = "linux";
        }
        {
          name = "linux_sysfs_read";
          when = "linux";
        }
        "nix_runtime"
        "git_config"
        "unlink_protection"
        {
          name = "opencode_linux";
          when = "linux";
        }
      ];
    };
    workdir = {
      access = "readwrite";
    };
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
        # gh CLI: auth token (hosts.yml), config, and state.
        "$HOME/.config/gh"
        "$HOME/.local/share/gh"
        # 1Password CLI (op): agent socket + CLI config, for
        # `GH_TOKEN="$(op read …)" gh …` / `op run -- gh …`.
        "$HOME/.1password"
        "$HOME/.config/op"
        "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t"
      ];
      read = [
        "/nix/store"
        "$HOME/.agents"
      ];
      read_file = [
        {
          path = "$HOME/Library/Keychains/login.keychain-db";
          when = "macos";
        }
        "$HOME/.gitconfig"
        "$HOME/.config/git/config"
      ];
      bypass_protection = [
        {
          path = "$HOME/Library/Keychains/login.keychain-db";
          when = "macos";
        }
      ];
      suppress_save_prompt = [
        "~/"
        "$HOME"
      ];
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

  skillNames = builtins.attrNames skills;
  goalPluginEntry = "file://${opencode-goal-plugin}/lib/node_modules/@prevalentware/opencode-goal-plugin";
  nonoPluginEntry = "file://${nonoPlugin}/share/opencode/plugins/nono-sandbox.ts";

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    permission = opencodePermission;
    autoupdate = false;
    subagent_depth = 2;
    default_agent = "orchestrator";
    small_model = "openrouter/openai/gpt-oss-20b:free";
    plugin = [
      goalPluginEntry
      nonoPluginEntry
    ];
    skills.paths = map (n: "${skills.${n}}/share/opencode/skills") skillNames;
    agent = {
      orchestrator = {
        description = "Primary orchestrator — leads free/cheap workers";
        mode = "primary";
      };
      worker-free = {
        description = "Implements one discrete free-model objective";
        mode = "subagent";
        # Pinned free model — without this the subagent inherits the
        # orchestrator's session model (cost + diversity regression).
        model = models.workerFreeModel;
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
    # fleetInstructions = absolute Nix store path (always on); AGENTS.md = project overlay.
    instructions = [
      "${fleetInstructions}"
      "AGENTS.md"
    ];
  };
  configJson = writeText "opencode.json" (builtins.toJSON opencodeConfig);
in
runCommand "opencode-nix-bundle-2.1.0"
  {
    passthru = {
      inherit
        profile
        modelsFile
        skills
        configJson
        fleetInstructions
        agentsDir
        ;
      inherit nono opencode-bin cm;
    };
    meta = {
      description = "Deterministic store-backed opencode+nono+skills+profile";
      mainProgram = "opencode";
    };
  }
  ''
    root=$out/share/opencode-nix
    mkdir -p $root/agent $root/skills $root/plugins $root/instructions $out/bin

    cp ${configJson} $root/opencode.json
    cp ${profile} $root/nono-profile.json
    cp ${modelsFile} $root/orchestration-models.json
    cp ${fleetInstructions} $root/instructions/fleet.md
    cp -a ${agentsDir}/. $root/agent/

    ${lib.concatMapStrings (n: ''
      mkdir -p $root/skills/${n}
      cp -a ${skills.${n}}/share/opencode/skills/${n}/. $root/skills/${n}/
    '') skillNames}

    cp ${nonoPlugin}/share/opencode/plugins/nono-sandbox.ts $root/plugins/

    # OPENCODE_CONFIG_DIR must be writable (not the Nix store). Store holds
    # immutable JSON/agents/skills; XDG config dir gets discovery symlinks.
    cat > $out/bin/opencode <<EOF
    #!${runtimeShell}
    set -euo pipefail
    export PATH="${cm}/bin:${nono}/bin:${agent-tools}/bin:\$PATH"
    root="$root"
    xdg_cfg="\''${XDG_CONFIG_HOME:-\$HOME/.config}"
    oc_dir="\$xdg_cfg/opencode"
    export OPENCODE_CONFIG="\$root/opencode.json"
    # Writable runtime config dir — NEVER the store (read-only → server crash).
    export OPENCODE_CONFIG_DIR="\$oc_dir"
    export OPENCODE_ORCHESTRATION_MODELS="\$root/orchestration-models.json"
    export NPM_CONFIG_CACHE="\''${NPM_CONFIG_CACHE:-\$HOME/.cache/opencode/npm}"
    export BUN_INSTALL_CACHE_DIR="\''${BUN_INSTALL_CACHE_DIR:-\$HOME/.cache/opencode/bun}"
    export OPENCODE_GOAL_STATE_PATH="\''${OPENCODE_GOAL_STATE_PATH:-\$HOME/.local/share/opencode/goal-plugin/goals.json}"
    mkdir -p \
      "\$HOME/.cache/opencode" \
      "\$HOME/.local/share/opencode" \
      "\$HOME/.local/state/opencode" \
      "\$oc_dir" \
      "\$xdg_cfg/nono/profile-drafts"
    # Discovery symlinks into the immutable bundle (safe to re-run).
    ln -sfn "\$root/opencode.json" "\$oc_dir/opencode.json"
    ln -sfn "\$root/orchestration-models.json" "\$oc_dir/orchestration-models.json"
    ln -sfn "\$root/agent" "\$oc_dir/agent"
    ln -sfn "\$root/skills" "\$oc_dir/skills"
    ln -sfn "\$root/plugins" "\$oc_dir/plugins"
    exec ${nono}/bin/nono run \
      --profile "\$root/nono-profile.json" \
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
  ''
