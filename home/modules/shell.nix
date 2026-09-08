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

    # `kitten ssh` ships terminfo + shell-integration to the remote over
    # kitty-private DCS escape sequences on the tty. herdr (like tmux) sits
    # between kitty and the shell and swallows those sequences, so the kitten's
    # bootstrap blocks forever on connect. Only alias ssh to it in a bare kitty
    # window (TERM=xterm-kitty); inside herdr/tmux TERM is xterm-256color and we
    # fall back to real ssh. KITTY_PID/KITTY_WINDOW_ID leak through herdr, so
    # they can't be used to detect a bare window — TERM and HERDR_ENV can.
    if [[ $TERM == xterm-kitty && -z $HERDR_ENV && -z $TMUX ]]; then
      alias ssh='kitten ssh'
    fi

    # sshd deletes its forwarded socket when the login ends, but the herdr
    # server outlives that login and keeps handing panes the dead path. Point
    # them at a stable link instead; ~/.ssh/rc (home/modules/herdr.nix) keeps it
    # current. -S follows the link, so a stale one leaves us on sshd's own.
    _agent_sock="$HOME/.ssh/agent.sock"
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
