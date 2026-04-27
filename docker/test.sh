#!/usr/bin/env bash
# dotfiles-nix の動作確認テストスクリプト (Ubuntu ターゲット)
set -euo pipefail

# nix-daemon を起動する
# Determinate Systems installer は multi-user モードでインストールされるが、
# --init none により init system (systemd 等) には登録されないため手動起動が必要。
sudo /nix/var/nix/profiles/default/bin/nix-daemon &
sleep 2

# Nix の環境変数・PATH を読み込む (Determinate Systems installer のパス)
# shellcheck source=/dev/null
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

cd ~/dotfiles-nix

# ── カラー出力ヘルパー ─────────────────────────────────────
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m✓ %s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m✗ %s\033[0m\n' "$*"; exit 1; }
step()  { printf '\n\033[1m[%s] %s\033[0m\n' "$1" "$2"; }

bold "════════════════════════════════════════"
bold " dotfiles-nix テスト (Ubuntu)"
bold "════════════════════════════════════════"

# ──────────────────────────────────────────────────────────
# テスト 1: flake の入力・メタデータを確認
# nix flake metadata は outputs を評価しないため Linux 上でも
# darwinConfigurations に影響されずに実行できる。
# ──────────────────────────────────────────────────────────
step "1/3" "flake の入力を確認"
nix flake metadata --json \
  | grep -q '"nixpkgs"' \
  && green "nixpkgs が inputs に含まれています" \
  || red "flake.nix の読み込みに失敗しました"

nix flake metadata --json \
  | grep -q '"home-manager"' \
  && green "home-manager が inputs に含まれています" \
  || red "home-manager が inputs にありません"

# ──────────────────────────────────────────────────────────
# テスト 2: Ubuntu 向け Home Manager 設定を評価
# darwinConfigurations は Linux で評価するとエラーになるため、
# homeConfigurations."zenimoto@ubuntu" だけを対象にする。
# ──────────────────────────────────────────────────────────
step "2/3" "Ubuntu 設定を評価 (home.stateVersion)"
STATE=$(nix eval \
  '.#homeConfigurations."zenimoto@ubuntu".config.home.stateVersion' \
  --raw 2>&1) \
  && green "home.stateVersion = ${STATE}" \
  || red "Ubuntu 設定の評価に失敗しました (出力: ${STATE})"

EDITOR_PKG=$(nix eval \
  '.#homeConfigurations."zenimoto@ubuntu".config.programs.neovim.enable' \
  --raw 2>&1) \
  && green "programs.neovim.enable = ${EDITOR_PKG}" \
  || red "programs.neovim の評価に失敗しました"

FISH_ENABLED=$(nix eval \
  '.#homeConfigurations."zenimoto@ubuntu".config.programs.fish.enable' \
  --raw 2>&1) \
  && green "programs.fish.enable = ${FISH_ENABLED}" \
  || red "programs.fish の評価に失敗しました"

# ──────────────────────────────────────────────────────────
# テスト 3: activationPackage をビルド
# 実際に home-manager switch を実行せずにビルドだけ行う。
# パッケージは cache.nixos.org から取得するため
# ビルド自体は発生せず、数分で完了するはず。
# ──────────────────────────────────────────────────────────
step "3/3" "activationPackage をビルド"
echo "    nixpkgs を取得中... (初回は数分かかります)"
nix build \
  '.#homeConfigurations."zenimoto@ubuntu".activationPackage' \
  --no-link \
  --print-build-logs \
  && green "ビルド成功" \
  || red "ビルドに失敗しました"

bold ""
bold "════════════════════════════════════════"
bold " ✓ すべてのテストが通過しました"
bold "════════════════════════════════════════"
