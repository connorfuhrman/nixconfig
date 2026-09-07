{ config, ... }: {
  # Full standalone home stack shared by every host.
  # Must be a module function so imports resolve lazily (an attrset RHS that
  # reads config.flake.modules.homeManager.* at define-time drops the attr).
  flake.modules.homeManager.standard = { ... }: {
    imports = [
      config.flake.modules.homeManager.base
      config.flake.modules.homeManager.emacs
      config.flake.modules.homeManager.coreutils
      config.flake.modules.homeManager.mosh
      config.flake.modules.homeManager.obsidian-config
    ];
  };
}
