# 03. Git — alias / カスタム `git-*` / git-hooks

両 dotfiles ともに git 周りの作り込みが豊富。

## Nix 化された統合 (ryoppippi)

### - [ ] `programs.git.delta.enable = true`

- **概要**: `delta` を pager に統合し diff を見やすく
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/programs/git*`
- **メリット**: side-by-side や行内 diff が見やすい
- **デメリット**: pager 描画が少し重い
- **実装メモ**: `home/git.nix` に `delta = { enable = true; options = { ... }; }`

### - [ ] Nix で git-hooks 宣言

- **概要**: commit-msg / pre-commit / pre-push を Nix から自動配置
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/git-hooks.nix`
- **メリット**: husky 不要、再現性 ◎、リポジトリ横断適用も可
- **デメリット**: per-repo の hooks と衝突するので設計要
- **実装メモ**: 同名ファイルを `home/` 配下に移植 → `imports`

### - [ ] `bit` (git ラッパー) 導入

- **概要**: 対話的な git ラッパー
- **参照**: ryoppippi `home.packages`
- **メリット**: ブランチ操作が直感的
- **デメリット**: 標準 git の挙動と微妙に違う点を覚える必要
- **実装メモ**: `home/packages.nix`

### - [ ] `git-now` / `git-wt` (worktree 管理)

- **概要**: `git now`（即コミット）、`git wt`（worktree CLI）
- **参照**: ryoppippi `home.packages`
- **メリット**: worktree ワークフロー支援
- **デメリット**: 標準 `git worktree` でも事足りる
- **実装メモ**: `home/packages.nix`

## kawarimidoll の `bin/git-*` カスタムサブコマンド

`PATH` に `bin/` が通っていれば `git foo` として呼べる仕組み。

### - [ ] `git quicksave` — stage+commit+push 1 発

- **概要**: タイムスタンプ付き quicksave commit
- **参照**: `ref/kawarimidoll-dotfiles/bin/git-__quicksave`
- **メリット**: WIP をリモートに即避難
- **デメリット**: 履歴が汚れるので feature ブランチ専用想定
- **使い方**: `git quicksave`
- **実装メモ**: `home/packages.nix` で `pkgs.writeShellApplication`、または `home.file` で配布

### - [ ] `git remember` — fzf でログ選択 → hash 抽出

- **概要**: 過去コミットを fzf プレビュー付きで検索し hash を出力
- **参照**: `ref/kawarimidoll-dotfiles/bin/git-__remember`
- **メリット**: cherry-pick / fixup 元の特定が爆速
- **デメリット**: なし
- **使い方**: `git remember | xargs git cherry-pick`
- **実装メモ**: writeShellApplication

### - [ ] `git abort` — 状態自動判定 abort

- **概要**: rebase/merge/cherry-pick/revert/bisect を判定して `--abort`
- **参照**: `ref/kawarimidoll-dotfiles/bin/git-__abort`
- **メリット**: 「今何 abort すればいいか」を考えなくていい
- **デメリット**: なし
- **使い方**: `git abort`
- **実装メモ**: writeShellApplication

### - [ ] `git push-with-check` — WIP 防御

- **概要**: ブランチ名/コミットメッセージに `wip` があれば push 禁止
- **参照**: `ref/kawarimidoll-dotfiles/bin/git-__push-with-check`
- **メリット**: うっかり WIP を push する事故防止
- **デメリット**: 既存ワークフロー（あえて WIP push）と衝突
- **実装メモ**: writeShellApplication、`git push` の abbr で置換も可

### - [ ] `wta` — worktree add ラッパー

- **概要**: `git worktree add` 後に `.env` / `.claude` を自動シンボリックリンク
- **参照**: `ref/kawarimidoll-dotfiles/bin/wta`
- **メリット**: worktree 切替時に毎回 env を作る手間ゼロ
- **デメリット**: シンボリックリンク対象が固定（要カスタマイズ）
- **使い方**: `wta <branch>`
- **実装メモ**: writeShellApplication

### - [ ] `wtb` / `wtd` — worktree branch 削除 / worktree 削除

- **概要**: 削除系の安全なラッパー
- **参照**: `ref/kawarimidoll-dotfiles/bin/wtb`, `wtd`
- **メリット**: `git worktree remove` 失敗パターン回避
- **実装メモ**: writeShellApplication

## ツール追加

### - [ ] `lazygit`

- **概要**: TUI git クライアント
- **参照**: ryoppippi `home.packages` / 既に packages.nix にある可能性
- **メリット**: スタッシュ・ブランチ・diff 操作が圧倒的に速い
- **デメリット**: TUI 特有の学習コスト
- **実装メモ**: `home/cli/lazygit.nix` 新設 or `home/packages.nix` に追加
