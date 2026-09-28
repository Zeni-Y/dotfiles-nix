# Codex CLI — 導入・認証・AGENTS.md の配り方

OpenAI の [Codex CLI](https://github.com/openai/codex) をこのリポジトリからどう入れ、
全体指示 (`~/.codex/AGENTS.md`) をどう配っているかをまとめた資料です。
Claude Code 側の考え方は [claude-code.md](../claude-code/claude-code.md) にあります。

---

## 目次

1. [何を入れているか](#1-何を入れているか)
2. [認証](#2-認証)
3. [指示ファイルの階層](#3-指示ファイルの階層)
4. [このリポジトリでの配り方](#4-このリポジトリでの配り方)
5. [Nix で管理しないもの](#5-nix-で管理しないもの)
6. [ハマりどころ](#6-ハマりどころ)

---

## 1. 何を入れているか

`home/codex.nix` の 1 モジュールだけです。

```nix
programs.codex = {
  enable = true;
  package = pkgs.codex;   # nixpkgs の Rust 実装。オーバーレイは不要
  context = /* 後述の連結した文字列 */;   # → ~/.codex/AGENTS.md
};
```

Claude Code は公式バイナリを入れるために `nix-claude-code` オーバーレイを足していますが、
Codex は nixpkgs 本体に `codex` があるので入力は増えません
(pinned な nixpkgs では 0.153.4。`nix flake update nixpkgs` で上がります)。

`codex` のほかに `codex-code-mode-host` と `logs_client` も PATH に入ります (0.153.4 で確認済み)。
名前が一般的すぎるので、他のツールと衝突していないか気になったら `which logs_client` で確認します。

主なサブコマンドは次のとおりです (`codex --help` の抜粋)。

| コマンド | 用途 |
| --- | --- |
| `codex` | 対話 TUI を起動。`codex "<prompt>"` で最初の指示を渡せる |
| `codex exec "<prompt>"` | 非対話実行 (CI やスクリプト向け) |
| `codex resume` / `codex fork` | 過去セッションの再開・分岐 |
| `codex review` | 変更のレビューを非対話で回す |
| `codex doctor` | インストール・config・認証の健康診断 |
| `codex login` / `logout` | 認証 (→ [2 章](#2-認証)) |

承認とサンドボックスは起動時に選べます。

```bash
codex -s read-only            # サンドボックス: read-only / workspace-write / danger-full-access
codex -a on-request           # 承認: untrusted / on-request / never
codex -m <model>              # モデルを一時的に変える
codex -c model_reasoning_effort=high   # config.toml の値を 1 回だけ上書き
```

## 2. 認証

Codex の認証情報は `~/.codex/auth.json` に保存されます。**Nix では配りません**
(→ [5 章](#5-nix-で管理しないもの))。switch 後に 1 回だけ実行します。

```bash
codex login          # ChatGPT アカウントでブラウザ認証
codex login status   # 現在の認証状態
codex logout
```

ブラウザを開けないリモートホストでは `codex login --device-auth` があります (未確認)。
WSL2 は Windows 側のブラウザが開くので通常の `codex login` で足ります (未確認)。

API キーで入る場合は **stdin 経由**です。引数に書くと履歴に残るので使いません。

```bash
op read "op://Private/OpenAI/credential" | codex login --with-api-key
```

`op` は 1Password CLI です (→ [1password-direnv.md](../secrets/1password-direnv.md))。
`OPENAI_API_KEY` を `.env` に平文で置く運用はしません。

## 3. 指示ファイルの階層

Codex が読む指示は `AGENTS.md` という 1 種類だけで、**広いスコープから狭いスコープへ**
重ねて読まれます。

| スコープ | 場所 | 用途 |
| --- | --- | --- |
| **User** | `$CODEX_HOME/AGENTS.md` (既定 `~/.codex/AGENTS.md`) | **全プロジェクト共通の個人ルール** |
| Project | `<repo>/AGENTS.md` | そのリポジトリ固有。git で共有 |
| サブディレクトリ | `<dir>/AGENTS.md` | そのディレクトリを触るときだけ |

Claude Code との違いは 2 点です。

- **`rules/` に相当する仕組みが無い。** frontmatter の `paths:` で「該当ファイルを
  読んだときだけ載せる」ような分割ができません。user スコープは 1 枚に収める必要があります。
- **HTML コメントが除去されない。** Claude Code はコンテキストに載せる前に
  `<!-- ... -->` を落としますが、Codex はそのまま読みます。

なお `$CODEX_HOME/AGENTS.override.md` を置くと同じディレクトリの `AGENTS.md` より
優先されます (home-manager の `programs.codex.contextOverride`)。一時的に共通ルールを
外したいときの逃げ道ですが、このリポジトリでは使っていません。

## 4. このリポジトリでの配り方

**配布元は `home/claude-code/` のままにして、`home/codex.nix` が読んで連結します。**
共通ルールを 2 箇所に書くと必ず片方が古くなるためです。

```
home/claude-code/CLAUDE.md            ─┐
home/claude-code/rules/git-workflow.md ├─ 連結 ─→ ~/.codex/AGENTS.md (166 行)
home/claude-code/rules/git-worktree.md ─┘
                                    ─→ ~/.claude/CLAUDE.md + ~/.claude/rules/
```

```nix
# home/codex.nix (抜粋)
context = lib.concatStringsSep "\n" (
  [ preamble ] ++ map (path: toCodexBranch (readWithoutComments path)) [
    ./claude-code/CLAUDE.md
    ./claude-code/rules/git-workflow.md
    ./claude-code/rules/git-worktree.md
  ]
);
```

- `readWithoutComments` は `builtins.split` で HTML コメントを落とします。
  人間向けの注記 (「実体は dotfiles-nix にある」など) を Codex に指示として
  読ませないためです ([3 章](#3-指示ファイルの階層))。
- `toCodexBranch` はブランチの接頭辞を `claude/<topic>` → `codex/<topic>` に読み替えます
  (`lib.replaceStrings`)。どちらのエージェントが切ったブランチか `git branch` で
  分かるようにするためです。置換は 1 箇所で済ませたいので、**共通ルール側では接頭辞を
  必ず `claude/<topic>` という同じ表記で書きます**。
- `preamble` は「このファイルは生成物」「`~/.claude/rules/*.md` への参照は後半に連結済み」
  「ブランチは `codex/<topic>`」「`claude --worktree` は使わない」の 4 点を先に書いています。
  連結すると元ファイル中の参照が宙に浮くためと、Claude Code 専用の逃げ道が
  そのまま残るためです。
- 置換漏れは `assertions` で評価時に落とします (`nix flake check` で気付ける)。
  `claude/<topic>` の表記が変わって `toCodexBranch` が無言で何もしなくなる事故を防ぐためです
  (壊して確認済み)。
- **`rules/nix.md` は入れていません。** あれは `paths:` 付きで「`.nix` を読んだときだけ
  載る」前提のルールなので、常時載る AGENTS.md には重すぎます。`.nix` を Codex に
  触らせたいリポジトリでは、そのリポジトリ側の `AGENTS.md` に書きます。

共通ルールを足す・直す手順は Claude Code 側と同じです
(→ [claude-code.md 5 章](../claude-code/claude-code.md#5-ルールを足す直す手順))。
`home/claude-code/` を編集して `git add` → `home-manager switch` すると、
`~/.claude/` と `~/.codex/AGENTS.md` の両方が同時に更新されます。

## 5. Nix で管理しないもの

**「ツール自身が書き込むファイルは Nix で配らない」**という原則は Claude Code と同じです。

| 対象 | 理由 |
| --- | --- |
| `~/.codex/config.toml` | TUI で選んだモデルや承認したコマンドの記憶が落ちる。Nix で配ると読み取り専用の symlink になって書き込みが失敗する |
| `~/.codex/auth.json` | `codex login` が書く認証情報 |
| `~/.codex/sessions/`, `history.jsonl` | セッションログ。マシンローカルで良い |

`config.toml` を宣言しないので、モデルや `sandbox_mode` の既定は Codex 本体の
既定値のままです。固定したくなったら `programs.codex.settings` に書けますが、
その項目は TUI から変更できなくなります。

一時的に変えたいだけなら `codex -c <key>=<value>` か、`programs.codex.profiles` で
`~/.codex/<name>.config.toml` を配って `codex --profile <name>` で選ぶ手もあります
(profiles は Nix 管理でも衝突しません。未使用)。

## 6. ハマりどころ

- **`codex update` は使わない。** バイナリは Nix store にあり書き込めません。
  上げるのは `nix flake update nixpkgs` (abbr: `nfu`) → `home-manager switch`。
- **`~/.codex/AGENTS.md` は Nix store への symlink なので直接編集できない。**
  直すのは `home/claude-code/` 側です。その場限りの指示はリポジトリの `AGENTS.md` に書きます。
- **switch 前に実ファイルの `~/.codex/AGENTS.md` があると
  `Existing file ... would be clobbered` で止まる。**
  中身を `home/claude-code/` に取り込んでから元を消します
  (→ [nix-concepts.md 7 章](../nix/nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む))。
- **ブランチの接頭辞は `codex/<topic>`** です (Claude Code は `claude/<topic>`)。
  共通ルール側の表記は `claude/<topic>` のままで、`home/codex.nix` が置換しています。
  共通ルールに新しくブランチ名を書くときは、この表記を崩さないでください
  (崩すと置換から漏れて `claude/` のまま Codex に配られます)。
- **Claude Code と同じ worktree で同時に走らせない。** 片方の編集がもう片方の前提を壊します
  (→ [git-worktree.md](../git/git-worktree.md))。

---

## 関連ドキュメント

- [claude-code.md](../claude-code/claude-code.md) — 指示ファイルの階層と書き方の指針 (共通の考え方はこちら)
- [1password-direnv.md](../secrets/1password-direnv.md) — API キーを平文で置かずに渡す
- [git-worktree.md](../git/git-worktree.md) — 並列エージェント運用と worktree のライフサイクル
- 一次情報: <https://developers.openai.com/codex/config-reference> /
  home-manager の `programs.codex` オプション
