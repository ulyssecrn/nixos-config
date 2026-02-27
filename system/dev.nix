{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    uv
  ];

  environment.sessionVariables = {
    UV_PYTHON_DOWNLOADS = "automatic";
  };
}