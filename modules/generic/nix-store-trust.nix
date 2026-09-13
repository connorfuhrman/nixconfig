{ ... }: {
  # Trust store paths signed by mac-mini (see docs/plans/nix-store-signing.md).
  #
  # Import on every host that copies closures FROM mac-mini (nix copy --from
  # ssh-ng://mac-mini, remote builder results, substituters). Self-trust on
  # mac-mini is fine.
  flake.modules.generic.nix-store-trust = { lib, pkgs, ... }: let
    # REPLACE modules/generic/keys/mac-mini.public after generating the keypair
    # on mac-mini — see docs/plans/nix-store-signing.md.
    macMiniPublicKey =
      lib.removeSuffix "\n" (builtins.readFile ./keys/mac-mini.public);
  in {
    # Append without clobbering cache.nixos.org-1 (default) or keys from
    # flake.nix / nixos.asahi (apple-silicon cachix).
    nix.settings.extra-trusted-public-keys = lib.mkAfter [ macMiniPublicKey ];

    # trusted-users ≈ root-equivalent for the store (CLI extra-trusted-*,
    # --no-check-sigs stopgap). Do not use "*" or disable require-sigs.
    nix.settings.trusted-users = lib.mkAfter (
      [ "root" "connorfuhrman" ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "@admin" ]
    );
  };
}
