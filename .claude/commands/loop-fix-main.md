---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(scripts/static-check.sh:*), Bash(scripts/verify-godot.sh:*), Bash(scripts/run-tests.sh:*), Read, Write, Edit, Glob, Grep
argument-hint: <障害またはIssue>
description: main上の障害修正をLoop外の承認付きで準備する
---

## タスク

このコマンドは人の依頼でのみ実行します。報告された `main` 上の障害を調べ、範囲を絞ったIssueとfeature branchを作り、`main` 向けPRを開きます。`main` へ直接pushしてはいけません。リリース済みの成果物に影響する操作にはmaintainerの承認が必要です。`scripts/static-check.sh`、`scripts/verify-godot.sh`、`scripts/run-tests.sh` を実行し、根拠を記録して、PR作成後に終了します。
