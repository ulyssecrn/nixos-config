{
  description = "ucorne's nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim.url = "github:pfassina/lazyvim-nix";
  };

  outputs = { self, nixpkgs, nixos-apple-silicon, nixos-hardware, home-manager, stylix, lazyvim,  ... }@inputs:
  let
    mkHost = { system, hostName, extraModules ? [] }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostName}/configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit lazyvim; };
            home-manager.users.ucorne = import ./hosts/${hostName}/home/home.nix;
          }
          stylix.nixosModules.stylix
        ] ++ extraModules;
      };
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
  };
}

