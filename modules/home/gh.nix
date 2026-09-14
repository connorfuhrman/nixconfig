{ ... }: {
  # GitHub CLI on every home that imports this module.
  # Token/host state stays in ~/.config/gh (gh auth login), not Nix.
  flake.modules.homeManager.gh = { ... }: {
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
    };
  };
}
