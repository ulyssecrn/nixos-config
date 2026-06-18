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

      system.stateVersion = "25.11";
    };
  };
}
