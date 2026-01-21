{
  description = "ucorne's nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-apple-silicon, home-manager, ... }@inputs: {
    nixosConfigurations.genghis = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/genghis/configuration.nix
        home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ucorne = import ./hosts/genghis/home-genghis.nix;
        }
      ];
    };
    nixosConfigurations.odin = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/odin/configuration.nix
        nixos-apple-silicon.nixosModules.apple-silicon-support
        home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ucorne = import ./hosts/odin/home-odin.nix;
        }
      ];
    };
    nixosConfigurations.loki = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/loki/configuration.nix
        home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.ucorne = import ./hosts/loki/home-loki.nix;
        }
      ];
    };
  };
}

