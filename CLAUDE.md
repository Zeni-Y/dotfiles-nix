# CLAUDE.md

`dotfiles-nix` — **Nix Flakes + Home Manager** で Linux (Ubuntu / WSL2 / Docker) の
ホームディレクトリを宣言的に管理する dotfiles。CI もテストも無い。

worktree・ブランチ・コミット・PR の作法は全プロジェクト共通なので `~/.claude/CLAUDE.md` と
`~/.claude/rules/` にある (**このリポジトリの `home/claude-code/` がその配布元**)。
ここには dotfiles-nix 固有のことだけを書く。

## 絶対に守ること

- **`home-manager switch` を実行しない。** マシン全体に効くので、適用は人間が本体から 1 回だけ。
  エージェント側の検証は評価まで:
  ```bash
  nix flake check --no-build
  nix build .#homeConfigurations."zenimoto@ubuntu".activationPackage
  ```
- **新しい `.nix` やそこから参照する Markdown を足したら `git add`。**
  flake は git 管理下のファイルしか見ない (コミットまでは不要)。
- **`ref/` を編集しない。** 他人の dotfiles のクローン (gitignore 済み)。読むのは自由。

## スコープ (勝手に広げない)

- 対象は **Linux のみ**。macOS (nix-darwin / Homebrew) 向けの分岐を足さない。
- **`sudo` が使える前提**。`/nix` に入る通常の multi-user Nix だけ。`nix-portable` は使わない。
- **システム領域は管理しない。** NixOS ではないので `~/` 配下 (Home Manager) だけ。
- 一度設計から外したもの (macOS / nix-portable / chezmoi / tmux / zellij / Zed) を
  再導入する提案はしない。

## どこに何があるか

| パス | 役割 |
| --- | --- |
| `flake.nix` | 入力 (nixpkgs / home-manager / nix-claude-code) と `userInfo` |
| `hosts/<name>.nix` | ホスト単位の入口。マシンを増やすときはここ + `flake.nix` の outputs |
| `home/packages.nix` | 「入れるだけで使える」ツール |
| `home/cli/<name>.nix` | シェル統合・設定・関数を持つツール |
| `home/shell/` `home/editors/` | fish / bash、Neovim |
| `home/claude-code/` | **`~/.claude/CLAUDE.md` と `~/.claude/rules/` の配布元** |
| `docker/` | `debug` (検証) / `working` (常駐開発) / `working_nixos` |
| `docs/` | 補足資料。足したら README と `docs/README.md` の索引にも行を足す |
| `plans/` | 実装前に書いた計画。作業後も消さない |
| `ref/` | 他人の dotfiles (gitignore 済み・参照専用) |

置き場所に迷ったら: **設定不要なら `home/packages.nix`、シェル関数や設定ファイルを持つなら
`home/cli/<name>.nix`** を作って `home/cli/default.nix` の `imports` に足す。
短縮入力 (`programs.fish.shellAbbrs`) はそのツールのモジュールに置く。

**個人情報は `flake.nix` の `userInfo` に集約する。** GitHub の owner 名は `userInfo.githubUser`
(`username` と綴りが違い自動導出できないため別項目)。`ghq.user` と fish の `flakeDir` は
そこから導出される。対話的な一括設定は `scripts/configure-user.sh`。

## 意図的にそうしているもの (「きれいにする」提案をしない)

- **`~/.config/nvim` は Nix 管理外。** `programs.neovim` は使わず `home.packages` で入れている。
  LazyVim starter の `init.lua` や `lazy-lock.json` と衝突するため。
- **`~/.claude/settings.json` と auto memory も管理外。** Claude Code 自身が書き換えるファイル。
- **`home/cli/gwq.nix` の `force = true`。** gwq が初回実行時に自分の config を作るため。
- **abbreviation (`abbr`) であって alias ではない。** 履歴に展開後のコマンドを残し、
  展開後にオプションを足せるようにするため。

## ハマったらここを見る

| 症状 / 知りたいこと | 参照先 |
| --- | --- |
| Nix の文法・flake・Home Manager のライフサイクル | [docs/nix/nix-concepts.md](docs/nix/nix-concepts.md) |
| `Existing file ... would be clobbered` | [nix-concepts.md 7 章](docs/nix/nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む) |
| worktree / 並列エージェント / ghq・gwq の住み分け | [docs/git/git-worktree.md](docs/git/git-worktree.md) |
| GitHub への ssh 一本化・1Password の鍵の使い回し | [docs/git/github-ssh.md](docs/git/github-ssh.md) |
| API キー / トークン / `.env` の扱い (1Password + direnv) | [docs/secrets/1password-direnv.md](docs/secrets/1password-direnv.md) |
| Claude Code の指示ファイルの階層と配り方 | [docs/claude-code/claude-code.md](docs/claude-code/claude-code.md) |
| `hms` などの短縮入力の展開先 | [docs/shell/fish-abbr.md](docs/shell/fish-abbr.md) (実行時は `abbr --show`) |
| ターミナル (herdr) のキーバインド・設定反映 | [docs/terminal/herdr.md](docs/terminal/herdr.md) |
| Neovim / LazyVim の責務分担 | [docs/editor/lazyvim.md](docs/editor/lazyvim.md) |
| Windows (WSL2) のセットアップ | [docs/setup/wsl2.md](docs/setup/wsl2.md) |
| コンテナで `nix-daemon` が落ちている / UID 不一致 | [docker/debug/README.md](docker/debug/README.md#よくあるエラーと対処) |
| その他の既知の罠 | [README.md「既知のハマりどころ」](README.md#既知のハマりどころ) |

`.nix` を触るとき・ドキュメントを書くときの細則は `.claude/rules/` に分けてある
(該当ファイルを開いたときだけ読み込まれる)。
