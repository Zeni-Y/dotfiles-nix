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

    # Nix プロファイルの PATH を明示的に通す。
    #
    # Determinate Nix のインストーラは nix.fish を「システム側の fish」の
    # vendor_conf.d (/usr/share/fish/vendor_conf.d/ など) に置く。そのため
    # apt 版の fish なら勝手に PATH が通るが、Nix store の fish で起動した
    # 場合は拾えないことがある。どちらで起動しても同じになるよう、
    # ここで明示的に読み込む/継ぎ足す。
    shellInit = ''
      for f in /nix/var/nix/profiles/default/etc/profile.d/nix.fish /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
          if test -r $f
              source $f
          end
      end

      # 上記が無い環境でも Nix プロファイルの bin を PATH 先頭に置く。
      # 後に処理したものが先頭に来るので、ユーザプロファイルを最後に回す。
      for d in /nix/var/nix/profiles/default/bin $HOME/.nix-profile/bin
          if test -d $d
              fish_add_path --global --move --prepend $d
          end
      end
    '';

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
