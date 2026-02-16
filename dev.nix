{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    uv
    direnv
    claude-code
    unityhub
    android-tools
  ];

  environment.sessionVariables = {
    UV_PYTHON_DOWNLOADS = "automatic";
  };
}