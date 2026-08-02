# Generic npm-tarball → node_modules layout for opencode plugins.
# URL is derived from pname + version when `url` is omitted:
#   https://registry.npmjs.org/<pname>/-/<basename>-<version>.tgz
{
  stdenvNoCC,
  fetchurl,
  lib,
  pname,
  version,
  hash,
  url ? null,
}:
let
  # @scope/name → name; bare name → name
  basename = lib.last (lib.splitString "/" pname);
  defaultUrl = "https://registry.npmjs.org/${pname}/-/${basename}-${version}.tgz";
in
stdenvNoCC.mkDerivation {
  inherit pname version;
  src = fetchurl {
    url = if url != null then url else defaultUrl;
    inherit hash;
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/${pname}
    if [ -d package ]; then
      cp -a package/. $out/lib/node_modules/${pname}/
    else
      cp -a . $out/lib/node_modules/${pname}/
    fi
    runHook postInstall
  '';
}
