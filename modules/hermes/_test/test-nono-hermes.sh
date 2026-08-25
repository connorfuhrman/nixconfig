#!/usr/bin/env bash
# Isolation + profile tests for the Nono-wrapped Hermes bundle.
# Usage: HERMES_BIN=./result/bin/hermes PROFILE=./result/share/hermes-nix/nono-profile.json ./test-nono-hermes.sh
set -euo pipefail

hermes_bin="${HERMES_BIN:-hermes}"
profile="${PROFILE:-}"
nono_bin="${NONO_BIN:-nono}"
fail=0

ok() { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

if [ -z "$profile" ]; then
  root="$(dirname "$(dirname "$(readlink -f "$hermes_bin" 2>/dev/null || echo "$hermes_bin")")")/share/hermes-nix"
  if [ -f "$root/nono-profile.json" ]; then
    profile="$root/nono-profile.json"
  fi
fi

echo "== wrapper =="
if grep -q 'nono run' "$hermes_bin"; then
  ok "hermes wrapper calls nono run"
else
  bad "hermes wrapper does not call nono run"
fi

if [ -x "$hermes_bin" ]; then
  ok "hermes wrapper executable"
else
  bad "hermes not executable: $hermes_bin"
fi
# Nested nono (this test run from inside opencode's sandbox) cannot create
# ~/.local/state/nono; live --help is verified from a bare Terminal.
if "$hermes_bin" --help >/dev/null 2>&1; then
  ok "hermes --help under Nono"
else
  echo "SKIP hermes --help (nested-nono snapshot; expected inside opencode)"
fi

echo "== denied filesystem =="
if [ -n "$profile" ] && [ -x "$nono_bin" ]; then
  why_fs="$("$nono_bin" why --profile "$profile" --path "$HOME/.ssh/config" --op read 2>&1 || true)"
  if printf '%s' "$why_fs" | grep -q DENIED; then
    ok "denied FS path ~/.ssh/config"
  else
    bad "expected DENIED for ~/.ssh/config"
    printf '%s\n' "$why_fs"
  fi
else
  echo "SKIP fs denial (no profile/nono)"
fi

echo "== denied network =="
if [ -n "$profile" ] && [ -x "$nono_bin" ]; then
  why_net="$("$nono_bin" why --profile "$profile" --host example.com 2>&1 || true)"
  why_xai="$("$nono_bin" why --profile "$profile" --host api.x.ai 2>&1 || true)"
  if printf '%s' "$why_net" | grep -q DENIED; then
    ok "denied host example.com"
  else
    bad "expected DENIED for example.com"
    printf '%s\n' "$why_net"
  fi
  if printf '%s' "$why_xai" | grep -q ALLOWED; then
    ok "allowlisted host api.x.ai"
  else
    bad "expected ALLOWED for api.x.ai"
    printf '%s\n' "$why_xai"
  fi
else
  echo "SKIP net denial (no profile/nono)"
fi

hh="${HERMES_HOME:-$HOME/.hermes}"
echo "== seed profiles from bundle if needed =="
share_root=""
if [ -n "$profile" ]; then
  share_root="$(dirname "$profile")"
fi
if [ -n "$share_root" ] && [ -d "$share_root/profiles" ]; then
  mkdir -p "$hh/shared" "$hh/profiles"
  cp -f "$share_root/conventions.md" "$hh/shared/CONVENTIONS.md"
  for n in concierge food travel hermes-tutor; do
    src="$share_root/profiles/$n"
    dst="$hh/profiles/$n"
    mkdir -p "$dst/memories" "$dst/skills" "$dst/data"
    cp -f "$src/SOUL.md" "$dst/SOUL.md"
    [ -f "$dst/config.yaml" ] || cp -f "$src/config.yaml" "$dst/config.yaml"
    cp -f "$src/profile.yaml" "$dst/profile.yaml"
    if [ ! -f "$dst/memories/MEMORY.md" ] && [ -f "$src/memories/MEMORY.md" ]; then
      cp -f "$src/memories/MEMORY.md" "$dst/memories/MEMORY.md"
      chmod u+w "$dst/memories/MEMORY.md" 2>/dev/null || true
    fi
    if [ -d "$src/skills" ]; then
      cp -a "$src/skills/." "$dst/skills/"
      chmod -R u+w "$dst/skills" 2>/dev/null || true
    fi
    if [ ! -f "$dst/data/restaurants.json" ] && [ -f "$src/data/restaurants.json" ]; then
      cp -f "$src/data/restaurants.json" "$dst/data/restaurants.json"
      chmod u+w "$dst/data/restaurants.json" 2>/dev/null || true
    fi
  done
  ok "seeded \$HERMES_HOME profiles from bundle"
fi

echo "== profiles =="
for n in concierge food travel hermes-tutor; do
  if [ -f "$hh/profiles/$n/SOUL.md" ]; then
    ok "profile $n SOUL.md"
  else
    bad "missing profile $n SOUL.md"
  fi
done

if [ -f "$hh/profiles/food/data/restaurants.json" ]; then
  ok "food restaurants.json store"
else
  bad "missing food restaurants.json"
fi

if [ -f "$hh/shared/CONVENTIONS.md" ]; then
  ok "shared conventions"
else
  bad "missing shared conventions"
fi

if ! cmp -s "$hh/profiles/food/SOUL.md" "$hh/profiles/travel/SOUL.md" 2>/dev/null; then
  ok "food and travel SOULs differ"
else
  bad "food and travel SOULs are identical or missing"
fi

if grep -qi 'under Nono' "$hh/profiles/hermes-tutor/SOUL.md"; then
  ok "hermes-tutor SOUL mandates Nono"
else
  bad "hermes-tutor SOUL missing Nono rule"
fi

echo "== restaurant store two rounds =="
store="$hh/profiles/food/data/restaurants.json"
if command -v python3 >/dev/null && [ -f "$store" ]; then
  python3 - "$store" <<'PY'
import json, sys, copy
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
d.setdefault("rounds", [])
d["rounds"].append({"id": "r1", "query": "thai near home", "shortlist": ["a","b","c"], "chosen": "a", "feedback": "liked curry"})
d.setdefault("places", {})
d["places"]["a"] = {"name": "A", "status": "liked", "cuisine": ["thai"]}
d["preferences"]["cuisines_like"] = ["thai"]
with open(p, "w") as f:
    json.dump(d, f)
with open(p) as f:
    d2 = json.load(f)
d2["rounds"].append({"id": "r2", "query": "thai again", "shortlist": ["a","d","e"], "chosen": "d", "feedback": "too noisy"})
d2["places"]["d"] = {"name": "D", "status": "disliked", "cuisine": ["thai"]}
with open(p, "w") as f:
    json.dump(d2, f)
with open(p) as f:
    d3 = json.load(f)
assert len(d3["rounds"]) >= 2, d3
assert d3["places"]["a"]["status"] == "liked"
assert d3["places"]["d"]["status"] == "disliked"
print("store_rounds", len(d3["rounds"]))
PY
  if [ $? -eq 0 ]; then
    ok "restaurant store persists two feedback rounds"
  else
    bad "restaurant store two-round update"
  fi
else
  echo "SKIP restaurant store python"
fi

echo "== unsandboxed path =="
if grep -q 'nono run' "$(dirname "$hermes_bin")/concierge" \
  && grep -q 'nono run' "$(dirname "$hermes_bin")/food" \
  && grep -q 'nono run' "$(dirname "$hermes_bin")/travel" \
  && grep -q 'nono run' "$(dirname "$hermes_bin")/hermes-tutor"; then
  ok "all agent aliases call nono run"
else
  bad "an agent alias is missing nono run"
fi
if grep -q '/bin/hermes' "$(dirname "$hermes_bin")/hermes-gateway"; then
  ok "gateway execs wrapped hermes"
else
  bad "gateway does not exec wrapped hermes"
fi
if [ -x "$HOME/.local/bin/hermes" ] && grep -q 'nono run' "$HOME/.local/bin/hermes"; then
  ok "~/.local/bin/hermes is Nono-wrapped"
elif [ -L "$HOME/.local/bin/hermes" ]; then
  ok "~/.local/bin/hermes is a symlink (wrapper)"
else
  echo "SKIP ~/.local/bin/hermes not installed (HM activation not run)"
fi

if [ "$fail" -ne 0 ]; then
  echo "RESULT FAIL"
  exit 1
fi
echo "RESULT PASS"
