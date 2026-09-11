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
  #   3. For start-on-boot without logging in: System Settings →
  #      Users & Groups → Automatic login → connorfuhrman.
  #   (The darwin `server` module already keeps the machine awake and
  #   restarts it after power failures.)
  flake.modules.darwin.roon-server = { ... }: {
    homebrew.enable = true;
    homebrew.casks = [ "roon" ];
  };
}
