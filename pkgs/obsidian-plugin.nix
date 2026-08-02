# Generic Obsidian community plugin from a GitHub tag tarball.
# callPackage with: { name, owner, repo, rev, hash, id }
{
  stdenvNoCC,
  fetchurl,
  name,
  owner,
  repo,
  rev,
  hash,
  id,
}:
stdenvNoCC.mkDerivation {
  pname = "obsidian-plugin-${id}";
  version = rev;
  src = fetchurl {
    url = "https://github.com/${owner}/${repo}/archive/refs/tags/${rev}.tar.gz";
    inherit hash;
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/obsidian/plugins/${id}
    # GitHub archive root is repo-rev/
    shopt -s dotglob nullglob
    for f in main.js manifest.json styles.css; do
      if [ -f "$f" ]; then cp "$f" $out/share/obsidian/plugins/${id}/; fi
    done
    # some archives nest one directory
    if [ ! -f $out/share/obsidian/plugins/${id}/manifest.json ]; then
      d="$(find . -maxdepth 2 -name manifest.json | head -n1)"
      test -n "$d"
      cp "$(dirname "$d")/main.js" $out/share/obsidian/plugins/${id}/ 2>/dev/null || true
      cp "$(dirname "$d")/manifest.json" $out/share/obsidian/plugins/${id}/
      cp "$(dirname "$d")/styles.css" $out/share/obsidian/plugins/${id}/ 2>/dev/null || true
    fi
    test -f $out/share/obsidian/plugins/${id}/manifest.json
    runHook postInstall
  '';
  meta = {
    description = "Obsidian plugin ${id} (immutable)";
    homepage = "https://github.com/${owner}/${repo}";
  };
}
