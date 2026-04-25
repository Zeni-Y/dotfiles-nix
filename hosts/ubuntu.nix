# ─────────────────────────────────────────────────────────────
# Ubuntu 用ホスト設定 (standalone home-manager)
#
# Ubuntu は NixOS ではないため、システム全体を Nix で管理せず
# ホームディレクトリ配下のみ home-manager で管理する構成にする。
# ─────────────────────────────────────────────────────────────
{ inputs, userInfo }:

let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  modules = [
    ../home

    {
      home.username = userInfo.username;
      home.homeDirectory = "/home/${userInfo.username}";
      home.stateVersion = "25.05";

      programs.git.userName = userInfo.gitName;
      programs.git.userEmail = userInfo.gitEmail;
    }
  ];
}
