# Supervised Nono-wrapped concierge gateway (mac-mini). Importing enables it.
{ ... }:
{
  flake.modules.homeManager.nono-hermes-gateway =
    {
      pkgs,
      config,
      ...
    }:
    {
      launchd.agents.hermes-concierge-gateway = {
        enable = true;
        config = {
          Label = "ai.x.hermes.concierge-gateway";
          ProgramArguments = [ "${pkgs.hermes}/bin/hermes-gateway" ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/hermes-concierge-gateway.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/hermes-concierge-gateway.err.log";
          ProcessType = "Background";
        };
      };
    };
}
