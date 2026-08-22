# Claude Code — 指示ファイルの階層と Nix での配り方

Claude Code に「毎回同じことを言い直さない」ための仕組みと、
それをこのリポジトリからどう配っているかをまとめた資料です。

---

## 目次

1. [2 つの記憶: CLAUDE.md と auto memory](#1-2-つの記憶-claudemd-と-auto-memory)
2. [指示ファイルの階層](#2-指示ファイルの階層)
3. [rules/ — トピック分割とパススコープ](#3-rules--トピック分割とパススコープ)
4. [このリポジトリでの配り方](#4-このリポジトリでの配り方)
5. [ルールを足す・直す手順](#5-ルールを足す直す手順)
6. [Nix で管理しないもの](#6-nix-で管理しないもの)
7. [書き方の指針](#7-書き方の指針)
8. [ハマりどころ](#8-ハマりどころ)

---

## 1. 2 つの記憶: CLAUDE.md と auto memory

Claude Code のセッションは毎回まっさらなコンテキストから始まります。
それを越えて知識を運ぶ仕組みが 2 つあり、どちらもセッション開始時に読み込まれます。

| | CLAUDE.md / rules | auto memory |
| --- | --- | --- |
| 書く人 | **人間** | **Claude 自身** |
| 中身 | 守らせたいルール・規約 | 気づき・学習したパターン |
| 置き場所 | `~/.claude/`、リポジトリ | `~/.claude/projects/<project>/memory/` |
| 共有 | git / Nix で配れる | マシンローカル。リポジトリ単位 (worktree 間で共有) |
| このリポジトリでの扱い | **Nix で宣言的に配る** | 管理しない (→ [6 章](#6-nix-で管理しないもの)) |

どちらも「強制」ではなく**コンテキスト**です。必ず実行させたい処理
(コミット前に必ず lint を通す等) はルールではなく hook にします。

---

## 2. 指示ファイルの階層

読み込み順は**広いスコープから狭いスコープへ**。後に読まれたものほど強く効きます。

| スコープ | 場所 | 用途 |
| --- | --- | --- |
| Managed policy | Linux: `/etc/claude-code/CLAUDE.md` | 組織全体。個人設定では除外できない |
| **User** | `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md` | **全プロジェクト共通の個人ルール** |
| **Project** | `<repo>/CLAUDE.md`, `<repo>/.claude/rules/*.md` | **そのリポジトリ固有。git で共有** |
| Local | `<repo>/CLAUDE.local.md` | 個人的なメモ。gitignore する |

さらに、作業ディレクトリから**上に向かって**各階層の `CLAUDE.md` が読まれ、
サブディレクトリのものは Claude がそのディレクトリのファイルを読んだときに追加されます。

判断基準はひとつだけです。

> **他のリポジトリでも同じことを言うか？ → Yes なら user スコープ、No ならリポジトリ側。**

`git worktree で作業する` `main に直接コミットしない` `日本語で答える` は前者。
`home-manager switch を実行しない` `ref/ を編集しない` は後者です。

---

## 3. rules/ — トピック分割とパススコープ

`CLAUDE.md` は 1 ファイル **200 行未満**が公式の目安です
(長いほどコンテキストを食い、追従率が落ちる)。溢れる分は `rules/` に切り出します。

```
~/.claude/
├── CLAUDE.md          # 常に読まれる。全体の方針と索引
└── rules/
    ├── git-worktree.md   # 常に読まれる
    ├── git-workflow.md   # 常に読まれる
    └── nix.md            # paths: に一致するファイルを読んだときだけ
```

frontmatter の `paths:` を書くと**そのグロブに一致するファイルを Claude が読んだときだけ**
読み込まれます。常時載せる必要のない細則はこれで節約できます。

```markdown
---
paths:
  - "**/*.nix"
  - "**/flake.lock"
---

# Nix / Home Manager
...
```

`paths:` の無い rules は常に読まれるので、**分割自体はコンテキストの節約になりません**
(整理のためのもの)。節約したいなら `paths:` を付けるか、そもそも書かないかです。

`@path/to/file` 記法での import もありますが、こちらも起動時に展開されるので同様です。

---

## 4. このリポジトリでの配り方

`home/claude-code/` が user スコープの配布元です。

```
home/claude-code/
├── default.nix        # programs.claude-code の設定
├── CLAUDE.md          # → ~/.claude/CLAUDE.md
└── rules/
    ├── git-worktree.md   # → ~/.claude/rules/git-worktree.md
    ├── git-workflow.md
    └── nix.md            # paths: **/*.nix
```

`default.nix` の要点はこれだけです。

```nix
programs.claude-code = {
  enable = true;
  package = pkgs.claude-code;   # nix-claude-code オーバーレイの公式バイナリ

  context = ./CLAUDE.md;        # → <configDir>/CLAUDE.md
  rulesDir = ./rules;           # → <configDir>/rules/
};
```

`configDir` の既定は `~/.claude` です。`rules = { <名前> = <内容>; }` という
書き方もありますが、**`rulesDir` にしておけば Markdown を置くだけで増やせる**ので
そちらを選んでいます。

`home/cli/` ではなくトップレベルの `home/claude-code/` に置いているのは、
シェル統合を持つ CLI ではなく「Markdown の設定ツリーを配るモジュール」だからです
(`home/editors/` と同じ扱い)。

リポジトリ側 (project スコープ) はふつうに git で管理しています。

```
CLAUDE.md                    # dotfiles-nix 固有の方針
.claude/rules/
├── nix-modules.md           # paths: flake.nix, hosts/**, home/**
└── docs.md                  # paths: README.md, docs/**, docker/**, plans/**
```

---

## 5. ルールを足す・直す手順

### 全プロジェクト共通のルールを足す

```bash
# 1. dotfiles-nix で編集 (worktree を切ってから)
$EDITOR home/claude-code/rules/<topic>.md

# 2. flake は git 管理下のファイルしか見ない
git add home/claude-code/rules/<topic>.md

# 3. 評価チェック
nix flake check --no-build

# 4. 適用 (人間が実行する)
home-manager switch --flake .#zenimoto@ubuntu   # abbr: hms
```

### リポジトリ固有のルールを足す

そのリポジトリの `CLAUDE.md` か `.claude/rules/<topic>.md` を編集してコミットするだけです。
Nix も switch も要りません。

### 反映を確認する

| 見たいもの | コマンド |
| --- | --- |
| どのファイルが実際に読み込まれたか | セッション内で `/context` の **Memory files** |
| 指示ファイルの一覧・編集 | セッション内で `/memory` |
| 配られた実体 | `ls -l ~/.claude/CLAUDE.md ~/.claude/rules/` (Nix store への symlink) |

---

## 6. Nix で管理しないもの

| 対象 | 理由 |
| --- | --- |
| `~/.claude/settings.json` | Claude Code 自身が `/config`・ログイン・`/memory` のトグルで書き換える。Nix で配ると読み取り専用の symlink になり、書き込みが失敗する |
| `~/.claude/projects/<project>/memory/` (auto memory) | Claude がセッション中に書くファイル群。マシンローカルで良い |
| `~/.claude.json` | 認証情報とセッション状態 |

これは `~/.config/nvim` を Nix 管理外にしているのと同じ判断です
(→ [README のエディタの節](../../README.md#エディタ-neovim--lazyvim))。
**「ツール自身が書き込むファイルは Nix で配らない」**を原則にしています。

固定したい設定項目が出てきたら `programs.claude-code.settings` に書けますが、
その項目は CLI 側から変更できなくなります。

---

## 7. 書き方の指針

公式ガイドの要点と、この構成での運用方針です。

- **具体的に書く。** 「きれいに書く」ではなく「`rg` を使う。`grep -r` は使わない」。
  検証できる粒度まで落とすほど守られます。
- **短く保つ。** 1 ファイル 200 行未満。長い解説は `docs/` に置き、ルールからはリンクだけ張る。
- **矛盾を残さない。** user スコープとリポジトリ側で食い違うと、どちらが採用されるかは不定です。
  リポジトリ側には「共通ルールと違う部分」だけを書きます。
- **手順ではなくルールを書く。** 多段の手順や、特定の作業でしか要らないものは
  skill やコマンドに切り出す方が向いています。
- **HTML コメント (`<!-- ... -->`) はコンテキストに載る前に除去されます。**
  「この実体は dotfiles-nix にある」のような人間向けの注記はコメントで書けば
  トークンを消費しません。
- **必ず実行させたいことはルールではなく hook にする。** ルールは強制力を持ちません。

---

## 8. ハマりどころ

- **`~/.claude/CLAUDE.md` は Nix store への symlink なので直接編集できない。**
  セッション中に `#` で覚えさせようとしても書き込めません。共通ルールは
  dotfiles-nix 側を直して `home-manager switch`。その場の学習は auto memory に任せます。
- **`~/.claude/rules/` は「ディレクトリごと」symlink される。** 中に手でファイルを置くことは
  できません (確認済み)。その場限りのルールはリポジトリ側の `.claude/rules/` に書きます。
- **`home/claude-code/rules/` に Markdown を足しただけでは配られない。**
  flake は git 管理下のファイルしか見ないので `git add` が要ります
  (→ [git-worktree.md 9 章](../git/git-worktree.md#9-この構成-nix--flake--direnv-での注意))。
- **`paths:` の無い rules は常時読み込まれる。** 「分ければ軽くなる」わけではありません。
- **worktree では `.claude/settings.local.json` が付いてこない** (gitignore 済みのため)。
  `.claude/rules/` は git 管理下なので付いてきます。
- **`CLAUDE.md` は `/compact` 後に読み直されるが、サブディレクトリのものや
  `paths:` 付き rules は再注入されない。** 該当ファイルに触れた時点で再度読まれます。
- **サブエージェントは親の auto memory を引き継がない。** 共有したい前提は
  CLAUDE.md か rules に書きます。

---

## 関連ドキュメント

- [git-worktree.md](../git/git-worktree.md) — 並列エージェント運用と worktree のライフサイクル
- [nix-concepts.md](../nix/nix-concepts.md) — Home Manager が設定を配る仕組み
- [ref-tips.md](./ref-tips.md) — 他 dotfiles の Claude Code 周りの採用候補
- 一次情報: <https://code.claude.com/docs/en/memory> /
  home-manager の `programs.claude-code` オプション
