---
paths:
  - "flake.nix"
  - "hosts/**/*.nix"
  - "home/**/*.nix"
---

# このリポジトリの Nix モジュールを書くとき

Nix 全般の作法 (適用しない・`git add`・`flake.lock` を触らない) は
`~/.claude/rules/nix.md` にある。ここは dotfiles-nix 固有の話。

## 置き場所

| 種類 | 置き場所 |
| --- | --- |
| 入れるだけで使えるツール | `home/packages.nix` の `home.packages` |
| シェル統合・設定ファイル・関数を持つツール | `home/cli/<name>.nix` を新規作成し `home/cli/default.nix` の `imports` に追加 |
| fish プラグイン | `home/shell/fish.nix` の `plugins` |
| 短縮入力 (`programs.fish.shellAbbrs`) | **そのツールのモジュール** (git のものは `home/git.nix`) |
| ホストごとの差分 | `hosts/<name>.nix` |
| 個人情報 (ユーザー名 / コミッタ名 / メール) | `flake.nix` の `userInfo` |

## 書き方

- ファイル冒頭に `# ──────` で囲ったブロックコメントを置き、
  **そのモジュールが何を担当し、なぜその方針なのか**を書く。
- 値を上流の既定から変えたら、**変えた理由**を必ずコメントに残す
  (`home/cli/gwq.nix` が典型。踏んだエラーと確認済みの挙動まで書いてある)。
- 何をしているかだけの薄いコメント (`# fish を有効化`) は足さない。
- 同じ値を 2 箇所に書かない。`GHQ_ROOT` と gwq の `basedir` のように連動する値は、
  片方から参照するかコメントで相互に指す。

## 検証

```bash
nix flake check --no-build                                          # 評価チェック (abbr: nfc)
nix build .#homeConfigurations."zenimoto@ubuntu".activationPackage  # 適用せずビルド
```

`home-manager switch` は打たない (CLAUDE.md 参照)。適用が要る変更は、
そのコマンドを提示して人間に任せる。

## 既存の設計判断 (覆さない)

- `programs.neovim` は使わない (`~/.config/nvim` を Nix 管理外にするため)。
  ただし `lua/plugins/*.lua` だけは `xdg.configFile` でファイル単位に配ってよい
  (lazy.nvim が読むだけなので read-only symlink で困らない)。ディレクトリごとは不可。
- `programs.claude-code.settings` は宣言しない (`~/.claude/settings.json` は CLI が書く)。
- Nix 管理外の実ファイルと衝突する設定は `force = true` を検討する。
  `-b backup` は初回限りの回避策で、恒久対策には使わない。
