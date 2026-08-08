# docs

このリポジトリの補足資料です。セットアップ手順と全体像は
リポジトリ直下の [README.md](../README.md) にあります。

| ファイル | 内容 |
| --- | --- |
| [nix-concepts.md](./nix-concepts.md) | Nix の構文・概念・Flakes・モジュール・Home Manager のライフサイクル。**まずこれ** |
| [herdr.md](./herdr.md) | [herdr](https://herdr.dev/) (ターミナルマルチプレクサ) の使い方・キーバインド・設定の反映フロー |
| [lazyvim.md](./lazyvim.md) | Neovim + [LazyVim](https://www.lazyvim.org/) の使い方・Nix との責務分担・プラグインのライフサイクル |
| [fish-abbr.md](./fish-abbr.md) | fish の補完がどこから来ているか・短縮入力 (abbreviation) の一覧と足し方 |
| [fish-nix-path.md](./fish-nix-path.md) | fish に Nix の PATH が通る仕組みと、このリポジトリでの扱い |
| [ref-tips/](./ref-tips/) | 他の dotfiles から取り入れる候補のチェックリスト |

## どこを見ればいいか

| 知りたいこと | 見る場所 |
| --- | --- |
| 導入したい / 環境を作り直したい | [README.md](../README.md) |
| `home-manager switch` が何をしているのか | [nix-concepts.md 5 章](./nix-concepts.md#5-home-manager-のライフサイクル) |
| Nix の文法が読めない | [nix-concepts.md 1 章](./nix-concepts.md#1-nix-言語の基本構文) |
| 外部ツールが書き換えた設定を Nix に取り込みたい | [nix-concepts.md 7 章](./nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む) |
| ターミナルで新しいタブ / ペイン / workspace を開きたい | [herdr.md 4 章](./herdr.md#4-基本操作-キーバインド) |
| セッションを残したままターミナルを閉じたい | [herdr.md 3 章](./herdr.md#3-起動デタッチ終了-ランタイムのライフサイクル) |
| `gst` などの短縮入力が何に展開されるのか | [fish-abbr.md 3 章](./fish-abbr.md#3-定義済み-abbreviation-一覧) (実行時は `abbr --show`) |
| コマンドのオプション候補がどこから出ているのか | [fish-abbr.md 1 章](./fish-abbr.md#1-補完はほぼ何もしなくても効く) |
| エディタのキー操作を知りたい | [lazyvim.md 4 章](./lazyvim.md#4-基本操作) |
| プラグインや LSP を足したい | [lazyvim.md 5 章](./lazyvim.md#5-設定を変える) / [6 章](./lazyvim.md#6-lspフォーマッタリンタ) |
| なぜエディタ設定が Nix 管理外なのか | [lazyvim.md 1 章](./lazyvim.md#1-責務の分担) |
