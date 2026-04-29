# 08. Nix Tooling — overlays / git-hooks.nix / agent-skills-nix

`ref/ryoppippi-dotfiles/nix/modules/` 由来。Nix エコシステム強化案。

### - [ ] `overlays/` で AI ツールをカスタムビルド

- **概要**: claude-code, codex, cursor-agent, opencode 等を nixpkgs に存在しなくても入れる
- **参照**: `ref/ryoppippi-dotfiles/nix/overlays/`
- **メリット**: AI ツール群を Nix で版固定、複数マシンで同期
- **デメリット**: overlay 保守の手間、上流リリース追従が必要
- **実装メモ**: `overlays/` 新設し `flake.nix` で読込

### - [ ] `git-hooks.nix` モジュール

- **概要**: commit-msg / pre-commit / pre-push を Nix から自動配置
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/git-hooks.nix`
- **メリット**: husky 不要、再現性 ◎
- **デメリット**: per-repo hooks との衝突調整
- **実装メモ**: `home/git-hooks.nix` として移植

### - [ ] `agent-skills-nix` パターン

- **概要**: 任意ファイル群を `~/.config/<dir>/` に展開する汎用モジュール
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/programs/agent-skills*`
- **メリット**: skill / agent / prompt ファイル群を Nix で版固定
- **デメリット**: 中身編集 → リビルドのサイクルに慣れが必要
- **実装メモ**: `home/claude.nix` 系の基盤として導入

### - [ ] `programs.direnv.nix-direnv.enable` 強化

- **概要**: nix-direnv による高速 flake シェル
- **メリット**: プロジェクト毎の env 切替が一瞬
- **デメリット**: 既に有効ならスキップ
- **実装メモ**: `home/cli/direnv.nix` を確認

### - [ ] `comma` (`,`) 導入

- **概要**: nix パッケージをインストールせず一時実行 (`, htop` で htop 起動)
- **参照**: ryoppippi `home.packages`
- **メリット**: 一度しか使わないツールを汚さず実行
- **デメリット**: 初回キャッシュ取得が遅い
- **実装メモ**: `home/packages.nix`

### - [ ] `devenv` 導入

- **概要**: プロジェクト別シェル環境（Nix シェルの上位）
- **参照**: ryoppippi
- **メリット**: 言語ランタイム切替が宣言的、services 起動も統合
- **デメリット**: flake-only 派には冗長
- **実装メモ**: `home/packages.nix`、各プロジェクトの `devenv.nix`

### - [ ] `nix run .#switch` 系のショートカット justfile / Makefile

- **概要**: `darwin-rebuild switch --flake .` 等の長いコマンドを 1 単語に
- **参照**: ryoppippi `flake.nix` apps
- **メリット**: タイプ量削減
- **デメリット**: 既存 `scripts/setup.sh` と棲み分け要
- **実装メモ**: `flake.nix` の `apps` セクション追加
