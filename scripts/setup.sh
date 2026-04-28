#!/bin/sh
# ─────────────────────────────────────────────────────────────
# Nix セットアップスクリプト
#
#   - sudo が使える環境では Determinate Systems の nix-installer で
#     通常の (multi-user) Nix をインストールする
#   - sudo が使えない環境では nix-portable をダウンロードして
#     ~/.local/bin/nix-portable に配置する
#
# 使い方:
#   ./scripts/setup.sh              # 自動判定 (sudo があれば普通の Nix)
#   ./scripts/setup.sh --portable   # 強制的に nix-portable
#   ./scripts/setup.sh --system     # 強制的に通常の Nix (sudo 必須)
# ─────────────────────────────────────────────────────────────
set -eu

MODE="auto"
for arg in "$@"; do
    case "$arg" in
        --portable) MODE="portable" ;;
        --system)   MODE="system" ;;
        --auto)     MODE="auto" ;;
        -h|--help)
            sed -n '2,15p' "$0"
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
    command -v sudo >/dev/null 2>&1 || return 1
    # root で実行されている場合は sudo 不要
    [ "$(id -u)" = "0" ] && return 0
    # passwordless sudo が通るならそれで OK
    sudo -n true 2>/dev/null && return 0
    # tty があり対話的に sudo できそうならそれで OK とする
    if [ -t 0 ] && [ -t 1 ]; then
        # sudo -v はタイムスタンプを更新するだけで副作用が少ない
        sudo -v 2>/dev/null && return 0
    fi
    return 1
}

# ─── 通常の Nix をインストール (Determinate Systems installer) ─
install_system_nix() {
    if command -v nix >/dev/null 2>&1; then
        ok "nix は既にインストール済み: $(command -v nix)"
        return 0
    fi
    log "Determinate Systems nix-installer で Nix をインストールします"
    curl --proto '=https' --tlsv1.2 -sSf -L \
        https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
    ok "Nix のインストールが完了しました"
    cat <<'EOM'

新しいシェルを開くか、以下を実行して PATH を読み込んでください:

  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

その後、Home Manager を適用できます:

  nix run home-manager/master -- switch --flake .#zenimoto@ubuntu
EOM
}

# ─── nix-portable をダウンロード ─────────────────────────────
# 参考: https://github.com/DavHau/nix-portable
install_nix_portable() {
    # ~/.local/bin を PATH の先頭に追加する。
    # 現在のプロセスにも反映しつつ、対話シェルが次回起動時にも読むよう
    # 適切な rc ファイルへ追記する。
    #
    # rc ファイル選択:
    #   bash → .bashrc (非ログイン対話シェル) と .profile (ログインシェル)
    #   zsh  → .zshrc
    # .profile だけだと Docker の `bash` などでは読まれないので注意。
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    case "${SHELL:-}" in
        *zsh) rcfiles="$HOME/.zshrc" ;;
        *)    rcfiles="$HOME/.bashrc $HOME/.profile" ;;
    esac

    for rcfile in $rcfiles; do
        # 既に書かれている場合は重複させない
        if [ ! -f "$rcfile" ] || ! grep -qs '\.local/bin' "$rcfile"; then
            printf '\n# Added by dotfiles-nix setup.sh\nexport PATH="$HOME/.local/bin:$PATH"\n' \
                >>"$rcfile"
            ok "${rcfile} に PATH を追記しました"
        fi
    done

    target="$HOME/.local/bin/nix-portable"
    mkdir -p "$HOME/.local/bin"

    if [ -x "$target" ]; then
        ok "nix-portable は既に配置済み: $target"
    else
        log "nix-portable をダウンロードします"
        arch="$(uname -m)"
        url="https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-${arch}"
        curl -L "$url" -o "$target"
        chmod +x "$target"
        ok "nix-portable をダウンロードしました: $target"
    fi

    cat <<'EOM'

nix-portable は単体バイナリで、/nix への書き込みも sudo も不要です。
普段使う nix コマンドは "nix-portable nix ..." の形で実行してください。

例:

  # flake のメタデータを表示
  nix-portable nix flake metadata

  # Home Manager を適用 (Ubuntu 用)
  nix-portable nix run home-manager/master -- \
    switch --flake .#zenimoto@ubuntu

エイリアスを張っておくと普段使いが楽になります:

  alias nix='nix-portable nix'
EOM
}

# ─── ディスパッチ ────────────────────────────────────────────
case "$MODE" in
    system)
        if ! have_sudo; then
            err "sudo が使えないため --system モードでインストールできません"
            err "--portable を指定するか、引数なしで実行してください"
            exit 1
        fi
        install_system_nix
        ;;
    portable)
        install_nix_portable
        ;;
    auto)
        if have_sudo; then
            log "sudo が使える環境を検出しました → 通常の Nix をインストールします"
            install_system_nix
        else
            log "sudo が使えない環境を検出しました → nix-portable を使用します"
            install_nix_portable
        fi
        ;;
esac
