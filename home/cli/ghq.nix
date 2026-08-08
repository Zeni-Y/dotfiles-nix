# ghq: リポジトリを <GHQ_ROOT>/<host>/<owner>/<repo> に集約する
#
# 「入れるだけ」なら home/packages.nix で足りるが、下の dev / ghq-path
# というシェル関数を持つのでこちらに置いている
# (packages.nix は設定不要のツール専用、という切り分け)。
{ pkgs, ... }:

{
  home.packages = [ pkgs.ghq ];

  # clone 先。gwq の worktree.basedir (home/cli/gwq.nix) と同じ値にすること。
  # 両者を揃えることで `ghq list` に本体と worktree の両方が並び、
  # 下の dev から一つの UI で行き来できる (docs/git-worktree.md 7 章)。
  #
  # home.sessionVariables は hm-session-vars 経由で bash にも fish にも
  # 届くので、シェルごとに書く必要は無い。
  home.sessionVariables.GHQ_ROOT = "$HOME/ghq";

  # ─────────────────────────────────────────────────────────
  # 「移動」を作る: ghq list + fzf
  #
  # programs.fish.functions は ~/.config/fish/functions/<name>.fish を
  # 生成する。fish の autoload に乗るので、シェル起動時のコストは無い。
  #
  # bash には入れていない。対話 bash は fish に exec する
  # (home/shell/bash.nix) ため、実際に使われるのは fish 側だけ。
  # ─────────────────────────────────────────────────────────
  programs.fish.functions = {
    ghq-path = {
      description = "ghq 配下のリポジトリ / worktree を fzf で選び、フルパスを返す";
      body = ''
        # --query "$argv" は引用が要る。素の $argv だと引数ゼロのとき
        # 展開結果まで消えて、--query が後続の --select-1 を食う。
        #
        # --select-1 で候補が 1 件なら即決定、--exit-0 で 0 件なら
        # ファインダを出さずに終了する (`dev dotfiles` のような使い方向け)。
        #
        # --with-nth -1 は「表示と絞り込みだけ」最終要素 (<repo> や
        # <repo>=<branch>) に絞る。<GHQ_ROOT>/<host>/<owner> は全リポジトリで
        # 共通なので出す意味が無い。選択結果 {} と関数の返り値は元の行の
        # ままフルパスなので、preview や dev 側の cd はそのまま動く。
        # 別 owner のリポジトリを持ち始めて名前が衝突するようになったら
        # -2.. (owner/repo 表示) に広げること。
        ghq list --full-path \
          | fzf --query "$argv" \
                --select-1 --exit-0 \
                --delimiter / --with-nth -1 \
                --prompt 'repo> ' \
                --preview 'git -C {} log --oneline --decorate --graph -10 2>/dev/null'
      '';
    };

    dev = {
      description = "ghq 配下のリポジトリ / worktree に移動する";
      body = ''
        set -l target (ghq-path $argv)

        # fzf を Esc / ctrl+c で抜けたときは何も返らない。
        # ここで止めないと引数無しの cd が走ってホームに飛ぶ。
        # (元ネタのシェル関数は `cd "$moveto" || exit 1` だが、
        #  fish の exit は関数ではなくシェル自体を終わらせるので使えない)
        if test -z "$target"
          return 1
        end

        cd $target
        or return 1

        # herdr の中ならワークスペース名も移動先に合わせる。
        # herdr のラベルはワークスペース作成時のリポジトリ名で決まるため、
        # 同じワークスペースの中で cd しただけでは追従しない。
        #
        # tmux 版はセッション名の "." を "-" に潰しているが、herdr の
        # ラベルは "." をそのまま受け付けるので置換はしない (確認済み)。
        # ラベルは "<repo>=<branch>" の形になるので、worktree に居るのか
        # 本体に居るのかがタブバーだけで分かる。
        if set -q HERDR_WORKSPACE_ID
          herdr workspace rename $HERDR_WORKSPACE_ID (path basename $target) >/dev/null
        end
      '';
    };
  };
}
