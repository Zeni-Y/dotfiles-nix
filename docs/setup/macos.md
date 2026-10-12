# macOS (Apple Silicon) でのセットアップ

対象は **手元の MacBook (aarch64-darwin)**。Ubuntu と同じく
**standalone Home Manager で `~/` だけを管理する**。nix-darwin は使わない。

Linux との違いは次の 4 点だけで、あとは `home/` のモジュールを共有している。

| 違い | どこで吸収しているか |
| --- | --- |
| ログインシェルが zsh | `home/darwin.nix` の `programs.zsh` (対話 zsh なら fish に exec) |
| WezTerm がこのマシン上で描画する (フォントが要る) | `home/darwin.nix` で Nerd Font を入れる |
| C コンパイラは Xcode CLT の clang | `home/packages.nix` で gcc を Linux 限定にしている |
| WSL の ssh-agent 中継は無関係 | `hosts/macbook.nix` で `wsl.windowsUsername` を設定しない (= 無効) |

## 目次

1. [前提の確認](#1-前提の確認)
2. [Nix のインストール](#2-nix-のインストール)
3. [初回 switch](#3-初回-switch)
4. [何が置き換わるか](#4-何が置き換わるか)
5. [ハマりどころ](#5-ハマりどころ)

---

## 1. 前提の確認

```bash
xcode-select -p   # /Library/Developer/CommandLineTools が出れば OK
sudo -v           # 管理者ユーザであること
```

CLT が無ければ `xcode-select --install`。git と clang はここから来る。

## 2. Nix のインストール

```bash
./scripts/setup.sh
```

最初の行に `macOS を検出しました → 通常の Nix をインストールします` と出る。
中身は Determinate Systems の installer (`install` プラン) で、`/nix` 用の
APFS ボリュームと launchd の nix-daemon を作る。`/etc/zshrc` に読み込みが
足されるので、**新しいターミナルを開いてから** `nix --version` で確認する。

## 3. 初回 switch

リポジトリはどこに clone してもよいが、`hmn` / `hmg` / `nfc` などの短縮入力は
`~/ghq/github.com/Zeni-Y/dotfiles-nix` を前提にしている (home/shell/fish.nix の
`flakeDir`)。`hms` だけはカレントディレクトリの flake を使う。

```bash
cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
nix run home-manager/master -- switch -b backup --flake .#zenimoto@macbook
```

`-b backup` は初回だけ付ける。素の macOS でも `~/.zshrc` と
`~/.config/gh/config.yml` (gh を Homebrew で入れて一度でも使った場合) が
既にあり、付けないと `Existing file ... would be clobbered` で止まる。
元のファイルは `*.backup` として残る。2 回目以降は fish の `hms` で足りる。

## 4. 何が置き換わるか

- **`~/.zshrc`** は Home Manager の生成物になる。元の `~/.zshrc` にあった
  `~/.local/bin` と `~/.unity/bin` の PATH 追加は `home/darwin.nix` の
  `home.sessionPath` に移してある。ほかに書き足していたものがあれば、
  `~/.zshrc.backup` を見て `home/darwin.nix` に移す。
- **`~/.zprofile`** は管理しない。Homebrew の `brew shellenv` はそのまま効き、
  exec した fish に PATH が引き継がれる。
- **WezTerm.app** は `~/Applications/Home Manager Apps/` にコピーされ、
  Spotlight から起動できる (stateVersion 25.11 以降の copyApps)。
- **フォント** は `~/Library/Fonts/HomeManager/` にコピーされる。
- Homebrew で入れた gh などは残るが、fish では Nix 版が PATH の先に来る。

## 5. ハマりどころ

- **ログインシェルは zsh のまま。** `chsh -s` で fish にしない。Nix store の
  fish を `/etc/shells` に足す (システム領域を触る) ことになるのと、fish を
  壊したときに素の zsh に戻れなくなるため。zsh で入りたいときは `zsh -f`。
- **macOS のアップデート後に `nix` が見つからない。** アップデートで
  `/etc/zshrc` が初期化されることがある。Determinate の installer は
  これを自動で直すが、直らないときは `/nix/nix-installer repair`。(未確認)
