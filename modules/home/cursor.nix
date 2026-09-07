# Home-manager: Cursor IDE (pkgs.code-cursor from nixpkgs).
# Settings/extensions stay in Cursor's UI — not programs.vscode.
{ ... }: {
  flake.modules.homeManager.cursor = { pkgs, lib, ... }: {
    nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "cursor";

    home.packages = [ pkgs.code-cursor ];
  };
}
