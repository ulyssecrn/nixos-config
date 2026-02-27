{ config, pkgs, ... }:

{
  # ── Shell ────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    shellAliases = {
      upgrade = "sudo nixos-rebuild switch";
      update = "cd /home/ucorne/.nixos && nix flake update";
      clf = "clear";
      ls = "eza --group-directories-first --icons --git";
      ll = "eza -l --group-directories-first --icons --git";
      la = "eza -la --group-directories-first --icons --git";
      open = "xdg-open";
      ff = "fastfetch";
      cl = "function _cl() { clang -std=c2x -Wall -lm -o \"\${1%.c}\" \"\$1\"; }; _cl";
      va = "source .venv/bin/activate";
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "marlonrichert/zsh-autocomplete"; }
        { name = "chisui/zsh-nix-shell"; }
        { name = "ptavares/zsh-direnv"; }
      ];
    };
    initContent = ''
    eval "$(uv generate-shell-completion zsh)"
    export PATH="/home/ucorne/.local/bin:$PATH"
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };
}