{ ... }: {
  # Mac-friendly Emacs (Emacs Plus) via the d12frosted/emacs-plus Homebrew
  # tap. The cask is a prebuilt, native-compiled Emacs.app (~1 min install,
  # includes Emacs.app + Emacs Client.app). The tap is trusted declaratively
  # (Homebrew 6.0+ requires trust for third-party taps).
  flake.modules.darwin.emacs-plus = { ... }: {
    homebrew.taps = [
      { name = "d12frosted/emacs-plus"; trusted = true; }
    ];
    homebrew.casks = [ "emacs-plus-app" ];
  };
}
