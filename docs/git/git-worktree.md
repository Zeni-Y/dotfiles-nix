# git worktree — ライフサイクルと並列エージェント運用

1 つのリポジトリに **複数の作業ディレクトリ**をぶら下げる機能です。
「main を見ながら feature を直す」「複数の coding agent を同時に走らせる」
といった、**同じリポジトリで同時に別のことをしたい**場面のための道具です。

> このドキュメントは以下のバージョンで実際に動かして確認した挙動をもとに書いています。
> git **2.55.0** / herdr **0.7.5** / ghq **1.10.1** / gwq **0.1.1** / Claude Code **2.1.222**
> 一次情報は `git help worktree` / `herdr worktree --help` / `gwq --help` /
> <https://code.claude.com/docs/en/worktrees>。

---

## 目次

1. [何を解決するのか](#1-何を解決するのか)
2. [用語と物理構造](#2-用語と物理構造)
3. [共有されるもの・されないもの](#3-共有されるものされないもの)
4. [ライフサイクル (素の git)](#4-ライフサイクル-素の-git)
5. [置き場所の設計 — 集約派と隔離派](#5-置き場所の設計--集約派と隔離派)
6. [作り方 4 つ — git / gwq / herdr / Claude Code](#6-作り方-4-つ--git--gwq--herdr--claude-code)
7. [集約派で揃える — gwq と herdr を合わせる](#7-集約派で揃える--gwq-と-herdr-を合わせる)
8. [並列エージェント運用のレシピ](#8-並列エージェント運用のレシピ)
9. [この構成 (Nix / flake / direnv) での注意](#9-この構成-nix--flake--direnv-での注意)
10. [ハマりどころ](#10-ハマりどころ)

---

## 1. 何を解決するのか

`git switch` は **作業ディレクトリを 1 つしか持てない**のが前提です。
ブランチを切り替えるとファイルが丸ごと書き換わるので、

- ビルド成果物やキャッシュが毎回無効になる
- 中断するには `git stash` が要る
- **並列に動く 2 つのプロセス (= エージェント) が同じファイルを踏む**

worktree はこれを、**履歴 (`.git`) は 1 つのまま、チェックアウト先を N 個に増やす**
という形で解決します。clone を N 個作るのと違い、オブジェクトもブランチも
リモートも共有されるので、ディスクも増えず `git fetch` も 1 回で済みます。

```
                       ┌─ 作業ディレクトリ A (main)          ← 人間が見ている
リポジトリ (.git) ─────┼─ 作業ディレクトリ B (feature/x)     ← エージェント 1
  オブジェクト/ブランチ  ├─ 作業ディレクトリ C (feature/y)     ← エージェント 2
  /リモート を共有        └─ 作業ディレクトリ D (review/pr-42)  ← レビュー用
```

| やりたいこと | clone を増やす | worktree |
| --- | --- | --- |
| ディスク | リポジトリの数だけ増える | 作業ファイルのみ |
| `git fetch` | 各 clone で必要 | 1 回で全部に効く |
| ブランチの見え方 | clone ごとにバラバラ | 全部で同じ |
| コミットの受け渡し | push/pull が要る | 同じリポジトリなので不要 |
| 同じブランチを 2 箇所で | できる (競合し放題) | **禁止される** (安全側) |

---

## 2. 用語と物理構造

| 用語 | 意味 |
| --- | --- |
| **main worktree** | `git clone` / `git init` で作った最初の作業ディレクトリ。`.git` が**ディレクトリ**である方 |
| **linked worktree** | `git worktree add` で後から生やした作業ディレクトリ。`.git` が**ファイル**である方 |
| **prunable** | ディレクトリが消えたのに登録だけ残っている状態 |

linked worktree の `.git` は、中身が 1 行のテキストファイルです。

```bash
$ cat ../wt-feat/.git
gitdir: /path/to/main-repo/.git/worktrees/wt-feat
```

そこから 2 つのディレクトリを使い分けています。ここが理解の要です。

| git の言い方 | 実体 | 何が入るか |
| --- | --- | --- |
| `git rev-parse --git-dir` | `.git/worktrees/<name>` | **その worktree 固有**: `HEAD` / `index` / `ORIG_HEAD` など |
| `git rev-parse --git-common-dir` | `.git` | **全 worktree 共有**: `objects` / `refs` / `config` / `hooks` / `packed-refs` |

> スクリプトや hook で「リポジトリ共通のメタデータ」を触りたいときは
> `--git-dir` ではなく **`--git-common-dir`** を使ってください。
> `--git-dir` は worktree ごとに別の場所を指すので、`.git/hooks/...` を
> `--git-dir` から組み立てると linked worktree で壊れます。

---

## 3. 共有されるもの・されないもの

並列作業で事故るかどうかは、ほぼここで決まります。

| 対象 | 共有? | 実際どうなるか |
| --- | --- | --- |
| コミット / オブジェクト | **共有** | 片方でコミットすれば、もう片方から即 `git log` で見える |
| ブランチ / タグ / リモート追跡 | **共有** | どこで `git fetch --prune` しても全 worktree に効く |
| `git config` (リポジトリ設定) | **共有** | 片方で `git config` すると全部に効く |
| **hooks** (`.git/hooks/`) | **共有** | pre-commit などは**全 worktree で同じものが動く** |
| **stash** | **共有** | 別 worktree で積んだ stash が `git stash list` に出る。事故の元 |
| `HEAD` / index / チェックアウト中のブランチ | 個別 | ここが worktree の本体 |
| **追跡されていないファイル** | 個別 | `.env` / `node_modules` / `.direnv` / gitignore 済みのもの**は複製されない** |

### 同じブランチは 2 箇所で checkout できない

```bash
$ git worktree add ../wt-dup feature/x
fatal: 'feature/x' is already used by worktree at '/path/to/wt-feat'
```

これは制限ではなく**安全装置**です。並列エージェントに 1 branch = 1 worktree を
強制してくれるので、素直に従うのが正解です。
`git branch` の出力では、他の worktree が checkout 中のブランチに `+` が付きます。

```
+ feature/x       ← 他の worktree が使用中
* main            ← 今ここ
  feature/y
```

### worktree ごとに config を変えたいとき

既定では `git config` はリポジトリ全体で共有です。worktree ごとに変えたいなら
拡張を有効化します (有効化自体はリポジトリ単位)。

```bash
git config extensions.worktreeConfig true
git config --worktree user.email bot@example.com
```

有効化前に `--worktree` を使うと、`extensions.worktreeConfig を有効にしろ`
というエラーになります。

---

## 4. ライフサイクル (素の git)

```
  ┌─────────────────────────────────────────────────────────────┐
  │ 1. 作る                                                     │
  │    git worktree add <path> -b <new-branch>   # 新規ブランチ  │
  │    git worktree add <path> <existing-branch> # 既存ブランチ  │
  │    git worktree add <path> --detach          # detached HEAD │
  └───────────────────────────┬─────────────────────────────────┘
                              ↓
  ┌─────────────────────────────────────────────────────────────┐
  │ 2. 使う                                                      │
  │    cd <path> && 普通に編集 / commit / push                   │
  │    ※ 追跡外ファイルは無いので初期セットアップが要る          │
  └───────────────────────────┬─────────────────────────────────┘
                              ↓
  ┌─────────────────────────────────────────────────────────────┐
  │ 3. 取り込む (main worktree 側から)                           │
  │    git log main..feature/x    # 何が入るか確認               │
  │    git merge feature/x  /  gh pr create                     │
  │    ※ push/pull は不要。同じリポジトリなので既に見えている    │
  └───────────────────────────┬─────────────────────────────────┘
                              ↓
  ┌─────────────────────────────────────────────────────────────┐
  │ 4. 片付ける                                                  │
  │    git worktree remove <path>       # 未コミットがあると拒否 │
  │    git worktree remove --force <path>                       │
  │    git branch -d feature/x          # ← ブランチは別途消す   │
  └───────────────────────────┬─────────────────────────────────┘
                              ↓
  ┌─────────────────────────────────────────────────────────────┐
  │ 5. 掃除 (rm -rf してしまった場合)                            │
  │    git worktree list      # → "prunable" と表示される        │
  │    git worktree prune     # 登録を消す                       │
  └─────────────────────────────────────────────────────────────┘
```

コマンド早見表:

| やりたいこと | コマンド |
| --- | --- |
| 一覧 | `git worktree list` (機械処理は `--porcelain`) |
| 新規ブランチで作る | `git worktree add ../repo-feat -b feature/x` |
| 既存ブランチで開く | `git worktree add ../repo-fix fix-issue-456` |
| ブランチを作らず見るだけ | `git worktree add ../repo-review --detach origin/main` |
| 移動 | `git worktree move <path> <new-path>` |
| 誤削除防止 (外部ディスク等) | `git worktree lock <path> --reason "..."` |
| 削除 | `git worktree remove <path>` |
| 消えた登録の掃除 | `git worktree prune` |

### 削除まわりの実挙動 (確認済み)

- **未コミット / 追跡外ファイルがあると `remove` は拒否される。**
  `fatal: '<path>' contains modified or untracked files, use --force to delete it`
- **`remove` してもブランチは残る。** 消したければ `git branch -d/-D` を別途。
  裏を返せば、**checkout だけ捨てて作業内容は残す**という使い方ができます。
- `lock` した worktree は `remove` が `remove -f -f` を要求してきます。
- ディレクトリを `rm -rf` すると `git worktree list` に `prunable` が付き、
  `git worktree prune` するまで**そのブランチは「使用中」のまま**です
  (= 別の worktree で checkout できない)。詰まったらまず `prune`。

---

## 5. 置き場所の設計 — 集約派と隔離派

worktree で最初に決めるのは「**どこに置くか**」です。
ここに 2 つの流儀があり、**どちらが正しいというものではありません**。
先に選んでおかないと、ツールごとにバラバラの場所に散らかります。

### 前提: ghq は worktree も「リポジトリ」として数える

`GHQ_ROOT` は `$HOME/ghq` (`home/cli/ghq.nix`)。
そして `ghq list` は**リポジトリを `.git` の有無で判定する**ため、
`.git` が**ファイル**である linked worktree も**リポジトリとして列挙します**。

実測 (`GHQ_ROOT` 配下に worktree を置いた場合):

```
$ ghq list
github.com/shunk031/app                ← 本体
github.com/shunk031/app=feature-auth   ← worktree も出る
```

一方、**リポジトリの内側**に置いた worktree
(`github.com/foo/bar/.claude/worktrees/nested`) は `ghq list` に**出ません**。
ghq の走査はリポジトリを見つけた時点でそこから下に降りないためです。

**この「worktree も列挙される」性質を、邪魔と見るか機能と見るかが分岐点です。**

### 流儀 A: 集約派 — 全部 `~/ghq` に置く

[shunk031 氏の記事](https://blog.shunk031.com/) が紹介している運用です。
clone も worktree も同じ root に集約し、`ghq list | fzf` **一発でどこにでも飛べる**
状態を作ります。

```
~/ghq/
  github.com/shunk031/app                # 本体 (ghq get)
  github.com/shunk031/app=feature-auth   # worktree (gwq)
  github.com/shunk031/app=bugfix-login   # worktree (gwq)
  github.com/shunk031/infra              # 別レポ
  github.com/shunk031/infra=refactor-tf  # worktree
```

肝は **`repo=branch` というディレクトリ名**です。

- 本体のすぐ隣に並ぶので、fzf で `app` と打てば本体も worktree も一度に出る
- worktree を**本体の中に**入れない (= 本体の `git status` を汚さない)
- `ghq list` に出るのは**むしろ望ましい**。移動先の候補が 1 箇所に揃う

| 良い点 | 悪い点 |
| --- | --- |
| 移動が `ghq list \| fzf` に一本化される | `ghq list` が worktree で伸びる |
| 本体と worktree が視覚的に隣接する | `ghq get`/`ghq rm` の対象と紛らわしい |
| ツールを跨いでも置き場所が 1 つ | ghq の標準レイアウト (`host/owner/repo`) が前提 |

### 流儀 B: 隔離派 — `~/ghq` の外に追い出す

worktree は「一時的な作業場」と割り切り、`ghq list` を **clone した本体だけ**に
保つ考え方です。herdr の既定 (`~/.herdr/worktrees`) と
Claude Code の既定 (`<repo>/.claude/worktrees/`) はどちらもこちら側です。

| 良い点 | 悪い点 |
| --- | --- |
| `ghq list` が本体だけで済む | 移動手段が別に要る (`git worktree list \| fzf` など) |
| ツールが勝手に作って勝手に消せる | 置き場所がツールごとに分かれる |
| 消し忘れても目に入らない | 消し忘れても目に入らない (放置されやすい) |

### 比較表

| 置き場所 | `ghq list` | 本体の `git status` | 流儀 |
| --- | --- | --- | --- |
| `~/ghq/<host>/<owner>/<repo>=<branch>` (gwq) | 出る (**狙って**) | きれい | A 集約 |
| `~/ghq/<repo>-feat` など無計画に GHQ_ROOT 直下 | 出る (**事故**) | きれい | ✗ |
| `<repo>/.claude/worktrees/` (Claude Code 既定) | 出ない | **`.gitignore` 必須** | B 隔離 |
| `~/.herdr/worktrees/` (herdr 既定) | 出ない | きれい | B 隔離 |

### どちらを選ぶか

- **人間が worktree を行き来する時間が長いなら A (集約)。**
  移動コストが体感で効いてきます。
- **エージェントに作らせて捨てさせるだけなら B (隔離)。**
  人間が場所を意識しないので、集約する意味が薄いです。

現実的には **両方を併用**します。人間が育てる作業は gwq で `~/ghq` に、
エージェントの使い捨て作業は Claude Code の `.claude/worktrees/` に、
という住み分けが素直です。詳しくは [7 章](#7-集約派で揃える--gwq-と-herdr-を合わせる)。

### 隔離派を選ぶなら: グローバル gitignore に足しておく

`home/git.nix` の `programs.git.ignores` は全リポジトリに効く除外リストです
(すでに `.claude/settings.local.json` が入っています)。
`claude --worktree` を使うなら、リポジトリごとの `.gitignore` を毎回いじらずに済むよう
ここに足しておくのが楽です。

```nix
ignores = [
  # ...
  # Claude Code
  ".claude/settings.local.json"
  ".claude/worktrees/"        # ← 追加候補
];
```

> 注意: これは**自分の環境だけ**の除外です。チームで共有するリポジトリでは
> リポジトリの `.gitignore` にも書いておかないと、他のメンバーの手元で漏れます。

---

## 6. 作り方 4 つ — git / gwq / herdr / Claude Code

**置き場所とブランチ名の決まり方**が最大の差です。

| | 素の `git worktree` | **gwq** | **herdr** | **Claude Code `--worktree`** |
| --- | --- | --- | --- | --- |
| 置き場所 | 自分で指定 | `basedir` + `naming.template` | `<directory>/<repo>/<branch>` | `<repo>/.claude/worktrees/<name>/` |
| 置き場所の自由度 | 完全 | **テンプレートで完全に制御** | 親ディレクトリのみ | 固定 (hook で置換可) |
| ブランチ名 | 自分で指定 | 自分で指定 | 自分で指定 | `worktree-<name>` (自動) |
| 分岐元 | 自分で指定 | 自分で指定 | `--base <ref>` | `worktree.baseRef` (既定はリモート既定ブランチ) |
| UI | なし | fzf | サイドバーに workspace | セッションが自動で入る |
| 後片付け | 全部手動 | `gwq remove` | `herdr worktree remove` | 終了時に対話で提案 |
| 流儀 | どちらでも | **A 集約** | B 隔離 | B 隔離 |

### 6-1. gwq — worktree を ghq っぽく管理する

「ghq が clone を管理するように、gwq は worktree を管理する」という位置づけの
CLI です。**nixpkgs に入っています** (`gwq` 0.1.1)。

```
$ nix search nixpkgs gwq
* legacyPackages.x86_64-linux.gwq (0.1.1)
  Git worktree manager with fuzzy finder interface
```

```
Available Commands:
  add      Create a new worktree      list    Display worktree list
  cd       Change to worktree dir     get     Get worktree path
  exec     Execute command in wt      status  Show status of all worktrees
  remove   Delete worktree            prune   Clean up deleted worktree info
  tmux     Manage tmux sessions       config  Configuration management
```

このリポジトリでは **`home/cli/gwq.nix` で導入済み**です
(パッケージ・`~/.config/gwq/config.toml`・fish のシェル統合をそこで持っています)。
設定の実測値は [7 章](#7-集約派で揃える--gwq-と-herdr-を合わせる)。

> `gwq tmux` は長時間処理用の tmux セッション管理ですが、この構成の
> マルチプレクサは herdr なので使いません ([herdr.md](../terminal/herdr.md))。

> **`buildGoModule` で自前パッケージ化する記事を見かけたら**: それは gwq が
> まだ nixpkgs に入っていなかった頃 (v0.0.5) の話です。現在は `pkgs.gwq` で足り、
> bash / fish / zsh の補完も `share/` に同梱されています
> (`fish -c 'complete -C "gwq "'` で確認済み)。自前 derivation を持つと
> `vendorHash` の更新を自分で追う羽目になるので、素直に nixpkgs を使います。

### 6-2. herdr から

キーバインドは `prefix+Shift+g` (= `keys.new_worktree`)。
worktree を切って、それ専用の workspace として開きます。
`open_worktree` / `remove_worktree` は既定でキー未割り当てなので、
使うなら `home/herdr.nix` の `keys` に足します。

CLI からも同じことができます (`--json` を付けると機械処理しやすい)。

```bash
herdr worktree list   --cwd ~/ghq/github.com/Zeni-Y/dotfiles-nix --json
herdr worktree create --cwd ~/ghq/github.com/Zeni-Y/dotfiles-nix --branch feature/x --base main --focus
herdr worktree open   --cwd ~/ghq/github.com/Zeni-Y/dotfiles-nix --path <既存 worktree のパス>
herdr worktree remove --workspace <workspace_id>   # --force で未コミットも消す
```

確認した挙動:

- 既定のパスは `~/.herdr/worktrees/<repo 名>/<ブランチ名>`。
  **リポジトリの外**なので、本体の `git status` を汚しません。
- ブランチ名の `/` は `-` に潰されます
  (`feature/deep/x` → `~/.herdr/worktrees/app/feature-deep-x`)。ディレクトリは入れ子になりません。
- `herdr worktree remove` は **checkout を消すだけでブランチは残す**。
  素の git と同じく `git branch -d` は自分でやる必要があります。
- `--cwd <repo>` で対象リポジトリを指定すると、そのリポジトリの workspace が
  無ければ herdr が**自動で 1 つ作ります**。使い終わったら
  `herdr workspace close <workspace_id>` で閉じます
  (`--workspace` オプションではなく**位置引数**です)。

### 6-3. Claude Code から

```bash
claude --worktree feature-auth     # -w でも可。名前を省くと自動生成名
claude --worktree "#1234"          # PR 番号から。# はクォート必須
```

`<repo>/.claude/worktrees/<name>/` に作られ、そのセッションはそこから出られなくなります
(本体への `Edit` / `Write` / `cd` / `git -C` は**ツール側でブロック**されます)。
サブエージェントも同じ制約を継承します。

押さえておく設定は 3 つ。

| 設定 | 効果 |
| --- | --- |
| `.gitignore` に `.claude/worktrees/` | **必須**。書かないと本体の `git status` が worktree の中身で埋まる |
| `.worktreeinclude` (リポジトリ直下) | gitignore 構文。**gitignore されているファイルだけ**を新しい worktree にコピーする |
| `worktree.baseRef` (settings) | `"fresh"` (既定, リモート既定ブランチから) / `"head"` (今の HEAD から) |

`.worktreeinclude` が「gitignore されているものだけ」なのがポイントで、
`.env` や `.claude/settings.local.json` のような**追跡外だが無いと動かないファイル**を
運ぶための機能です。追跡済みファイルは元々チェックアウトされるのでコピーされません。

終了時のクリーンアップは自動です。

| worktree の状態 | 終了時の挙動 |
| --- | --- |
| きれい + 名前なしセッション | worktree もブランチも自動削除 |
| きれい + 名前付きセッション | 消していいか聞かれる |
| 変更やコミットが残っている | 残すか消すか聞かれる (消すと**作業ごと消える**) |
| `-p` (非対話) | **何もしない**。`git worktree remove` で自分で消す |

サブエージェント用の worktree は `cleanupPeriodDays` に従って定期的に掃除されます
(作業が残っているものは飛ばされる)。`--worktree` で作ったものは掃除対象外です。
カスタムサブエージェントを常に隔離したいなら frontmatter に `isolation: worktree`。

---

## 7. 集約派で揃える — gwq と herdr を合わせる

「clone も worktree も `~/ghq` に集約して fzf 一発で飛ぶ」流儀を、
この環境で実現する手順です。**herdr も合わせられます** (方法は 7-4)。

### 7-1. 前提: ghq の標準レイアウトであること (移行済み)

集約派のテンプレート `{{.Host}}/{{.Owner}}/{{.Repository}}={{.Branch}}` は
`~/ghq/github.com/Zeni-Y/dotfiles-nix=feature-x` を作ります。
本体がその隣に無いと意味が無いので、**本体も標準レイアウトに置かれている必要があります**。

このリポジトリは以前 `~/ghq/dotfiles-nix` (host/owner の階層が無い手置きの形)
でしたが、**移行済み**です。

```
~/ghq/
  github.com/Zeni-Y/dotfiles-nix              ← 本体
  github.com/Zeni-Y/dotfiles-nix=feature-x    ← worktree (gwq が作る)
```

これから同じことをする場合の手順:

```bash
ghq list --full-path                       # 今どうなっているか
ghq get github.com/<owner>/<repo>          # 標準レイアウトで取り直す
# もしくは既存ディレクトリを移動させる (gitignore 済みファイルも保てる)
ghq migrate github.com/<owner>/<repo>
```

> **`ghq get` で取り直すと gitignore 済みのファイルが消えます。**
> このリポジトリの場合 `ref/` (23MB, 他 dotfiles の clone 2 つ) と
> `.claude/settings.local.json` がそれに当たるため、取り直しではなく
> `mv` (= `ghq migrate` 相当) で移行しました。

移行に伴って次も更新済みです。同じことをするなら追随が要ります。

| 場所 | 内容 |
| --- | --- |
| `home/shell/fish.nix` の `flakeDir` | `hmn` / `hmg` / `nfc` / `nfu` の展開先。**ここが唯一の実コード参照** |
| `docs/shell/fish-abbr.md` | abbreviation 一覧に載っているパス |
| `docs/terminal/herdr.md` | CLI の例に出てくるパス |

`docs/setup/wsl2.md` の手順も新レイアウトに揃えてあります。

ghq の root は git-config でも指定できます (現状は `home/cli/ghq.nix` の
`home.sessionVariables.GHQ_ROOT`)。どちらか一方で十分です。

### 7-2. gwq の設定

gwq の設定ファイルは **`~/.config/gwq/config.toml`** です。

```toml
[naming]
template = '{{.Host}}/{{.Owner}}/{{.Repository}}={{.Branch}}'

[worktree]
basedir = '~/ghq'

[cd]
launch_shell = false
auto_cd_on_add = true
```

既定値は次のとおりです (実測)。

| キー | 既定値 | この構成での値 | なぜ変えるか |
| --- | --- | --- | --- |
| `naming.template` | `{{.Host}}/{{.Owner}}/{{.Repository}}/{{.Branch}}` | `...{{.Repository}}={{.Branch}}` | 本体の「隣」に並べる |
| `worktree.basedir` | `~/worktrees` | `~/ghq` | ghq と root を揃える |
| `naming.sanitize_chars` | `/` → `-`, `:` → `-` | そのまま | — |
| `cd.launch_shell` | `true` | `false` | シェルを積み上げない (7-3) |
| `cd.auto_cd_on_add` | `false` | `true` | 作った直後に飛ぶ |

既定の `.../{{.Repository}}/{{.Branch}}` (最後が **`/`**) のままで
`basedir = '~/ghq'` にすると、**本体ディレクトリの中に worktree が生える**ため、
`=` に変えるのが要点です。

`sanitize_chars` のおかげで `/` を含むブランチも平らになります (実測)。

```
gwq add -b feature/deep/y  →  ~/ghq/github.com/shunk031/app=feature-deep-y
```

この構成では `home/cli/gwq.nix` がこれを持っています
(`home/cli/default.nix` の `imports` に登録済み)。

> **確認した罠**: gwq 0.1.1 は **`XDG_CONFIG_HOME` を見ません**。
> `$HOME/.config/gwq/config.toml` を直接読みます。
> `XDG_CONFIG_HOME` を既定から動かしていなければ `xdg.configFile` の出力先と
> 一致するので問題ありませんが、動かしている環境では設定が黙って無視されます。
> 反映されているかは `gwq config list` で確認してください。

> **もう一つの罠**: gwq は `--help` 以外のほぼ全サブコマンド (`version` でさえ)
> の初回実行時に `config.toml` を既定値で自動生成します。Nix で配る前に一度でも
> gwq を実行していると、その実ファイルが残って
> `Existing file ... would be clobbered` で **switch 全体が失敗します**。
> `home/cli/gwq.nix` では `force = true` で恒久的に潰してあります
> (経緯は [nix-concepts.md 7-7 章](../nix/nix-concepts.md#7-7-例外-まだ-nix-管理下に無い実ファイルは上書きされず-switch-が止まる))。

### 7-3. 移動を作る — シェル統合と `dev`

集約派の見返りはここです。移動の作り方は 2 つあり、**役割が違います**。

#### (a) worktree 間 — `gwq cd` / `gwq add` (シェル統合)

gwq の既定では `gwq cd` は「**新しいシェルを起こしてその中で移動する**」動作です。
worktree を渡り歩くたびにシェルが積み上がり、戻るのに `exit` を数えることになります。

`cd.launch_shell = false` にすると、gwq は選んだパスを標準出力に吐くだけになり、
`gwq completion fish` が**補完に加えてシェル統合の関数**を出力するようになります。
これを読み込めば `gwq cd` / `gwq add` が**現在のシェルを動かします**。

```console
$ gwq add -b feature-x     # 作成して、そのまま移動する
Created worktree for branch 'feature-x'
$ pwd
~/ghq/github.com/Zeni-Y/dotfiles-nix=feature-x

$ gwq cd                   # 引数なしならファインダ (プレビュー付き) が出る
```

ここが素の git との一番の差です。`git worktree add` は作るだけで、
どこに出来たかは自分で覚える必要がありました (4 章)。

統合スクリプトは**ビルド時に生成**して store から読んでいます。

```nix
# home/cli/gwq.nix (抜粋)
fishIntegration = pkgs.runCommand "gwq-fish-integration.fish" { } ''
  export HOME="$PWD"
  install -Dm644 ${configFile} "$HOME/.config/gwq/config.toml"
  ${pkgs.gwq}/bin/gwq completion fish > "$out"
'';
```

`export HOME="$PWD"` して config を置いているのがミソです。統合部分が出るかどうかは
gwq が**実行時に読んだ `config.toml`** で決まるため、配布するのと同じ設定を
食わせないと補完だけが出力されます。nixpkgs が同梱している補完
(`share/fish/vendor_completions.d/gwq.fish`) は既定値でビルドされているので、
統合部分を含みません。

> シェル起動時に `gwq completion fish | source` と書く手もありますが、
> それだと対話シェルを開くたびに gwq を起動します (実測 ≒ 20ms)。
> store のパスを `source` するだけなら実行時コストはゼロです。
> なお補完定義は vendor 側と二重登録になりますが、fish は同一候補を
> まとめるので実害はありません (`complete -C 'gwq '` で確認済み)。

#### (b) リポジトリ間 — `dev` (ghq + fzf)

`gwq cd` が見るのは**カレントリポジトリの worktree だけ**です。
リポジトリをまたぐ移動は `ghq list` を fzf に流します。clone も worktree も
同じ root にあるので、これ一つで両方に飛べます。

```console
$ dev              # 一覧から選ぶ
$ dev dotfiles     # 候補が 1 件なら即決定 (--select-1)
```

実体は `home/cli/ghq.nix` の `programs.fish.functions` です
(`~/.config/fish/functions/dev.fish` が生成され、fish の autoload に乗ります)。

```fish
set -l target (ghq-path $argv)

# fzf を Esc / ctrl+c で抜けたときは何も返らない。
# ここで止めないと引数無しの cd が走ってホームに飛ぶ。
if test -z "$target"
  return 1
end

cd $target
or return 1

if set -q HERDR_WORKSPACE_ID
  herdr workspace rename $HERDR_WORKSPACE_ID (path basename $target) >/dev/null
end
```

元記事との差は 3 点です。

- **`exit` ではなく `return`**。fish の `exit` は関数ではなく**シェル自体**を
  終わらせます。元記事の `cd "${moveto}" || exit 1` をそのまま移植すると、
  fzf をキャンセルしただけでターミナルが閉じます。
- **tmux ではなく herdr**。`herdr workspace rename <WORKSPACE_ID> <LABEL>` は
  ワークスペース ID を**位置引数**で取るので、`$HERDR_WORKSPACE_ID` を渡します。
  herdr のラベルはワークスペース作成時のリポジトリ名で決まるため、
  同じワークスペースの中で `cd` しただけでは追従しません。
- **`.` を `-` に潰さない**。元記事の `${repo_name//./-}` は tmux が
  セッション名の `.` を嫌うための処理です。herdr のラベルは `.` をそのまま
  受け付けます (実測)。ラベルは `<repo>=<branch>` の形になるので、
  worktree に居るのか本体に居るのかがタブバーだけで分かります。

### 7-4. herdr を集約派に合わせる

**結論: 設定だけでは合いません。`--path` を使えば完全に合わせられます。**

herdr の worktree 設定は `directory` **1 つだけ**です。

```toml
# [worktrees]
# directory = "~/.herdr/worktrees"
```

命名テンプレートに相当するものは無く、パスの組み立ては
**`<directory>/<repo 名>/<ブランチ名>` 固定**です (実測)。したがって:

- `directory = "~/ghq"` にしても、できるのは `~/ghq/<repo 名>/<branch>` です。
  `<repo 名>` はパスの末尾だけ (= `dotfiles-nix`) なので host/owner の階層は付かず、
  `~/ghq/dotfiles-nix/feature-x` のような**本体から離れた場所**に散らばります。
  しかもそれ自体が `ghq list` に `dotfiles-nix/feature-x` として出ます。
  集約派の狙い (本体の隣に並べる) がまるごと外れるので、
  **`directory = "~/ghq"` は設定しないでください。**

代わりに、herdr の worktree コマンドは `--path` で**置き場所を明示できます**。
これで集約派のレイアウトを直接作れます (実測で確認)。

```bash
REPO=~/ghq/github.com/Zeni-Y/dotfiles-nix

# 集約派のパスに worktree を作って workspace として開く
herdr worktree create --cwd $REPO --branch feature-x --base main \
  --path "$REPO=feature-x" --focus

# gwq が作った worktree を herdr の workspace として開く
herdr worktree open --cwd $REPO --path "$REPO=feature-auth" --focus
```

`herdr worktree open --path` が効くのが重要で、これにより
**作成と命名は gwq、UI と並列監視は herdr**、という分担が成立します。
実際に gwq で作った `app=feature-auth` を開くと、herdr 側には
`app=feature-auth` というラベルの workspace として並びます。

```
gwq add ─→ ~/ghq/github.com/owner/app=feature-auth ─→ herdr worktree open --path
   (作成・命名・fzf)              (単一の root)            (workspace として監視)
```

残る制約が 1 つあります。**キーバインド `prefix+Shift+g` は `directory` 設定を使う**
ので、集約派のパスにはなりません。キー一発で集約派の worktree を作りたいなら、
ラッパーを用意して別のキーやコマンドに割り当てます。

```fish
function wt --description 'カレントのリポジトリに集約派レイアウトで worktree を作る'
    set -l repo (git rev-parse --show-toplevel); or return
    set -l branch $argv[1]
    test -n "$branch"; or begin; echo "usage: wt <branch>"; return 1; end
    herdr worktree create --cwd $repo --branch $branch --base main \
        --path "$repo=$branch" --focus
end
```

### 7-5. まとめ: 何をどこに置くか

| 用途 | ツール | 置き場所 |
| --- | --- | --- |
| worktree を作る | `gwq add -b <branch>` (作成後そのまま移動) | `~/ghq/<host>/<owner>/<repo>=<branch>` |
| それを herdr で監視する | `herdr worktree open --path` | 同上 |
| キー一発で作って開く | `wt` ラッパー (7-4) | 同上 |
| エージェントの使い捨て作業 | `claude --worktree` | `<repo>/.claude/worktrees/` |
| 同じリポジトリの worktree 間を移動 | `gwq cd` | — |
| リポジトリをまたいで移動 | `dev` (ghq + fzf) | — |

---

## 8. 並列エージェント運用のレシピ

### 8-1. 全体像

```
                      ┌─ worktree A ─ agent 1 ─ branch feature/a ─┐
本体 (main) ──────────┼─ worktree B ─ agent 2 ─ branch feature/b ─┼─→ PR → main
 (人間: 指示とレビュー) └─ worktree C ─ agent 3 ─ branch feature/c ─┘
```

守るべき原則は 3 つだけです。

1. **1 エージェント = 1 worktree = 1 ブランチ。** git がこれを強制してくれます。
2. **タスクは所有権で分ける。** 同じファイルを 2 体に触らせない。
   ファイルが被ると、隔離できているのはディスク上だけで、
   マージ時に人間が競合を解く羽目になります。
3. **人間は本体の checkout に居続ける。** 指示とレビューはここから。
   worktree の中に入ってしまうと全体が見えなくなります。

### 8-2. herdr で並べる (人間が見張る場合)

herdr はサイドバーに workspace とエージェントの状態 (作業中 / 入力待ち / 完了) を
並べて出せるので、**N 体の進捗を 1 画面で見る**用途に向いています。

```bash
REPO=~/ghq/github.com/Zeni-Y/dotfiles-nix
for b in feat-a feat-b feat-c; do
  herdr worktree create --cwd $REPO --branch $b --base main \
    --path "$REPO=$b" --no-focus
done
herdr workspace list --json | jq -r '.result.workspaces[] | "\(.workspace_id)\t\(.label)"'
```

各 workspace のペインでエージェントを起動し、CLI から流し込めます。

```bash
herdr agent start my-agent --kind claude --pane <pane_id>
herdr agent prompt <target> "テストを直して" --wait --until idle --timeout 600000
herdr agent list                       # 状態の一覧
herdr agent wait <target> --until idle --timeout 900000
herdr agent read <target>              # 出力を読む
```

状態表示を有効にするには統合の導入が必要です
(`herdr integration install claude`)。ただし置き先の `~/.claude/hooks/` は
Home Manager の管理外なので、恒久運用するなら `home/` 配下で `home.file` として
宣言し直してください ([herdr.md 8 章](../terminal/herdr.md#8-cli-から操作する))。

### 8-3. Claude Code に任せる (見張らない場合)

```bash
# 別ターミナル / 別ペインでそれぞれ
claude --worktree fix-login
claude --worktree add-tests
```

こちらは worktree の作成・隔離・後片付けまで面倒を見てくれるぶん、
置き場所とブランチ名は規約に従うことになります。
セッション内で「worktree で作業して」と頼めば、その場で worktree に移ることもできます。

1 セッションの中でサブエージェントを並列に走らせたいだけなら、
worktree を手で切らずに `isolation: worktree` を使う方が簡単です。

### 8-4. どちらを使うか

| 状況 | 選択 |
| --- | --- |
| 進捗を横目で見ながら複数走らせたい | **herdr** の worktree workspace |
| 投げっぱなしにして結果だけ受け取りたい | **`claude --worktree`** |
| 1 セッション内で並列に作業させたい | サブエージェントの `isolation: worktree` |
| 人間が長く育てる / 頻繁に行き来する | **gwq** (集約派) |

### 8-5. マージまでの流れ

worktree 間で push/pull は不要です。同じリポジトリなので、
本体から他の worktree のコミットがそのまま見えます。

```bash
# 本体の checkout で
git worktree list                       # 誰がどこで何をしているか
git log --oneline main..feature/a       # 取り込む前に差分を確認
git diff main...feature/a

gh pr create --head feature/a           # PR にする (推奨)
# もしくは直接
git merge --no-ff feature/a

# 片付け
gwq remove feature/a                    # gwq 管理下なら
git worktree remove <path>              # 素の git なら
git branch -d feature/a                 # ← どちらでもブランチは別途
```

エージェントを増やすと**律速はレビュー側に移ります**。
同時に走らせる数は、自分がレビューを捌ける数で決めるのが現実的です。

---

## 9. この構成 (Nix / flake / direnv) での注意

### flake は worktree でそのまま動く

このリポジトリを worktree に切って `nix flake metadata` を実行すると、
worktree のパスとそのブランチの revision で正しく解決されます。

```
Resolved URL: git+file:///path/to/worktree
Locked URL:   git+file:///path/to/worktree?ref=refs/heads/<branch>&rev=<sha>
```

つまり worktree の中から次がそのまま使えます。

```bash
home-manager switch --flake .#zenimoto@ubuntu
```

ただし **`home-manager switch` の結果はマシン全体に効きます**。
worktree で隔離されるのはファイルの編集だけで、実際に適用した設定は 1 つです。
複数のエージェントに同時に `switch` させると当然壊れるので、
**適用は人間が本体から 1 回だけ**やる、と決めておくのが安全です。
エージェントには `nix flake check --no-build` や `nix build` までに留めてもらいます。

### flake は git 管理下のファイルしか見ない

`nix build` / `home-manager switch` は git 管理下のファイルだけを store にコピーします。
worktree で新規ファイルを足したときは、`git add` しないと
`path ... does not exist` や「変更が反映されない」になります。これは worktree 固有の話ではありませんが、
worktree では**追跡外ファイルが最初から存在しない**ぶん遭遇しやすくなります。

### 追跡外ファイルは付いてこない

このリポジトリで worktree を切ると、次は**存在しません**。

| 消えるもの | 対処 |
| --- | --- |
| `ref/` (`.gitignore` 済み。他 dotfiles の参照用) | 必要なら `.worktreeinclude` に書くか symlink |
| `.claude/settings.local.json` (グローバル ignore 済み) | `.worktreeinclude` に書く |
| `.direnv/` | worktree で `direnv allow` し直す |

`.worktreeinclude` を置くならこんな形です (Claude Code が作る worktree に効きます)。

```text
.claude/settings.local.json
```

### direnv はパスごとに信頼する

direnv (`home/cli/direnv.nix`, nix-direnv 有効) は **ディレクトリパス単位**で
`.envrc` を信頼します。worktree は別パスなので、`.envrc` があるリポジトリでは
worktree ごとに一度 `direnv allow` が必要です。

nix-direnv のキャッシュ (`.direnv/`) も worktree ごとに作られるため、
最初の `direnv reload` は時間がかかります (store は共有なので再ビルドではなく評価のみ)。

### hooks は共有される

`.git/hooks/` は全 worktree 共通です。pre-commit などを書くときは、
**「1 つの作業ディレクトリしかない」前提を置かない**こと。
共有メタデータを指したいときは `git rev-parse --git-common-dir`、
今の作業ディレクトリを指したいときは `git rev-parse --show-toplevel` を使います。

---

## 10. ハマりどころ

- **無計画に `~/ghq/` 直下に worktree を置くと `ghq list` が汚れる。**
  `.git` がファイルでも ghq はリポジトリとして数えます。
  集約派でやるなら `repo=branch` の命名まで含めて**意図的に**やること
  ([5 章](#5-置き場所の設計--集約派と隔離派))。
- **herdr の `[worktrees] directory` を `~/ghq` にしてはいけない。**
  パスは `<directory>/<repo 名>/<branch>` 固定で、`<repo 名>` は末尾の要素だけなので
  `~/ghq/dotfiles-nix/<branch>` という**本体から離れた場所**にでき、`ghq list` も汚します。
  集約派に合わせるなら `directory` ではなく `--path` を使ってください
  ([7-4](#7-4-herdr-を集約派に合わせる))。
- **gwq の既定テンプレートは末尾が `/{{.Branch}}`。**
  そのまま `basedir` を `~/ghq` にすると本体の中に worktree が生えます。`=` に変えること。
- **gwq 0.1.1 は `XDG_CONFIG_HOME` を見ない。**
  `$HOME/.config/gwq/config.toml` 決め打ちです。反映確認は `gwq config list`。
- **gwq は初回実行時に `~/.config/gwq/config.toml` を自分で作る**
  (`--help` 以外のほぼ全サブコマンド。`gwq version` でさえ作ります)。
  Nix で配る前に一度でも `gwq` を実行していると、その既定ファイルが残っていて
  `home-manager switch` が
  `Existing file '/home/zenimoto/.config/gwq/config.toml' would be clobbered`
  で止まります (この構成でも導入時に実際に踏みました)。
  **対策済み**: `home/cli/gwq.nix` で `force = true` を宣言しているので、
  別のマシンで構築するときも止まりません
  ([nix-concepts.md 7-7](../nix/nix-concepts.md#7-7-例外-まだ-nix-管理下に無い実ファイルは上書きされず-switch-が止まる))。
  なお **gwq 側は既存ファイルを勝手に上書きしません**。Nix の symlink が
  張られた後は、gwq を何度実行してもそのままです (実測)。
- **新しい `.nix` ファイルを足したら `git add` するまで flake から見えない。**
  `home/cli/gwq.nix` を追加した直後の switch は
  `error: Path 'home/cli/gwq.nix' ... is not tracked by Git` で失敗します。
  コミットまでは不要で、`git add` だけで通ります
  ([9 章](#9-この構成-nix--flake--direnv-での注意))。
- **`.claude/worktrees/` を ignore し忘れると本体の `git status` が壊滅する。**
  worktree のファイルが丸ごと未追跡として出ます。
- **`git worktree remove` はブランチを消さない。** herdr の `worktree remove` も同じ。
  片付けたつもりでも `git branch` が育ち続けます。`git branch -d` まで含めて 1 セット。
- **ディレクトリを `rm -rf` すると登録が残り、そのブランチが「使用中」のままになる。**
  `git worktree list` に `prunable` と出たら `git worktree prune` (`gwq prune` でも可)。
- **stash はリポジトリ共通。** 別 worktree で積んだ stash が
  `git stash list` に混ざります。並列作業中は stash を使わず、
  WIP コミットで退避する方が事故りません。
- **同じブランチを 2 つの worktree で checkout できない。**
  `fatal: '<branch>' is already used by worktree at ...`。
  設計上の安全装置なので、ブランチを分けるのが正解です。
- **hooks も `git config` も共有。** worktree ごとに変えたいなら
  `extensions.worktreeConfig = true` を先に有効化 ([3 章](#3-共有されるものされないもの))。
- **`.env` や `.direnv` は付いてこない。** worktree は追跡外ファイルを複製しません。
  毎回必要になるものは `.worktreeinclude` に書くか、セットアップスクリプトを用意します。
- **`claude -p` (非対話) で作った worktree は自動で消えない。**
  CI やスクリプトで回すときは `git worktree remove` を明示的に呼んでください。
- **`home-manager switch` はマシン全体に効く。** worktree で隔離されるのは
  ファイル編集だけです。並列エージェントには適用させないこと ([9 章](#9-この構成-nix--flake--direnv-での注意))。
- **`herdr workspace close` は位置引数。** `--workspace w6` ではなく
  `herdr workspace close w6` です (`worktree remove` の方は `--workspace` を取るので紛らわしい)。
- **ghq の標準レイアウトへ移行すると flake のパスが変わる。**
  `home/shell/fish.nix` の `flakeDir` が唯一の実コード参照で、`hmn` / `nfc` / `nfu` は
  そこから組み立てられます。この Ubuntu ホストも `docs/setup/wsl2.md` の手順も移行済み
  ([7-1](#7-1-前提-ghq-の標準レイアウトであること-移行済み))。
  **fork して別 owner にするなら `flakeDir` の `Zeni-Y` も直すこと。**
  owner 名は `userInfo.username` (zenimoto) と綴りが違うので自動導出できません。
- **`ghq get` で取り直すと gitignore 済みのファイルが消える。**
  `ref/` や `.claude/settings.local.json` が該当します。移行は `mv` /
  `ghq migrate` で行うこと。

---

## 関連ドキュメント

- [herdr.md](../terminal/herdr.md) — workspace / ペイン操作と CLI (`herdr worktree` はその一部)
- [nix-concepts.md](../nix/nix-concepts.md) — flake と Home Manager のライフサイクル
- [fish-abbr.md](../shell/fish-abbr.md) — `hms` などの abbreviation (集約派移行時に要修正)
- [ref-tips.md](./ref-tips.md) — `wta` / `wtb` / `wtd` など worktree ラッパーの導入候補
- 一次情報: `git help worktree` / `herdr worktree --help` / `gwq --help` /
  <https://code.claude.com/docs/en/worktrees>
