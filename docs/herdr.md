# herdr — 使い方とライフサイクル

ターミナルマルチプレクサとして [herdr](https://herdr.dev/) を使っています
(以前の tmux / zellij の置き換え)。設定は `home/herdr.nix` に書き、
Home Manager が `~/.config/herdr/config.toml` を生成します。

> このドキュメントは herdr **0.7.5** 時点の挙動をもとに書いています。
> `herdr --default-config` / `herdr <subcommand> --help` が一次情報です。

---

## 目次

1. [herdr の考え方](#1-herdr-の考え方)
2. [用語と階層](#2-用語と階層)
3. [起動・デタッチ・終了 (ランタイムのライフサイクル)](#3-起動デタッチ終了-ランタイムのライフサイクル)
4. [基本操作 (キーバインド)](#4-基本操作-キーバインド)
5. [このリポジトリの設定](#5-このリポジトリの設定)
6. [設定変更のライフサイクル](#6-設定変更のライフサイクル)
7. [CLI から操作する](#7-cli-から操作する)
8. [ハマりどころ](#8-ハマりどころ)

---

## 1. herdr の考え方

tmux と同じく **サーバ / クライアント型**です。ターミナル (WezTerm など) を閉じても
サーバ側にセッションが残り、後から `herdr` で繋ぎ直せます。

tmux との一番の違いは、**セッションの永続化・復元が本体機能**である点です。
tmux でいう `resurrect` / `continuum` 相当が組み込みなので、プラグインを入れる必要が
ありません。さらに AI コーディングエージェント (Claude Code など) のペインを
検出してサイドバーに状態表示する、という方向に振った作りになっています。

```
WezTerm (アウターターミナル)
└── herdr クライアント        ← 表示と入力だけを担当。閉じても中身は死なない
      │  (Unix socket: ~/.config/herdr/herdr.sock)
      └── herdr サーバ         ← ペインの PTY・スクロールバック・レイアウトを保持
            └── fish / nvim / claude ...
```

---

## 2. 用語と階層

| 階層 | 説明 | tmux で言うと |
| --- | --- | --- |
| **session** | サーバが保持する最上位の単位。既定は `default`。`--session <name>` で複数持てる | session |
| **workspace** (= space) | プロジェクト / 作業単位。サイドバーに一覧が出る。それぞれ cwd と git ブランチを持つ | (相当なし。近いのは session) |
| **tab** | workspace の中のタブ。上部のタブバーに並ぶ | window |
| **pane** | tab を分割した端末 1 つ | pane |
| **agent** | ペインの中で動いている AI エージェントとして検出されたもの。サイドバーに状態が出る | (相当なし) |
| **worktree** | git worktree を切って、それ専用の workspace として開く機能 | (相当なし) |

サイドバー (左) に workspace と agent の一覧、上部にタブバーが出ます。
サイドバーの開閉は `prefix+b`。

---

## 3. 起動・デタッチ・終了 (ランタイムのライフサイクル)

```
herdr                    # サーバが無ければ起動し、クライアントとしてアタッチ
  │
  ├─ prefix+q            # デタッチ。サーバとペインの中身はそのまま残る
  │                      #   → ターミナルを閉じたり SSH が切れても同じ状態
  ├─ herdr               # 再アタッチ (同じ画面が戻る)
  │
  ├─ herdr session list  # セッションの一覧と状態
  ├─ herdr session stop <name>    # セッションのプロセスを止める
  ├─ herdr session delete <name>  # 停止済みセッションを消す
  └─ herdr server stop   # サーバごと止める (全ペイン終了)
```

| やりたいこと | コマンド |
| --- | --- |
| 起動 / 再アタッチ | `herdr` (短縮エイリアス `hd`) |
| 名前付きセッション | `herdr --session work` / `herdr session attach work` |
| セッション一覧 | `herdr session list` |
| クライアント / サーバの状態 | `herdr status` |
| リモートのサーバに SSH 越しに繋ぐ | `herdr --remote <ssh-target>` |
| サーバを使わず単体で動かす (退避用) | `herdr --no-session` |

`hd` は `home/herdr.nix` で定義している fish / bash のエイリアスで、
中身は `herdr` そのものです。引数はそのまま渡るので `hd session list` の
ように使えます。alias なのでシェルスクリプト中の `hd` は効きません
(スクリプトからは `herdr` と書いてください)。

### 再起動をまたぐ復元

`session.resume_agents_on_restore = true` (このリポジトリで有効) にしていると、
サーバ再起動後に **公式インテグレーションを入れたエージェントのペイン**が、
元の会話セッションに復帰します。ペインの中身そのもの (シェルの履歴やスクロールバック)
は既定では再起動をまたぎません (`experimental.pane_history` が該当機能ですが既定 off)。

---

## 4. 基本操作 (キーバインド)

**prefix は `Ctrl-q`** (herdr 既定は `Ctrl-b`)。
以下はすべて「prefix を押してから」のキーです。
一覧は起動後 **`prefix+?`** でいつでも出せます。
prefix の選定理由とトレードオフは [8 章](#8-ハマりどころ) を参照。

### タブ

| 操作 | キー |
| --- | --- |
| **新しいタブを作る** | `prefix+c` (既定では名前を聞かれる) |
| 次のタブ / 前のタブ | `prefix+n` / `prefix+p` |
| 番号でタブを選ぶ | `prefix+1` … `prefix+9` |
| タブ名を変更 | `prefix+Shift+t` |
| タブを閉じる | `prefix+Shift+x` |

> 新規タブ作成時の名前入力が煩わしければ、`home/herdr.nix` に
> `ui.prompt_new_tab_name = false;` を足すと即座に自動生成名で作られます。

### workspace (プロジェクト単位)

| 操作 | キー |
| --- | --- |
| **新しい workspace を作る** | `prefix+Shift+n` |
| workspace を一覧から選ぶ | `prefix+w` |
| workspace 名を変更 | `prefix+Shift+w` |
| workspace を閉じる | `prefix+Shift+d` (既定では確認あり) |
| git worktree を切って開く | `prefix+Shift+g` |
| ナビゲートモード (上下で workspace, hjkl でペイン) | `prefix+g` |

### ペイン

| 操作 | キー |
| --- | --- |
| 縦分割 (右に開く) | `prefix+v` |
| 横分割 (下に開く) | `prefix+-` |
| 左 / 下 / 上 / 右のペインへ移動 | `prefix+h` / `prefix+j` / `prefix+k` / `prefix+l` |
| 次 / 前のペインへ巡回 | `prefix+Tab` / `prefix+Shift+Tab` |
| ペインをズーム (全画面トグル) | `prefix+z` |
| リサイズモードに入る | `prefix+r` |
| ペインを閉じる | `prefix+x` |
| ペイン名を変更 | `prefix+Shift+p` |
| スクロールバックを `$EDITOR` で開く | `prefix+e` |

新しいペイン・タブ・workspace の cwd は `terminal.new_cwd = "follow"` により
**元のペインのカレントディレクトリを引き継ぎます** (tmux の
`split-window -c "#{pane_current_path}"` 相当)。

### その他

| 操作 | キー |
| --- | --- |
| キーバインドのヘルプ | `prefix+?` |
| 設定画面 | `prefix+s` |
| サイドバーの開閉 | `prefix+b` |
| 設定ファイルの再読み込み | `prefix+Shift+r` |
| デタッチ | `prefix+q` |
| 通知の発生元を開く | `prefix+o` |

`prefix+e` の「スクロールバックを開く」は `$EDITOR` を使うので、この構成では
nvim が開きます (`home/editors/neovim.nix` が `EDITOR=nvim` を設定)。

---

## 5. このリポジトリの設定

`home/herdr.nix` の `programs.herdr.settings` がそのまま TOML になります。

| 設定 | 値 | 意図 |
| --- | --- | --- |
| `onboarding` | `false` | 設定は Nix で持つのでウィザードを通さない |
| `terminal.default_shell` | `${pkgs.fish}/bin/fish` | PATH 上の apt 版 fish ではなく Nix 管理の fish を使う ([理由](./fish-nix-path.md#3-fish-が-vendor_confd-を読む経路)) |
| `terminal.new_cwd` | `"follow"` | 新規ペイン / タブが元の cwd を引き継ぐ |
| `keys.prefix` | `"ctrl+q"` | 既定の `ctrl+b` (fish の backward-char) とも `ctrl+t` (fzf) とも衝突しないキー |
| `theme.name` | `"catppuccin"` | WezTerm (Catppuccin Mocha) と揃える |
| `session.resume_agents_on_restore` | `true` | サーバ再起動後にエージェントのセッションを再開 |

ペイン移動や分割のキーは herdr 既定がすでに prefix-first の vi 風なので上書きしていません。

設定できる項目の全量は次で確認できます。

```bash
herdr --default-config          # 既定値つきのコメント入りテンプレート
herdr config check              # 今の config.toml を検証 (不明キーを教えてくれる)
```

---

## 6. 設定変更のライフサイクル

```
home/herdr.nix を編集
  │
  ├─ home-manager switch --flake .#zenimoto@ubuntu
  │     ├─ ~/.config/herdr/config.toml を Nix store への symlink として張り替え
  │     └─ onChange フックが `herdr server reload-config` を実行
  │           (Home Manager の herdr モジュールが自動でやる)
  │
  ├─ 反映されたか確認: herdr config check
  └─ 手動で再読み込みしたいとき: prefix+Shift+r もしくは
     herdr server reload-config
```

キーバインドやテーマなど大半は reload で反映されます。
`ui.sidebar_start_collapsed` のように **次回起動時に効く**ものもあるので、
効かないときは一度デタッチしてサーバを再起動 (`herdr server stop` → `herdr`) します。

`~/.config/herdr/config.toml` は Nix store への symlink (読み取り専用) なので、
**GUI の設定画面 (`prefix+s`) から変更しても書き戻せません**。
設定変更は必ず `home/herdr.nix` 側で行ってください
(この考え方の一般論は [nix-concepts.md の 7 章](./nix-concepts.md#7-外部ツールによる変更を-nix-に取り込む))。

---

## 7. CLI から操作する

herdr は動作中サーバをソケット API 経由で操作する CLI を持っています。
スクリプトや AI エージェントから「タブを開く」「ペインにコマンドを流す」ができます。

```bash
herdr tab list
herdr tab create --cwd ~/ghq/github.com/Zeni-Y/dotfiles-nix --label build --focus
herdr pane split --current --direction down --ratio 0.3
herdr pane run --current -- cargo test         # ペインでコマンドを実行
herdr pane read --current                      # ペインの出力を読む
herdr workspace create --cwd ~/ghq/some-repo --label some-repo --focus
herdr worktree create --branch feature/x --base main --focus
herdr agent list                               # 検出されたエージェントの状態
```

サブコマンドの一覧は `herdr --help`、各コマンドの引数は
`herdr <group> <command> --help` で確認できます。

### エージェント連携 (任意)

`herdr integration install claude` のように入れると、エージェント側に hook を置いて
「作業中 / 入力待ち / 完了」をサイドバーに出せます。

```bash
herdr integration status          # 各エージェントのインストール状況
herdr integration install claude  # ~/.claude/hooks/herdr-agent-state.sh を置く
```

ただし **置き先 (`~/.claude/hooks/` など) は Home Manager の管理外**なので、
マシンを作り直すと消えます。恒久的に使うなら `home/` 配下で
`home.file` として宣言し直すのが筋です。

---

## 8. ハマりどころ

- **`herdr update` は使わない**。herdr の実体は Nix store 上の読み取り専用バイナリ
  (`~/.nix-profile/bin/herdr` → `/nix/store/...`) なので自己更新できません。
  バージョンは flake.lock で固定されており、上げるときは:
  ```bash
  nix flake update            # nixpkgs を更新
  home-manager switch --flake .#zenimoto@ubuntu
  ```
  同じ理由で `herdr channel set preview` も意味がありません。
- **タブバーの位置は設定できない** (0.7.5 では常に上)。tmux の
  `status-position top` に相当する `ui.tab_bar_position` というキーは存在せず、
  書いてもサーバは無視して `herdr config check` が
  `unknown config key ui.tab_bar_position; ignoring key` を出します
  (以前このリポジトリでも書いていて無視されていたため削除しました)。
  タブバーまわりで今使えるのは `ui.hide_tab_bar_when_single_tab` です。
  **設定を足したら `herdr config check` で不明キーが無いか確認する**のが確実です。
- **herdr のペインの中から `herdr` を起動できない**。`experimental.allow_nested`
  が既定で `false` のため。ネストしたいときだけ明示的に有効化します。
- **設定画面 (`prefix+s`) の変更は保存できない** (上記 6 章)。
- **バージョンチェックのために herdr.dev へ通信する** (`update.version_check` /
  `update.manifest_check` が既定 `true`)。オフライン環境や外部通信を切りたい場合は
  `home/herdr.nix` に次を足します。
  ```nix
  update = {
    version_check = false;
    manifest_check = false;
  };
  ```
- **prefix はペインの中のアプリより先に herdr が食う**。つまり prefix に選んだキーは
  シェルやエディタで使えなくなります。この構成でのキーごとの衝突状況は次のとおりです。

  | 候補 | 衝突するもの | 判定 |
  | --- | --- | --- |
  | `ctrl+b` (herdr 既定) | fish / readline の `backward-char` (1 文字戻る) | 常用キーなので不採用 |
  | `ctrl+t` (旧設定) | fzf のシェル統合 (`bind ctrl-t fzf-file-widget` — ファイルをあいまい検索して挿入) | 常用するので不採用 |
  | `ctrl+j` | fzf の `down` (候補を下へ)、LazyVim の `<C-j>` (下のウィンドウへ)、readline の `accept-line` (= Enter) | 常用キーが 3 つ潰れるので不採用 |
  | **`ctrl+q` (採用)** | fzf の `abort`、Neovim の挿入/コマンドラインモードの `CTRL-Q`、readline の `quoted-insert`、端末のフロー制御 (XON) | いずれも代替あり |

  `ctrl+q` を選んだ場合の代替手段:
  - fzf を閉じる → `Ctrl-c` / `Ctrl-g` / `Esc`
  - Neovim → ノーマルモードの `CTRL-Q` はそもそも未使用
    (`:help index` に "not used, or used for terminal control flow")。
    挿入 / コマンドラインモードの literal 入力は `Ctrl-v` で代替できる
  - bash の quoted-insert → `Ctrl-v`
  - XON (`Ctrl-s` で止めた出力の再開) → herdr クライアントは raw モードで
    入力を読むためフロー制御は効いておらず、そもそも `Ctrl-s` で止まりません

  `Ctrl-r` (履歴)、`Ctrl-alt-f` / `Ctrl-alt-l` / `Ctrl-alt-s` (fzf.fish)、
  `Ctrl-t` (fzf のファイル挿入) はすべてそのまま使えます。
  なお **WezTerm 側の leader が `Ctrl-w`** (`home/wezterm.nix`) である点は別の話として
  残っています。leader に割り当てたキーバインドが 1 つも無くても WezTerm は
  `Ctrl-w` を leader 起動として消費するため、ペインの中の Neovim で
  ウィンドウ操作の `<C-w>` が効きません (LazyVim は `<C-h/j/k/l>` を用意しているので
  移動は困りません)。気になるなら `home/wezterm.nix` の `config.leader` を変えてください。
- **ログの場所**: `~/.config/herdr/herdr.log` (加えて `herdr-client.log` /
  `herdr-server.log`)。挙動がおかしいときはここを見ます。
