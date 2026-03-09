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

      ai = {
        sidekick.enable = true;       # side ai window
        copilot.enable = true;        # inline completions
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

      # Formatters
      black
      alejandra   # nix

      # Tools
      ripgrep
    ];

    config = {
      options = ''
        vim.g.autoformat = false
        vim.api.nvim_create_autocmd("User", {
          pattern = "VeryLazy",
          callback = function()
            vim.cmd("silent! Copilot disable")
          end,
        })
      '';
    };

    plugins = {
      uv = ''
        return {
          {
            "benomahony/uv.nvim",
            ft = "python",
            opts = {
              keymaps = {
                prefix = "<leader>v",
              },
              picker_integration = true,
            },
          },
          {
            "folke/which-key.nvim",
            opts = {
              spec = {
                { "<leader>v", group = "uv", icon = { icon = "", color = "purple" } },
              },
            },
          },
        }
      '';
    };
  };
}
