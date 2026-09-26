---
allowed-tools: Bash(git:*)
description: main ブランチに戻ってリモートと同期する
---

## 現在の状況

- 現在のブランチ: !`git branch --show-current`
- 変更状態: !`git status --short`

## タスク

以下の手順で `main` に同期してください。

1. **コミット状態の確認**: `git status` で未コミットの変更がないか確認する。
   変更がある場合はユーザーに報告して終了する（コミットするか、どう扱うか確認を取る）。

2. **リモートの取得**: `git fetch origin` でリモートの最新状態を取得する。

3. **main へ切り替え**: `git checkout main`

4. **最新化**: `git pull origin main`

5. **完了報告**: 切り替え完了と、`main` の最新コミットを報告する。

## 注意事項

- `main` への直接 commit / push は禁止（要件定義 §120）。作業は `feature/*` などのブランチで行う。
