{ config, pkgs, ... }:

{
  # Weekly flake-input update gated on an all-hosts build: updates a private
  # checkout, builds the x86_64 hosts (warming the cache) and evals the aarch64
  # hosts (genghis can't build them); only if ALL pass does it commit + push the
  # lock, else the repo stays last-known-good. Discord either way. Never
  # switches — you still `git pull && nrs`.
  #
  # Bootstrap once on genghis:
  #   sudo -u flake-bot ssh-keygen -t ed25519 -N "" -f /var/lib/flake-bot/.ssh/id_ed25519
  #   sudo -u flake-bot sh -c 'ssh-keyscan github.com >> /var/lib/flake-bot/.ssh/known_hosts'
  #   # add the .pub as a write deploy key on github.com/ulyssecrn/nixos-config
  #   sudo -u flake-bot git clone git@github.com:ulyssecrn/nixos-config.git /var/lib/flake-bot/nixos
  #   echo 'DISCORD_WEBHOOK_URL=...' | sudo tee /var/lib/flake-bot/env   # then chmod 0600, chown flake-bot
  #   sudo systemctl start flake-bot   # test before trusting the timer

  users.users.flake-bot = {
    isSystemUser = true;
    group = "flake-bot";
    home = "/var/lib/flake-bot";
    createHome = true;
  };
  users.groups.flake-bot = { };

  systemd.services.flake-bot = {
    description = "Weekly flake-input update with all-hosts build gate";
    after = [ "network-online.target" "nix-daemon.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "flake-bot";
      Group = "flake-bot";
      EnvironmentFile = "/var/lib/flake-bot/env";
      WorkingDirectory = "/var/lib/flake-bot/nixos";
    };
    path = [ config.nix.package pkgs.git pkgs.openssh pkgs.curl pkgs.jq pkgs.coreutils ];
    script = ''
      set -uo pipefail
      STATE=/var/lib/flake-bot
      cd "$STATE/nixos" || { exit 1; }
      export GIT_SSH_COMMAND="ssh -i $STATE/.ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=$STATE/.ssh/known_hosts"

      X86_HOSTS="loki atilla genghis"
      ARM_HOSTS="odin hannibal"

      notify() {
        jq -nc --arg c "$1" '{content: $c}' \
          | curl -fsS --max-time 20 -X POST -H "Content-Type: application/json" \
              --data-binary @- "$DISCORD_WEBHOOK_URL" || true
      }

      if ! git fetch --prune origin; then notify ":warning: flake-bot: \`git fetch\` failed on genghis"; exit 1; fi
      git reset --hard origin/main
      git clean -fd
      OLD=$(git rev-parse --short HEAD)

      if ! nix flake update 2> "$STATE/update.log"; then
        notify ":x: flake-bot: \`nix flake update\` failed:
\`\`\`
$(tail -c 1400 "$STATE/update.log")
\`\`\`"
        exit 1
      fi
      if git diff --quiet flake.lock; then
        echo "no input changes — nothing to do"; exit 0
      fi

      # build x86_64 (warms cache via GC-rooted links); eval aarch64 (can't build here)
      mkdir -p "$STATE/gcroots"
      summary=""
      errtail=""
      failed=0

      for h in $X86_HOSTS; do
        if nix build ".#nixosConfigurations.$h.config.system.build.toplevel" \
             --out-link "$STATE/gcroots/result-$h" 2> "$STATE/build-$h.log"; then
          summary+="✅ $h (built)"$'\n'
        else
          summary+="❌ $h (build)"$'\n'; failed=1
          errtail+="── $h ──"$'\n'"$(tail -c 700 "$STATE/build-$h.log")"$'\n'
        fi
      done

      for h in $ARM_HOSTS; do
        if nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" \
             > /dev/null 2> "$STATE/eval-$h.log"; then
          summary+="✅ $h (eval)"$'\n'
        else
          summary+="❌ $h (eval)"$'\n'; failed=1
          errtail+="── $h ──"$'\n'"$(tail -c 700 "$STATE/eval-$h.log")"$'\n'
        fi
      done

      if [ "$failed" -eq 0 ]; then
        git -c user.name="flake-bot" -c user.email="flake-bot@genghis" \
          commit -am "[flake] weekly bot auto update"
        NEW=$(git rev-parse --short HEAD)
        if git push origin main 2> "$STATE/push.log"; then
          notify ":white_check_mark: **flake update green** ($OLD→$NEW)
$summary
Pull + \`nrs\` to switch (cache is warm)."
        else
          notify ":warning: built green but **push failed** — lock committed locally only:
\`\`\`
$(tail -c 1000 "$STATE/push.log")
\`\`\`"
        fi
      else
        git checkout -- flake.lock
        notify ":x: **flake update FAILED — lock NOT advanced** (still $OLD)
$summary
\`\`\`
$(printf '%s' "$errtail" | tail -c 1300)
\`\`\`"
      fi
    '';
  };

  systemd.timers.flake-bot = {
    description = "Weekly flake-bot run";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sat *-*-* 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
