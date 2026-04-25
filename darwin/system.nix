# ─────────────────────────────────────────────────────────────
# macOS のシステム設定
#
# `defaults write` 相当を nix-darwin の宣言で書く。
# 反映には `darwin-rebuild switch` 後に再ログインが必要な項目もある。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  # Nix の experimental features を有効化 (flakes & nix command)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # nix-darwin が touch する /etc/zshrc 等のためにシェル候補を登録
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # 必須レベルの最小システムパッケージ
  environment.systemPackages = with pkgs; [
    coreutils
    git
  ];

  # システム設定 (defaults write 相当)
  system.defaults = {
    # Dock
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 48;
      orientation = "bottom";
      mru-spaces = false;     # スペースを使用順に並べ替えない
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";  # リスト表示
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
    };

    # キーボード
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;  # キーリピートを有効化
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    # スクリーンショット保存先
    screencapture.location = "~/Pictures/Screenshots";

    # トラックパッド
    trackpad = {
      Clicking = true;             # タップでクリック
      TrackpadThreeFingerDrag = true;
    };
  };

  # nix-darwin が要求する state version
  system.stateVersion = 6;
}
