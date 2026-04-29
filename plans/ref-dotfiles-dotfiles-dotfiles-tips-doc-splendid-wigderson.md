# ref/ dotfiles から自分の dotfiles に取り入れる候補のドキュメント化

## Context

`ref/ryoppippi-dotfiles` と `ref/kawarimidoll-dotfiles` には、現在の `dotfiles-nix` には無い実用的な工夫が多数含まれている。これらを「カテゴリ別ドキュメント＋チェックリスト」としてまとめておけば、ユーザーが取り入れたいものを後からチェックして実装フェーズで一気に反映できる。

本タスクは **2 フェーズ構成**：

1. **今回（本プラン）**: `docs/ref-tips/` 配下にカテゴリ別の候補集ドキュメントを作成する。各項目はチェックボックス `- [ ]` 付き。
2. **次回（チェック後）**: ユーザーが `[x]` を付けた項目だけを Nix モジュール / dotfiles に実装する。

ユーザー回答により方針確定済み:

- 配置: `docs/ref-tips/` 配下にカテゴリ別分割
- スコープ: 両 dotfiles から網羅的に列挙（フィルタしない）
- 粒度: 概要 + メリット/デメリット + 使い方 + 参照パス

---

## ドキュメント構成

```
docs/ref-tips/
├── README.md                  # 全体インデックス + 凡例 + 進め方
├── 01-shell-fish.md           # ryoppippi: fish abbr/functions/key bindings
├── 02-shell-zsh-zeno.md       # kawarimidoll: zeno snippets / ZLE widget
├── 03-git.md                  # 両者: alias / custom git-* / git-hooks
├── 04-neovim.md               # 両者: keymap / mini.nvim / プラグイン管理
├── 05-terminal-ghostty.md     # 両者: declarative config / scrollback in vim
├── 06-claude-code.md          # 両者: CLAUDE.md / agents / skills / hooks
├── 07-karabiner.md            # ryoppippi: TypeScript で Karabiner
├── 08-nix-tooling.md          # ryoppippi: overlays / git-hooks / agent-skills-nix
├── 09-cli-tools.md            # 両者: delta, bit, comma, lazygit, dust, eza, ghq 連携
├── 10-macos.md                # ryoppippi: defaults write / Homebrew Cask の追加候補
└── 11-scripts-misc.md         # 両者: bin/ 以下の便利スクリプト群
```

各ファイルの項目フォーマット（標準）：

```markdown
### - [ ] 項目名

- **概要**: 何をするものか（1-2 行）
- **参照**: `ref/<repo>/<path>:<line>` (引用 1-3 行)
- **メリット**: 取り入れることで得られるもの
- **デメリット/コスト**: 学習コスト・依存追加・好みの分かれる点
- **使い方**: どのキー / コマンドで発火するか
- **実装メモ**: 自分の dotfiles のどこに入れるか（home/cli/foo.nix など）
```

---

## 各ファイルに載せる候補項目（網羅リスト）

### 01-shell-fish.md

- `git pf` = `push --force-with-lease --force-if-includes`（安全 force-push）
- `git rbm` = `rebase origin/main`、`git smu` = submodule 一括更新
- `cl/clo/clh` = claude / claude --model opus / haiku の短縮
- `dc/dcu/dcub/dcd/dcr` = docker compose 系
- `dr` = `deno run -A --unstable` + キャッシュクリア関数
- `ngc` = `nix-collect-garbage`、`nrn` = `nix run nixpkgs#<...>`（カーソル位置保持）
- 関数 `fkill`: fzf でプロセス選択して kill
- 関数 `npkill`: node_modules を並列で `/tmp` に退避削除
- 関数 `gh-q`: GitHub GraphQL → 検索 → clone → cd
- 関数 `__ghq_roots`: ghq 配下を fzf で検索 → cd（Ctrl+G）
- `fish_right_prompt`: 30 秒以上のコマンドに `notify-send`（nvim 等は除外）
- `fish_user_key_bindings`: Ctrl+G/Ctrl+B/Ctrl+X Ctrl+K に fkill/git switch/ghq
- FZF env: ripgrep + bat プレビュー + Ctrl+R で `?` プレビュートグル

参照: `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`、`fish/functions/`、`fish/config/fzf.fish`

### 02-shell-zsh-zeno.md

> 自分は fish 主体だが「abbr 設計」のヒントとして紹介。
> Nix 版 `nix-zeno` 相当は無いので、fish `abbr` で代替実装する想定。

- スペース後展開のグローバル abbr: `G`→`| rg`, `L`→`| less`, `NL`→`> /dev/null 2>&1`
- `mkcd`, `cds`（tmp + git init）等の生活系スニペット
- ZLE ウィジェット相当のアイデア:
  - `^x^f`: ghq 配下 fzf cd（fish 版に移植可）
  - `^x^e`: コマンドラインを vim で編集（fish 既定でも `Alt-e`）
  - `fancy-ctrl-z`: バッファ空なら `fg`、そうでなければ push-input
  - 末尾引数削除 `^x^w`

参照: `ref/kawarimidoll-dotfiles/.config/zeno/config.yml`、`.config/zsh/lazy.zsh`

### 03-git.md

ryoppippi 系（Nix で Hooks 統合）:

- `programs.git` への `delta` 統合（diff 見栄え）
- Nix で commit-msg / pre-commit / pre-push を宣言（`nix/modules/home/git-hooks.nix`）
- `bit` (git ラッパー)、`git-now`、`git-wt`（worktree 管理）の導入

kawarimidoll 系（`bin/` のカスタム git サブコマンド）:

- `git quicksave`: stage + commit + push を 1 発（タイムスタンプ commit）
- `git remember`: fzf でログ選択 → hash 抽出（プレビュー付き）
- `git abort`: rebase/merge/cherry-pick/revert/bisect を自動判定して abort
- `git push-with-check`: WIP ブランチ名/コミットメッセージを禁止 + origin/HEAD 比較
- `wta`: `git worktree add` ラッパー（`.env`/`.claude` を自動シンボリックリンク）
- `wtb` / `wtd`: worktree branch 削除 / worktree 削除

両者共通:

- `lazygit` の追加（home/cli/lazygit.nix 新規）
- `gh` と git の credential 統合は既に有り → 維持

参照:

- `ref/ryoppippi-dotfiles/nix/modules/home/git-hooks.nix`
- `ref/kawarimidoll-dotfiles/bin/git-*`

### 04-neovim.md

> 現状 `home/editors/neovim.nix` は本体だけ入れる最小構成。本格構成化の候補。

ryoppippi:

- 80+ プラグイン構成（参考枠、丸ごと採用は重い）
- 注目キーマップ:
  - `0` を「行頭が空白だけなら 0、それ以外は ^」に切替
  - `i`/`A` を空行なら `cc`（インデント自動）
  - `j`/`k` の大ジャンプを jumplist に記録（`m'` 自動付与）
  - タブ: `<Tab>`/`<S-Tab>` で次/前、`th/tj/tk/tl` で端へ
  - `:` と `;` の入れ替え
- 自作プラグイン `nvim-in-the-loop`（参考紹介のみ）

kawarimidoll（mini.nvim 派, 軽量構成の手本）:

- `vim.loader.enable()` でキャッシュ起動高速化
- `mini.deps` でプラグインマネージャ自前運用（外部不要）
- `mini.pick` / `mini.files` / `mini.cmdline`（`<space>f/e/d`）
- `XDG_STATE_HOME=/tmp` で undodir を一時化（永続不要派向け）
- `Grep` コマンド (ripgrep 統合) の `<space>/`

実装方針案（プラン分岐）:

- (A) Nix で本体 + treesitter/lsp サーバ群だけ提供、設定は `~/.config/nvim/` に直書き
- (B) `programs.neovim.plugins` で全プラグイン Nix 化（再現性高、起動微増）

参照:

- `ref/ryoppippi-dotfiles/nvim/lua/config/keymaps.lua`
- `ref/kawarimidoll-dotfiles/.config/nvim/init.lua`

### 05-terminal-ghostty.md

> 現状は wezterm のみ。ghostty 追加 or 移行の候補。

- ryoppippi: declarative ghostty を `programs.ghostty` 相当で記述
- kawarimidoll:
  - GLSL シェーダ (`gradient-background.glsl`, `cursor-blaze.glsl`)
  - **scrollback を vim で編集** (`super+shift+a` → `write_screen_file:paste` → vim ターミナル)
  - 分割 resize モード、`Shift+Enter = CSI u`
- WezTerm にも応用可能な keybind（split / resize）の参考

参照:

- `ref/kawarimidoll-dotfiles/.config/ghostty/config`
- `ref/ryoppippi-dotfiles/nix/modules/home/programs/ghostty*`

### 06-claude-code.md

ryoppippi (Agent Skills 群):

- `commit`: Conventional Commits 自動分割
- `create-pr`: branch → commit → push → PR 一括
- `fix-ci`: CI 失敗の修正提案
- `merge-main`: main 取り込み + 競合解決
- `pr-apply-review`: レビューコメント反映
- `tdd`: TDD フロー支援
- `council`: 複数エージェント協議型レビュー
- `session-summary-japanese`: セッション末に日本語サマリ
- `agent-skills-nix` で `~/.config/claude/skills/` に Nix から配布

kawarimidoll:

- 9 種のサブエージェント（commit-maker / pr-maker / reviewer / rebaser / reworder 他）
- `hooks/notification.sh` (Pushover で待機通知)
- カスタム skill: `agent-memory`, `grill-me`, `oss-research`
- CLAUDE.md の規約: ドキュメント層 / 通信スタイル / `z-ai/` を gitignore
- 「RTK」系コマンド書き換え（トークン削減）

横断:

- `claude/CLAUDE.md` ユーザー方針（UK 英語、JSDoc、コメント方針）
- `claude/rules/` 分割（tools.md, nix.md, ai-assistance.md, web-fetch.md）
- 出力スタイル（お嬢さま口調 等）

参照:

- `ref/ryoppippi-dotfiles/claude/`, `nix/modules/home/programs/agent-skills*`
- `ref/kawarimidoll-dotfiles/.config/claude/`

### 07-karabiner.md

> macOS 専用。Linux マシンでは対象外。

- TypeScript で Karabiner 設定を生成（`bun run build` / watch）
- Vim 風 hjkl → 矢印（Fn 修飾）
- Tap = Tab / Hold = 修飾キー の Dual-Function
- Left Ctrl 単押し → Escape
- App ごとの bundle id 条件分岐
- `darwin/` から `home.file."Library/.../karabiner.json".source` で配布する案

参照: `ref/ryoppippi-dotfiles/karabiner/`

### 08-nix-tooling.md

- `overlays/` で AI ツール（claude-code, codex, cursor-agent, opencode 等）をカスタムビルド
- `git-hooks.nix` で commit-msg/pre-commit/pre-push を宣言的にインストール
- `agent-skills-nix` パターン（任意ファイル群を `~/.config/...` に展開する仕組み）
- `programs.direnv.nix-direnv.enable` 強化案（既に有るなら維持）
- `programs.fish.plugins` を `pkgs.fishPlugins` で固定（既に実施済み → 維持）
- `comma` (`nix-community/comma`) でインストールせず一時実行
- `devenv` 導入（プロジェクト別シェル）

参照: `ref/ryoppippi-dotfiles/nix/modules/`, `flake.nix`

### 09-cli-tools.md

ryoppippi 由来:

- `delta` (git diff 見やすく) ← `programs.git.delta.enable`
- `dust` (du の見やすい版)
- `trash-cli` (rm 代替)
- `bit` (git ラッパー)
- `comma` (一時実行)
- `lazygit` (TUI git)
- `git-lfs`

kawarimidoll 由来:

- `fffe`: fd + fzf + エディタ統合（複数ファイル選択編集）
- 24-bit color チェッカ、`centering`、`mov_to_mp4`、`wakeup`(caffeinate)

横断:

- fzf × ripgrep × bat 統合 env を fish.nix に注入
- `eza` の icons / git-status flag セット見直し
- `bat` テーマと `--style` 既定値見直し

### 10-macos.md

> 現状 darwin/ にある defaults write を増強する候補（macOS のみ実装）。

- Homebrew Cask 追加候補: WezTerm / Ghostty / Zed / Raycast / 1Password / Karabiner-Elements
- `system.defaults.NSGlobalDomain` 系の追加項目（KeyRepeat, InitialKeyRepeat, AppleShowAllExtensions 等）
- Touch ID for sudo（`security.pam.enableSudoTouchIdAuth`）
- Dock / Finder / TextEdit のデフォルト調整

参照: `ref/ryoppippi-dotfiles/nix/modules/darwin/`

### 11-scripts-misc.md

- `bin/fffe`（fd+fzf+editor 一括）
- `bin/wakeup`（caffeinate ラッパー）
- `bin/24-bit-color`（端末カラー確認）
- `bin/centering`（テキスト中央寄せ）
- `bin/mov_to_mp4` / `deno-init` 等の生活系
- `scripts/` への配置 or `home.packages` で `pkgs.writeShellApplication` 化のどちらか

参照: `ref/kawarimidoll-dotfiles/bin/`

---

## 作業手順（実装フェーズで実行）

### Step 1: ドキュメント生成（今回承認後すぐ）

1. `docs/ref-tips/` を作成
2. `README.md` を書く（凡例・各ファイルへのリンク・使い方）
3. 上記 11 ファイルを作成。各項目は `- [ ] 項目名` の H3 見出し + 標準フォーマット 4 ブロック
4. 各項目の **参照** 欄には `ref/<repo>/<path>:<line>` を必ず付ける（後で実装時に再読しやすくするため）

### Step 2: ユーザーがチェック（手動）

ユーザーが各ファイルを開き `[ ]` → `[x]` に書き換える。

### Step 3: チェック済み項目の実装（次回セッション）

1. `git grep -n '\- \[x\]' docs/ref-tips/` でチェック済み項目を抽出
2. 該当する `ref/` 内のファイルを Read で再確認
3. `home/`, `darwin/`, `home/cli/` 等に Nix モジュール追加 / 既存編集
4. `nix run .#switch` 相当でビルドが通ることを検証
5. fish の場合は `home/shell/fish.nix` の `interactiveShellInit` / `shellAbbrs` / `functions` を編集

---

## 修正対象ファイル（ドキュメント生成時）

新規作成のみ:

- `docs/ref-tips/README.md`
- `docs/ref-tips/01-shell-fish.md`
- `docs/ref-tips/02-shell-zsh-zeno.md`
- `docs/ref-tips/03-git.md`
- `docs/ref-tips/04-neovim.md`
- `docs/ref-tips/05-terminal-ghostty.md`
- `docs/ref-tips/06-claude-code.md`
- `docs/ref-tips/07-karabiner.md`
- `docs/ref-tips/08-nix-tooling.md`
- `docs/ref-tips/09-cli-tools.md`
- `docs/ref-tips/10-macos.md`
- `docs/ref-tips/11-scripts-misc.md`

既存ファイルの編集なし（実装フェーズまで触らない）。

---

## 実装フェーズで参照する重要ファイル（再確認用）

- `ref/ryoppippi-dotfiles/fish/config/abbrs_aliases.fish`
- `ref/ryoppippi-dotfiles/fish/functions/`（fkill, npkill, gh-q, \_\_ghq_roots, fish_right_prompt, fish_user_key_bindings）
- `ref/ryoppippi-dotfiles/nix/modules/home/`（git-hooks.nix, programs/, agent-skills\*）
- `ref/ryoppippi-dotfiles/karabiner/karabiner.ts`
- `ref/ryoppippi-dotfiles/claude/`, `agents/skills/`
- `ref/kawarimidoll-dotfiles/.config/zeno/config.yml`
- `ref/kawarimidoll-dotfiles/.config/zsh/lazy.zsh`
- `ref/kawarimidoll-dotfiles/.config/nvim/init.lua`
- `ref/kawarimidoll-dotfiles/.config/ghostty/config`
- `ref/kawarimidoll-dotfiles/.config/claude/`（CLAUDE.md, settings.json, agents/, hooks/notification.sh, skills/）
- `ref/kawarimidoll-dotfiles/bin/`（git-\*, wta, wtb, wtd, fffe, wakeup ほか）

自分の dotfiles 側の主要編集候補:

- `home/shell/fish.nix`
- `home/git.nix`
- `home/editors/neovim.nix`
- `home/cli/`（lazygit.nix, delta は git.nix 内, dust.nix など新設）
- `home/wezterm.nix` or 新設 `home/ghostty.nix`
- `darwin/`（defaults write, Homebrew Cask 追加）
- `home/claude.nix` 新設（agent skills / hooks 配布）

---

## 検証方法（Step 1 完了時）

- `ls docs/ref-tips/` で 12 ファイル存在確認
- `grep -c '\- \[ \]' docs/ref-tips/*.md` で各ファイルの候補数を表示
- `docs/ref-tips/README.md` から各ファイルへのリンクが切れていないこと
- ユーザーが任意ファイルを開いてチェックボックスを書き換えられる

検証方法（Step 3 完了時）:

- `nix flake check` (or `nix build .#homeConfigurations...`) が通る
- `home-manager switch --flake .` (or `darwin-rebuild switch --flake .`) が成功
- 該当ツール / キーバインドが実際に動く（fish 起動、git エイリアス試行 等）
