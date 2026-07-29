{ config, pkgs, ... }:

{
  # ── Shell ────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    shellAliases = {
      # NixOS — rebuild
      nrs = "sudo nixos-rebuild switch --flake /home/ucorne/.nixos#$(hostname)";
      nrt = "sudo nixos-rebuild test   --flake /home/ucorne/.nixos#$(hostname)";
      nrb = "sudo nixos-rebuild boot   --flake /home/ucorne/.nixos#$(hostname)";
      # NixOS — flake / repo housekeeping
      nfu = "nix flake update --flake /home/ucorne/.nixos";
      nfp = "git -C /home/ucorne/.nixos pull";
      # NixOS — generation maintenance
      ngc = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +2 && sudo nix-collect-garbage";
      nls = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";

      clf = "clear";
      ls = "eza --group-directories-first --icons --git";
      ll = "eza -l --group-directories-first --icons --git";
      la = "eza -la --group-directories-first --icons --git";
      open = "xdg-open";
      ff = "fastfetch";
      cl = "claude";
      oc = "opencode";
      va = "source .venv/bin/activate";
      ssh = "kitten ssh";
      atilla-initrd = "command ssh atilla-initrd";
      genghis-initrd = "command ssh genghis-initrd";
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
