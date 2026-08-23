# 環境変数と秘密情報を 1Password + direnv で管理する

API キー・トークン・DB のパスワードといった秘密情報を、**平文の `.env` として
ディスクに置かない**ための構成。実体は 1Password の vault に置き、リポジトリには
`op://Vault/Item/field` という**参照だけ**を書いたテンプレートを置く。
参照を実際の値に変えるのはシェルに入った瞬間 (direnv) か、コマンドを走らせる
瞬間 (`op run`) だけで、値はプロセスの環境変数としてしか存在しない。

| 層 | 何を持つか | 実体 |
| --- | --- | --- |
| 保管 | 秘密そのもの | 1Password の vault |
| 参照 | `KEY=op://Vault/Item/field` | リポジトリの `.env.op` (コミットしてよい) |
| 注入 | プロセスの環境変数 | direnv の `use op` / `op run` |

関係するファイル:

| パス | 役割 |
| --- | --- |
| `home/cli/onepassword.nix` | `op` (1Password CLI) の導入と短縮入力 |
| `home/cli/direnv.nix` | direnv の `stdlib` に `use_op` を足す (`~/.config/direnv/direnvrc`) |
| `home/git.nix` | 全リポジトリ共通の gitignore で `.env` 系を落とす |

## 1. なぜこの形か

`.env` を平文で置く運用は、次のどれか 1 つで漏れる。

- `git add -A` でうっかりコミットする (履歴に残るので消すのが面倒)
- バックアップ・同期ツール・エディタのプロジェクト共有に紛れる
- ホームディレクトリを読めるプロセス (入れたばかりの CLI、エージェント) が読める

1Password に寄せると、**ディスク上に平文が無い**・**失効や共有を GUI 側で管理できる**・
**別マシンでも同じ参照で解決できる** の 3 つが同時に手に入る。参照 (`op://…`) は
値ではないのでコミットしてよく、「どのアイテムを使うのか」がリポジトリに残るのも利点
(新しいマシンや別の人が、何を用意すればいいか読み取れる)。

## 2. 全体像

```
1Password vault
  └─ Item: OpenAI  ├─ field: credential  ← 秘密の実体
                   
        ▲ op read / op inject (op CLI が取りに行く)
        │
リポジトリ                       シェル / プロセス
  .env.op   ── use op ──▶  OPENAI_API_KEY=sk-...   (direnv が cd で注入)
  .envrc                    ▲
  (どちらもコミットする)     └── op run --env-file=.env.op -- <cmd> でも同じ
```

ディスクに書かれるのは `.env.op` (参照だけ) と `.envrc` だけ。値はどこにも保存しない。

## 3. セットアップ

### 3-1. op を入れる

`home/cli/onepassword.nix` が `programs.onepassword.enable = true` (既定) で
Linux 版 `op` を入れる。**適用は人間が本体のチェックアウトから 1 回だけ**。

```fish
cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
home-manager switch --flake '.#zenimoto@ubuntu'
op --version
```

### 3-2. アカウントを登録してサインインする

初回だけアカウント登録が要る。サインインアドレス・メールアドレス・
**Secret Key** (1Password アプリの「アカウント」→「セットアップ用のコード / 秘密鍵」)
とマスターパスワードを聞かれる。

```fish
op account add --address my.1password.com --email <you@example.com>
```

以降はセッションを開くだけ。fish では `eval` ではなく `source` に流す
(`op` は `$SHELL` を見て fish 用の `set -gx …` を出力する)。

```fish
op signin | source     # 短縮入力: opsi
op whoami              # 短縮入力: opw
```

- セッションは**最終操作から 30 分**で切れる。切れたら再度 `op signin`。
- direnv から `use op` が呼ばれたときにサインインしていないと、
  `use op: 解決できなかった` が出て変数は設定されない。先に `op signin` する。

### 3-3. 動作確認

```fish
op read "op://Private/OpenAI/credential"
```

値が 1 行返れば設定完了。

### 3-4. (任意) WSL で Windows Hello を使う

WSL の Linux 版 `op` は Windows のデスクトップアプリ連携を使えないため、
サインインのたびにマスターパスワードを打つことになる。生体認証で済ませたい場合は
**Windows 側の op.exe を呼ぶ**構成に切り替えられる。

1. Windows 側で CLI を入れる: `winget install 1password-cli`
2. 1Password 8 の **設定 > 開発者 > 「1Password CLI と統合」** を有効にする
   (Windows Hello も有効にしておく)
3. `hosts/ubuntu.nix` のモジュールに次を足して switch

   ```nix
   programs.onepassword.useWindowsCli = true;
   ```

`op` は Windows 側 op.exe への薄いラッパになり、解錠は Windows Hello のダイアログで
行われる。direnv から非対話で呼ばれてもダイアログが出るので、`op signin` は不要になる。

**制約**: op.exe は Windows のプロセスなので、`op run -- <Linux コマンド>` は使えない
(子プロセスが Windows 側で起動してしまう)。値を stdout に出すだけの `op read` /
`op inject` — つまり `use op` — は問題なく動く。リモートの Ubuntu や Docker では
この切り替えは使えないので、既定 (Linux 版) のままにする。

## 4. 使い方

### 4-1. 1Password 側にアイテムを用意する

GUI で作るのが早い。CLI なら:

```fish
op item create --category "API Credential" --title OpenAI \
    --vault Private credential=sk-xxxxxxxx
```

参照 (`op://…`) は GUI の項目右クリック →「秘密の参照をコピー」で取れる。
CLI から確認するなら:

```fish
op item get OpenAI --vault Private --format json | jq -r '.fields[].reference'
```

### 4-2. `.env.op` を書く (リポジトリにコミットする)

```bash
# .env.op — 参照だけ。秘密は含まれないのでコミットしてよい
OPENAI_API_KEY=op://Private/OpenAI/credential
DATABASE_URL="op://Private/MyApp/database url"   # 空白を含むなら引用符で囲む
# STRIPE_KEY=op://Private/Stripe/api key         # 先頭 # はコメント
```

- 書式は `KEY=op://Vault/Item[/Section]/field`。`export ` を前置してもよい。
- 参照に**空白が含まれるときは `"` で囲む** (1Password 側の仕様。`use op` は
  囲みを外して読むので、囲んでも囲まなくても動く)。
- 使える文字は英数字と `-` `_` `.` と空白。それ以外を含む名前は、名前ではなく
  アイテムの ID で参照する。
- この書式は `op run --env-file` と同じなので、同じファイルを両方で使い回せる。

### 4-3. `.envrc` から呼ぶ

```bash
# .envrc
use op          # 既定で .env.op を読む。別名なら `use op .env.op.dev`
```

```fish
direnv allow
```

そのディレクトリに `cd` した時点で環境変数が入る。

```
direnv: loading .envrc
direnv: using op
direnv: 1Password から 2 件読み込んだ (.env.op)
```

`.env.op` を書き換えると `watch_file` により自動で読み直す。
nix-direnv と併用する場合は普通に併記できる。

```bash
# .envrc
use flake
use op
dotenv_if_exists .env.local   # 秘密でない上書き (ポート番号など) はこちらで
```

### 4-4. direnv を使わない渡し方

| やりたいこと | コマンド |
| --- | --- |
| 1 コマンドだけ環境変数付きで動かす | `op run --env-file=.env.op -- <cmd>` (短縮入力 `opr`) |
| 値を 1 個だけ取る | `op read "op://Private/OpenAI/credential"` |
| 設定ファイルのテンプレートを埋める | `op inject -i config.tmpl -o config.yaml` |

`op run` は子プロセスにだけ環境変数を渡し、標準出力に秘密が出たらマスクしてくれる。
CI や `docker compose` など direnv が効かない文脈ではこちらを使う。

**平文の `.env` をどうしても作らないといけない場合** (ファイルパスしか受け付けない
ツールなど) は、その場で作ってすぐ消す。`op inject` の出力ファイルは既定で 0600。

```fish
op inject -i .env.op -o .env; and docker compose up; rm -f .env
```

## 5. どこまでコミットしてよいか

| ファイル | コミット | 理由 |
| --- | --- | --- |
| `.env.op` | する | 参照だけで値が無い。何を用意すべきかの説明も兼ねる |
| `.envrc` | する | `use op` と書いてあるだけ |
| `.env` / `.env.local` | しない | 平文。`home/git.nix` の共通 gitignore で落としてある |
| `.envrc.local` | しない | 個人の上書き用。同じく共通 gitignore |

共通 gitignore は `.env` と `.env.*` を落としたうえで、`.env.op` /
`.env.example` / `.env.sample` を否定パターンで戻している。プロジェクト側の
`.gitignore` で `.env*` をまとめて無視していると `.env.op` も落ちるので、
その場合は `!.env.op` を足す。

> vault 名やアイテム名がリポジトリに残るのは意図どおり。それ自体は認証情報ではなく、
> 公開したくない命名 (社内プロジェクト名など) を避ければよい。

## 6. `use op` は何をしているか

`home/cli/direnv.nix` の `stdlib` が `~/.config/direnv/direnvrc` に配られ、
そこで定義した `use_op` が `use op` として呼ばれる。処理はこれだけ:

1. `.env.op` を 1 行ずつ読み、`KEY` と `op://` 参照に分ける
2. 参照を並べたテンプレートを組み、**`op inject` を 1 回だけ**呼ぶ
3. 返ってきた値を `export "KEY=値"` で入れる

設計上の理由:

- **`op read` を参照ごとに呼ばない。** direnv はそのディレクトリに入るたび
  `.envrc` を評価するので、プロセス起動を参照の数だけ繰り返すと体感で待たされる。
- **`eval` を通さない。** `eval "$(op inject …)"` 方式は、値に `"` や `` ` `` や
  `$(…)` が含まれていると壊れる (最悪コマンドとして実行される)。値は変数に入れて
  `export` するだけにしてある。
- **平文をディスクに書かない。** 中間ファイルを作らず、パイプで受けて環境変数にする。

## 7. ハマりどころ

- **サインインしていないと静かに空になる。** `use op` は失敗を赤字で出すが、
  `.envrc` の評価自体は続くので変数が空のまま先に進む。`op signin` してから
  `direnv reload`。
- **セッションは 30 分で切れる** (Linux 版でデスクトップアプリ連携が無い場合)。
  頻繁に打ちたくなければ 3-4 章の Windows 版中継に切り替える。
- **改行を含む秘密 (SSH 秘密鍵や証明書) は `use op` では扱えない。** 1 行 1 値で
  対応付けているため。そういう値は `.envrc` に直接書く:

  ```bash
  export TLS_KEY="$(op read 'op://Private/MyApp/private key')"
  ```

- **`direnv allow` を忘れると何も起きない。** `.envrc` を書き換えたときも必要。
- **op.exe 経由では `op run --` が使えない** (3-4 章)。`use op` を使う。
- **Docker コンテナや CI には持ち込めない。** デスクトップアプリもマスター
  パスワードも無いため。その文脈では 1Password の**サービスアカウント**を作り、
  `OP_SERVICE_ACCOUNT_TOKEN` を CI のシークレットとして渡す
  (トークン自体が平文の鍵になるので、個人の開発機では使わない)。
- **`.env.op` の参照ミスは inject 全体を失敗させる。** 1 つでも解決できない参照が
  あると全部設定されない。`op read` で個別に確かめる。

## 8. 参考

- [1Password CLI: Get started](https://www.1password.dev/cli/get-started/)
- [op run — 環境変数への読み込み](https://www.1password.dev/cli/secrets-environment-variables/)
- [op inject のリファレンス](https://www.1password.dev/cli/reference/commands/inject/)
- [秘密の参照 (op://) の書式](https://www.1password.dev/cli/secret-reference-syntax/)
- ssh 鍵側の運用は [git/github-ssh.md](../git/github-ssh.md)
