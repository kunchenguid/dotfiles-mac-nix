{
  description = "Minimal macOS Nix setup with nix-darwin + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Agentic-workflow tooling built by Kun Chen (github.com/kunchenguid),
    # pulled in as a flake input since it ships its own Nix package.
    treehouse = {
      url = "github:kunchenguid/treehouse";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-darwin, home-manager, treehouse, ... }: {
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./nix/host.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.yuweiyan = import ./nix/user.nix;
          home-manager.extraSpecialArgs = { inherit treehouse; };
        }
      ];
    };
  };
}
