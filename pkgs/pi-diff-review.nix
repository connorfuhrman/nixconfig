# pi-diff-review: interactive diff review UI (vim keys, inline comments)
# for the pi coding agent (@johnfodero/pi-diff-review). Zero runtime deps;
# peer deps (@earendil-works/pi-*, range `*`) come from pi's bundled
# runtime.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-diff-review";
  npmName = "@johnfodero/pi-diff-review";
  version = "1.1.2";
  hash = "sha256-IBtuUO9/eGW0vCYW933Va3AkzhDmuhbK+wlmac4HVmc=";
  deps = [ ];
  description = "Interactive diff review for the pi coding agent";
  homepage = "https://github.com/johnfodero/pi-diff-review";
  license = lib.licenses.mit;
}