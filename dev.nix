{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    uv
    direnv
  ];

  environment.sessionVariables = {
    UV_PYTHON_DOWNLOADS = "automatic";
  };
}