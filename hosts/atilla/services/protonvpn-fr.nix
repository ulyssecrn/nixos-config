{ config, pkgs, lib, ... }:

{
  # ProtonVPN-France exit node — runs in a systemd-nspawn container with its
  # own tailscaled identity ("atilla-proton"). Tailnet devices picking this
  # node as their exit route get sent out via ProtonVPN-France.
  #
  # Split routing inside the container: tailscaled's own outbound (control
  # plane, derp) goes via veth → atilla → WAN; tailnet-forwarded traffic
  # (iif tailscale0) goes via wg-protonvpn-fr. If wg goes down, forwarded
  # traffic is dropped (kill switch — no fallback in custom table) but the
  # node itself stays reachable for debugging.
  #
  # One-time setup:
  #   1. ProtonVPN dashboard → WireGuard → create config for a France server.
  #      From the downloaded .conf, copy:
  #        PrivateKey  → /var/lib/protonvpn-fr/private  (chmod 600 root:root)
  #        PublicKey   → peers.publicKey below
  #        Endpoint    → peers.endpoint below
  #        Address     → address below (typically 10.2.0.2/32)
  #   2. nrs on atilla.
  #   3. Inside the container, register the tailscale identity:
  #        sudo nixos-container root-login atilla-proton
  #        tailscale up --advertise-exit-node --accept-dns=false \
  #                     --hostname=atilla-proton
  #      Open the printed URL to authenticate. In the Tailscale admin
  #      console, approve the exit node.

  # WireGuard kernel module needs to be loaded on the host so the container
  # can create wg interfaces.
  boot.kernelModules = [ "wireguard" ];

  # Host-side NAT for the container's own outbound traffic (tailscaled →
  # control plane, wg → ProtonVPN endpoint). Wildcard "ve-+" matches any
  # nspawn veth, so we don't have to hard-code the truncated container name.
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "enp6s0";
  };

  containers.atilla-proton = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";

    # ProtonVPN WireGuard private key, mounted read-only from the host.
    bindMounts."/var/lib/protonvpn-fr" = {
      hostPath = "/var/lib/protonvpn-fr";
      isReadOnly = true;
    };

    # /dev/net/tun for tailscaled.
    allowedDevices = [
      { node = "/dev/net/tun"; modifier = "rw"; }
    ];

    config = { config, pkgs, lib, ... }: {
      networking.hostName = "atilla-proton";
      networking.useDHCP = false;
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      # Drop the firewall — the only inbound paths are veth (from atilla,
      # controlled) and the tailscale wireguard. Tailscale's own openFirewall
      # would re-add rules; cleaner to just turn it off in this container.
      networking.firewall.enable = false;

      services.tailscale.enable = true;
      # Enables ip_forward so Tailscale recognizes exit node capability.
      services.tailscale.useRoutingFeatures = "server";

      # UDP GRO offload on the veth — required for non-terrible exit-node
      # throughput per https://tailscale.com/s/ethtool-config-udp-gro.
      # Without this, every forwarded UDP packet is processed individually
      # instead of batched. Roughly doubles throughput on this kind of
      # forwarding-only host.
      systemd.services.tailscale-udp-gro = {
        description = "Enable UDP GRO forwarding on eth0 for Tailscale exit node";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
        '';
      };

      # ProtonVPN-France WireGuard. table=off so wg-quick doesn't touch any
      # routing table — we install routes manually into table 200 below.
      networking.wg-quick.interfaces.protonvpn-fr = {
        address = [ "10.2.0.2/32" ];
        privateKeyFile = "/var/lib/protonvpn-fr/private";
        table = "off";
        peers = [{
          publicKey = "mbgw7Sxzok7Px1T/cTLDvWEdbU8bWWS00aOhAJy2omQ=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "146.70.194.34:51820";
          persistentKeepalive = 25;
        }];
      };

      # Custom routing table for tailnet-forwarded traffic. Container's own
      # outbound stays on main table → veth → atilla → WAN, so tailscaled
      # keeps reaching its control plane even when wg is down.
      networking.iproute2 = {
        enable = true;
        rttablesExtraConfig = ''
          200  protonvpn
        '';
      };

      systemd.services.protonvpn-fr-routes = {
        description = "ProtonVPN-FR routing (table 200 + tailnet-iif ip rule)";
        requires = [ "wg-quick-protonvpn-fr.service" ];
        after    = [ "wg-quick-protonvpn-fr.service" ];
        partOf   = [ "wg-quick-protonvpn-fr.service" ];
        wantedBy = [ "wg-quick-protonvpn-fr.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ${pkgs.iproute2}/bin/ip route replace default dev protonvpn-fr table protonvpn
          ${pkgs.iproute2}/bin/ip rule add iif tailscale0 lookup protonvpn priority 200 || true
        '';
        preStop = ''
          ${pkgs.iproute2}/bin/ip rule del iif tailscale0 lookup protonvpn priority 200 || true
        '';
      };

      # MASQUERADE for tailnet→wg forwarded traffic so returns come back here.
      networking.nat = {
        enable = true;
        internalInterfaces = [ "tailscale0" ];
        externalInterface = "protonvpn-fr";
      };

      # Uptime Kuma heartbeat: probes WireGuard handshake freshness and pushes
      # when healthy. Silence = Kuma marks down. KUMA_URL_PROTONVPN_FR lives in
      # /var/lib/protonvpn-fr/env (the same bind-mounted dir as the wg key).
      systemd.services.kuma-push-protonvpn-fr = {
        description = "Kuma heartbeat: ProtonVPN-FR tunnel health";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = "/var/lib/protonvpn-fr/env";
        };
        script = ''
          set -eu
          # With persistentKeepalive=25, handshake should refresh every
          # ~25s. >3min stale ≈ tunnel broken.
          handshake_ts=$(${pkgs.wireguard-tools}/bin/wg show protonvpn-fr latest-handshakes 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}')
          if [ -z "$handshake_ts" ] || [ "$handshake_ts" = "0" ]; then
            echo "no handshake — tunnel never established"
            exit 1
          fi
          age=$(( $(date +%s) - handshake_ts ))
          if [ "$age" -gt 180 ]; then
            echo "handshake stale: ''${age}s"
            exit 1
          fi
          ${pkgs.curl}/bin/curl -fsS --max-time 10 "$KUMA_URL_PROTONVPN_FR" || true
        '';
      };

      systemd.timers.kuma-push-protonvpn-fr = {
        description = "Probe + push ProtonVPN-FR tunnel health";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1min";
          AccuracySec = "1s";  # default 1min jitter races the Kuma window
          Unit = "kuma-push-protonvpn-fr.service";
        };
      };

      system.stateVersion = "25.11";
    };
  };
}
