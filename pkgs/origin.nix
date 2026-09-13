# Cursor Origin CLI (prebuilt). Artifact URLs and SHA256s come from the
# public installer at https://downloads.cursor.com/origin/install.sh
# (latest channel). Bump by copying that file's version + per-platform
# hashes; CDN paths stay under the legacy `co/` prefix.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

let
  inherit (stdenv) hostPlatform;
  version = "2026.09.03-12-04-37-b7e9da7";
  sources = {
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/co/${version}/darwin-arm64/co.tar.gz";
      hash = "sha256-Ahk3Izaa+zQXaOCkcSNY9MgFSaFxDKiDRhATKqpFBAQ=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/co/${version}/darwin-x64/co.tar.gz";
      hash = "sha256-iw7QMoMhx3BdvW98p77H4ibBNYe7i5AlQCeC9fNqQZI=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/co/${version}/linux-arm64/co.tar.gz";
      hash = "sha256-mjLmUXn655MrAZb4p+SWEvgmOzYuEsoM4BppiDBlPEM=";
    };
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/co/${version}/linux-x64/co.tar.gz";
      hash = "sha256-HWDmKa4hoZiFDcaCcZwfMFCzVoFkxlSf6BEtsysIVbs=";
    };
  };
in
stdenv.mkDerivation {
  pname = "origin";
  inherit version;

  src = sources.${hostPlatform.system} or (throw "origin: unsupported system ${hostPlatform.system}");

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals hostPlatform.isLinux [
    autoPatchelfHook
    stdenv.cc.cc.lib
  ];

  buildInputs = lib.optionals hostPlatform.isLinux [ zlib ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 origin $out/bin/origin
    runHook postInstall
  '';

  meta = {
    description = "Cursor Origin CLI for repos, pull requests, and git auth";
    homepage = "https://cursor.com/docs/origin/cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "origin";
    platforms = builtins.attrNames sources;
  };
}
