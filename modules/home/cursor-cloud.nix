{ config, ... }: {
  # Cursor Cloud Agent home: base + coreutils + emacs only.
  # No gh — Cloud Agent uses the GitHub MCP, not the CLI.
  # Must be a module function so imports resolve lazily (same as standard).
  flake.modules.homeManager.cursor-cloud = { lib, ... }: {
    imports = [
      config.flake.modules.homeManager.base
      config.flake.modules.homeManager.coreutils
      config.flake.modules.homeManager.emacs
    ];
    home.username = lib.mkForce "ubuntu";
    home.homeDirectory = lib.mkForce "/home/ubuntu";
  };
}
