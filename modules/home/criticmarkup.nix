{ ... }:
let
  src = ./_tools/criticmarkup;
  mkCm = pkgs:
    pkgs.buildGoModule {
      pname = "cm";
      version = "1.0.0";
      inherit src;
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
    };
in
{
  perSystem = { pkgs, ... }: {
    packages.cm = mkCm pkgs;
    checks.cm-go-test = pkgs.runCommand "cm-go-test" {
      nativeBuildInputs = [ pkgs.go ];
    } ''
      export HOME=$TMPDIR
      export GOCACHE=$TMPDIR/go-cache
      export GOPATH=$TMPDIR/gopath
      cp -r ${src} ./src
      chmod -R u+w ./src
      cd src
      go test -count=1 .
      touch $out
    '';
  };

  flake.modules.homeManager.criticmarkup = { pkgs, ... }: {
    home.packages = [ (mkCm pkgs) ];
  };
}
