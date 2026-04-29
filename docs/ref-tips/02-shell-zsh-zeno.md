# 02. Shell — zsh / zeno (発想を fish に移植する)

主に `ref/kawarimidoll-dotfiles/.config/zeno/` 由来。  
自分は fish 主体なので、ここでは「アイデア」を抽出して fish の `abbr` / `bind` で代替する形を想定する。

## Zeno 風グローバル abbr

### - [ ] スペース後展開のグローバル略語: `G`/`L`/`NL`

- **概要**: `cmd G word` → `cmd | rg word`、`L` → `| less`、`NL` → `> /dev/null 2>&1`
- **参照**: `ref/kawarimidoll-dotfiles/.config/zeno/config.yml`（行 70-124）
- **メリット**: パイプ・リダイレクトが 1-2 文字で書ける
- **デメリット**: fish の `abbr` は単語境界で展開されるので「位置」を要工夫（regex abbr）
- **使い方**: `ls G hoge<space>` → `ls | rg hoge` に展開
- **実装メモ**: fish 4.0+ の `abbr --regex` で実装可能。`home/shell/fish.nix`

### - [ ] `mkcd` (ディレクトリ作成 →cd)

- **概要**: `mkdir -p $1 && cd $1`
- **参照**: `ref/kawarimidoll-dotfiles/.config/zeno/config.yml`
- **メリット**: 定番の便利関数
- **デメリット**: 関数名が他と衝突しないよう注意
- **実装メモ**: `home/shell/fish.nix` functions

### - [ ] `cds` (tmp + git init)

- **概要**: `cd (mktemp -d) && git init` の一発系
- **参照**: 同上
- **メリット**: 実験用ブランチを即作れる
- **デメリット**: tmp 掃除の運用が必要
- **実装メモ**: 関数

## ZLE ウィジェット相当（fish bind に移植）

### - [ ] `Ctrl+X Ctrl+F` ghq fzf cd

- **概要**: ghq 配下を fzf で選び cd
- **参照**: `ref/kawarimidoll-dotfiles/.config/zsh/lazy.zsh`（行 51-63）
- **メリット**: 上記 ryoppippi の `__ghq_roots` と同等。どちらか採用すれば OK
- **実装メモ**: 重複候補。01 と統合検討

### - [ ] `Ctrl+X Ctrl+E` 現在のコマンドを vim で編集

- **概要**: 長いコマンドラインを vim で開いて編集
- **参照**: `ref/kawarimidoll-dotfiles/.config/zsh/lazy.zsh`（行 68-72）
- **メリット**: 巨大 one-liner の編集が楽
- **デメリット**: fish には `Alt-e` で類似機能ありなので必須度低い
- **実装メモ**: bind

### - [ ] `fancy-ctrl-z` (空なら fg / そうでなければ push-input)

- **概要**: `Ctrl+Z` がコンテキスト依存に動作変更
- **参照**: `ref/kawarimidoll-dotfiles/.config/zsh/lazy.zsh`（行 187-197）
- **メリット**: vim から戻る ↔ 送る ↔ コマンド一時退避がシームレス
- **デメリット**: fish 標準の `Ctrl+Z` 挙動を覚え直し
- **実装メモ**: fish 関数 + `bind \cz fancy-ctrl-z`

### - [ ] `Ctrl+X Ctrl+W` 末尾引数削除

- **概要**: コマンドラインの最後の引数だけを消す
- **参照**: `ref/kawarimidoll-dotfiles/.config/zsh/lazy.zsh`（行 164-172）
- **メリット**: 試行錯誤中に最終引数だけ書き換えやすい
- **デメリット**: なし
- **実装メモ**: fish 関数 + bind
