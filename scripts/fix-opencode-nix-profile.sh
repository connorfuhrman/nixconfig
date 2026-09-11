#!/usr/bin/env bash
# Restore opencode-nix after nono auto-added read:["~/"] (breaks sandbox init).
set -euo pipefail
PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nono/profiles/opencode-nix.json"
DRAFT="${XDG_CONFIG_HOME:-$HOME/.config}/nono/profile-drafts/opencode-nix.json"
mkdir -p "$(dirname "$PROFILE")" "$(dirname "$DRAFT")"
cat > "$DRAFT" <<'JSON'
{
  "extends": ["nolabs-ai/opencode"],
  "meta": {
    "name": "opencode-nix",
    "version": "1.3.1",
    "description": "opencode + CWD r/w + nix user-state; no full-home grant"
  },
  "workdir": { "access": "readwrite" },
  "filesystem": {
    "allow": ["~/.local/share/nix"],
    "read": ["/nix/store"],
    "read_file": ["~/.gitconfig", "~/.config/git/config"]
  }
}
JSON
cp "$DRAFT" "$PROFILE"
echo "Restored $PROFILE from draft (no full-home grant)."
echo "Run: opencode"
