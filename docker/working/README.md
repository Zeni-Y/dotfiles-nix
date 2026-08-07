# Docker 開発環境

SSH でアクセスできる Ubuntu 開発コンテナ。**Nix (Flakes + Home Manager) と dotfiles を
イメージに焼き込む**ので、コンテナを起動した時点で fish / neovim / claude-code などが
揃っている。コンテナを作り直しても中でのセットアップ作業は不要。

## 設計方針

- **ベースイメージ**: `ubuntu:24.04`（CUDA イメージ不要。PyTorch は pip 同梱の CUDA ランタイムを使用）
- **パッケージは可能な限り Nix で管理する**。apt で入れるのは Nix より前に必要なもの
  （`ca-certificates` / `curl`）、setuid が要るもの（`sudo`）、root のシステムサービス
  （`openssh-server`）、glibc のロケール生成（`locales`）の4種類だけ。
  開発用ツールは `home/packages.nix` ほかで Nix 管理する
- **dotfiles 展開**: イメージビルド時に Home Manager の activation まで済ませる
  （`docker/working_nixos` と同じ方針）。flake だけ更新したいときは `make switch`
- **systemd は無い**ので、`nix-daemon` は `entrypoint.sh` が起動する
- **SSH 鍵管理**: SSH agent forwarding を利用。秘密鍵はコンテナに配置しない。
  `authorized_keys` は起動時に `entrypoint.sh` が `https://github.com/<GITHUB_USER>.keys` から取得する
- **ユーザー名**: コンテナ内のユーザー名は `flake.nix` の `userInfo.username`（既定 `zenimoto`）と
  揃える必要がある。Home Manager の `homeConfigurations` が `/home/<username>` を前提にするため

## ファイル構成

| ファイル             | 役割                                                                       |
| -------------------- | -------------------------------------------------------------------------- |
| `Dockerfile`         | ubuntu + 最小 apt + SSH 設定 + Nix のインストール + dotfiles の焼き込み    |
| `bake-dotfiles.sh`   | ビルド時に `nix-daemon` を上げてユーザー権限で Home Manager を適用する     |
| `entrypoint.sh`      | `nix-daemon` 起動 → `authorized_keys` 取得 → `sshd` 前面実行               |
| `Makefile`           | build / run / switch / clean 等のタスク定義                                |

## セットアップ手順

### イメージビルド

```bash
cd docker/working/
make build
```

`$USER_working_image` という名前のイメージが作成される。`--build-arg` でホストの UID/GID を引き継ぐため、マウントしたファイルの権限問題が起きない。

ビルドは Nix のインストールと Home Manager の適用まで走るので、**初回は数十分**かかる
（バイナリキャッシュに無いものはローカルでビルドされる）。2 回目以降は Docker の
レイヤキャッシュが効き、`home/` 以下を触ったときだけ dotfiles のレイヤが作り直される。
`flake.lock` を触っていなければ nixpkgs の再取得も起きない。

Dockerfile 自体をいじっていて素早く回したいときは、dotfiles の焼き込みを飛ばせる:

```bash
make build BAKE_DOTFILES=0   # 数分で終わる。Nix は入るが dotfiles は未適用
```

ビルドコンテキストはリポジトリルート（`Makefile` が `-f` 付きで `../..` を渡す）。
dotfiles をイメージに取り込むためで、`make build` を使う限り意識しなくてよい。

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

### dotfiles (Nix + Home Manager) の更新

**セットアップ作業は不要**。Nix も dotfiles もイメージに焼き込んであるので、
`make run` した時点で fish / neovim / claude-code などが使える。
コンテナを作り直しても `/nix` はイメージ側にあるため、やり直しは発生しない。

flake や `home/` 以下を更新したときの反映方法は2通り:

```bash
# A. コンテナ内のリポジトリから再適用する（速い。イメージは古いまま）
make switch

# B. イメージごと作り直す（イメージも最新になる）
make build && make rm && make run
```

`make switch` はイメージに焼き込んだ `/home/$USER/dotfiles-nix` を使う。
ホストの `~/ghq` に clone 済みのものを使いたいときは:

```bash
make switch REPO=/home/$USER/ghq/github.com/Zeni-Y/dotfiles-nix
```

Nix / Home Manager 周りのエラーは
[docker/debug/README.md の「よくあるエラーと対処」](../debug/README.md#よくあるエラーと対処) にまとまっている。

なお `scripts/setup.sh` はコンテナでは使わない（イメージビルド時に
Determinate Nix Installer を `linux --init none` プランで実行済み）。
生の Ubuntu マシンに Nix を入れるときのスクリプトとして残してある。

### パッケージを足したいとき

**まず `home/packages.nix` に足して `make switch`** を試す。apt は
「Nix に無い」「FHS 前提のシステムライブラリが要る」場合の逃げ道として使う:

```bash
sudo apt-get update && sudo apt-get install -y <package>
```

apt で入れたものはコンテナを作り直すと消えるので、常用するなら
`home/packages.nix` に移すか、`Dockerfile` の apt 行に足すこと。

C 拡張のビルドで詰まる場合、まず Nix 側の `gcc` / `pkg-config`
（`home/packages.nix`）が使われているか確認する。システムヘッダとの
組み合わせが必要なら `sudo apt-get install build-essential` が確実。

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
