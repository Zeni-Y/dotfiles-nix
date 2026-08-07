#!/usr/bin/env bash
# NixOS(nixos/nix) 版 working コンテナの起動処理。
#
#   1. nix-daemon を起動する
#      systemd が無いので誰も面倒を見てくれない。これが居ないと
#      一般ユーザーは store に書けず `home-manager switch` も失敗する。
#   2. sshd のホスト鍵をコンテナ内で生成する
#      イメージに焼くと同じイメージから作った全コンテナで秘密鍵が共有される。
#   3. GitHub から公開鍵を取得して authorized_keys を組み立てる
#      取得元: https://github.com/${GITHUB_USER}.keys
#      鍵の増減は GitHub 側で完結する (再ビルド不要、`make restart` だけでよい)。
#      ネットワーク不達 / 空レスポンス時は既存の authorized_keys を維持し、
#      誤って鍵を消してログインできなくなる事故を避ける。
#   4. sshd を foreground 実行する
set -euo pipefail

: "${USERNAME:?USERNAME must be set (build-arg of Dockerfile)}"
: "${GITHUB_USER:?GITHUB_USER must be set (build-arg or -e GITHUB_USER=...)}"

PROFILE=/nix/var/nix/profiles/default

# ─── 1. nix-daemon ───────────────────────────────────────────
if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
    "${PROFILE}/bin/nix-daemon" --daemon &
    for _ in $(seq 1 100); do
        [ -S /nix/var/nix/daemon-socket/socket ] && break
        sleep 0.2
    done
fi
if [ -S /nix/var/nix/daemon-socket/socket ]; then
    echo "==> nix-daemon is up"
else
    echo "WARN: nix-daemon socket did not appear; nix may not work for non-root users" >&2
fi

# ─── 2. ホスト鍵 ─────────────────────────────────────────────
mkdir -p /etc/ssh
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    "${PROFILE}/bin/ssh-keygen" -A
    echo "==> generated sshd host keys"
fi

# ─── 3. authorized_keys ──────────────────────────────────────
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

# ─── 4. sshd ─────────────────────────────────────────────────
exec "${PROFILE}/bin/sshd" -D -e
