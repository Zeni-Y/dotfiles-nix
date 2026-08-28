# ─────────────────────────────────────────────────────────────
# MacBook (macOS) 用ホスト設定 (standalone home-manager)
#
# macOS でも nix-darwin は使わず、Ubuntu と同じくホームディレクトリ
# 配下のみを home-manager で管理する。システム領域 (Dock / Finder の
# defaults、Homebrew で入れる GUI アプリなど) は対象外。
# Nix は sudo を使う通常の multi-user 構成 (/nix) を前提にする。
#
# Linux 専用モジュール (../home/wsl-ssh-agent.nix) はここでは import
# しない。macOS の home-manager には systemd.user.* オプション自体が
# 無いので、import すると評価が通らない。
# ─────────────────────────────────────────────────────────────
{ inputs, userInfo }:

let
  # Apple Silicon 前提。Intel Mac に入れるなら "x86_64-darwin" に変える。
  system = "aarch64-darwin";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ inputs.nix-claude-code.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  modules = [
    ../home

    {
      home.username = userInfo.username;
      # macOS のホームは /home ではなく /Users
      home.homeDirectory = "/Users/${userInfo.username}";
      home.stateVersion = "25.05";

      programs.git.settings.user.name = userInfo.gitName;
      programs.git.settings.user.email = userInfo.gitEmail;

      # `ghq get <repo>` と owner を省略したときの補完先。
      # home/shell/fish.nix の flakeDir もこの値から導出している。
      programs.git.settings.ghq.user = userInfo.githubUser;

      # fish の hms などが適用先として参照する homeConfigurations の
      # キーのホスト部 (home/shell/fish.nix)
      dotfiles.flakeHost = "macbook";
    }
  ];
}
