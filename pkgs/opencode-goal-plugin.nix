{ callPackage }:
callPackage ./opencode-npm-plugin.nix {
  pname = "@prevalentware/opencode-goal-plugin";
  version = "0.1.29";
  hash = "sha256-7kFgin0luOREk56fx8KsANEHcYp7rFcm/rQiJxJRj+I=";
  # url derived from pname + version in opencode-npm-plugin.nix
}
