{ config, pkgs, ... }:

{
  # Weekly flake-input update, two-stage gate on a private checkout. Only if
  # BOTH stages pass does it commit + push the lock, else the repo stays
  # last-known-good. Discord either way. Never switches — you still
  # `git pull && nrs`.
  #
  #   stage 1  eval all five hosts (seconds)
  #   stage 2  build the x86_64 hosts (genghis can't build the aarch64 ones)
  #
  # Eval runs first *and covers every host* on purpose. A bad input bump almost
  # always breaks eval rather than compilation (renamed/removed options, a
  # home-manager↔nixpkgs API skew), and eval is a strict subset of what a build
  # does — so hoisting it costs nothing and turns a ~40min feedback loop into a
  # ~10s one. This is not hypothetical: the 2026-08-08 run spent three full x86
  # builds before reporting a hannibal *eval* failure that was knowable
  # instantly.
  #
  # A failing eval does NOT skip stage 2 — the hosts that evaled clean still get
  # built. The lock won't be pushed, but your fix commit reuses nearly all of
  # those closures, so the re-run after you fix it is cheap.
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
    path = [
      config.nix.package
      pkgs.git
      pkgs.openssh
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    script = ''
      set -uo pipefail
      STATE=/var/lib/flake-bot
      cd "$STATE/nixos" || { exit 1; }
      export GIT_SSH_COMMAND="ssh -i $STATE/.ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=$STATE/.ssh/known_hosts"

      X86_HOSTS="loki atilla genghis"
      ARM_HOSTS="odin hannibal"
      ALL_HOSTS="$X86_HOSTS $ARM_HOSTS"

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

      # Which inputs moved, one line each: "name: olddate → newdate". Goes in
      # every failure notification — the culprit is almost always visible here,
      # and a bump can drag an input across a whole nixpkgs release without
      # anything in this repo changing (nixos-raspberrypi silently went
      # nixos-25.11 → nixos-26.05 that way, which is what broke the 2026-08-08
      # run). nix prints each input as a 3-line stanza with a rev and a narHash;
      # `paste - - -` folds each stanza back to one line and the revs are dropped
      # — the name and the date jump are what you actually read, and the whole
      # block has to fit alongside a stack trace in a 2000-char Discord message.
      inputs=$(grep -E "^(• Updated input|  →|    ')" "$STATE/update.log" \
        | sed -E "s/^• Updated input '(.*)':$/\1/; s/^    '.*' \((.*)\)$/\1/; s/^  → '.*' \((.*)\)$/\1/" \
        | paste - - - | sed -E 's/\t/: /; s/\t/ → /' | head -25)

      # ── stage 1: eval every host ──────────────────────────────────────
      evalsummary=""
      errtail=""
      evalfailed=0
      GREEN_X86=""

      for h in $ALL_HOSTS; do
        if nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" \
             > /dev/null 2> "$STATE/eval-$h.log"; then
          evalsummary+="✅ $h (eval)"$'\n'
          case " $X86_HOSTS " in *" $h "*) GREEN_X86+="$h " ;; esac
        else
          evalsummary+="❌ $h (eval)"$'\n'; evalfailed=1
          errtail+="── $h ──"$'\n'"$(tail -c 700 "$STATE/eval-$h.log")"$'\n'
        fi
      done

      # Report the verdict before stage 2 rather than after it — that ordering
      # is the whole point of the split.
      if [ "$evalfailed" -ne 0 ]; then
        notify ":x: **eval gate FAILED — lock NOT advanced** (still $OLD)
$evalsummary
Inputs that moved:
\`\`\`
$inputs
\`\`\`
\`\`\`
$(printf '%s' "$errtail" | tail -c 900)
\`\`\`
Building the hosts that evaled clean anyway, to warm the cache for your fix."
      fi

      # ── stage 2: build the x86_64 hosts that evaled clean ─────────────
      # GC-rooted so the closures survive the fleet-wide gc until the next run.
      mkdir -p "$STATE/gcroots"
      buildsummary=""
      buildfailed=0
      # Kept separate from errtail: on the eval-failure path that one has
      # already been sent, and appending to it would re-send the eval trace.
      builderrtail=""

      for h in $GREEN_X86; do
        if nix build ".#nixosConfigurations.$h.config.system.build.toplevel" \
             --out-link "$STATE/gcroots/result-$h" 2> "$STATE/build-$h.log"; then
          buildsummary+="✅ $h (built)"$'\n'
        else
          buildsummary+="❌ $h (build)"$'\n'; buildfailed=1
          builderrtail+="── $h ──"$'\n'"$(tail -c 700 "$STATE/build-$h.log")"$'\n'
        fi
      done

      # Revert only after stage 2: the builds have to run against the NEW lock
      # or they warm nothing.
      if [ "$evalfailed" -ne 0 ]; then
        # Verdict already sent above; speak again only if the cache-warming
        # builds surfaced something the eval gate couldn't — eval-green but
        # build-broken (a package that doesn't compile, not a config error).
        if [ "$buildfailed" -ne 0 ]; then
          notify ":warning: flake-bot: cache-warming builds also failed:
$buildsummary
\`\`\`
$(printf '%s' "$builderrtail" | tail -c 900)
\`\`\`"
        fi
        git checkout -- flake.lock
        exit 1
      fi

      if [ "$buildfailed" -ne 0 ]; then
        git checkout -- flake.lock
        notify ":x: **build gate FAILED — lock NOT advanced** (still $OLD)
$evalsummary$buildsummary
Inputs that moved:
\`\`\`
$inputs
\`\`\`
\`\`\`
$(printf '%s' "$builderrtail" | tail -c 900)
\`\`\`"
        exit 1
      fi

      git -c user.name="flake-bot" -c user.email="flake-bot@genghis" \
        commit -am "[flake] weekly bot auto update"
      NEW=$(git rev-parse --short HEAD)
      if git push origin main 2> "$STATE/push.log"; then
        notify ":white_check_mark: **flake update green** ($OLD→$NEW)
$evalsummary$buildsummary
Pull + \`nrs\` to switch (cache is warm)."
      else
        notify ":warning: built green but **push failed** — lock committed locally only:
\`\`\`
$(tail -c 1000 "$STATE/push.log")
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
