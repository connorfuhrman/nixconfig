# pi-plan-mode: plan mode for the pi coding agent (@narumitw/pi-plan-mode).
# Published from the narumiruna/pi-extensions monorepo; peer deps
# (@earendil-works/pi-*, range `*`) are provided by pi's bundled runtime.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-plan-mode";
  npmName = "@narumitw/pi-plan-mode";
  version = "0.58.0";
  hash = "sha256-K1wobYWW6tfQjx79Io4gTev4PPvYd8CVE0m88ZGoL2w=";
  # Runtime deps pinned to upstream's package-lock.json (0.58.0).
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
  description = "Plan mode for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}
