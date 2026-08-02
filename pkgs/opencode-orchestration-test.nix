{
  stdenvNoCC,
  fetchurl,
  nodejs,
  runtimeShell,
  opencode,
}:
let
  sdk = fetchurl {
    url = "https://registry.npmjs.org/@opencode-ai/sdk/-/sdk-1.18.11.tgz";
    hash = "sha256-EmHTx2xUJpc1tP6bYOrEpnz5SC8ZpvIIWL+LnjQCCeE=";
  };
  testSrc = ../modules/opencode/_test/opencode-orchestration-test;
  modelsFile = opencode.passthru.modelsFile;
  agentsDir = opencode.passthru.agentsDir;
in
stdenvNoCC.mkDerivation {
  pname = "opencode-orchestration-test";
  version = "1.0.0";
  dontUnpack = true;
  nativeBuildInputs = [ nodejs ];
  buildPhase = ''
    mkdir -p $out/lib/test/node_modules/@opencode-ai
    tar -xzf ${sdk} -C $out/lib/test/node_modules/@opencode-ai
    if [ -d $out/lib/test/node_modules/@opencode-ai/package ]; then
      mv $out/lib/test/node_modules/@opencode-ai/package $out/lib/test/node_modules/@opencode-ai/sdk
    fi
    cp ${testSrc}/test.mjs $out/lib/test/test.mjs
  '';
  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/opencode-orchestration-test <<EOF
    #!${runtimeShell}
    export NODE_PATH=$out/lib/test/node_modules
    export OPENCODE_ORCHESTRATION_MODELS=${modelsFile}
    export OPENCODE_AGENTS_DIR=${agentsDir}
    exec ${nodejs}/bin/node $out/lib/test/test.mjs
    EOF
    chmod +x $out/bin/opencode-orchestration-test
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    export NODE_PATH=$out/lib/test/node_modules
    export OPENCODE_ORCHESTRATION_MODELS=${modelsFile}
    export OPENCODE_AGENTS_DIR=${agentsDir}
    ${nodejs}/bin/node $out/lib/test/test.mjs
  '';
  meta.mainProgram = "opencode-orchestration-test";
}
