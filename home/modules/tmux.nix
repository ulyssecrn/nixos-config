# home/modules/tmux.nix
{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 100000;
    terminal = "tmux-256color";
    keyMode = "vi";
  };
}
