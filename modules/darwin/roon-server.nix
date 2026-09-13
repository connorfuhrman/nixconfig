{ ... }: {
  # Roon Server (Core) on macOS via the Roon app.
  #
  # Roon no longer ships a standalone headless "Roon Server" for macOS —
  # Roon.app IS the Core (nixpkgs' roon-server package is x86_64-linux only).
  # So we install Roon.app via Homebrew and let Roon manage its own
  # "RoonServer" login item.
  #
  # One-time setup after the first rebuild that includes this module:
  #   1. Install Homebrew on the machine if missing:
  #      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  #   2. Open Roon.app, sign in, and choose to use this Mac as the Roon
  #      Server (Core). Enable Roon's "launch at login" option.
  #   3. Console auto-login for start-on-boot without logging in is declared
  #      in the darwin `server` module via nix-darwin
  #      `system.defaults.loginwindow.autoLoginUser` (connorfuhrman). If
  #      auto-login is not already configured on the machine, run once:
  #      `sudo sysadminctl -autologin set -userName connorfuhrman -password -`
  #      (creates `/etc/kcpassword`).
  #   (The darwin `server` module already keeps the machine awake and
  #   restarts it after power failures.)
  flake.modules.darwin.roon-server = { ... }: {
    homebrew.enable = true;
    homebrew.casks = [ "roon" ];
  };
}
