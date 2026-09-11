{ writeShellScriptBin, jq }:
writeShellScriptBin "cursor-cloud-setup" ''
  export TEMPLATE_JSON=${./cursor-cloud/environment.json}
  export TEMPLATE_SH=${./cursor-cloud/nix-home.sh}
  export JQ=${jq}/bin/jq
  exec ${./cursor-cloud/setup.sh} "$@"
''
