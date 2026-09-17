{
  lib,
  symlinkJoin,
  writeText,
  callPackage,
}:
let
  pluginSpecs = {
    document-comments = {
      owner = "kylemcd";
      repo = "obsidian-document-comments";
      rev = "0.1.12";
      hash = "sha256-Gmh/L2T+ZxPR5+YbqY1J7gez5+sIJwnp5FNO4IainDU=";
      id = "document-comments";
    };
    track-changes = {
      owner = "philphilphil";
      repo = "obsidian-track-changes";
      rev = "1.9.0";
      hash = "sha256-WvXfrhamMmwuy3h3uQf12FTm96ZJJhGJZWQ8RCEXBBI=";
      id = "track-changes";
    };
    remote-ssh = {
      owner = "sotashimozono";
      repo = "obsidian-remote-ssh";
      rev = "1.1.7";
      hash = "sha256-Abvi1h4jq0SmHdFBXPL9qwph//nQl+SPqWrCEP/1U0k=";
      id = "remote-ssh";
    };
    ghostty-terminal = {
      owner = "lavs9";
      repo = "obsidian-ghostty-terminal";
      rev = "0.2.1";
      hash = "sha256-0gRgKI1eDtrQZ/LMbnBNgz2oN8ORp6p9DgFO/N43I+s=";
      id = "ghostty-terminal";
    };
  };

  communityPluginsJson = builtins.toJSON [
    "document-comments"
    "track-changes"
    "remote-ssh"
    "ghostty-terminal"
  ];

  plugins = lib.mapAttrs (
    name: spec:
    callPackage ./obsidian-plugin.nix (
      spec
      // {
        inherit name;
      }
    )
  ) pluginSpecs;
in
symlinkJoin {
  name = "obsidian-plugins-nix";
  paths = builtins.attrValues plugins;
  postBuild = ''
    mkdir -p $out/share/obsidian
    cp ${writeText "community-plugins.json" communityPluginsJson} \
      $out/share/obsidian/community-plugins.json
  '';
  passthru = {
    inherit plugins pluginSpecs;
  };
}
