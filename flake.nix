{
  description = "Minimal macOS Nix setup with nix-darwin + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # herdr isn't in nixpkgs-24.11 yet, so it's pulled straight from its own flake
    herdr.url = "github:ogulcancelik/herdr";
  };

  outputs = { nixpkgs, nix-darwin, home-manager, herdr, ... }: {
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = [
        ./nix/host.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit herdr; };
          home-manager.users.yash_khandelwal = import ./nix/user.nix;
        }
      ];
    };
  };
}
