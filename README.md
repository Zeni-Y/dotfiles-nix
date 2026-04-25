# Nixを使ったdotfiles管理チュートリアル

> [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) を参考に、初心者向けに簡略化したチュートリアルです。

## 目次

1. [dotfilesとは？](#1-dotfilesとは)
2. [Nixとは？](#2-nixとは)
3. [なぜNixでdotfilesを管理するのか？](#3-なぜnixでdotfilesを管理するのか)
4. [用語解説](#4-用語解説)
5. [環境のセットアップ](#5-環境のセットアップ)
6. [ディレクトリ構成](#6-ディレクトリ構成)
7. [設定ファイルを書く](#7-設定ファイルを書く)
8. [設定を適用する](#8-設定を適用する)
9. [日常的な使い方](#9-日常的な使い方)
10. [次のステップ](#10-次のステップ)

---

## 1. dotfilesとは？

Linuxや macOS では、ホームディレクトリ（`~`）に `.bashrc` や `.gitconfig` などのドット（`.`）で始まるファイルが存在します。これらは各種ツールの設定ファイルで、**dotfiles（ドットファイル）** と呼ばれています。

```
~/.gitconfig      # Gitの設定
~/.bashrc         # Bashシェルの設定
~/.config/nvim/   # Neovimの設定
```

これらを Git リポジトリで管理することで：

- **バックアップ** — マシンが壊れても設定を復元できる
- **同期** — 複数のマシンで同じ設定を使える
- **共有** — 自分の設定を公開して他の人の参考にしてもらえる

---

## 2. Nixとは？

**Nix** は、パッケージ管理と設定管理を行うツール（およびプログラミング言語）です。

通常のパッケージマネージャ（apt、brew など）との大きな違いは、**再現性（reproducibility）** にあります。

| 通常のパッケージマネージャ | Nix |
|---|---|
| 同じコマンドでも環境によって結果が変わりうる | 同じ設定ファイルから必ず同じ環境が作られる |
| 削除しても依存関係が残ることがある | クリーンなアンインストールが可能 |
| バージョンが自動で上がることがある | バージョンをロックファイルで管理できる |

> **NixはmacでもLinuxでも使えます。**

---

## 3. なぜNixでdotfilesを管理するのか？

従来のdotfiles管理（シンボリックリンクなど）と比べたNixの利点：

1. **宣言的（Declarative）** — 「こういう状態にしたい」と書くだけで、Nixが実現してくれる
2. **再現性** — 新しいマシンでも`nix switch`一発で完全に同じ環境が作られる
3. **ロールバック** — 設定を変更して壊れても、以前の状態に戻せる
4. **パッケージ管理も一緒に** — インストールするツールも同じ設定ファイルで管理できる

---

## 4. 用語解説

このチュートリアルで登場する用語を事前に説明します。

### Nix言語

設定ファイルを書くための関数型プログラミング言語です。`.nix` という拡張子のファイルに書きます。

```nix
# これはNix言語のコメント
{
  # 属性セット（JSONのオブジェクトに近い）
  name = "Alice";
  age = 30;

  # リスト
  tools = [ "git" "vim" "curl" ];
}
```

### Nix Flakes（フレークス）

Nixの設定を**モジュール化・バージョン管理**するための仕組みです。`flake.nix` というファイルが入口になります。

- **inputs** — 依存するNixパッケージ集（nixpkgs）やツール（home-manager）のバージョンを指定
- **outputs** — この flake が提供する設定（各マシンの設定など）を定義

```
flake.nix   ← 入口：依存関係とマシン設定の一覧
flake.lock  ← 自動生成：依存関係の正確なバージョンが記録される（Gitのコミットハッシュなど）
```

### Home Manager

Nix を使って**ユーザーレベルの設定**（dotfiles、ツールのインストールなど）を管理するツールです。

- シェルの設定
- Gitの設定
- 各種ツールのインストール

などを `.nix` ファイルで一元管理できます。

### nixpkgs

Nix の公式パッケージリポジトリです。80,000以上のパッケージが収録されています。`pkgs.git`、`pkgs.curl` のように参照します。

---

## 5. 環境のセットアップ

### Nixのインストール

[Determinate Systems の Nix インストーラー](https://determinate.systems/posts/determinate-nix-installer) を使うと、Flakes が最初から有効な状態でインストールできます。

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

> **公式インストーラーとの違い**: Determinate Systems版はFlakesが最初から有効で、アンインストールも簡単です。

インストール後、新しいターミナルを開いてから確認：

```bash
nix --version
# nix (Nix) 2.x.x
```

### Home Managerのインストール

後の手順で `flake.nix` に組み込む形で使うため、**別途インストールは不要**です。

---

## 6. ディレクトリ構成

このチュートリアルで作成するファイルの構成です：

```
~/dotfiles/
├── flake.nix          # Nix Flakeの入口
├── flake.lock         # 自動生成されるロックファイル（触らない）
└── home.nix           # Home Managerの設定（メイン）
```

シンプルに保つため、まず2つのファイルだけで始めます。

---

## 7. 設定ファイルを書く

### リポジトリを作成する

```bash
mkdir ~/dotfiles
cd ~/dotfiles
git init
```

### `flake.nix` を書く

```nix
{
  description = "My dotfiles";

  inputs = {
    # nixpkgs: Nixの公式パッケージリポジトリ
    # "nixos-unstable" は最新パッケージが揃っているブランチ
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager: ユーザー設定を管理するツール
    # "follows" により、nixpkgsのバージョンをhome-managerと統一する
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
  let
    # 使用するシステムアーキテクチャを指定
    # Linux (x86_64) の場合: "x86_64-linux"
    # Mac (Apple Silicon) の場合: "aarch64-darwin"
    # Mac (Intel) の場合: "x86_64-darwin"
    system = "x86_64-linux";

    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    # homeConfigurations: Home Managerの設定
    # "yourname" の部分は実際のユーザー名に変更してください
    homeConfigurations."yourname" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [ ./home.nix ];
    };
  };
}
```

> **ポイント**: `system` と `"yourname"` の部分は自分の環境に合わせて変更してください。

### `home.nix` を書く

```nix
{ pkgs, ... }:

{
  # Home Managerが管理するユーザーのホームディレクトリ
  home.username = "yourname";      # 実際のユーザー名に変更
  home.homeDirectory = "/home/yourname";  # Macの場合は /Users/yourname

  # Home Manager 自体のバージョン互換性設定
  # 初回設定時のバージョンを書いておく（アップデート時に変更しない）
  home.stateVersion = "25.05";

  # ─────────────────────────────────────────
  # インストールするパッケージの一覧
  # ─────────────────────────────────────────
  home.packages = with pkgs; [
    # ファイル検索
    ripgrep   # rg コマンド：高速なgrep代替
    fd        # find コマンドの代替

    # ファイル表示
    bat       # cat コマンドの代替（シンタックスハイライト付き）
    eza       # ls コマンドの代替（色付き、Gitステータス表示）

    # その他ユーティリティ
    curl
    jq        # JSONの整形・クエリツール
  ];

  # ─────────────────────────────────────────
  # Gitの設定
  # ─────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Your Name";          # GitHubなどで使う名前
    userEmail = "you@example.com";   # GitHubなどで使うメールアドレス

    extraConfig = {
      # デフォルトブランチ名を "main" にする
      init.defaultBranch = "main";

      # git pull 時にリベースを使う（マージコミットを作らない）
      pull.rebase = true;

      # git push 時に現在のブランチを自動でリモートに設定
      push.autoSetupRemote = true;
    };
  };

  # ─────────────────────────────────────────
  # Bashシェルの設定
  # ─────────────────────────────────────────
  programs.bash = {
    enable = true;

    # シェル起動時に実行されるコマンド
    initExtra = ''
      # eza を ls の代わりに使う
      alias ls='eza --icons'
      alias ll='eza -la --icons'

      # bat を cat の代わりに使う
      alias cat='bat'
    '';
  };

  # ─────────────────────────────────────────
  # Home Manager 自体も Home Manager で管理する
  # ─────────────────────────────────────────
  programs.home-manager.enable = true;
}
```

> **`with pkgs;` について**: `with pkgs;` を使うと、`pkgs.ripgrep` と書く代わりに `ripgrep` と書けます。

---

## 8. 設定を適用する

### 初回セットアップ

```bash
cd ~/dotfiles

# flake.lock を生成（初回のみ）
nix flake update

# 設定を適用
# "yourname" は flake.nix で設定したユーザー名に合わせる
nix run home-manager/master -- switch --flake .#yourname
```

### 2回目以降の適用

```bash
cd ~/dotfiles
home-manager switch --flake .#yourname
```

### 確認してみる

```bash
# ripgrep が使えるか確認
rg --version

# bat が使えるか確認
bat --version

# git の設定が反映されているか確認
git config --global --list
```

---

## 9. 日常的な使い方

### 設定を変更する

1. `home.nix` を編集する
2. `home-manager switch --flake .#yourname` を実行
3. 変更が即座に反映される

### パッケージを追加する

`home.nix` の `home.packages` にパッケージ名を追加して `switch` するだけです：

```nix
home.packages = with pkgs; [
  ripgrep
  fd
  bat
  eza
  curl
  jq
  # ↓ 追加したいパッケージをここに書く
  htop      # プロセスモニター
  tree      # ディレクトリツリー表示
];
```

### パッケージ名を調べる

[search.nixos.org](https://search.nixos.org/packages) でパッケージを検索できます。

```bash
# コマンドラインからも検索可能
nix search nixpkgs htop
```

### 依存関係を最新にする

```bash
cd ~/dotfiles
nix flake update        # flake.lock を最新に更新
home-manager switch --flake .#yourname  # 適用
```

### ロールバック（元に戻す）

```bash
# 一世代前の設定に戻す
home-manager generations   # 世代の一覧を見る
home-manager rollback      # 直前の世代に戻す
```

### 設定をGitで管理する

```bash
cd ~/dotfiles
git add flake.nix flake.lock home.nix
git commit -m "Initial dotfiles setup"

# GitHubにpushして保存・公開
git remote add origin https://github.com/yourusername/dotfiles.git
git push -u origin main
```

---

## 10. 次のステップ

基本的な設定ができたら、以下のような拡張を検討してみてください。

### 設定をファイルに分ける

`home.nix` が大きくなってきたら、ファイルを分割できます：

```
~/dotfiles/
├── flake.nix
├── home.nix          # メイン（importsでファイルを読み込む）
├── git.nix           # Gitの設定
├── shell.nix         # シェルの設定
└── packages.nix      # パッケージ一覧
```

`home.nix` に `imports` を追加します：

```nix
{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./shell.nix
    ./packages.nix
  ];

  home.username = "yourname";
  home.homeDirectory = "/home/yourname";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
```

### よく使われる Home Manager のオプション

```nix
# Zshの設定
programs.zsh = {
  enable = true;
  autosuggestion.enable = true;   # 入力補完
  syntaxHighlighting.enable = true;  # シンタックスハイライト
};

# Fish shellの設定
programs.fish = {
  enable = true;
};

# SSH の設定
programs.ssh = {
  enable = true;
  addKeysToAgent = "yes";
};

# direnv（ディレクトリごとに環境を切り替える）
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;  # Nixプロジェクトと連携
};

# starship（カスタムプロンプト）
programs.starship = {
  enable = true;
};
```

### macOSの場合：nix-darwinも使う

macOSをお使いの場合、[nix-darwin](https://github.com/LnL7/nix-darwin) を使うと、システムレベルの設定（Dockの設定、macOSのデフォルトなど）も Nix で管理できます。ただしこれは中級者向けです。

### Home Manager のオプション一覧

[Home Manager Option Search](https://home-manager-options.extranix.com/) で、利用可能なオプションを検索できます。

---

## トラブルシューティング

### `nix` コマンドが見つからない

新しいターミナルを開く、またはシェルを再起動してください：

```bash
source ~/.bashrc  # または source ~/.zshrc
```

### `home-manager` コマンドが見つからない

`home.nix` に以下が含まれているか確認してください：

```nix
programs.home-manager.enable = true;
```

その後、フルパスで実行：

```bash
nix run home-manager/master -- switch --flake .#yourname
```

### パッケージが見つからないエラー

パッケージ名が間違っている可能性があります。[search.nixos.org](https://search.nixos.org/packages) で正確な名前を調べてください。

### flake.lock の競合

```bash
nix flake update  # ロックファイルを再生成
```

---

## 参考リソース

- [nixpkgs パッケージ検索](https://search.nixos.org/packages)
- [Home Manager オプション検索](https://home-manager-options.extranix.com/)
- [Nix公式ドキュメント](https://nix.dev/)
- [Home Manager公式ドキュメント](https://nix-community.github.io/home-manager/)
- [Zero to Nix（英語入門サイト）](https://zero-to-nix.com/)
- [参考にしたdotfiles: ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles)
