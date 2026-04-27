# ─────────────────────────────────────────────────────────────
# Homebrew (macOS 専用)
#
# - nix-homebrew : Homebrew 本体を nix-darwin の activation で
#                  自動インストール / 更新する。
# - homebrew     : nix-darwin 標準モジュール。Cask / formula を
#                  宣言的に維持する。
#
# これにより `sudo nix run nix-darwin -- switch --flake .#<host>`
# 一発で Homebrew 自体のセットアップから Cask 適用までが完了する。
# ─────────────────────────────────────────────────────────────
{ inputs, userInfo, ... }:

{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  # Homebrew 本体のブートストラップ。
  # 既に手動で /opt/homebrew や /usr/local が存在する場合でも
  # autoMigrate = true で nix-homebrew の管理下に取り込む。
  nix-homebrew = {
    enable = true;
    user = userInfo.username;
    enableRosetta = true;   # Apple Silicon で x86_64 brew も使えるようにする
    autoMigrate = true;
  };

  homebrew = {
    enable = true;

    # darwin-rebuild のたびに `brew bundle --cleanup` 相当を実行し、
    # ここに書いていないものを削除する。安全側に倒すなら "check" にする。
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # 公式以外の tap
    taps = [ ];

    # CLI ツール (本来 nixpkgs にあるものは Nix 側に置くのが望ましい。
    # ここには「Homebrew でしか入手できない」「macOS 固有」のものだけ書く)
    brews = [
      "mas"  # Mac App Store CLI
    ];

    # GUI アプリ
    casks = [
      "wezterm"
      "zed"
      "raycast"
      "rectangle"
      "1password"
      "google-chrome"
      "slack"
      "visual-studio-code"
      "docker"
      "obsidian"
    ];

    # Mac App Store
    masApps = {
      # "Xcode" = 497799835;
    };
  };
}
