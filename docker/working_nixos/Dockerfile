# ─────────────────────────────────────────────────────────────
# working (NixOS / Nix ベース版) 開発コンテナ
#
# docker/working が ubuntu:24.04 + 「入ってから setup.sh で Nix を入れる」
# なのに対し、こちらは公式 nixos/nix イメージを土台にして
# **Nix と dotfiles (Home Manager) をイメージに焼き込む**。
# コンテナを起動した時点で fish / neovim / claude-code などが揃っている。
#
# nixos/nix は「Nix 入りの最小イメージ」であって NixOS そのものではない。
# systemd は動かないので、sshd は entrypoint.sh から直接起動する
# (docker/working と同じ運用感、--privileged も不要)。
#
# ビルドコンテキストは **リポジトリルート**。Makefile が `-f` 付きで
# `../..` を渡すので、`make build` を使う限り意識しなくてよい。
# ─────────────────────────────────────────────────────────────
FROM nixos/nix:2.35.1

# Home Manager の homeConfigurations は /home/<username> を前提にするため、
# flake.nix の userInfo.username と一致させる必要がある。
# Makefile は既定でホストの $USER を渡す (make build USERNAME=... で上書き可)。
ARG USERNAME=zenimoto
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# 起動時に https://github.com/${GITHUB_USER}.keys から authorized_keys を取得する
ARG GITHUB_USER=Zeni-Y
# 適用する homeConfigurations の名前。
# home/ 以下の設定は OS 非依存なので、Ubuntu 用の定義をそのまま使う。
ARG HM_CONFIG=${USERNAME}@ubuntu
# タイムゾーンはビルド時だけ使う。ランタイムに TZ を残さないのは、
# nixpkgs の glibc が既定で /usr/share/zoneinfo を見ないため
# (TZDIR が渡らない場面で TZ が POSIX 形式の文字列と解釈され UTC になる)。
# TZ 未設定なら glibc は /etc/localtime を読むので、そちらに寄せる。
ARG TZ=Asia/Tokyo

ENV LANG=en_US.UTF-8 \
    # ベースイメージが USER=root を持っている。Docker の `USER` 命令や
    # `docker exec -u` は実行 UID を変えるだけで $USER を書き換えないため、
    # そのままだと Home Manager が「USER is "root", expected ...」で止まる。
    # ログインシェルでは /etc/profile が id(1) を見て上書きする。
    USER=${USERNAME} \
    # entrypoint.sh から参照するため、ビルド時の値をランタイム環境変数にも残す
    USERNAME=${USERNAME} \
    GITHUB_USER=${GITHUB_USER} \
    HM_CONFIG=${HM_CONFIG} \
    # ベースイメージの PATH には /usr/bin / /bin が入っていない。
    # setuid 版 sudo を /usr/bin に置くので明示的に足す。
    PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/usr/bin:/bin

# ─── Nix の設定 ──────────────────────────────────────────────
# /etc/nix/nix.conf も /etc/passwd 等も Nix store へのシンボリックリンク
# (= 読み取り専用) なので、書き換える前に実ファイルへ展開する。
RUN set -eu; \
    for f in /etc/nix/nix.conf /etc/passwd /etc/group /etc/shadow; do \
        if [ -L "$f" ]; then cp --remove-destination "$(readlink -f "$f")" "$f"; fi; \
    done; \
    chmod 644 /etc/nix/nix.conf /etc/passwd /etc/group; \
    chmod 600 /etc/shadow; \
    { \
        echo "experimental-features = nix-command flakes"; \
        echo "max-jobs = auto"; \
        echo "trusted-users = root ${USERNAME}"; \
    } >> /etc/nix/nix.conf

# ─── システム側ツールの導入 ──────────────────────────────────
# nixos/nix には useradd / sudo / ロケール等が入っていないので足す。
#
# バージョンはリポジトリの flake.lock に固定した nixpkgs から引く
# (`--inputs-from`)。ここで flake.nix / flake.lock だけ先に COPY するのは、
# リポジトリの他のファイルを触ってもこのレイヤのキャッシュを壊さないため。
#
# `--priority` は同じファイルを提供するパッケージ同士の優先順位
# (小さいほど強い / 既定は 5)。ベースイメージの coreutils などと
# `kill` や `su` が衝突するので、明示的に順位を付けて解決する。
COPY flake.nix flake.lock /etc/nix-inputs/
#
# `pkg^out` は出力の明示。tzdata の既定 (outputsToInstall) は bin/man だけで、
# 肝心の zoneinfo が入っている out が入らないので指定する。
RUN set -eu; \
    nix profile install --inputs-from /etc/nix-inputs --priority 4 \
        nixpkgs#shadow \
        nixpkgs#procps \
        nixpkgs#gnused \
        nixpkgs#gawk \
        'nixpkgs#tzdata^out,bin' \
        nixpkgs#glibcLocalesUtf8; \
    nix profile install --inputs-from /etc/nix-inputs --priority 6 \
        nixpkgs#util-linux \
        'nixpkgs#glibc^bin'; \
    nix store gc --quiet 2>/dev/null || true

# ロケールとタイムゾーン。NixOS 以外の環境では glibc がロケールアーカイブを
# 見つけられないので LOCALE_ARCHIVE で明示する。
ENV LOCALE_ARCHIVE=/nix/var/nix/profiles/default/lib/locale/locale-archive \
    TZDIR=/nix/var/nix/profiles/default/share/zoneinfo
#
# glibc が既定で見るのは /usr/share/zoneinfo なので、そこからも張っておく。
# これが無いと TZDIR が渡らない環境 (sshd 経由のセッション等) で
# TZ=Asia/Tokyo が POSIX 形式の文字列として解釈され、UTC のままになる。
# ベースイメージの /usr/share は /nix/var/nix/profiles/share へのリンクだが、
# その参照先は存在しない (壊れたリンク)。default プロファイルに張り直す。
RUN ln -snf /nix/var/nix/profiles/default/share /usr/share && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# ─── ユーザー作成 ────────────────────────────────────────────
# ログインシェルは Nix store の bash。プロファイル経由の安定パスを使う
# (store のハッシュ付きパスを /etc/passwd に焼くと更新で壊れるため)。
RUN set -eu; \
    groupadd --gid "${USER_GID}" "${USERNAME}"; \
    useradd --no-log-init --uid "${USER_UID}" --gid "${USER_GID}" -m \
            -s /nix/var/nix/profiles/default/bin/bash "${USERNAME}"; \
    echo "/nix/var/nix/profiles/default/bin/bash" > /etc/shells; \
    # sshd は特権分離用のユーザーと /var/empty を要求する
    groupadd -r sshd; \
    useradd -r -g sshd -d /var/empty \
            -s /nix/var/nix/profiles/default/bin/nologin sshd; \
    mkdir -p /var/empty /var/run /run

# sudo は setuid が要るので、Nix store のバイナリをコピーして立てる。
# store 側は GC root を張って closure (共有ライブラリ) を保護しておく。
# プロファイルには入れない ── PATH 上で setuid でない方を掴むのを避けるため。
RUN set -eu; \
    nix build --inputs-from /etc/nix-inputs \
        --out-link /nix/var/nix/gcroots/sudo 'nixpkgs#sudo^out'; \
    install -m 4755 -o root -g root \
        /nix/var/nix/gcroots/sudo/bin/sudo /usr/bin/sudo; \
    mkdir -p /etc/pam.d; \
    nix build --inputs-from /etc/nix-inputs \
        --out-link /nix/var/nix/gcroots/linux-pam 'nixpkgs#linux-pam^out'; \
    PAM=$(readlink -f /nix/var/nix/gcroots/linux-pam); \
    # nixpkgs の sudo / sshd は PAM 付きでビルドされている。NixOS なら
    # security.pam が /etc/pam.d を生成するが、ここには無いので最小構成を置く。
    # sudoers 側で NOPASSWD にしている開発用コンテナなので pam_permit で通す。
    #
    # sshd 側で PAM が要るのは「アカウントがロックされている」判定を
    # 避けるため。`useradd` はパスワード欄に `!` を入れる (= ロック扱い) ので、
    # UsePAM no のままだと公開鍵認証まで蹴られる。
    for t in auth account password session; do \
        echo "$t sufficient ${PAM}/lib/security/pam_permit.so"; \
    done | tee /etc/pam.d/sudo > /etc/pam.d/sshd; \
    printf 'root ALL=(ALL) ALL\n%s ALL=(ALL) NOPASSWD:ALL\n' "${USERNAME}" > /etc/sudoers; \
    chmod 440 /etc/sudoers

# ─── ログインシェル用のプロファイル ──────────────────────────
# SSH ログイン (login shell) で Nix の PATH / 証明書 / NIX_PROFILES が
# 立つようにする。nix-daemon.sh はストアが書けないユーザーを自動で
# daemon 経由にするので、NIX_REMOTE を手で設定する必要はない。
RUN printf '%s\n' \
        '# dotfiles-nix: nixos/nix ベースイメージ用の system-wide profile' \
        'export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/usr/bin:/bin"' \
        '# イメージの ENV に焼いた USER を、実際に実行しているユーザーで上書きする' \
        'USER="$(id -un)"; export USER' \
        'if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then' \
        '    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
        'fi' \
        'export LOCALE_ARCHIVE=/nix/var/nix/profiles/default/lib/locale/locale-archive' \
        'export TZDIR=/nix/var/nix/profiles/default/share/zoneinfo' \
        > /etc/profile

# ─── sshd 設定 ───────────────────────────────────────────────
# 公開鍵認証のみ / agent forwarding 有効。
# ホスト鍵はイメージに焼かず、entrypoint.sh がコンテナごとに生成する。
#
# `SetEnv PATH=...` は `ssh <host> <command>` (非対話) 用。この形では
# /etc/profile も ~/.bashrc も読まれず、sshd 既定の PATH には
# Nix のプロファイルが入っていないので、ほぼ全部のコマンドが見つからなくなる。
RUN mkdir -p /etc/ssh && printf '%s\n' \
        'Port 22' \
        'HostKey /etc/ssh/ssh_host_ed25519_key' \
        'HostKey /etc/ssh/ssh_host_rsa_key' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        'KbdInteractiveAuthentication no' \
        'UsePAM yes' \
        'AllowAgentForwarding yes' \
        'X11Forwarding no' \
        'PrintMotd no' \
        'AcceptEnv LANG LC_*' \
        "SetEnv PATH=/home/${USERNAME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin LANG=${LANG} TZDIR=${TZDIR}" \
        'Subsystem sftp /nix/var/nix/profiles/default/libexec/sftp-server' \
        > /etc/ssh/sshd_config

# ─── dotfiles (Home Manager) の適用 ──────────────────────────
# リポジトリをイメージに取り込み、ビルド時に activation まで済ませる。
# `nix build` / activation はユーザー権限で走らせる必要がある一方、
# store はユーザーから書けないので、この RUN の中だけ nix-daemon を上げる。
COPY --chown=${USER_UID}:${USER_GID} . /home/${USERNAME}/dotfiles-nix
RUN set -eu; \
    nix-daemon --daemon & \
    for _ in $(seq 1 100); do \
        [ -S /nix/var/nix/daemon-socket/socket ] && break; \
        sleep 0.2; \
    done; \
    setpriv --reuid="${USER_UID}" --regid="${USER_GID}" --init-groups \
        env HOME="/home/${USERNAME}" USER="${USERNAME}" \
            PATH=/nix/var/nix/profiles/default/bin:/usr/bin:/bin \
            HOME_MANAGER_BACKUP_EXT=backup \
        bash -eu -c ' \
            out=$(nix build --no-link --print-out-paths \
                "/home/'"${USERNAME}"'/dotfiles-nix#homeConfigurations.\"'"${HM_CONFIG}"'\".activationPackage"); \
            "$out"/activate \
        '; \
    nix store gc --quiet 2>/dev/null || true

# ─── 起動 ────────────────────────────────────────────────────
# nix-daemon を上げ、GitHub から authorized_keys を取り、sshd を foreground 実行する。
# root 権限が必須。SSH ログイン後は鍵に対応するユーザーに切り替わる。
# `docker exec` で入る場合は `-u $USERNAME` を指定する。
COPY docker/working_nixos/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/${USERNAME}
USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
