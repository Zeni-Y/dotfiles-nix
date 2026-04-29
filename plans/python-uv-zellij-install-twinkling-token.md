# uv と zellij を Home Manager で導入する

## Context

普段使いの開発環境に Python 用パッケージマネージャ `uv` (astral-sh) と、ターミナルマルチプレクサ `zellij` を追加したい。
現状この dotfiles-nix リポジトリにはどちらの記述もなく、毎回手で入れるのは面倒なので、Linux/macOS どちらでも Home Manager 経由で管理されるようにする。

- `uv`: Python 本体の管理 (`uv python install`) と仮想環境/依存解決を 1 バイナリでこなせる。本体の Python は uv に任せ、Nix では入れない方針。
- `zellij`: tmux と並行運用したいので自動起動はせず、`zellij` コマンド実行時のみ起動する。設定は最低限 `default_shell = "fish"` のみを Nix で持たせ、それ以上の調整は後から `programs.zellij.settings` を増やす形にする。

## 既存パターン

このリポジトリは Nix Flake + Home Manager (Linux 用 `hosts/ubuntu.nix`, macOS 用 `hosts/macos.nix` 経由) 構成。

- 入れるだけのツール → `home/packages.nix` の `home.packages` に追記
  - 例: `ripgrep`, `fd`, `lazygit` など
- シェル統合や設定が必要なツール → `home/cli/<tool>.nix` を作って `programs.<tool>` で書き、`home/cli/default.nix` の `imports` に追加
  - 例: `home/cli/fzf.nix`, `home/cli/zoxide.nix`, `home/cli/eza.nix`

## 変更内容

### 1. `home/packages.nix` に `uv` を追加

`home/packages.nix:52` 付近、「その他便利系」のセクションに 1 行追加するか、新規に Python 用カテゴリコメントを追加:

```nix
# Python 環境管理 (Python 本体は `uv python install` で管理)
uv
```

`uv` は単独バイナリで Home Manager 専用モジュールが不要なので `home.packages` で十分。

### 2. `home/cli/zellij.nix` を新規作成

最小設定として `default_shell` のみ Nix で持たせる。シェル統合 (auto-start) は無効。

```nix
# zellij: ターミナルマルチプレクサ。自動起動はせず、コマンド実行時のみ使う。
{ ... }:

{
  programs.zellij = {
    enable = true;
    # enableFishIntegration は意図的に false (デフォルト)。
    # 起動時の自動アタッチは行わず、必要なときに `zellij` を手動で叩く。
    settings = {
      default_shell = "fish";
    };
  };
}
```

### 3. `home/cli/default.nix` に zellij をインポート

`home/cli/default.nix` の `imports` リストに `./zellij.nix` を追加。アルファベット順を踏襲して末尾近くに置く。

```nix
imports = [
  ./bat.nix
  ./direnv.nix
  ./fzf.nix
  ./gh.nix
  ./zoxide.nix
  ./eza.nix
  ./zellij.nix   # 追加
];
```

## 変更対象ファイル

- `/home/zenimoto/host/ghq/dotfiles-nix/home/packages.nix` (編集)
- `/home/zenimoto/host/ghq/dotfiles-nix/home/cli/zellij.nix` (新規作成)
- `/home/zenimoto/host/ghq/dotfiles-nix/home/cli/default.nix` (編集)

## 検証手順

1. Flake 構文チェック
   ```sh
   nix flake check --no-build
   ```
2. Home Manager 適用 (Ubuntu の場合)
   ```sh
   home-manager switch --flake .#zenimoto@ubuntu
   ```
   または既存 Makefile / 普段使いの apply コマンドがあればそれを使う。
3. インストール確認
   ```sh
   uv --version
   zellij --version
   ```
4. uv 動作確認
   ```sh
   uv python install 3.12   # 任意
   uv init /tmp/uv-smoke && cd /tmp/uv-smoke && uv add requests
   ```
5. zellij 動作確認
   ```sh
   zellij                 # 起動 → 中で fish が立ち上がること
   # Ctrl-q で抜ける
   cat ~/.config/zellij/  # Nix 管理の config.kdl が置かれていることを確認
   ```
6. シェル起動時に zellij が自動アタッチされない (＝普通の fish プロンプトが出る) ことを確認。
