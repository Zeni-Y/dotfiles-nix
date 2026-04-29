# ref/ dotfiles から取り入れる候補集

`ref/ryoppippi-dotfiles` と `ref/kawarimidoll-dotfiles` から、本リポジトリ (`dotfiles-nix`) に取り入れる価値がありそうな設定・tips を **網羅的に** 抽出しチェックリスト化したものです。

## 使い方

1. 各カテゴリファイルを開いて項目を読む
2. 採用したいものは `- [ ]` を `- [x]` に書き換える
3. 次回 Claude にこのディレクトリを渡すと、`[x]` の項目だけ実装します

```fish
# チェック済み一覧を確認
git grep -n '\- \[x\]' docs/ref-tips/
```

## ファイル構成

| #   | ファイル                                        | 内容                                                  |
| --- | ----------------------------------------------- | ----------------------------------------------------- |
| -   | [README.md](./README.md)                        | このファイル                                          |
| 01  | [shell-fish.md](./01-shell-fish.md)             | fish abbr / functions / key bindings (主に ryoppippi) |
| 02  | [shell-zsh-zeno.md](./02-shell-zsh-zeno.md)     | zeno snippets / ZLE widget の発想 (kawarimidoll)      |
| 03  | [git.md](./03-git.md)                           | alias / カスタム `git-*` / git-hooks                  |
| 04  | [neovim.md](./04-neovim.md)                     | キーマップ / mini.nvim / プラグイン管理               |
| 05  | [terminal-ghostty.md](./05-terminal-ghostty.md) | ghostty 宣言的設定 / scrollback in vim                |
| 06  | [claude-code.md](./06-claude-code.md)           | CLAUDE.md / agents / skills / hooks                   |
| 07  | [karabiner.md](./07-karabiner.md)               | TypeScript で Karabiner (macOS 専用)                  |
| 08  | [nix-tooling.md](./08-nix-tooling.md)           | overlays / git-hooks.nix / agent-skills-nix           |
| 09  | [cli-tools.md](./09-cli-tools.md)               | delta, bit, comma, lazygit, dust 他                   |
| 10  | [macos.md](./10-macos.md)                       | defaults write / Homebrew Cask 追加候補               |
| 11  | [scripts-misc.md](./11-scripts-misc.md)         | bin/ 以下の便利スクリプト群                           |

## 凡例

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

## 出典

- `ref/ryoppippi-dotfiles/` — Nix Flake + home-manager + nix-darwin。AI/Agent 統合が秀逸
- `ref/kawarimidoll-dotfiles/` — zsh + zeno + mini.nvim。シェル体験と git 周りの自作スクリプトが豊富
