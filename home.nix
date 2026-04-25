{ pkgs, ... }:

{
  home.username = "yourname";          # 実際のユーザー名に変更
  home.homeDirectory = "/home/yourname";  # Macの場合は /Users/yourname

  home.stateVersion = "25.05";

  # ─────────────────────────────────────────
  # インストールするパッケージ
  # ─────────────────────────────────────────
  home.packages = with pkgs; [
    ripgrep  # 高速なgrep代替 (rg)
    fd       # 高速なfind代替
    bat      # シンタックスハイライト付きcat代替
    eza      # アイコン・色付きls代替
    curl
    jq       # JSONクエリツール
    htop     # プロセスモニター
  ];

  # ─────────────────────────────────────────
  # Gitの設定
  # ─────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "you@example.com";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # ─────────────────────────────────────────
  # Bashシェルの設定
  # ─────────────────────────────────────────
  programs.bash = {
    enable = true;
    initExtra = ''
      alias ls='eza --icons'
      alias ll='eza -la --icons'
      alias cat='bat'
    '';
  };

  programs.home-manager.enable = true;
}
