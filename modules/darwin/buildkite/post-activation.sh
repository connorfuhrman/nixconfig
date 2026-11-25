agent_home=@agentHome@
checkout=@agentCheckout@
mkdir -p "$agent_home/.ssh"
if [ ! -f "$agent_home/.gitconfig" ]; then
  : > "$agent_home/.gitconfig"
  chown @agentUser@:@agentUser@ "$agent_home/.gitconfig"
  chmod 644 "$agent_home/.gitconfig"
fi
install -m 600 -o @agentUser@ -g @agentUser@ @sshConfigSource@ "$agent_home/.ssh/config"
install -m 644 -o @agentUser@ -g @agentUser@ @knownHostsSource@ "$agent_home/.ssh/known_hosts"
if [ -f @originSshKey@ ]; then
  chown @agentUser@:@agentUser@ @originSshKey@
  chmod 600 @originSshKey@
fi
if [ -f @originSshKey@.pub ]; then
  chown @agentUser@:@agentUser@ @originSshKey@.pub
  chmod 644 @originSshKey@.pub
fi
mkdir -p "$checkout/builds" "$checkout/plugins"
chown -R @agentUser@:@agentUser@ "$agent_home"
chown -R @agentUser@:docker "$checkout"
chmod 755 "$agent_home"
chmod 755 "$checkout"
chmod 755 "$checkout/builds"
chmod 755 "$checkout/plugins"
chmod 700 "$agent_home/.ssh"

mkdir -p /etc/buildkite-agent
chmod 755 /etc/buildkite-agent
if [ -f /etc/buildkite-agent/cluster.token ]; then
  chown root:@agentUser@ /etc/buildkite-agent/cluster.token
  chmod 640 /etc/buildkite-agent/cluster.token
fi

launchctl kickstart -k system/org.nixos.buildkite-agent-macos 2>/dev/null || true