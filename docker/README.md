# Docker を使った動作確認

このディレクトリには Ubuntu コンテナ上で
dotfiles-nix の Nix 設定が正しく評価・ビルドできるかを
確認するための環境が含まれています。

> **対象**: `homeConfigurations."zenimoto@ubuntu"` (Linux / Home Manager)  
> macOS (nix-darwin) の設定は Linux コンテナで評価できないため、対象外です。

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
├── Dockerfile   Ubuntu + Nix のテスト環境
├── test.sh      テストスクリプト (3 ステップ)
└── README.md    このファイル
.dockerignore    ビルドコンテキストの除外設定 (リポジトリルート)
```

---

## クイックスタート

### 1. イメージをビルドする

```bash
docker build -f docker/Dockerfile -t dotfiles-nix-test .
```

Dockerfile が行うこと:

| ステップ | 内容 |
|---|---|
| Ubuntu 24.04 をベースにする | |
| `zenimoto` ユーザーを作成 | `flake.nix` の `userInfo.username` と一致させる |
| Nix をシングルユーザーモードでインストール | `--no-daemon` でデーモン不要 |
| Flakes を有効化 | `~/.config/nix/nix.conf` に追記 |
| dotfiles をコンテナにコピー | |

#### Nix シングルユーザーモード (`--no-daemon`) とは

Nix のインストールには **マルチユーザーモード** と **シングルユーザーモード** の 2 種類があります。

| モード | 仕組み | 主な用途 |
|---|---|---|
| マルチユーザー (通常デフォルト) | `nix-daemon` が root 権限で `/nix/store` を管理 | 通常の Linux / macOS 環境 |
| シングルユーザー (`--no-daemon`) | ユーザー自身が直接 `/nix/store` に書き込む | Docker など |

Docker コンテナには `systemd` や `launchd` などのサービスマネージャーが存在しないため、
`nix-daemon` プロセスを起動できません。
`--no-daemon` を指定することで、デーモンなしでも Nix が動作する **シングルユーザーモード** でインストールされます。

> **注意**: シングルユーザーモードでは `/nix/store` の所有者がそのユーザーになります。
> 複数ユーザーが共有するサーバーには適しませんが、Docker の 1 ユーザー環境では問題ありません。

#### Flakes の有効化 (`experimental-features`) とは

Flakes は Nix の**再現性を高める仕組み**で、`flake.nix` と `flake.lock` を組み合わせて
依存パッケージのバージョンを完全に固定します。このリポジトリの設定はすべて Flakes の上に成り立っています。

2024 年時点で Flakes は公式には「実験的機能」扱いのため、デフォルトでは無効です。
`~/.config/nix/nix.conf` に以下を追記することで有効化されます。

```
experimental-features = nix-command flakes
```

| 機能名 | 内容 |
|---|---|
| `nix-command` | 新しい統合 CLI (`nix build`, `nix eval`, `nix flake` など) を有効化 |
| `flakes` | `flake.nix` / `flake.lock` によるパッケージ管理を有効化 |

> **補足**: 通常の macOS / Linux 環境でも、同じ設定が必要です。
> Flakes の詳細は `docs/nix-concepts.md` を参照してください。

> **初回ビルド時間の目安**: 約 2〜5 分 (Nix のダウンロードを含む)

### 2. テストを実行する

```bash
docker run --rm dotfiles-nix-test
```

テストは 3 ステップで構成されています:

```
[1/3] flake の入力を確認
      └─ flake.nix が正しく読み込めるか (nixpkgs, home-manager の存在確認)

[2/3] Ubuntu 設定を評価
      └─ home.stateVersion / programs.neovim.enable / programs.fish.enable を取得

[3/3] activationPackage をビルド
      └─ home-manager switch 相当のパッケージを実際にビルド
         (パッケージは cache.nixos.org から取得するため通常コンパイル不要)
```

> **テスト 3 の所要時間**: nixpkgs のダウンロードが発生する初回は **5〜20 分** かかることがあります。
> キャッシュが利く 2 回目以降は大幅に短縮されます。

---

## インタラクティブシェルで確認する

テストを自動実行せず、コンテナの中に直接入って手動で確認したい場合:

```bash
docker run --rm -it dotfiles-nix-test bash
```

コンテナ内で使えるコマンド例:

```bash
# Nix 環境を読み込む (ログインシェルでない場合は必要)
. ~/.nix-profile/etc/profile.d/nix.sh

# flake の outputs を確認
nix flake show

# Ubuntu 設定を評価してみる
nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw

# activationPackage をビルドして中身を確認
nix build '.#homeConfigurations."zenimoto@ubuntu".activationPackage'
ls -la result/  # ビルド結果のシンボリックリンク

# home-manager switch を実際に実行する (フルテスト)
nix run home-manager -- switch --flake '.#zenimoto@ubuntu'
fish --version   # fish がインストールされたか確認
git --version
```

---

## コードを変更しながら確認する

設定を変更するたびにイメージを再ビルドするのは時間がかかります。
ホスト側のファイルをマウントすることで、変更をすぐに反映できます。

```bash
# リポジトリをマウントしてインタラクティブに入る
docker run --rm -it \
  -v "$(pwd):/home/zenimoto/dotfiles-nix" \
  dotfiles-nix-test bash

# コンテナ内で Nix を読み込み、評価を試す
. ~/.nix-profile/etc/profile.d/nix.sh
cd ~/dotfiles-nix
nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw
```

> **注意**: マウントしたファイルはコンテナ内から書き込み可能なため、
> `flake.lock` などが更新されることがあります。

---

## テスト結果の見方

### 成功時

```
════════════════════════════════════════
 dotfiles-nix テスト (Ubuntu)
════════════════════════════════════════

[1/3] flake の入力を確認
✓ nixpkgs が inputs に含まれています
✓ home-manager が inputs に含まれています

[2/3] Ubuntu 設定を評価 (home.stateVersion)
✓ home.stateVersion = 24.11
✓ programs.neovim.enable = true
✓ programs.fish.enable = true

[3/3] activationPackage をビルド
    nixpkgs を取得中... (初回は数分かかります)
✓ ビルド成功

════════════════════════════════════════
 ✓ すべてのテストが通過しました
════════════════════════════════════════
```

### よくあるエラーと対処

#### `error: flake 'path:...' does not provide attribute`

`flake.nix` のユーザー名と Dockerfile の `ARG USERNAME` が一致していない場合に発生します。

```bash
# flake.nix の userInfo.username を確認
grep 'username' flake.nix

# Dockerfile の ARG USERNAME と一致しているか確認
grep 'ARG USERNAME' docker/Dockerfile
```

#### `error: reading file '/nix/store/...'` / `Permission denied`

`/nix` が正しく作成されていない可能性があります。
`--no-daemon` インストールが正常に完了しているか確認してください。

```bash
# コンテナ内で確認
docker run --rm -it dotfiles-nix-test bash
ls /nix/store | head -5
```

#### `error: attribute 'fishPlugins' missing`

nixpkgs のバージョンが古い可能性があります。`flake.lock` を更新してください。

```bash
# ホスト側で実行
nix flake update
git add flake.lock
git commit -m "chore: update flake.lock"
# イメージを再ビルド
docker build -f docker/Dockerfile -t dotfiles-nix-test .
```

#### ビルドが非常に遅い

`cache.nixos.org` への接続を確認してください。
Docker Desktop の場合、DNS 設定が原因でキャッシュにアクセスできないことがあります。

```bash
# キャッシュが使えているか確認 (コンテナ内)
. ~/.nix-profile/etc/profile.d/nix.sh
nix store ping --store https://cache.nixos.org
```

---

## Docker を使わない確認方法 (参考)

実際の Ubuntu / macOS 環境がある場合は Docker 不要です。

```bash
# flake の構文エラーを確認
nix flake check

# Ubuntu 設定だけをビルド (macOS 上でも Linux 設定をチェックできる)
nix build '.#homeConfigurations."zenimoto@ubuntu".activationPackage'

# 評価結果を確認
nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw
```
