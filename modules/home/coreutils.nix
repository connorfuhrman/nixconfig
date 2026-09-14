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
      origin
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
      # C-\ — rare in Emacs. Must be quoted: bare C-\ ends with \ (tmux line-cont).
      prefix = "'C-\\'";

      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        pain-control
        better-mouse-mode
        {
          plugin = prefix-highlight;
          extraConfig = ''
            set -g @prefix_highlight_fg '#0b1f0b'
            set -g @prefix_highlight_bg '#7dcea0'
            set -g @prefix_highlight_show_copy_mode 'on'
            set -g @prefix_highlight_copy_mode_attr 'fg=#0b1f0b,bg=#f0e68c,bold'
            set -g @prefix_highlight_prefix_prompt 'Wait'
            set -g @prefix_highlight_copy_prompt 'Copy'
          '';
        }
        mode-indicator
        extrakto
        tmux-thumbs
        tmux-fzf
        fuzzback
        logging
        session-wizard
        tmux-which-key
        copy-toolkit
        {
          plugin = cpu;
          extraConfig = ''
            set -g @cpu_low_fg_color '#[fg=#a8e6a1]'
            set -g @cpu_medium_fg_color '#[fg=#f0e68c]'
            set -g @cpu_high_fg_color '#[fg=#ff6b6b]'
            set -g @ram_low_fg_color '#[fg=#a8e6a1]'
            set -g @ram_medium_fg_color '#[fg=#f0e68c]'
            set -g @ram_high_fg_color '#[fg=#ff6b6b]'
          '';
        }
        battery
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
        set -as terminal-features ",*:RGB"
        set -g set-clipboard on

        # Prefix + send-prefix come from programs.tmux.prefix (quoted 'C-\')

        # --- Green bottom status (Direction A; no theme plugin) ---
        set -g status on
        set -g status-position bottom
        set -g status-interval 5
        set -g status-style "bg=#1a3d1a,fg=#a8e6a1"
        set -g status-left-length 48
        set -g status-right-length 140
        set -g status-left "#{prefix_highlight}#{tmux_mode_indicator}#[bold,fg=#0b1f0b,bg=#7dcea0] #S #[fg=#7dcea0,bg=#1a3d1a] "
        set -g status-right "#[fg=#7dcea0]#(cd #{pane_current_path} && git rev-parse --abbrev-ref HEAD 2>/dev/null) #{cpu_fg_color}#{cpu_percentage} #{ram_fg_color}#{ram_percentage} #{battery_icon} #{battery_percentage} #[fg=#7dcea0]#h #[fg=#a8e6a1]%H:%M "
        setw -g window-status-current-style "bg=#7dcea0,fg=#0b1f0b,bold"
        setw -g window-status-style "fg=#8fbc8f"
        setw -g window-status-format " #I:#W#F "
        setw -g window-status-current-format " #I:#W#F "
        set -g window-status-separator ""

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
