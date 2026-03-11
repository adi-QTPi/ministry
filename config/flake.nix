{
  description = "Aditya's Highly Portable Multi-Machine Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    
    homeConfigurations = {
      "aditya@hogwarts" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."aarch64-darwin"; 
        modules = [ ./hosts/hogwarts/home.nix ];
      };

      "karma@teddy" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux"; 
        modules = [ ./hosts/teddy/home.nix ];
      };

      "karma@rubie" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux"; 
        modules = [ ./hosts/rubie/home.nix ];
      };

    };
  };
}