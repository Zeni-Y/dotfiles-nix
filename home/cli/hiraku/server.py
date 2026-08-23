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

URL の構成:
    /                       2 ペインのアプリ本体 (app.html)
    /hiraku.css             pandoc 出力に当てる CSS
    /player.html            音声プレーヤー
    /api/roots              対象一覧と初期選択
    /api/tree?path=&filter= 1 階層ぶんのツリー (遅延展開用)
    /api/events             変更通知 (SSE)
    /view/<スラグ>/<相対パス>  md は変換して、それ以外は実体を配信
"""

import argparse
import json
import mimetypes
import os
import queue
import shutil
import signal
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

ROOTS = {}          # スラグ -> 絶対パス (realpath 済み)
INITIAL = None      # 起動時に開いておく仮想パス ("スラグ/相対パス") か None
ASSETS = {}         # 静的ファイルの実体パス
CLIENTS = set()     # SSE クライアントの Queue
CLIENTS_LOCK = threading.Lock()


# ─────────────────────────── パスの解決 ───────────────────────────

def kind_of(name):
    return EXT_KIND.get(os.path.splitext(name)[1].lower())


def skip(name):
    return name.startswith(".") or name in SKIP_DIRS


def resolve(vpath):
    """仮想パス "スラグ/a/b.md" を絶対パスにする。対象の外なら None。

    realpath したうえで root 配下かを確かめる。symlink を踏んで
    配信対象の外に出る URL を弾くため (届く経路は SSH トンネルだけとはいえ、
    見せるつもりのないファイルを読ませない)。
    """
    parts = [p for p in vpath.split("/") if p not in ("", ".")]
    if not parts:
        return None
    root = ROOTS.get(parts[0])
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


def list_dir(vdir, want):
    """vdir 直下のエントリを [ディレクトリ..., ファイル...] の順で返す。"""
    target = resolve(vdir)
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

def snapshot():
    """配信対象の (仮想パス -> mtime,size) を集める。差分が変更通知になる。

    inotify を使わないのは、依存を増やさずに済ませるため。対象は
    ドキュメントのディレクトリ程度を想定していて、0.7 秒ごとの走査で足りる。

    第 2 の戻り値は「上限で打ち切ったか」。打ち切ると集めきれなかったぶんが
    消えたように見えるので、呼び出し側で削除の扱いを変える。
    """
    snap = {}
    budget = WATCH_MAX_ENTRIES
    for slug, root in ROOTS.items():
        stack = [(root, slug)]
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
                            snap[child] = "d"
                            stack.append((e.path, child))
                        elif e.is_file() and kind_of(e.name):
                            st = e.stat()
                            snap[child] = (st.st_mtime_ns, st.st_size)
            except OSError:
                continue
    return snap, budget <= 0


def broadcast(payload):
    data = json.dumps(payload, ensure_ascii=False)
    with CLIENTS_LOCK:
        targets = list(CLIENTS)
    for q in targets:
        q.put(data)


def watch():
    prev, truncated = snapshot()
    if truncated:
        print("対象が大きすぎるので変更の監視を一部だけにする "
              "(見えていないファイルの更新は反映されない)", file=sys.stderr)
    while True:
        time.sleep(WATCH_INTERVAL)
        cur, truncated = snapshot()
        if cur == prev:
            continue
        changed = [p for p in cur if prev.get(p) != cur[p]]
        # 打ち切ったときの「消えた」は走査が届かなかっただけのことがあるので
        # 削除として扱わない (毎回ツリーを作り直してしまう)
        removed = [] if truncated else [p for p in prev if p not in cur]
        # ファイルの増減はツリーの作り直しが要る。中身だけの変更なら
        # 開いているファイルの再読み込みで済む
        structure = bool(removed) or any(prev.get(p) is None for p in changed)
        prev = cur
        if changed or removed:
            broadcast({"changed": changed + removed, "structure": structure})


# ─────────────────────────── 変換と配信 ───────────────────────────

def render_md(path):
    """markdown を pandoc で HTML にする。失敗しても画面に理由を出す。

    --embed-resources は使わない。ページ自身が /view/<スラグ>/<ディレクトリ>/
    という URL で配信されるので、相対パスの画像や CSS はブラウザが同じ
    サーバーに取りに来て解決できる (他の md へのリンクもそのまま辿れる)。
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
    server_version = "hiraku"
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

        if path == "/":
            return self.send_asset("app", "text/html; charset=utf-8", head_only)
        if path == "/hiraku.css":
            return self.send_asset("css", "text/css; charset=utf-8", head_only)
        if path == "/player.html":
            return self.send_asset("player", "text/html; charset=utf-8", head_only)
        if path == "/api/roots":
            return self.send_json({
                "roots": [{"slug": s, "name": os.path.basename(p) or p, "path": p}
                          for s, p in ROOTS.items()],
                "initial": INITIAL,
            }, head_only)
        if path == "/api/tree":
            return self.api_tree(query, head_only)
        if path == "/api/events":
            return self.api_events(head_only)
        if path.startswith("/view/"):
            return self.view(path[len("/view/"):], head_only)
        self.fail(404, "not found")

    # ── API ──

    def api_tree(self, query, head_only):
        want = query.get("filter", ["all"])[0]
        want = ALL_KINDS if want == "all" else frozenset({want} & ALL_KINDS)
        vdir = query.get("path", [""])[0].strip("/")
        if not vdir:
            # 空指定は対象そのものの一覧。対象が 1 つならその中身を返して、
            # ルートのノードを 1 段はさまずに済ませる
            if len(ROOTS) == 1:
                slug = next(iter(ROOTS))
                entries = list_dir(slug, want)
            else:
                entries = [{"name": os.path.basename(p) or p, "path": s, "type": "dir"}
                           for s, p in ROOTS.items()]
            return self.send_json({"entries": entries or []}, head_only)
        entries = list_dir(vdir, want)
        if entries is None:
            return self.fail(404, "no such directory")
        self.send_json({"entries": entries}, head_only)

    def api_events(self, head_only):
        if head_only:
            return self.fail(405, "GET only")
        q = queue.Queue()
        with CLIENTS_LOCK:
            CLIENTS.add(q)
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
                CLIENTS.discard(q)
            self.close_connection = True

    # ── 実ファイル ──

    def view(self, vpath, head_only):
        target = resolve(vpath.strip("/"))
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


# ─────────────────────────── 起動 ───────────────────────────

def make_slug(path, used):
    base = os.path.basename(path.rstrip("/")) or "root"
    slug = "".join(c if c.isalnum() or c in "._-" else "-" for c in base)
    candidate, n = slug, 2
    while candidate in used:
        candidate = "%s-%d" % (slug, n)
        n += 1
    return candidate


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--asset", action="append", default=[], metavar="KEY=PATH")
    ap.add_argument("targets", nargs="+")
    opts = ap.parse_args()

    for item in opts.asset:
        key, _, path = item.partition("=")
        ASSETS[key] = path

    global INITIAL
    for target in opts.targets:
        target = os.path.realpath(target)
        if os.path.isdir(target):
            root = target
            rel = None
        else:
            # ファイルを渡された場合は親ディレクトリを対象にして、その
            # ファイルを開いた状態で始める。隣のファイルへも移れる方が
            # 「ディレクトリを開き直す」より手数が少ない
            root, rel = os.path.dirname(target), os.path.basename(target)
        slug = next((s for s, p in ROOTS.items() if p == root), None)
        if slug is None:
            slug = make_slug(root, ROOTS)
            ROOTS[slug] = root
        if rel and INITIAL is None:
            INITIAL = slug + "/" + rel

    if shutil.which("pandoc") is None:
        print("pandoc が見つからない (markdown の変換ができない)", file=sys.stderr)

    ThreadingHTTPServer.allow_reuse_address = True
    ThreadingHTTPServer.daemon_threads = True  # SSE 接続が残っていても終了できるように
    try:
        httpd = ThreadingHTTPServer(("127.0.0.1", opts.port), Handler)
    except OSError as e:
        print("ポート %d を開けない: %s" % (opts.port, e), file=sys.stderr)
        print("別の hiraku が動いているかもしれない (-p で変えられる)", file=sys.stderr)
        return 1

    threading.Thread(target=watch, daemon=True).start()

    url = "http://localhost:%d/" % opts.port
    if INITIAL:
        url += "#" + quote(INITIAL)
    print("ローカルのブラウザで開く: " + url)
    for slug, root in ROOTS.items():
        print("  %s  →  %s" % (slug, root))
    print("Ctrl-C で終了する (終了したらブラウザからは見えなくなる)")
    sys.stdout.flush()

    signal.signal(signal.SIGINT, signal.default_int_handler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n終了した")
    return 0


if __name__ == "__main__":
    sys.exit(main())
