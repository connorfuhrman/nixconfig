{ ... }: {
  # Shared base for all standalone home-manager configurations.
  flake.modules.homeManager.base = { pkgs, lib, ... }: {
    home.username = "connorfuhrman";
    home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/connorfuhrman" else "/home/connorfuhrman";
    home.stateVersion = "25.11";

    # Let home-manager manage itself.
    programs.home-manager.enable = true;

    # Standalone HM has no home.backupFileExtension option. The Nix installer
    # writes ~/.zprofile on macOS; programs.zsh.enable also manages that file,
    # so first activation aborts with "would be clobbered" unless this env
    # var is set. Export it before checkLinkTargets (subprocess inherits it).
    # `switch-darwin -b backup` sets the same var for the CLI path.
    home.activation.backupExistingFiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      export HOME_MANAGER_BACKUP_EXT="''${HOME_MANAGER_BACKUP_EXT:-backup}"
    '';

    # Homebrew is outside nix; ensure it stays on PATH even when a parent
    # shell left __NIX_DARWIN_SET_ENVIRONMENT_DONE set (stale PATH).
    home.sessionPath = lib.optionals pkgs.stdenv.isDarwin [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];

    # HM-managed ~/.zshrc (and related). System /etc/zsh* stays with nix-darwin.
    programs.zsh = {
      enable = true;
      initContent = lib.concatStringsSep "\n" [
        (lib.optionalString pkgs.stdenv.isDarwin ''
          path=('/opt/homebrew/bin' '/opt/homebrew/sbin' $path)
        '')
        # NixOS-style green bracketed prompt (no snowflake).
        ''
          PROMPT=$'\n%F{green}[%n@%m:%~]%# %f'
        ''
      ];
    };

    programs.git = {
      enable = true;
      settings = {
        user.name = "Connor Fuhrman";
        user.email = "connormfuhrman@gmail.com";
        init.defaultBranch = "master";
        push.autoSetupRemote = true;
        core.pager = "ydiff -s --wrap";
        interactive.diffFilter = "ydiff -s";
      };
    };
  };
}
