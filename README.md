# dotfiles-nix

[Zeni-Y/dotfiles](https://github.com/Zeni-Y/dotfiles) (chezmoi 管理) を参考に、
**Nix Flakes + Home Manager** で Linux (Ubuntu / Docker コンテナ) 環境を
宣言的に管理するための dotfiles です。

CI やテストは含めず、設定が増えても見通しを保てるように
トピックごとにモジュールを分割しています。

## 前提とスコープ

- **対象 OS は Linux のみ**。Docker コンテナ内での利用も想定します。
  macOS (nix-darwin / Homebrew) は対象外です。
- **`sudo` が使えることが前提**。Nix は `/nix` にインストールする
  通常の (multi-user) 構成のみをサポートします。
- **`nix-portable` は使いません**。`sudo` が使えない環境は考慮しないので、
  そのような環境ではシステム管理者に Nix のインストールを依頼してください。

> **Nix の構文・概念・ライフサイクルを学びたい場合は [docs/nix-concepts.md](docs/nix-concepts.md) を参照してください。**

---

## 目次

1. [何ができるか](#何ができるか)
2. [ディレクトリ構成](#ディレクトリ構成)
3. [前提ソフトウェアのインストール](#前提ソフトウェアのインストール)
4. [初回セットアップ](#初回セットアップ)
5. [日々の運用](#日々の運用)
6. [カスタマイズの勘どころ](#カスタマイズの勘どころ)
7. [既知のハマりどころ](#既知のハマりどころ)

---

## 何ができるか

| トピック | 中身 |
| --- | --- |
| シェル | bash → fish への自動切替・fish プラグイン (autopair / sponge / fzf.fish / **pure** プロンプト) |
| Git | userName/userEmail・rebase 既定・push.autoSetupRemote・gh による credential helper・url.pushInsteadOf |
| ターミナル | tmux (prefix `C-t`, resurrect/continuum, Catppuccin)・WezTerm (FiraCode Nerd Font, Catppuccin Mocha) |
| エディタ | Neovim (defaultEditor) |
| CLI ツール | bat / eza / fzf / zoxide / direnv (nix-direnv 連携) / gh / lazygit / ripgrep / fd / jq / yq / yazi / ghq |

---

## ディレクトリ構成

```
.
├── flake.nix                # 入力 (nixpkgs / home-manager) と出力を定義
├── flake.lock               # 依存バージョンの固定 (初回 `nix flake update` で生成)
│
├── hosts/                   # ホスト (= 適用対象) 単位の入口
│   └── ubuntu.nix           #   standalone Home Manager
│
├── home/                    # ユーザー領域 (~/) の設定
│   ├── default.nix          #   配下のモジュールを集約
│   ├── packages.nix         #   "入れるだけ" の CLI ツール群
│   ├── git.nix              #   Git
│   ├── tmux.nix             #   tmux + プラグイン
│   ├── wezterm.nix          #   WezTerm
│   ├── shell/               #   シェル関連
│   │   ├── default.nix
│   │   ├── bash.nix         #     対話シェルなら fish に exec
│   │   └── fish.nix         #     fish + plugins (autopair/sponge/fzf.fish/pure) + alias
│   ├── editors/             #   エディタ
│   │   ├── default.nix
│   │   └── neovim.nix
│   └── cli/                 #   シェル統合が必要な CLI ツール
│       ├── default.nix
│       ├── bat.nix
│       ├── eza.nix
│       ├── fzf.nix
│       ├── zoxide.nix
│       ├── direnv.nix
│       └── gh.nix
│
├── scripts/
│   └── setup.sh             # Nix のインストール (sudo 必須)
│
└── docker/                  # Docker 上の検証環境 / 開発環境
    ├── debug/               #   素の Ubuntu で setup.sh を検証する箱
    └── working/             #   SSH で入る常駐開発コンテナ
```

設計の指針:

- **ユーザー領域の設定はすべて `home/` に置く**。Ubuntu でも Docker コンテナでも同じものが入る。
- **ホスト構成は `hosts/` に集約する**。新しいマシンを足すときは
  `flake.nix` の outputs と `hosts/<name>.nix` を 1 つ書くだけで済む。
- **システム領域は Nix で管理しない**。対象は NixOS ではない Linux なので、
  `~/` 配下だけを Home Manager で宣言的に管理する。

---

## 前提ソフトウェアのインストール

### Nix

リポジトリ同梱の `scripts/setup.sh` が
[Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
で通常の (multi-user) Nix をインストールする。**`sudo` (または root) が必須**。

```bash
./scripts/setup.sh
```

挙動:

| 環境 | 動作 |
| --- | --- |
| `sudo` + `systemd` が使える | そのままインストール。`nix-daemon` は systemd が面倒を見る |
| `sudo` は使えるが `systemd` が無い (Docker コンテナなど) | `linux --init none` プランでインストール。`nix-daemon` の自動起動だけ諦め、代わりに `~/.bashrc` へ起動スニペットを追記する |
| `sudo` が使えない | **サポート外**。エラーで停止する |

systemd の有無は自動判定するが、明示したい場合は:

```bash
./scripts/setup.sh --init-none   # 強制的に `linux --init none` プラン
```

systemd が無い環境では `nix-daemon` を自前で起動する必要がある。
`setup.sh` が `~/.bashrc` に以下を追記するので、新しいシェルを開けば自動起動する:

```bash
if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
fi
```

flakes と `nix` コマンドはインストーラが既定で有効化してくれる。
公式インストーラを手動で使った場合は `~/.config/nix/nix.conf` に
`experimental-features = nix-command flakes` を追記する。

#### `sudo` が使えない環境について

このリポジトリは **`sudo` の無い環境を一切考慮しない**。
`nix-portable` のような無権限で動かす仕組みは使わない。
共有サーバなどで `/nix` を作れない場合は、システム管理者に
上記インストーラでの Nix 導入を依頼すること。

Docker コンテナ内での利用は今後も想定するが、その場合も
コンテナ内のユーザに sudo (NOPASSWD) を持たせる前提とする。

---

## 初回セットアップ

```bash
# 自分のフォークを clone する想定
git clone git@github.com:<you>/dotfiles-nix.git
cd dotfiles-nix

# 個人情報を書き換える: flake.nix の `userInfo`
#   username    : OS のユーザー名
#   gitName     : git のコミッタ名
#   gitEmail    : git のコミットアドレス
$EDITOR flake.nix
```

### Ubuntu (standalone home-manager)

```bash
# 初回は home-manager コマンド自体を nix run で持ってくる
# `-b backup` は既存の dotfiles を退避するためのフラグ (下記参照)。初回 switch では必須。
nix run home-manager/master -- switch -b backup --flake .#zenimoto@ubuntu

# 以降は home-manager コマンドが PATH に入っているのでそれを使う
home-manager switch --flake .#zenimoto@ubuntu
```

#### `-b backup` の挙動

Home Manager は `~/.bashrc` や `~/.profile` のような **既に存在するファイルを
黙って上書きしない**。素の Ubuntu には Ubuntu 標準の `~/.bashrc` などが既に
置かれているため、無印で `switch` を打つと

```
Existing file '/home/<you>/.bashrc' would be clobbered
```

で停止する。`-b backup` を付けると Home Manager は次の動作になる:

1. Home Manager が管理したいパス (`~/.bashrc`, `~/.profile`, `~/.config/...` など) に
   既存の実体ファイルがあるかチェックする
2. 衝突しているファイルを `<元のパス>.backup` にリネームして退避する
3. 退避した跡地に Nix store を指す symlink を張る

例えば `~/.bashrc` が既にあれば `~/.bashrc.backup` に移動され、その後で
`~/.bashrc -> /nix/store/...-home-manager-files/.bashrc` の symlink が作られる。

**注意点**:
- 拡張子 (`backup`) は何でもよく、`-b old` でも `-b 2025-04-28` でも動く。
- **同じ拡張子のバックアップが既にある場合、再度 `switch` するとまた同じエラーで
  止まる**。再実行するときは別の拡張子 (`-b backup2`) を渡すか、`rm
  ~/.bashrc.backup ~/.profile.backup` で退避済みファイルを消してから流す。
- 2 回目以降の `switch` は Home Manager 自身が貼った symlink を相手にするので
  通常 `-b backup` 不要。symlink は「Home Manager 管理下」と判定されるので
  普通に上書きされる。
- 退避された `.backup` の中身が要らないと確認できたら、後から消して構わない。

`zenimoto@ubuntu` という名前は `flake.nix` の `homeConfigurations.<name>` に対応する。
マシンを増やすときはこの名前を分け、`hosts/<name>.nix` を追加する。

---

## 日々の運用

```bash
# 設定を編集したあとの反映
home-manager switch --flake .#zenimoto@ubuntu

# 依存パッケージのアップデート (flake.lock を更新)
nix flake update

# どんな差分が当たるか事前確認
nix build .#homeConfigurations."zenimoto@ubuntu".activationPackage
```

切り戻し:

```bash
# Home Manager は世代ベースで戻れる
home-manager generations
/nix/store/...-home-manager-generation/activate   # 任意の世代に戻す
```

---

## カスタマイズの勘どころ

- **新しい CLI ツールを足したい** → `home/packages.nix` の `home.packages` に追加。
  シェル統合が必要なものは `home/cli/<name>.nix` を作って `home/cli/default.nix` で imports する。
- **fish のプラグインを足したい** → `home/shell/fish.nix` の `plugins` に
  `{ name; src = pkgs.fishPlugins.<name>.src; }` を追加。
- **プロンプトや補完の文字色を変えたい** → `home/shell/fish.nix` の
  `interactiveShellInit` にある配色ブロック。fish と pure は控えめな情報
  (git ブランチ名・入力補完のゴースト表示など) に `brblack` を当てるため、
  黒背景だと沈む。そこだけ灰色系の実値に差し替えてある。
  fzf の分は `home/cli/fzf.nix` の `colors`。
- **マシンを増やしたい** → `hosts/<name>.nix` を作り、`flake.nix` の outputs に登録。

---

## 既知のハマりどころ

- **初回 `home-manager switch` では `-b backup` を付ける**。
  既存の `~/.bashrc` / `~/.profile` などがあると Home Manager は黙って上書きせず
  `Existing file '...' would be clobbered` で停止する。`-b backup` を付ければ
  `.backup` 拡張子で退避してからリンクを張り直してくれる。
  ```bash
  nix run home-manager -- switch -b backup --flake '.#zenimoto@ubuntu'
  ```
  2 度目以降の switch で同じバックアップが既にあるとまたぶつかるので、
  別の拡張子 (`-b backup2`) にするか退避済みファイルを消す。
- **`home-manager news` / `generations` などのサブコマンドも `--flake` が必要**。
  flake 構成では `~/.config/home-manager/home.nix` が無いので、`--flake` 無しで
  叩くと `No configuration file found` で落ちる。
  ```bash
  home-manager news --flake '.#zenimoto@ubuntu'
  # 楽にしたいなら alias:
  alias hm="home-manager --flake ~/dotfiles-nix#zenimoto@ubuntu"
  # あるいは symlink を張って引数なしで呼べるようにする:
  ln -sfn ~/dotfiles-nix ~/.config/home-manager
  ```
- **systemd 無しの環境 (Docker コンテナなど) では `nix-daemon` を手動起動する**。
  `setup.sh` でインストール後、`opening lock file ".../big-lock": Permission denied`
  が出るのは daemon が落ちているサイン。`~/.bashrc` に
  `pgrep -x nix-daemon || sudo /nix/var/nix/profiles/default/bin/nix-daemon &` を
  仕込んでおくと毎回手で叩かなくて済む。
- **`pkgs.fishPlugins` にないプラグイン**を使いたい場合は `fetchFromGitHub` で src を固定する
  (詳細は `home/shell/fish.nix` のコメント参照)。
- **fish_plugins (fisher)** をリポジトリに残しても Nix 管理下では機能しないので消して良い。

Docker コンテナ固有のトラブル (UID/GID 不一致による
`repository ... is not owned by current user`、`USER: unbound variable` など) は
[docker/debug/README.md の「よくあるエラーと対処」](docker/debug/README.md#よくあるエラーと対処) を参照。

---

## 参考

- 元になった dotfiles: <https://github.com/Zeni-Y/dotfiles>
- Nix Flakes: <https://nix.dev/concepts/flakes>
- Home Manager: <https://nix-community.github.io/home-manager/>
- Determinate Nix Installer: <https://github.com/DeterminateSystems/nix-installer>
