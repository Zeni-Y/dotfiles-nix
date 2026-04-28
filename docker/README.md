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

このコンテナの `zenimoto` ユーザーには passwordless sudo が付いているため、
`scripts/setup.sh` を引数なしで呼ぶと auto モードで **通常の Nix** が入ります。
実機の sudo なし環境 (CI / 共有サーバー / SSH 先など) でも動かすことを
想定しているので、まず **nix-portable で検証** してから、続けて
通常の Nix 経路を確認するのが推奨ワークフローです。

### 1. nix-portable で検証 (sudo を使わない経路)

```bash
# 1. ホスト側でトークンをセット (private repo を clone する場合など)
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# 2. コンテナに入る
./docker/run.sh

# --- ここから先はコンテナ内 ---

# 3. nix-portable をダウンロード (~/.local/bin/nix-portable)
./scripts/setup.sh --portable

# 4. setup.sh が ~/.bashrc に追記した PATH を反映する
exec bash               # 新しい対話シェルに置き換える
# あるいは現在のシェルに読み込みたいなら:
#   . ~/.bashrc

which nix-portable      # → /home/zenimoto/.local/bin/nix-portable

# 5. flake / Home Manager を試す
nix-portable nix flake metadata
nix-portable nix eval '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' --raw
nix-portable nix build '.#homeConfigurations."zenimoto@ubuntu".activationPackage'

# 6. 実際に適用してみる (フルテスト)
nix-portable nix run home-manager/master -- switch --flake '.#zenimoto@ubuntu'
fish --version
```

> 普段使いするなら `alias nix='nix-portable nix'` を張っておくと楽です。

### 2. 通常の Nix で検証 (sudo あり)

```bash
# 1. ホスト側でトークンをセット (private repo を clone する場合など)
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# 2. コンテナに入る (portable 経路と別の状態で試したい場合は
#    一度コンテナを抜けて再起動するとクリーンな状態になる)
./docker/run.sh

# --- ここから先はコンテナ内 ---

# 3. セットアップスクリプトを実行 (Determinate Nix Installer)
./scripts/setup.sh
# あるいは明示的に: ./scripts/setup.sh --system

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

### `error: opening lock file "/nix/var/nix/db/big-lock": Permission denied`

`scripts/setup.sh` のあと `nix` を実行した際に出る。**`nix-daemon`
がまだ起動していない**のが原因。このコンテナは systemd を持たないので
daemon は自動起動しない。インストール直後の出力どおり手で立ち上げる:

```bash
sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
pgrep -x nix-daemon   # 起動確認
```

毎回打つのが面倒なら `~/.bashrc` 末尾に以下を追記しておくと、
シェル起動時にバックグラウンドで自動起動される (既に動いていればスキップ):

```bash
if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
fi
```

### `home-manager: line ...: USER: unbound variable`

Docker の `USER` 命令は実行 UID を切り替えるだけで環境変数 `$USER`
までは設定しない。素の Ubuntu イメージで非ログインの bash を起動すると
`$USER` が空のまま入っており、Home Manager の起動スクリプトが `set -u`
で落ちる。

`docker/Dockerfile` 側で `ENV USER=${USERNAME}` を明示しているので
**イメージを再ビルドすれば解消**する:

```bash
docker rmi $(docker images -q 'dotfiles-nix-test*') 2>/dev/null || true
./docker/run.sh
```

旧イメージのまま動かしているセッションでの緊急回避:

```bash
export USER=$(id -un)
```

### `repository path '...' is not owned by current user`

`nix run home-manager -- switch --flake ...` の途中で出る。
マウントしたリポジトリの所有者がホスト側 UID で、コンテナ内ユーザの
UID と一致しないと git (libgit2) の所有者チェックに引っかかる。

`docker/run.sh` がホストの `id -u` / `id -g` を build-arg で渡し、
イメージタグ (`dotfiles-nix-test:<uid>-<gid>`) も UID/GID 単位で
分離しているので、**`./docker/run.sh` で起動し直せば解消**する。

それでも残る (古いイメージを `docker run` で直接呼んでいる等) 場合の
緊急回避:

```bash
git config --global --add safe.directory /home/zenimoto/dotfiles-nix
```

### `Existing file '/home/zenimoto/.bashrc' would be clobbered`

Home Manager は既存ファイルを黙って上書きしない。**初回 switch では
必ず `-b backup` を付ける**。指定した拡張子で既存ファイルを退避してから
シンボリックリンクを張り直してくれる。

```bash
nix run home-manager -- switch -b backup --flake '.#zenimoto@ubuntu'
```

> 同じ拡張子のバックアップが既に存在すると 2 度目以降の switch でまた
> 同じエラーになる。再実行時は別の拡張子 (`-b backup2` など) にするか、
> `rm ~/.bashrc.backup ~/.profile.backup` で消してから流す。

テスト用コンテナで素早く済ませたいだけなら、`-b backup` の代わりに
`rm -f ~/.bashrc ~/.profile` してから switch しても良い。

### `home-manager news` が `No configuration file found` で落ちる

`switch` 以外のサブコマンド (`news`, `generations` など) も
**flake ベースの構成では `--flake` を渡す必要がある**。

```bash
home-manager news       --flake '.#zenimoto@ubuntu'
home-manager generations --flake '.#zenimoto@ubuntu'
```

毎回打ちたくなければ alias を張る:

```bash
alias hm="home-manager --flake ~/dotfiles-nix#zenimoto@ubuntu"
hm news
hm switch -b backup
```

または `~/.config/home-manager` をリポジトリへの symlink にしておくと、
`home-manager` を引数なしで呼んでも flake を見つけてくれる:

```bash
ln -sfn ~/dotfiles-nix ~/.config/home-manager
```

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
