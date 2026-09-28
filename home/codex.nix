# ─────────────────────────────────────────────────────────────
# Codex CLI: OpenAI 公式のコーディングエージェント
#
# パッケージは nixpkgs の `pkgs.codex` (Rust 実装)。オーバーレイは要らない。
# 設定の配布は home-manager 標準の `programs.codex` モジュールに任せる。
#
# 全体指示 (AGENTS.md) を「連結して」配っているのは、codex が起動時に読む
# user スコープの指示が CODEX_HOME/AGENTS.md の 1 枚だけで、Claude Code の
# rules/ のようなトピック分割 (frontmatter の paths: によるスコープ) を
# 持たないため。同じ内容を 2 箇所に書くと片方が古くなるので、配布元は
# home/claude-code/ のままにして、ここでは読んで繋ぐだけにする。
# rules/nix.md を含めないのは、あれが「.nix を読んだときだけ載る」前提で
# 書かれたルールで、常時載る AGENTS.md には重いため。
#
# home/cli/ ではなくトップレベルに置いているのは home/claude-code/ と同じ理由。
# シェル統合を持つ CLI ではなく、指示ファイルを配るモジュールだから。
# ─────────────────────────────────────────────────────────────
{ lib, pkgs, ... }:

let
  # HTML コメントを落として読む。Claude Code はコンテキストに載せる前に
  # 自分で除去するのでコメントに人間向けの注記を書いてあるが、codex は
  # 除去しないのでそのまま指示として読まれてしまう (「Claude のコンテキストには
  # 載らない」と書いてあるコメントが載る、という状態になる)。
  readWithoutComments =
    path:
    let
      parts = builtins.split "<!--([^-]|-[^-]|--[^>])*-->" (builtins.readFile path);
    in
    lib.concatStrings (builtins.filter builtins.isString parts);

  # ブランチの接頭辞だけはエージェントごとに分ける。どちらが切ったブランチか
  # `git branch` で判別できるようにするため。共通ルール側は `claude/<topic>` の
  # ままにして、ここで読み替える (この 1 箇所で済むよう、元ファイルでは
  # 接頭辞を必ず `claude/<topic>` という同じ表記で書く)。
  toCodexBranch = lib.replaceStrings [ "claude/<topic>" ] [ "codex/<topic>" ];

  # 連結した結果を読むのは codex なので、元ファイル中の
  # 「詳細は ~/.claude/rules/... にある」という参照が宙に浮く。
  # それが下に繋がっていることだけ先に伝えておく。
  preamble = ''
    # 全体指示 (Codex)

    このファイルは dotfiles-nix の `home/codex.nix` が生成している。直接編集しない。

    内容は Claude Code と共通の個人設定。読むときの前提だけ先に書く。

    - 文中で `~/.claude/rules/*.md` を参照している箇所は、その内容をこのファイルの
      後半に連結してある。
    - **ブランチは `codex/<topic>`** (Claude Code は `claude/<topic>`)。以下の記述は
      Codex 向けに置換済み。
    - `claude --worktree <name>` は Claude Code 専用の機能なので使わない。worktree は
      `gwq add -b codex/<topic>` か `git worktree add` で作る。
  '';

  sharedInstructions = [
    ./claude-code/CLAUDE.md
    ./claude-code/rules/git-workflow.md
    ./claude-code/rules/git-worktree.md
  ];

  agentsMd = lib.concatStringsSep "\n" (
    [ preamble ] ++ map (path: toCodexBranch (readWithoutComments path)) sharedInstructions
  );
in
{
  # 置換漏れを評価時に落とす。共通ルール側の `claude/<topic>` という表記が変わると
  # toCodexBranch が無言で何もしなくなり、Codex に `claude/` のまま配られてしまう。
  assertions = [
    {
      assertion = lib.hasInfix "codex/<topic>" agentsMd;
      message = ''
        home/codex.nix: ブランチ接頭辞の置換が効いていません。
        home/claude-code/ 側の `claude/<topic>` という表記を確認してください。
      '';
    }
  ];

  programs.codex = {
    enable = true;
    package = pkgs.codex;

    # → ~/.codex/AGENTS.md
    context = agentsMd;

    # ── ここで宣言していないもの ──
    #
    # settings (~/.codex/config.toml): codex 自身が書き換えるファイル。
    #   TUI で選んだモデルや承認したコマンドの記憶がここに落ちるので、Nix で
    #   配ると Nix store への symlink (読み取り専用) になって書き込みが失敗する。
    #   `programs.claude-code.settings` を宣言していないのと同じ判断。
    #
    # ~/.codex/auth.json: `codex login` が書く認証情報。
    # ~/.codex/sessions/, history.jsonl: セッションログ。マシンローカルでよい。
  };
}
