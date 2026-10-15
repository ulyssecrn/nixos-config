{ config, pkgs, lib, ... }:

let
  lanIf = "eno1";              # lafayette's onboard I219 — check `ip -br link`
  gatewayAddr = "10.20.20.20"; # outside the router's .100–.254 DHCP pool
  frenchExitNode = "100.110.148.102"; # atilla — residential, not atilla-proton (streaming blocks VPN IPs)
in
{
  # TV gateway to France. The Fire TV (Vega OS, no Tailscale app) is given a
  # static config with gateway = 10.20.20.20; that address is this nspawn
  # container, sitting on the LAN through a macvlan with its own tailscaled
  # identity ("lafayette-fr") whose exit node is a French host. Only devices
  # pointed at it go to France — lafayette itself stays a US exit node (a node
  # can't both use and advertise one).
  #
  # Forwarded LAN traffic is SNATed onto the container's tailnet IP (the exit
  # node only accepts packets from a node's own address). If the exit node is
  # unreachable, tailscale keeps the default route on tailscale0, so the TV
  # loses internet rather than falling back to a US IP.
  #
  # One-time setup, after the first nrs:
  #   sudo nixos-container root-login lafayette-fr
  #   tailscale up --hostname=lafayette-fr --accept-dns=false \
  #                --exit-node=100.110.148.102 --exit-node-allow-lan-access
  # Open the printed URL. Prefs persist in the container's /var/lib/tailscale.
  # Never --accept-routes here: it pulls in lafayette's own 10.20.20.0/24, and
  # the container's replies to the LAN (the TV included) vanish into the tunnel.
  #
  # The TV must not have IPv6 via the Verizon router, or it streams straight
  # out of the US over v6 and only v4 goes through here.

  containers.lafayette-fr = {
    autoStart = true;
    privateNetwork = true;
    # No veth: the container's own outbound (control plane, DERP, WireGuard)
    # goes straight to the router through the macvlan, so no host-side NAT.
    # Side effect of macvlan: lafayette itself can't reach 10.20.20.20.
    macvlans = [ lanIf ];

    allowedDevices = [
      { node = "/dev/net/tun"; modifier = "rw"; }
    ];

    config = { config, pkgs, lib, ... }: {
      networking.hostName = "lafayette-fr";
      networking.useDHCP = false;
      networking.interfaces."mv-${lanIf}".ipv4.addresses = [{
        address = gatewayAddr;
        prefixLength = 24;
      }];
      networking.defaultGateway = { address = "10.20.20.1"; interface = "mv-${lanIf}"; };
      networking.useHostResolvConf = lib.mkForce false;
      networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];

      # Only the LAN (macvlan) and tailscale's WireGuard reach this; the NixOS
      # firewall's rpfilter would also fight the exit-node policy routing.
      networking.firewall.enable = false;

      services.tailscale.enable = true;
      services.tailscale.useRoutingFeatures = "client";

      # --exit-node-allow-lan-access should add a throw for the LAN to table 52,
      # but tailscaled doesn't treat the macvlan as a LAN interface: table 52 is
      # just `default dev tailscale0`, so every reply to the LAN — the TV's
      # included — went into the tunnel. Send LAN destinations to main ahead of
      # tailscale's 5270 rule ourselves.
      systemd.services.lan-bypass-tailscale = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ${pkgs.iproute2}/bin/ip rule del to 10.20.20.0/24 lookup main priority 5200 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip rule add to 10.20.20.0/24 lookup main priority 5200
        '';
        preStop = ''
          ${pkgs.iproute2}/bin/ip rule del to 10.20.20.0/24 lookup main priority 5200 || true
        '';
      };

      networking.nat = {
        enable = true;
        internalInterfaces = [ "mv-${lanIf}" ];
        externalInterface = "tailscale0";
        # tailscale0 is MTU 1280; the TV assumes 1500. Clamp MSS on forwarded
        # SYNs or large TCP transfers (i.e. video) stall on blackholed PMTU.
        extraCommands = ''
          iptables -t mangle -C FORWARD -o tailscale0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
            || iptables -t mangle -A FORWARD -o tailscale0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        '';
      };

      system.stateVersion = "26.05";
    };
  };
}
