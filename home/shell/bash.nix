# ─────────────────────────────────────────────────────────────
# Bash 設定
#
# 元の dotfiles ではログイン直後に fish へ切り替える方針なので、
# そのフックだけ最小限残しておく。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.bash = {
    enable = true;

    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
    historyFileSize = 20000;

    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };

    # 対話シェルなら fish に乗り換える。SSH や CI のような非対話実行では
    # bash のまま動かす必要があるので $- に i が含まれる場合のみ exec する。
    initExtra = ''
      if [[ $- == *i* ]] && command -v fish >/dev/null 2>&1; then
        exec fish
      fi
    '';
  };
}
