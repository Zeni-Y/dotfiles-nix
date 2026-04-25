# ─────────────────────────────────────────────────────────────
# Fish シェル設定
#
# 元の dotfiles で使われている fisher プラグインを Nix 側で再現する。
# Nix で管理するため fisher 自体は不要 (プラグインは store にある src を読む)。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    plugins = [
      { name = "autopair";  src = pkgs.fishPlugins.autopair.src; }
      { name = "sponge";    src = pkgs.fishPlugins.sponge.src; }
      { name = "fzf-fish";  src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "pure";      src = pkgs.fishPlugins.pure.src; }
    ];

    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      la = "eza -a --icons";
      lt = "eza --tree --icons --level=2";
      cat = "bat";
      grep = "rg";
    };

    interactiveShellInit = ''
      # 環境変数
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx LANG en_US.UTF-8

      # ghq でクローンしたリポジトリ用
      set -gx GHQ_ROOT $HOME/ghq

      # fzf のキーバインドを fish 用に
      set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"
    '';
  };
}
