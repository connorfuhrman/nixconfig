set -euo pipefail
export PATH="@scriptPath@:$PATH"

primaryUser="@primaryUser@"
home="/Users/$primaryUser"
machine=podman-machine-default
podman="@podman@"
sudo="/usr/bin/sudo"
getconf="/usr/bin/getconf"

# sudo(8) drops the login-session TMPDIR; podman then reports
# /tmp/podman/... while the real socket lives under /var/folders/.../T/.
userTmpDir="$("$sudo" -u "$primaryUser" "$getconf" DARWIN_USER_TEMP_DIR)"

as_user() {
  "$sudo" -u "$primaryUser" env HOME="$home" TMPDIR="$userTmpDir" PATH="@scriptPath@:$PATH" "$@"
}

podman_as_user() {
  as_user "$podman" "$@"
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

desiredMemory="@desiredMemoryMiB@"
currentMemory="$(podman_as_user machine inspect "$machine" --format '{{.Resources.Memory}}' 2>/dev/null || echo 0)"
state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
if [ "$currentMemory" != "$desiredMemory" ]; then
  echo "Podman machine memory $currentMemory MiB -> $desiredMemory MiB"
  # applehv applies --memory only when the VM is stopped.
  if [ "$state" = "running" ]; then
    podman_as_user machine stop "$machine"
    state=stopped
  fi
  podman_as_user machine set --memory "$desiredMemory" "$machine"
fi

# Checkout is on the default /Users share. Prune leftover nested
# virtiofs of the checkout or the agent home (/var/lib or /private/var).
checkoutRoot="@agentCheckoutRoot@"
oldCheckoutRoot="@oldCheckoutRoot@"
agentHome="@agentHome@"
mkdir -p "$checkoutRoot"
jsonPath="$(podman_as_user machine inspect "$machine" --format '{{.ConfigDir.Path}}')/$machine.json"
volumePy="@volumeEnsurePy@"
python="@python3@"
vol_status="$(as_user "$python" "$volumePy" --status "$jsonPath" "$checkoutRoot" "$oldCheckoutRoot" "$agentHome")"
if [ "$vol_status" = "needed" ]; then
  echo "Podman machine virtiofs: dropping nested checkout shares (covered by /Users)"
  if [ "$state" = "running" ]; then
    podman_as_user machine stop "$machine"
    state=stopped
  fi
  as_user "$python" "$volumePy" --prune "$jsonPath" "$checkoutRoot" "$oldCheckoutRoot" "$agentHome"
fi

if [ "$state" = "starting" ]; then
  echo "Podman machine already starting; waiting"
elif [ "$state" != "running" ]; then
  podman_as_user machine start "$machine" || true
fi
for _ in $(seq 1 60); do
  state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
  if [ "$state" = "running" ]; then
    break
  fi
  sleep 1
done

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

# Never umount or SSH-stat guest checkout paths. umount of a symlink
# onto /private virtiofs hangs the share; [ -d ] follows it and hangs.
echo "podman $machine running (rootful, @desiredMemoryMiB@ MiB, checkout $checkoutRoot on /Users virtiofs); proxy $listen -> $sock"
