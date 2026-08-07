#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# イメージビルド時に Home Manager を適用する (Dockerfile から root で実行)。
#
#   1. nix-daemon を起動する
#      systemd が無いので誰も面倒を見てくれない。これが居ないと
#      一般ユーザーは store に書けず activationPackage のビルドが失敗する。
#   2. ユーザー権限に降りて activationPackage をビルドし activate する
#      root のまま走らせると Home Manager が「USER が違う」と言って止まる。
#   3. ビルドの中間生成物を GC してイメージサイズを削る
#
# 環境変数:
#   USERNAME  … 適用先ユーザー (Dockerfile の ARG/ENV から渡る)
#   HM_CONFIG … homeConfigurations の名前 (例: zenimoto@ubuntu)
#   REPO      … リポジトリのパス (既定: /home/${USERNAME}/dotfiles-nix)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

: "${USERNAME:?USERNAME must be set (build-arg of Dockerfile)}"
: "${HM_CONFIG:?HM_CONFIG must be set (build-arg of Dockerfile)}"
REPO="${REPO:-/home/${USERNAME}/dotfiles-nix}"

PROFILE=/nix/var/nix/profiles/default

# ─── 1. nix-daemon ───────────────────────────────────────────
if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
    "${PROFILE}/bin/nix-daemon" --daemon &
    for _ in $(seq 1 100); do
        [ -S /nix/var/nix/daemon-socket/socket ] && break
        sleep 0.2
    done
fi
if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
    echo "ERROR: nix-daemon socket did not appear" >&2
    exit 1
fi
echo "==> nix-daemon is up"

# ─── 2. Home Manager ─────────────────────────────────────────
# 内側で実行するスクリプトはファイルに書き出す。setpriv 越しに
# 長いワンライナーを渡すとクォートが読めなくなるため。
#
# HOME_MANAGER_BACKUP_EXT は必須。useradd が /etc/skel から配った
# ~/.bashrc / ~/.profile と Home Manager の生成物が衝突するので、
# 退避先の拡張子を教えておかないと activation が止まる。
inner=$(mktemp)
trap 'rm -f "${inner}"' EXIT
cat >"${inner}" <<EOS
set -eu
out=\$(nix build --no-link --print-out-paths \\
    '${REPO}#homeConfigurations."${HM_CONFIG}".activationPackage')
"\$out"/activate
EOS
# mktemp は 0600 / root 所有で作るので、降りた先のユーザーから読めるようにする
chmod 644 "${inner}"

setpriv --reuid="$(id -u "${USERNAME}")" --regid="$(id -g "${USERNAME}")" --init-groups \
    env HOME="/home/${USERNAME}" USER="${USERNAME}" \
        PATH="${PROFILE}/bin:/usr/bin:/bin" \
        HOME_MANAGER_BACKUP_EXT=backup \
    bash "${inner}"

echo "==> home-manager activation done (${HM_CONFIG})"

# ─── 3. GC ───────────────────────────────────────────────────
nix store gc --quiet 2>/dev/null || true
