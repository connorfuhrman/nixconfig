{ ... }: {
  # Everyday CLI upgrades shared across all home configurations.
  flake.modules.homeManager.coreutils = { pkgs, ... }: {
    home.packages = with pkgs; [
      bat
      ydiff
      dust
      jq
      gtop
      gping
    ];

    programs.eza.enable = true;
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zsh.shellAliases = {
      ls = "eza";
    };

    programs.tmux = {
      enable = true;
      mouse = true;
      clock24 = true;
      baseIndex = 1;
      escapeTime = 0;
      historyLimit = 50000;
      terminal = "tmux-256color";
      focusEvents = true;
      aggressiveResize = true;
      keyMode = "emacs";
      prefix = "C-a";
      shortcut = "a";

      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        pain-control
        better-mouse-mode
        prefix-highlight
        {
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavor "mocha"
            set -g @catppuccin_window_status_style "rounded"
          '';
        }
        {
          plugin = resurrect;
          extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'
          '';
        }
      ];

      extraConfig = ''
        set -g renumber-windows on
        set -g status-position top
        set -as terminal-features ",*:RGB"
        set -g set-clipboard on

        # Keep cwd when splitting (pain-control also binds | / -)
        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"

        # Prefix + r reloads config
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux reloaded"

        # Faster pane switching with Alt+arrows (no prefix)
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D
      '';
    };
  };
}
