# ─────────────────────────────────────────────────────────
# dotfiles-nix テスト環境 (素の Ubuntu 24.04)
#
# Nix はあえてインストールしない。コンテナ内で `scripts/setup.sh`
# などを実際に走らせて挙動を確認するためのまっさらな箱として使う。
#
# 推奨の起動方法は `docker/run.sh`。リポジトリをマウントし、
# ホストの GITHUB_TOKEN を渡した状態で対話シェルに入れる。
# ─────────────────────────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

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

# flake.nix の userInfo.username と一致させる必要がある
ARG USERNAME=zenimoto
RUN useradd -m -s /bin/bash "${USERNAME}" && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Docker の `USER` 命令は実行 UID を切り替えるだけで環境変数 $USER までは
# 設定しない。非ログインの bash では $USER が空のままになり、
# Home Manager が `set -u` で unbound variable エラーを出すので明示する。
ENV USER=${USERNAME} \
    HOME=/home/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}/dotfiles-nix

CMD ["/bin/bash"]
