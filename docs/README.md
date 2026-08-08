# docs

このリポジトリの補足資料です。セットアップ手順と全体像は
リポジトリ直下の [README.md](../README.md) にあります。

| ファイル | 内容 |
| --- | --- |
| [nix-concepts.md](./nix-concepts.md) | Nix の構文・概念・Flakes・モジュール・Home Manager のライフサイクル。**まずこれ** |
| [wsl2.md](./wsl2.md) | Windows (WSL2) でのセットアップ手順・Docker との使い分け・WSL 固有のハマりどころ |
| [herdr.md](./herdr.md) | [herdr](https://herdr.dev/) (ターミナルマルチプレクサ) の使い方・キーバインド・設定の反映フロー |
| [lazyvim.md](./lazyvim.md) | Neovim + [LazyVim](https://www.lazyvim.org/) の使い方・Nix との責務分担・プラグインのライフサイクル |
| [git-worktree.md](./git-worktree.md) | git worktree のライフサイクル・ghq / herdr / Claude Code との住み分け・並列エージェント運用 |
| [claude-code.md](./claude-code.md) | Claude Code の指示ファイル (CLAUDE.md / rules) の階層と、Nix での配り方 |
| [fish-abbr.md](./fish-abbr.md) | fish の補完がどこから来ているか・短縮入力 (abbreviation) の一覧と足し方 |
| [fish-nix-path.md](./fish-nix-path.md) | fish に Nix の PATH が通る仕組みと、このリポジトリでの扱い |
| [ref-tips/](./ref-tips/) | 他の dotfiles から取り入れる候補のチェックリスト |

## どこを見ればいいか

| 知りたいこと | 見る場所 |
| --- | --- |
| 導入したい / 環境を作り直したい | [README.md](../README.md) |
| Windows 上に環境を作りたい | [wsl2.md](./wsl2.md) |
| WSL で systemd が要るのはなぜか | [wsl2.md 3 章](./wsl2.md#3-systemd-を有効化する) |
| WezTerm の設定が Windows で効かない | [wsl2.md 7 章](./wsl2.md#72-ターミナル) |
| `home-manager switch` が何をしているのか | [nix-concepts.md 5 章](./nix-concepts.md#5-home-manager-のライフサイクル) |
| Nix の文法が読めない | [nix-concepts.md 1 章](./nix-concepts.md#1-nix-言語の基本構文) |
| 外部ツールが書き換えた設定を Nix に取り込みたい | [nix-concepts.md 7 章](./nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む) |
| ターミナルで新しいタブ / ペイン / workspace を開きたい | [herdr.md 4 章](./herdr.md#4-基本操作-キーバインド) |
| ペインの出力を遡りたい / コピーしたい | [herdr.md 5 章](./herdr.md#5-ペインの操作-分割スクロールコピー) |
| セッションを残したままターミナルを閉じたい | [herdr.md 3 章](./herdr.md#3-起動デタッチ終了-ランタイムのライフサイクル) |
| 複数の coding agent を並列に走らせたい | [git-worktree.md 8 章](./git-worktree.md#8-並列エージェント運用のレシピ) |
| worktree をどこに置けばいいか (ghq との関係) | [git-worktree.md 5 章](./git-worktree.md#5-置き場所の設計--集約派と隔離派) |
| clone と worktree を `~/ghq` に集約したい (gwq) | [git-worktree.md 7 章](./git-worktree.md#7-集約派で揃える--gwq-と-herdr-を合わせる) |
| worktree を消したのにブランチが残る / 消せない | [git-worktree.md 4 章](./git-worktree.md#4-ライフサイクル-素の-git) |
| リポジトリ / worktree に手早く移動したい (`dev`, `gwq cd`) | [git-worktree.md 7-3 章](./git-worktree.md#7-3-移動を作る--シェル統合と-dev) |
| Claude Code に毎回同じ指示を出さずに済ませたい | [claude-code.md 2 章](./claude-code.md#2-指示ファイルの階層) |
| 共通ルールを足したい / どこに書くか迷う | [claude-code.md 4 章](./claude-code.md#4-このリポジトリでの配り方) / [5 章](./claude-code.md#5-ルールを足す直す手順) |
| `~/.claude/CLAUDE.md` が編集できない | [claude-code.md 8 章](./claude-code.md#8-ハマりどころ) |
| `gst` などの短縮入力が何に展開されるのか | [fish-abbr.md 3 章](./fish-abbr.md#3-定義済み-abbreviation-一覧) (実行時は `abbr --show`) |
| コマンドのオプション候補がどこから出ているのか | [fish-abbr.md 1 章](./fish-abbr.md#1-補完はほぼ何もしなくても効く) |
| エディタのキー操作を知りたい | [lazyvim.md 4 章](./lazyvim.md#4-基本操作) |
| プラグインや LSP を足したい | [lazyvim.md 5 章](./lazyvim.md#5-設定を変える) / [6 章](./lazyvim.md#6-lspフォーマッタリンタ) |
| なぜエディタ設定が Nix 管理外なのか | [lazyvim.md 1 章](./lazyvim.md#1-責務の分担) |
