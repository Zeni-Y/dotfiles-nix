# ─────────────────────────────────────────────────────────────
# macOS 用ホスト設定 (nix-darwin + Home Manager)
#
# nix-darwin がシステムレベル (Homebrew, defaults write 等) を、
# その上で home-manager がユーザーレベルの dotfiles を管理する。
# ─────────────────────────────────────────────────────────────
{ inputs, userInfo }:

inputs.nix-darwin.lib.darwinSystem {
  # Apple Silicon を既定にしている。Intel Mac の場合は "x86_64-darwin" に変更。
  system = "aarch64-darwin";

  specialArgs = { inherit inputs userInfo; };

  modules = [
    ../darwin

    inputs.home-manager.darwinModules.home-manager
    {
      nixpkgs.config.allowUnfree = true;

      # nix-darwin now requires primaryUser to be set explicitly for
      # any options that apply to a specific user (Homebrew, system.defaults, etc.)
      system.primaryUser = userInfo.username;

      users.users.${userInfo.username}.home = "/Users/${userInfo.username}";

      # Home Manager を nix-darwin に同居させる設定
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit userInfo; };
      home-manager.users.${userInfo.username} = {
        imports = [ ../home ];

        home.username = userInfo.username;
        home.homeDirectory = "/Users/${userInfo.username}";
        home.stateVersion = "25.05";

        programs.git.settings.user.name = userInfo.gitName;
        programs.git.settings.user.email = userInfo.gitEmail;
      };
    }
  ];
}
