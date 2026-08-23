# GitHub への接続を ssh に一本化する

`home/git.nix` の `url."git@github.com:".insteadOf = "https://github.com/"` により、
GitHub との **clone / fetch / push はすべて ssh** に書き換わる。https の URL で
clone しても実際の通信は `git@github.com:` になる。

あわせて `git config ghq.user` (`flake.nix` の `userInfo.githubUser` から導出) を
設定しているので、`ghq get <repo>` と owner を省略しても自分の owner 名で補完され、
private リポジトリもそのまま ssh で clone できる。

## なぜ https ではなく ssh か

https の認証は**トークン** (gh の OAuth トークンや PAT) で、これは
「持っていれば誰でも使える文字列」がローカルに保存される方式。漏洩リスクと
有効期限・スコープの管理が付いて回り、失効すると全リポジトリの操作が止まる。

ssh の認証は**鍵の署名**で、秘密鍵そのものは通信に乗らない。さらにこの環境では
秘密鍵は 1Password の vault にあり、Linux 側には鍵ファイルもトークンも置かない。
agent が生きている限り動き続け、鍵の使用時に Windows Hello などの確認も挟める。

## 鍵は 1 つ、マシンごとの設定だけ変わる

鍵は 1Password の vault に 1 組だけあり、GitHub への公開鍵の登録も 1 回だけ。
マシンを増やしても鍵を作り直す必要はなく、**その agent にどう繋ぐか**だけが
マシンのタイプで変わる。

| マシンのタイプ | やること |
| --- | --- |
| GUI がある (Windows / Mac / Linux デスクトップ) | 1Password アプリを入れ、設定で「SSH エージェントを使用」を有効にする |
| WSL2 | 上に加えて Windows 側 agent への中継が必要。`home/wsl-ssh-agent.nix` が担当し、`userInfo.windowsUsername` を設定すると有効になる (→ [setup/wsl2.md 7-4 章](../setup/wsl2.md#74-ssh-agent-を-windows-側に一本化する-任意)) |
| リモートの Ubuntu (GUI 無し) | 1Password は動かないので入れない。手元のマシンから **agent forwarding** で持ち込む。リモートに秘密鍵を置かない (→ [setup/ubuntu.md](../setup/ubuntu.md)) |

## 例外: agent が居ない無人環境

cron・CI・単体の Docker コンテナなど ssh-agent が存在しない文脈では、
insteadOf の書き換えによって**公開リポジトリの https clone まで失敗する**
(GitHub の ssh は公開リポジトリでも認証必須のため)。

そういう環境では次のどちらかで逃げる:

- この gitconfig 自体を持ち込まない (Home Manager を適用しなければ素の git のまま)
- その場で書き換えを外す:

  ```bash
  git config --global --unset 'url.git@github.com:.insteadof'
  ```

  1 コマンド限りなら global 設定ごと無視するのが確実 (https で繋がることを確認済み):

  ```bash
  GIT_CONFIG_GLOBAL=/dev/null git clone https://github.com/<owner>/<repo>
  ```

  なお `-c` や `GIT_CONFIG_*` 環境変数で「https を https に書き換える」ルールを
  重ねても打ち消せない (ssh 側の書き換えが勝つことを確認済み)。

ポート 22 を塞ぐネットワークに居る場合は、`ssh.github.com` の 443 番へ迂回できる:

```
# ~/.ssh/config
Host github.com
    HostName ssh.github.com
    Port 443
    User git
```
