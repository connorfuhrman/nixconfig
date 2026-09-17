# pi-worktree: git worktree isolation for parallel agent work
# (@narumitw/pi-worktree). Published from the narumiruna/pi-extensions
# monorepo; peer deps (@earendil-works/pi-*, range `*`) are provided by
# pi's bundled runtime.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-worktree";
  npmName = "@narumitw/pi-worktree";
  version = "0.51.7";
  hash = "sha256-uuOKqJLK/Feqzbs9DoXtFo8l351VKZRy6PFJJpQFf+I=";
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
  description = "Git worktree isolation for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}
