# Docker を使った動作確認

このディレクトリには **素の Ubuntu コンテナ** を立ち上げて、
リポジトリのセットアップ手順 (`scripts/setup.sh` など) を
実機さながらに試すための環境が含まれています。

> **対象**: `homeConfigurations."zenimoto@ubuntu"` (Linux / Home Manager)
> macOS (nix-darwin) の設定は Linux コンテナで評価できないため、対象外です。

> Nix はイメージにプリインストールしません。
> コンテナ内で `scripts/setup.sh` を走らせることで、
> 実際のインストール手順を毎回まっさらな状態から検証できます。

---

## 前提

- Docker がインストールされていること ([Docker Desktop](https://www.docker.com/products/docker-desktop/) または Docker Engine)
- コマンドはすべて **リポジトリルート** から実行します

```bash
cd /path/to/dotfiles-nix   # リポジトリルートに移動
```

---

## ファイル構成

```
docker/
├── Dockerfile   素の Ubuntu 24.04 (nix なし、ユーザー作成のみ)
├── run.sh       マウント + GITHUB_TOKEN つきで起動するラッパー
└── README.md    このファイル
.dockerignore    ビルドコンテキストの除外設定 (リポジトリルート)
```

---

## クイックスタート

ホスト側のリポジトリをマウントしてコンテナに入るのが標準ワークフローです。
`docker/run.sh` は初回呼び出し時にイメージが無ければ自動でビルドします。

```bash
./docker/run.sh
```

これは内部的に以下を実行しています:

```bash
docker run --rm -it \
  -v "$(pwd):/home/zenimoto/dotfiles-nix" \
  -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  dotfiles-nix-test
```

| 設定 | 内容 |
|---|---|
| `-v $(pwd):...` | ホストのリポジトリを `~/dotfiles-nix` にマウント。編集はそのまま反映される |
| `-e GITHUB_TOKEN` | ホストの `GITHUB_TOKEN` をコンテナにそのまま引き継ぐ (private repo / gh CLI 用) |
| `--rm -it` | 終了時にコンテナを破棄、対話シェルとして起動 |

### 別コマンドを直接実行する

`run.sh` の引数はそのままコンテナに渡されます。

```bash
./docker/run.sh ./scripts/setup.sh           # セットアップを一発実行
./docker/run.sh bash -c 'nix --version'      # 任意のコマンド
```

### イメージを手動でビルドし直す

```bash
docker build -f docker/Dockerfile -t dotfiles-nix-test .
```

Dockerfile が行うのは以下だけです:

- Ubuntu 24.04 をベースにする
- `curl`, `git`, `sudo` など最低限のパッケージを入れる
- `zenimoto` ユーザー (passwordless sudo 付き) を作成する

---

## 典型的な検証フロー

```bash
# 1. ホスト側でトークンをセット (private repo を clone する場合など)
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# 2. コンテナに入る
./docker/run.sh

# --- ここから先はコンテナ内 ---

# 3. セットアップスクリプトを実行 (Nix を入れる)
./scripts/setup.sh

# 4. PATH を読み込んで Nix を使う
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 5. flake / Home Manager を試す
nix flake metadata
nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw
nix build '.#homeConfigurations."zenimoto@ubuntu".activationPackage'

# 6. 実際に適用してみる (フルテスト)
nix run home-manager -- switch --flake '.#zenimoto@ubuntu'
fish --version
```

> **注意**: マウントしたファイルはコンテナ内から書き込み可能なため、
> `flake.lock` などが更新されることがあります。

---

## よくあるエラーと対処

### `error: flake 'path:...' does not provide attribute`

`flake.nix` のユーザー名と Dockerfile の `ARG USERNAME` が一致していない場合に発生します。

```bash
grep 'username' flake.nix
grep 'ARG USERNAME' docker/Dockerfile
```

### `GITHUB_TOKEN` がコンテナ内で空

ホスト側のシェルで `export` されているか確認してください。

```bash
echo "${GITHUB_TOKEN:0:4}..."   # ホスト側
./docker/run.sh bash -c 'echo "${GITHUB_TOKEN:0:4}..."'
```

### ビルドが非常に遅い (Nix インストール後)

`cache.nixos.org` への接続を確認してください。
Docker Desktop の場合、DNS 設定が原因でキャッシュにアクセスできないことがあります。

```bash
# コンテナ内で確認
nix store ping --store https://cache.nixos.org
```

---

## Docker を使わない確認方法 (参考)

実際の Ubuntu / macOS 環境がある場合は Docker 不要です。

```bash
nix flake check
nix build '.#homeConfigurations."zenimoto@ubuntu".activationPackage'
nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw
```
