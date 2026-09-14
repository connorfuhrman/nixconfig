# pi-usage: provider quota/balance dashboard for the pi coding agent
# (@narumitw/pi-usage). Published from the narumiruna/pi-extensions
# monorepo; peer deps (@earendil-works/pi-*, range `*`) are provided by
# pi's bundled runtime.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-usage";
  npmName = "@narumitw/pi-usage";
  version = "0.60.8";
  hash = "sha256-hmf2O/j8xQx702EQE4hEtr7b0hVea3boDGh7A3S12/w=";
  deps = [
    {
      name = "@narumitw/pi-tui-kit";
      version = "0.61.0";
      hash = "sha256-v2DZv0Ea7Unmedj26yeyJyFd0ga7C8aOnnzaCptA6cs=";
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
  description = "Provider quota/balance dashboard for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}