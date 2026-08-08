# Windows (WSL2) でのセットアップ

Windows 上でこのリポジトリの環境を再現する手順です。
**WSL2 の Ubuntu 24.04 を「実機の Ubuntu」として扱い、README の通常手順に合流させる**
のが方針で、WSL 固有の作業は最初の 3 節 (WSL の導入 / systemd の有効化 / 置き場所) に
集約されています。

> **対象**: `homeConfigurations."zenimoto@ubuntu"` (standalone Home Manager)
>
> Windows 側の準備 (フォント・ターミナル) は [7 章](#7-windows-側の仕上げ) にまとめています。
> Linux 側だけ終わらせても、フォントが無いと herdr や LazyVim のアイコンが豆腐になります。

---

## 目次

1. [なぜ WSL2 か (Docker との使い分け)](#1-なぜ-wsl2-か-docker-との使い分け)
2. [WSL2 のインストール](#2-wsl2-のインストール)
3. [systemd を有効化する](#3-systemd-を有効化する)
4. [リポジトリを置く場所](#4-リポジトリを置く場所)
5. [Nix のインストール](#5-nix-のインストール)
6. [初回 switch](#6-初回-switch)
7. [Windows 側の仕上げ](#7-windows-側の仕上げ)
8. [WSL 固有のハマりどころ](#8-wsl-固有のハマりどころ)
9. [作り直し方](#9-作り直し方)

---

## 1. なぜ WSL2 か (Docker との使い分け)

このリポジトリには `docker/` 配下に検証用・常駐開発用のコンテナが用意されていますが、
**Windows 上の日常環境としては WSL2 が適しています**。

| 観点 | WSL2 | Docker (`docker/working`) |
| --- | --- | --- |
| このリポジトリの想定 | `hosts/ubuntu.nix` = Ubuntu 上の standalone Home Manager。**そのもの** | 想定内だが副次的な位置づけ |
| systemd | 有効化でき、`setup.sh` が**通常経路**でインストールする。`nix-daemon` は systemd 任せ | systemd が無いので `--init none` 経路。daemon の自動起動を `~/.bashrc` で肩代わりする |
| 永続性 | `/nix` も `$HOME` もそのまま残り、`home-manager switch` を回すだけ | コンテナが揮発するので dotfiles をイメージに焼き込む必要がある (初回ビルド数十分) |
| ターミナル | Windows 側の WezTerm / Windows Terminal から直接起動できる | SSH で入る前提。GUI ターミナルの設定は使われない |
| 階層 | ネイティブ | Docker Desktop for Windows のバックエンドは WSL2。**WSL の上に一段乗る** |

最後の行が効きます。Windows で Docker を使うなら結局下に WSL2 がいるので、
常用環境なら間に何も挟まない方が速くて壊れにくい。

Docker 側を使うのは次のようなときです (WSL2 の中で Docker を動かせるので排他ではありません):

- `scripts/setup.sh` の変更をまっさらな状態から何度も検証したい → [`docker/debug`](../docker/debug/README.md)
- リモートに置く常駐開発環境を作りたい → [`docker/working`](../docker/working/README.md)

---

## 2. WSL2 のインストール

PowerShell を**管理者権限で**開いて実行します。

```powershell
wsl --install -d Ubuntu-24.04
```

インストール後、WSL 本体を最新にしておきます。次の 3 章で使う systemd 対応が
古い WSL には入っていないためです。

```powershell
wsl --update
wsl --version      # WSL バージョン 0.67.6 以上であること
```

> `wsl --version` が「認識されていない」旨のエラーになる場合、Windows 同梱の古い WSL が
> 動いています。`wsl --update` で Microsoft Store 版に上げてください
> (Windows 10 では Store 版が必須)。

### ユーザー名を `zenimoto` に揃える

初回起動時に UNIX ユーザー名とパスワードを聞かれます。ここで
**`flake.nix` の `userInfo.username` と同じ名前**を入力してください。

```nix
# flake.nix
userInfo = {
  username = "zenimoto";   # ← WSL のユーザー名をこれに合わせる
  ...
};
```

`hosts/ubuntu.nix` が `home.homeDirectory = "/home/${userInfo.username}"` を前提にするため、
名前がずれていると `home-manager switch` が別のホームを見に行って失敗します。
別の名前にしたい場合は先に `flake.nix` 側を書き換えてください。

WSL の既定ユーザーは `sudo` グループに入っているので、`setup.sh` の sudo 要件は満たしています。
念のため確認するなら:

```bash
sudo -v      # パスワードを聞かれて通れば OK
```

### 最小限の apt パッケージ

Nix より前に必要なものだけ入れます (`docker/working` と同じ考え方で、
残りはすべて Nix 管理)。

```bash
sudo apt update
sudo apt install -y curl ca-certificates git
```

---

## 3. systemd を有効化する

**この章が WSL 固有の作業で一番重要です。**

`scripts/setup.sh` は `/run/systemd/system` の有無で systemd を判定し、
インストール方式を切り替えます。

| systemd | `setup.sh` の動作 |
| --- | --- |
| あり | 通常インストール。`nix-daemon` は systemd が起動・監視する |
| なし | `linux --init none` プラン。daemon の自動起動を諦め、`~/.bashrc` に手動起動スニペットを追記する |

WSL2 は既定で systemd が無効なので、**`setup.sh` を実行する前に**有効化します。

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
```

PowerShell 側で WSL を一度落とします (再起動しないと反映されません)。

```powershell
wsl --shutdown
```

もう一度 Ubuntu を開いて確認します。

```bash
ls -d /run/systemd/system     # ディレクトリが見えれば OK
systemctl is-system-running   # running か degraded なら OK
```

> `degraded` は一部のユニットが起動に失敗しているだけで、Nix の用途には問題ありません。
> `setup.sh` が見ているのは `/run/systemd/system` の存在だけです。

---

## 4. リポジトリを置く場所

**Linux 側のホーム配下、`~/ghq/github.com/Zeni-Y/dotfiles-nix` に置いてください。**
ghq の標準レイアウト (`<root>/<host>/<owner>/<repo>`) です。

```bash
mkdir -p ~/ghq/github.com/Zeni-Y
git clone https://github.com/Zeni-Y/dotfiles-nix.git ~/ghq/github.com/Zeni-Y/dotfiles-nix
cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
```

パスが決め打ちなのは、fish の短縮入力がこの場所を前提にしているためです
(`home/shell/fish.nix` の `flakeDir`)。

```nix
flakeDir = "${config.home.homeDirectory}/ghq/github.com/Zeni-Y/dotfiles-nix";
flakeRef = "${flakeDir}#${config.home.username}@ubuntu";
```

`hms` / `nfu` / `nfc` などの abbreviation はこの `flakeRef` に展開されるので、
別の場所に置くと展開先が実在せず落ちます (→ [docs/fish-abbr.md](./fish-abbr.md))。
**別の owner に fork した場合は `flakeDir` の `Zeni-Y` も直してください**
(GitHub の owner 名は `userInfo.username` と綴りが違うので自動では導けません)。

host/owner の階層まで含めた形にしているのは、git worktree を同じ `~/ghq` に
集約して `ghq list | fzf` 一発で行き来できるようにするためです
(→ [docs/git-worktree.md 7 章](./git-worktree.md#7-集約派で揃える--gwq-と-herdr-を合わせる))。
Nix と ghq が入った後なら、2 台目以降は次でも取得できます。

```bash
ghq get github.com/Zeni-Y/dotfiles-nix
```

### `/mnt/c/...` に置いてはいけない

Windows 側のドライブは 9p (WSL2) 経由でマウントされており、次の問題があります。

- **遅い**。Nix / git のような小さいファイルを大量に触る処理が体感で数倍〜十数倍遅くなる
- **パーミッションと symlink が正しく扱えない**。Home Manager は Nix store への symlink を
  張って回るので、これは致命的
- `git status` が全ファイル変更扱いになるなど、パーミッション由来の誤検知が起きる

Windows 側のファイルを編集したいときは、逆に **Windows のエディタから WSL を開く**
(VS Code の WSL 拡張、`\\wsl$\Ubuntu-24.04\home\zenimoto\...`) のが正解です。

### SSH 鍵 (SSH で clone したい場合)

WSL 内で鍵を作り、GitHub に登録するのが一番素直です。

```bash
ssh-keygen -t ed25519 -C "zeki110922@gmail.com"
cat ~/.ssh/id_ed25519.pub    # これを GitHub の SSH keys に登録
```

Home Manager の適用後は `gh` が入るので、以降は `gh auth login` で
credential helper 経由の HTTPS 認証も使えます (`home/git.nix`)。

---

## 5. Nix のインストール

```bash
cd ~/ghq/github.com/Zeni-Y/dotfiles-nix
./scripts/setup.sh
```

**出力の最初の行を必ず確認してください。**

```
==> sudo + systemd を検出しました → 通常の Nix をインストールします
```

これが出れば 3 章が効いています。もし

```
==> sudo は使えるが systemd が無い環境を検出しました (Docker コンテナなど)
```

と出たら systemd が有効になっていません。`Ctrl-C` で止めて 3 章をやり直してください
(そのまま進めても動きますが、`nix-daemon` を毎回 `~/.bashrc` から起こす構成になります)。

インストール後、現在のシェルに反映します。

```bash
exec bash
nix --version
```

---

## 6. 初回 switch

`flake.nix` の `userInfo` を自分の情報に書き換えます。

```bash
$EDITOR flake.nix
```

```nix
userInfo = {
  username = "zenimoto";
  gitName  = "zenimoto";
  gitEmail = "zeki110922@gmail.com";   # ← 既定のプレースホルダから変更する
};
```

適用します。**初回は `-b backup` が必須**です。Ubuntu 標準の `~/.bashrc` /
`~/.profile` が既にあり、Home Manager はそれらを黙って上書きしないためです。

```bash
nix run home-manager/master -- switch -b backup --flake '.#zenimoto@ubuntu'
```

初回は nixpkgs の取得とビルドで時間がかかります (回線とキャッシュ次第で数分〜数十分)。

終わったら新しいシェルを開きます。bash が fish に `exec` で切り替わり、
pure プロンプトが出れば成功です。

```bash
exec bash        # → fish に切り替わる
which nvim herdr # Nix store のパスが返る
```

以降の運用 (`hms` / `nfu` / 世代の切り戻しなど) は
[README の「日々の運用」](../README.md#日々の運用) に合流します。

---

## 7. Windows 側の仕上げ

ここから先は **Windows 側**の作業です。ターミナルとフォントを解決するのは
Windows のアプリケーションであり、WSL の中ではないことに注意してください。

### 7.1 Nerd Font のインストール (必須)

`home/wezterm.nix` は `FiraCode Nerd Font` を指定しています。herdr のステータスライン、
LazyVim のファイルアイコン、`eza --icons` はすべて Nerd Font のグリフに依存するので、
**Windows 側にフォントを入れないと豆腐 (□) だらけになります**。

1. <https://www.nerdfonts.com/font-downloads> から `FiraCode Nerd Font` を取得
2. zip を展開し、`.ttf` を全選択 → 右クリック →「インストール」

WSL の中に `fonts-firacode` を apt で入れても意味がありません
(Linux 側にはフォントを描画する主体がいないため)。

### 7.2 ターミナル

**Windows Terminal** (WSL インストール時に既定で入る) をそのまま使うのが最短です。
プロファイルの `fontFace` を `FiraCode Nerd Font` にすれば、herdr も LazyVim も
そのまま動きます。配色は Catppuccin Mocha を入れると `home/herdr.nix` と揃います。

**WezTerm を使う場合は注意点があります。**

`home/wezterm.nix` が配置するのは **WSL 内の** `~/.config/wezterm/wezterm.lua` です。
一方 WezTerm は Windows 側で動く GUI アプリなので、読むのは
`%USERPROFILE%\.wezterm.lua` (または `%USERPROFILE%\.config\wezterm\wezterm.lua`) であり、
**WSL 内の設定は一切参照されません**。

対処は次のどちらかです。

- **Windows Terminal を使い、WSL 内の WezTerm 設定は「Linux 実機に移ったとき用」として置いておく**
  (何もしなくてよい。推奨)
- **Windows 側に同等の設定を置く**。`home/wezterm.nix` の `extraConfig` の内容を
  `%USERPROFILE%\.wezterm.lua` にコピーし、WSL を既定ドメインにする行を足す:

  ```lua
  config.default_domain = 'WSL:Ubuntu-24.04'
  ```

  この場合、Windows 側の設定は Nix 管理外になるため、`home/wezterm.nix` を更新したら
  手で同期する必要があります。

### 7.3 リソース制限 (任意)

WSL2 は既定でホストメモリの相当量を使いに行きます。絞りたい場合は
`%USERPROFILE%\.wslconfig` を作ります。

```ini
[wsl2]
memory=8GB
processors=4
swap=8GB
```

反映は `wsl --shutdown` の後、次回起動時です。

---

## 8. WSL 固有のハマりどころ

- **systemd を有効にせず `setup.sh` を実行してしまった**。
  Nix 自体は入っているので、`/etc/wsl.conf` を書いて `wsl --shutdown` した後、
  `~/.bashrc` (Home Manager 適用後は `~/.bashrc.backup`) に入った
  `dotfiles-nix:nix-daemon-autostart` ブロックを消せば通常構成に戻せます。
  systemd 側の daemon は `systemctl status nix-daemon` で確認できます。
  Nix を入れ直したいなら `/nix/nix-installer uninstall` が使えます。

- **`opening lock file ".../big-lock": Permission denied`**。
  `nix-daemon` が動いていないサインです。systemd 構成なら
  `sudo systemctl start nix-daemon`、そうでなければ README の
  [既知のハマりどころ](../README.md#既知のハマりどころ) を参照。

- **Windows の PATH が混ざる**。
  WSL は既定で Windows の `PATH` を継ぎ足すので、`node` や `python` が Windows 側の
  実行ファイルに解決されることがあります。切るなら `/etc/wsl.conf` に:

  ```ini
  [interop]
  appendWindowsPath = false
  ```

  ただし切ると `code .` / `explorer.exe .` / `clip.exe` が使えなくなります。
  VS Code の WSL 連携を使うなら**切らない**方が便利です。
  混入が気になる箇所だけ、`home/shell/fish.nix` の `shellInit` で
  Nix プロファイルを PATH 先頭に置いている (`fish_add_path --prepend`) ので、
  実用上は Nix 側が優先されます。

- **`~/.bashrc` が Home Manager に置き換わり、`setup.sh` の追記が消えたように見える**。
  仕様通りです。`setup.sh` が書いた内容は `-b backup` で `~/.bashrc.backup` に退避され、
  跡地に Nix store への symlink が張られます。systemd 構成なら Nix の PATH は
  `/etc/profile.d/` 経由で通り、fish は `home/shell/fish.nix` の `shellInit` で
  明示的に通しているので、どちらも影響を受けません
  (→ [docs/fish-nix-path.md](./fish-nix-path.md))。

- **ディスクが減らない**。
  WSL2 の仮想ディスク (`ext4.vhdx`) は自動で拡張されますが**自動では縮みません**。
  Nix の世代を消しても Windows 側の使用量は戻らないので、まず Linux 側で回収し、

  ```bash
  nix-collect-garbage -d
  ```

  Windows 側の実サイズも戻したい場合は、`wsl --shutdown` の後に
  `wsl --manage Ubuntu-24.04 --set-sparse true` を試すか、`diskpart` の
  `compact vdisk` を使います (どちらも先にバックアップを取ってください)。

- **`/mnt/c` 配下での作業が遅い / git が全ファイル変更扱いになる**。
  4 章の通り、作業ディレクトリは Linux 側のホームに置いてください。

- **時計がずれる**。
  スリープ復帰後に WSL の時刻がずれ、TLS 証明書の検証や `nix` の取得が失敗することが
  あります。新しい WSL では自動同期されますが、起きたら
  `sudo hwclock -s`、あるいは `wsl --shutdown` で直ります。

---

## 9. 作り直し方

WSL のディストリを丸ごと捨ててやり直せるのが、実機に対する WSL の利点です。
PowerShell で:

```powershell
wsl --unregister Ubuntu-24.04     # ★ ホームディレクトリごと消える
wsl --install -d Ubuntu-24.04
```

**`--unregister` は確認なしに全データを消します。** `~/ghq` の未 push なコミットや
`~/.ssh` の鍵が消えるので、必ず先に退避してください。

Linux 側の設定だけ作り直したい場合は、WSL を消す必要はありません。
Home Manager の世代を戻すか、`~/.config/nvim` などの Nix 管理外ディレクトリを
消して `home-manager switch` し直します
(→ [README の既知のハマりどころ](../README.md#既知のハマりどころ))。
