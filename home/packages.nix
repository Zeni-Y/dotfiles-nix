# ─────────────────────────────────────────────────────────────
# 共通でインストールする CLI ツール
#
# シェル統合や設定が必要なものは home/cli/*.nix で programs.* として
# 個別管理する。ここには「入れるだけで使える」ツールだけを置く。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ファイル/テキスト検索
    ripgrep
    fd

    # データ処理
    jq
    yq-go

    # システムモニター
    htop
    btop

    # ネットワーク
    curl
    wget

    # 圧縮・転送
    unzip
    rsync

    # Git 関連
    lazygit
    ghq

    # Git 以外の VCS / インフラ
    gnumake

    # シェルスクリプト品質
    shellcheck
    shfmt

    # テスト
    bats

    # 言語サーバー (エディタから利用)
    bash-language-server
    pyright

    # Python 環境管理 (Python 本体は `uv python install` で導入)
    uv

    # その他便利系
    yazi      # TUI ファイラー
    tldr      # 簡潔な man の代替
  ];
}
