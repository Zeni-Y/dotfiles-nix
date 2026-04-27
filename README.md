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
3. [初回セットアップ](#初回セットアップ)
4. [日々の運用](#日々の運用)
5. [カスタマイズの勘どころ](#カスタマイズの勘どころ)
6. [既知のハマりどころ](#既知のハマりどころ)

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

## 初回セットアップ

事前に `flake.nix` の `userInfo` を自分の値に書き換えておく:

| キー | 用途 |
| --- | --- |
| `username` | OS のユーザー名。`darwinConfigurations.<username>` の名前にもなる |
| `gitName` | git のコミッタ名 |
| `gitEmail` | git のコミットアドレス |

以降の手順は OS ごとに分かれる。

### macOS

1. Nix をインストール:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.nixos.org | sh -s -- install
   ```

2. このリポジトリを clone:

   ```bash
   git clone https://github.com/Zeni-Y/dotfiles-nix.git ~/ghq/github.com/Zeni-Y/dotfiles-nix
   cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
   ```

3. nix-darwin の構成を適用 (Homebrew も自動でインストールされる):

   ```bash
   sudo nix run nix-darwin -- switch --flake .#zenimoto
   ```

   `zenimoto` の部分は `flake.nix` の `userInfo.username` に合わせて変える。
   `nix-homebrew` モジュールが Homebrew 本体のブートストラップまで面倒を見るため、
   `brew` コマンドの事前インストールは不要。

4. シェルをリロード:

   ```bash
   exec fish
   ```

   以降は `sudo darwin-rebuild switch --flake .#zenimoto` で再適用できる。

### Linux (Ubuntu など)

1. Nix をまだ入れていなければインストール:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.nixos.org | sh -s -- install
   ```

2. このリポジトリを clone:

   ```bash
   git clone https://github.com/Zeni-Y/dotfiles-nix.git ~/ghq/github.com/Zeni-Y/dotfiles-nix
   cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
   ```

3. Home Manager の構成を適用:

   ```bash
   nix run .#switch
   ```

   `apps.x86_64-linux.switch` がラッパーとして
   `home-manager switch --flake .#<username>@ubuntu` を呼ぶ。
   2 回目以降は `home-manager switch --flake .#<username>@ubuntu` を直接叩いてもよい。

4. シェルをリロード:

   ```bash
   exec fish
   ```

> 公式インストーラ (`install.nixos.org`) を使った場合、flakes と
> `nix` コマンドを有効にするために `~/.config/nix/nix.conf` に
> `experimental-features = nix-command flakes` を 1 行追加する必要がある。
> Determinate Nix Installer を使う場合は最初から有効化されている。

---

## 日々の運用

```bash
# 設定を編集したあとの反映
home-manager switch --flake .#zenimoto@ubuntu      # Linux
sudo darwin-rebuild switch --flake .#zenimoto      # macOS

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
