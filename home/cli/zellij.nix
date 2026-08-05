# zellij: ターミナルマルチプレクサ。自動起動はせず、コマンド実行時のみ使う。
{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    # enableFishIntegration は意図的に false (デフォルト)。
    # シェル起動時の自動アタッチは行わず、必要なときに `zellij` を手動で叩く。
    settings = {
      # "fish" と書くと PATH 上の fish (apt 版の /usr/bin/fish など) が
      # 使われてしまうので、Home Manager 管理の fish を絶対パスで指定する。
      default_shell = "${pkgs.fish}/bin/fish";
    };
  };
}
