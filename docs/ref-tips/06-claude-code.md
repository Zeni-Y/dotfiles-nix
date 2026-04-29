# 06. Claude Code — CLAUDE.md / agents / skills / hooks

両 dotfiles ともに最も作り込みが進んでいる領域。  
グローバル `~/.config/claude/` への配布を Nix 化するのが理想。

## Agent Skills (ryoppippi)

### - [ ] Skill: `commit` (Conventional Commits 自動分割)

- **概要**: 変更を分析して revertable な単位に分割し連続コミット
- **参照**: `ref/ryoppippi-dotfiles/agents/skills/commit/`
- **メリット**: 大きな変更を意味単位で履歴化
- **デメリット**: 自動分割の判断が常に最適とは限らない
- **使い方**: `/commit` (Claude Code 内)
- **実装メモ**: `home/claude.nix` 新設で `~/.config/claude/skills/` に配置

### - [ ] Skill: `create-pr`

- **概要**: branch → commit → push → PR 作成 一括
- **参照**: `ref/ryoppippi-dotfiles/agents/skills/create-pr/`
- **メリット**: PR 作成のお作法を毎回同じに
- **デメリット**: なし
- **実装メモ**: 同上

### - [ ] Skill: `fix-ci`

- **概要**: CI 失敗ログ取得 → 修正提案
- **参照**: `ref/ryoppippi-dotfiles/agents/skills/fix-ci/`
- **メリット**: CI 赤を放置しなくなる
- **デメリット**: gh CLI 認証必須
- **実装メモ**: 同上

### - [ ] Skill: `merge-main`

- **概要**: main 取込 → 競合自動解決を試行
- **参照**: ryoppippi skills
- **メリット**: ブランチ長期化対策
- **デメリット**: 自動マージは慎重に
- **実装メモ**: 同上

### - [ ] Skill: `pr-apply-review`

- **概要**: PR レビューコメントを取得して反映
- **参照**: ryoppippi skills
- **メリット**: レビュー対応の労力削減
- **デメリット**: なし
- **実装メモ**: 同上

### - [ ] Skill: `tdd`

- **概要**: TDD フロー（red→green→refactor）支援
- **参照**: ryoppippi skills
- **メリット**: TDD 実践の心理的負担減
- **デメリット**: 言語によってテンプレ差
- **実装メモ**: 同上

### - [ ] Skill: `council` (複数エージェント協議)

- **概要**: 複数 Claude が議論してコードレビュー
- **参照**: ryoppippi skills
- **メリット**: 視点が増える
- **デメリット**: トークン消費大
- **実装メモ**: 同上

### - [ ] Skill: `session-summary-japanese`

- **概要**: セッション末に日本語でサマリ生成
- **参照**: ryoppippi skills
- **メリット**: 後から振り返れる、claude-mem との連携
- **デメリット**: なし
- **実装メモ**: 同上

### - [ ] Nix で `~/.config/claude/skills/` を配布する仕組み

- **概要**: `agent-skills-nix` パターン（ファイル群を home-manager で展開）
- **参照**: `ref/ryoppippi-dotfiles/nix/modules/home/programs/agent-skills*`
- **メリット**: skill が flake で版固定、複数マシンで同期
- **デメリット**: skill 単体追加に Nix リビルドが必要
- **実装メモ**: `home/claude.nix` で `xdg.configFile."claude/skills/foo".source = ./skills/foo;`

## Subagents (kawarimidoll)

### - [ ] Subagent: commit-maker / pr-maker / reviewer / rebaser / reworder ...

- **概要**: 9 種のサブエージェントを `agents/` に配置
- **参照**: `ref/kawarimidoll-dotfiles/.config/claude/agents/`
- **メリット**: タスク特化エージェントで品質向上
- **デメリット**: 役割の使い分けを覚える必要
- **実装メモ**: `xdg.configFile."claude/agents/<name>.md".source = ...`

### - [ ] Hook: `notification.sh` (Pushover で待機通知)

- **概要**: Claude が user 入力待ちになったら Pushover 通知
- **参照**: `ref/kawarimidoll-dotfiles/.config/claude/hooks/notification.sh`
- **メリット**: 長い思考の終了を別タスクから検知
- **デメリット**: Pushover 課金 ($5 一回)
- **実装メモ**: `settings.json` の hooks に登録、API token は別管理

### - [ ] Custom Skill: `agent-memory` / `grill-me` / `oss-research`

- **概要**: 独自 skill 集
- **参照**: `ref/kawarimidoll-dotfiles/.config/claude/skills/`
- **メリット**: ニッチなワークフロー支援
- **デメリット**: 中身を読んで自分用に調整必須
- **実装メモ**: 同上

### - [ ] CLAUDE.md の「z-ai/ を gitignore」規約

- **概要**: 作業中の AI 生成物を `z-ai/` に隔離 → gitignore
- **参照**: `ref/kawarimidoll-dotfiles/.config/claude/CLAUDE.md`
- **メリット**: AI 出力をうっかり commit しない
- **デメリット**: なし
- **実装メモ**: グローバル CLAUDE.md に追記

### - [ ] RTK 風コマンド書き換え (トークン削減)

- **概要**: 一般 git コマンドを軽量版に自動書き換え
- **参照**: kawarimidoll CLAUDE.md
- **メリット**: 長い出力をトークン節約
- **デメリット**: 別ツール (rtk) 依存
- **実装メモ**: 別パッケージ調査必要

## 横断: ユーザー方針

### - [ ] グローバル `CLAUDE.md` のコメント / 言語ポリシー

- **概要**: 「変更説明コメント禁止」「JSDoc 必須」「UK 英語」など
- **参照**: `ref/ryoppippi-dotfiles/claude/CLAUDE.md`
- **メリット**: 全プロジェクトで統一されたコード品質
- **デメリット**: 個別プロジェクト規約と衝突する可能性
- **実装メモ**: `~/.config/claude/CLAUDE.md` を home-manager で配布

### - [ ] `claude/rules/` をトピック別に分割

- **概要**: tools.md / nix.md / ai-assistance.md / web-fetch.md
- **参照**: `ref/ryoppippi-dotfiles/claude/rules/`
- **メリット**: ルールをスコープ別に管理しやすい
- **デメリット**: ルール多すぎるとトークン消費増
- **実装メモ**: 同上

### - [ ] Output Style (お嬢さま口調 等)

- **概要**: 出力スタイルを定義
- **参照**: ryoppippi `claude/`
- **メリット**: 楽しい、口調で誤読を減らせる
- **デメリット**: チーム作業では使いどころ限定
- **実装メモ**: `~/.config/claude/output-styles/`
