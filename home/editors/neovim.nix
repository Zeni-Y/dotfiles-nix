# ─────────────────────────────────────────────────────────────
# Neovim + LazyVim
#
# あえて programs.neovim を使わない。あのモジュールは
# ~/.config/nvim/init.lua を Nix store 上に生成して symlink するため、
#   - LazyVim starter が置く init.lua と衝突する
#   - lazy-lock.json のような「Neovim 自身が書き込むファイル」を置けない
#     (symlink 先が read-only な Nix store になる)
# という二重の理由で LazyVim と噛み合わない。
#
# そこでここでは本体と LazyVim が前提にする外部コマンドだけを入れ、
# ~/.config/nvim は Nix 管理外の実ディレクトリとして扱う。
# エディタ側の設定 (options / keymaps / plugins) は原則
# ~/.config/nvim/lua/ 配下に Lua で書く。
#
# 例外として lua/plugins/ の中の「マシンが変わっても同じにしたい」spec だけは
# nvim/plugins/*.lua に置いて xdg.configFile で配る (下部参照)。
# lazy.nvim は lua/plugins/*.lua を読むだけで書き戻さないので、
# ここだけ read-only な symlink にしても init.lua や lazy-lock.json とは衝突しない。
#
# 旧 extraConfig にあった number / relativenumber / expandtab /
# tabstop=2 / shiftwidth=2 / ignorecase / smartcase / termguicolors は
# すべて LazyVim の既定値と同じなので移植不要。変えたくなったら
# ~/.config/nvim/lua/config/options.lua に書く。
# ─────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

let
  nvimConfigDir = "${config.xdg.configHome}/nvim";
  starterRepo = "https://github.com/LazyVim/starter";
in
{
  home.packages = with pkgs; [
    neovim

    # LazyVim が要求する外部コマンド。
    # git / ripgrep / fd / lazygit / gcc / gnumake / curl / unzip は
    # home/packages.nix と home/git.nix 側で既に入っているのでここには書かない。
    nodejs      # mason 経由で入る LSP・フォーマッタの多くが node を要求する
    tree-sitter # 公式配布されていないパーサを自前ビルドするとき用
  ];

  # programs.neovim.defaultEditor の代替。
  # fish の interactiveShellInit でも同じものを設定しているが、
  # あちらは対話 fish に入ったときだけ。非対話の bash や systemd 経由でも
  # 効くようセッション変数としても持たせておく。
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # programs.neovim.viAlias / vimAlias の代替。
  # あちらは実体 (nvim への symlink) を作るがこちらはシェルの alias なので、
  # スクリプト中の `vim ...` は素通りしてシステムの vim に落ちる点だけ注意。
  programs.fish.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };
  programs.bash.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  # ─────────────────────────────────────────────────────────────
  # lua/plugins/ に配る spec
  #
  # ディレクトリごとではなくファイル単位で置く。lua/plugins/ を丸ごと
  # xdg.configFile にすると starter の example.lua と衝突するうえ、
  # 手元で試しに 1 ファイル足すこともできなくなる。
  # ここに無いファイルはこれまで通りユーザが自由に置ける。
  # ─────────────────────────────────────────────────────────────
  xdg.configFile."nvim/lua/plugins/snacks-explorer.lua".source =
    ./nvim/plugins/snacks-explorer.lua;

  # ─────────────────────────────────────────────────────────────
  # LazyVim starter の初回取得
  #
  # ~/.config/nvim が無いときだけ clone する。以降は完全にユーザ管理で、
  # switch し直しても中身には一切触らない (= 上書き事故が起きない)。
  # .git を落としているのは、starter を「自分の設定の初期値」として
  # 扱い、必要なら自分のリポジトリで管理し直せるようにするため。
  #
  # ネットワークが無い環境でも switch 自体は失敗させたくないので、
  # 取得に失敗したら警告だけ出して続行する。
  #
  # linkGeneration の後に回すのは、programs.neovim を使っていた世代から
  # 移行するときに「Home Manager が張った init.lua の symlink を外し終えた
  # 状態」を見たいため。外した跡に空ディレクトリや dangling symlink が
  # 残ることがあるので、clone の前に掃除する。
  # ─────────────────────────────────────────────────────────────
  home.activation.lazyvimStarter = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    # dangling symlink (Nix store を指したまま世代が消えたもの)
    if [ -L "${nvimConfigDir}" ] && [ ! -e "${nvimConfigDir}" ]; then
      $DRY_RUN_CMD rm -f "${nvimConfigDir}"
    # 中身を全部持っていかれた空ディレクトリ
    elif [ -d "${nvimConfigDir}" ] && [ -z "$(ls -A "${nvimConfigDir}" 2>/dev/null)" ]; then
      $DRY_RUN_CMD rmdir "${nvimConfigDir}"
    fi

    if [ ! -e "${nvimConfigDir}" ]; then
      echo "neovim: ${nvimConfigDir} が無いので LazyVim starter を取得します"
      if $DRY_RUN_CMD ${pkgs.git}/bin/git clone --depth 1 ${starterRepo} "${nvimConfigDir}"; then
        $DRY_RUN_CMD rm -rf "${nvimConfigDir}/.git"
      else
        $DRY_RUN_CMD rm -rf "${nvimConfigDir}"
        echo "neovim: LazyVim starter の取得に失敗しました (ネットワーク未接続?)。" >&2
        echo "neovim: 後で手動で実行してください:" >&2
        echo "  git clone --depth 1 ${starterRepo} ${nvimConfigDir} && rm -rf ${nvimConfigDir}/.git" >&2
      fi
    fi
  '';
}
