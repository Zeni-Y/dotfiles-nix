# dotfiles-nix

[Zeni-Y/dotfiles](https://github.com/Zeni-Y/dotfiles) (chezmoi 管理) を参考に、
**Nix Flakes + Home Manager + nix-darwin** で macOS / Ubuntu の両方の環境を
宣言的に管理するための dotfiles です。

CI やテストは含めず、設定が増えても見通しを保てるように
トピックごとにモジュールを分割しています。

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
| エディタ | Neovim (defaultEditor)・Zed (`~/.config/zed/{settings,keymap}.json` を生成) |
| CLI ツール | bat / eza / fzf / zoxide / direnv (nix-direnv 連携) / gh / lazygit / ripgrep / fd / jq / yq / yazi / ghq |
| macOS のみ | Homebrew Cask (WezTerm, Zed, Raycast, Rectangle, 1Password, Slack, VSCode, Docker, Obsidian, …)・Dock / Finder / キーボード / トラックパッドの defaults write |

---

## ディレクトリ構成

```
.
├── flake.nix                # 入力 (nixpkgs / home-manager / nix-darwin) と出力を定義
├── flake.lock               # 依存バージョンの固定 (初回 `nix flake update` で生成)
│
├── hosts/                   # ホスト (= 適用対象) 単位の入口
│   ├── macos.nix            #   nix-darwin + Home Manager
│   └── ubuntu.nix           #   standalone Home Manager
│
├── home/                    # ユーザー領域 (~/) の設定。OS を問わない
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
└── darwin/                  # macOS のシステム領域。nix-darwin モジュール
    ├── default.nix
    ├── system.nix           # Dock / Finder / キーボードなど defaults write 相当
    └── homebrew.nix         # Cask / brew formula / Mac App Store
```

設計の指針:

- **OS 共通の設定は `home/` に置く**。Ubuntu でも macOS でも同じものが入る。
- **OS 固有の設定だけ `darwin/` に置く**。Linux 用の似た層が要るときは `nixos/` を増やす。
- **ホスト構成は `hosts/` に集約する**。新しいマシンを足すときは
  `flake.nix` の outputs と `hosts/<name>.nix` を 1 つ書くだけで済む。

---

## 前提ソフトウェアのインストール

### 共通: Nix

リポジトリ同梱の `scripts/setup.sh` が、環境に応じて自動で
適切な Nix をセットアップする。

```bash
./scripts/setup.sh
```

挙動:

| 環境 | 動作 |
| --- | --- |
| `sudo` + `systemd` が使える | [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) で通常の (multi-user) Nix をインストール |
| `sudo` は使えるが `systemd` が無い (Docker コンテナなど) | 同じ Determinate Nix Installer を `linux --init none` プランで実行。`nix-daemon` の自動起動だけ諦める |
| `sudo` が使えない | [nix-portable](https://github.com/DavHau/nix-portable) を `~/.local/bin/nix-portable` にダウンロード |

systemd が無い環境では `nix-daemon` を自前で起動する必要があるので、
インストール後に表示される指示に従って `~/.bashrc` などに以下を追記しておくと楽:

```bash
if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
fi
```

明示的に切り替えたい場合:

```bash
./scripts/setup.sh --system     # 強制的に通常の Nix (sudo 必須)
                                # systemd が無ければ自動で --init none に切り替わる
./scripts/setup.sh --portable   # 強制的に nix-portable
```

flakes と `nix` コマンドはインストーラが既定で有効化してくれる。
公式インストーラを手動で使った場合は `~/.config/nix/nix.conf` に
`experimental-features = nix-command flakes` を追記する。

#### nix-portable を使う場合の注意

nix-portable は単体バイナリで `/nix` への書き込みも root も不要なため、
共有マシンや CI コンテナ、開発用 SSH 接続先などで便利。
ただし通常の `nix` コマンドの代わりに、すべて `nix-portable` 経由で呼び出す:

```bash
# flake の確認
nix-portable nix flake metadata

# Home Manager を適用 (Ubuntu 用)
nix-portable nix run home-manager/master -- switch --flake .#zenimoto@ubuntu
```

シェルにエイリアスを張っておくと使い勝手が良い:

```bash
alias nix='nix-portable nix'
```

##### experimental-features (flakes / nix-command) について

nix-portable は **`flakes` と `nix-command` をデフォルトで有効化した状態**で
配布されているため、`/etc/nix/nix.conf` を書いたり追加フラグを渡したりする
必要はない (公式 README: "Features `flakes` and `nix-command` are enabled
out of the box.")。インストール直後から `nix-portable nix flake ...` が動く。

`ca-derivations` など追加の experimental feature を有効にしたい場合は、
通常の Nix と同じ方法で設定する。デフォルト値を上書きしないよう
`extra-experimental-features` を使うのが安全:

```bash
mkdir -p ~/.config/nix
echo 'extra-experimental-features = ca-derivations' >> ~/.config/nix/nix.conf

# あるいは環境変数で
export NIX_CONFIG="extra-experimental-features = ca-derivations"

# あるいは 1 回限りのフラグ
nix-portable nix --extra-experimental-features ca-derivations build ...
```

なお nix-portable 固有の挙動 (実行ランタイム選択や保存場所変更など) は
`NP_RUNTIME` / `NP_LOCATION` / `NP_DEBUG` といった `NP_*` 系の環境変数で
制御する。これらは Nix の experimental-features とは別物。

### macOS のみ: Homebrew

nix-darwin の Homebrew モジュールは「Homebrew 本体が入っている前提」で動くため、
先に入れておく:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

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
nix run home-manager/master -- switch --flake .#zenimoto@ubuntu

# 以降は home-manager コマンドが PATH に入っているのでそれを使う
home-manager switch --flake .#zenimoto@ubuntu
```

`sudo` が使えない環境 (= nix-portable をインストールした場合) は
すべての `nix` 呼び出しを `nix-portable nix` に置き換える:

```bash
nix-portable nix run home-manager/master -- switch --flake .#zenimoto@ubuntu
```

### macOS (nix-darwin)

```bash
# nix-darwin を初回だけブートストラップ
nix run nix-darwin -- switch --flake .#mac

# 以降は darwin-rebuild が使える
sudo darwin-rebuild switch --flake .#mac
```

`mac` という名前は `flake.nix` の `darwinConfigurations.<name>` に対応する。
複数 Mac ある場合はこの名前を hostname ごとに分ける。

---

## 日々の運用

```bash
# 設定を編集したあとの反映
home-manager switch --flake .#zenimoto@ubuntu      # Ubuntu
sudo darwin-rebuild switch --flake .#mac           # macOS

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

# nix-darwin 側
sudo darwin-rebuild --list-generations
sudo darwin-rebuild --switch-generation <n>
```

---

## カスタマイズの勘どころ

- **新しい CLI ツールを足したい** → `home/packages.nix` の `home.packages` に追加。
  シェル統合が必要なものは `home/cli/<name>.nix` を作って `home/cli/default.nix` で imports する。
- **Mac の GUI アプリを足したい** → `darwin/homebrew.nix` の `casks` に追加。
- **fish のプラグインを足したい** → `home/shell/fish.nix` の `plugins` に
  `{ name; src = pkgs.fishPlugins.<name>.src; }` を追加。
- **マシンを増やしたい** → `hosts/<name>.nix` を作り、`flake.nix` の outputs に登録。

---

## 既知のハマりどころ

- **macOS の `system.defaults` の一部はログアウトしないと反映されない** (Dock など)。
- **Homebrew の `cleanup = "zap"`** は、ここで宣言していないものを問答無用でアンインストールする。
  既存環境を取り込む段階では `"check"` または `"uninstall"` の方が安全。
- **`pkgs.fishPlugins` にないプラグイン**を使いたい場合は `fetchFromGitHub` で src を固定する
  (詳細は `home/shell/fish.nix` のコメント参照)。
- **fish_plugins (fisher)** をリポジトリに残しても Nix 管理下では機能しないので消して良い。

---

## 参考

- 元になった dotfiles: <https://github.com/Zeni-Y/dotfiles>
- Nix Flakes: <https://nix.dev/concepts/flakes>
- Home Manager: <https://nix-community.github.io/home-manager/>
- nix-darwin: <https://github.com/nix-darwin/nix-darwin>
