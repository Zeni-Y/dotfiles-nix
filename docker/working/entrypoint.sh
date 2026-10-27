#!/usr/bin/env bash
# コンテナ起動時に nix-daemon を上げ、GitHub から公開鍵を取得して
# authorized_keys を組み立て、sshd を foreground 実行する。
#
#   1. nix-daemon を起動する
#      systemd が無いので誰も面倒を見てくれない。これが居ないと
#      一般ユーザーは store に書けず `home-manager switch` も失敗する。
#   2. authorized_keys を組み立てる
#      取得元: https://github.com/${GITHUB_USER}.keys
#      - GitHub に登録されている公開鍵をそのまま流し込むので、鍵の増減は
#        GitHub 側で完結する（コンテナの再ビルドは不要、再起動だけでよい）。
#      - ネットワーク不達 / 空レスポンス時は既存の authorized_keys を維持し、
#        誤って鍵を消してログインできなくなる事故を避ける。
#   3. sshd を foreground 実行する
set -euo pipefail

: "${USERNAME:?USERNAME must be set (build-arg of Dockerfile)}"
: "${GITHUB_USER:?GITHUB_USER must be set (build-arg or -e GITHUB_USER=...)}"

NIX_PROFILE=/nix/var/nix/profiles/default
NIX_SOCKET=/nix/var/nix/daemon-socket/socket

# ─── 1. nix-daemon ───────────────────────────────────────────
# ソケットの有無で「起動済み」と判断してはいけない。/nix はボリュームでは
# なくイメージ層なので、ビルド時に bake-dotfiles.sh が上げた daemon の
# ソケットがそのまま焼き込まれて残る。新しいコンテナではファイルだけが
# 存在して listen している相手は居らず、
#   error: cannot connect to socket at '...': Connection refused
# になる (しかも entrypoint は「もう居る」と誤認して黙って先へ進むので、
# ログを見ても気付けない)。
#
# entrypoint はコンテナ起動時に 1 度だけ走り、その時点で生きた daemon は
# 居ないので、残骸を消して無条件に起こす。起動確認もファイルの出現では
# 足りないので、プロセスが生きているかまで見る。
if [ -x "${NIX_PROFILE}/bin/nix-daemon" ]; then
    rm -f "${NIX_SOCKET}"
    "${NIX_PROFILE}/bin/nix-daemon" --daemon &
    daemon_pid=$!
    for _ in $(seq 1 100); do
        [ -S "${NIX_SOCKET}" ] && break
        kill -0 "${daemon_pid}" 2>/dev/null || break   # 即死したら待つ意味がない
        sleep 0.2
    done
    if [ -S "${NIX_SOCKET}" ] && kill -0 "${daemon_pid}" 2>/dev/null; then
        echo "==> nix-daemon is up (pid ${daemon_pid})"
    else
        echo "WARN: nix-daemon did not come up; nix may not work for non-root users" >&2
    fi
else
    echo "WARN: nix-daemon not found; this image seems to be built without Nix" >&2
fi

# ─── 2. authorized_keys ──────────────────────────────────────
SSH_DIR="/home/${USERNAME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"
TMP_KEYS="${AUTH_KEYS}.new"

mkdir -p "${SSH_DIR}"

if curl -fsSL --max-time 10 "https://github.com/${GITHUB_USER}.keys" -o "${TMP_KEYS}"; then
    if [ -s "${TMP_KEYS}" ]; then
        mv "${TMP_KEYS}" "${AUTH_KEYS}"
        echo "==> authorized_keys updated from https://github.com/${GITHUB_USER}.keys ($(wc -l < "${AUTH_KEYS}") key(s))"
    else
        rm -f "${TMP_KEYS}"
        echo "WARN: https://github.com/${GITHUB_USER}.keys returned empty body; keeping existing authorized_keys" >&2
    fi
else
    rm -f "${TMP_KEYS}"
    echo "WARN: failed to fetch keys from GitHub; keeping existing authorized_keys" >&2
fi

chown -R "${USERNAME}:${USERNAME}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
[ -f "${AUTH_KEYS}" ] && chmod 600 "${AUTH_KEYS}"

# ─── 3. sshd ─────────────────────────────────────────────────
exec /usr/sbin/sshd -D -e
