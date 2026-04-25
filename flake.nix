{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
  let
    # ご自分のシステムに合わせて変更してください:
    #   Linux (x86_64):      "x86_64-linux"
    #   Mac (Apple Silicon): "aarch64-darwin"
    #   Mac (Intel):         "x86_64-darwin"
    system = "x86_64-linux";

    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    homeConfigurations."yourname" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home.nix ];
    };
  };
}
