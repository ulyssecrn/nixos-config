# home/modules/herdr.nix
#
# herdr — agent-aware terminal multiplexer. Same shape as tmux (server holds the
# PTYs, clients attach/detach), plus a sidebar that tracks each pane's agent
# state (working / blocked / done / idle) so a blocked agent is visible without
# cycling panes.
#
# NOT imported from home/profiles/base.nix: `programs.herdr` landed on
# home-manager master and does not exist on release-25.11, which hannibal is
# pinned to — importing it fleet-wide breaks hannibal's eval. Same constraint as
# stylix.nix. Imported per-host instead: genghis (hosts the agents) and loki
# (thin client + local dev).
{ config, pkgs, ... }:

{
  programs.herdr = {
    enable = true;

    settings = {
      # The binary is an immutable nix-store path, so `herdr update` cannot work
      # and the background polling of herdr.dev only produces an update nag we
      # can't act on. Version bumps ride in with the weekly flake-bot instead.
      update = {
        version_check = false;
        manifest_check = false;
      };

      theme.name = "tokyo-night";

      ui = {
        # Every real session is reached over SSH, so a sound would play on the
        # machine we are *not* sitting at. "terminal" emits the notification
        # escape instead, which travels back down the SSH connection to
        # whichever client is attached (loki's kitty, or the phone).
        sound.enabled = false;
        toast.delivery = "terminal";

        # Order the sidebar by attention needed rather than by workspace — the
        # point of running several agents at once is to see which one is blocked.
        agent_panel_sort = "priority";
      };
    };
  };
}
