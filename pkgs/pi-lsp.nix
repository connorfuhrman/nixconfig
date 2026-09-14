# pi-lsp: language server integration (diagnostics for the agent) for the
# pi coding agent (@narumitw/pi-lsp). Zero runtime deps; peer deps
# (@earendil-works/pi-*, typebox `*`) come from pi's bundled runtime.
{
  callPackage,
  lib,
}:
callPackage ./pi-package.nix {
  pname = "pi-lsp";
  npmName = "@narumitw/pi-lsp";
  version = "0.49.7";
  hash = "sha256-ELTGPYRpLokLZ5O7RlPFsAzSTAO76Hny3DGvh2nZ6xE=";
  deps = [ ];
  description = "Language server integration for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}