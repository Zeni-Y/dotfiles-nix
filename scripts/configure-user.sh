#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# flake.nix の userInfo を対話的に書き換える
#
# 初回セットアップで各ユーザーが書き換える必要のある個人情報
# (username / gitName / gitEmail / githubUser / windowsUsername) は
# flake.nix の userInfo に集約してある。このスクリプトは現在値を
# デフォルトとして順に質問し、flake.nix のその行だけを書き換える。
#
# 使い方:
#   ./scripts/configure-user.sh
#
# Enter だけ押せば現在値を維持する。書き換え後の確認は:
#   git diff flake.nix
#   nix flake check --no-build
# ─────────────────────────────────────────────────────────────
set -euo pipefail

FLAKE="$(cd "$(dirname "$0")/.." && pwd)/flake.nix"
[ -f "$FLAKE" ] || { echo "flake.nix が見つかりません: $FLAKE" >&2; exit 1; }

# userInfo 内のキーの現在値を取り出す (値は "..." か null の前提)
current() {
    sed -n "s/^ *$1 = \"\{0,1\}\([^\";]*\)\"\{0,1\};.*/\1/p" "$FLAKE" | head -n1
}

# キーの行を丸ごと書き換える。行末コメントは保持する。
# $3 に raw を渡すと引用符を付けない (null 用)。
set_value() {
    local key=$1 value=$2 mode=${3:-quoted}
    [ "$mode" = quoted ] && value="\"$value\""
    sed -i "s|^\( *\)$key = [^;]*;|\1$key = $value;|" "$FLAKE"
}

ask() {
    local prompt=$1 cur=$2 input
    read -rp "$prompt [$cur]: " input
    echo "${input:-$cur}"
}

echo "flake.nix の userInfo を設定します (Enter で現在値を維持)"
echo

username=$(ask "Linux のユーザー名 (username)" "$(current username)")
git_name=$(ask "git のコミット名 (gitName)" "$(current gitName)")
git_email=$(ask "git のコミットアドレス (gitEmail)" "$(current gitEmail)")
github_user=$(ask "GitHub の owner 名 (githubUser)" "$(current githubUser)")
windows_username=$(ask "Windows ユーザー名。WSL 以外なら null (windowsUsername)" "$(current windowsUsername)")

set_value username "$username"
set_value gitName "$git_name"
set_value gitEmail "$git_email"
set_value githubUser "$github_user"
if [ "$windows_username" = "null" ] || [ -z "$windows_username" ]; then
    set_value windowsUsername null raw
else
    set_value windowsUsername "$windows_username"
fi

echo
echo "flake.nix を更新しました。差分と評価結果を確認してください:"
echo "  git diff flake.nix"
echo "  nix flake check --no-build"
echo "問題なければ Home Manager を適用します (初回は -b backup 付き):"
echo "  nix run home-manager/master -- switch -b backup --flake .#${username}@ubuntu"
