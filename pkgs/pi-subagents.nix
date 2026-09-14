# pi-subagents: sub-agent orchestration for the pi coding agent
# (@tintinweb/pi-subagents).
#
# Consumed as a local-path pi package: the derivation output contains the
# package plus its runtime node_modules, so pi loads it directly from the
# store (no runtime npm install). Referenced from modules/home/pi.nix via
# programs.pi-coding-agent.settings.packages.
#
# Build approach: the npm tarball is used verbatim (pi loads its TS entry
# `src/index.ts` with its own loader; nothing needs compiling). We do NOT
# use buildNpmPackage: upstream's package-lock.json is unusable with
# prefetch-npm-deps (dev-only @earendil-works/pi-coding-agent@0.84.2
# subtree entries lack integrity hashes and crash the fetcher), and the
# full dep tree would drag in test-only tooling. Instead node_modules is
# assembled directly from the registry tarballs pinned by upstream's
# lockfile — every runtime dep is zero-dependency, so the closure is flat.
#
# Version pin: 0.17.1 is the newest release whose peer dependency covers
# nixpkgs' pi-coding-agent (>= 0.80.0; 0.18+ require >= 0.81/0.84). The
# @earendil-works/* peer deps are provided by pi's bundled runtime, not
# installed here.
{
  lib,
  runCommand,
  stdenvNoCC,
  fetchurl,
}:

let
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

  tarballUrl = dep: let
    base = builtins.head (lib.reverseList (lib.splitString "/" dep.name));
  in "https://registry.npmjs.org/${dep.name}/-/${base}-${dep.version}.tgz";

  # Flat node_modules: each dep is a zero-dependency package tarball.
  nodeModules = runCommand "pi-subagents-node-modules" { } (
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
  pname = "pi-subagents";
  version = "0.17.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@tintinweb/pi-subagents/-/pi-subagents-${finalAttrs.version}.tgz";
    hash = "sha256-+bwgrR51AErnXDjDdRRUTpkIK75nrJ/1pewetN7rMnA=";
  };

  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    local pkgOut="$out/lib/node_modules/@tintinweb/pi-subagents"
    mkdir -p "$pkgOut"
    cp -r . "$pkgOut/"
    cp -r "${nodeModules}" "$pkgOut/node_modules"

    runHook postInstall
  '';

  passthru = {
    # Path to register in pi settings (local-path package source).
    piPackagePath = "${finalAttrs.finalPackage}/lib/node_modules/@tintinweb/pi-subagents";
  };

  meta = {
    description = "Sub-agent orchestration for the pi coding agent";
    homepage = "https://github.com/tintinweb/pi-subagents";
    license = lib.licenses.mit;
  };
})
