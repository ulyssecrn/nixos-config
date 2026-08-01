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
      he = "hermes";
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

    # Stable SSH agent socket, for herdr (and tmux).
    #
    # sshd mints a fresh forwarded-agent socket per login and deletes it when
    # that login ends. The herdr *server* is long-lived and outlives the login
    # that started it, so it keeps handing every new pane the SSH_AUTH_SOCK it
    # inherited on day one — long since deleted. Hence `ssh genghis && git push`
    # works while `ssh genghis && herdr && git push` cannot reach any agent.
    #
    _agent_sock="$HOME/.ssh/agent.sock"
    if [ -n "$SSH_CONNECTION" ] && [ -S "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$_agent_sock" ]; then
      ln -sfn "$SSH_AUTH_SOCK" "$_agent_sock"
    fi
    [ -S "$_agent_sock" ] && export SSH_AUTH_SOCK="$_agent_sock"
    unset _agent_sock
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
