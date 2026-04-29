# 09. CLI Tools (delta, bit, comma, lazygit, dust 他)

`home/packages.nix` / `home/cli/` 配下に追加する候補。

## 単発ツール

### - [ ] `delta` — git diff を見やすく

- **概要**: side-by-side / 行内 diff / シンタックスハイライト
- **参照**: ryoppippi
- **メリット**: コードレビューの可読性が大幅向上
- **デメリット**: pager 描画がやや重い
- **実装メモ**: `home/git.nix` に `delta = { enable = true; }`

### - [ ] `dust` — `du` の見やすい版

- **概要**: ディスク使用量をグラフィカル表示
- **参照**: ryoppippi
- **メリット**: 容量食い犯の特定が速い
- **デメリット**: なし
- **実装メモ**: `home/packages.nix`

### - [ ] `trash-cli` — `rm` 代替

- **概要**: ゴミ箱に送る `trash` コマンド
- **参照**: ryoppippi
- **メリット**: 誤削除リカバリ可能
- **デメリット**: ゴミ箱の自動掃除が必要
- **実装メモ**: `home/packages.nix`、fish abbr で `rm` を `trash` に置換も検討

### - [ ] `bit` — git ラッパー

- **概要**: 対話的な git
- **参照**: ryoppippi
- **メリット**: ブランチ操作が直感的
- **デメリット**: 標準 git と挙動差
- **実装メモ**: `home/packages.nix`

### - [ ] `comma` (`,`)

- **概要**: nix から一時的にコマンド実行
- **参照**: ryoppippi
- **メリット**: 環境を汚さない
- **デメリット**: 初回が遅い
- **実装メモ**: `home/packages.nix`（08 と重複）

### - [ ] `lazygit`

- **概要**: TUI git
- **参照**: ryoppippi
- **メリット**: 操作が圧倒的に速い
- **デメリット**: TUI 学習コスト
- **実装メモ**: `home/cli/lazygit.nix` 新設

### - [ ] `git-lfs`

- **概要**: 大容量ファイル管理
- **参照**: ryoppippi
- **メリット**: 画像/動画リポジトリで必須
- **デメリット**: 使わないなら不要
- **実装メモ**: `home/packages.nix`

## 既存ツール強化案

### - [ ] fzf × ripgrep × bat 統合 env を fish に注入

- **概要**: `FZF_DEFAULT_COMMAND` `FZF_*_OPTS` を統一設定
- **参照**: `ref/ryoppippi-dotfiles/fish/config/fzf.fish`
- **メリット**: どのキーバインド経由でも統一されたプレビュー
- **デメリット**: なし
- **実装メモ**: `home/cli/fzf.nix` の `defaultOptions` 等

### - [ ] `eza` の icons / git-status 設定見直し

- **概要**: `--icons --git --group-directories-first` 等を既定化
- **参照**: 両 dotfiles
- **メリット**: ls の情報量が増える
- **デメリット**: nerd font 必須
- **実装メモ**: `home/cli/eza.nix`

### - [ ] `bat` テーマ・style 既定値見直し

- **概要**: テーマ統一 + `--style=numbers,changes` 等
- **参照**: 両 dotfiles
- **メリット**: cat 出力が常時シンタックスハイライト
- **デメリット**: なし
- **実装メモ**: `home/cli/bat.nix`
