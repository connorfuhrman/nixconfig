# Home-manager: CriticMarkup CLI (cm). Package body: pkgs/cm.nix
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # Go unit tests for cm source (not a package build).
      checks.cm-go-test =
        pkgs.runCommand "cm-go-test"
          {
            nativeBuildInputs = [ pkgs.go ];
          }
          ''
            export HOME=$TMPDIR
            export GOCACHE=$TMPDIR/go-cache
            export GOPATH=$TMPDIR/gopath
            cp -r ${./_tools/criticmarkup} ./src
            chmod -R u+w ./src
            cd src
            go test -count=1 .
            touch $out
          '';
    };

  flake.modules.homeManager.criticmarkup =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.cm ];
    };
}
