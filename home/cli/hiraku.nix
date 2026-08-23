# ─────────────────────────────────────────────────────────────
# hiraku: リモートのファイルをローカルのブラウザで見る
#
# 対応: markdown / HTML / 画像 / PDF / 音声。markdown はこのマシン
# (リモート) で HTML に変換し、それ以外は実体をそのまま 127.0.0.1 限定の
# HTTP で配信して、ローカル側は SSH の LocalForward 越しに Chrome で開く。
# 完全オフライン (pandoc + python3 だけ) で、外部 API やネットワーク公開を
# 伴わない。使い方は docs/cli/hiraku.md。
#
# 実体は python の小さなサーバー (hiraku/server.py) で、これを
# **フォアグラウンドで** 起動する。Ctrl-C で止まり、止めたらブラウザからも
# 見えなくなる。常時見たいならシェルの側でバックグラウンドに回す。
# 変換結果をディスクに残さない (旧版の ~/.cache/hiraku を廃止した) のは、
# 「動かしている間だけ見える」を素直な作りで実現するため。md はリクエスト
# ごとに pandoc に通すので、事前生成 (entr) も要らなくなった。
#
# 画面はディレクトリを畳んだ状態のファイルツリー + プレビューの 2 ペイン。
# 配下を再帰的に全部並べないのは、大きなディレクトリでも開くのが軽く、
# 目的のファイルを探しやすいため。拡張子で絞り込め、境界のドラッグで
# ツリーの幅を変えられる。ファイルの変更は監視スレッドが検知して SSE で
# ブラウザに伝え、開いているファイルだけを読み込み直す。
#
# PDF はブラウザのネイティブ表示に任せる。音声と画像は全プレビュー共通の
# 静的ページ /player.html /image.html (?src= で対象を指定) で開く。音声の波形生成・
# チャンネル切替はブラウザ側の Web Audio API でやる。サーバー側に ffmpeg 等の
# 依存を増やさないため。画像をネイティブ表示にしないのは、ペイン幅に合わせて
# 勝手に伸縮されるだけで倍率を選べず、大きい画像も小さい画像も見づらいため。
#
# ターミナル内に画像として描画する案 (Kitty graphics) も検証したが、
# テキスト選択・コピーができない静止画になるため不採用にした。
# 検証記録は docs/cli/hiraku.md 6 章。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  # 画面まわりは Nix の文字列に埋めず別ファイルに置く。JS も CSS も
  # ''${ } を Nix にエスケープさせずに済み、エディタの支援も効くため。
  hirakuServer = ./hiraku/server.py;
  hirakuApp = ./hiraku/app.html;
  hirakuCss = ./hiraku/style.css;
  hirakuPlayer = ./hiraku/player.html;
  hirakuImage = ./hiraku/image.html;

  hiraku = pkgs.writeShellApplication {
    name = "hiraku";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.pandoc
      pkgs.python3
    ];
    text = ''
      usage() {
        cat <<'EOF'
      使い方: hiraku [-p PORT] <ファイル|ディレクトリ>...

      指定したものを 127.0.0.1:PORT (既定 4649) で配信し、ローカル側は
      SSH の LocalForward 越しにブラウザで開く。画面はファイルツリー +
      プレビューの 2 ペイン。

      対応形式: markdown / HTML / 画像 (png jpg gif svg webp avif bmp ico) /
                PDF / 音声 (mp3 wav ogg flac m4a aac opus)。音声は波形表示・
                クリックでのシーク・L/R チャンネル切替ができるプレーヤーで開く。
                画像は左クリックで拡大・Ctrl+左クリックで縮小・長押しで移動
                できるビューアで開き、倍率を右上に表示する。

        -p PORT   待ち受けポート (既定 4649)

      Ctrl-C で終了する。終了するとブラウザからは見えなくなる (変換結果を
      ディスクに残さないため)。ログアウトしても見続けたいなら
      `hiraku docs/ &; disown` のようにバックグラウンドへ回す。

      ファイルを渡すとその親ディレクトリが対象になり、そのファイルを開いた
      状態で始まる。複数指定すると 1 つのサーバーでまとめて配信する
      (ポートが増えないので LocalForward は 1 行のままでよい)。
      EOF
      }

      port=4649
      while getopts "p:h" opt; do
        case $opt in
          p) port=$OPTARG ;;
          h) usage; exit 0 ;;
          *) usage >&2; exit 1 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ $# -lt 1 ]; then
        usage >&2
        exit 1
      fi

      for target in "$@"; do
        if [ ! -e "$target" ]; then
          echo "ありません: $target" >&2
          exit 1
        fi
      done

      # exec で置き換える。シェルを 1 段はさむと Ctrl-C や終了ステータスの
      # 伝わり方を自前で面倒みることになり、旧版が「Ctrl-C で終わらない」
      # 原因になっていた
      exec python3 ${hirakuServer} \
        --port "$port" \
        --asset "app=${hirakuApp}" \
        --asset "css=${hirakuCss}" \
        --asset "player=${hirakuPlayer}" \
        --asset "image=${hirakuImage}" \
        -- "$@"
    '';
  };
in
{
  home.packages = [ hiraku ];
}
