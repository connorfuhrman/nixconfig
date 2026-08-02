{ ... }: {
  # Always-on headless server behavior for macOS hosts.
  flake.modules.darwin.server = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mosh ];

    # Power policy: never sleep, restart after power failure, wake on LAN.
    system.activationScripts.serverPower.text = ''
      pmset -a sleep 0
      pmset -a autorestart 1
      pmset -a womp 1
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
