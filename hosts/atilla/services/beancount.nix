{ config, lib, pkgs, ... }:

let
  dir = "/var/lib/beancount";

  # Only copied in when the file is absent: after that the ledger is user data,
  # edited through Fava, and a rebuild must never touch it.
  seedMain = pkgs.writeText "main.beancount" ''
    option "title" "Finances"
    option "operating_currency" "EUR"
    option "operating_currency" "USD"

    include "prices.beancount"
  '';

  # Beancount errors on an include whose target is missing, and fava refuses to
  # start on a ledger path that doesn't exist, so both have to be there before
  # either unit runs.
  seed = pkgs.writeShellScript "beancount-seed" ''
    [ -e ${dir}/main.beancount ]   || install -m 0640 ${seedMain} ${dir}/main.beancount
    [ -e ${dir}/prices.beancount ] || install -m 0640 /dev/null ${dir}/prices.beancount
  '';

  common = {
    User = "beancount";
    Group = "beancount";
    StateDirectory = "beancount";
    StateDirectoryMode = "0750";
    UMask = "0027";
    ExecStartPre = seed;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
  };
in
{
  # Beancount ledger + Fava web UI, for spending and investments.
  #
  # The ledger is plain text in /var/lib/beancount (main.beancount, plus
  # prices.beancount which the timer below appends to). Fava's built-in editor
  # is the editing path, so the files belong to the service user and nothing
  # else writes them.
  #
  # Fava has no authentication of any kind. Like paperless it is NOT behind
  # Pangolin; caddy fronts it with basic_auth (see services/caddy.nix), so the
  # LAN as a whole doesn't get to read the ledger.
  #
  # Investments: give each commodity a `price:` source and the timer fetches a
  # quote every weekday evening, e.g.
  #   2020-01-01 commodity VTI
  #     price: "USD:yahoo/VTI"
  #   2020-01-01 commodity USD
  #     price: "EUR:ecbrates/USD-EUR"

  users.users.beancount = {
    isSystemUser = true;
    group = "beancount";
    home = dir;
  };
  users.groups.beancount = { };

  systemd.services.fava = {
    description = "Fava web UI for the beancount ledger";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = common // {
      ExecStart = "${pkgs.fava}/bin/fava --host 127.0.0.1 --port 5000 ${dir}/main.beancount";
      Restart = "on-failure";
    };
  };

  systemd.services.beancount-prices = {
    description = "Fetch commodity prices into the beancount ledger";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.beanprice ];
    serviceConfig = common // { Type = "oneshot"; };
    # --inactive: without it bean-price only quotes commodities held *at cost*,
    # which skips FX entirely (cash in USD carries no cost basis). It doesn't
    # imply --clobber, so a quote already in prices.beancount for the day isn't
    # fetched again — reruns and Persistent catch-ups don't pile up duplicates.
    # --no-cache: the default cache never expires, which is wrong for "latest".
    script = ''
      set -euo pipefail
      out=$(bean-price --inactive --no-cache ${dir}/main.beancount)
      if [ -n "$out" ]; then
        printf '%s\n' "$out" >> ${dir}/prices.beancount
      fi
    '';
  };

  systemd.timers.beancount-prices = {
    description = "Weekday commodity price fetch";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # After the US close (22:00 Paris); ECB reference rates land ~16:00 CET.
      OnCalendar = "Mon..Fri 23:30";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}
