# git worktree で作業する

Claude Code のセッションやエージェントを並行させるので、**ファイルを編集する作業は
worktree を切ってから始める**。同じチェックアウトを 2 つのセッションが触ると、
片方の編集がもう片方の前提を壊す。読むだけ・調べるだけなら worktree は要らない。

## 作り方

置き場所は**集約派**。本体の「隣」に `<repo>=<branch>` で並べる。
ghq / gwq の root (`~/ghq`) に揃えているので、`dev` から本体にも worktree にも飛べる。

```bash
repo=$(git rev-parse --show-toplevel)
git worktree add -b claude/<topic> "$repo=<topic>" main
```

- 手元に `gwq` があるなら `gwq add -b claude/<topic>` が同じ場所に作り、そのまま移動する。
- 使い捨てで良ければ `claude --worktree <name>` (`<repo>/.claude/worktrees/` に隔離) でもよい。
- 1 セッション内でサブエージェントを並列に走らせるだけなら `isolation: worktree` で足りる。

## 原則

1. **1 セッション = 1 worktree = 1 ブランチ。** 同じブランチは 2 箇所で checkout できない
   (`fatal: '<branch>' is already used by worktree at ...`)。これは安全装置なので、
   回避せずブランチを分ける。
2. **同じファイルを 2 体に触らせない。** ディスク上で隔離できていても、マージで衝突する。
3. **人間は本体の checkout に居る。** 指示とレビューはそこから行う。

## 片付け

```bash
git worktree remove <path>
git branch -d <branch>          # ← worktree を消してもブランチは残る
```

ディレクトリを `rm -rf` しただけだと登録が残り、そのブランチが「使用中」のままになる。
`git worktree list` に `prunable` と出たら `git worktree prune`。

## 落とし穴

- **追跡外ファイルは付いてこない。** `.env` / `.direnv/` / gitignore 済みの参照ディレクトリなど。
  毎回必要なものは `.worktreeinclude` に書くか symlink する。
- **`.git/hooks/` と `git config`、stash はリポジトリ共通。** 並列作業中は stash を使わず、
  WIP コミットで退避する方が事故らない。
- **direnv はパス単位で信頼する。** worktree ごとに `direnv allow` が要る。
- **`.claude/worktrees/` を gitignore し忘れると本体の `git status` が壊滅する。**
- **ビルド成果物やロックファイルの生成は worktree ごとにやり直しになる。** 初回は遅い。
