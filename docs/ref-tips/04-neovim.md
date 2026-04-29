# 04. Neovim — keymap / mini.nvim / プラグイン管理

現状 `home/editors/neovim.nix` は本体を入れる最小構成。本格構成化の参考。

## キーマップ (ryoppippi)

### - [ ] `0` の挙動を文脈依存に

- **概要**: 行頭が空白だけなら `0`、それ以外は `^`
- **参照**: `ref/ryoppippi-dotfiles/nvim/lua/config/keymaps.lua`
- **メリット**: 「インデント先頭 vs 物理先頭」を脳死で切替
- **デメリット**: vim 標準と違うので別 PC で混乱
- **実装メモ**: `~/.config/nvim/lua/...` に直書き or `programs.neovim.extraLuaConfig`

### - [ ] `i`/`A` を空行で `cc` に

- **概要**: 空行で `i` 押すとインデントが付かない問題を解決
- **参照**: 同上
- **メリット**: 空行から書き始める時にインデント自動
- **デメリット**: なし
- **実装メモ**: extraLuaConfig

### - [ ] `j`/`k` 大ジャンプを jumplist 記録

- **概要**: `5j` 等で `m'5j` 相当 → `''` で戻れる
- **参照**: 同上
- **メリット**: 大移動後の戻りが楽
- **デメリット**: なし
- **実装メモ**: extraLuaConfig

### - [ ] タブ操作 `<Tab>` / `<S-Tab>` / `th tj tk tl`

- **概要**: タブの次/前/端 移動を統一
- **参照**: 同上
- **メリット**: タブ運用が直感的
- **デメリット**: バッファ運用派には不要
- **実装メモ**: extraLuaConfig

### - [ ] `:` と `;` の入れ替え

- **概要**: コマンドモードを `;` で起動（Shift 不要）
- **参照**: 同上
- **メリット**: コマンド入力が楽
- **デメリット**: f/F/t/T の繰り返し `;` を犠牲に
- **実装メモ**: extraLuaConfig

## 構成 (kawarimidoll, mini.nvim 派 — 軽量参考)

### - [ ] `vim.loader.enable()` 起動高速化

- **概要**: Lua バイトコードキャッシュ
- **参照**: `ref/kawarimidoll-dotfiles/.config/nvim/init.lua:2`
- **メリット**: 起動が体感で速くなる
- **デメリット**: なし
- **実装メモ**: init.lua 冒頭

### - [ ] `mini.deps` で外部プラグインマネージャ不要

- **概要**: lazy.nvim/packer 等を入れずに mini.deps だけで管理
- **参照**: 同上
- **メリット**: 依存最小、シンプル
- **デメリット**: 大規模構成では機能不足の可能性
- **実装メモ**: init.lua

### - [ ] `mini.pick` / `mini.files` / `mini.cmdline`

- **概要**: telescope/nvim-tree/noice 相当を mini で
- **参照**: kawarimidoll init.lua
- **メリット**: 軽量・統一感
- **デメリット**: telescope 拡張プラグインは使えない
- **実装メモ**: init.lua

### - [ ] `XDG_STATE_HOME=/tmp` で undodir 一時化

- **概要**: undo 履歴を永続化しない設計
- **参照**: 同上
- **メリット**: 履歴ファイルが溜まらない
- **デメリット**: 過去 undo を失う（人による）
- **実装メモ**: init.lua / 環境変数

### - [ ] `<space>/` で ripgrep grep

- **概要**: `:Grep` カスタムコマンド + キーマップ
- **参照**: 同上
- **メリット**: live-grep が即起動
- **デメリット**: なし
- **実装メモ**: extraLuaConfig + ripgrep 必須

## 構成方針

### - [ ] 方針 A: 本体 + LSP/treesitter のみ Nix 化

- **概要**: 設定 (init.lua/Lua プラグイン) は `~/.config/nvim/` に直書き
- **メリット**: nvim プラグイン更新が高速、Nix リビルド不要
- **デメリット**: マシン間の再現性は git だけに依存
- **実装メモ**: 現状維持寄り。LSP サーバ群を `home.packages` に追加

### - [ ] 方針 B: `programs.neovim.plugins` で全プラグイン Nix 化

- **概要**: lazy.nvim 廃止、プラグインは Nix で固定
- **メリット**: flake.lock で完全再現、ロールバック可能
- **デメリット**: 起動時間微増、最新プラグイン追従が遅め
- **実装メモ**: `home/editors/neovim.nix` に `plugins = with pkgs.vimPlugins; [...]`
