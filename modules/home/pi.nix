# Pi coding agent on every home that imports this module.
# Auth stays in ~/.pi/agent (pi /login or env keys), not Nix.
{ ... }: {
  flake.modules.homeManager.pi = {pkgs, ...}: {
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
        pkgs.pi-tasks.piPackagePath
        pkgs.pi-usage.piPackagePath
        pkgs.pi-diff-review.piPackagePath
        pkgs.pi-worktree.piPackagePath
        pkgs.pi-lsp.piPackagePath
      ];
    };
    # Agent addendum appended to pi's system prompt on boot: documents the
    # installed extensions and where their docs/skills live.
    home.file.".pi/agent/APPEND_SYSTEM.md".source = ./APPEND_SYSTEM.md;
  };
}
