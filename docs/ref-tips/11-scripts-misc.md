# 11. Scripts / Misc — bin/ 以下の便利スクリプト群

`ref/kawarimidoll-dotfiles/bin/` 中心。  
`pkgs.writeShellApplication` で Nix パッケージ化するか、`home.file` で配布するか選択。

### - [ ] `fffe` — fd + fzf + editor 統合

- **概要**: `fd` で候補出し → `fzf --multi` で複数選択 → エディタで一括 open
- **参照**: `ref/kawarimidoll-dotfiles/bin/fffe:109-111`
- **メリット**: 「あのファイル何だっけ」を即編集に繋げる
- **デメリット**: fd / fzf 必須
- **使い方**: `fffe [query]`
- **実装メモ**: `pkgs.writeShellApplication { name = "fffe"; runtimeInputs = [ pkgs.fd pkgs.fzf ]; text = ...; }`

### - [ ] `wakeup` — `caffeinate` ラッパー (macOS)

- **概要**: スリープ防止
- **参照**: `ref/kawarimidoll-dotfiles/bin/wakeup`
- **メリット**: 長いビルド/DL 中の sleep 防止
- **デメリット**: macOS 専用
- **使い方**: `wakeup [duration]`
- **実装メモ**: `darwin/` 専用に配置

### - [ ] `24-bit-color` — 端末カラー確認

- **概要**: TrueColor 表示確認
- **参照**: `ref/kawarimidoll-dotfiles/bin/24-bit-color`
- **メリット**: 新環境セットアップ時の動作確認
- **デメリット**: 使用頻度低
- **実装メモ**: writeShellApplication

### - [ ] `centering` — テキスト中央寄せ

- **概要**: 端末幅に応じてテキストをセンタリング
- **参照**: `ref/kawarimidoll-dotfiles/bin/centering`
- **メリット**: スクリプトの飾り出力に使える
- **デメリット**: ニッチ
- **実装メモ**: writeShellApplication

### - [ ] `mov_to_mp4` — 動画変換

- **概要**: ffmpeg ラッパーで MOV→MP4
- **参照**: `ref/kawarimidoll-dotfiles/bin/mov_to_mp4`
- **メリット**: スクリーン録画変換が一発
- **デメリット**: ffmpeg 必須
- **実装メモ**: writeShellApplication, runtimeInputs に ffmpeg

### - [ ] `deno-init` — Deno プロジェクト初期化

- **概要**: deno init + 自分流テンプレ
- **参照**: `ref/kawarimidoll-dotfiles/bin/deno-init`
- **メリット**: Deno 触るならテンプレ統一
- **デメリット**: Deno 触らないなら不要
- **実装メモ**: writeShellApplication

### - [ ] `playjs` — JS one-liner 実行環境

- **概要**: その場で書いて即実行する JS 実験スクリプト
- **参照**: `ref/kawarimidoll-dotfiles/bin/playjs`
- **メリット**: scratch 用
- **デメリット**: node/bun/deno のどれを使うか要選択
- **実装メモ**: writeShellApplication

### - [ ] 配布方式の選択

- **概要**: `pkgs.writeShellApplication` で Nix package 化 vs `home.file."bin/foo".source = ./bin/foo;` でそのまま配布
- **メリット (writeShellApplication)**: shellcheck 通る、依存が明示
- **メリット (home.file)**: スクリプト編集 → 即反映 (リビルド不要)
- **実装メモ**: 安定運用するものは writeShellApplication、試行錯誤中は home.file
