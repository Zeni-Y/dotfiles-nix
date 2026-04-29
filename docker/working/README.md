# Docker 開発環境

SSH でアクセスできる Ubuntu 開発コンテナ。dotfiles は chezmoi で手動セットアップする。

## 設計方針

- **ベースイメージ**: `ubuntu:24.04`（CUDA イメージ不要。PyTorch は pip 同梱の CUDA ランタイムを使用）
- **dotfiles 展開**: コンテナ起動後に手動で `chezmoi init --apply` を実行する
- **SSH 鍵管理**: SSH agent forwarding を利用。秘密鍵・公開鍵はコンテナに配置しない
- **chezmoi 管理外**: `docker/` ディレクトリ自体は chezmoi の管理対象外

## ファイル構成

| ファイル     | 役割                                              |
| ------------ | ------------------------------------------------- |
| `Dockerfile` | ubuntu ベースイメージ + 最小パッケージ + SSH 設定 |
| `Makefile`   | build / run / clean 等のタスク定義                |

## セットアップ手順

### イメージビルド

```bash
cd docker/
make build
```

`$USER_working_image` という名前のイメージが作成される。`--build-arg` でホストの UID/GID を引き継ぐため、マウントしたファイルの権限問題が起きない。

### コンテナ起動

```bash
make run
```

`-d` でバックグラウンド起動し、PID 1 として `sshd -D` が常駐するため、ホスト側から **いつでも SSH 接続できる状態が維持される**。`--restart unless-stopped` を付けているので Docker / ホスト再起動後も自動復帰する。

GPU は `nvidia-smi` がホストにある場合のみ `--gpus all` が自動付与される（Mac では自動で外れる）。

### コンテナに入る

bash で直接入る（`exit` してもコンテナは停止しない）:

```bash
make shell
```

### dotfiles と SSH 鍵のセットアップ

初回のみ `make shell` で入って chezmoi を適用する。chezmoi で `~/.ssh/authorized_keys` が展開されるので、これ以降ホストから SSH 接続できる:

```bash
chezmoi init --apply Zeni-Y
```

### SSH 接続

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
| dotfiles        | なし（手動設定）                       | chezmoi で手動セットアップ         |
| chezmoi         | コンテナにインストール済み             | なし（手動インストール）           |
| entrypoint.sh   | chezmoi 自動適用 + SSH 起動            | 廃止（ENTRYPOINT で SSH のみ起動） |
| ユーザー認証    | パスワード (`chpasswd`)                | sudo NOPASSWD（パスワードなし）    |
| 起動モード      | `-itd` (デタッチ) + SSH 接続           | `-d` (バックグラウンド常駐) + SSH  |
| `.ssh` マウント | ホストからマウント                     | 不要（SSH agent forwarding）       |
| ホームマウント  | `$HOME` 全体                           | `$HOME` → `/home/$USER/host`       |
