{ config, pkgs, lazyvim, ... }:

{
  imports = [ lazyvim.homeManagerModules.default ];
  programs.lazyvim = {
    enable = true;

    extras = {
      lang = {
        nix = {
          enable = true;
          installDependencies = true;
        };

        python = {
          enable = true;
          installDependencies = true;
        };

        clangd = {
          enable = true;
          installDependencies = true;
        };

        tex.enable = true;
      };

      editor = {
        neo_tree.enable = true;
        telescope.enable = true;
      };

      ai = {
        claudecode.enable = true;
        copilot.enable = true;
        copilot_chat.enable = true;
      };
    };

    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
      nix
      python
      c
      cpp
      make
      latex
      bibtex
    ];

    extraPackages = with pkgs; [
      # LSP servers
      nixd
      pyright
      clang-tools
      texlab

      # Linters
      statix
    ];
  };
}
