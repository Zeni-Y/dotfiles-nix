# ─────────────────────────────────────────────────────────
# dotfiles-nix テスト環境 (Ubuntu 24.04 + Nix single-user)
#
# ビルドはリポジトリルートから実行する:
#   docker build -f docker/Dockerfile -t dotfiles-nix-test .
# ─────────────────────────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

# ── 必要なシステムパッケージ ──────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      xz-utils \
      git \
      ca-certificates \
      sudo \
      locales && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# ── テスト用ユーザー ──────────────────────────────────────
# flake.nix の userInfo.username と一致させる。
# home-manager は home.username でユーザー名をチェックするため、
# 必ずここと flake.nix の値が合っている必要がある。
ARG USERNAME=zenimoto
RUN useradd -m -s /bin/bash "${USERNAME}" && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ── Nix をシングルユーザーモードでインストール ─────────────
# --no-daemon: nix-daemon を起動しない (Docker に向いた方式)
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
      https://nixos.org/nix/install | sh -s -- --no-daemon

# ── Flakes を有効化 ───────────────────────────────────────
RUN mkdir -p .config/nix && \
    echo 'experimental-features = nix-command flakes' >> .config/nix/nix.conf

# ── dotfiles をコンテナにコピー ───────────────────────────
# ビルドコンテキスト (リポジトリルート) の全ファイルをコピー。
# .dockerignore で .git や result などは除外済み。
COPY --chown=${USERNAME}:${USERNAME} . /home/${USERNAME}/dotfiles-nix/

WORKDIR /home/${USERNAME}/dotfiles-nix

# ── デフォルト: テストスクリプトを実行 ───────────────────
# インタラクティブシェルに切り替える場合:
#   docker run --rm -it dotfiles-nix-test bash
CMD ["/bin/bash", "/home/zenimoto/dotfiles-nix/docker/test.sh"]
