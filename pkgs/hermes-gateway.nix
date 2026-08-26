{
  writeShellApplication,
  hermes,
}:
writeShellApplication {
  name = "hermes-gateway";
  runtimeInputs = [ hermes ];
  text = ''
    if ! command -v op >/dev/null 2>&1; then
      echo "hermes-gateway: 1Password CLI (op) not on PATH" >&2
      exit 1
    fi
    vault="''${HERMES_OP_VAULT:-op://Private/hermes}"
    has_token=0
    load_op() {
      local field="$1" val
      if val="$(op read "$vault/$field" 2>/dev/null)" && [ -n "$val" ]; then
        export "$field=$val"
        has_token=1
      fi
    }
    load_tokens() {
      has_token=0
      load_op TELEGRAM_BOT_TOKEN
      load_op DISCORD_BOT_TOKEN
      load_op DISCORD_TOKEN
    }
    load_tokens
    if [ "$has_token" -ne 1 ]; then
      echo "hermes-gateway: no bot token at $vault; waiting on op" >&2
      while true; do
        load_tokens
        if [ "$has_token" -eq 1 ]; then
          break
        fi
        sleep 60
      done
    fi
    exec hermes concierge gateway start "$@"
  '';
}
