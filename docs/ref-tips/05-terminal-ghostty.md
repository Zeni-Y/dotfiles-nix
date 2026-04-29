# 05. Terminal — Ghostty (宣言的設定 / scrollback in vim)

現状は WezTerm のみ。Ghostty を追加 or 移行する候補。

### - [ ] `programs.ghostty` の宣言的設定 (home-manager)

- **概要**: ghostty の設定を Nix から書き出し
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/programs/ghostty*`
- **メリット**: 他端末アプリと同じく Nix 一元管理
- **デメリット**: home-manager の `programs.ghostty` モジュール対応バージョン要確認
- **実装メモ**: `home/ghostty.nix` 新設

### - [ ] Ghostty インストール (macOS)

- **概要**: `homebrew.casks = [ "ghostty" ]`
- **参照**: ryoppippi `darwin/`
- **メリット**: 軽量・Metal accelerated
- **デメリット**: WezTerm から移行するか併存するか要決定
- **実装メモ**: `darwin/` Homebrew 設定

### - [ ] Scrollback を vim で編集 (`super+shift+a`)

- **概要**: terminal スクロールバックをファイル化 → vim ターミナルで開く
- **参照**: `ref/kawarimidoll-dotfiles/.config/ghostty/config:49-51`
- **メリット**: ターミナル出力をそのまま編集・保存・grep 可
- **デメリット**: vim 必須、Ghostty 専用機能
- **使い方**: `Cmd+Shift+A`
- **実装メモ**: `keybind = super+shift+a=write_screen_file:paste,...`

### - [ ] GLSL シェーダ (gradient / cursor blaze)

- **概要**: 背景グラデーション / カーソル軌跡
- **参照**: `ref/kawarimidoll-dotfiles/.config/ghostty/`
- **メリット**: 見た目の楽しさ
- **デメリット**: GPU 負荷、好みが分かれる
- **実装メモ**: `home.file` でシェーダ配布

### - [ ] 分割 resize モード

- **概要**: 専用モード入って hjkl で分割サイズ調整
- **参照**: `ref/kawarimidoll-dotfiles/.config/ghostty/config`
- **メリット**: tmux 不要で多重表示
- **デメリット**: tmux と機能重複
- **実装メモ**: keybind 設定

### - [ ] `Shift+Enter = CSI u` エンコーディング

- **概要**: Shift+Enter を別キーとして送出（nvim/Claude 系で改行入力に使える）
- **参照**: 同上
- **メリット**: モダンなキー入力（CSI u プロトコル）
- **デメリット**: 受け側アプリが対応していること
- **実装メモ**: keybind

### - [ ] WezTerm 側へ keybind 思想を移植

- **概要**: 上記 split / resize の発想を WezTerm に応用
- **メリット**: WezTerm を残しつつ快適性向上
- **デメリット**: 設定言語が違うので書き換え必要
- **実装メモ**: `home/wezterm.nix`
