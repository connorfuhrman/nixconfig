{ ... }: {
  # Always-on headless server behavior for macOS hosts.
  flake.modules.darwin.server = { pkgs, config, ... }: {
    environment.systemPackages = [ pkgs.mosh ];

    # Headless remote host: auto-login primary user at the console on boot.
    # Console auto-login does not change SSH auth (password still required).
    # /etc/kcpassword is a one-time hardware step:
    # sudo sysadminctl -autologin set -userName connorfuhrman -password -
    system.defaults.loginwindow.autoLoginUser = config.system.primaryUser;
    system.defaults.loginwindow.GuestEnabled = false;

    # Tailscale for remote access; keep tailscaled alive across crashes.
    services.tailscale.enable = true;
    launchd.daemons.tailscaled.serviceConfig.KeepAlive = true;

    # Power policy: never sleep, wake on LAN, and auto-start after AC loss.
    #
    # pmset autorestart + nix-darwin power.restartAfterPowerFailure (systemsetup
    # "Start up automatically after a power failure") are the legacy Intel-era
    # pair; they often do not cold-boot Apple Silicon after a full AC disconnect.
    # macOS Tahoe 26.5+ adds Energy → "Start up when power is connected"
    # (Jeff Geerling / Apple Silicon desktop servers); pmset exposes it as
    # autorestartatconnect (no -a flag). Hardware-gated: 2024+ Mac mini, 2025+
    # Mac Studio, 2024+ iMac. nix-darwin master will ship
    # power.universal.autoRestart.onPowerConnect; until then we set it here.
    power.restartAfterPowerFailure = true;

    system.activationScripts.serverPower.text = ''
      pmset -a sleep 0
      pmset -a autorestart 1
      pmset -a womp 1
      pmset autorestartatconnect 1
    '';

    # Keep SSH (Remote Login) enabled for remote builds and administration.
    # If macOS privacy restrictions make this fail, enable it once manually:
    # System Settings → General → Sharing → Remote Login.
    # mosh-server rides on Remote Login (UDP 60000-61000); allow through
    # macOS Application Firewall if you enable it.
    system.activationScripts.remoteLogin.text = ''
      systemsetup -setremotelogin on || true
    '';
  };
}
