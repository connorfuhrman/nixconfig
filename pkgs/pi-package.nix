# Generic pi coding-agent package: npm tarball verbatim + flat
# zero-dependency node_modules, for consumption as a local-path pi package
# source (see modules/home/pi.nix — pi loads store paths directly, no
# runtime npm install).
#
# Why not buildNpmPackage / importNpmLock (nixpkgs' current tooling)? Both
# require a well-formed package-lock.json, and the upstreams pinned here
# publish lockfiles with integrity-less dev-only @earendil-works/* entries
# that crash prefetch-npm-deps. Every dep must therefore be pinned manually
# below — and each one must be zero-dependency, so a flat hoisted node_modules
# is correct. TS entries are loaded (transpiled) by pi at runtime; nothing
# needs building.
#
# callPackage with:
#   pname      derivation-safe name (no "@"; e.g. "pi-plan-mode")
#   npmName    npm package name (may be scoped; e.g. "@narumitw/pi-plan-mode")
#   version    npm version
#   hash       SRI hash of the npm tarball
#   deps       runtime dependency closure, pinned to upstream's lockfile:
#              [ { name; version; hash } ] — each entry zero-dependency
#   deps       runtime dependency closure, pinned to upstream's lockfile:
#              [ { name; version; hash } ] — each entry zero-dependency
#   postInstall  extra installPhase shell commands, run after the package
#                and node_modules are copied (has $pkgOut in scope)
#   description / homepage / license   meta passthrough
{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  pname,
  npmName,
  version,
  hash,
  deps ? [ ],
  postInstall ? "",
  description,
  homepage,
  license,
}: let
  # Registry tarball URL; scoped and unscoped packages both ship "package/"
  # as the single top-level directory.
  tarballUrl = name: v:
    "https://registry.npmjs.org/${name}/-/${
      builtins.head (lib.reverseList (lib.splitString "/" name))
    }-${v}.tgz";

  # Flat node_modules: every dep is zero-dependency, so they hoist to the
  # package root exactly like npm would.
  nodeModules = runCommand "pi-node-modules-${pname}" { } (
    lib.concatStringsSep "\n" (
      map (dep: ''
        mkdir -p "$out/${dep.name}"
        tar -xzf "${
          fetchurl {
            url = tarballUrl dep.name dep.version;
            hash = dep.hash;
          }
        }" -C "$out/${dep.name}" --strip-components=1
      '')
      deps
    )
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = tarballUrl npmName version;
    inherit hash;
  };

  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    local pkgOut="$out/lib/node_modules/${npmName}"
    mkdir -p "$pkgOut"
    cp -r . "$pkgOut/"
    cp -r "${nodeModules}" "$pkgOut/node_modules"

    ${postInstall}

    runHook postInstall
  '';

  passthru = {
    # Path to register in pi settings (local-path package source).
    piPackagePath = "${finalAttrs.finalPackage}/lib/node_modules/${npmName}";
  };

  meta = {
    inherit description homepage license;
  };
})
