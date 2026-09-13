{ ... }: {
  # Podman on macOS for Linux containers (Buildkite docker plugin on mac-mini-macos).
  #
  # The machine API socket lives under the primary user's 700 TMPDIR, which
  # buildkite-agent-macos cannot traverse. Rootful mode plus a root socat proxy
  # on /var/run/docker.sock (660, group docker) is the agent-visible path.
  flake.modules.darwin.podman = { config, lib, pkgs, ... }:
    let
      primaryUser = config.system.primaryUser;
      agentUser = "buildkite-agent-macos";
      podman = pkgs.podman;
      dockerGid = toString config.users.groups.docker.gid;
      scriptPath = lib.makeBinPath [
        podman
        pkgs.coreutils
        pkgs.gnugrep
      ];

      dockerWrapper = pkgs.writeShellScript "docker-via-podman" ''
        export DOCKER_HOST="''${DOCKER_HOST:-unix:///var/run/docker.sock}"
        export CONTAINER_HOST="''${CONTAINER_HOST:-unix:///var/run/docker.sock}"
        exec ${podman}/bin/podman "$@"
      '';

      dockerCompat = pkgs.runCommand "${podman.pname}-docker-compat-${podman.version}"
        {
          nativeBuildInputs = [ pkgs.installShellFiles ];
          outputs = [ "out" "man" ];
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
        '';

      podmanMachineEnsure = pkgs.writeShellScript "podman-machine-ensure" ''
        set -euo pipefail
        export PATH="${scriptPath}:$PATH"

        primaryUser="${primaryUser}"
        home="/Users/${primaryUser}"
        machine=podman-machine-default
        podman="${podman}/bin/podman"
        sudo="/usr/bin/sudo"
        getconf="/usr/bin/getconf"

        # sudo(8) drops the login-session TMPDIR; podman then reports
        # /tmp/podman/... while the real socket lives under /var/folders/.../T/.
        userTmpDir="$("$sudo" -u "$primaryUser" "$getconf" DARWIN_USER_TEMP_DIR)"

        podman_as_user() {
          "$sudo" -u "$primaryUser" env HOME="$home" TMPDIR="$userTmpDir" PATH="${scriptPath}:$PATH" "$podman" "$@"
        }

        if ! podman_as_user machine inspect "$machine" >/dev/null 2>&1; then
          echo "ERROR: podman machine '$machine' missing — run once as $primaryUser:" >&2
          echo "  podman machine init --rootful $machine" >&2
          exit 1
        fi

        rootful="$(podman_as_user machine inspect "$machine" --format '{{.Rootful}}' 2>/dev/null || echo false)"
        if [ "$rootful" != "true" ]; then
          state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo unknown)"
          if [ "$state" = "running" ]; then
            echo "ERROR: $machine is rootless (Rootful=false). Stop it, then run once as $primaryUser:" >&2
            echo "  podman machine stop $machine && podman machine set --rootful $machine" >&2
            exit 1
          fi
          echo "Converting $machine to rootful mode..."
          podman_as_user machine set --rootful "$machine"
        fi

        state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
        if [ "$state" != "running" ]; then
          podman_as_user machine start "$machine"
        fi

        resolve_sock() {
          local candidate=""

          candidate="$(podman_as_user machine inspect "$machine" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)"
          if [ -n "$candidate" ] && [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          candidate="$userTmpDir/podman/$machine-api.sock"
          if [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          candidate="$(find "$userTmpDir" /var/folders "$home/.local/share/containers/podman/machine" \
            -name "$machine-api.sock" -type s 2>/dev/null | head -n1 || true)"
          if [ -n "$candidate" ] && [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          return 1
        }

        sock=""
        for _ in $(seq 1 30); do
          sock="$(resolve_sock || true)"
          if [ -n "$sock" ]; then
            break
          fi
          sleep 1
        done

        if [ -z "$sock" ] || [ ! -S "$sock" ]; then
          echo "ERROR: Podman API socket not found (ConnectionInfo, TMPDIR, or find)" >&2
          exit 1
        fi

        mkdir -p /var/run
        target_file=/var/run/podman-api.target
        prev_file=/var/run/podman-api.target.prev
        listen=/var/run/docker.sock
        printf '%s\n' "$sock" > "$target_file"
        chgrp docker "$sock" 2>/dev/null || true
        chmod 660 "$sock" 2>/dev/null || true

        # Never leave a symlink into the 700 TMPDIR as the agent-visible path.
        # Root socat can open that sock; uid 536 cannot traverse the parents.
        need_proxy_restart=0
        if [ -L "$listen" ] || [ ! -S "$listen" ]; then
          need_proxy_restart=1
        fi
        prev=""
        if [ -f "$prev_file" ]; then
          prev="$(tr -d '\n' < "$prev_file")"
        fi
        if [ "$prev" != "$sock" ]; then
          need_proxy_restart=1
        fi

        if [ "$need_proxy_restart" = 1 ]; then
          if [ -L "$listen" ]; then
            rm -f "$listen"
          fi
          /bin/launchctl kickstart -k system/org.nixos.podman-docker-proxy 2>/dev/null || true
          printf '%s\n' "$sock" > "$prev_file"
        fi

        for _ in $(seq 1 10); do
          if [ -S "$listen" ] && [ ! -L "$listen" ]; then
            chgrp docker "$listen"
            chmod 660 "$listen"
            break
          fi
          sleep 1
        done

        echo "podman $machine running (rootful); proxy $listen -> $sock"
      '';

      podmanDockerProxy = pkgs.writeShellScript "podman-docker-proxy" ''
        set -euo pipefail
        target_file=/var/run/podman-api.target
        listen=/var/run/docker.sock
        target=""

        for _ in $(seq 1 60); do
          if [ -f "$target_file" ]; then
            target="$(tr -d '\n' < "$target_file")"
            if [ -n "$target" ] && [ -S "$target" ]; then
              break
            fi
          fi
          sleep 1
        done

        if [ -z "$target" ] || [ ! -S "$target" ]; then
          echo "ERROR: podman API target not ready ($target_file)" >&2
          exit 1
        fi

        # Drop Docker Desktop / stale symlink so we bind a real listen sock.
        rm -f "$listen"

        echo "proxy $listen -> $target"
        exec ${pkgs.socat}/bin/socat \
          UNIX-LISTEN:"$listen",fork,reuseaddr,unlink-early,mode=0660,user=root,group=${dockerGid} \
          UNIX-CONNECT:"$target"
      '';
    in
    {
      environment.systemPackages = [
        podman
        dockerCompat
      ];

      # nix-darwin's buildkite module sets launchd PATH from runtimePackages
      # only — not /run/current-system/sw/bin. The docker plugin execs `docker`.
      services.buildkite-agents.macos.runtimePackages = [ dockerCompat ];

      users.knownGroups = lib.mkAfter [ "docker" ];
      users.groups.docker = {
        gid = lib.mkDefault 537;
        members = [ primaryUser agentUser ];
      };

      # Root launchd: machine is owned by primaryUser; the proxy listen sock is
      # root:docker so the agent never opens the 700 TMPDIR path.
      launchd.daemons.podman-machine = {
        path = with pkgs; [ podman coreutils gnugrep ];
        script = "${podmanMachineEnsure}";
        serviceConfig = {
          RunAtLoad = true;
          StartInterval = 300;
          KeepAlive = {
            SuccessfulExit = false;
          };
          StandardOutPath = "/var/log/podman-machine.log";
          StandardErrorPath = "/var/log/podman-machine.log";
        };
      };

      launchd.daemons.podman-docker-proxy = {
        path = with pkgs; [ coreutils socat ];
        script = "${podmanDockerProxy}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
          };
          StandardOutPath = "/var/log/podman-docker-proxy.log";
          StandardErrorPath = "/var/log/podman-docker-proxy.log";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        launchctl kickstart -k system/org.nixos.podman-machine 2>/dev/null || true
        launchctl kickstart -k system/org.nixos.podman-docker-proxy 2>/dev/null || true
      '';
    };
}
