# nono-wrap: apply a nono sandbox configuration to an executable.
#
# Produces a wrapper binary that runs the wrapped tool under
# `nono run --profile <store-path>`. The profile is written to the store,
# so the policy is immutable — nono can never rewrite it with overly broad
# grants (it auto-adds read:["~/"] to named home profiles, which breaks
# sandbox init).
#
# Conventions (from the retired opencode-nix bundle):
#   - profile always from the store, never by name
#   - never grant "~/" or "~/.local/state/nono"
#   - --allow-cwd + --suppress-save-prompt "$HOME" to cut interactive noise
#
# callPackage with:
#   name          wrapper binary name (e.g. "pi-nono")
#   package       package providing the wrapped executable
#   executable    bin name inside package (default: package.meta.mainProgram)
#   profile       nono profile: attrset (JSON-encoded) or path/text already
#                 containing valid profile JSON
#   extraArgs     extra `nono run` flags (strings) — e.g. ["--allow" "$HOME/work"]
#   extraPackages extra PATH entries for the wrapped tool (node, jq, …)
#   description / meta passthrough
{
  lib,
  stdenvNoCC,
  writeText,
  runtimeShell,
  nono,
  name,
  package,
  executable ? package.meta.mainProgram or (throw "nono-wrap: no executable; set it explicitly"),
  profile,
  extraArgs ? [ ],
  extraPackages ? [ ],
  description ? "Sandboxed ${executable} (nono)",
}: let
  profileJson =
    if builtins.isAttrs profile
    then writeText "nono-profile.json" (builtins.toJSON profile)
    else if lib.isDerivation profile || lib.isStorePath profile
    then profile
    else writeText "nono-profile.json" profile;

  binPath = "${package}/bin/${executable}";
  pathPrefix = lib.makeBinPath extraPackages;
in
stdenvNoCC.mkDerivation {
  inherit name;

  passthru = {
    inherit profileJson package;
    # The wrapped (unsandboxed) binary, for direct access if ever needed.
    wrappedExecutable = binPath;
  };

  buildCommand = ''
    mkdir -p $out/bin

    cat > $out/bin/${name} <<EOF
    #!${runtimeShell}
    set -euo pipefail
    ${lib.optionalString (extraPackages != []) ''export PATH="${pathPrefix}''${PATH:+':$PATH'}"''}
    exec ${nono}/bin/nono run \
      --profile ${profileJson} \
      --allow-cwd \
      --suppress-save-prompt "\$HOME" \
      ${lib.concatStringsSep " \\\n      " extraArgs} \
      -- ${binPath} "\$@"
    EOF
    chmod +x $out/bin/${name}
  '';

  meta = {
    inherit description;
    mainProgram = name;
  };
}
