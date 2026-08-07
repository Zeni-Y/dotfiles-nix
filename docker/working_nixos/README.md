# Docker 開発環境 (NixOS / nixos/nix ベース)

[docker/working](../working/README.md) の NixOS 版。SSH でアクセスできる開発コンテナという
役割は同じだが、ベースイメージを `ubuntu:24.04` から公式の **`nixos/nix`** に変え、
**Nix と dotfiles (Home Manager) をイメージに焼き込む**。

コンテナを起動した時点で fish / neovim / claude-code などが揃っているので、
`scripts/setup.sh` を走らせる手順が丸ごと不要になる。

## working との違い

| 項目                | `docker/working`                          | `docker/working_nixos`                       |
| ------------------- | ----------------------------------------- | -------------------------------------------- |
| ベースイメージ      | `ubuntu:24.04`                            | `nixos/nix:2.35.1`                            |
| Nix                 | コンテナ内で `scripts/setup.sh` を実行     | イメージに同梱済み                            |
| dotfiles 適用       | コンテナ内で `home-manager switch`         | イメージビルド時に適用済み                    |
| ビルドコンテキスト  | `docker/working/`                         | リポジトリルート（flake を焼き込むため）      |
| ビルド時間          | 数分                                       | 初回は数十分（nixpkgs のビルド／ダウンロード）|
| flake 更新の反映    | コンテナ内で `home-manager switch`         | `make switch`（または `make build` し直す）   |
| SSH ポート（既定）  | 2222                                      | 2223（両方同時に起動できるようにずらしてある）|
| パッケージ管理      | `apt` + Nix                               | Nix のみ（`apt` は無い）                      |

`docker/working` と共存できる。イメージ名・コンテナ名・SSH ポートがすべて別なので、
`make run` を両方で叩けば 2 つ並べて動かせる。

## 設計方針

- **`nixos/nix` は NixOS そのものではない**。「Nix 入りの最小 Linux イメージ」であり
  systemd は動かない。そのため sshd は NixOS の `services.openssh` ではなく
  `entrypoint.sh` から直接起動する（`--privileged` も cgroup のマウントも不要で、
  `docker/working` と同じ運用感になる）
- **dotfiles はイメージに焼き込む**。Nix が最初から居るので、ビルド時に
  `homeConfigurations.<user>@ubuntu` の activation まで済ませてしまう。
  `home/` 以下の設定は OS 非依存なので、Ubuntu 用の定義をそのまま使う
- **SSH 鍵管理**: SSH agent forwarding を利用。秘密鍵はコンテナに配置しない。
  `authorized_keys` は起動時に `entrypoint.sh` が `https://github.com/<GITHUB_USER>.keys` から取得する。
  sshd のホスト鍵もイメージには焼かず、起動時にコンテナごとに生成する
- **ユーザー名**: コンテナ内のユーザー名は `flake.nix` の `userInfo.username`（既定 `zenimoto`）と
  揃える必要がある。Home Manager の `homeConfigurations` が `/home/<username>` を前提にするため

## ファイル構成

| ファイル        | 役割                                                                     |
| --------------- | ------------------------------------------------------------------------ |
| `Dockerfile`    | nixos/nix + システムツール + ユーザー + sshd 設定 + dotfiles の焼き込み  |
| `entrypoint.sh` | nix-daemon 起動 → ホスト鍵生成 → `authorized_keys` 取得 → `sshd` 前面実行 |
| `Makefile`      | build / run / switch / clean 等のタスク定義                              |

## セットアップ手順

### イメージビルド

```bash
cd docker/working_nixos/
make build
```

`$USER_working_nixos_image` という名前のイメージが作成される。`--build-arg` でホストの
UID/GID を引き継ぐため、マウントしたファイルの権限問題が起きない。

コンテナ内のユーザー名は既定でホストの `$USER` を引き継ぐ。`flake.nix` の
`userInfo.username` と違う場合は `USERNAME` を明示する:

```bash
make build USERNAME=zenimoto
make run   USERNAME=zenimoto
```

初回ビルドは Home Manager の適用まで走るので数十分かかる（バイナリキャッシュに無い
ものはローカルでビルドされる）。2 回目以降は Docker のレイヤキャッシュが効き、
`home/` 以下を触ったときだけ dotfiles のレイヤが作り直される。

### コンテナ起動

```bash
make run
```

`-d` でバックグラウンド起動し、`sshd -D` が常駐するため、ホスト側から
**いつでも SSH 接続できる状態が維持される**。`--restart unless-stopped` を付けているので
Docker / ホスト再起動後も自動復帰する。

`--init` を付けているので PID 1 は tini になり、`sshd` と `nix-daemon` はその子として動く。
SSH セッションが残すゾンビプロセスの刈り取りと、`docker stop` のシグナル転送を tini に任せられる。

GPU は `nvidia-smi` がホストにある場合のみ `--gpus all` が自動付与される。

### コンテナに入る

```bash
make shell   # bash（ログインシェル）で入る。exit してもコンテナは停止しない
```

bash は対話シェルなら fish に `exec` する（`home/shell/bash.nix` の設定）ので、
そのまま fish が立ち上がる。

### SSH 接続

`authorized_keys` はコンテナ起動時に `entrypoint.sh` が
`https://github.com/$GITHUB_USER.keys` から取得する（既定 `GITHUB_USER=Zeni-Y`）。
鍵を足したり消したりしたときは GitHub 側で編集して `make restart` すればよい。

```bash
make ssh
# または
ssh -A -p 2223 $USER@localhost
```

### dotfiles を更新する

イメージにはビルド時点のリポジトリが `~/dotfiles-nix` として入っている。
設定を書き換えたら再適用する:

```bash
make switch
# ホストの ~/ghq に clone したものを使う場合
make switch REPO=/home/$USER/ghq/github.com/Zeni-Y/dotfiles-nix
```

`make switch` はコンテナ内で `home-manager switch --flake '.#<user>@ubuntu'` を叩くだけ。
コンテナの中から直接実行してもよい:

```bash
make shell
cd ~/dotfiles-nix
home-manager switch --flake '.#zenimoto@ubuntu'
```

`-b backup` の意味や 2 回目以降の注意点は
[トップ README](../../README.md#-b-backup-の挙動) を参照。
Nix / Home Manager 周りのエラーは
[docker/debug/README.md の「よくあるエラーと対処」](../debug/README.md#よくあるエラーと対処) にまとまっている。

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

## 仕組みの補足

素の `nixos/nix` は「Nix を動かすための最小構成」なので、開発コンテナとして
使うには足りないものがある。Dockerfile で補っているのは以下:

- **`/etc/passwd` などが store へのシンボリックリンク**
  読み取り専用なので `useradd` が失敗する。実ファイルへ展開してから使う
- **`useradd` / `sudo` / ロケール / タイムゾーンが無い**
  `nix profile install` で足す。バージョンはリポジトリの `flake.lock` に
  固定した nixpkgs から引く（`--inputs-from`）ので、home 側の環境と同じ nixpkgs になる。
  ベースイメージの coreutils と `kill` などが衝突するので `--priority` で順位を付けている
- **`sudo` は setuid が要る**
  Nix store のファイルに setuid は付けられないので、バイナリを `/usr/bin/sudo` に
  コピーして `4755` にする。store 側は GC root を張って closure を保護している。
  nixpkgs の sudo は PAM 付きなので、`/etc/pam.d/sudo` に `pam_permit` の最小構成を置く
  （sudoers 側で `NOPASSWD` にしている開発用コンテナ前提の割り切り）
- **`useradd` が作るアカウントは「ロック済み」扱い**
  パスワード欄が `!` になるため、`UsePAM no` の sshd は公開鍵認証まで蹴る
  （`User ... not allowed because account is locked`）。`/etc/pam.d/sshd` に
  `pam_permit` の最小構成を置いて `UsePAM yes` で動かしている
- **`ssh <host> <command>` は PATH が空同然になる**
  非対話実行では `/etc/profile` も `~/.bashrc` も読まれず、sshd 既定の PATH には
  Nix のプロファイルが入っていない。`sshd_config` の `SetEnv PATH=...` で補っている
- **`nix-daemon` を誰も起動しない**
  systemd が無いので `entrypoint.sh` が面倒を見る。これが居ないと一般ユーザーは
  store に書けず `home-manager switch` も失敗する。Nix はストアが書けないユーザーなら
  自動で daemon 経由になるので、`NIX_REMOTE` を手で設定する必要はない
- **タイムゾーンが解決できない**
  nixpkgs の glibc は既定で `/usr/share/zoneinfo` を見ない（`TZDIR` 頼み）。
  `TZ` を環境変数として残すと、`TZDIR` が渡らない場面で `Asia/Tokyo` が
  POSIX 形式の文字列として解釈されて UTC になる。そこで `TZ` はビルド時の
  `ARG` に留め、`/etc/localtime` を張って解決させている
  （別のタイムゾーンにするなら `make build` に `--build-arg TZ=...` を足す）
- **ログインシェルの絶対パス**
  `/bin/bash` は存在しない。`/etc/passwd` には
  `/nix/var/nix/profiles/default/bin/bash` を書く（store のハッシュ付きパスを
  直接書くと、更新のたびにログインできなくなる）

## 注意点

- `apt` は無い。システムに何か足したいときは `sudo nix profile install nixpkgs#<pkg>`
  （システム共通のプロファイル）か、ユーザー側なら `home/packages.nix` に足して `make switch`
- コンテナを作り直しても dotfiles はイメージ側にあるので消えない。一方 `/nix` の
  ユーザープロファイル世代はイメージのものに戻る
- `~/ghq` と `~/.cache` はホストからマウントされる（`docker/working` と同じ）。
  `$HOME` 全体は `/home/$USER/host` にマウントされる
- GPU は `--gpus all` で渡るが、nvidia-container-toolkit が注入するドライバは
  `/usr/lib64` などを前提にしている。CUDA を使うワークロードでは
  `docker/working`（Ubuntu ベース）の方が素直に動くことがある
