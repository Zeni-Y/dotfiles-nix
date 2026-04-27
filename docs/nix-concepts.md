# Nix 概念ガイド

このリポジトリを読み書きするのに必要な Nix の構文・概念・ライフサイクルをまとめた資料です。

---

## 目次

1. [Nix 言語の基本構文](#1-nix-言語の基本構文)
2. [Nix の核心概念](#2-nix-の核心概念)
3. [Flakes のしくみ](#3-flakes-のしくみ)
4. [モジュールシステム](#4-モジュールシステム)
5. [Home Manager のライフサイクル](#5-home-manager-のライフサイクル)
6. [nix-darwin のライフサイクル](#6-nix-darwin-のライフサイクル)
7. [よく使うコマンド早見表](#7-よく使うコマンド早見表)
8. [外部ツールによる変更を Nix に取り込む](#8-外部ツールによる変更を-nix-に取り込む)

---

## 1. Nix 言語の基本構文

Nix は「設定を書くための純粋関数型言語」です。
プログラムを実行するのではなく、**どんな環境を作るかを記述する** ために使います。

### 1-1. 基本的な値

```nix
# 文字列
"hello"
''
  複数行文字列は二重シングルクォート。
  先頭の共通インデントは自動で除去される。
''

# 文字列補間
let name = "zenimoto"; in "Hello, ${name}!"   # => "Hello, zenimoto!"

# 数値
42
3.14

# 真偽値
true
false

# null
null

# パス (クォートなし。ファイルシステムのパスとして扱われる)
./home/git.nix          # 相対パス → 評価時に絶対パスへ
/nix/store              # 絶対パス
```

### 1-2. リスト

```nix
[ "a" "b" "c" ]         # 区切りはスペース (カンマ不要)
[ 1 2 3 ]
[ ./foo.nix ./bar.nix ] # パスのリスト
```

### 1-3. アトリビュートセット (attribute set / attrset)

他の言語でいう「オブジェクト」や「辞書」に相当します。

```nix
{
  name = "zenimoto";
  age  = 30;
  git  = {                # ネスト可
    email = "you@example.com";
  };
}

# ドット記法でアクセス
let person = { name = "zenimoto"; }; in
person.name     # => "zenimoto"

# ? でデフォルト値
person.nickname or "no nickname"
```

### 1-4. `let ... in`

ローカル変数を定義します。`in` 以降の式の中でのみ有効です。

```nix
let
  x = 10;
  y = 20;
  sum = x + y;
in
"合計は ${toString sum}"   # => "合計は 30"
```

### 1-5. `inherit`

`inherit x;` は `x = x;` の糖衣構文です。同名の変数を attrset に持ち込みます。

```nix
let
  system = "x86_64-linux";
  pkgs   = import nixpkgs { inherit system; };
  #                          ↑ これは system = system; と同じ
in
{ inherit system pkgs; }
# ↑ { system = system; pkgs = pkgs; } と同じ
```

### 1-6. 関数

Nix の関数は常に引数を 1 つだけ取ります。複数引数はカリー化か attrset で表現します。

```nix
# 基本形: 引数 → 本体
x: x + 1

# 呼び出し (括弧不要。スペースで適用)
(x: x + 1) 5   # => 6

# attrset を引数にとる (= 名前付き引数)
{ a, b }: a + b

# デフォルト値付き
{ a, b ? 10 }: a + b

# 残りを ... で受け取る (Home Manager モジュールで頻出)
{ a, ... }: a

# 引数に名前を付ける (@パターン)
args @ { a, b, ... }: args.a + b
```

### 1-7. `with`

attrset のスコープを展開します。`pkgs.ripgrep` を `ripgrep` と書けるようになります。

```nix
with pkgs; [
  ripgrep
  fd
  bat
]
# ↑ [ pkgs.ripgrep pkgs.fd pkgs.bat ] と同じ
```

### 1-8. `if` 式

文ではなく式なので、必ず `else` が要ります。

```nix
if stdenv.isDarwin
  then "/Users/zenimoto"
  else "/home/zenimoto"
```

### 1-9. `import`

別ファイルの Nix 式を読み込みます。

```nix
import ./home/git.nix        # ファイルの中身がそのまま式として展開される
import ./home/git.nix { }    # ファイルが関数なら引数を渡して呼び出す
```

### 1-10. `rec` (再帰 attrset)

attrset 内で自身の他の属性を参照できるようになります。

```nix
rec {
  base = "/home/zenimoto";
  config = "${base}/.config";   # base を参照できる
}
```

---

## 2. Nix の核心概念

### 2-1. Nix Store (`/nix/store/`)

すべてのパッケージ・ビルド結果が格納される場所です。

```
/nix/store/
  ├── abc123...-git-2.44.0/        ← git 本体
  ├── def456...-ripgrep-14.0.0/   ← ripgrep
  └── ghi789...-home-manager-generation/  ← HM の世代
```

各ディレクトリ名の先頭ハッシュは **入力の完全な記述 (ソース・依存・ビルドオプションなど) から計算** されます。  
→ 同じ入力からは必ず同じパスになる (**再現性**)  
→ 別バージョン・別設定のパッケージが同時に共存できる (**副作用なし**)

### 2-2. Derivation (ビルドレシピ)

「どのソースを、どの依存を使って、どうビルドするか」を記述した attrset です。
`pkgs.ripgrep` と書いたとき、実体は derivation です。

```
derivation
  └── /nix/store/<hash>-ripgrep-14.0.0.drv  (ビルド指示書)
        → realisation →
  /nix/store/<hash>-ripgrep-14.0.0/          (実際のファイル)
```

### 2-3. Realisation (実体化)

Derivation を実際にビルド (またはキャッシュから取得) してストアパスを作ることです。
`nix build` や `home-manager switch` の中で自動的に行われます。

### 2-4. Closure (クロージャ)

あるパッケージとその **推移的な依存関係の全体** のことです。

```
ripgrep の closure
  ├── ripgrep 本体
  ├── glibc
  └── gcc-runtime
```

`nix copy` などは closure 単位で転送します。

### 2-5. Profile と Generation

**Profile**: 現在アクティブなパッケージ群への「エイリアス」。  
`~/.nix-profile/bin/` は実際には `/nix/store/` 以下への symlink 群です。

**Generation**: Profile の履歴です。`switch` するたびに新世代が作られます。

```
~/.local/state/home-manager/gcroots/
  current-home  → /nix/store/<hash>-home-manager-generation/  ← 現在
  link-1        → /nix/store/<hash>-home-manager-generation/  ← 1世代前
  link-2        → /nix/store/<hash>-home-manager-generation/  ← 2世代前
```

前の世代に戻すことを **ロールバック** といいます。

### 2-6. Garbage Collection

どの Generation からも参照されていないストアパスを削除します。

```bash
nix-collect-garbage        # 参照のないものを削除
nix-collect-garbage -d     # 古い世代ごと削除してから GC
```

**GC Root**: GC の対象にならないよう守られる起点。Generation や `nix build` の結果が登録されます。

### 2-7. Lazy Evaluation (遅延評価)

Nix は式を **必要になるまで評価しません**。  
`home.packages` に書いた数十パッケージも、実際に使われる部分だけが評価・ビルドされます。  
これが巨大な nixpkgs を扱いながら高速なのと、「一部だけビルドする」が自然にできる理由です。

### 2-8. Pure / Impure

Nix の評価はデフォルトで **pure (純粋)** です。  
→ 同じ入力からは必ず同じ出力が得られる  
→ ネットワークアクセス・時刻・環境変数などの副作用を評価中に使えない  
→ Flakes はこれを flake.lock で保証する

---

## 3. Flakes のしくみ

### 3-1. `flake.nix` の構造

```
flake.nix
├── description   説明文字列
├── inputs        依存する外部 flake (nixpkgs など)
└── outputs       この flake が外に出力するもの
```

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    #              └─ GitHub のオーナー/リポジトリ/ブランチ
  };

  outputs = { nixpkgs, ... }:  # inputs が引数として渡ってくる
  {
    homeConfigurations."zenimoto@ubuntu" = ...;
    darwinConfigurations."mac" = ...;
  };
}
```

### 3-2. `inputs.X.follows`

依存する flake が使う nixpkgs を、**自分の nixpkgs と同じバージョンに固定** する指定です。

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
    # ↑ home-manager が依存する nixpkgs を、
    #   自分の nixpkgs と同じものにする
    #   (なければ別バージョンが2つダウンロードされる)
  };
};
```

### 3-3. `flake.lock` (ロックファイル)

`git clone` した直後の `flake.lock` は **その時点での inputs の完全なコミット SHA を記録** しています。

```json
{
  "nodes": {
    "nixpkgs": {
      "locked": {
        "rev": "abc123...",    // 固定されたコミット
        "narHash": "sha256-..." // コンテンツのハッシュ
      }
    }
  }
}
```

`nix flake update` を実行するまで inputs のバージョンは変わりません。  
→ 半年後に別マシンでビルドしても **完全に同じパッケージが入る**

### 3-4. `outputs` に書けるもの

よく使うキー:

| キー | 用途 |
|---|---|
| `homeConfigurations.<name>` | `home-manager switch` のターゲット |
| `darwinConfigurations.<name>` | `darwin-rebuild switch` のターゲット |
| `nixosConfigurations.<name>` | `nixos-rebuild switch` のターゲット |
| `packages.<system>.<name>` | `nix build .#<name>` でビルドできるパッケージ |
| `devShells.<system>.<name>` | `nix develop .#<name>` で入れる開発シェル |
| `apps.<system>.<name>` | `nix run .#<name>` で実行できるアプリ |

---

## 4. モジュールシステム

Home Manager や NixOS の設定は**モジュールシステム**の上に成り立っています。

### 4-1. モジュールの基本形

```nix
# home/git.nix
{ config, pkgs, lib, ... }:  # ← 引数 (attrset パターン)
{
  # ── 何を設定するか ──
  programs.git = {
    enable = true;
    userName = "zenimoto";
  };

  home.packages = [ pkgs.gh ];
}
```

引数の意味:

| 引数 | 内容 |
|---|---|
| `config` | **すべてのモジュールを評価した後の最終的な設定値** |
| `pkgs` | nixpkgs のパッケージ集合 |
| `lib` | Nix ライブラリ関数 (型チェック・リスト操作など) |
| `...` | 上記以外の引数を無視 (ないと未知の引数でエラーになる) |

### 4-2. `imports` による合成

```nix
# home/default.nix
{ ... }:
{
  imports = [
    ./git.nix
    ./tmux.nix
    ./shell
  ];
}
```

`imports` に並べたモジュールは**すべてマージ**されます。  
同じオプションに複数のモジュールが値を書いても、型に応じてマージルールが決まります:

```nix
# モジュール A
{ home.packages = [ pkgs.ripgrep ]; }

# モジュール B
{ home.packages = [ pkgs.fd ]; }

# 評価後 (リストは結合される)
{ home.packages = [ pkgs.ripgrep pkgs.fd ]; }
```

### 4-3. 評価の順序

重要なのは「**書いた順序に意味はない**」ことです。

```
すべての imports を収集
      ↓
すべてのモジュールをマージ
      ↓
config を遅延評価 (参照が解決できるまで繰り返す)
      ↓
最終的な config からファイル・パッケージを実体化
```

これにより `./git.nix` の中から `config.programs.gh.enable` (別ファイルで定義) を参照できます。

### 4-4. `options` / `config` の分離 (上級)

モジュールは「オプション定義」と「設定値」を分離して書くこともできます。

```nix
{ lib, config, ... }:
{
  # オプションを宣言する
  options.my.name = lib.mkOption {
    type = lib.types.str;
    default = "anonymous";
    description = "表示名";
  };

  # config ブロックで値をセットする
  config = {
    home.sessionVariables.MY_NAME = config.my.name;
  };
}
```

`programs.git` のような HM 組み込みモジュールは、内部でこれをやっています。  
`options.programs.git.userName` を宣言し、その値から `~/.config/git/config` を生成しています。

---

## 5. Home Manager のライフサイクル

### 5-1. `home-manager switch` が何をするか

```
home-manager switch --flake .#zenimoto@ubuntu
        │
        ▼
① flake.nix を評価
   homeConfigurations."zenimoto@ubuntu" の attrset を取得

        ▼
② すべての modules をマージして config を計算
   (packages.nix, git.nix, shell/fish.nix, … を全部合成)

        ▼
③ 差分を確認
   現在の世代と新しい config を比較

        ▼
④ Realisation
   必要なパッケージを /nix/store/ にビルド or キャッシュから取得

        ▼
⑤ Activation (アクティベーション)
   ・~/.config/git/config など設定ファイルを symlink で配置
   ・~/.nix-profile を新しい世代に向け直す
   ・ユーザーサービス (systemd など) を再起動

        ▼
⑥ 新しい世代を登録 → ロールバック可能になる
```

### 5-2. Activation の中身

「設定ファイルを配置する」といっても、HM はファイルを **コピーではなく symlink** します。

```
~/.config/git/config
  └──→ /nix/store/<hash>-home-manager-files/.config/git/config
```

→ ストア上のファイルは読み取り専用 → 誤って手動編集しても次の switch で元に戻る

### 5-3. `xdg.configFile` と `home.file` の違い

| オプション | 配置先 |
|---|---|
| `xdg.configFile."foo"` | `~/.config/foo` |
| `home.file.".foo"` | `~/.foo` |

```nix
xdg.configFile."git/config".text = "...";  # → ~/.config/git/config
home.file.".gitconfig".text = "...";       # → ~/.gitconfig
```

### 5-4. Generation とロールバック

```bash
# 現在の世代を確認
home-manager generations
# 例:
# 2024-01-15 12:00 : id 5 -> /nix/store/abc-home-manager-generation
# 2024-01-10 09:00 : id 4 -> /nix/store/def-home-manager-generation

# 特定の世代に戻す
/nix/store/def...-home-manager-generation/activate

# 古い世代を削除 (GC の前に実行)
home-manager expire-generations "-30 days"
```

---

## 6. nix-darwin のライフサイクル

### 6-1. nix-darwin とは

macOS には NixOS のようなシステム全体を Nix で管理する仕組みがデフォルトで存在しません。  
**nix-darwin** はそのギャップを埋め、macOS のシステム設定を宣言的に管理します。

```
nix-darwin が管理するもの
  ├── /etc/zshrc, /etc/bashrc などシステムシェル設定
  ├── system.defaults (defaults write 相当の設定)
  ├── Homebrew (casks / formulae の宣言)
  └── launchd サービス
```

### 6-2. `darwin-rebuild switch` が何をするか

```
sudo darwin-rebuild switch --flake .#mac
        │
        ▼
① flake.nix を評価
   darwinConfigurations."mac" を取得

        ▼
② darwin/ モジュールと home-manager モジュールをマージ

        ▼
③ 必要なパッケージを Realise

        ▼
④ macOS システムへの Activation
   ├── system.defaults を defaults write で書き込み
   ├── /etc/ 以下のファイルを更新
   ├── Homebrew: brew bundle を実行
   │     → casks に書いたものをインストール
   │     → cleanup = "zap" なら宣言にないものをアンインストール
   └── Home Manager の activation も実行 (ユーザー設定を配置)

        ▼
⑤ 新しいシステム世代を登録
```

### 6-3. home-manager と nix-darwin の役割分担

```
nix-darwin
  └── darwin/ 配下のモジュール
        ├── /etc/ レベルの設定
        └── Homebrew (管理者権限が必要な操作)

home-manager (nix-darwin に同居)
  └── home/ 配下のモジュール
        ├── ~/.config/ 以下の設定ファイル
        └── ユーザー PATH に入るパッケージ
```

このリポジトリでは `hosts/macos.nix` が両者を 1 つの `darwinSystem` にまとめています。

---

## 7. よく使うコマンド早見表

### 設定の適用

```bash
# Ubuntu: ユーザー設定を反映
home-manager switch --flake .#zenimoto@ubuntu

# macOS: システム+ユーザー設定を反映
sudo darwin-rebuild switch --flake .#mac

# 変更内容をドライラン (実際には何もしない)
home-manager build --flake .#zenimoto@ubuntu
```

### Flake / パッケージ操作

```bash
# inputs を最新に更新 (flake.lock を書き換える)
nix flake update

# 特定の input だけ更新
nix flake update nixpkgs

# flake の評価エラーを確認
nix flake check

# nixpkgs でパッケージを検索
nix search nixpkgs ripgrep

# パッケージを一時的に試す (インストール不要)
nix shell nixpkgs#ripgrep
```

### 世代管理

```bash
# Home Manager の世代一覧
home-manager generations

# nix-darwin の世代一覧
darwin-rebuild --list-generations

# 古い世代を削除してからストアを GC
home-manager expire-generations "-30 days"
nix-collect-garbage -d
```

### デバッグ

```bash
# あるパッケージが store のどこにあるか確認
nix eval nixpkgs#ripgrep.outPath

# 設定の最終的な評価結果を確認
nix eval .#homeConfigurations."zenimoto@ubuntu".config.home.packages

# ビルドログを詳細表示
home-manager switch --flake .#zenimoto@ubuntu --show-trace
```

---

## 8. 外部ツールによる変更を Nix に取り込む

外部ツール (Claude Code、`git config --global`、エディタの設定 UI など) が
設定ファイルを書き換えようとしたとき、または書き換えた結果を Nix 設定に反映したいときの
対処法をまとめます。

### 8-1. まず「Nix が管理しているか」を確認する

HM が管理する設定ファイルは **Nix ストアへの symlink** になっており、**読み取り専用** です。

```bash
# symlink かどうか確認
ls -la ~/.config/git/config

# Nix 管理下の場合 (読み取り専用)
# ~/.config/git/config -> /nix/store/<hash>-home-manager-files/.config/git/config

# Nix 非管理の場合 (通常のファイル)
# ~/.config/git/config
```

これにより 2 つのケースに分かれます。

---

### 8-2. ケース A: Nix が管理しているファイルを変更したい

`programs.git` などで管理している場合、**外部ツールからの書き込みは失敗します**。

```bash
# 例: git config --global は読み取り専用の symlink に書こうとして失敗する
git config --global user.email "new@example.com"
# error: could not lock config file: Read-only file system
```

**対処: .nix ファイルを編集 → switch する**

```bash
# 1. 対応する .nix ファイルを開いて値を変更する
#    例: git のメールを変えたい → home/git.nix の userEmail を編集
$EDITOR home/git.nix

# 2. 設定を反映する
home-manager switch --flake .#zenimoto@ubuntu   # Ubuntu
sudo darwin-rebuild switch --flake .#mac         # macOS
```

> **重要**: 次の `switch` まで古い値が使われます。ツールが「設定を変更した」と報告しても、
> 実際には書き込みに失敗している場合があります。`ls -la` で symlink を確認してください。

---

### 8-3. ケース B: Nix が管理していないファイルが変更された

Claude Code の `settings.json` など、このリポジトリで宣言していないファイルは
ツールが自由に読み書きできます。

```
~/.config/claude/settings.json   ← Nix 非管理 → Claude が自由に変更できる
~/.config/git/config             ← Nix 管理   → 読み取り専用
```

変更内容を Nix で管理したくなった場合の手順:

```bash
# 1. 現在のファイル内容を確認
cat ~/.config/claude/settings.json

# 2. 対応する .nix ファイルに内容を移す
#    例: xdg.configFile を使う場合
$EDITOR home/editors/neovim.nix   # 適切なモジュールに追記
```

```nix
# home/ 内の適当なファイルに追記する例
xdg.configFile."claude/settings.json".text = builtins.toJSON {
  theme = "dark";
  # ... ツールが書いた内容をここに転記
};
```

```bash
# 3. switch → 以降はこのファイルも Nix 管理になり読み取り専用になる
home-manager switch --flake .#zenimoto@ubuntu
```

> **注意**: Nix 管理下に置くと、以降 Claude Code は自動的にこのファイルを更新できなくなります。
> ツールが設定を自動保存する場合は、Nix 管理外のままにしておく方が実用的です (→ 8-4 参照)。

---

### 8-4. 「ツールに自動更新させたい」場合の方針

Claude Code・エディタのプラグイン設定など、**ツールが頻繁に自動書き換えるファイル**は
Nix 管理外のままにしておくのが現実的です。

| ファイルの性質 | 推奨方針 |
|---|---|
| ほぼ変わらない (git のユーザー名など) | Nix で管理 (`programs.git` など) |
| 手動でたまに変える | Nix で管理してもよい |
| ツールが頻繁に自動更新する (Claude 設定、LSP キャッシュなど) | **Nix 管理外のままにする** |
| 秘密情報を含む (トークン、パスワード) | **絶対に Nix 管理しない** (Nix store は全ユーザーが読める) |

#### 「Nix 管理外」のファイルをバージョン管理したい場合

Nix ではなく git で直接追跡します。

```bash
# dotfiles-nix リポジトリ内に置いて git で管理する
mkdir -p extras/
cp ~/.config/claude/settings.json extras/claude-settings.json
git add extras/claude-settings.json
git commit -m "chore: Claude Code 設定をバックアップ"

# 新しいマシンへの移植は手動コピー
cp extras/claude-settings.json ~/.config/claude/settings.json
```

---

### 8-5. 変更を Nix に取り込む標準的なワークフロー

外部ツールが設定を変更した後の「逆引き反映」の手順をまとめます。

```
外部ツールが設定を変更した
        │
        ▼
ls -la <変更されたファイル>
        │
        ├─ symlink → /nix/store/... (Nix 管理)
        │       │
        │       └─ 実際には書き込み失敗している
        │          → .nix ファイルを直接編集 → switch
        │
        └─ 通常ファイル (Nix 非管理)
                │
                ├─ Nix で管理したい
                │     → .nix に内容を転記 → switch
                │       (以降ツールは自動更新できなくなる)
                │
                └─ Nix 管理不要 (ツールが頻繁に更新するなど)
                      → git で直接管理 or 管理しない
```

#### 具体例: `git config --global` で変更した設定を Nix に反映する

```bash
# ❌ これは読み取り専用のため失敗する
git config --global core.autocrlf false

# ✅ 正しい手順: home/git.nix を編集する
```

```nix
# home/git.nix
programs.git = {
  extraConfig = {
    core.autocrlf = false;  # ← ここに追記
  };
};
```

```bash
home-manager switch --flake .#zenimoto@ubuntu
```

#### 具体例: Claude Code が `~/.config/claude/settings.json` を更新した

このリポジトリでは Claude の設定を Nix 管理外にしているため、
Claude が書き換えた内容はそのまま有効です。次の `switch` で上書きされることもありません。

設定を dotfiles に残したい場合は `extras/` に手動コピーして git で管理します。

---

### 8-6. `home-manager switch` は Nix 宣言を強制適用する

どのケースでも共通して覚えておくべきことがあります:

> **`home-manager switch` を実行すると、Nix で宣言した値がすべて強制的に適用されます。**
> Nix 管理下のファイルへの「switch 間の手動変更」はすべて上書きされます。

これを逆に活用すると:

```bash
# 設定が壊れた/汚れた → switch するだけで Nix 宣言の状態に戻る
home-manager switch --flake .#zenimoto@ubuntu
```

Nix 管理の設定は「ソースオブトゥルース (.nix ファイル)」に常に戻せる、という保証になります。

---

## 参考リンク

- [Nix 言語リファレンス](https://nix.dev/manual/nix/stable/language/)
- [Home Manager オプション一覧](https://nix-community.github.io/home-manager/options.xhtml)
- [nix-darwin オプション一覧](https://daiderd.com/nix-darwin/manual/index.html)
- [nixpkgs パッケージ検索](https://search.nixos.org/packages)
- [nix.dev (チュートリアル集)](https://nix.dev/)
