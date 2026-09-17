{
  installShellFiles,
  podman,
  runCommand,
  writeShellScript,
}:

let
  dockerWrapper = writeShellScript "docker-via-podman" ''
    export DOCKER_HOST="''${DOCKER_HOST:-unix:///var/run/docker.sock}"
    export CONTAINER_HOST="''${CONTAINER_HOST:-unix:///var/run/docker.sock}"
    exec ${podman}/bin/podman "$@"
  '';
in
runCommand "${podman.pname}-docker-compat-${podman.version}"
  {
    nativeBuildInputs = [ installShellFiles ];
    outputs = [
      "out"
      "man"
    ];
    inherit (podman) meta;
    preferLocalBuild = true;
  }
  ''
    mkdir -p $out/bin
    ln -s ${dockerWrapper} $out/bin/docker

    mkdir -p $man/share/man/man1
    for f in ${podman.man}/share/man/man1/*; do
      basename=$(basename "$f" | sed s/podman/docker/g)
      ln -s "$f" "$man/share/man/man1/$basename"
    done
  ''
