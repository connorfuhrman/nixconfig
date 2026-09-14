# pi-subagents: sub-agent orchestration for the pi coding agent
# (@tintinweb/pi-subagents).
#
# Version pin: 0.17.1 is the newest release whose pi peer dependency covers
# nixpkgs' pi-coding-agent (>= 0.80.0; 0.18+ require >= 0.81/0.84).
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-subagents";
  npmName = "@tintinweb/pi-subagents";
  version = "0.17.1";
  hash = "sha256-+bwgrR51AErnXDjDdRRUTpkIK75nrJ/1pewetN7rMnA=";
  # Runtime deps pinned to upstream's package-lock.json (v0.17.1).
  deps = [
    {
      name = "@sinclair/typebox";
      version = "0.34.49";
      hash = "sha256-+qQOQeVjP4MSaZLDY4z58lyjWnFBdEwvrF7MhjeYqfQ=";
    }
    {
      name = "croner";
      version = "10.0.1";
      hash = "sha256-1tk8KGEl/tVnuYaldv8dqnTnLVa7Y/4oJIyhfPywDO4=";
    }
    {
      name = "nanoid";
      version = "5.1.11";
      hash = "sha256-7kw/yTPdayd+Ndo/NogDexoiJZRssTBjnepTTlrDxHA=";
    }
  ];
  description = "Sub-agent orchestration for the pi coding agent";
  homepage = "https://github.com/tintinweb/pi-subagents";
  license = lib.licenses.mit;
}
