# ─────────────────────────────────────────────────────────────
# Home Manager のエントリポイント
#
# ここから配下のモジュールを束ねて取り込む。
# トピックごとにファイルを分けているため、必要に応じて
# このリストから外せば該当機能を丸ごと無効化できる。
# ─────────────────────────────────────────────────────────────
{ ... }:

{
  imports = [
    ./packages.nix

    ./shell
    ./editors
    ./cli

    # Claude Code。バイナリだけでなく ~/.claude/CLAUDE.md と
    # ~/.claude/rules/ (全プロジェクト共通の指示) も配るため、
    # Markdown を同居させたディレクトリモジュールにしている。
    ./claude-code

    ./git.nix
    ./herdr.nix
    ./wsl-ssh-agent.nix
    ./wezterm.nix
  ];

  programs.home-manager.enable = true;
}
