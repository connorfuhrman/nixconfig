{ ... }: {
  # 1Password app + CLI on macOS via Homebrew (requires Homebrew installed —
  # see modules/darwin/roon-server.nix for the install command).
  flake.modules.darwin.onepassword = { ... }: {
    homebrew.casks = [ "1password" "1password-cli" ];
  };
}