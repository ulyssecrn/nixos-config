{ config, lib, pkgs, ... }:

let
  # Wraps the gamescope launch with llama-cpp stop/restart so the GPU's
  # full VRAM is free during play and the model comes back online when
  # Steam exits.
  gameSession = pkgs.writeShellScriptBin "genghis-game-session" ''
    set -e
    sudo systemctl stop llama-cpp.service
    trap 'sudo systemctl start llama-cpp.service' EXIT
    cage -- steam -bigpicture
  '';
in
{
  # ── Audio ──────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # ── Bluetooth (controllers, headphones) ───────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # ── Greetd → gamescope session ────────────────────────────────────
  # Single session; greetd hands control to the wrapper, which
  # orchestrates llama-cpp around gamescope's lifetime.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${gameSession}/bin/genghis-game-session";
        user = "greeter";
      };
    };
  };

  # ── NOPASSWD for llama-cpp toggle ─────────────────────────────────
  # Wrapper runs as ucorne; sudo must not prompt.
  security.sudo.extraRules = [{
    users = [ "ucorne" ];
    commands = [
      { command = "/run/current-system/sw/bin/systemctl start llama-cpp.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl stop llama-cpp.service"; options = [ "NOPASSWD" ]; }
    ];
  }];

  environment.systemPackages = with pkgs; [ vesktop cage ];
}
