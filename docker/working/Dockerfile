# ─────────────────────────────────────────────────────────────
# working (Ubuntu ベース) 開発コンテナ
#
# ubuntu:24.04 を土台にしつつ、**Nix と dotfiles (Home Manager) を
# イメージに焼き込む**。コンテナを起動した時点で fish / neovim /
# claude-code などが揃っているので、コンテナを作り直しても
# `scripts/setup.sh` と `home-manager switch` をやり直す必要がない。
#
# apt で入れるのは以下だけに絞り、開発用ツールはすべて Nix
# (home/packages.nix ほか) で管理する:
#   - Nix をインストールする前に必要なもの (ca-certificates, curl)
#   - setuid が要るもの (sudo)
#   - root のシステムサービスとして動くもの (openssh-server)
#   - glibc のロケール生成 (locales)
#
# ビルドコンテキストは **リポジトリルート**。Makefile が `-f` 付きで
# `../..` を渡すので、`make build` を使う限り意識しなくてよい。
# ─────────────────────────────────────────────────────────────
FROM ubuntu:24.04

# Home Manager の homeConfigurations は /home/<username> を前提にするため、
# flake.nix の userInfo.username と一致させる必要がある。
# Makefile は既定でホストの $USER を渡す (make build USERNAME=... で上書き可)。
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# 起動時に https://github.com/${GITHUB_USER}.keys から authorized_keys を取得する
ARG GITHUB_USER=Zeni-Y
# 適用する homeConfigurations の名前
ARG HM_CONFIG=${USERNAME}@ubuntu
# 0 にすると dotfiles の焼き込み (Home Manager の適用) をスキップする。
# Dockerfile 自体をいじっているときなど、ビルドを数分で回したいとき用。
ARG BAKE_DOTFILES=1

ENV TZ=Asia/Tokyo
ENV DEBIAN_FRONTEND=noninteractive
# entrypoint.sh から参照するため、ビルド時の値をランタイム環境変数にも残す
ENV USERNAME=${USERNAME}
ENV GITHUB_USER=${GITHUB_USER}
ENV HM_CONFIG=${HM_CONFIG}
# Nix を PATH に載せる。ユーザーのプロファイル (~/.nix-profile/bin) は
# Home Manager が ~/.bashrc 経由で前に足すので、ここではシステム側だけ。
ENV PATH=/nix/var/nix/profiles/default/bin:${PATH}

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ─── apt: Nix より前に必要なものだけ ─────────────────────────
# 開発ツール (git / wget / コンパイラ等) はここには入れない。Nix 側で管理する。
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl sudo locales openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen ja_JP.UTF-8 && \
    # SSH サーバー設定（公開鍵認証のみ、agent forwarding 有効）
    mkdir -p /var/run/sshd && \
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?AllowAgentForwarding\s+.*/AllowAgentForwarding yes/' /etc/ssh/sshd_config && \
    # `ssh <host> <command>` (非対話) では /etc/profile も ~/.bashrc も読まれず、
    # sshd 既定の PATH には Nix のプロファイルが入っていない。明示的に足しておく。
    printf 'SetEnv PATH=/home/%s/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin\n' \
        "${USERNAME}" >> /etc/ssh/sshd_config

# ユーザー作成
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -G sudo -s /bin/bash && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ─── Nix のインストール ──────────────────────────────────────
# Determinate Systems の nix-installer を使う (scripts/setup.sh と同じ)。
# コンテナには systemd が無いので `linux --init none` プラン固定。
# daemon の面倒は entrypoint.sh が見る。
#
# `sandbox = false` について:
#   Nix のビルドサンドボックスは user namespace を要求するが、docker build 中は
#   seccomp やネストの都合で使えないことがある。公式の nixos/nix イメージも
#   同じ理由でサンドボックスを切っている。ホスト側が user namespace を許す
#   環境なら、この行は消してよい。
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install linux --init none --no-confirm && \
    { \
        echo "experimental-features = nix-command flakes"; \
        echo "max-jobs = auto"; \
        echo "trusted-users = root ${USERNAME}"; \
        echo "sandbox = false"; \
    } >> /etc/nix/nix.conf

# ログインシェル (SSH ログイン含む) で Nix の PATH / NIX_* が立つようにする。
# インストーラもシステム側 rc を書き換えるが、拾われない環境でも確実に効くよう
# /etc/profile.d にも置いておく (scripts/setup.sh が ~/.bashrc に入れるのと同趣旨)。
RUN printf '%s\n' \
        '# dotfiles-nix: Nix 環境を読み込む' \
        'if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then' \
        '    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
        'fi' \
        > /etc/profile.d/nix-dotfiles.sh

# ─── flake の入力を先に取得 ──────────────────────────────────
# flake.nix / flake.lock だけ先に COPY して inputs を store に落としておく。
# こうしておくと home/ 以下を触ったときに nixpkgs の再取得が起きない。
#
# ここは純粋な高速化なので、失敗してもビルドは止めない
# (後段の `nix build` が改めて取得するだけで結果は変わらない)。
COPY flake.nix flake.lock /etc/nix-inputs/
RUN nix flake archive /etc/nix-inputs >/dev/null \
    || echo "WARN: flake inputs の事前取得に失敗しました。ビルドは続行します" >&2

# ─── dotfiles (Home Manager) の焼き込み ──────────────────────
# リポジトリをイメージに取り込み、ビルド時に activation まで済ませる。
COPY --chown=${USER_UID}:${USER_GID} . /home/${USERNAME}/dotfiles-nix
COPY docker/working/bake-dotfiles.sh /usr/local/bin/bake-dotfiles.sh
RUN chmod +x /usr/local/bin/bake-dotfiles.sh && \
    if [ "${BAKE_DOTFILES}" = "1" ]; then \
        /usr/local/bin/bake-dotfiles.sh; \
    else \
        echo "==> BAKE_DOTFILES=${BAKE_DOTFILES}: dotfiles の焼き込みをスキップしました"; \
    fi

WORKDIR /home/$USERNAME

# 起動時に nix-daemon を上げ、GitHub から authorized_keys を取得して sshd を立ち上げる
COPY docker/working/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# sshd を PID 1 として foreground 実行（root 権限が必須）
# SSH ログイン後は鍵に対応するユーザーに切り替わる
# `docker exec` で入る場合は `-u $USERNAME` を指定する
USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
