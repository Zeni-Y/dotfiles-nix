# Claude Code: Anthropic 公式 CLI (AI コーディングエージェント)
#
# パッケージは nix-claude-code オーバーレイが提供する公式プリビルドバイナリ
# (`pkgs.claude-code`) を使用する。設定ファイル/エージェント/コマンド/フック
# などの管理は home-manager 標準の `programs.claude-code` モジュールに任せる。
{ pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
  };
}
