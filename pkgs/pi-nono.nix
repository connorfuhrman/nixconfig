# Sandboxed pi: the pi coding agent wrapped in the nono sandbox.
# The profile is pi's agent home (~/.pi: auth, sessions, trust) plus the
# shared AI-agent baseline; node is on PATH for pi package support.
{
  callPackage,
  lib,
  nodejs,
  nono-profiles,
  pi-coding-agent,
}:
callPackage ./nono-wrap.nix {
  name = "pi-nono";
  package = pi-coding-agent;
  executable = "pi";
  profile = nono-profiles.extendProfile nono-profiles.agentBase {
    meta.name = "pi-nono";
    meta.description = "pi coding agent under the nono sandbox";
    filesystem.allow = [
      # pi agent home: auth (~/.pi/agent), sessions, trust decisions, and
      # npm-installed pi packages (~/.pi/agent/npm|git via PI_PACKAGE_DIR).
      "$HOME/.pi"
    ];
  };
  extraPackages = [ nodejs ];
  description = "pi coding agent under the nono sandbox";
}
