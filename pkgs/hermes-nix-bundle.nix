{
  symlinkJoin,
  hermes-cli,
  hermes-gateway,
  hermes-share,
}:
symlinkJoin {
  name = "hermes-nix-bundle-1.1.0";
  paths = [
    hermes-cli
    hermes-gateway
    hermes-share
  ];
  passthru = {
    inherit hermes-cli hermes-gateway hermes-share;
    profile = hermes-share.passthru.profile;
  };
  meta = {
    description = "Nono-wrapped Hermes (cli + gateway + share)";
    mainProgram = "hermes";
  };
}
