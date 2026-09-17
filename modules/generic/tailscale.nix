{ ... }: {
  # Tailscale mesh VPN on every machine (NixOS and nix-darwin alike).
  #
  # One-time per machine, after the first rebuild that includes this module:
  #   sudo tailscale up
  # and sign in (credentials live in 1Password). With MagicDNS enabled on the
  # tailnet, machines then resolve by their plain hostnames (e.g. `mac-mini`).
  #
  # Note: on macOS this is the headless tailscaled (launchd). Do NOT also
  # install the Tailscale.app cask on a machine using this module — they
  # conflict.
  flake.modules.generic.tailscale = { ... }: {
    services.tailscale.enable = true;
  };
}
