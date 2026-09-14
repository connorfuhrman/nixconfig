# pi-tasks: Claude Code-style task tracking for the pi coding agent
# (@tintinweb/pi-tasks). Peer deps (@earendil-works/pi-*) are provided by
# pi's bundled runtime; typebox is a zero-dependency real dep.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-tasks";
  npmName = "@tintinweb/pi-tasks";
  version = "0.9.0";
  hash = "sha256-VomARzIvrn0lpyTLJ8zG8bbmYQ4jTiOYdZBEJ3csRPg=";
  deps = [
    {
      name = "typebox";
      version = "1.3.30";
      hash = "sha256-FLQzO6IIpjioBMIu3clhHFCLgvF4RAWUq8mauM0T4kk=";
    }
  ];
  description = "Task tracking (create/get/list/update) for the pi coding agent";
  homepage = "https://github.com/tintinweb/pi-subagents";
  license = lib.licenses.mit;
}