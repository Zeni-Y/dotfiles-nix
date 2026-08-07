# Docker 開発環境

SSH でアクセスできる Ubuntu 開発コンテナ。dotfiles は **Nix (Flakes + Home Manager)** で
セットアップする。イメージには Nix を焼き込まず、**コンテナに入ってから**
`scripts/setup.sh` と `home-manager switch` を実行する。

## 設計方針

- **ベースイメージ**: `ubuntu:24.04`（CUDA イメージ不要。PyTorch は pip 同梱の CUDA ランタイムを使用）
- **dotfiles 展開**: コンテナ起動後に手動で Nix を入れ、Home Manager を適用する
  （イメージビルド時には何もしない。ビルドを軽く保ち、flake の更新をイメージ再ビルドなしで取り込める）
- **SSH 鍵管理**: SSH agent forwarding を利用。秘密鍵はコンテナに配置しない。
  `authorized_keys` は起動時に `entrypoint.sh` が `https://github.com/<GITHUB_USER>.keys` から取得する
- **ユーザー名**: コンテナ内のユーザー名は `flake.nix` の `userInfo.username`（既定 `zenimoto`）と
  揃える必要がある。Home Manager の `homeConfigurations` が `/home/<username>` を前提にするため

## ファイル構成

| ファイル        | 役割                                                        |
| --------------- | ----------------------------------------------------------- |
| `Dockerfile`    | ubuntu ベースイメージ + 最小パッケージ + SSH 設定           |
| `entrypoint.sh` | GitHub から `authorized_keys` を取得して `sshd` を foreground 実行 |
| `Makefile`      | build / run / clean 等のタスク定義                          |

## セットアップ手順

### イメージビルド

```bash
cd docker/working/
make build
```

`$USER_working_image` という名前のイメージが作成される。`--build-arg` でホストの UID/GID を引き継ぐため、マウントしたファイルの権限問題が起きない。

コンテナ内のユーザー名は既定でホストの `$USER` を引き継ぐ。`flake.nix` の
`userInfo.username` と違う場合は `USERNAME` を明示する:

```bash
make build USERNAME=zenimoto
make run   USERNAME=zenimoto
```

### コンテナ起動

```bash
make run
```

`make run` はコンテナ名とホスト側 SSH ポートを対話的に尋ねる。

```
コンテナ名を入力してください [zenimoto_working_container]:
ホスト側 SSH ポート番号を入力してください [2222]:
```

- そのまま Enter を押すと `[...]` の既定値を使う。既定値が既に使われている場合は、
  空いている候補（`..._2`、次の空きポート）が既定値として提示される
- 入力した名前が既存コンテナ（停止中も含む）と重複する場合、または入力したポートが
  既に LISTEN 中の場合は、その旨を表示して入力し直しを求める
- 尋ねずに起動したいときは値を明示するか `NO_PROMPT=1` を付ける:

```bash
make run SSH_PORT=3333            # ポートは尋ねない
make run CONTAINER_NAME=foo       # 名前は尋ねない
make run NO_PROMPT=1              # 何も尋ねない（CI などの非対話環境向け）
```

既定以外の名前 / ポートで起動したコンテナを操作するときは、`shell` / `ssh` / `stop` /
`rm` / `logs` / `restart` にも同じ変数を渡す:

```bash
make shell CONTAINER_NAME=foo
make ssh   SSH_PORT=3333
```

`-d` でバックグラウンド起動し、`sshd -D` が常駐するため、ホスト側から **いつでも SSH 接続できる状態が維持される**。`--restart unless-stopped` を付けているので Docker / ホスト再起動後も自動復帰する。

`--init` を付けているので PID 1 は tini になり、`sshd` はその子として動く。SSH セッションが残すゾンビプロセスの刈り取りと、`docker stop` のシグナル転送を tini に任せられる。

GPU は `nvidia-smi` がホストにある場合のみ `--gpus all` が自動付与される。

### コンテナに入る

bash で直接入る（`exit` してもコンテナは停止しない）:

```bash
make shell
```

### dotfiles (Nix + Home Manager) のセットアップ

初回のみ `make shell` で入って Nix を入れ、Home Manager を適用する。
イメージには Nix が入っていないので、**この手順はコンテナの中で実行する**。

```bash
make shell   # コンテナ内へ

# 1. リポジトリを取得する
#    ~/ghq はホストからマウントされているので、ホスト側に既に clone 済みなら
#    その場所をそのまま使えばよい（改めて clone する必要はない）
git clone https://github.com/Zeni-Y/dotfiles-nix.git ~/dotfiles-nix
cd ~/dotfiles-nix

# 2. Nix をインストールする（Determinate Nix Installer）
#    コンテナには systemd が無いので setup.sh は自動で
#    `linux --init none` プランに切り替わり、~/.bashrc に
#    nix-daemon の起動スニペットを追記する
./scripts/setup.sh

# 3. 新しいシェルに切り替えて PATH と nix-daemon を有効にする
exec bash

# 4. Home Manager を適用する（初回は必ず -b backup を付ける）
nix run home-manager/master -- switch -b backup --flake '.#zenimoto@ubuntu'

# 5. 以降は PATH に入った home-manager を直接使う
home-manager switch --flake '.#zenimoto@ubuntu'
```

`-b backup` の意味や 2 回目以降の注意点は
[トップ README](../../README.md#-b-backup-の挙動) を参照。
Nix / Home Manager 周りのエラーは
[docker/debug/README.md の「よくあるエラーと対処」](../debug/README.md#よくあるエラーと対処) にまとまっている。

コンテナを作り直すと `/nix` も消えるので、この手順は再実行が必要になる。
`~/ghq` や `~/.cache` はホストからマウントされているため、
clone とビルドキャッシュ（Nix store は含まない）は残る。

### SSH 接続

`authorized_keys` はコンテナ起動時に `entrypoint.sh` が
`https://github.com/$GITHUB_USER.keys` から取得する（既定 `GITHUB_USER=Zeni-Y`）。
鍵を足したり消したりしたときは GitHub 側で編集して `make restart` すればよい。
dotfiles のセットアップが済んでいなくても SSH では入れる。

agent forwarding 付きでログイン:

```bash
make ssh
# または
ssh -A -p 2222 $USER@localhost
```

### ログ確認 / 再起動

```bash
make logs       # sshd のログを追跡
make restart    # 再起動（コンテナ設定は維持）
make stop       # 停止
```

### GPU 動作確認

```bash
make gpu-test
```

## 主な変更点（旧構成からの移行）

| 項目            | 旧                                     | 新                                 |
| --------------- | -------------------------------------- | ---------------------------------- |
| ベースイメージ  | `nvidia/cuda:12.2.0-devel-ubuntu22.04` | `ubuntu:24.04`                     |
| SSH             | openssh-server + ポートフォワード      | SSH agent forwarding               |
| dotfiles        | なし（手動設定）                       | Nix Flakes + Home Manager          |
| dotfiles 適用   | イメージビルド時                       | コンテナ内で `setup.sh` → `home-manager switch` |
| entrypoint.sh   | dotfiles 自動適用 + SSH 起動           | GitHub から鍵を取得して sshd 起動  |
| ユーザー認証    | パスワード (`chpasswd`)                | sudo NOPASSWD（パスワードなし）    |
| 起動モード      | `-itd` (デタッチ) + SSH 接続           | `-d` (バックグラウンド常駐) + SSH  |
| `.ssh` マウント | ホストからマウント                     | 不要（SSH agent forwarding）       |
| ホームマウント  | `$HOME` 全体                           | `$HOME` → `/home/$USER/host`       |
