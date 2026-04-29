FROM ubuntu:24.04

ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# 起動時に https://github.com/${GITHUB_USER}.keys から authorized_keys を取得する
ARG GITHUB_USER=Zeni-Y

ENV TZ=Asia/Tokyo
ENV DEBIAN_FRONTEND=noninteractive
# entrypoint.sh から参照するため、ビルド時の値をランタイム環境変数にも残す
ENV USERNAME=${USERNAME}
ENV GITHUB_USER=${GITHUB_USER}

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl git sudo locales ca-certificates openssh-server software-properties-common \
    gnupg \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget llvm \
    libncurses5-dev xz-utils tk-dev libxml2-dev \
    libxmlsec1-dev libffi-dev liblzma-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen ja_JP.UTF-8 && \
    # SSH サーバー設定（公開鍵認証のみ、agent forwarding 有効）
    mkdir -p /var/run/sshd && \
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?AllowAgentForwarding\s+.*/AllowAgentForwarding yes/' /etc/ssh/sshd_config

# ユーザー作成
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -G sudo -s /bin/bash && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

WORKDIR /home/$USERNAME

# 起動時に GitHub から authorized_keys を取得して sshd を立ち上げる
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# sshd を PID 1 として foreground 実行（root 権限が必須）
# SSH ログイン後は鍵に対応するユーザーに切り替わる
# `docker exec` で入る場合は `-u $USERNAME` を指定する
USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
