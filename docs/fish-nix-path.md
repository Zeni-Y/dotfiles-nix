# fish に Nix の PATH が通る仕組み

このリポジトリの `home/shell/fish.nix` には PATH を設定するコードが一切無いのに、
fish を起動すると最初から `nix` / `home-manager` / Nix プロファイル経由のコマンドに
パスが通っています。なぜ動くのかを順を追って説明します。

---

## 1. 結論

fish には `vendor_conf.d` という「**サードパーティのパッケージが起動時設定を置くための公式の口**」
があり、Determinate Systems の nix-installer はそこに `nix.fish` / `nix-daemon.fish`
を配置します。fish は `~/.config/fish/config.fish` を読むより前にこれらを自動 source
するため、ユーザの設定ファイルが Nix を一切知らなくても PATH が通ります。

```
fish 起動
  └─ vendor_conf.d/*.fish を自動読み込み           ← ここで Nix の PATH が通る
       /nix/var/nix/profiles/default/etc/profile.d/nix.fish
       /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
  └─ /etc/fish/conf.d/*.fish
  └─ ~/.config/fish/conf.d/*.fish                  ← home-manager のプラグイン読み込み
  └─ ~/.config/fish/config.fish                    ← home-manager が生成する本体
       └─ source .../hm-session-vars.fish          ← home.sessionVariables のみ
```

---

## 2. 「vendor」とは何か

英語の "vendor" は文字通りには「販売者・供給元」ですが、ソフトウェアの文脈では
**「自分（ユーザ／システム管理者）以外の供給元」** という意味で使われます。
転じて「他のパッケージが配置するファイルを置くための領域」を表す慣習的な接頭語に
なっています。

fish の場合、設定ファイル群は読み込み元によって 3 階層に分かれています:

| 階層 | ディレクトリ例 | 誰が置くか |
| --- | --- | --- |
| ユーザ | `~/.config/fish/conf.d/` | 自分 (もしくは自分が動かす home-manager) |
| システム | `/etc/fish/conf.d/` | OS の管理者 (apt や手動配置) |
| **vendor** | `<prefix>/share/fish/vendor_conf.d/` | **インストール先のパッケージ自身** |

「vendor 系ディレクトリ」は具体的には次の 3 つがあります:

- `vendor_conf.d/` … fish 起動時に自動 source される `*.fish`
- `vendor_functions.d/` … 関数定義を置く（`functions/` と同じ役割）
- `vendor_completions.d/` … 補完定義を置く（`completions/` と同じ役割）

つまり「nix というパッケージが、ユーザの設定ファイルを汚さずに自分の初期化スクリプト
を fish に読ませたい」というときに使う場所が vendor_conf.d、ということです。

### なぜ「vendor」と呼ぶのか

Linux の他のツールにも同じ命名規則があります（systemd の `/usr/lib/systemd/system/`
を「vendor unit」と呼ぶなど）。共通する考え方は:

> **管理者が編集すべきでない、パッケージ提供者が責任を持つ領域**

ユーザ／管理者が触るのは `~/.config/...` や `/etc/...`、パッケージ自身が触るのは
`share/.../vendor_*.d/`、と役割を明確に分離するための語彙です。

---

## 3. fish が vendor_conf.d を読む経路

fish は起動時に複数のディレクトリから vendor_conf.d を自動探索します。

1. **fish 本体の prefix 配下**
   `$__fish_data_dir/vendor_conf.d/`
   （ビルド時に決まる。`echo $__fish_data_dir` で確認可能）

2. **`XDG_DATA_DIRS` の各ディレクトリ配下**
   `XDG_DATA_DIRS` を `:` で分割し、それぞれの `fish/vendor_conf.d/` を見る

このリポジトリの構成 (Ubuntu + standalone home-manager + Determinate Nix) では:

- fish 本体は `~/.nix-profile/bin/fish` から提供される
- `$__fish_data_dir` は概ね `~/.nix-profile/share/fish` または fish パッケージの
  nix store パス配下
- そこから symlink / プロファイルマージで
  `/nix/var/nix/profiles/default/etc/profile.d/nix.fish` などにたどり着く

このため、bash の rc ファイルが nix-daemon.sh を一切読み込まない環境
（Docker コンテナ等）でも、fish を直接起動するだけで PATH が通ります。

---

## 4. 検証コマンド

実際に経路を確認したいときは fish 上で次を実行します。

```fish
# (a) bash 側で nix-daemon.sh が読まれているかを確認 → このリポジトリでは読まれない
grep -l 'nix-daemon\|nix.sh' \
    /etc/bash.bashrc /etc/profile /etc/zshrc ~/.bashrc ~/.profile 2>/dev/null

# (b) Determinate Nix が配置する fish 用ファイル
ls -la /nix/var/nix/profiles/default/etc/profile.d/ 2>/dev/null
# nix.fish と nix-daemon.fish が見えるはず

# (c) fish 自身の vendor_conf.d
echo $__fish_data_dir
ls -la $__fish_data_dir/vendor_conf.d/ 2>/dev/null

# (d) XDG_DATA_DIRS 経由の vendor_conf.d
for d in (string split ':' $XDG_DATA_DIRS)
    test -d $d/fish/vendor_conf.d/; and ls $d/fish/vendor_conf.d/
end

# (e) nix.fish への到達経路を symlink ごと辿る
find ~/.nix-profile /nix/var/nix/profiles \
     \( -name 'nix.fish' -o -name 'nix-daemon.fish' \) -ls 2>/dev/null
```

---

## 5. config.fish 8 行目の `hm-session-vars.fish` との違い

home-manager が生成する `~/.config/fish/config.fish` の冒頭にはこの行があります:

```fish
source /nix/store/.../hm-session-vars.fish/etc/profile.d/hm-session-vars.fish
```

これは **`home.sessionVariables` / `home.sessionPath`** に書いた値を fish に流し込む
ためのものです。Nix プロファイルそのものの PATH（`~/.nix-profile/bin` や
`/nix/var/nix/profiles/default/bin`）はここでは設定されません。

整理すると役割分担は次のとおりです:

| ファイル | 配置者 | 内容 |
| --- | --- | --- |
| `vendor_conf.d/nix.fish` | Nix インストーラ | Nix プロファイルの PATH を通す |
| `hm-session-vars.fish` | home-manager | `home.sessionVariables` の中身 |
| `~/.config/fish/config.fish` | home-manager | `programs.fish.*` の宣言を展開 |
| `~/.config/fish/conf.d/plugin-*.fish` | home-manager | `programs.fish.plugins` のロード |

---

## 6. まとめ

- fish には **vendor_conf.d** という「パッケージ供給元用」の自動ロード口がある
- "vendor" は「ユーザ／管理者ではなく、パッケージ提供側が触る領域」という意味
- Determinate Nix がそこに `nix.fish` を置くため、ユーザの設定ファイルが何も
  しなくても PATH が通る
- `hm-session-vars.fish` は別の役割（ユーザ定義の環境変数）であり、Nix プロファイル
  の PATH 設定はしていない
