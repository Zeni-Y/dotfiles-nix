# リモート接続先の Ubuntu でのセットアップ

対象は **SSH で入って使う素の Ubuntu** (実マシン / VM / 共有サーバ)。
Windows 上に作るなら [wsl2.md](./wsl2.md)、使い捨ての検証なら
[docker/](../../docker/) を使う。

WSL2 との一番の違いは SSH まわり:

- **秘密鍵をリモートに置かない。** 手元 (WSL2) の 1Password agent を
  agent forwarding で持ち込む (→ [5 章](#5-ssh-agent--鍵はリモートに置かない))
- systemd は普通の Ubuntu なら最初から動いているので、WSL のような
  有効化手順 (wsl2.md 3 章) は要らない

## 目次

1. [前提の確認](#1-前提の確認)
2. [リポジトリの配置](#2-リポジトリの配置)
3. [Nix のインストール (setup.sh)](#3-nix-のインストール-setupsh)
4. [初回 switch](#4-初回-switch)
5. [SSH agent — 鍵はリモートに置かない](#5-ssh-agent--鍵はリモートに置かない)
6. [ハマりどころ](#6-ハマりどころ)

---

## 1. 前提の確認

```bash
sudo -v                        # sudo が使えること (無い環境はサポート外 → README)
systemctl is-system-running    # running / degraded なら OK
```

`degraded` はどれかのサービスが失敗しているだけで、Nix には影響しない。
`offline` や `command not found` なら systemd が動いていないので、
[setup.sh の `--init-none` 経路](../../README.md#前提ソフトウェアのインストール)になる
(コンテナ以外でそうなることはまず無い)。

---

## 2. リポジトリの配置

ghq の標準レイアウトに置く。worktree を同じ root に集約するため、
この階層でなければならない (→ [git-worktree.md 7 章](../git/git-worktree.md#7-集約派で揃える--gwq-と-herdr-を合わせる))。

```bash
sudo apt-get update && sudo apt-get install -y git curl ca-certificates
mkdir -p ~/ghq/github.com/Zeni-Y
cd ~/ghq/github.com/Zeni-Y
git clone https://github.com/Zeni-Y/dotfiles-nix.git
cd dotfiles-nix
```

clone は **HTTPS でよい**。鍵をまだ持ち込んでいない段階でも通るし、
push は `home/git.nix` の `pushInsteadOf` が SSH に読み替えるので、
agent forwarding (5 章) さえ効いていればそのまま push できる。

---

## 3. Nix のインストール (setup.sh)

```bash
./scripts/setup.sh
```

**出力の最初の行を必ず確認する。**

```
==> sudo + systemd を検出しました → 通常の Nix をインストールします
```

これが出れば通常経路。`systemd が無い環境を検出しました` と出たら
1 章に戻って systemd の状態を確認する。インストール後:

```bash
exec bash
nix --version
```

---

## 4. 初回 switch

`flake.nix` の `userInfo` を確認する。**`username` はそのマシンの
OS ユーザー名と一致している必要がある** (`home.homeDirectory` の導出元)。
`windowsUsername` はリモートでは触らなくてよい — Windows agent への中継
(`home/wsl-ssh-agent.nix`) は npiperelay が見つからないホストでは
自動でスキップされる。

```bash
$EDITOR flake.nix    # 必要なら username / gitName / gitEmail を直す
```

適用する。**初回は `-b backup` が必須**
(理由と挙動は [README の「-b backup の挙動」](../../README.md#-b-backup-の挙動))。

```bash
nix run home-manager/master -- switch -b backup --flake '.#zenimoto@ubuntu'
```

終わったら新しいシェルを開き、fish + pure プロンプトになれば成功。
以降は [README の「日々の運用」](../../README.md#日々の運用) に合流する
(`hms` はリポジトリに cd してから)。

---

## 5. SSH agent — 鍵はリモートに置かない

リモートに秘密鍵を作らず、**手元の agent を forwarding で持ち込む**。
手元が WSL2 なら鍵は 1Password が持っている
(→ [wsl2.md 7-4 章](./wsl2.md#74-ssh-agent-を-windows-側に一本化する-任意))。

手元の `~/.ssh/config` で対象ホストに `ForwardAgent yes` を付けるか、
都度 `ssh -A` で入る。リモート側で確認:

```bash
ssh-add -l    # 手元の鍵一覧が見えれば forwarding が効いている
```

再接続すると転送ソケット (`SSH_AUTH_SOCK`) のパスは毎回変わるが、
herdr 内のペインには `home/herdr.nix` の固定パス機構
(`~/.ssh/ssh_auth_sock`) が新しいソケットを届けるので、
開きっぱなしのペインもそのまま使える。

---

## 6. ハマりどころ

- **`ssh-add -l` が `Error connecting to agent`**。
  `-A` を付け忘れたか、`ForwardAgent yes` が対象ホストに効いていない。
  サーバ側で `AllowAgentForwarding no` になっている場合もある
  (`sshd_config` を確認)。
- **herdr の古いペインだけ agent が効かない**。
  固定パスの symlink が古い。herdr の外で新しいシェルを 1 つ開くと
  張り直される (→ `home/herdr.nix` のコメント)。
- **`nix-daemon` が落ちている / `big-lock: Permission denied`**。
  `sudo systemctl start nix-daemon`。詳細は
  [README の「既知のハマりどころ」](../../README.md#既知のハマりどころ)。
