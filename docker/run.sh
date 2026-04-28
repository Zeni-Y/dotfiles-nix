#!/usr/bin/env bash
# dotfiles-nix のテスト用 Ubuntu コンテナを起動する。
#
#   - リポジトリルートを ~/dotfiles-nix にマウントする
#   - ホストの GITHUB_TOKEN をコンテナに渡す
#   - 追加引数はそのままコンテナのコマンドに渡される
#
# 使い方:
#   docker/run.sh                 # 対話シェル (デフォルト)
#   docker/run.sh ./scripts/setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-dotfiles-nix-test}"
USERNAME="${USERNAME:-zenimoto}"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "==> イメージ ${IMAGE} が見つからないのでビルドします"
    docker build -f "${REPO_ROOT}/docker/Dockerfile" -t "${IMAGE}" "${REPO_ROOT}"
fi

exec docker run --rm -it \
    -v "${REPO_ROOT}:/home/${USERNAME}/dotfiles-nix" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    "${IMAGE}" "$@"
