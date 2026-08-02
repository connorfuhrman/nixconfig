# Generic opencode skill packager.
# callPackage with: { name = "…"; src = ./path-to-skill-dir; }
{ stdenvNoCC, name, src }:
stdenvNoCC.mkDerivation {
  pname = "opencode-skill-${name}";
  version = "1.0.0";
  inherit src;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/opencode/skills/${name}
    cp -a . $out/share/opencode/skills/${name}/
    runHook postInstall
  '';
  meta.description = "opencode skill: ${name}";
}
