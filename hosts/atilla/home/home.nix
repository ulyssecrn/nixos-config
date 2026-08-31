{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../home/profiles/base.nix
    ../../../home/modules/stylix.nix
    ../../../home/modules/claude-code-playwright.nix
  ];
}
