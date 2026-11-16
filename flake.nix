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
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };

    # Pinned to the parent of 30f8896 (#115), which renamed dev-path dirs to
    # owner--repo; lazy.nvim maps a module back to its plugin by dir name, so
    # lazy-loaded plugins get required without loading and nvim errors on start
    # (lualine/trouble). Unpin once upstream #119 (issue #117) lands.
    lazyvim.url = "github:pfassina/lazyvim-nix/5fd3c18f49d5d82c7411c56656c49aa27ca4d06e";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hermes patches patchelf with a fix that only applies to 0.19.x, and nixpkgs
    # went back 0.19.2 -> 0.15.2 in Nov 2026, so on our nixpkgs the patch fails
    # and the hermes build dies. Pin it to the last unstable rev with 0.19.2 (an
    # explicit rev: dropping `follows` alone re-resolves to latest unstable
    # rather than hermes's own lock). Restore `follows = "nixpkgs"` once
    # upstream gates the patch on the patchelf version.
    nixpkgs-hermes.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
    # Pinned to the last rev that builds: f578714 (2026-11-15) ships a stale
    # pnpmDeps hash for hermes-tui (ERR_PNPM_NO_OFFLINE_TARBALL). Unpin once
    # upstream refreshes it.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/4b40ffb0ad6d7da5d3260f5e499e1691508dd4d5";
      inputs.nixpkgs.follows = "nixpkgs-hermes";
    };

    # Agent skills packs — plain repos of SKILL.md folders, not flakes. Consumed
    # by home/modules/skills/ and shared across claude-code/codex/
    # opencode. `flake = false` so it's just a pinned source tree the flake-bot
    # bumps weekly.
    kistack = {
      url = "github:American-Embedded/kistack";
      flake = false;
    };

    # Portfolio site at ulysse.corne.sh. Not following nixpkgs, so the server
    # builds with the same Zola that the site's CI tested.
    website.url = "github:ulyssecrn/website";
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
    # Out-of-tree packages, exposed so `nix-update --flake <name>` can bump
    # their version + hashes (it needs a flake attr to evaluate). The flake-bot
    # runs nix-update on these weekly, behind its build gate — see
    # hosts/genghis/services/flake-bot.nix. Build one with `nix build .#<name>`.
    packages.x86_64-linux.playwright-cli =
      (import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      }).callPackage ./home/pkgs/playwright-cli.nix { };

    # ── Genghis ─────────────────────────────────────────────────────────
    # x86 desktop with Nvidia 3090
    nixosConfigurations.genghis = mkHost {
      system = "x86_64-linux";
      hostName = "genghis";
      extraModules = [ inputs.hermes-agent.nixosModules.default ];
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
      extraModules = [ inputs.website.nixosModules.default ];
    };

    # ── Lafayette ────────────────────────────────────────────────────
    # ThinkCentre M900 Tiny — headless server on the US LAN
    nixosConfigurations.lafayette = mkHost {
      system = "x86_64-linux";
      hostName = "lafayette";
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

