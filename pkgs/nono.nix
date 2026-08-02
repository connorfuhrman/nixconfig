{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  pname = "nono";
  version = "0.69.0";
  system = stdenv.hostPlatform.system;

  # upstream rustc target triple in the release tarball name
  rustTarget = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
  }.${system};

  hashes = {
    "aarch64-darwin" = "sha256-gf9O/2Wpds2hAu+B7pb/n4Zo95iA++tr/g+QNd+QPwU=";
    "aarch64-linux" = "sha256-rcBz9c2gFBHEZnNF9PBN1AAv2rSswcNEvYba4d4hkWA=";
    "x86_64-linux" = "sha256-PHn7DcKpFxt9RBAmllZm9WUsQvZ7xXEKJ9jp+Sgi9hk=";
  };
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl {
    url = "https://github.com/nolabs-ai/nono/releases/download/v${version}/${pname}-v${version}-${rustTarget}.tar.gz";
    hash = hashes.${system};
  };
  sourceRoot = ".";
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    bin="$(find . -maxdepth 3 -type f -name nono | head -n 1)"
    test -n "$bin"
    install -Dm755 "$bin" $out/bin/nono
    runHook postInstall
  '';
  meta = {
    description = "Zero-latency AI agent sandbox";
    homepage = "https://github.com/nolabs-ai/nono";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "nono";
  };
}
