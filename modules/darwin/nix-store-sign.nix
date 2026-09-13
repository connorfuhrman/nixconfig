{ ... }: {
  # Sign locally-built store paths on mac-mini (signer only).
  #
  # Secret is installed out-of-band at secretKeyPath — never commit it.
  # See docs/plans/nix-store-signing.md.
  flake.modules.darwin.nix-store-sign = { ... }: let
    secretKeyPath = "/etc/nix/keys/mac-mini-1.secret";
  in {
    nix.settings.secret-key-files = [ secretKeyPath ];
  };
}
