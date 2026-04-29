# 07. Karabiner-Elements (macOS 専用)

`ref/ryoppippi-dotfiles/karabiner/` を TypeScript で記述する手法。  
Linux 機では対象外。

### - [ ] Karabiner 設定を TypeScript で生成

- **概要**: `karabiner.ts` を `bun run build` で `karabiner.json` に変換
- **参照**: `ref/ryoppippi-dotfiles/karabiner/`
- **メリット**: JSON 手書きより遥かに保守性 ◎、型補完あり
- **デメリット**: bun 必須、初期セットアップに手間
- **実装メモ**: `darwin/karabiner/` 新設

### - [ ] Vim 風 hjkl → 矢印 (Fn 修飾)

- **概要**: `Fn+h/j/k/l` を ←/↓/↑/→ に
- **参照**: ryoppippi karabiner.ts
- **メリット**: ホームポジションから外れずカーソル移動
- **デメリット**: Fn キー位置がキーボード依存
- **実装メモ**: karabiner.ts ルール

### - [ ] Tap = Tab / Hold = 修飾キー (Dual-Function)

- **概要**: 単押しで Tab、長押しで Hyper キー等
- **参照**: 同上
- **メリット**: 1 キー 2 役割で省スペース
- **デメリット**: 慣れるまで誤入力
- **実装メモ**: karabiner.ts ルール

### - [ ] Left Ctrl 単押し → Escape

- **概要**: 単押し Esc / 長押し Ctrl
- **参照**: 同上
- **メリット**: vim ユーザー必携
- **デメリット**: 既に Caps→Esc 派なら不要
- **実装メモ**: karabiner.ts

### - [ ] App 別 (bundle id) 条件分岐

- **概要**: アプリごとにキーバインドを切替
- **参照**: 同上
- **メリット**: ブラウザ ↔ エディタで挙動変更
- **デメリット**: ルール量が増えると複雑
- **実装メモ**: karabiner.ts

### - [ ] Karabiner 設定を `home.file` で配布

- **概要**: `home.file."Library/Application Support/Karabiner/karabiner.json".source = ...`
- **参照**: ryoppippi
- **メリット**: home-manager で設定一元管理
- **デメリット**: Karabiner UI で編集 → 上書き衝突に注意
- **実装メモ**: `darwin/karabiner.nix`
