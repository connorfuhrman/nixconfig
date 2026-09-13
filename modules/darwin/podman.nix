{ ... }: {
  # Podman on macOS for Linux containers (Buildkite docker plugin on mac-mini-macos).
  #
  # nix-darwin has no virtualisation.podman — use nixpkgs podman (podman-remote +
  # vfkit/gvproxy on Apple Silicon) with a launchd helper and a /var/run/docker.sock
  # symlink for docker API compat.
  flake.modules.darwin.podman = { config, lib, pkgs, ... }:
    let
      primaryUser = config.system.primaryUser;
      agentUser = "buildkite-agent-macos";
      podman = pkgs.podman;

      dockerCompat = pkgs.runCommand "${podman.pname}-docker-compat-${podman.version}"
        {
          nativeBuildInputs = [ pkgs.installShellFiles ];
          outputs = [ "out" "man" ];
          inherit (podman) meta;
          preferLocalBuild = true;
        }
        ''
          mkdir -p $out/bin
          ln -s ${podman}/bin/podman $out/bin/docker

          mkdir -p $man/share/man/man1
          for f in ${podman.man}/share/man/man1/*; do
            basename=$(basename "$f" | sed s/podman/docker/g)
            ln -s "$f" "$man/share/man/man1/$basename"
          done
        '';

      podmanMachineEnsure = pkgs.writeShellScript "podman-machine-ensure" ''
        set -euo pipefail
        export HOME="/Users/${primaryUser}"
        export PATH="${lib.makeBinPath [ podman ]}:$PATH"

        machine=podman-machine-default

        if ! podman machine list --format '{{.Name}}' 2>/dev/null | grep -qx "$machine"; then
          echo "podman machine $machine missing — run once as ${primaryUser}:" >&2
          echo "  podman machine init --rootful $machine" >&2
          exit 1
        fi

        state="$(podman machine inspect "$machine" --format '{{.State}}' 2>/dev/null || true)"
        if [ "$state" != "running" ]; then
          podman machine start "$machine"
        fi

        sock="$(find "$HOME/.local/share/containers/podman/machine" -name podman.sock -print -quit 2>/dev/null || true)"
        if [ -z "$sock" ] || [ ! -S "$sock" ]; then
          echo "podman machine socket not found under $HOME/.local/share/containers/podman/machine" >&2
          exit 1
        fi

        mkdir -p /var/run
        ln -sf "$sock" /var/run/docker.sock
        chgrp docker "$sock"
        chmod 660 "$sock"
      '';
    in
    {
      environment.systemPackages = [
        podman
        dockerCompat
      ];

      users.knownGroups = lib.mkAfter [ "docker" ];
      users.groups.docker = {
        gid = lib.mkDefault 537;
        members = [ primaryUser agentUser ];
      };

      launchd.daemons.podman-machine = {
        path = [ podman ];
        script = "${podmanMachineEnsure}";
        serviceConfig = {
          UserName = primaryUser;
          RunAtLoad = true;
          StartInterval = 300;
          StandardOutPath = "/var/log/podman-machine.log";
          StandardErrorPath = "/var/log/podman-machine.log";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        launchctl kickstart -k system/org.nixos.podman-machine 2>/dev/null || true
      '';
    };
}
