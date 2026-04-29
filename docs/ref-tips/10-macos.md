# 10. macOS — defaults write / Homebrew Cask 追加候補

`darwin/` 配下の強化案。macOS 専用。

## Homebrew Cask 追加候補

### - [ ] WezTerm

- **概要**: 既存設定そのまま使えるターミナル
- **メリット**: nix で wezterm config を入れるなら本体は brew 経由が安定
- **デメリット**: 既に入ってるなら不要
- **実装メモ**: `homebrew.casks = [ "wezterm" ];`

### - [ ] Ghostty

- **概要**: 軽量 GPU 加速ターミナル
- **メリット**: 高速、scrollback in vim 等の独自機能
- **デメリット**: WezTerm との二重持ち
- **実装メモ**: `homebrew.casks = [ "ghostty" ];`

### - [ ] Zed

- **概要**: 高速 collaborative エディタ
- **メリット**: 軽い、Vim mode あり
- **デメリット**: nvim/VSCode と機能重複
- **実装メモ**: `homebrew.casks = [ "zed" ];`

### - [ ] Raycast

- **概要**: Spotlight 代替ランチャ
- **メリット**: 拡張性 ◎、Snippet/Window 管理など
- **デメリット**: 学習コスト
- **実装メモ**: `homebrew.casks = [ "raycast" ];`

### - [ ] 1Password

- **概要**: パスワードマネージャ
- **メリット**: ssh-agent / git signing 統合
- **デメリット**: サブスク
- **実装メモ**: `homebrew.casks = [ "1password" "1password-cli" ];`

### - [ ] Karabiner-Elements

- **概要**: キーマッピング
- **メリット**: 07 章の TypeScript 設定と組み合わせて強力
- **デメリット**: macOS のみ
- **実装メモ**: `homebrew.casks = [ "karabiner-elements" ];`

## defaults write 系

### - [ ] `NSGlobalDomain.KeyRepeat` / `InitialKeyRepeat` 高速化

- **概要**: キーリピートを最速 (KeyRepeat=2, InitialKeyRepeat=15)
- **参照**: ryoppippi `darwin/`
- **メリット**: vim/エディタ移動が高速
- **デメリット**: 慣れないと誤入力
- **実装メモ**: `system.defaults.NSGlobalDomain.KeyRepeat = 2;`

### - [ ] `AppleShowAllExtensions = true`

- **概要**: ファイル拡張子を常に表示
- **メリット**: 拡張子偽装ファイル対策
- **デメリット**: なし
- **実装メモ**: `system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;`

### - [ ] Touch ID for sudo

- **概要**: `security.pam.enableSudoTouchIdAuth = true`
- **参照**: ryoppippi `darwin/`
- **メリット**: sudo パスワード入力不要
- **デメリット**: macOS update で消えがち（自動再有効化される）
- **実装メモ**: `darwin/` に追加

### - [ ] Dock 設定 (autohide / 位置 / サイズ)

- **概要**: `system.defaults.dock.*`
- **メリット**: 画面領域確保
- **デメリット**: 好みの問題
- **実装メモ**: `system.defaults.dock = { autohide = true; orientation = "left"; tilesize = 36; };`

### - [ ] Finder 設定 (パスバー / ステータスバー / 隠しファイル)

- **概要**: `system.defaults.finder.*`
- **メリット**: 開発者向け Finder
- **デメリット**: なし
- **実装メモ**: `system.defaults.finder = { ShowPathbar = true; ShowStatusBar = true; AppleShowAllFiles = true; };`

### - [ ] スクリーンショット保存先を `~/Pictures/Screenshots/`

- **概要**: デスクトップ汚れ防止
- **メリット**: デスクトップが綺麗
- **デメリット**: なし
- **実装メモ**: `system.defaults.screencapture.location = "~/Pictures/Screenshots";`
