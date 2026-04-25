# ─────────────────────────────────────────────────────────────
# Homebrew (macOS 専用)
#
# nix-darwin の Homebrew モジュールは brew コマンドを呼び出す
# 薄いラッパーで、宣言的に Cask / formula を維持できる。
#
# 前提: 事前に Homebrew 本体を入れておく必要がある
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# ─────────────────────────────────────────────────────────────
{ ... }:

{
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
