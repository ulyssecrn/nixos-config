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
      rsync
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
      transfer = ''
        return {
          {
            "coffebar/transfer.nvim",
            lazy = true,
            cmd = {
              "TransferInit",
              "DiffRemote",
              "TransferUpload",
              "TransferDownload",
              "TransferDirDiff",
              "TransferRepeat"
            },
            opts = {},
            keys = {
                { "<leader>td", "<cmd>TransferDownload<cr>", desc = "Download from remote" },
                { "<leader>tf", "<cmd>DiffRemote<cr>", desc = "Diff with remote" },
                { "<leader>ti", "<cmd>TransferInit<cr>", desc = "Init Deployment config" },
                { "<leader>tr", "<cmd>TransferRepeat<cr>", desc = "Repeat transfer" },
                { "<leader>tu", "<cmd>TransferUpload<cr>", desc = "Upload to remote" },
            },
          },
          {
            "folke/which-key.nvim",
            opts = {
              spec = {
                { "<leader>t", group = "transfer", icon = "" },
              },
            },
          },
        }
      '';
    };
  };
}
