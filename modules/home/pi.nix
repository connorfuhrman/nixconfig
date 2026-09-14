{ ... }: {
  # Pi coding agent on every home that imports this module.
  # Auth stays in ~/.pi/agent (pi /login or env keys), not Nix.
  flake.modules.homeManager.pi = { pkgs, ... }: {
    programs.pi-coding-agent = {
      enable = true;
      # npm: extensions (skills, pi packages) need node on PATH.
      extraPackages = [ pkgs.nodejs ];
    };
  };
}
