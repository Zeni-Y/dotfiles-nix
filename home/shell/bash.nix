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
    #
    # `fish` を PATH 引き (command -v fish) すると、apt で入った
    # /usr/bin/fish を掴んでしまうことがある。それでは flake.lock で
    # 固定したバージョンではなくなるので、Home Manager が管理する
    # Nix store の fish を絶対パスで指定する。
    initExtra = ''
      if [[ $- == *i* ]] && [[ -x ${pkgs.fish}/bin/fish ]]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };
}
