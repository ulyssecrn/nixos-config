{ config, pkgs, lazyvim, ... }:

{
  imports = [ lazyvim.homeManagerModules.default ];
  programs.lazyvim = {
    enable = true;

    extras = {
        lang.nix = {
          enable = true;
          installDependencies = true;
        };
        lang.python.enable = true;
    };

    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
      nix
      python
    ];

    extraPackages = with pkgs; [
      # LSP servers
      nixd
      pyright

      # Linters
      statix
    ];
  };
}
