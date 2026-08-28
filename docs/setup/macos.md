# macOS (MacBook) でのセットアップ

対象は **sudo が使える MacBook** (Apple Silicon)。Intel Mac に入れる場合は
`hosts/macbook.nix` の `system` を `x86_64-darwin` に変える。

方針は Linux と同じで、**standalone Home Manager で `~/` 配下だけを管理する**:

- **nix-darwin は使わない。** システム領域 (Dock / Finder の `defaults`、
  ログインシェルの登録など) は Nix の管理外。
- **Homebrew も管理しない。** GUI アプリ (ブラウザ、1Password アプリなど) は
  従来どおり手で入れる。このリポジトリが面倒を見るのは CLI ツールと
  その設定ファイルだけ。
- Nix は `sudo` を使う通常の multi-user 構成 (`/nix`)。`nix-portable` は使わない。

## 目次

1. [前提の確認](#1-前提の確認)
2. [リポジトリの配置](#2-リポジトリの配置)
3. [Nix のインストール (setup.sh)](#3-nix-のインストール-setupsh)
4. [初回 switch](#4-初回-switch)
5. [fish をログインシェルにする](#5-fish-をログインシェルにする)
6. [ハマりどころ](#6-ハマりどころ)

---

## 1. 前提の確認

```bash
sudo -v                 # sudo が使えること (無い環境はサポート外 → README)
xcode-select --install  # git などの Command Line Tools。導入済みならエラーになるだけ
```

systemd まわりの確認 (ubuntu.md 1 章) は不要。macOS では `nix-daemon` を
launchd が管理するので、インストーラに任せておけばよい。

---

## 2. リポジトリの配置

Linux と同じく ghq の標準レイアウトに置く。worktree を同じ root に集約するため、
この階層でなければならない (→ [git-worktree.md 7 章](../git/git-worktree.md#7-集約派で揃える--gwq-と-herdr-を合わせる))。

```bash
mkdir -p ~/ghq/github.com/Zeni-Y
cd ~/ghq/github.com/Zeni-Y
git clone https://github.com/Zeni-Y/dotfiles-nix.git
cd dotfiles-nix
```

`flake.nix` の `userInfo` をまだ設定していなければここで済ませる
(`./scripts/configure-user.sh`)。`username` は **macOS のユーザー名**
(`whoami` の出力) と一致している必要がある。ホームディレクトリは
`hosts/macbook.nix` が `/Users/<username>` として組み立てる。

---

## 3. Nix のインストール (setup.sh)

```bash
./scripts/setup.sh
```

`uname` で macOS を判定し、[Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
の macOS プランでインストールする。Linux と違って `--init-none` や
`~/.bashrc` への追記は無く、`nix-daemon` は launchd に登録される。
インストーラが `/etc/zshrc` などを書き換えるので、
**新しいターミナルを開けば** そのまま `nix` コマンドが使える。

macOS のアップデートで `/etc/zshrc` が初期化されて `nix` が見えなくなることが
あるが、Determinate installer はその復旧も面倒を見ている (→ 6 章)。

---

## 4. 初回 switch

```bash
nix run home-manager/master -- switch -b backup --flake .#zenimoto@macbook
```

`-b backup` の意味と 2 回目以降の扱いは
[README の該当節](../../README.md#-b-backup-の挙動) を参照。以降は:

```bash
home-manager switch --flake .#zenimoto@macbook   # abbr: hms (fish 上で)
```

`@macbook` は `flake.nix` の `homeConfigurations."zenimoto@macbook"` に対応する。
fish の `hms` / `hmn` などの短縮入力は `hosts/macbook.nix` の
`dotfiles.flakeHost = "macbook"` からこのキーを組み立てるので、
Linux マシンと同じ操作感で使える。

---

## 5. fish をログインシェルにする

macOS の既定シェルは zsh で、このリポジトリは zsh を管理しない。
Home Manager が入れた fish を直接ログインシェルにする:

```bash
# Home Manager の fish は ~/.nix-profile/bin/fish に symlink される。
# 実体 (Nix store のパス) は世代ごとに変わるので、symlink の方を登録する。
echo "$HOME/.nix-profile/bin/fish" | sudo tee -a /etc/shells
chsh -s "$HOME/.nix-profile/bin/fish"
```

ターミナルアプリ側で起動シェルを指定できるなら (WezTerm の `default_prog` など)、
`chsh` の代わりにそちらで fish を指定してもよい。

Linux の「bash から fish へ exec する」フック (`home/shell/bash.nix`) は
macOS でも配られるが、zsh には効かないので上記のどちらかが必要になる。

---

## 6. ハマりどころ

- **`nix` が突然見つからなくなった** — macOS のアップデートが `/etc/zshrc` を
  書き戻したのが典型。新しいターミナルでダメなら
  `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` で読み直すか、
  Determinate installer を再実行する (導入済みなら修復だけ走る)。
- **WezTerm を GUI アプリとして使いたい** — nixpkgs 版はコマンドとして入るが
  `/Applications` には現れない。Spotlight や Dock から起動したい場合は
  公式配布版を別途入れてよい。設定 (`~/.config/wezterm/wezterm.lua`) は
  Home Manager が配るものをどちらの実体も読む。
- **ssh-agent** — WSL 用の中継 (`home/wsl-ssh-agent.nix`) は macOS では
  import されない。1Password アプリの SSH agent を使う場合は
  [github-ssh.md](../git/github-ssh.md) の方針どおり `~/.ssh/config` の
  `IdentityAgent` で 1Password のソケットを指す。
- **`op` (1Password CLI)** — macOS ではデスクトップアプリ連携が使えるので、
  1Password アプリの 設定 > 開発者 で CLI 連携を有効にすれば
  Touch ID で解錠できる (WSL の `useWindowsCli` のような迂回は不要)。
