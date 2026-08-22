# ─────────────────────────────────────────────────────────────
# preview: リモートの markdown / HTML をローカルのブラウザで見る
#
# このマシン (リモート) で HTML に変換して 127.0.0.1 限定の HTTP で
# 配信し、ローカル側は SSH の LocalForward 越しに Chrome で開く。
# 完全オフライン (pandoc + entr + python http.server) で、外部 API や
# ネットワーク公開を伴わない。使い方は docs/cli/preview.md。
#
# サーバーは ~/.cache/preview を配信ルートに 1 個だけ常駐させ、
# ファイルごとにサブパス (/<slug>/) を割り当てる。複数ファイルを
# 同時にプレビューしてもポートが増えず、ローカル側の LocalForward が
# 1 行で済むようにするための設計 (1 起動 = 1 ポートにしない)。
# ディレクトリを渡すと、配下の md/html を左ツリー + 右 iframe の
# 2 ペイン画面でまとめて見られる。
#
# ターミナル内に画像として描画する案 (Kitty graphics) も検証したが、
# テキスト選択・コピーができない静止画になるため不採用にした。
# 検証記録は docs/cli/preview.md 5 章。
# ─────────────────────────────────────────────────────────────
{ pkgs, ... }:

let
  # pandoc の素の standalone HTML は無装飾で読みにくいので最小限の CSS を当てる。
  # --embed-resources で HTML 本体に埋め込まれるため、配信するのは 1 ファイルで済む。
  previewCss = pkgs.writeText "preview.css" ''
    :root { color-scheme: light dark; }
    body { font-family: system-ui, sans-serif; line-height: 1.6; max-width: 48rem; margin: 2rem auto; padding: 0 1rem; }
    h1, h2 { border-bottom: 1px solid #8884; padding-bottom: .3em; }
    pre { background: #8881; padding: .8em; border-radius: 6px; overflow-x: auto; }
    table { border-collapse: collapse; }
    th, td { border: 1px solid #8886; padding: .3em .8em; }
    blockquote { border-left: 4px solid #8886; margin-left: 0; padding-left: 1em; opacity: .8; }
    img { max-width: 100%; }
  '';

  preview = pkgs.writeShellApplication {
    name = "preview";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gnugrep
      # setsid のため (サーバーを呼び出し元のプロセスグループから切り離す)
      pkgs.util-linux
      pkgs.pandoc
      pkgs.entr
      pkgs.python3
    ];
    text = ''
      render_md() {
        # $1=元ファイル $2=出力先 $3=自動リロード秒 (空なら無し)。
        # 相対パスの画像を --embed-resources で拾えるよう、元ファイルの場所で変換する
        local src=$1 out=$2 refresh=''${3:-}
        local args=()
        if [ -n "$refresh" ]; then
          args+=(-V "header-includes=<meta http-equiv=\"refresh\" content=\"$refresh\">")
        fi
        (
          cd "$(dirname "$src")" &&
            pandoc -s -f gfm -t html5 --embed-resources \
              --css ${previewCss} \
              --metadata "title=$(basename "$src")" \
              "''${args[@]}" -o "$out" "$(basename "$src")"
        )
      }

      list_files() {
        # $1 配下の md/html を相対パスで列挙する。隠しディレクトリ (.git など) と
        # node_modules は除外。-mindepth 1 が無いと起点の . 自体が '.*' の
        # prune に食われて何も出なくなる
        (
          cd "$1" &&
            find . -mindepth 1 \( -name '.*' -o -name node_modules \) -prune -o \
              -type f \( -name '*.md' -o -name '*.markdown' -o -name '*.html' -o -name '*.htm' \) -print \
            | sed 's|^\./||' | LC_ALL=C sort
        )
      }

      generate_dir_index() {
        # $1=元ディレクトリ $2=スラグディレクトリ。
        # 左にファイルツリー、右に iframe の 2 ペイン画面を生成する。
        # target="content" の素の HTML だけで動かし、JS には依存しない
        local srcroot=$1 slugdir=$2 slug rel d base depth prevdir=""
        slug=$(basename "$slugdir")
        {
          printf '<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>' "$(basename "$srcroot")"
          printf 'body{display:flex;height:100vh;margin:0;font-family:system-ui,sans-serif}'
          printf '#side{width:16rem;overflow:auto;border-right:1px solid #8884;padding:.8rem;flex-shrink:0}'
          printf '#side h2{font-size:1rem;margin:.2rem 0 .8rem}'
          printf '#side a{display:block;padding:.15rem .3rem;text-decoration:none;border-radius:4px;overflow-wrap:anywhere}'
          printf '#side a:hover{background:#8882}'
          printf '#side .d{opacity:.6;font-size:.85em;margin-top:.4rem}'
          printf 'iframe{flex:1;border:0}'
          printf '</style></head><body><nav id="side"><h2>%s</h2>' "$(basename "$srcroot")"
          while IFS= read -r rel; do
            d=$(dirname "$rel")
            base=$(basename "$rel")
            depth=$(printf '%s' "$rel" | tr -cd / | wc -c)
            if [ "$d" != "$prevdir" ] && [ "$d" != . ]; then
              printf '<div class="d" style="padding-left:%sem">%s/</div>' "$((depth - 1))" "$d"
            fi
            prevdir=$d
            case $rel in
              *.md | *.markdown)
                printf '<a style="padding-left:%sem" href="/%s/md/%s.html" target="content">%s</a>' \
                  "$depth" "$slug" "$rel" "$base"
                ;;
              *)
                printf '<a style="padding-left:%sem" href="/%s/src/%s" target="content">%s</a>' \
                  "$depth" "$slug" "$rel" "$base"
                ;;
            esac
          done < <(list_files "$srcroot")
          printf '</nav><iframe name="content"></iframe></body></html>'
        } > "$slugdir/index.html"
      }

      render_dir_all() {
        # $1=元ディレクトリ $2=スラグディレクトリ $3=自動リロード秒。
        # 1 ファイルの失敗 (壊れた md など) で全体を止めない
        local srcroot=$1 slugdir=$2 refresh=$3 rel
        while IFS= read -r rel; do
          case $rel in
            *.md | *.markdown)
              mkdir -p "$slugdir/md/$(dirname "$rel")"
              render_md "$srcroot/$rel" "$slugdir/md/$rel.html" "$refresh" \
                || echo "変換失敗: $rel" >&2
              ;;
          esac
        done < <(list_files "$srcroot")
      }

      # ── 内部モード (entr から自分自身を呼び直すためのもの) ──
      case "''${1:-}" in
        --render)
          render_md "$2" "$3" "''${4:-}"
          exit 0
          ;;
        --render-rel)
          # $2=元dir $3=スラグdir $4=自動リロード秒 $5=変更されたファイル。
          # ツリーは毎回作り直す (ファイル名変更などの取りこぼし対策として安価)
          generate_dir_index "$2" "$3"
          case $5 in
            *.md | *.markdown)
              rel=''${5#"$2"/}
              mkdir -p "$3/md/$(dirname "$rel")"
              render_md "$5" "$3/md/$rel.html" "''${4:-}"
              ;;
          esac
          exit 0
          ;;
      esac

      usage() {
        cat <<'EOF'
      使い方: preview [-p PORT] [-r 秒] <file.md|file.html|ディレクトリ>
              preview -l   登録済みプレビューの一覧を表示する
              preview -s   サーバーを停止する (登録はキャッシュに残る)

      サーバーは 1 個だけ常駐し、対象ごとに http://localhost:PORT/<slug>/ を
      割り当てる。トップ (/) は一覧ページ。ローカル側で LocalForward を張って開く。
      ディレクトリを渡すと、配下の md/html を左ツリー + 右プレビューの
      2 ペイン画面でまとめて見られる。
        -p PORT   待ち受けポート (既定 4649。稼働中のサーバーがあればそちらに従う)
        -r 秒     ブラウザ側の自動リロード間隔 (markdown のみ。既定は手動リロード)
      EOF
      }

      root=''${XDG_CACHE_HOME:-$HOME/.cache}/preview
      meta=$root/.meta
      pidfile=$root/server.pid
      portfile=$root/server.port
      mkdir -p "$root" "$meta"

      server_running() {
        [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
      }

      # トップページ: 登録済みエントリへのリンク一覧を静的に生成する。
      # python http.server は index.html があればそれを返すので、これだけで済む
      generate_index() {
        {
          printf '<!doctype html><html><head><meta charset="utf-8"><title>preview</title>'
          printf '<style>body{font-family:system-ui,sans-serif;max-width:48rem;margin:2rem auto;padding:0 1rem;line-height:1.8}</style>'
          printf '</head><body><h1>preview 一覧</h1><ul>'
          for m in "$meta"/*; do
            [ -f "$m" ] || continue
            printf '<li><a href="/%s">%s</a></li>' "$(sed -n 2p "$m")" "$(sed -n 1p "$m")"
          done
          printf '</ul></body></html>'
        } > "$root/index.html"
      }

      ensure_server() {
        if server_running; then
          running_port=$(cat "$portfile")
          if [ "$running_port" != "$port" ]; then
            echo "注意: サーバーはポート $running_port で稼働中なのでそちらを使う (-p $port は無視)" >&2
            port=$running_port
          fi
          return
        fi
        # setsid で別セッションに切り離す。nohup では足りない:
        # md の監視 (entr) を Ctrl-C で止めるとき、同じプロセスグループに居ると
        # サーバーまで SIGINT で道連れになる。端末クローズ (SIGHUP) 対策も兼ねる。
        # 127.0.0.1 に束縛して LAN には公開しない。届く経路は SSH トンネルだけ
        setsid python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root" \
          > "$root/server.log" 2>&1 &
        echo $! > "$pidfile"
        echo "$port" > "$portfile"
        sleep 0.5
        if ! server_running; then
          echo "サーバーの起動に失敗 (ポート $port が使用中?):" >&2
          tail -3 "$root/server.log" >&2
          rm -f "$pidfile" "$portfile"
          exit 1
        fi
      }

      port=4649
      refresh=""
      action=serve
      while getopts "p:r:lsh" opt; do
        case $opt in
          p) port=$OPTARG ;;
          r) refresh=$OPTARG ;;
          l) action=list ;;
          s) action=stop ;;
          h) usage; exit 0 ;;
          *) usage >&2; exit 1 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ "$action" = list ]; then
        [ -f "$portfile" ] && port=$(cat "$portfile")
        if server_running; then
          state="稼働中 (pid $(cat "$pidfile"))"
        else
          state="停止中"
        fi
        echo "サーバー: $state  http://localhost:$port/"
        for m in "$meta"/*; do
          [ -f "$m" ] || continue
          printf '  http://localhost:%s/%s\t%s\n' "$port" "$(sed -n 2p "$m")" "$(sed -n 1p "$m")"
        done
        exit 0
      fi

      if [ "$action" = stop ]; then
        if server_running; then
          kill "$(cat "$pidfile")"
          rm -f "$pidfile" "$portfile"
          echo "サーバーを停止した (登録は $root に残る。全消しは rm -rf $root)"
        else
          echo "サーバーは起動していない"
        fi
        exit 0
      fi

      if [ $# -ne 1 ]; then
        usage >&2
        exit 1
      fi
      src=$(realpath "$1")
      if [ ! -e "$src" ]; then
        echo "ファイルがありません: $src" >&2
        exit 1
      fi

      # スラグは「ファイル名 + フルパスのハッシュ」。同名ファイル (別リポジトリの
      # README.md 同士など) が衝突しないようにしつつ、URL から中身が分かる形にする
      slug=$(printf '%s' "$(basename "$src")" | tr -c 'A-Za-z0-9._-' '-')-$(printf '%s' "$src" | sha1sum | cut -c1-6)

      if [ -d "$src" ]; then
        # ディレクトリモード: 配下の md は $slug/md/ に変換結果をミラーし、
        # html や画像は $slug/src/ (symlink) から実体を配信する
        slugdir=$root/$slug
        mkdir -p "$slugdir/md"
        ln -sfn "$src" "$slugdir/src"
        url=$slug/
        printf '%s\n%s\n' "$src" "$url" > "$meta/$slug"
        generate_index
        ensure_server
        echo "ローカルのブラウザで開く: http://localhost:$port/$url"
        echo "(一覧: http://localhost:$port/  監視を終えるには Ctrl-C。サーバーは残る)"
        # entr の -d は監視中のディレクトリにファイルが増減すると一度終了するので、
        # ループで再スキャンしてツリーと変換結果を作り直す。
        # /_ は変更されたファイルのパスに置き換わる (変更分だけ再変換するため)
        while :; do
          generate_dir_index "$src" "$slugdir"
          render_dir_all "$src" "$slugdir" "$refresh"
          if ! list_files "$src" | grep -q .; then
            sleep 2
            continue
          fi
          list_files "$src" | sed "s|^|$src/|" \
            | entr -nd "$0" --render-rel "$src" "$slugdir" "$refresh" /_ \
            || true
        done
      fi

      case $src in
        *.md | *.markdown)
          # 変換結果はキャッシュ領域に置き、元ファイルのディレクトリを汚さない
          dir=$root/$slug
          mkdir -p "$dir"
          url=$slug/
          printf '%s\n%s\n' "$src" "$url" > "$meta/$slug"
          generate_index
          ensure_server
          "$0" --render "$src" "$dir/index.html" "$refresh"
          echo "ローカルのブラウザで開く: http://localhost:$port/$url"
          echo "(一覧: http://localhost:$port/  監視を終えるには Ctrl-C。サーバーは残る)"
          # 保存のたびに変換し直す。フォアグラウンドで待つので Ctrl-C で監視だけ終わる
          printf '%s\n' "$src" | entr -np "$0" --render "$src" "$dir/index.html" "$refresh"
          ;;
        *.html | *.htm)
          # HTML は変換せず、相対パスの画像や CSS が生きるようディレクトリごと
          # symlink で配信ルートに載せる (実体はコピーしない)
          ln -sfn "$(dirname "$src")" "$root/$slug"
          url=$slug/$(basename "$src")
          printf '%s\n%s\n' "$src" "$url" > "$meta/$slug"
          generate_index
          ensure_server
          echo "ローカルのブラウザで開く: http://localhost:$port/$url"
          echo "(一覧: http://localhost:$port/  サーバー停止は preview -s)"
          ;;
        *)
          echo "対応していない拡張子です (.md / .html): $src" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = [ preview ];
}
