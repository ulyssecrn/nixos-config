{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../home/profiles/base.nix
    ../../../home/modules/stylix.nix
    ../../../home/modules/skills/playwright.nix
    ../../../home/modules/herdr.nix
  ];
}
