# ─────────────────────────────────────────────────────────
# dotfiles-nix テスト環境 (Ubuntu 24.04 + Determinate Systems nix-installer)
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

# ── Nix をインストール (Determinate Systems nix-installer) ──
# root として実行: multi-user インストールのため /nix の作成に root 権限が必要。
# --init none: systemd 等 init system への登録をスキップ (Docker に向いた方式)
# --no-confirm: 非インタラクティブ環境での確認プロンプトをスキップ
# nix-command・flakes は Determinate installer がデフォルトで /etc/nix/nix.conf に追加する。
RUN curl -fsSL https://install.determinate.systems/nix | \
    sh -s -- install linux --init none --no-confirm

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ── dotfiles をコンテナにコピー ───────────────────────────
# ビルドコンテキスト (リポジトリルート) の全ファイルをコピー。
# .dockerignore で .git や result などは除外済み。
COPY --chown=${USERNAME}:${USERNAME} . /home/${USERNAME}/dotfiles-nix/

WORKDIR /home/${USERNAME}/dotfiles-nix

# ── Windows CRLF を除去 ──────────────────────────────────
# Windows 環境では git が .nix/.sh を CRLF でチェックアウトする場合がある。
# .nix に CR が残ると home-manager が生成する bash スクリプトに
# `fi\r` が入り、bash の構文チェックが失敗する。
RUN find . \( -name "*.nix" -o -name "*.sh" \) -print0 \
    | xargs -0 sed -i 's/\r$//'

# ── デフォルト: テストスクリプトを実行 ───────────────────
# インタラクティブシェルに切り替える場合:
#   docker run --rm -it dotfiles-nix-test bash
CMD ["/bin/bash", "/home/zenimoto/dotfiles-nix/docker/test.sh"]
