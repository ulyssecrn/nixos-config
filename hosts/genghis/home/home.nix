{ config, pkgs, ... }:

{
  imports = [
    ../../../home/profiles/base.nix
    ../../../home/modules/stylix.nix
    ../../../home/modules/herdr.nix
    ../../../home/modules/claude-code-playwright.nix
  ];

  # genghis is the box we attach to from the phone, and the server side owns the
  # layout decision, so the phone-layout threshold belongs here rather than in
  # the shared module. An iPhone in landscape reports more than the 64-column
  # default and would otherwise get the desktop sidebar at an unusable width.
  programs.herdr.settings.ui.mobile_width_threshold = 80;
}
