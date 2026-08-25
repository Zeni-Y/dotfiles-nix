#!/usr/bin/env python3
"""hiraku のプレビューサーバー。

hiraku 本体 (home/cli/hiraku.nix) がフォアグラウンドで起動する。指定された
パスを 127.0.0.1 限定の HTTP で配信し、markdown はリクエストのたびに
pandoc に通す。

変換結果をディスクに残さないのは意図的で、「hiraku が動いている間だけ
ブラウザから見える」状態にするため (プロセスを落とせば何も残らない)。
そのため事前生成 (旧版の entr + ~/.cache/hiraku) は無い。ファイルの変更は
監視スレッドが検知して SSE (/api/events) でブラウザに伝え、ブラウザが
開き直すことで即座に反映される。

**ポートは 1 つ、URL の 1 段目でセッションを分ける。** 起動するたびに
`-p` で別のポートを選び、ローカル側の LocalForward を足す運用が面倒だった
ため、複数の hiraku が同じポート (既定 4649) を共有する。仕組み:

  - 起動したプロセスは対象の realpath から求めたハッシュを「セッション」の
    名前 (スラグ) とし、状態ファイルを $XDG_RUNTIME_DIR/hiraku/<ポート>/ に置く。
    同じ対象なら毎回同じ URL になるので、ブックマークできる。
  - ポートを掴めたプロセスが「窓口」になり、**生きている全セッション**を
    /<スラグ>/... で配信する。状態ファイルは対象のパスしか持たないので、
    窓口は他プロセスの対象もディスクから直接読める (中継は要らない)。
  - 窓口が Ctrl-C で落ちたら、残っているプロセスが 1 秒以内にポートを
    引き継ぐ。ブラウザ側は SSE が勝手に再接続するので繋ぎ直さなくてよい。
  - 生死は状態ファイルの pid + /proc の起動時刻で判定する。SIGKILL された
    プロセスの置き土産は、次に読んだ誰かが消す。

URL の構成:
    /                          セッション一覧 (1 つだけなら そこへ 303)
    /hiraku.css                pandoc 出力に当てる CSS (全セッション共通)
    /api/sessions              生きているセッションの一覧
    /<スラグ>/                 2 ペインのアプリ本体 (app.html)
    /<スラグ>/player.html      音声プレーヤー
    /<スラグ>/image.html       画像ビューア (拡大縮小・移動)
    /<スラグ>/api/roots        対象一覧と初期選択
    /<スラグ>/api/tree?path=&filter=  1 階層ぶんのツリー (遅延展開用)
    /<スラグ>/api/events       変更通知 (SSE)
    /<スラグ>/view/<対象>/<相対パス>  md は変換して、それ以外は実体を配信

セッション配下の URL をすべて /<スラグ>/ 起点にしてあるので、画面側 (app.html)
は相対 URL だけで書ける。スラグを JS に埋め込まずに済む。
"""

import argparse
import errno
import hashlib
import http.client
import json
import mimetypes
import os
import queue
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote, unquote, urlparse

# 拡張子の種別。ツリーのフィルタ (すべて / md / html / 画像 / PDF / 音声) と
# 「どう表示するか」の分岐を兼ねる。
KINDS = {
    "md": {".md", ".markdown"},
    "html": {".html", ".htm"},
    "image": {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".avif", ".bmp", ".ico"},
    "pdf": {".pdf"},
    "audio": {".mp3", ".wav", ".ogg", ".oga", ".flac", ".m4a", ".aac", ".opus"},
}
ALL_KINDS = frozenset(KINDS)
EXT_KIND = {ext: kind for kind, exts in KINDS.items() for ext in exts}

# 隠しディレクトリ (.git など) と node_modules は歩かない。
SKIP_DIRS = {"node_modules"}

# 監視の間隔と、1 周でたどるエントリ数の上限。上限を置くのは
# うっかり ~/ を渡したときに 1 秒ごとの全走査で CPU を焼かないため。
WATCH_INTERVAL = 0.7
WATCH_MAX_ENTRIES = 50000

# 窓口を譲り受けるまでの待ち時間。Ctrl-C からの引き継ぎがブラウザの
# SSE 再接続 (既定 3 秒) より速く済むように短くしてある。
TAKEOVER_INTERVAL = 1.0

SERVER_NAME = "hiraku"

ASSETS = {}         # 静的ファイルの実体パス
STATE_DIR = None    # セッションの状態ファイルを置くディレクトリ
CLIENTS = set()     # (スラグ, Queue) の集合 (SSE クライアント)
CLIENTS_LOCK = threading.Lock()

_sessions_cache = ({}, 0.0)
_sessions_lock = threading.Lock()


# ────────────────────── セッションの登録と一覧 ──────────────────────

def state_dir_for(port):
    """状態ファイルの置き場。ポートごとに分けるのは、-p で別ポートを選んだ
    hiraku を「別の世界」にするため (窓口が他ポートの対象まで配信しない)。"""
    base = os.environ.get("XDG_RUNTIME_DIR")
    if not base or not os.path.isdir(base):
        # /tmp は他人と共有なので、自分のものだと確かめてから使う
        base = os.path.join("/tmp", "hiraku-%d" % os.getuid())
        os.makedirs(base, mode=0o700, exist_ok=True)
        st = os.lstat(base)
        if not os.path.isdir(base) or st.st_uid != os.getuid() or os.path.islink(base):
            raise SystemExit("%s が使えない (自分のディレクトリではない)" % base)
    path = os.path.join(base, "hiraku", str(port))
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def proc_starttime(pid):
    """/proc/<pid>/stat の 22 番目 (プロセスの起動時刻)。pid の使い回しで
    死んだセッションを生きていると誤認しないための照合用。"""
    try:
        with open("/proc/%d/stat" % pid, "rb") as f:
            data = f.read()
    except OSError:
        return None
    try:
        # comm には空白も ')' も入りうるので最後の ')' から切る
        return int(data[data.rindex(b")") + 2:].split()[19])
    except (ValueError, IndexError):
        return None


def scan_sessions():
    """状態ファイルを読んで、生きているセッションだけを返す。

    死んでいるものはここで消す。持ち主が Ctrl-C で終われば自分で片付けるが、
    SIGKILL されると残るため、読んだ側が掃除する役目も持たせている。
    """
    found = {}
    try:
        names = os.listdir(STATE_DIR)
    except OSError:
        return found
    for name in names:
        if not name.endswith(".json"):
            continue
        path = os.path.join(STATE_DIR, name)
        try:
            with open(path, "rb") as f:
                rec = json.loads(f.read().decode("utf-8"))
            pid, started = int(rec["pid"]), int(rec["started"])
        except (OSError, ValueError, KeyError, TypeError):
            continue
        if proc_starttime(pid) != started:
            try:
                os.unlink(path)
            except OSError:
                pass
            continue
        found[rec["slug"]] = rec
    return found


def sessions():
    """scan_sessions() を 0.3 秒だけ使い回す。1 リクエストで何度も呼ぶので。"""
    global _sessions_cache
    now = time.monotonic()
    with _sessions_lock:
        cached, at = _sessions_cache
        if now - at < 0.3:
            return cached
    fresh = scan_sessions()
    with _sessions_lock:
        _sessions_cache = (fresh, now)
    return fresh


def forget_sessions_cache():
    global _sessions_cache
    with _sessions_lock:
        _sessions_cache = ({}, 0.0)


def slug_for(roots):
    """対象からセッションのスラグを決める。

    「読める名前 + パスのハッシュ」。ハッシュにするのは、同じ対象を開けば
    毎回同じ URL になってブックマークできるようにするため。読める名前を
    前に付けるのは、一覧やブラウザの履歴で見分けられるようにするため。
    """
    paths = sorted(roots.values())
    digest = hashlib.sha256("\0".join(paths).encode("utf-8")).hexdigest()[:6]
    base = os.path.basename(paths[0].rstrip("/")) or "root"
    base = "".join(c if c.isalnum() or c in "._-" else "-" for c in base)[:24]
    return "%s-%s" % (base.strip("-.") or "root", digest)


def register(roots, initial):
    """自分のセッションを状態ファイルに置き、使ったスラグを返す。

    同じ対象を 2 つ同時に開いたときだけスラグが埋まっているので、その場合は
    -2, -3 と後ろに足す。
    """
    base = slug_for(roots)
    live = scan_sessions()
    for n in range(1, 100):
        slug = base if n == 1 else "%s-%d" % (base, n)
        if slug in live:
            continue
        rec = {
            "slug": slug,
            "pid": os.getpid(),
            "started": proc_starttime(os.getpid()),
            "roots": roots,
            "initial": initial,
        }
        path = os.path.join(STATE_DIR, slug + ".json")
        tmp = "%s.%d.tmp" % (path, os.getpid())
        # 書きかけを他プロセスに読ませないよう rename で差し替える
        with open(tmp, "wb") as f:
            f.write(json.dumps(rec, ensure_ascii=False).encode("utf-8"))
        os.replace(tmp, path)
        forget_sessions_cache()
        return slug
    raise SystemExit("同じ対象のセッションが多すぎる")


def unregister(slug):
    """自分の状態ファイルを消す。終了した瞬間にブラウザから見えなくなる。"""
    path = os.path.join(STATE_DIR, slug + ".json")
    try:
        with open(path, "rb") as f:
            rec = json.loads(f.read().decode("utf-8"))
        if int(rec.get("pid", -1)) != os.getpid():
            return  # 取り違え防止 (自分のでなければ触らない)
        os.unlink(path)
    except (OSError, ValueError):
        pass


# ─────────────────────────── パスの解決 ───────────────────────────

def kind_of(name):
    return EXT_KIND.get(os.path.splitext(name)[1].lower())


def skip(name):
    return name.startswith(".") or name in SKIP_DIRS


def resolve(roots, vpath):
    """仮想パス "対象/a/b.md" を絶対パスにする。対象の外なら None。

    realpath したうえで root 配下かを確かめる。symlink を踏んで
    配信対象の外に出る URL を弾くため (届く経路は SSH トンネルだけとはいえ、
    見せるつもりのないファイルを読ませない)。
    """
    parts = [p for p in vpath.split("/") if p not in ("", ".")]
    if not parts:
        return None
    root = roots.get(parts[0])
    if root is None or ".." in parts:
        return None
    target = os.path.realpath(os.path.join(root, *parts[1:]))
    if target != root and not target.startswith(root + os.sep):
        return None
    return target


def dir_has_match(path, want, depth=0):
    """path 配下に want に合うファイルが 1 つでもあるか (見つかり次第打ち切る)。

    フィルタで空になったディレクトリをツリーに出さないための判定。
    深さを打ち切るのは symlink ループと極端に深い木への保険。
    """
    if depth > 24:
        return True
    try:
        subdirs = []
        with os.scandir(path) as it:
            for e in it:
                if skip(e.name):
                    continue
                if e.is_dir(follow_symlinks=False):
                    subdirs.append(e.path)
                elif e.is_file():
                    k = kind_of(e.name)
                    if k and k in want:
                        return True
    except OSError:
        return False
    return any(dir_has_match(d, want, depth + 1) for d in subdirs)


def list_dir(roots, vdir, want):
    """vdir 直下のエントリを [ディレクトリ..., ファイル...] の順で返す。"""
    target = resolve(roots, vdir)
    if target is None or not os.path.isdir(target):
        return None
    dirs, files = [], []
    try:
        with os.scandir(target) as it:
            for e in it:
                if skip(e.name):
                    continue
                vpath = vdir.rstrip("/") + "/" + e.name
                if e.is_dir(follow_symlinks=False):
                    if dir_has_match(e.path, want):
                        dirs.append({"name": e.name, "path": vpath, "type": "dir"})
                elif e.is_file():
                    k = kind_of(e.name)
                    if k and k in want:
                        files.append({"name": e.name, "path": vpath, "type": "file", "kind": k})
    except OSError:
        return None
    key = lambda e: e["name"].lower()
    return sorted(dirs, key=key) + sorted(files, key=key)


# ─────────────────────────── 変更の監視 ───────────────────────────

def snapshot(live):
    """生きている全セッションの (スラグ, 仮想パス) -> mtime,size を集める。

    inotify を使わないのは、依存を増やさずに済ませるため。対象は
    ドキュメントのディレクトリ程度を想定していて、0.7 秒ごとの走査で足りる。

    第 2 の戻り値は「上限で打ち切ったか」。打ち切ると集めきれなかったぶんが
    消えたように見えるので、呼び出し側で削除の扱いを変える。
    """
    snap = {}
    budget = WATCH_MAX_ENTRIES
    for slug, sess in live.items():
        for rslug, root in sess["roots"].items():
            stack = [(root, rslug)]
            while stack and budget > 0:
                path, vpath = stack.pop()
                try:
                    with os.scandir(path) as it:
                        for e in it:
                            if skip(e.name):
                                continue
                            budget -= 1
                            if budget <= 0:
                                break
                            child = vpath + "/" + e.name
                            if e.is_dir(follow_symlinks=False):
                                snap[(slug, child)] = "d"
                                stack.append((e.path, child))
                            elif e.is_file() and kind_of(e.name):
                                st = e.stat()
                                snap[(slug, child)] = (st.st_mtime_ns, st.st_size)
                except OSError:
                    continue
    return snap, budget <= 0


def broadcast(slug, payload):
    """1 セッションのクライアントにだけ送る。他のセッションの更新で
    関係のないブラウザが読み直さないように。"""
    data = json.dumps(payload, ensure_ascii=False)
    with CLIENTS_LOCK:
        targets = [q for s, q in CLIENTS if s == slug]
    for q in targets:
        q.put(data)


def watch():
    live = sessions()
    prev, truncated = snapshot(live)
    if truncated:
        print("対象が大きすぎるので変更の監視を一部だけにする "
              "(見えていないファイルの更新は反映されない)", file=sys.stderr)
    known = set(live)
    while True:
        time.sleep(WATCH_INTERVAL)
        forget_sessions_cache()
        live = sessions()
        # 終わったセッションのブラウザには「終わった」と伝える。黙って
        # 404 を返すだけだと、なぜ見えなくなったのか分からない
        for slug in known - set(live):
            broadcast(slug, {"gone": True})
        known = set(live)
        cur, truncated = snapshot(live)
        if cur == prev:
            continue
        changed = [p for p in cur if prev.get(p) != cur[p]]
        # 打ち切ったときの「消えた」は走査が届かなかっただけのことがあるので
        # 削除として扱わない (毎回ツリーを作り直してしまう)
        removed = [] if truncated else [p for p in prev if p not in cur]
        news = {p for p in changed if prev.get(p) is None}
        prev = cur
        by_slug = {}
        for slug, vpath in changed + removed:
            entry = by_slug.setdefault(slug, {"changed": [], "structure": False})
            entry["changed"].append(vpath)
        for slug, vpath in removed:
            by_slug[slug]["structure"] = True
        for slug, vpath in news:
            by_slug[slug]["structure"] = True
        for slug, payload in by_slug.items():
            # ファイルの増減はツリーの作り直しが要る。中身だけの変更なら
            # 開いているファイルの再読み込みで済む
            broadcast(slug, payload)


# ─────────────────────────── 変換と配信 ───────────────────────────

def render_md(path):
    """markdown を pandoc で HTML にする。失敗しても画面に理由を出す。

    --embed-resources は使わない。ページ自身が
    /<スラグ>/view/<対象>/<ディレクトリ>/ という URL で配信されるので、
    相対パスの画像や CSS はブラウザが同じサーバーに取りに来て解決できる
    (他の md へのリンクもそのまま辿れる)。
    """
    try:
        proc = subprocess.run(
            [
                "pandoc", "-s", "-f", "gfm", "-t", "html5",
                "--css", "/hiraku.css",
                "--metadata", "title=" + os.path.basename(path),
                "-o", "-", os.path.basename(path),
            ],
            cwd=os.path.dirname(path) or ".",
            capture_output=True,
        )
    except OSError as e:
        return error_page("pandoc を実行できない", str(e))
    if proc.returncode != 0:
        return error_page("変換に失敗した", proc.stderr.decode("utf-8", "replace"))
    return proc.stdout


def error_page(title, detail):
    """変換できなかった理由をプレビュー枠の中に出す。

    接続を切って白紙にすると原因が分からないので、常に HTML を返す。
    """
    body = (
        '<!doctype html><meta charset="utf-8">'
        '<link rel="stylesheet" href="/hiraku.css">'
        "<h1>" + escape(title) + "</h1><pre>" + escape(detail) + "</pre>"
    )
    return body.encode("utf-8")


def escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def content_type(path):
    ctype, _ = mimetypes.guess_type(path)
    if ctype is None:
        return "application/octet-stream"
    if ctype.startswith("text/") or ctype in ("image/svg+xml", "application/javascript"):
        return ctype + "; charset=utf-8"
    return ctype


class Handler(BaseHTTPRequestHandler):
    server_version = SERVER_NAME
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass  # アクセスログは端末を汚すだけなので出さない

    def do_GET(self):
        self.guarded(head_only=False)

    def do_HEAD(self):
        self.guarded(head_only=True)

    def guarded(self, head_only):
        """予期しない例外で無言のまま切断しない (原因が分からなくなるため)。"""
        try:
            self.route(head_only)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as e:  # noqa: BLE001
            try:
                self.fail(500, "hiraku 内部エラー: %r" % (e,))
            except OSError:
                pass

    def route(self, head_only):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)
        query = parse_qs(parsed.query)

        # ── セッションをまたぐ URL ──
        if path == "/hiraku.css":
            return self.send_asset("css", "text/css; charset=utf-8", head_only)
        if path == "/api/sessions":
            return self.send_json({"sessions": [
                {"slug": s,
                 "name": " / ".join(os.path.basename(p) or p for p in r["roots"].values()),
                 "paths": sorted(r["roots"].values()),
                 "initial": r["initial"]}
                for s, r in sorted(sessions().items())
            ]}, head_only)
        if path == "/":
            live = sessions()
            # 1 つしか動いていないなら選ばせる意味がないので直行する
            # (localhost:4649 を開くだけ、という今までの手癖を残すため)
            if len(live) == 1:
                return self.redirect("/%s/" % quote(next(iter(live))))
            return self.send_asset("index", "text/html; charset=utf-8", head_only)

        # ── セッション配下 ──
        slug, _, rest = path.lstrip("/").partition("/")
        sess = sessions().get(slug)
        if sess is None:
            return self.fail(404, "そのプレビューは終わっている: /%s/" % slug)
        rest = "/" + rest
        if rest == "/":
            if not path.endswith("/"):
                # 相対 URL の起点をセッションに揃えるため必ず / で終わらせる
                return self.redirect("/%s/" % quote(slug))
            return self.send_asset("app", "text/html; charset=utf-8", head_only)
        if rest == "/player.html":
            return self.send_asset("player", "text/html; charset=utf-8", head_only)
        if rest == "/image.html":
            return self.send_asset("image", "text/html; charset=utf-8", head_only)
        if rest == "/api/roots":
            return self.send_json({
                "slug": slug,
                "roots": [{"slug": s, "name": os.path.basename(p) or p, "path": p}
                          for s, p in sess["roots"].items()],
                "initial": sess["initial"],
            }, head_only)
        if rest == "/api/tree":
            return self.api_tree(sess, query, head_only)
        if rest == "/api/events":
            return self.api_events(slug, head_only)
        if rest.startswith("/view/"):
            return self.view(sess, rest[len("/view/"):], head_only)
        self.fail(404, "not found")

    # ── API ──

    def api_tree(self, sess, query, head_only):
        roots = sess["roots"]
        want = query.get("filter", ["all"])[0]
        want = ALL_KINDS if want == "all" else frozenset({want} & ALL_KINDS)
        vdir = query.get("path", [""])[0].strip("/")
        if not vdir:
            # 空指定は対象そのものの一覧。対象が 1 つならその中身を返して、
            # ルートのノードを 1 段はさまずに済ませる
            if len(roots) == 1:
                entries = list_dir(roots, next(iter(roots)), want)
            else:
                entries = [{"name": os.path.basename(p) or p, "path": s, "type": "dir"}
                           for s, p in roots.items()]
            return self.send_json({"entries": entries or []}, head_only)
        entries = list_dir(roots, vdir, want)
        if entries is None:
            return self.fail(404, "no such directory")
        self.send_json({"entries": entries}, head_only)

    def api_events(self, slug, head_only):
        if head_only:
            return self.fail(405, "GET only")
        q = queue.Queue()
        client = (slug, q)
        with CLIENTS_LOCK:
            CLIENTS.add(client)
        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b": hello\n\n")
            self.wfile.flush()
            while True:
                try:
                    data = q.get(timeout=15)
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")  # 中間のプロキシに切られないように
                else:
                    self.wfile.write(b"data: " + data.encode("utf-8") + b"\n\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ValueError, OSError):
            pass
        finally:
            with CLIENTS_LOCK:
                CLIENTS.discard(client)
            self.close_connection = True

    # ── 実ファイル ──

    def view(self, sess, vpath, head_only):
        target = resolve(sess["roots"], vpath.strip("/"))
        if target is None or not os.path.isfile(target):
            return self.fail(404, "no such file")
        if kind_of(target) == "md":
            body = render_md(target)
            # 保存のたびに中身が変わるのでキャッシュさせない
            return self.send_bytes(body, "text/html; charset=utf-8", head_only,
                                   extra={"Cache-Control": "no-store"})
        return self.send_file(target, head_only)

    def send_file(self, target, head_only):
        try:
            size = os.path.getsize(target)
            f = open(target, "rb")
        except OSError:
            return self.fail(404, "no such file")
        with f:
            ctype = content_type(target)
            # 音声と PDF は部分取得を投げてくるブラウザがあるので Range に答える
            start, end = 0, size - 1
            rng = self.headers.get("Range")
            partial = False
            if rng and rng.startswith("bytes=") and size:
                spec = rng[len("bytes="):].split(",")[0]
                lo, _, hi = spec.partition("-")
                try:
                    if lo:
                        start = int(lo)
                        end = int(hi) if hi else size - 1
                    elif hi:
                        start = max(0, size - int(hi))
                    partial = 0 <= start <= end < size
                except ValueError:
                    partial = False
                if not partial:
                    start, end = 0, size - 1
            length = end - start + 1
            self.send_response(206 if partial else 200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(length))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-store")
            if partial:
                self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
            self.end_headers()
            if head_only:
                return
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    # ── 返信の下請け ──

    def redirect(self, location):
        self.send_response(303)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def send_asset(self, key, ctype, head_only):
        with open(ASSETS[key], "rb") as f:
            self.send_bytes(f.read(), ctype, head_only)

    def send_json(self, obj, head_only):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_bytes(body, "application/json; charset=utf-8", head_only,
                        extra={"Cache-Control": "no-store"})

    def send_bytes(self, body, ctype, head_only, extra=None):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if not head_only:
            self.wfile.write(body)

    def fail(self, code, message):
        body = message.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# ─────────────────────────── 窓口の受け渡し ───────────────────────────

def try_bind(port):
    """ポートを掴めたら HTTP サーバーを返す。埋まっていたら None。

    SO_REUSEADDR は TIME_WAIT を跨ぐためのもので、待ち受け中のプロセスが
    いれば bind は失敗する。この失敗をそのまま「窓口は他にいる」の判定に使う。
    """
    ThreadingHTTPServer.allow_reuse_address = True
    ThreadingHTTPServer.daemon_threads = True  # SSE 接続が残っていても終了できるように
    try:
        return ThreadingHTTPServer(("127.0.0.1", port), Handler)
    except OSError as e:
        if e.errno in (errno.EADDRINUSE, errno.EACCES):
            return None
        raise


def is_hiraku(port):
    """埋まっているポートの相手が hiraku かどうか。

    無関係なプロセスが 4649 を使っているとき、黙って待ち続けると
    「開いたのに何も見えない」になるので、起動時に 1 度だけ確かめる。
    """
    try:
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=1.5)
        try:
            conn.request("HEAD", "/api/sessions")
            resp = conn.getresponse()
            resp.read()
            return SERVER_NAME in (resp.getheader("Server") or "")
        finally:
            conn.close()
    except (OSError, http.client.HTTPException, socket.timeout):
        return False


def serve(port, httpd=None):
    """ポートが空くまで待ち、掴めたら窓口として配信し続ける。

    窓口が Ctrl-C で落ちても、待っていたプロセスが引き継ぐので
    「他のセッションまで道連れで見えなくなる」ことがない。httpd を渡せる
    のは、起動時に掴めたソケットを閉じずにそのまま使うため (閉じてから
    掴み直すと、その隙に別のプロセスに取られる)。
    """
    watching = False
    while True:
        if httpd is None:
            httpd = try_bind(port)
        if httpd is None:
            time.sleep(TAKEOVER_INTERVAL)
            continue
        if not watching:
            threading.Thread(target=watch, daemon=True).start()
            watching = True
        httpd.serve_forever()


# ─────────────────────────── 起動 ───────────────────────────

def make_slug(path, used):
    base = os.path.basename(path.rstrip("/")) or "root"
    slug = "".join(c if c.isalnum() or c in "._-" else "-" for c in base)
    candidate, n = slug, 2
    while candidate in used:
        candidate = "%s-%d" % (slug, n)
        n += 1
    return candidate


def collect_targets(targets):
    """引数から (対象スラグ -> 絶対パス, 最初に開く仮想パス) を作る。"""
    roots, initial = {}, None
    for target in targets:
        target = os.path.realpath(target)
        if os.path.isdir(target):
            root, rel = target, None
        else:
            # ファイルを渡された場合は親ディレクトリを対象にして、その
            # ファイルを開いた状態で始める。隣のファイルへも移れる方が
            # 「ディレクトリを開き直す」より手数が少ない
            root, rel = os.path.dirname(target), os.path.basename(target)
        slug = next((s for s, p in roots.items() if p == root), None)
        if slug is None:
            slug = make_slug(root, roots)
            roots[slug] = root
        if rel and initial is None:
            initial = slug + "/" + rel
    return roots, initial


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--asset", action="append", default=[], metavar="KEY=PATH")
    ap.add_argument("targets", nargs="+")
    opts = ap.parse_args()

    for item in opts.asset:
        key, _, path = item.partition("=")
        ASSETS[key] = path

    global STATE_DIR
    STATE_DIR = state_dir_for(opts.port)

    roots, initial = collect_targets(opts.targets)

    if shutil.which("pandoc") is None:
        print("pandoc が見つからない (markdown の変換ができない)", file=sys.stderr)

    # 窓口が他プロセスでも URL は同じなので、先に登録して URL を出す
    slug = register(roots, initial)
    try:
        httpd = try_bind(opts.port)
        if httpd is None and not is_hiraku(opts.port):
            print("ポート %d を hiraku 以外が使っている (-p で変えられる)" % opts.port,
                  file=sys.stderr)
            return 1

        url = "http://localhost:%d/%s/" % (opts.port, slug)
        if initial:
            url += "#" + quote(initial)
        print("ローカルのブラウザで開く: " + url)
        for rslug, root in roots.items():
            print("  %s  →  %s" % (rslug, root))
        print("Ctrl-C で終了する (終了したらブラウザからは見えなくなる)")
        sys.stdout.flush()

        signal.signal(signal.SIGINT, signal.default_int_handler)
        try:
            serve(opts.port, httpd)
        except KeyboardInterrupt:
            print("\n終了した")
        return 0
    finally:
        unregister(slug)


if __name__ == "__main__":
    sys.exit(main())
