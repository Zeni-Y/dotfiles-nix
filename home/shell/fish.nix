# ─────────────────────────────────────────────────────────────
# Fish シェル設定
#
# プラグインは programs.fish.plugins で管理する。
# これにより fisher は不要で、バージョンは flake.lock で固定される。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    # pure はプロンプトテーマを提供するため starship とは併用しない。
    # pkgs.fishPlugins に無いプラグインは fetchFromGitHub で固定できる。
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
