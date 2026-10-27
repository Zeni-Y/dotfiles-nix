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
NIX_SOCKET=/nix/var/nix/daemon-socket/socket

# ─── 1. nix-daemon ───────────────────────────────────────────
# この RUN の中だけで使うので、終了時に必ず落としてソケットも消す。
# 消し忘れると /nix はイメージ層なのでソケットが焼き込まれ、コンテナ起動時の
# entrypoint.sh が「もう daemon が居る」と誤認して起動を飛ばす
# (結果、一般ユーザーから `Connection refused`)。
rm -f "${NIX_SOCKET}"
"${PROFILE}/bin/nix-daemon" --daemon &
DAEMON_PID=$!

cleanup() {
    kill "${DAEMON_PID}" 2>/dev/null || true
    wait "${DAEMON_PID}" 2>/dev/null || true
    rm -f "${NIX_SOCKET}"
    rm -f "${inner:-}"
}
trap cleanup EXIT

for _ in $(seq 1 100); do
    [ -S "${NIX_SOCKET}" ] && break
    kill -0 "${DAEMON_PID}" 2>/dev/null || break   # 即死したら待つ意味がない
    sleep 0.2
done
if [ ! -S "${NIX_SOCKET}" ] || ! kill -0 "${DAEMON_PID}" 2>/dev/null; then
    echo "ERROR: nix-daemon did not come up" >&2
    exit 1
fi
echo "==> nix-daemon is up (pid ${DAEMON_PID})"

# ─── 2. Home Manager ─────────────────────────────────────────
# 内側で実行するスクリプトはファイルに書き出す。setpriv 越しに
# 長いワンライナーを渡すとクォートが読めなくなるため。
#
# HOME_MANAGER_BACKUP_EXT は必須。useradd が /etc/skel から配った
# ~/.bashrc / ~/.profile と Home Manager の生成物が衝突するので、
# 退避先の拡張子を教えておかないと activation が止まる。
inner=$(mktemp)   # 後片付けは上の cleanup がまとめて見る
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
