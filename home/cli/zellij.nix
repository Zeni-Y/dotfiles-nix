# zellij: ターミナルマルチプレクサ。自動起動はせず、コマンド実行時のみ使う。
{ ... }:

{
  programs.zellij = {
    enable = true;
    # enableFishIntegration は意図的に false (デフォルト)。
    # シェル起動時の自動アタッチは行わず、必要なときに `zellij` を手動で叩く。
    settings = {
      default_shell = "fish";
    };
  };
}
