# pi-goal: autonomous single-objective /goal completion for the pi coding
# agent (@narumitw/pi-goal). Published from the narumiruna/pi-extensions
# monorepo; peer deps (@earendil-works/pi-* and typebox, range `*`) are
# provided by pi's bundled runtime.
{
  callPackage,
  lib,
  writeText,
}:
let
  # pi-goal imports stripTerminalSequences from @earendil-works/pi-tui,
  # an export that only exists in pi-tui >= 0.84 — nixpkgs' pi-coding-agent
  # 0.80.10 lacks it, so goal_complete crashes in the TUI after delivering
  # the result. Redirect that import to this polyfill (same contract as
  # upstream 0.84: string in, ANSI/OSC-stripped string out; the callers
  # spread the result, which works for strings).
  tuiPolyfill = writeText "pi-tui-strip-polyfill.js" ''
    // Polyfill for @earendil-works/pi-tui < 0.84 (nixpkgs pi 0.80.10).
    export function stripTerminalSequences(value) {
      if (typeof value !== "string") return value;
      return value.replace(
        /\x1B(?:\][^\x07\x1B]*(?:\x07|\x1B\\)|\[[0-?]*[ -/]*[@-~]|[@-Z\\-_])/g,
        "",
      );
    }
  '';
in
callPackage ./pi-package.nix {
  pname = "pi-goal";
  npmName = "@narumitw/pi-goal";
  version = "0.54.4";
  hash = "sha256-s/qHmedg12sm+YBJ3g7DKLnaLDVb5Ra0hOp7CJLDihc=";
  # Runtime deps pinned to upstream's package-lock.json (0.54.4) — same
  # tree as pi-plan-mode.
  deps = [
    {
      name = "@narumitw/pi-tui-kit";
      version = "0.59.0";
      hash = "sha256-NKgaW5StT7YhxMSSObxexuoBSdLkALMnpoZ/dbe2cDU=";
    }
    {
      name = "grok-mermaid";
      version = "0.2.3";
      hash = "sha256-QdAgY/UyYf6GmsttoLAYONbs4JXXOnBjZFzgRC8NjIg=";
    }
    {
      name = "highlight.js";
      version = "11.12.0";
      hash = "sha256-rMv6qrdFCIYJtO6ivcoq1i8fHdJzBOD432XP4P4EIUM=";
    }
  ];
  postInstall = ''
    # Redirect the pi-tui import that pi 0.80.10 cannot satisfy (see
    # polyfill above). Only the exact bundled import form is rewritten;
    # other @earendil-works/pi-tui imports are untouched. Covers dist
    # chunks and node_modules copies.
    grep -rl --include='*.js' --include='*.ts' 'stripTerminalSequences' "$pkgOut" \
      | xargs -r sed -i 's|import { stripTerminalSequences } from "@earendil-works/pi-tui"|import { stripTerminalSequences } from "${tuiPolyfill}"|'
  '';
  description = "Autonomous /goal completion for the pi coding agent";
  homepage = "https://github.com/narumiruna/pi-extensions";
  license = lib.licenses.mit;
}
