# ブランチ・コミット・PR

## ブランチ

- **`main` に直接コミット・直接 push しない。** 変更は必ずブランチ経由。
- 名前は `claude/<topic>` (英小文字ケバブケース)。`main` から切る。
- 作業を始める前に `git switch main && git pull` で追従してから切る。

## コミット

- **日本語 + Conventional Commits**: `<type>(<scope>): <要約>`
  - type: `feat` / `fix` / `docs` / `refactor` / `chore` / `test`
  - scope: モジュール名かディレクトリ名 (例 `feat(ghq,gwq): ...`, `fix(docker/working): ...`)
- 本文は「何をしたか」ではなく **なぜそうしたか**。触ったファイルごとに 1〜2 行の要約を付ける。
- 1 コミット 1 目的。フォーマッタが出した無関係な差分は混ぜない。
- **頼まれていないのに commit / push しない。**

## PR

```bash
git push -u origin <branch>
gh pr create --base main          # 本文は 概要 / 変更点 / 確認 の構成
gh pr merge <N> --merge --delete-branch
git switch main && git pull
```

- マージは **merge commit** (`--merge`)。`--squash` にしない。
- マージ後は worktree とローカルブランチを片付ける (`~/.claude/rules/git-worktree.md`)。

## 指示の解釈

| 言われたこと | やること |
| --- | --- |
| commit | commit まで |
| commit&push | push まで。PR を作るかは一言添える |
| **push&merge** | commit → push → PR 作成 → **merge → ブランチ削除**まで一続き。途中で確認を挟まない |

## やらないこと

- `main` への force push、公開済みブランチの履歴改変。
- `git add -A` で意図しないファイルを巻き込むこと。`git status` で確認してから add する。
- コミットに秘密情報 (トークン / 鍵 / `.env`) を含めること。
