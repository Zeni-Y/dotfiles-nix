# 01. Shell — fish (abbr / functions / key bindings)

主に `ref/ryoppippi-dotfiles/fish/` 由来。abbr は補完が効くので alias より優先。

## Abbr（短縮入力）

### - [ ] `git pf` = 安全 force-push

- **概要**: `git push --force-with-lease --force-if-includes` への abbr
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: rebase 後に脳死で `pf` だけ打てる。`--force` を使わず事故防止
- **デメリット**: 既存習慣との衝突
- **使い方**: `git pf<space>` でフル展開
- **実装メモ**: `home/shell/fish.nix` の `shellAbbrs`

### - [ ] `git rbm` / `git rbi` 系 rebase abbr 群

- **概要**: `rebase origin/main`, `rebase -i HEAD~N` 等の頻出 rebase
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: rebase ワークフロー高速化
- **デメリット**: 種類が多くて覚えきれない可能性
- **使い方**: `git rbm<space>`
- **実装メモ**: `home/shell/fish.nix` shellAbbrs

### - [ ] `git smu` = submodule 一括更新

- **概要**: `git submodule update --remote --init --recursive`
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: submodule 多用プロジェクトで楽
- **デメリット**: 自分が submodule 多用しないなら不要
- **実装メモ**: shellAbbrs

### - [ ] Claude 短縮 `cl` / `clo` / `clh`

- **概要**: `claude` / `claude --model opus` / `claude --model haiku`
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: モデル切替の手間削減
- **デメリット**: モデル ID は変動するので追従が必要
- **実装メモ**: `home/shell/fish.nix` shellAbbrs

### - [ ] Docker Compose 短縮 `dc/dcu/dcub/dcd/dcr`

- **概要**: `docker compose` の頻出サブコマンド一式
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: compose 中心の開発が快適
- **デメリット**: docker compose を使わないなら不要
- **実装メモ**: shellAbbrs

### - [ ] Deno 短縮 `dr` + キャッシュクリア関数

- **概要**: `deno run -A --unstable` 短縮 + cache 強制再取得
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: Deno 開発で頻出
- **デメリット**: Deno 触らないなら不要
- **実装メモ**: shellAbbrs + 関数

### - [ ] Nix abbr `ngc` / `nrn`

- **概要**: `nix-collect-garbage`、`nix run nixpkgs#<...>`（カーソル位置保持）
- **参照**: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- **メリット**: Nix 日常運用が早い
- **デメリット**: `nrn` のカーソル制御は fish 4.0+ 機能依存
- **実装メモ**: shellAbbrs / fish 関数

## Functions

### - [ ] `fkill` — fzf でプロセス選択して kill

- **概要**: `ps ax | fzf` で対話的にプロセス kill
- **参照**: `ref/ryoppippi-dotfiles/fish/functions/fkill.fish`
- **メリット**: PID 調べて kill する手間ゼロ
- **デメリット**: 誤爆リスクあり（プレビューで mitigate）
- **使い方**: `fkill` または `Ctrl+X Ctrl+K`（key binding）
- **実装メモ**: `home/shell/fish.nix` の `functions` または独立 .fish ファイル

### - [ ] `npkill` — node_modules 並列削除

- **概要**: 全ディレクトリの node_modules を `/tmp` に退避 → 並列削除
- **参照**: ryoppippi 関数群
- **メリット**: ディスク開放が高速
- **デメリット**: Node 開発以外では不要、`/tmp` 容量に注意
- **使い方**: `npkill`
- **実装メモ**: 関数

### - [ ] `gh-q` — GitHub 検索 → clone → cd

- **概要**: GitHub GraphQL でリポジトリ検索 → ghq clone → cd
- **参照**: `ref/ryoppippi-dotfiles/fish/functions/gh-q.fish`
- **メリット**: 「あれ何ていうリポジトリだっけ」を即解決
- **デメリット**: `gh` 認証 + GraphQL クエリ依存
- **使い方**: `gh-q <keyword>`
- **実装メモ**: 関数

### - [ ] `__ghq_roots` + Ctrl+G キーバインド

- **概要**: ghq 配下 root を fzf で検索 → cd
- **参照**: `ref/ryoppippi-dotfiles/fish/functions/__ghq_roots.fish`
- **メリット**: プロジェクト切替が一瞬
- **デメリット**: ghq 前提
- **使い方**: Ctrl+G
- **実装メモ**: 関数 + `fish_user_key_bindings`

### - [ ] `fish_right_prompt` 長時間コマンド通知

- **概要**: 30 秒以上のコマンドに `notify-send` (Linux) / `osascript` (mac)
- **参照**: `ref/ryoppippi-dotfiles/fish/functions/fish_right_prompt.fish`
- **メリット**: 長いビルド/テスト中に他作業可能
- **デメリット**: nvim 等は除外する判定ロジックが要メンテ
- **実装メモ**: 関数

### - [ ] `fish_user_key_bindings` 統合キーバインド

- **概要**: Ctrl+G/Ctrl+B/Ctrl+X Ctrl+K に ghq/git switch/fkill を割当
- **参照**: `ref/ryoppippi-dotfiles/fish/functions/fish_user_key_bindings.fish`
- **メリット**: 頻出操作が片手で発火
- **デメリット**: 他アプリのショートカット衝突
- **実装メモ**: 関数

## FZF 統合 env

### - [ ] FZF default = ripgrep + bat プレビュー

- **概要**: `FZF_DEFAULT_COMMAND='rg --files --hidden --follow ...'` + bat preview
- **参照**: `ref/ryoppippi-dotfiles/fish/config/fzf.fish`
- **メリット**: `.git/` を除外しつつ高速、シンタックスハイライト付きプレビュー
- **デメリット**: ripgrep / bat 必須（既に入ってる）
- **実装メモ**: `home/cli/fzf.nix` の `defaultOptions` / `fileWidgetOptions`

### - [ ] Ctrl+R で `?` プレビュートグル

- **概要**: history 検索時、`?` で長いコマンドのプレビュー表示
- **参照**: `ref/ryoppippi-dotfiles/fish/config/fzf.fish`
- **メリット**: 長い one-liner を全文確認できる
- **デメリット**: なし
- **実装メモ**: `FZF_CTRL_R_OPTS`
