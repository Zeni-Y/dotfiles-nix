# ─────────────────────────────────────────────────────────────
# preview: リモートのファイルをローカルのブラウザで見る
#
# 対応: markdown / HTML / 画像 / PDF / 音声。
# markdown はこのマシン (リモート) で HTML に変換し、それ以外は実体を
# そのまま 127.0.0.1 限定の HTTP で配信して、ローカル側は SSH の
# LocalForward 越しに Chrome で開く。完全オフライン (pandoc + entr +
# python http.server) で、外部 API やネットワーク公開を伴わない。
# 使い方は docs/cli/preview.md。
#
# サーバーは ~/.cache/preview を配信ルートに 1 個だけ常駐させ、
# ファイルごとにサブパス (/<slug>/) を割り当てる。複数ファイルを
# 同時にプレビューしてもポートが増えず、ローカル側の LocalForward が
# 1 行で済むようにするための設計 (1 起動 = 1 ポートにしない)。
# ディレクトリを渡すと、配下の対応ファイルを左ツリー + 右 iframe の
# 2 ペイン画面でまとめて見られる。
#
# 画像と PDF はブラウザのネイティブ表示に任せる。音声は全プレビュー
# 共通の静的ページ /player.html (?src= で対象を指定) で開き、波形の
# 生成・チャンネル切替はブラウザ側の Web Audio API でやる。サーバーを
# 静的配信のままにして、リモート側に ffmpeg 等の依存を増やさないため。
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

  # 音声プレーヤー (全プレビュー共通の静的ページ)。?src=/<slug>/<file> で対象を受ける。
  # 波形はブラウザが音声ファイルを fetch + decodeAudioData して描く。サーバー側で
  # 波形画像を作らないのは、静的配信だけで済ませて依存を増やさないため。
  # チャンネル切替は <audio> → ChannelSplitter → ChannelMerger の経路で、
  # 「L だけ」を選んだら左チャンネルを両耳に流す (片耳だけ鳴らすと聴き比べづらい)。
  previewPlayer = pkgs.writeText "preview-player.html" ''
    <!doctype html>
    <html><head><meta charset="utf-8"><title>preview</title>
    <style>
    :root { color-scheme: light dark; }
    body { font-family: system-ui, sans-serif; max-width: 60rem; margin: 2rem auto; padding: 0 1rem; }
    h1 { font-size: 1.1rem; overflow-wrap: anywhere; border-bottom: 1px solid #8884; padding-bottom: .3em; }
    #wave { width: 100%; height: 220px; display: block; background: #8881; border-radius: 6px; cursor: crosshair; touch-action: none; }
    #bar { display: flex; align-items: center; gap: .8rem; margin-top: .8rem; flex-wrap: wrap; }
    audio { flex: 1; min-width: 16rem; }
    #ch button { padding: .3em .8em; border: 1px solid #8886; background: none; border-radius: 4px; cursor: pointer; color: inherit; }
    #ch button.on { background: #4a90d9; color: #fff; border-color: #4a90d9; }
    #status { opacity: .7; font-size: .9em; }
    </style></head><body>
    <h1 id="name"></h1>
    <canvas id="wave" height="220"></canvas>
    <div id="bar">
      <audio id="audio" controls preload="metadata"></audio>
      <span id="ch">
        <button data-ch="stereo" class="on">ステレオ</button>
        <button data-ch="left">L のみ</button>
        <button data-ch="right">R のみ</button>
      </span>
    </div>
    <p id="status">波形を生成中…</p>
    <script>
    "use strict";
    var src = new URLSearchParams(location.search).get("src");
    var audio = document.getElementById("audio");
    var canvas = document.getElementById("wave");
    var cctx = canvas.getContext("2d");
    var statusEl = document.getElementById("status");
    if (!src) { statusEl.textContent = "?src=/<スラグ>/<ファイル> の指定がない"; throw new Error("no src"); }
    var name = decodeURIComponent(src.split("/").pop());
    document.getElementById("name").textContent = name;
    document.title = name;
    audio.src = src;

    // <audio> → splitter → merger → 出力。suspended のままだと無音なので再生開始で resume
    var actx = new (window.AudioContext || window.webkitAudioContext)();
    var splitter = actx.createChannelSplitter(2);
    var merger = actx.createChannelMerger(2);
    actx.createMediaElementSource(audio).connect(splitter);
    merger.connect(actx.destination);
    audio.addEventListener("play", function () { actx.resume(); });

    var mode = "stereo";
    function applyMode() {
      try { splitter.disconnect(); } catch (e) { void e; }
      if (mode === "left") { splitter.connect(merger, 0, 0); splitter.connect(merger, 0, 1); }
      else if (mode === "right") { splitter.connect(merger, 1, 0); splitter.connect(merger, 1, 1); }
      else { splitter.connect(merger, 0, 0); splitter.connect(merger, 1, 1); }
      renderCache();
    }
    applyMode();
    document.querySelectorAll("#ch button").forEach(function (b) {
      b.addEventListener("click", function () {
        mode = b.dataset.ch;
        document.querySelectorAll("#ch button").forEach(function (x) { x.classList.toggle("on", x === b); });
        applyMode();
      });
    });

    // 波形: 全サンプルを decode し、1px 列ごとの min/max を描いてキャッシュしておく
    var buffer = null;
    var cache = document.createElement("canvas");
    fetch(src)
      .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.arrayBuffer(); })
      .then(function (b) { return actx.decodeAudioData(b); })
      .then(function (buf) {
        buffer = buf;
        if (buf.numberOfChannels < 2) document.getElementById("ch").style.display = "none";
        statusEl.textContent = buf.numberOfChannels + "ch / " + buf.sampleRate + " Hz / " + fmt(buf.duration);
        resize();
      })
      .catch(function (e) { statusEl.textContent = "波形の生成に失敗 (再生は下のプレーヤーで試せる): " + e.message; });

    function fmt(t) {
      if (!isFinite(t)) return "-:--";
      var m = Math.floor(t / 60), s = t - m * 60;
      return m + ":" + (s < 10 ? "0" : "") + s.toFixed(1);
    }

    function renderCache() {
      if (!buffer) return;
      var w = canvas.width, h = canvas.height;
      cache.width = w; cache.height = h;
      var c = cache.getContext("2d");
      var nch = Math.min(2, buffer.numberOfChannels);
      var laneH = h / nch;
      for (var ch = 0; ch < nch; ch++) {
        var data = buffer.getChannelData(ch);
        var mid = laneH * ch + laneH / 2;
        // 聴いていない側のチャンネルは薄くして、どちらが鳴るかを波形でも示す
        var dim = nch === 2 && ((mode === "left" && ch === 1) || (mode === "right" && ch === 0));
        c.fillStyle = dim ? "rgba(128,140,150,.25)" : (ch === 0 ? "#4a90d9" : "#2fa878");
        var step = data.length / w;
        for (var x = 0; x < w; x++) {
          var lo = 1, hi = -1;
          var s0 = Math.floor(x * step), s1 = Math.min(data.length, Math.floor((x + 1) * step) + 1);
          // 列内の全サンプルは見ない (長尺だと描画が数秒止まる)。間引いても見た目はほぼ同じ
          var stride = Math.max(1, Math.floor((s1 - s0) / 200));
          for (var i = s0; i < s1; i += stride) { var v = data[i]; if (v < lo) lo = v; if (v > hi) hi = v; }
          var y0 = mid - hi * (laneH / 2) * 0.95;
          c.fillRect(x, y0, 1, Math.max(1, (hi - lo) * (laneH / 2) * 0.95));
        }
        if (nch === 2) {
          c.fillStyle = "rgba(128,128,128,.8)";
          c.font = "12px system-ui";
          c.fillText(ch === 0 ? "L" : "R", 6, laneH * ch + 14);
        }
      }
      if (nch === 2) { c.fillStyle = "rgba(128,128,128,.4)"; c.fillRect(0, laneH, w, 1); }
    }

    function frame() {
      var w = canvas.width, h = canvas.height;
      cctx.clearRect(0, 0, w, h);
      if (cache.width) cctx.drawImage(cache, 0, 0);
      if (audio.duration) {
        var x = audio.currentTime / audio.duration * w;
        cctx.fillStyle = "rgba(128,128,128,.25)";
        cctx.fillRect(0, 0, x, h);
        cctx.fillStyle = "#e05252";
        cctx.fillRect(x - 1, 0, 2, h);
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);

    function resize() {
      var r = canvas.getBoundingClientRect();
      var dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(100, Math.floor(r.width * dpr));
      canvas.height = Math.floor(220 * dpr);
      renderCache();
    }
    window.addEventListener("resize", resize);
    resize();

    // 波形のクリック / ドラッグでシーク
    var dragging = false;
    function seek(e) {
      if (!audio.duration) return;
      var r = canvas.getBoundingClientRect();
      var f = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
      audio.currentTime = f * audio.duration;
    }
    canvas.addEventListener("pointerdown", function (e) { dragging = true; canvas.setPointerCapture(e.pointerId); seek(e); });
    canvas.addEventListener("pointermove", function (e) { if (dragging) seek(e); });
    canvas.addEventListener("pointerup", function () { dragging = false; });

    // Space で再生/停止、←→ で 5 秒シーク
    window.addEventListener("keydown", function (e) {
      if (e.target.tagName === "BUTTON" || e.target.tagName === "AUDIO") return;
      if (e.code === "Space") { e.preventDefault(); if (audio.paused) audio.play(); else audio.pause(); }
      else if (e.code === "ArrowLeft") audio.currentTime = Math.max(0, audio.currentTime - 5);
      else if (e.code === "ArrowRight") audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + 5);
    });
    </script></body></html>
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
        # $1 配下の対応ファイル (md/html/画像/pdf/音声) を相対パスで列挙する。
        # 隠しディレクトリ (.git など) と node_modules は除外。-mindepth 1 が無いと
        # 起点の . 自体が '.*' の prune に食われて何も出なくなる
        (
          cd "$1" &&
            find . -mindepth 1 \( -name '.*' -o -name node_modules \) -prune -o \
              -type f \( -iname '*.md' -o -iname '*.markdown' -o -iname '*.html' -o -iname '*.htm' \
                -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.svg' \
                -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' -o -iname '*.ico' \
                -o -iname '*.pdf' \
                -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.oga' -o -iname '*.flac' \
                -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.opus' \) -print \
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
            case ''${rel,,} in
              *.md | *.markdown)
                printf '<a style="padding-left:%sem" href="/%s/md/%s.html" target="content">%s</a>' \
                  "$depth" "$slug" "$rel" "$base"
                ;;
              *.mp3 | *.wav | *.ogg | *.oga | *.flac | *.m4a | *.aac | *.opus)
                # 音声は素の <audio> ではなく波形付きプレーヤー経由で開く
                printf '<a style="padding-left:%sem" href="/player.html?src=/%s/src/%s" target="content">♪ %s</a>' \
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
        # 変換が要るのは md だけ (他は $slugdir/src の symlink 経由でそのまま配信)。
        # 1 ファイルの失敗 (壊れた md など) で全体を止めない
        local srcroot=$1 slugdir=$2 refresh=$3 rel
        while IFS= read -r rel; do
          case ''${rel,,} in
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
          case ''${5,,} in
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
      使い方: preview [-p PORT] [-r 秒] <ファイル|ディレクトリ>
              preview -l   登録済みプレビューの一覧を表示する
              preview -s   サーバーを停止する (登録はキャッシュに残る)

      対応形式: markdown / HTML / 画像 (png jpg gif svg webp avif bmp ico) / PDF /
                音声 (mp3 wav ogg flac m4a aac opus)。音声は波形表示・クリックでの
                シーク・L/R チャンネル切替ができるプレーヤーで開く。

      サーバーは 1 個だけ常駐し、対象ごとに http://localhost:PORT/<slug>/ を
      割り当てる。トップ (/) は一覧ページ。ローカル側で LocalForward を張って開く。
      ディレクトリを渡すと、配下の対応ファイルを左ツリー + 右プレビューの
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
      # 音声プレーヤーは全プレビュー共通の静的ページ (実体は Nix store)。
      # 毎回張り直すことで home-manager switch 後の新版も次の起動から反映される
      ln -sfn ${previewPlayer} "$root/player.html"

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
        # html・画像・pdf・音声は $slug/src/ (symlink) から実体を配信する
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

      case ''${src,,} in
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
        *.html | *.htm | *.pdf | \
          *.png | *.jpg | *.jpeg | *.gif | *.svg | *.webp | *.avif | *.bmp | *.ico)
          # HTML・画像・PDF は変換せず、相対パスの画像や CSS が生きるよう
          # ディレクトリごと symlink で配信ルートに載せる (実体はコピーしない)。
          # 表示はブラウザのネイティブ機能 (PDF ビューアなど) に任せる
          ln -sfn "$(dirname "$src")" "$root/$slug"
          url=$slug/$(basename "$src")
          printf '%s\n%s\n' "$src" "$url" > "$meta/$slug"
          generate_index
          ensure_server
          echo "ローカルのブラウザで開く: http://localhost:$port/$url"
          echo "(一覧: http://localhost:$port/  サーバー停止は preview -s)"
          ;;
        *.mp3 | *.wav | *.ogg | *.oga | *.flac | *.m4a | *.aac | *.opus)
          # 音声は実体を symlink で配信しつつ、URL は波形付きプレーヤーにする
          ln -sfn "$(dirname "$src")" "$root/$slug"
          url="player.html?src=/$slug/$(basename "$src")"
          printf '%s\n%s\n' "$src" "$url" > "$meta/$slug"
          generate_index
          ensure_server
          echo "ローカルのブラウザで開く: http://localhost:$port/$url"
          echo "(一覧: http://localhost:$port/  サーバー停止は preview -s)"
          ;;
        *)
          echo "対応していない拡張子です (md / html / 画像 / pdf / 音声): $src" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = [ preview ];
}
