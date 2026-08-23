<!--
  ~/.claude/CLAUDE.md (user スコープ / 全プロジェクト共通)

  実体は dotfiles-nix の home/claude-code/CLAUDE.md。~/.claude/CLAUDE.md は
  Nix store への symlink なので直接編集できない。直すのはリポジトリ側。
  この HTML コメントは Claude のコンテキストに載る前に除去される。
-->

# 個人設定 (全プロジェクト共通)

プロジェクト固有のことは各リポジトリの `CLAUDE.md` に書いてある。競合したらそちらが優先。

## 応答

- **日本語で答える。** コミットメッセージ・PR・コード内コメント・ドキュメントも日本語。
- 結論を先に書く。前置き・謝辞・自己評価は書かない。
- 確認していないことは「未確認」と明示する。動かしていないコードを「動く」と書かない。

## 作業の進め方

- 複数セッションを並行させるので、**ファイルを編集する作業は git worktree を切ってから始める**
  (→ `~/.claude/rules/git-worktree.md`)。読むだけ・調べるだけなら不要。
- 1 トピック 1 ブランチ。頼まれていないファイルをついでに直さない。
- **環境全体に効く操作は自分で実行しない。** パッケージの本適用、`sudo` を伴うもの、
  常駐サービスの再起動など。コマンドを提示して人間に任せる。
- 破壊的な操作 (`rm -rf` / force push / ブランチ削除 / リモートへの反映) は、
  実行前に対象を `ls` や `git status` で確認する。

## Git

詳細は `~/.claude/rules/git-workflow.md`。要点だけ:

- `main` に直接コミット・直接 push しない。ブランチは `claude/<topic>`。
- コミットメッセージは日本語 + Conventional Commits。本文には**なぜそうしたか**を書く。
- **「push&merge」= commit → push → PR 作成 → merge → ブランチ削除まで一続き**。途中で確認を挟まない。
- **「commit&push」= push で止める**。PR を作るかは一言添える。

## 道具

- リポジトリ移動は `dev` (ghq + fzf)、worktree は `gwq`。clone も worktree も `~/ghq` 配下。
- GitHub の操作は `gh` CLI。ブラウザ前提の手順を書かない。
- 検索は `rg` / `fd`。`grep -r` / `find` は使わない。
- 対話シェルは **fish**。`&&` `||` `$()` は使えない (`; and` / `; or` / `()`)。
  シェルスクリプトを書くときは `#!/usr/bin/env bash` と明示する。
- エディタは Neovim (LazyVim)、ターミナルマルチプレクサは herdr。

## 書きもの

- コメントは「なぜ」を書く。何をしているかだけのコメントは足さない。
- ドキュメントを追加したら、索引 (README や `docs/README.md`) にも行を足す。
- **秘密情報 (トークン / 鍵 / パスワード) をファイルにもコミットにも書かない。**
  設定に必要なら環境変数か外部の credential helper 経由にする。
- 環境変数で秘密を渡すときは **1Password + direnv** を使う。値は書かず、
  `.env.op` に `KEY=op://Vault/Item/field` の参照だけを置いて `.envrc` に `use op`
  と書く (`.env.op` と `.envrc` はコミットしてよい。平文の `.env` は作らない)。
  1 コマンドだけなら `op run --env-file=.env.op -- <cmd>`。

## 覚えさせたいことの置き場所

| 内容 | 置き場所 | 実体 |
| --- | --- | --- |
| 全プロジェクト共通のルール | `~/.claude/CLAUDE.md` | dotfiles-nix `home/claude-code/CLAUDE.md` |
| 共通ルールのうちトピックが立つもの | `~/.claude/rules/*.md` | dotfiles-nix `home/claude-code/rules/` |
| そのリポジトリ固有のルール | `<repo>/CLAUDE.md` `<repo>/.claude/rules/*.md` | リポジトリにコミット |
| Claude 自身が学んだこと | auto memory (`~/.claude/projects/<project>/memory/`) | Nix 管理外・マシンローカル |

「これは他のプロジェクトでも要るな」と思ったルールは、リポジトリの `CLAUDE.md` ではなく
dotfiles-nix の `home/claude-code/` に足す (反映は `home-manager switch`。人間が実行する)。
