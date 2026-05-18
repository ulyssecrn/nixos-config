{ config, lib, pkgs, ... }:

{
  # qBittorrent with built-in ProtonVPN tunnel (binhex/arch-qbittorrentvpn).
  # The container uses OpenVPN; .ovpn files live in /srv/appdata/binhex-qbittorrentvpn/openvpn/
  #
  # VPN_USER / VPN_PASS are sensitive — kept outside the nix store at:
  #   /var/lib/qbittorrent/env   (root:root mode 0600)
  # File contents:
  #   VPN_USER=...
  #   VPN_PASS=...
  virtualisation.oci-containers.containers.qbittorrent = {
    image = "binhex/arch-qbittorrentvpn";
    environment = {
      TZ = "Europe/Paris";
      PUID = "99";
      PGID = "100";
      UMASK = "000";
      VPN_ENABLED = "yes";
      VPN_CLIENT = "openvpn";
      VPN_PROV = "protonvpn";
      STRICT_PORT_FORWARD = "yes";
      ENABLE_PRIVOXY = "no";
      ENABLE_SOCKS = "no";
      USERSPACE_WIREGUARD = "no";
      NAME_SERVERS = "1.1.1.1,1.0.0.1";
      LAN_NETWORK = "10.10.10.0/24";
      WEBUI_PORT = "8080";
      VPN_INPUT_PORTS = "9696";    # opened in VPN tunnel for Prowlarr
      DEBUG = "false";
    };
    environmentFiles = [ "/var/lib/qbittorrent/env" ];
    volumes = [
      "/srv/appdata/binhex-qbittorrentvpn:/config:rw"
      # Downloads on the mergerfs union so they share a "filesystem" with the
      # library; new downloads + their hardlinks land on the same branch.
      "/srv/media/torrents:/media/torrents:rw"
    ];
    ports = [
      "8080:8080"        # WebUI
      "58946:58946"      # torrent TCP
      "58946:58946/udp"  # torrent UDP
      "9696:9696"        # Prowlarr (forwarded through VPN)
    ];
    extraOptions = [
      "--privileged"
      "--security-opt=label=disable"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
    ];
    autoStart = true;
  };

  systemd.services."podman-qbittorrent".unitConfig.RequiresMountsFor = "/srv/media";

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent    0700 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 58946 9696 ];
  networking.firewall.allowedUDPPorts = [ 58946 ];
}
