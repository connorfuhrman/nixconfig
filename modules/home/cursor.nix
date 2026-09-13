# Home-manager: Cursor IDE (pkgs.code-cursor from nixpkgs).
# Settings/extensions stay in Cursor's UI — not programs.vscode.
{ ... }: {
  flake.modules.homeManager.cursor = { pkgs, lib, ... }: {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [ "cursor" "origin" ];

    home.packages = [ pkgs.code-cursor ];
  };
}
