# ─────────────────────────────────────────────────────────────
# MacBook (Apple Silicon) 用ホスト設定 (standalone home-manager)
#
# Ubuntu と同じく nix-darwin は使わず、ホームディレクトリ配下だけを
# home-manager で管理する。システム側 (/etc, launchd のシステムデーモン,
# Homebrew, macOS の defaults) には触らない。Linux と同じ「~/ だけ」の
# 管理範囲に揃えることで、home/ のモジュールをほぼそのまま共有できる。
#
# macOS 固有の差分 (ログインシェルが zsh であること、フォントの置き場所など)
# は home/darwin.nix に集め、このホストからだけ import する。
# 共通モジュール側に isDarwin の分岐を散らさないため。
# ─────────────────────────────────────────────────────────────
{ inputs, userInfo }:

let
  system = "aarch64-darwin";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ inputs.nix-claude-code.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  # homeConfigurations のキー (<user>@<hostName>) の後半。
  # home/shell/fish.nix の hms などの短縮入力がこれを使う。
  extraSpecialArgs.hostName = "macbook";

  modules = [
    ../home
    ../home/darwin.nix

    {
      home.username = userInfo.username;
      home.homeDirectory = "/Users/${userInfo.username}";
      # 新規に入れたマシンなので Ubuntu (25.05) に揃えず、その時点の stable にする。
      # 25.11 以降は GUI アプリが copyApps (Spotlight から起動できる) になる。
      home.stateVersion = "26.05";

      programs.git.settings.user.name = userInfo.gitName;
      programs.git.settings.user.email = userInfo.gitEmail;

      # `ghq get <repo>` と owner を省略したときの補完先。
      # home/shell/fish.nix の flakeDir もこの値から導出している。
      programs.git.settings.ghq.user = userInfo.githubUser;

      # wsl.windowsUsername は設定しない (null = WSL の中継を無効化)。
    }
  ];
}
