#!/bin/sh
# ─────────────────────────────────────────────────────────────
# Nix セットアップスクリプト
#
# 前提: **sudo (または root) が使えること**。
#   Nix は Determinate Systems の nix-installer で /nix にインストールする
#   multi-user 構成のみを対象とする。sudo が使えない環境 (nix-portable 等) は
#   一切サポートしない。sudo が無い環境ではシステム管理者に Nix の
#   インストールを依頼すること。
#
#   - systemd が動いている環境ではそのままインストールする
#   - systemd が無い環境 (Docker コンテナなど) では
#     `nix-installer install linux --init none` で daemon の自動起動を
#     諦めた状態でインストールし、~/.bashrc に daemon 起動スニペットを入れる
#
# 使い方:
#   ./scripts/setup.sh              # systemd の有無を自動判定
#   ./scripts/setup.sh --init-none  # 強制的に `linux --init none` プラン
#                                   #   (systemd 判定を上書きしたいとき)
# ─────────────────────────────────────────────────────────────
set -eu

FORCE_INIT_NONE=0
for arg in "$@"; do
    case "$arg" in
        --init-none) FORCE_INIT_NONE=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            printf 'unknown option: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
err() { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; }

# ─── sudo が実用的に使えるか判定 ─────────────────────────────
# sudo コマンドの有無だけでなく、実行権限があるかも確認する。
# パスワード入力なしで通る (-n) ことが必須ではないが、
# 少なくとも sudoers に登録されている必要がある。
have_sudo() {
    # root で実行されている場合は sudo 不要
    [ "$(id -u)" = "0" ] && return 0
    command -v sudo >/dev/null 2>&1 || return 1
    # passwordless sudo が通るならそれで OK
    sudo -n true 2>/dev/null && return 0
    # tty があり対話的に sudo できそうならそれで OK とする
    if [ -t 0 ] && [ -t 1 ]; then
        # sudo -v はタイムスタンプを更新するだけで副作用が少ない
        sudo -v 2>/dev/null && return 0
    fi
    return 1
}

# ─── systemd が PID 1 で動いているか判定 ─────────────────────
# nix-installer は init system に登録するために systemd を要求する。
# Docker コンテナや WSL1 などでは systemd が無いので、その場合は
# `linux --init none` プランで入れる必要がある。
#
# 検出方法は systemd 自身が推奨している
# /run/systemd/system ディレクトリの存在チェック。
# 参考: https://www.freedesktop.org/software/systemd/man/sd_booted.html
have_systemd() {
    [ -d /run/systemd/system ]
}

# ─── ~/.bashrc に Nix 関連の起動スニペットを追記 ──────────────
# 同じ目印 (grep キー) を含む行が既にあれば二重に書かない。
#
# 引数:
#   $1 = "with-daemon-autostart" or "no-daemon-autostart"
#        前者なら nix-daemon の pgrep 自動起動ブロックも追記する
write_bashrc_nix_snippets() {
    autostart="${1:-no-daemon-autostart}"
    rcfile="$HOME/.bashrc"
    : >>"$rcfile"   # ファイルが無ければ作る (touch 相当)

    # nix-daemon.sh の source 行
    # Determinate installer はシステム側 rc (/etc/bash.bashrc 等) を書き換えるが、
    # それが拾われない環境 (sandbox / 一部のコンテナ) でも確実に PATH と
    # NIX_* 環境変数が立つよう、ユーザの ~/.bashrc にも明示的に入れておく。
    if ! grep -qsF 'dotfiles-nix:nix-daemon-source' "$rcfile"; then
        cat >>"$rcfile" <<'EOM'

# dotfiles-nix:nix-daemon-source — Nix 環境を読み込む
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOM
        ok "${rcfile} に nix-daemon.sh の source 行を追記しました"
    fi

    # nix-daemon の自動起動ブロック (systemd が無い環境のみ)
    if [ "$autostart" = "with-daemon-autostart" ] && \
       ! grep -qsF 'dotfiles-nix:nix-daemon-autostart' "$rcfile"; then
        cat >>"$rcfile" <<'EOM'

# dotfiles-nix:nix-daemon-autostart — systemd の無い環境用に nix-daemon を起動
if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
fi
EOM
        ok "${rcfile} に nix-daemon の自動起動スニペットを追記しました"
    fi
}

# ─── Nix をインストール (Determinate Systems installer) ───────
# 引数:
#   $1 = "with-systemd" or "no-systemd"
install_nix() {
    init_mode="${1:-with-systemd}"

    if command -v nix >/dev/null 2>&1; then
        ok "nix は既にインストール済み: $(command -v nix)"
        return 0
    fi

    if [ "$init_mode" = "no-systemd" ]; then
        log "systemd が見つかりません → \`linux --init none\` でインストールします"
        log "Determinate Systems nix-installer で Nix をインストールします"
        curl --proto '=https' --tlsv1.2 -sSf -L \
            https://install.determinate.systems/nix \
            | sh -s -- install linux --init none --no-confirm
    else
        log "Determinate Systems nix-installer で Nix をインストールします"
        curl --proto '=https' --tlsv1.2 -sSf -L \
            https://install.determinate.systems/nix \
            | sh -s -- install --no-confirm
    fi
    ok "Nix のインストールが完了しました"

    # ~/.bashrc に source 行を (no-systemd ならそれに加えて daemon 自動起動も) 追記
    if [ "$init_mode" = "no-systemd" ]; then
        write_bashrc_nix_snippets with-daemon-autostart
    else
        write_bashrc_nix_snippets no-daemon-autostart
    fi

    cat <<'EOM'

~/.bashrc に Nix 環境の読み込みを追記したので、
新しいシェルを開けばそのまま nix コマンドが使えます:

  exec bash         # 現在のシェルを置き換える
  # あるいは別ターミナルを開く

今のシェルにすぐ反映したい場合は手動で source してください:

  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
EOM

    if [ "$init_mode" = "no-systemd" ]; then
        cat <<'EOM'

systemd の無い環境では nix-daemon が自動起動しないので、
~/.bashrc に「未起動なら sudo で起動する」スニペットも追記済みです。
新しいシェルを開けば自動的にバックグラウンドで起動します。

今のシェルですぐ daemon を起動したい場合:

  sudo /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &
EOM
    fi

    cat <<'EOM'

その後、Home Manager を適用できます (初回は必ず -b backup を付ける):

  nix run home-manager/master -- switch -b backup --flake .#zenimoto@ubuntu
EOM
}

# ─── 実行 ────────────────────────────────────────────────────
if ! have_sudo; then
    err "sudo (または root) が使えないため Nix をインストールできません"
    err "このリポジトリは sudo の無い環境 (nix-portable など) をサポートしません"
    err "システム管理者に Nix のインストールを依頼してください:"
    err "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    exit 1
fi

if [ "$FORCE_INIT_NONE" = "1" ]; then
    log "--init-none が指定されました → \`linux --init none\` プランでインストールします"
    install_nix no-systemd
elif have_systemd; then
    log "sudo + systemd を検出しました → 通常の Nix をインストールします"
    install_nix with-systemd
else
    log "sudo は使えるが systemd が無い環境を検出しました (Docker コンテナなど)"
    log "→ \`linux --init none\` プランで Nix をインストールします"
    install_nix no-systemd
fi
