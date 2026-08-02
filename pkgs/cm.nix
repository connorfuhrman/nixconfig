{ buildGoModule, lib }:
buildGoModule {
  pname = "cm";
  version = "1.0.0";
  src = ../modules/opencode/_tools/criticmarkup;
  vendorHash = null;
  meta = {
    description = "CriticMarkup CLI (cm) for agent/human markdown review";
    homepage = "https://github.com/CriticMarkup/CriticMarkup-toolkit";
    mainProgram = "cm";
  };
  postInstall = ''
    if [ ! -e $out/bin/cm ]; then
      b="$(find $out/bin -type f -perm -111 | head -n1)"
      test -n "$b"
      mv "$b" $out/bin/cm
    fi
  '';
}
