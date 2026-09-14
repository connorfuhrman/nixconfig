# pi-goal: autonomous single-objective /goal completion for the pi coding
# agent (@narumitw/pi-goal). Published from the narumiruna/pi-extensions
# monorepo; peer deps (@earendil-works/pi-*, range `*`) are provided by pi's
# bundled runtime. tuiPolyfill: pi-goal imports stripTerminalSequences from
# @earendil-works/pi-tui, which pi 0.80.10 lacks (crashes goal mode).
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-goal";
  npmName = "@narumitw/pi-goal";
  version = "0.54.4";
  hash = "sha256-s/qHmedg12sm+YBJ3g7DKLnaLDVb5Ra0hOp7CJLDihc=";
  tuiPolyfill = true;
  # Runtime deps pinned to upstream's package-lock.json (0.54.4) — same
  # tree as pi-plan-mode.
  deps = [
    {
      name = "@narumitw/pi-tui-kit";
      version = "0.59.0";
      hash = "sha256-NKgaW5StT7YhxMSSObxexuoBSdLkALMnpoZ/dbe2cDU=";
    }
    {
      name = "grok-mermaid";
      version = "0.2.3";
      hash = "sha256-QdAgY/UyYf6GmsttoLAYONbs4JXXOnBjZFzgRC8NjIg=";
    }
    {
      name = "highlight.js";
      version = "11.12.0";
      hash = "sha256-rMv6qrdFCIYJtO6ivcoq1i8fHdJzBOD432XP4P4EIUM=";
    }
  ];
  description = "Autonomous /goal completion for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}