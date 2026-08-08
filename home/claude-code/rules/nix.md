---
paths:
  - "**/*.nix"
  - "**/flake.lock"
---

# Nix / Home Manager

`.nix` を読み書きするときだけ読み込まれるルール。

## 適用はエージェントがやらない

**`home-manager switch` / `nixos-rebuild switch` を実行しない。** マシン全体に効くので、
適用は人間が本体のチェックアウトから 1 回だけ行う。エージェント側の検証は評価までに留める。

```bash
nix flake check --no-build
nix build .#homeConfigurations."<name>".activationPackage
```

## flake は git 管理下のファイルしか見ない

新しい `.nix` (や flake から参照するファイル) を足したら **`git add`** する。
しないと `error: Path '...' is not tracked by Git` や「変更が反映されない」になる。
コミットまでは不要。worktree では追跡外ファイルが最初から無いぶん、これを踏みやすい。

## そのほか

- **`flake.lock` を手で書き換えない。** 更新は `nix flake update`。
- **`Existing file '...' would be clobbered`** は「Nix 管理外の実ファイル」との衝突。
  ツールが自分で生成する設定を Nix から配るなら `force = true`、
  素の環境に元からあるファイルとの初回衝突なら `-b backup`。
  `-b backup` は同じ拡張子の退避が残っていると再実行でまた止まるので、恒久対策には向かない。
- **ツール自身の自己更新機能は使わない** (`<tool> update` の類)。実体は Nix store 上の
  読み取り専用バイナリで、バージョンは `flake.lock` が持っている。
- モジュールは 1 トピック 1 ファイル。作ったら親の `imports` に足す。
- コメントは「なぜこの値なのか」を書く。上流の既定値と変えた理由、踏んだバグ、実際に確認した挙動。
