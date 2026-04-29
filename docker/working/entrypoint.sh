#!/usr/bin/env bash
# コンテナ起動時に GitHub から公開鍵を取得して authorized_keys を組み立て、
# sshd を foreground 実行する。
#
# 取得元: https://github.com/${GITHUB_USER}.keys
#   - GitHub に登録されている公開鍵をそのまま流し込むので、鍵の増減は
#     GitHub 側で完結する（コンテナの再ビルドは不要、再起動だけでよい）。
#   - ネットワーク不達 / 空レスポンス時は既存の authorized_keys を維持し、
#     誤って鍵を消してログインできなくなる事故を避ける。
set -euo pipefail

: "${USERNAME:?USERNAME must be set (build-arg of Dockerfile)}"
: "${GITHUB_USER:?GITHUB_USER must be set (build-arg or -e GITHUB_USER=...)}"

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

exec /usr/sbin/sshd -D -e
