# ─────────────────────────────────────────────────────────────
# Fish シェル設定
#
# プラグインは programs.fish.plugins で管理する。
# これにより fisher は不要で、バージョンは flake.lock で固定される。
# ─────────────────────────────────────────────────────────────
{ config, pkgs, ... }:

let
  # flake の場所と homeConfigurations のキー。
  # 後者は flake.nix の `homeConfigurations."${userInfo.username}@ubuntu"`
  # と一致させる必要がある。username は userInfo から流れてくるので
  # config 経由で拾い、ホスト側の "ubuntu" だけ直書きする。
  #
  # パスは ghq の標準レイアウト (<root>/<host>/<owner>/<repo>)。
  # worktree を同じ root に集約するため (docs/git/git-worktree.md 7 章)、
  # ここは host/owner を含んだ形でなければならない。
  # GitHub の owner は userInfo.username と綴りが違うので home.username からは
  # 導けない。flake.nix の userInfo.githubUser が git config (ghq.user) に
  # 流れてくるので、そこから拾って直書きをなくしている。
  flakeDir = "${config.home.homeDirectory}/ghq/github.com/${config.programs.git.settings.ghq.user}/dotfiles-nix";
  flakeRef = "${flakeDir}#${config.home.username}@ubuntu";
in
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

      # ─────────────────────────────────────────────────────
      # 接続直後の 1 枚目のシェルでも同梱補完を効かせる
      #
      # ログインシェルが fish (/etc/passwd) なので、bash 経由なら通る
      # /etc/profile → nix-daemon.sh を誰も読まない。fish は起動の時点の
      # XDG_DATA_DIRS / NIX_PROFILES から fish_complete_path を組み立てるため、
      # 1 枚目だけ ~/.nix-profile/share/fish/vendor_completions.d が抜け、
      # `herdr session <Tab>` などの同梱補完がファイル名補完に落ちる。
      # すぐ上で source した nix.fish が XDG_DATA_DIRS を export するのは
      # それより後なので間に合わず、しかし export された値は子に継承される。
      # これが「シェルを開き直すと補完が効くようになる」の正体。
      #
      # fish_complete_path は起動後に XDG_DATA_DIRS を足しても組み直されないので、
      # ここで fish の起動時と同じ規則で不足分を埋める。
      # ─────────────────────────────────────────────────────
      if status is-interactive; and set -q XDG_DATA_DIRS
          for d in (string split : -- $XDG_DATA_DIRS)
              set -l base (string replace -r '/+$' "" -- $d)/fish

              if test -d $base/vendor_completions.d; and not contains -- $base/vendor_completions.d $fish_complete_path
                  # man ページから機械生成した補完 (generated_completions) より
                  # 前に置く。あちらはサブコマンドを知らないので、先に当たると
                  # 同梱補完まで届かなくなる
                  set -l merged
                  set -l inserted 0
                  for p in $fish_complete_path
                      if test $inserted -eq 0; and string match -q '*generated_completions*' -- $p
                          set -a merged $base/vendor_completions.d
                          set inserted 1
                      end
                      set -a merged $p
                  end
                  test $inserted -eq 0; and set -a merged $base/vendor_completions.d
                  set -g fish_complete_path $merged
              end

              if test -d $base/vendor_functions.d; and not contains -- $base/vendor_functions.d $fish_function_path
                  set -ga fish_function_path $base/vendor_functions.d
              end
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

    # ─────────────────────────────────────────────────────────
    # dotfiles 管理まわりの短縮入力
    #
    # flake 構成では `--flake` を省略すると
    # `~/.config/home-manager/home.nix` を探しに行って落ちるので、
    # home-manager 系はどのサブコマンドでも毎回 --flake が要る。
    # 手で打つには長すぎるうえ、間違えても分かりにくいので abbr にする。
    #
    # abbr は展開後に編集できるので、`-b backup` を足したい初回だけ
    # 展開してから書き足す、といった使い方ができる
    # (alias だとこれができない)。
    #
    # ツール固有の abbr は各モジュール側に置いている:
    #   git    → home/git.nix
    #   herdr  → home/herdr.nix
    # ─────────────────────────────────────────────────────────
    shellAbbrs = {
      # hms だけは絶対パスではなく `.` を参照する。適用はリポジトリに
      # cd してから行う運用なので、worktree など「いま居るチェックアウト」を
      # そのまま適用できる方が意図と一致する。username は userInfo から
      # config 経由で流れてくるので直書きしない。
      hms = "home-manager switch --flake .#${config.home.username}@ubuntu";
      hmn = "home-manager news --flake ${flakeRef}";
      hmg = "home-manager generations --flake ${flakeRef}";

      # flake の更新と、switch 前の評価チェック。
      # nix flake check はビルドまでやると重いので --no-build を既定にする
      # (README の確認手順と揃えている)。
      nfc = "nix flake check --no-build ${flakeDir}";
      nfu = "nix flake update --flake ${flakeDir}";
    };

    interactiveShellInit = ''
      # 環境変数
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx LANG en_US.UTF-8

      # GHQ_ROOT は home/cli/ghq.nix の home.sessionVariables で設定している。
      # あちらは hm-session-vars.fish 経由で fish にも届くので、
      # ここに書くと二重定義になる。

      # 起動時の "Welcome to fish, the friendly interactive shell" を消す。
      # 既定の fish_greeting 関数は $fish_greeting を表示するだけなので、
      # 空にすれば何も出ない (関数の再定義は不要)。
      # pure のプロンプトは 1 行目から始まってほしいので黙らせる。
      #
      # fish は universal 変数として fish_greeting を持つことがあるが、
      # global が universal より優先されるのでここでの set -g で上書きできる。
      set -g fish_greeting ""

      # ─────────────────────────────────────────────────────
      # 暗すぎる文字色の底上げ (黒背景対策)
      #
      # fish と pure は「控えめな情報」に brblack を割り当てる。
      # Catppuccin Mocha だと brblack = #585b70、背景 #1e1e2e に
      # 対するコントラスト比は 1.6:1 しかなく、プロンプトの git 情報
      # (main*) や入力補完のゴースト表示がほぼ読めない。
      #
      # 明るい ANSI 色 (blue/red/yellow など) を使っている箇所は
      # 端末のテーマに追随して見えるので触らない。暗い既定値だけを
      # 灰色系の実値に差し替える。WCAG AA (4.5:1) は満たす。
      #
      # conf.d/*.fish (pure 本体) は config.fish より先に読まれ、
      # pure は universal 変数へ既定値を入れる。fish は global を
      # universal より優先して解決するので、ここで上書きできる。
      # ─────────────────────────────────────────────────────

      # git ブランチ名と dirty マーク、ユーザ名・ホスト名など。
      # pure_color_git_branch などは "pure_color_mute" という
      # 変数名を値に持つ間接参照なので、mute を変えれば波及する。
      set -g pure_color_mute a6adc8   # subtext0  7.4:1

      # 入力補完のゴースト表示 (既定 555)。入力済みの文字より
      # 暗く、それでも読める明度にする。
      set -g fish_color_autosuggestion 9399b2   # overlay2  5.8:1

      # コメントも同じ理由で暗い既定値のことがある
      set -g fish_color_comment 9399b2

      # Tab で開く補完候補メニュー。説明文と選択行が沈みやすい。
      set -g fish_pager_color_description a6adc8
      set -g fish_pager_color_selected_background --background=45475a
    '';
  };
}
