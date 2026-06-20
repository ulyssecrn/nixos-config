{
  description = "ucorne's nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };

    lazyvim.url = "github:pfassina/lazyvim-nix";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-apple-silicon, home-manager, home-manager-stable, lazyvim, nixos-hardware, nixos-raspberrypi, ... }@inputs:
  let
    mkHost = { hostName, extraModules ? [], builder ? nixpkgs.lib.nixosSystem, system ? null, hm ? home-manager }:
      builder (
        {
          modules = [
            ./hosts/${hostName}/configuration.nix
            hm.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit lazyvim inputs; };
              home-manager.users.ucorne = import ./hosts/${hostName}/home/home.nix;
            }
          ] ++ extraModules;
        }
        // (if system != null then { inherit system; } else {})
      );
  in {
    # ── Genghis ─────────────────────────────────────────────────────────
    # x86 desktop with Nvidia 3090Ti
    nixosConfigurations.genghis = mkHost {
      system = "x86_64-linux";
      hostName = "genghis";
    };

    # ── Odin ─────────────────────────────────────────────────────────
    # Macbook Pro M1 pro (Asahi Linux)
    nixosConfigurations.odin = mkHost {
      system = "aarch64-linux";
      hostName = "odin";
      extraModules = [ nixos-apple-silicon.nixosModules.apple-silicon-support ];
    };

    # ── Loki ─────────────────────────────────────────────────────────
    # ThinkPad X1 Carbon gen 13, Lunar Lake Intel 258V
    nixosConfigurations.loki = mkHost {
      system = "x86_64-linux";
      hostName = "loki";
      extraModules = [ nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen ];
    };

    # ── Atilla ───────────────────────────────────────────────────────
    # x86 home server, Intel 11700K + Nvidia 1080 Ti, btrfs+LUKS + ZFS + mergerfs
    nixosConfigurations.atilla = mkHost {
      system = "x86_64-linux";
      hostName = "atilla";
    };

    # ── Hannibal ─────────────────────────────────────────────────────
    # Raspberry Pi 5 — LAN server. nixos-raspberrypi provides its own builder
    # (its rpi-linux kernel + firmware + bootloader); pinned to nixos-25.11.
    nixosConfigurations.hannibal = mkHost {
      hostName = "hannibal";
      builder = nixos-raspberrypi.lib.nixosSystem;
      hm = home-manager-stable;
      extraModules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nixos-raspberrypi.nixosModules.trusted-nix-caches
      ];
    };
  };
}

