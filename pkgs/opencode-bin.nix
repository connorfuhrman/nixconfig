{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:
let
  pname = "opencode-bin";
  version = "1.18.5";
  system = stdenv.hostPlatform.system;

  # upstream asset filename suffix (after opencode-)
  asset = {
    "aarch64-darwin" = "darwin-arm64.zip";
    "aarch64-linux" = "linux-arm64-musl.tar.gz";
    "x86_64-linux" = "linux-x64-musl.tar.gz";
  }.${system};

  hashes = {
    "aarch64-darwin" = "sha256-hfb57s4XTTvwySWICGplKEOIuJElbI9BAtwxfUdv/KY=";
    "aarch64-linux" = "sha256-1JP20VvUwstCnVnFIT6iNxKPTdiJqUJpg7TG5dLAR64=";
    "x86_64-linux" = "sha256-8WToUsf/mK/5nv0DnzrCrN0XF+Jfa5TEceLIJ1IvZyw=";
  };
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-${asset}";
    hash = hashes.${system};
  };
  sourceRoot = ".";
  nativeBuildInputs = lib.optionals stdenv.isDarwin [ unzip ];
  installPhase = ''
    runHook preInstall
    bin="$(find . -maxdepth 3 -type f -name opencode | head -n 1)"
    test -n "$bin"
    install -Dm755 "$bin" $out/bin/opencode
    runHook postInstall
  '';
  meta = {
    description = "AI coding agent (upstream binary)";
    homepage = "https://opencode.ai";
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "opencode";
  };
}
