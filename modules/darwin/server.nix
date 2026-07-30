{ ... }: {
  # Always-on headless server behavior for macOS hosts.
  flake.modules.darwin.server = { ... }: {
    # Power policy: never sleep, restart after power failure, wake on LAN.
    system.activationScripts.serverPower.text = ''
      pmset -a sleep 0
      pmset -a autorestart 1
      pmset -a womp 1
    '';

    # Keep SSH (Remote Login) enabled for remote builds and administration.
    # If macOS privacy restrictions make this fail, enable it once manually:
    # System Settings → General → Sharing → Remote Login.
    system.activationScripts.remoteLogin.text = ''
      systemsetup -setremotelogin on || true
    '';
  };
}
