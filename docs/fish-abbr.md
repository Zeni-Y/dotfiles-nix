# fish の補完と短縮入力 (abbreviation)

「コマンドのオプション候補を出す」「よく使うコマンドを短く打つ」の 2 つを
このリポジトリでどう解決しているかをまとめます。

---

## 目次

1. [補完はほぼ何もしなくても効く](#1-補完はほぼ何もしなくても効く)
2. [abbreviation を alias より優先する理由](#2-abbreviation-を-alias-より優先する理由)
3. [定義済み abbreviation 一覧](#3-定義済み-abbreviation-一覧)
4. [追加・変更のしかた](#4-追加変更のしかた)
5. [注意点](#5-注意点)

---

## 1. 補完はほぼ何もしなくても効く

`<Tab>` を押したときのオプション候補は、4 つの供給源から来ます。
いずれもこのリポジトリで個別に設定を書いているわけではありません。

| 供給源 | 対象 | 実体 |
| --- | --- | --- |
| fish 内蔵 | git, ssh, systemctl など約 1000 コマンド | fish 本体に同梱。git はブランチ名や各オプションの説明まで出る |
| パッケージ同梱 | herdr, gh, uv, jq, rsync, eza, zoxide … | 各パッケージが `share/fish/vendor_completions.d/*.fish` を置く。herdr は clap 生成の 383 行 |
| Home Manager 生成 | man ページを持つその他のコマンド | `programs.fish.generateCompletions` (既定 on) が man から機械生成し `~/.local/share/fish/home-manager/generated_completions/` に置く |
| 履歴 | 過去に打ったコマンド全部 | fish の autosuggestion (灰色のゴースト表示、`→` で確定) と fzf.fish の `Ctrl-r` |

確認したいときは実際に候補数を数えられます。

```fish
count (complete -C "git switch --")   # fish 内蔵の git 補完
count (complete -C "herdr ")          # herdr 同梱の補完
```

### alias にも補完が引き継がれる

`hd` (= `herdr`) のような alias も補完が効きます。Home Manager の
`programs.fish.shellAliases` は fish の `alias` builtin を使うため、生成されるのは
単なる別名ではなく `--wraps` 付きの関数だからです。

```fish
function hd --wraps=herdr --description 'alias hd herdr'
    herdr $argv
end
```

`--wraps=herdr` があるので、`hd <Tab>` は herdr の補完定義をそのまま使います。

---

## 2. abbreviation を alias より優先する理由

短縮入力には alias ではなく **abbreviation (`abbr`)** を使っています。
abbr はスペースか Enter を打った瞬間に、**コマンドラインの文字列そのものを**
展開します。

```
gst<Space>   →   git status --short --branch
                 ^ この時点で画面上の文字が置き換わる
```

| | abbr | alias |
| --- | --- | --- |
| 画面と履歴に残るもの | 展開後の完全なコマンド | 短縮形のまま |
| 展開後の手直し | できる (オプションを足す・消す) | できない |
| 補完 | 展開後の実コマンドに対して効く | `--wraps` が要る |
| 覚え方 | 打つたびに元のコマンドが目に入る | 元のコマンドを忘れる |
| スクリプト内 | 効かない | 効かない |

履歴に完全なコマンドが残るのが実務上いちばん効きます。半年後に
`Ctrl-r` で履歴を漁ったとき、`gf` ではなく `git fetch --prune` と出るので
何をしたのかが分かります。

一方 `ls` → `eza --icons` のような**常に同じ意味で置き換えたいもの**は
alias のままにしています (毎回 `eza --icons` と展開されても嬉しくないため)。

---

## 3. 定義済み abbreviation 一覧

実行時の正確な一覧は `abbr --show` で出ます。

### git — `home/git.nix`

| 短縮 | 展開 |
| --- | --- |
| `gst` | `git status --short --branch` |
| `gd` / `gds` | `git diff` / `git diff --staged` |
| `gl` | `git log --oneline --graph --decorate --max-count=20` |
| `ga` / `gaa` | `git add` / `git add --all` |
| `gc` / `gca` | `git commit` / `git commit --amend` |
| `gcm` | `git commit -m "…"` (引用符の中にカーソルが入る) |
| `gb` | `git branch` |
| `gsw` / `gswc` | `git switch` / `git switch --create` |
| `gf` | `git fetch --prune` |
| `gp` / `gpl` | `git push` / `git pull` |
| `grb` | `git rebase` |
| `lg` | `lazygit` |

`checkout` ではなく `switch` を既定にしているのは、git 2.23 で
「ブランチを移る」と「ファイルを戻す」に分割された方が曖昧さが無いためです。
hunk 単位の add や rebase の並べ替えのような込み入った操作は `lg` (lazygit) に任せます。

### herdr — `home/herdr.nix`

| 短縮 | 展開 |
| --- | --- |
| `hd` | `herdr` (これだけ alias) |
| `hdl` | `herdr session list` |
| `hda` | `herdr session attach` |
| `hdc` | `herdr config check` |

`hdc` は設定を足したあとに不明キーが無いか確かめるためのもので、
[herdr.md](./herdr.md) でも設定変更のたびに実行するよう書いています。

### dotfiles 管理 — `home/shell/fish.nix`

| 短縮 | 展開 |
| --- | --- |
| `hms` | `home-manager switch --flake ~/ghq/dotfiles-nix#zenimoto@ubuntu` |
| `hmn` | `home-manager news --flake …` |
| `hmg` | `home-manager generations --flake …` |
| `nfc` | `nix flake check --no-build ~/ghq/dotfiles-nix` |
| `nfu` | `nix flake update --flake ~/ghq/dotfiles-nix` |

flake 構成では `--flake` を省略すると `~/.config/home-manager/home.nix` を
探しに行って `No configuration file found` で落ちるため、home-manager 系は
どのサブコマンドでも毎回 `--flake` が要ります。手で打つには長すぎるので
abbr にしています。

初回 switch だけ必要な `-b backup` は、`hms` を展開してから書き足せます
(abbr が alias より扱いやすい典型例)。

---

## 4. 追加・変更のしかた

**ツール固有の abbr は、そのツールのモジュールに置きます。**
`vi` / `vim` の alias を `home/editors/neovim.nix` に置いているのと同じ方針で、
「そのツールを外したら関連設定も一緒に消える」状態を保つためです。

```nix
# home/<tool>.nix
programs.fish.shellAbbrs = {
  foo = "some --long --command";
};
```

### カーソル位置を指定する

```nix
gcm = {
  expansion = ''git commit -m "%"'';
  setCursor = "%";   # 展開後、% があった位置にカーソルが来る
};
```

### 特定コマンドの後ろでだけ展開する

fish 4.6 以降はコマンド限定 abbr が使えます。グローバルな名前空間を
汚さずに済むので、2 文字の短い綴りを使いたいときに向いています。

```nix
# `git st` のときだけ展開される。単体の `st` は展開されない
st = {
  command = "git";
  expansion = "status";
};
```

反映は他の設定と同じで、`hms` (= `home-manager switch --flake …`) のあと
fish を開き直すだけです。

---

## 5. 注意点

- **fish 専用**。bash では abbr は効きません。bash は対話なら fish に
  `exec` する構成 (`home/shell/bash.nix`) なので実害はほぼありませんが、
  非対話の bash に落ちる経路では使えません。
- **シェルスクリプトでは効かない**。abbr も alias も対話シェルの機能です。
  スクリプトには展開後の完全なコマンドを書いてください。
- **展開されるのはコマンドの先頭語だけ**。`position` の既定が `"command"`
  なので、`echo gd` の `gd` のように引数位置に来たものは展開されません。
- **既存コマンドと綴りが衝突しないか確認する**。abbr はコマンド先頭で
  展開されるので、同名の実コマンドがあると意図せず置き換わります。
  追加前に `command -v <綴り>` で確認してください
  (現在の定義はすべて衝突が無いことを確認済み)。
