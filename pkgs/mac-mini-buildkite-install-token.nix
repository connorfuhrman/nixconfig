{ writeShellScriptBin }:
writeShellScriptBin "mac-mini-buildkite-install-token" (
  builtins.readFile ./mac-mini-buildkite-install-token.sh
)
