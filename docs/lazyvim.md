# Neovim + LazyVim — 使い方とライフサイクル

エディタは Neovim に [LazyVim](https://www.lazyvim.org/) を載せた構成です。
**Neovim 本体と外部コマンドだけを Nix で管理し、エディタ設定とプラグインは
`~/.config/nvim` (Nix 管理外) に置く**、という分担になっています。

> 記載しているキーマップは、このリポジトリで実際に入っている LazyVim
> (`install_version: 8`, picker/explorer が **snacks** な世代) のものです。
> 現物は `<leader>sk` (Keymaps ピッカー) か `:map` で確認できます。

---

## 目次

1. [責務の分担](#1-責務の分担)
2. [ライフサイクル](#2-ライフサイクル)
3. [ファイルとディレクトリの役割](#3-ファイルとディレクトリの役割)
4. [基本操作](#4-基本操作)
5. [設定を変える](#5-設定を変える)
6. [LSP・フォーマッタ・リンタ](#6-lspフォーマッタリンタ)
7. [更新・ロールバック・作り直し](#7-更新ロールバック作り直し)
8. [ハマりどころ](#8-ハマりどころ)

---

## 1. 責務の分担

| 層 | 管理者 | 実体 |
| --- | --- | --- |
| Neovim 本体 / nodejs / tree-sitter | Nix (`home/editors/neovim.nix`) | `~/.nix-profile/bin/nvim` |
| LazyVim が要求する外部コマンド (git, ripgrep, fd, lazygit, gcc, make, curl, unzip) | Nix (`home/packages.nix`, `home/git.nix`) | 同上 |
| `EDITOR` / `VISUAL` / `vi`・`vim` エイリアス | Nix (`home/editors/neovim.nix`) | セッション変数とシェル alias |
| **エディタ設定 (options / keymaps / plugins)** | **ユーザ (Nix 管理外)** | `~/.config/nvim/` |
| **プラグイン本体** | **lazy.nvim** | `~/.local/share/nvim/lazy/` |
| **LSP サーバ・フォーマッタ** | **mason.nvim** | `~/.local/share/nvim/mason/` |

`programs.neovim` (Home Manager のモジュール) を**あえて使っていません**。
あれは `~/.config/nvim/init.lua` を Nix store 上に生成して symlink するため、

- LazyVim starter が置く `init.lua` と衝突する
- `lazy-lock.json` のように **Neovim 自身が書き込むファイル**を置けない
  (symlink 先が読み取り専用の Nix store になる)

という二重の理由で LazyVim と噛み合いません。
代わりに失われる `defaultEditor` / `viAlias` / `vimAlias` は、
`home.sessionVariables` とシェルの `shellAliases` で補っています
(alias なので、スクリプト中の `vim ...` はシステムの vim に落ちる点だけ注意)。

つまり **`home-manager switch` でエディタの設定は変わらないし、世代を切り戻しても
戻りません**。これは意図的なトレードオフです (プラグイン更新のたびに Nix を
リビルドしなくてよい / マシン間の再現性は `~/.config/nvim` を自分で git 管理して担保する)。

---

## 2. ライフサイクル

```
1. home-manager switch
     └─ activation (lazyvimStarter)
          ├─ ~/.config/nvim が「無いときだけ」LazyVim starter を clone
          │    (.git は削除。以降は完全に自分の設定として扱える)
          └─ 既にあれば一切触らない  ← 2 回目以降の switch は no-op

2. 初回 nvim 起動
     ├─ init.lua → lua/config/lazy.lua が lazy.nvim を bootstrap
     │    (~/.local/share/nvim/lazy/lazy.nvim に clone)
     ├─ LazyVim 本体 + 既定プラグインを取得してインストール
     └─ 取得したリビジョンを ~/.config/nvim/lazy-lock.json に固定

3. 日常
     ├─ :Lazy            プラグインの状態確認・インストール・削除
     ├─ :Lazy update     更新して lazy-lock.json を書き換え
     ├─ :LazyExtras      言語サポート等の Extra を有効化 (lazyvim.json に記録)
     ├─ :Mason           LSP / フォーマッタのインストール
     └─ :checkhealth     外部コマンドや設定の不足チェック

4. 壊れた・作り直したい
     └─ rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
        home-manager switch   → starter を取り直して 2. からやり直し
```

activation が clone に失敗したとき (ネットワークが無い環境など) は警告を出して
switch 自体は続行します。後から手動でやるなら:

```bash
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
```

---

## 3. ファイルとディレクトリの役割

| パス | 誰が書く | 中身 |
| --- | --- | --- |
| `~/.config/nvim/init.lua` | starter (以後ユーザ) | `lua/config/lazy.lua` を読むだけ |
| `~/.config/nvim/lua/config/options.lua` | ユーザ | `vim.opt.*` (LazyVim 既定の上書き) |
| `~/.config/nvim/lua/config/keymaps.lua` | ユーザ | 追加・上書きするキーマップ |
| `~/.config/nvim/lua/config/autocmds.lua` | ユーザ | autocmd |
| `~/.config/nvim/lua/config/lazy.lua` | starter | lazy.nvim の bootstrap と LazyVim の読み込み |
| `~/.config/nvim/lua/plugins/*.lua` | ユーザ | プラグインの追加・上書き (ファイル名は自由) |
| `~/.config/nvim/lazy-lock.json` | lazy.nvim | プラグインの固定リビジョン (**git 管理推奨**) |
| `~/.config/nvim/lazyvim.json` | LazyVim | 有効化した Extra の一覧 |
| `~/.local/share/nvim/lazy/` | lazy.nvim | プラグインの実体 |
| `~/.local/share/nvim/mason/` | mason.nvim | LSP / フォーマッタのバイナリ |
| `~/.local/state/nvim/` | Neovim | undo 履歴・shada・セッション・ログ |

`~/.config/nvim` ごと別リポジトリで管理したい場合は、そこで `git init` して push すれば
よいだけです。この dotfiles 側は「無ければ starter を置く」以上のことをしません。

---

## 4. 基本操作

`<leader>` は **Space**。`<leader>` を押して少し待つと **which-key** が
候補一覧を出すので、キーを覚えていなくても辿れます。
`<leader>sk` で全キーマップをあいまい検索できます。

### VS Code との対応

| VS Code | LazyVim | キー |
| --- | --- | --- |
| エクスプローラー | snacks.explorer | `<leader>e` (root) / `<leader>E` (cwd) |
| Ctrl+P (ファイル検索) | snacks.picker | `<leader><space>` または `<leader>ff` |
| Ctrl+Shift+F (全文検索) | snacks.picker | `<leader>/` または `<leader>sg` |
| 開いているファイルのタブ | bufferline | `<S-h>` / `<S-l>` |
| エディタ分割 | ウィンドウ | `<leader>\|` (右) / `<leader>-` (下) |
| ソース管理パネル | lazygit | `<leader>gg` |
| 差分表示 (行の gutter) | gitsigns | `]h` / `[h` で hunk 移動 |
| IntelliSense | nvim-lspconfig + blink.cmp + mason | `gd` / `K` / `<leader>ca` |
| 問題パネル | trouble | `<leader>xx` |
| 統合ターミナル | snacks.terminal | `<C-/>` |
| Ctrl+Shift+H (置換) | grug-far | `<leader>sr` |

### 「新しいタブを開く」— バッファ / ウィンドウ / タブページ

Neovim の「タブ」は VS Code のタブとは意味が違います。ここを混同しやすいので整理します。

| 概念 | 実体 | 主な操作 |
| --- | --- | --- |
| **バッファ** | 開いているファイル 1 つ。VS Code の「タブ」に相当し、bufferline に並ぶ | 次/前: `<S-l>` / `<S-h>`、閉じる: `<leader>bd`、一覧: `<leader>,` |
| **ウィンドウ** | 画面の分割領域。VS Code の「エディタグループ」 | 分割: `<leader>\|` / `<leader>-`、移動: `<C-h/j/k/l>`、閉じる: `<leader>wd`、最大化: `<leader>wm` |
| **タブページ** | ウィンドウ配置一式のセット。VS Code に相当物なし (近いのはウィンドウ) | 新規: `<leader><tab><tab>`、次/前: `<leader><tab>]` / `<leader><tab>[`、閉じる: `<leader><tab>d`、他を閉じる: `<leader><tab>o` |

日常的に使うのはバッファとウィンドウで、タブページはあまり使いません。
「作業一式を切り替えたい」なら、Neovim のタブページより
**herdr のタブ / workspace** ([docs/herdr.md](./herdr.md)) を使うほうが素直です。

### よく使うキー

| 操作 | キー |
| --- | --- |
| ファイル検索 (プロジェクトルート) | `<leader><space>` / `<leader>ff` |
| 最近開いたファイル | `<leader>fr` |
| 全文検索 (grep) | `<leader>/` / `<leader>sg` |
| カーソル下の語を検索 | `<leader>sw` |
| バッファ一覧 | `<leader>,` |
| ファイルツリー | `<leader>e` |
| 定義へジャンプ / 参照一覧 | `gd` / `gr` |
| ホバードキュメント | `K` |
| コードアクション / リネーム | `<leader>ca` / `<leader>cr` |
| 診断一覧 (trouble) | `<leader>xx` |
| フォーマット | `<leader>cf` |
| lazygit | `<leader>gg` |
| git status / diff ピッカー | `<leader>gs` / `<leader>gd` |
| ターミナル (トグル) | `<C-/>` |
| 保存 | `<C-s>` |
| プラグイン管理画面 | `<leader>l` |
| Extra の有効化 | `:LazyExtras` |
| 全部終了 | `<leader>qq` |
| セッション復元 (persistence) | `<leader>qs` |
| ジャンプ (flash) | `s` |
| キーマップ検索 | `<leader>sk` |

---

## 5. 設定を変える

| やりたいこと | 触る場所 |
| --- | --- |
| オプション (行番号・インデント・折返しなど) | `~/.config/nvim/lua/config/options.lua` |
| キーマップの追加・上書き | `~/.config/nvim/lua/config/keymaps.lua` |
| autocmd | `~/.config/nvim/lua/config/autocmds.lua` |
| プラグイン追加 / 既定プラグインの上書き・無効化 | `~/.config/nvim/lua/plugins/*.lua` |
| 言語サポートなどの一括有効化 | `:LazyExtras` |
| カラースキーム | `lua/plugins/*.lua` で `LazyVim` の `opts.colorscheme` |

`~/.config/nvim/lua/plugins/` に置いた `.lua` は **lazy.nvim の spec を返すだけ**です。
starter の `lua/plugins/example.lua` に典型例が全部入っているので、まずそれを読むのが早いです。

```lua
-- ~/.config/nvim/lua/plugins/my.lua
return {
  -- プラグインを足す
  { "folke/todo-comments.nvim", opts = {} },

  -- LazyVim の既定設定を上書きする (同じ名前で opts を書くとマージされる)
  {
    "nvim-lualine/lualine.nvim",
    opts = { options = { globalstatus = false } },
  },

  -- 既定プラグインを無効化する
  { "folke/flash.nvim", enabled = false },

  -- LazyVim 本体のオプション (カラースキームなど)
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
```

なお LazyVim 既定の options (`number` / `relativenumber` / `expandtab` /
`tabstop=2` / `shiftwidth=2` / `ignorecase` / `smartcase` / `termguicolors` 等) は
このリポジトリが以前 Nix 側の `extraConfig` で持っていた値と同じなので、
移植は不要でした。変えたくなったら `options.lua` に書きます。

---

## 6. LSP・フォーマッタ・リンタ

入り口は 2 つあります。

1. **`:LazyExtras`** — 言語ごとの束 (LSP + treesitter パーサ + フォーマッタ設定) を
   まとめて有効化する。`lang.nix`, `lang.python`, `lang.typescript` など。
   選んだ内容は `~/.config/nvim/lazyvim.json` に記録され、再起動後に反映されます。
2. **`:Mason`** — 個別の LSP サーバ / フォーマッタをインストールする。
   実体は `~/.local/share/nvim/mason/` に落ちます。

不足している外部コマンドは `:checkhealth lazyvim` (と `:LazyHealth`) が教えてくれます。
`nodejs` は mason 経由で入る多くのサーバが要求するため Nix 側で入れてあります。

フォーマットは **conform.nvim** (`<leader>cf`、保存時自動フォーマットは
`<leader>uf` でトグル)、リントは **nvim-lint** が担当します。

---

## 7. 更新・ロールバック・作り直し

```vim
:Lazy update     " プラグインを更新し lazy-lock.json を書き換える
:Lazy restore    " lazy-lock.json のリビジョンに戻す (更新の切り戻し)
:Lazy clean      " spec から消えたプラグインを削除
:Lazy profile    " 起動時間のプロファイル
```

- **`lazy-lock.json` が Nix でいう `flake.lock`** です。これを git 管理していれば
  「同じプラグイン構成」を別マシンで再現できます。
- **Home Manager の世代とは無関係**です。`home-manager switch` を巻き戻しても
  プラグインは戻りません。戻したいときは `:Lazy restore`。
- 完全に作り直すとき:
  ```bash
  rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  home-manager switch --flake .#zenimoto@ubuntu   # starter を取り直す
  ```
  設定を残したい場合は `~/.config/nvim` を消す前に別リポジトリへ push しておくこと。

---

## 8. ハマりどころ

- **`~/.config/nvim` は Home Manager の管理下に無い**。switch をやり直しても、
  世代を切り戻しても、エディタの設定とプラグインは元に戻りません (意図的)。
  再現性が欲しければ `~/.config/nvim` 自体を git 管理してください。
- **activation は「無いときだけ」clone する**。既に `~/.config/nvim` があれば
  starter で上書きされることはありません (逆に言うと、starter が更新されても
  追従しません。追従したいときは
  <https://github.com/LazyVim/starter> の差分を自分で取り込みます)。
- **この構成に telescope も neo-tree も入っていない**。LazyVim
  `install_version: 8` 以降の既定は **snacks.picker / snacks.explorer** です。
  ネット上の記事が `<leader>ff` を telescope 前提で説明していても、キーは同じで
  実装だけが違う、と読み替えてください。telescope や neo-tree に戻したいなら
  `:LazyExtras` で `editor.telescope` / `editor.neo-tree` を有効化します。
- **`vim` はエイリアスなのでスクリプトからは効かない**。`vi` / `vim` は fish/bash の
  alias として定義しているだけなので、シェルスクリプト中の `vim ...` は
  システムの vim (あれば) に落ちます。確実に nvim を使いたい箇所では `nvim` と書きます。
- **mason が落としてくるバイナリは配布元のビルド済みバイナリ**です。
  Ubuntu ベースの環境 (このリポジトリの主対象) では問題ありませんが、
  NixOS ベースのコンテナ (`docker/working_nixos`) では動的リンカが無く
  起動できないことがあります。その場合は mason を使わず、必要な LSP を
  `home/packages.nix` に足して `lspconfig` から使うのが確実です。
- **`:checkhealth` の警告をまず読む**。外部コマンド不足 (fd / ripgrep / gcc など) は
  Nix 側の問題なので `home/packages.nix` を見ます。
