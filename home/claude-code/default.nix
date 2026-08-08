# ─────────────────────────────────────────────────────────────
# Claude Code: Anthropic 公式 CLI (AI コーディングエージェント)
#
# パッケージは nix-claude-code オーバーレイが提供する公式プリビルドバイナリ
# (`pkgs.claude-code`)。設定の配布は home-manager 標準の
# `programs.claude-code` モジュールに任せる。
#
# ここで配るのは **全プロジェクト共通 (user スコープ) の指示だけ**。
# リポジトリ固有の指示は各リポジトリの CLAUDE.md / .claude/rules/ に置く。
# 階層と使い分けは docs/claude-code.md を参照。
#
# home/cli/ ではなくトップレベルに置いているのは、シェル統合を持つ CLI
# ではなく「設定ツリー (Markdown) を配るモジュール」だから
# (home/editors/ と同じ扱い)。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # ~/.claude/CLAUDE.md
    # 全プロジェクトの全セッションで、プロジェクトの CLAUDE.md より先に読まれる。
    # 公式の目安は 1 ファイル 200 行未満 (長いと追従率が落ちる) なので、
    # トピックが立つものは下の rules/ に切り出す。
    context = ./CLAUDE.md;

    # ~/.claude/rules/*.md
    # user スコープの rules は CLAUDE.md と同じく毎セッション読まれる。
    # ただし frontmatter に `paths:` を書いたものは、該当するファイルを
    # 実際に読んだときだけ載る (rules/nix.md がその例)。
    #
    # `rules = { <名前> = <内容>; }` ではなく rulesDir にしているのは、
    # ルールを 1 本足すたびにこの .nix を編集しなくて済むようにするため。
    # ディレクトリごと symlink されるだけなので追加は Markdown を置いて
    # `git add` するだけで済む (flake は git 管理下のファイルしか見ない)。
    rulesDir = ./rules;

    # ── ここで宣言していないもの ──
    #
    # settings: ~/.claude/settings.json は Claude Code 自身が /config や
    #   ログイン、`/memory` のトグルで書き換えるファイル。Nix で配ると
    #   Nix store への symlink (読み取り専用) になり、CLI 側の書き込みが
    #   失敗するので管理しない。恒久的に固定したい項目が出てきたら
    #   `settings` に足すこともできるが、その項目は CLI から変更できなくなる。
    #
    # auto memory (~/.claude/projects/<project>/memory/): Claude 自身が
    #   セッション中に書くファイル群。同じ理由で管理外。
    #
    # agents / commands / hooks / skills: 必要になったら
    #   programs.claude-code.{agents,commands,hooks,skills} で同様に配れる。
  };
}
