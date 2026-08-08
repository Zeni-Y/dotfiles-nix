# markdown / HTML プレビュー (`preview`)

リモート (このマシン) にある markdown / HTML を、手元のブラウザ (Chrome など) で見るための
コマンド。実装は `home/cli/preview.nix`。

## 1. 全体像

```
リモート                                              ローカル
────────────────────────────────────                  ────────────────────────
a.md   ──pandoc──▶  ~/.cache/preview/a.md-3f2a/       http://localhost:4649/a.md-3f2a/
b.md   ──pandoc──▶  ~/.cache/preview/b.md-9c1e/       http://localhost:4649/b.md-9c1e/
site/  ◀─symlink─   ~/.cache/preview/site-8d2c        http://localhost:4649/site-8d2c/...
                          │
                  python http.server ◀── SSH トンネル ── ブラウザ (一覧は /)
                  (127.0.0.1:4649、1 個だけ常駐)
```

- 変換も配信もリモートで完結する (pandoc + entr + python http.server、完全オフライン)。
- **サーバーは 1 個だけ常駐**し、ファイルごとに `/<スラグ>/` のサブパスを割り当てる。
  複数ファイルを同時にプレビューしてもポートは増えず、LocalForward は 1 行で済む。
  トップ (`/`) は登録済みプレビューの一覧ページ。
- HTTP サーバーは **127.0.0.1 にしか束縛しない**。LAN には公開されず、
  届く経路は SSH の LocalForward だけ。

## 2. 事前準備 (ローカル側、初回のみ)

ローカルマシンの `~/.ssh/config` で、このリモートのエントリにポート転送を足す:

```
Host <このリモート>
    LocalForward 4649 localhost:4649
```

接続済みのセッションには効かないので、設定後に SSH を張り直す。
その場しのぎなら `ssh -L 4649:localhost:4649 <host>` でもよい。

## 3. 使い方

```bash
preview README.md            # 変換して登録。表示された URL をローカルのブラウザで開く
preview -r 2 README.md       # ブラウザを 2 秒ごとに自動リロードさせる
preview site/index.html      # HTML はそのまま配信 (相対パスの画像も生きる)
preview -l                   # 登録済みプレビューの一覧 (URL と元ファイル)
preview -s                   # サーバーを停止する
```

- 初回の `preview` がサーバーを自動起動する。2 個目以降のファイルは同じサーバーに
  相乗りするので、**ポートはずっと 4649 のまま**。URL の一覧は `preview -l` か
  ブラウザで `http://localhost:4649/` を見る。
- markdown は保存するたびに entr が変換し直すので、ブラウザはリロードするだけでよい。
  `-r 秒` を付ければリロードも自動になる (スクロール位置が飛ぶので既定は手動)。
  **Ctrl-C で止まるのはこの監視だけ**で、サーバーと他のプレビューは残る。
- 変換結果は `~/.cache/preview/` に置かれ、元ファイルのディレクトリは汚さない。
  登録はサーバーを止めても残る。全部消すなら `rm -rf ~/.cache/preview`。
- `-p PORT` でポートを変えられるが、サーバーが既に稼働中ならそちらの
  ポートが優先される (1 サーバー方針のため)。LocalForward 側も合わせること。

## 4. 設計判断

- **1 サーバー・1 ポートに集約する**。1 起動 = 1 ポートの素朴な作りだと、複数ファイルの
  同時プレビューでポートが増え、ローカル側の LocalForward をその都度足すことになる
  (SSH の設定にポート範囲の構文は無く、範囲ぶん列挙するしかない)。ファイルは
  `/<ファイル名>-<パスのハッシュ>/` のサブパスで分ける。ハッシュを足すのは
  別リポジトリの README.md 同士のような同名ファイルの衝突を避けるため。
- **サーバーは setsid で呼び出し元から切り離す**。nohup では足りない: md の監視 (entr) を
  Ctrl-C で止めるとき、同じプロセスグループに居るとサーバーまで SIGINT で道連れになる。
- **レンダラは pandoc (gfm 入力)**。grip は GitHub API 依存 (オフライン不可・レート制限)
  なので不採用。
- **相対パスの画像は `--embed-resources` で HTML に埋め込む**。配信対象が 1 ファイルに
  収まり、画像のパス解決をサーバー側で考えずに済む。
- **ポート既定値は 4649**。well-known / ephemeral を避けた覚えやすい値で、
  ローカル側の LocalForward を固定で書いておける。
- HTML 入力の場合は変換せず、そのファイルのディレクトリごと symlink で配信ルートに
  載せる (HTML が相対パスで参照する画像・CSS を生かすため。実体はコピーしない)。

## 5. 検討した代替案: ターミナル内プレビュー (Kitty graphics)

2026-08-08 に検証した記録。herdr 0.7.5 + WezTerm の組み合わせで、
HTML を headless Chromium で画像化しペイン内に描画する案。
**動くことは実証済みだが、静止画のためテキスト選択・コピーができず不採用**。
リンクも踏めず、依存 (chromium + フォント数百 MB) も重い。

### 検証で分かったこと

前提の設定 (適用済み・無害なので残してある):

- herdr: `experimental.kitty_graphics = true` (`home/herdr.nix`)
- WezTerm: `enable_kitty_graphics = true` (`home/wezterm.nix`、デフォルト false)

herdr 0.7.5 の Kitty graphics 実装の実測:

| 項目 | 結果 |
| --- | --- |
| 生 RGB (`f=24`) | ✅ 通る |
| PNG (`f=100`) | ❌ `EINVAL: unsupported format` |
| チャンク転送 (`m=1`/`m=0`) | ✅ 1720 チャンク 7MB でも通る |
| ピクセルジオメトリ報告 (CSI 14t/16t/18t) | ❌ 無応答 |

- herdr は外側ターミナルの実セルサイズを知らないため、中継時に仮のセルサイズで
  スケールし、素朴に送ると**大きく粗く**表示される (herdr 無しの素の SSH なら綺麗)。
- 回避策は成立する: 外側ターミナルの実セルサイズ (WezTerm で 17x37px) を herdr の外で
  CSI 16t で測って控えておき、**セル数 x 実セルサイズぴったりの解像度でレンダリングして
  `c=`/`r=` を明示**すれば、herdr 内でも等倍で綺麗に表示できる (実証済み)。
- HTML → 画像化はフォントの無いヘッドレス環境だと文字が全部消える。
  `FONTCONFIG_FILE` で nix store のフォント (dejavu / Noto CJK) を指す fonts.conf を
  渡す必要がある。
- ターミナル内ブラウザ [terminal-browser](https://terminal-browser.com/) も検討したが、
  配布バイナリが Apple Silicon macOS のみで Linux では動かず除外。

herdr の実装が成熟して (PNG 対応・ジオメトリ報告・実セルサイズでの中継)
画質問題が解消しても、静止画である制約は残る。再評価するならテキスト選択まで
できる仕組み (terminal-browser の Linux 対応など) が出てきたとき。
