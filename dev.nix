{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python310
    python311
    python312
    python313

    uv
  ];

  environment.sessionVariables = {
    UV_PYTHON_DOWNLOADS = "never";
  };
}