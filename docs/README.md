# docs

このリポジトリの補足資料です。セットアップ手順と全体像は
リポジトリ直下の [README.md](../README.md) にあります。

系統ごとにディレクトリを分けています。各ディレクトリの `ref-tips*.md` は
他人の dotfiles (`ref/`) から取り入れる候補のチェックリストです (→ [ref-tips の使い方](#ref-tips-の使い方))。

| 系統 | ファイル | 内容 |
| --- | --- | --- |
| [nix/](./nix/) | [nix-concepts.md](./nix/nix-concepts.md) | Nix の構文・概念・Flakes・モジュール・Home Manager のライフサイクル。**まずこれ** |
| | [ref-tips.md](./nix/ref-tips.md) | overlays / git-hooks.nix / agent-skills-nix の導入候補 |
| [setup/](./setup/) | [wsl2.md](./setup/wsl2.md) | Windows (WSL2) でのセットアップ手順・1Password ssh-agent 連携・WSL 固有のハマりどころ |
| | [ubuntu.md](./setup/ubuntu.md) | リモート接続先の素の Ubuntu でのセットアップ手順・SSH agent forwarding の扱い |
| [shell/](./shell/) | [fish-abbr.md](./shell/fish-abbr.md) | fish の補完がどこから来ているか・短縮入力 (abbreviation) の一覧と足し方 |
| | [fish-nix-path.md](./shell/fish-nix-path.md) | fish に Nix の PATH が通る仕組みと、このリポジトリでの扱い |
| | [ref-tips.md](./shell/ref-tips.md) | fish の abbr / functions / key bindings の導入候補 |
| [git/](./git/) | [git-worktree.md](./git/git-worktree.md) | git worktree のライフサイクル・ghq / herdr / Claude Code との住み分け・並列エージェント運用 |
| | [ref-tips.md](./git/ref-tips.md) | git alias / カスタム `git-*` / git-hooks の導入候補 |
| [editor/](./editor/) | [lazyvim.md](./editor/lazyvim.md) | Neovim + [LazyVim](https://www.lazyvim.org/) の使い方・Nix との責務分担・プラグインのライフサイクル |
| | [ref-tips.md](./editor/ref-tips.md) | Neovim のキーマップ / プラグインの導入候補 |
| [terminal/](./terminal/) | [herdr.md](./terminal/herdr.md) | [herdr](https://herdr.dev/) (ターミナルマルチプレクサ) の使い方・キーバインド・設定の反映フロー |
| [claude-code/](./claude-code/) | [claude-code.md](./claude-code/claude-code.md) | Claude Code の指示ファイル (CLAUDE.md / rules) の階層と、Nix での配り方 |
| | [ref-tips.md](./claude-code/ref-tips.md) | CLAUDE.md / agents / skills / hooks の導入候補 |
| [cli/](./cli/) | [hiraku.md](./cli/hiraku.md) | リモートの markdown / HTML をローカルのブラウザで見る `hiraku` コマンドの使い方と設計 |
| | [ref-tips-tools.md](./cli/ref-tips-tools.md) | delta, bit, comma, lazygit, dust などの導入候補 |
| | [ref-tips-scripts.md](./cli/ref-tips-scripts.md) | `bin/` 以下の便利スクリプト群の導入候補 |
| [archive/](./archive/) | [README.md](./archive/README.md) | 使わなくなったツールの資料の置き場。理由もそこに書く |

## どこを見ればいいか

| 知りたいこと | 見る場所 |
| --- | --- |
| 導入したい / 環境を作り直したい | [README.md](../README.md) |
| Windows 上に環境を作りたい | [setup/wsl2.md](./setup/wsl2.md) |
| リモートの Ubuntu に環境を作りたい | [setup/ubuntu.md](./setup/ubuntu.md) |
| 再起動後もパスフレーズ無しで ssh したい (1Password) | [setup/wsl2.md 7-4 章](./setup/wsl2.md#74-ssh-agent-を-windows-側に一本化する-任意) |
| WSL で systemd が要るのはなぜか | [setup/wsl2.md 3 章](./setup/wsl2.md#3-systemd-を有効化する) |
| WezTerm の設定が Windows で効かない | [setup/wsl2.md 7 章](./setup/wsl2.md#72-ターミナル) |
| `home-manager switch` が何をしているのか | [nix/nix-concepts.md 5 章](./nix/nix-concepts.md#5-home-manager-のライフサイクル) |
| Nix の文法が読めない | [nix/nix-concepts.md 1 章](./nix/nix-concepts.md#1-nix-言語の基本構文) |
| 外部ツールが書き換えた設定を Nix に取り込みたい | [nix/nix-concepts.md 7 章](./nix/nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む) |
| ターミナルで新しいタブ / ペイン / workspace を開きたい | [terminal/herdr.md 4 章](./terminal/herdr.md#4-基本操作-キーバインド) |
| ペインの出力を遡りたい / コピーしたい | [terminal/herdr.md 5 章](./terminal/herdr.md#5-ペインの操作-分割スクロールコピー) |
| セッションを残したままターミナルを閉じたい | [terminal/herdr.md 3 章](./terminal/herdr.md#3-起動デタッチ終了-ランタイムのライフサイクル) |
| 複数の coding agent を並列に走らせたい | [git/git-worktree.md 8 章](./git/git-worktree.md#8-並列エージェント運用のレシピ) |
| リモートの markdown / HTML を手元のブラウザで見たい | [cli/hiraku.md](./cli/hiraku.md) |
| worktree をどこに置けばいいか (ghq との関係) | [git/git-worktree.md 5 章](./git/git-worktree.md#5-置き場所の設計--集約派と隔離派) |
| clone と worktree を `~/ghq` に集約したい (gwq) | [git/git-worktree.md 7 章](./git/git-worktree.md#7-集約派で揃える--gwq-と-herdr-を合わせる) |
| worktree を消したのにブランチが残る / 消せない | [git/git-worktree.md 4 章](./git/git-worktree.md#4-ライフサイクル-素の-git) |
| リポジトリ / worktree に手早く移動したい (`dev`, `gwq cd`) | [git/git-worktree.md 7-3 章](./git/git-worktree.md#7-3-移動を作る--シェル統合と-dev) |
| Claude Code に毎回同じ指示を出さずに済ませたい | [claude-code/claude-code.md 2 章](./claude-code/claude-code.md#2-指示ファイルの階層) |
| 共通ルールを足したい / どこに書くか迷う | [claude-code/claude-code.md 4 章](./claude-code/claude-code.md#4-このリポジトリでの配り方) / [5 章](./claude-code/claude-code.md#5-ルールを足す直す手順) |
| `~/.claude/CLAUDE.md` が編集できない | [claude-code/claude-code.md 8 章](./claude-code/claude-code.md#8-ハマりどころ) |
| `gst` などの短縮入力が何に展開されるのか | [shell/fish-abbr.md 3 章](./shell/fish-abbr.md#3-定義済み-abbreviation-一覧) (実行時は `abbr --show`) |
| コマンドのオプション候補がどこから出ているのか | [shell/fish-abbr.md 1 章](./shell/fish-abbr.md#1-補完はほぼ何もしなくても効く) |
| エディタのキー操作を知りたい | [editor/lazyvim.md 4 章](./editor/lazyvim.md#4-基本操作) |
| プラグインや LSP を足したい | [editor/lazyvim.md 5 章](./editor/lazyvim.md#5-設定を変える) / [6 章](./editor/lazyvim.md#6-lspフォーマッタリンタ) |
| なぜエディタ設定が Nix 管理外なのか | [editor/lazyvim.md 1 章](./editor/lazyvim.md#1-責務の分担) |

## ref-tips の使い方

`ref/ryoppippi-dotfiles` と `ref/kawarimidoll-dotfiles` から、本リポジトリに取り入れる価値が
ありそうな設定・tips を網羅的に抽出したチェックリストです。系統ごとのディレクトリに
`ref-tips*.md` として置いてあります。

> 本リポジトリの対象は **Linux (Ubuntu / Docker コンテナ) のみ** なので、
> macOS 専用の項目 (Karabiner / Homebrew Cask / `defaults write` など) は
> 候補から外しています。

1. 各ファイルを開いて項目を読む
2. 採用したいものは `- [ ]` を `- [x]` に書き換える
3. 次回 Claude にそのファイルを渡すと、`[x]` の項目だけ実装します

```fish
# チェック済み一覧を確認
git grep -n '\- \[x\]' docs/
```

各項目は次の構造で記載されています。

```markdown
### - [ ] 項目名

- **概要**: 何をするものか
- **参照**: ref/<repo>/<path>
- **メリット**: 採用すると得られるもの
- **デメリット/コスト**: トレードオフ
- **使い方**: どう発動するか
- **実装メモ**: 自分のリポジトリのどこに置くか
```

出典 (どちらも `ref/` にクローンしてある。gitignore 済み・参照専用):

- `ref/ryoppippi-dotfiles/` — Nix Flake + home-manager 構成。AI/Agent 統合が秀逸
- `ref/kawarimidoll-dotfiles/` — zsh + zeno + mini.nvim。シェル体験と git 周りの自作スクリプトが豊富
