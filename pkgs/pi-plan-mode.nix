# pi-plan-mode: plan mode for the pi coding agent (@narumitw/pi-plan-mode).
#
# Consumed as a local-path pi package: the derivation output contains the
# package plus its runtime node_modules, so pi loads it directly from the
# store (no runtime npm install). Referenced from modules/home/pi.nix via
# programs.pi-coding-agent.settings.packages.
#
# Build approach: the npm tarball is used verbatim — it already contains
# the esbuild-generated TS entry `dist/index.ts` that pi's manifest loads
# (`packages: "external"` bundle; pi transpiles it at load time). We do
# NOT use buildNpmPackage: upstream publishes from the
# narumiruna/pi-extensions monorepo whose root package-lock.json is
# unusable with prefetch-npm-deps (dozens of entries lack integrity
# hashes). Instead node_modules is assembled directly from the registry
# tarballs pinned by upstream's lockfile — every runtime dep is
# zero-dependency (or depends only on the other two), so the closure is
# flat:
#   @narumitw/pi-tui-kit@0.59.0 -> grok-mermaid@0.2.3, highlight.js@11.12.0
#
# Versioning: pin the release commit-equivalent npm tarball. Peer deps
# (`@earendil-works/pi-*`, peer range `*`) are provided by pi's bundled
# runtime, not installed here.
{
  lib,
  runCommand,
  stdenvNoCC,
  fetchurl,
}:

let
  # Runtime dep tree pinned to upstream's package-lock.json (0.58.0).
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

  tarballUrl = dep: let
    base = builtins.head (lib.reverseList (lib.splitString "/" dep.name));
  in "https://registry.npmjs.org/${dep.name}/-/${base}-${dep.version}.tgz";

  # Flat node_modules: pi-tui-kit's deps (grok-mermaid, highlight.js) are
  # zero-dependency, so they hoist to the package root like npm would.
  nodeModules = runCommand "pi-plan-mode-node-modules" { } (
    lib.concatStringsSep "\n" (
      map (dep: ''
        mkdir -p "$out/${dep.name}"
        tar -xzf "${
          fetchurl {
            url = tarballUrl dep;
            hash = dep.hash;
          }
        }" -C "$out/${dep.name}" --strip-components=1
      '') deps
    )
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-plan-mode";
  version = "0.58.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@narumitw/pi-plan-mode/-/pi-plan-mode-${finalAttrs.version}.tgz";
    hash = "sha256-K1wobYWW6tfQjx79Io4gTev4PPvYd8CVE0m88ZGoL2w=";
  };

  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    local pkgOut="$out/lib/node_modules/@narumitw/pi-plan-mode"
    mkdir -p "$pkgOut"
    cp -r . "$pkgOut/"
    cp -r "${nodeModules}" "$pkgOut/node_modules"

    runHook postInstall
  '';

  passthru = {
    # Path to register in pi settings (local-path package source).
    piPackagePath = "${finalAttrs.finalPackage}/lib/node_modules/@narumitw/pi-plan-mode";
  };

  meta = {
    description = "Plan mode for the pi coding agent";
    homepage = "https://github.com/narumiruna/pi-extensions";
    license = lib.licenses.mit;
  };
})
