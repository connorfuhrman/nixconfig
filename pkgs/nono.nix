# nono: zero-latency AI agent sandbox (Seatbelt on macOS, Landlock on Linux).
# Binary release (upstream does not publish a build recipe); autoPatchelf for
# the Linux glibc build.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  pname = "nono";
  version = "0.77.0";
  system = stdenv.hostPlatform.system;

  # Upstream rustc target triple in the release tarball name.
  rustTarget =
    {
      "aarch64-darwin" = "aarch64-apple-darwin";
      "x86_64-darwin" = "x86_64-apple-darwin";
      "aarch64-linux" = "aarch64-unknown-linux-gnu";
      "x86_64-linux" = "x86_64-unknown-linux-gnu";
    }
    .${system};

  hashes = {
    "aarch64-darwin" = "sha256-G0E+YXWPXiEvHGg7lcOq2zeZoB29VGhd1+rjN4LefxI=";
    "x86_64-darwin" = "sha256-tprEm58pGHlY8C+sJYDfs4vwzhSbxThaTxr+dlvjCbY=";
    "aarch64-linux" = "sha256-f1IxI75y2CVjW75jy4tnIxi5dPw8qEHNMMaW8dVAwWg=";
    "x86_64-linux" = "sha256-hrz3oTTW9H4GStDyVh8b4Cuf/8ZDcIw+wt1AcOgreY4=";
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
