# Pi coding agent on every home that imports this module.
# Auth stays in ~/.pi/agent (pi /login or env keys), not Nix.
{ ... }: {
  flake.modules.homeManager.pi = {pkgs, lib, config, ...}: let
    cfg = config.programs.pi-coding-agent;
  in {
    programs.pi-coding-agent = {
      enable = true;
      # npm: extensions (skills, pi packages) need node on PATH.
      extraPackages = [pkgs.nodejs];
      # Third-party pi packages, installed from the nix store as local-path
      # package sources (pi loads store paths directly — no runtime npm
      # install, no version drift). Plan mode and sub-agent orchestration.
      settings.packages = [
        pkgs.pi-plan-mode.piPackagePath
        pkgs.pi-subagents.piPackagePath
        pkgs.pi-goal.piPackagePath
      ];
      # Global skills teaching pi agents how to use the tools provided by
      # the packages above. Markdown lives in modules/home/_skills/ (each
      # <name>/SKILL.md; the `_` prefix keeps import-tree from auto-importing
      # it). pi's `skills` setting accepts directories and discovers
      # SKILL.md folders recursively, so pointing it at the store path of
      # that directory loads every skill — adding a skill = adding a file.
      # Store-backed like the packages: pi reads the nix store directly, no
      # copies into ~/.pi (user-level skills there can still override).
      settings.skills = [ "${./_skills}" ];
    };

    # pi-subagents' nested-delegation ceiling. maxSubagentDepth lives in
    # ~/.pi/agent/subagents.json (the extension's own config file), NOT pi's
    # settings.json, so `settings` can't carry it. Seed the file with depth 3
    # (default 2 = one level of nesting; the pi-orchestration skill relies on
    # a second). Seed-only, never clobber: users may edit depth at runtime via
    # /agents → Settings → Nested depth, so a store symlink or unconditional
    # write would break their changes. Idempotent: adds the key only when the
    # file is absent (plain write) or present-but-missing-it (jq merge when
    # jq is available; an unparseable or already-configured file is left
    # alone).
    home.activation.seedPiSubagentsDepth =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        subagentsFile="${cfg.configDir}/subagents.json"

        if [ ! -e "$subagentsFile" ]; then
          $DRY_RUN_CMD printf '%s' '{"maxSubagentDepth":3}' > "$subagentsFile"
        elif command -v jq >/dev/null 2>&1 \
            && jq -e 'type == "object" and (has("maxSubagentDepth") | not)' \
                "$subagentsFile" >/dev/null 2>&1; then
          tmp="$(mktemp)"
          if jq '. + {"maxSubagentDepth":3}' "$subagentsFile" > "$tmp"; then
            $DRY_RUN_CMD mv -f "$tmp" "$subagentsFile"
          else
            rm -f "$tmp"
          fi
        fi
      '';
  };
}
