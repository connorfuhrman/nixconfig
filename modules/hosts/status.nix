# Host maturity metadata — single source of truth for README / AGENTS tables.
{ ... }: {
  flake.hostStatus = {
    mbp14 = {
      experimental = true;
      note = "Asahi / NixOS on Apple Silicon — not yet validated on hardware";
    };
    nuc = {
      experimental = true;
      note = "Intel NUC plain server — not yet validated on hardware";
    };
    nuc-cluster-head = {
      experimental = true;
      note = "NUC Ray head role — not yet validated on hardware";
    };
    nuc-cluster-worker = {
      experimental = true;
      note = "NUC Ray worker role — not yet validated on hardware";
    };
    rpi-cluster-head = {
      experimental = true;
      note = "Raspberry Pi Ray head prototype — not yet validated on hardware";
    };
    macbook = {
      experimental = false;
      note = "Primary macOS laptop — in daily use";
    };
    mac-mini = {
      experimental = false;
      note = "Always-on builder + Roon — in daily use";
    };
  };
}
