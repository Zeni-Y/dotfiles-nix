# CLAUDE.md

このリポジトリ (`dotfiles-nix`) で作業するときの規約。**作業を始める前に必ずこれを読む。**

背景・手順・解説は [README.md](README.md) と [docs/](docs/) にあるので、
ここには「守るべきルール」と「どこを見るか」だけを置く。

## 先に押さえる 4 行

1. 編集は **git worktree** の中でやる (他の Claude Code セッションと競合させない)
2. **`main` に直接コミットしない**。`claude/<topic>` ブランチ → PR → **merge commit**
3. **`home-manager switch` は打たない**。検証は `nix flake check --no-build` / `nix build` まで
4. 新しい `.nix` を足したら **`git add`**。しないと flake から見えない

---

## 1. スコープ (勝手に広げない前提)

- **対象 OS は Linux のみ**。Ubuntu 実機 / WSL2 / Docker コンテナ。
  **macOS (nix-darwin / Homebrew) は対象外**なので、macOS 向けの分岐や設定を足さない。
- **`sudo` が使える前提**。`/nix` に入る通常の (multi-user) Nix だけをサポートする。
  **`nix-portable` は使わない**。無権限環境の話は考慮しない。
- **システム領域は Nix で管理しない**。NixOS ではないので `~/` 配下 (Home Manager) だけ。
- 対象外にしたものを再導入する提案は、明示的に頼まれない限りしない
  (過去に `refactor: nix-portable と macOS を設計から除外する` で意図的に落としている)。

## 2. 作業の進め方 — worktree を使う

複数の Claude Code セッションが同じチェックアウトを触ると壊れる。**編集は必ず worktree で行う。**

置き場所は**集約派**。本体の「隣」に `<repo>=<branch>` で並べる (`~/ghq` に集約)。

```bash
# 本体: ~/ghq/github.com/Zeni-Y/dotfiles-nix
git worktree add -b claude/<topic> \
  ~/ghq/github.com/Zeni-Y/dotfiles-nix=<topic> main
```

- 人間の手元では `gwq add -b <branch>` が同じ場所に作り、そのまま移動する。
- 使い捨てで良いなら `claude --worktree <name>` (`<repo>/.claude/worktrees/` に隔離される) でもよい。
- **後片付けは `git worktree remove <path>` + `git branch -d <branch>` で 1 セット**。
  worktree を消してもブランチは残る。`rm -rf` しただけなら `git worktree prune`。
- worktree には**追跡外ファイルが付いてこない** (`ref/`, `.claude/settings.local.json`, `.direnv/`)。
  必要なら `.worktreeinclude` か symlink で持ち込む。

詳細・ハマりどころ: **[docs/git-worktree.md](docs/git-worktree.md)** (並列エージェント運用は 8 章)。

## 3. Git / PR 運用

- **`main` へ直接コミット・直接 push はしない。** 履歴は全て
  `Merge pull request #N from Zeni-Y/claude/...` の形になっている。
- ブランチ名は `claude/<topic>` (英小文字ケバブケース)。
- コミットメッセージは **日本語 + Conventional Commits**。
  `feat(ghq,gwq): clone と worktree を ~/ghq に集約し、移動コマンドを追加` のように、
  scope はモジュール名 / ディレクトリ名。
  本文は「何をしたか」ではなく **なぜそうしたか** と、触ったファイルごとの要約を書く。
- PR 本文は 概要 / 設定 / ドキュメント / 確認 の構成。
- マージは **`gh pr merge <N> --merge --delete-branch`** (squash ではない)。main は保護されていない。
- ユーザが **「push&merge」** と言ったら、commit → push → `gh pr create` → merge → ブランチ削除まで
  一続きでやる。途中で「PR を作りますか？」と確認を挟まない。
  **「commit&push」** だけなら push で止め、PR を作るか一言添える。

## 4. どこに何を書くか

```
flake.nix           入力 (nixpkgs / home-manager / nix-claude-code) と userInfo
hosts/<name>.nix    ホスト単位の入口。マシンを増やすときはここ + flake.nix の outputs
home/               ユーザー領域 (~/) の設定。Ubuntu でも Docker でも同じものが入る
  packages.nix        「入れるだけで使える」ツール
  cli/<name>.nix      シェル統合・設定・関数を持つツール (default.nix に imports を追加)
  shell/ editors/     同上
scripts/setup.sh    Nix のインストール (sudo 必須)
docker/             debug / working / working_nixos
docs/               補足資料 (README の表と docs/README.md の索引も更新する)
plans/              実装前に書いた計画。作業後もそのまま残す
ref/                他人の dotfiles (gitignore 済み・参照専用)。★ 絶対に編集しない
```

判断に迷ったときの原則:

- **設定不要なら `home/packages.nix`、シェル関数や設定ファイルを持つなら `home/cli/<name>.nix`。**
  後者を作ったら `home/cli/default.nix` の `imports` に足す。
- 短縮入力 (`programs.fish.shellAbbrs`) は**そのツールのモジュールに置く**。
  git のものは `home/git.nix`、herdr のものは `home/herdr.nix`、
  home-manager / nix のものは `home/shell/fish.nix`。
- **個人情報は `flake.nix` の `userInfo` に集約**。他のファイルに名前やメールを直書きしない。
  例外は GitHub の owner 名 `Zeni-Y` (`home/shell/fish.nix` の `flakeDir`)。
  `userInfo.username` (`zenimoto`) と綴りが違うので自動導出できない。

## 5. Nix を編集するときのルール

- **新しい `.nix` を足したら `git add`。** flake は git 管理下のファイルしか見ないので、
  `error: Path 'home/cli/xxx.nix' ... is not tracked by Git` で落ちる。コミットまでは不要。
- **`home-manager switch` はエージェントが打たない。** マシン全体に効くので、適用は人間が本体から 1 回だけ。
  エージェント側の検証は下記まで。
  ```bash
  nix flake check --no-build      # 評価チェック (abbr: nfc)
  nix build .#homeConfigurations."zenimoto@ubuntu".activationPackage
  ```
- **Nix 管理外の実ファイルと衝突する設定は `force = true`** を検討する
  (`home/cli/gwq.nix` が実例。ツールが自分で作る config を Nix で配るケース)。
  `-b backup` は初回 switch 用の回避策で、恒久対策には向かない。
  → [docs/nix-concepts.md 7-7](docs/nix-concepts.md#7-7-例外-まだ-nix-管理下に無い実ファイルは上書きされず-switch-が止まる)
- **`~/.config/nvim` は意図的に Nix 管理外。** `programs.neovim` は使わず
  `home.packages = [ pkgs.neovim ]` にしてある。ここを「きれいにする」提案はしない
  (理由は README のエディタの節)。
- バージョンを上げたいときは `nix flake update` → `home-manager switch`。
  ツール自身の自己更新 (`herdr update` など) は使わない。

## 6. ドキュメント

このリポジトリは**ドキュメントも成果物**。コードを変えたら対応する資料も同じ PR で直す。

- 新しいトピックの資料は `docs/<topic>.md`。
  足したら **`docs/README.md` の表と「どこを見ればいいか」** 、および
  **ルート `README.md` の補足資料の表**にも行を足す。
- 文体は**日本語**。README / docs は常体と敬体が混在しているが、**1 ファイル内では揃える**。
  既存ファイルに追記するときはそのファイルの文体に合わせる。
- `.nix` のコメントは**「なぜそうしたか」を厚く書く**のがこのリポジトリの流儀
  (`home/cli/gwq.nix` が典型)。何をしているかだけの薄いコメントは足さない。
- `docs/ref-tips/` は他の dotfiles からの**採用候補チェックリスト**。
  ユーザが `- [x]` を付けた項目だけを実装する。勝手に全部入れない。
- `plans/` は実装前の計画置き場。作業が終わっても消さない。

## 7. 触らないもの

- `ref/` — 他人の dotfiles のクローン (gitignore 済み)。読むのは自由、**編集・コミットはしない**。
- `.claude/settings.local.json` — グローバル gitignore 済み。コミットしない。
- `flake.lock` — 更新するのは `nix flake update` のときだけ。手で書き換えない。
- `.gitattributes` の LF 指定 — Windows/WSL で `set -euo pipefail` が壊れるのを防いでいる。

## 8. ハマったらここを見る

| 症状 | 見る場所 |
| --- | --- |
| Nix の文法・flake・Home Manager のライフサイクル | [docs/nix-concepts.md](docs/nix-concepts.md) |
| `Existing file ... would be clobbered` | README「`-b backup` の挙動」/ [nix-concepts 7 章](docs/nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む) |
| worktree / 並列エージェント / ghq・gwq の住み分け | [docs/git-worktree.md](docs/git-worktree.md) |
| `hms` などの短縮入力が何に展開されるか | [docs/fish-abbr.md](docs/fish-abbr.md) (実行時は `abbr --show`) |
| ターミナル (herdr) のキーバインド・設定反映 | [docs/herdr.md](docs/herdr.md) |
| Neovim / LazyVim の責務分担 | [docs/lazyvim.md](docs/lazyvim.md) |
| Windows (WSL2) のセットアップ | [docs/wsl2.md](docs/wsl2.md) |
| コンテナで `nix-daemon` が落ちている / UID 不一致 | [docker/debug/README.md](docker/debug/README.md) |
| その他の既知の罠 | README「既知のハマりどころ」 |
