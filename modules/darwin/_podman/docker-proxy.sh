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
exec @socat@ \
  UNIX-LISTEN:"$listen",fork,reuseaddr,unlink-early,mode=0660,user=root,group=@dockerGid@ \
  UNIX-CONNECT:"$target"
