---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(scripts/*)
argument-hint: [追加の指示]
description: フィーチャーブランチを作成して PR を出す
---

## 現在の状況

- 現在のブランチ: !`git branch --show-current`
- 変更ファイル: !`git status --short`
- 追加の指示: $ARGUMENTS

## タスク

以下の手順で PR を作成してください。

1. **現在の状態を確認**: `git status` と `git diff` で変更内容を確認し、PR に含める変更を把握する。
   変更がない場合はユーザーに報告して終了する。

2. **目的（Why）の明確化**: この PR が必要な理由を明確にする。以下のいずれかの形で言語化する。
   - 「（対象者）が（困っている状態）を解消するため」
   - 「（対象者）が（嬉しい状態）になるため」

   目的が明確でない場合は、必ずユーザーに質問して確認を取る。PR の description に目的として記載する。

3. **ブランチ決定**:
   - 現在のブランチが `main` の場合: 変更内容に基づいてブランチ名を決め、作成してチェックアウトする
     （例: `feature/opponent-grid`, `fix/lock-delay-reset`, `perf/target-selection`）
   - 既にフィーチャーブランチにいる場合: 変更内容がブランチ名と合っていればそのまま使う。
     合っていなければ `main` から新しいブランチを作って変更を持ち越す

4. **品質チェック**: `.gd` / `.tscn` / `.tres` / `project.godot` への変更がある場合、
   プロジェクトルートで以下を実行する。ドキュメントのみの変更ならスキップ可。

   ```sh
   scripts/static-check.sh   # Lint / フォーマット / 命名規約 / 依存方向
   scripts/verify-godot.sh   # import + 起動検証
   scripts/run-tests.sh      # 自動テスト
   ```

   Godot はスクリプトエラーが出ても終了コード 0 を返すことがあるため、出力も確認する
   （各スクリプトが `ERROR` / `SCRIPT ERROR` / `WARNING` を走査して失敗させる）。
   エラーがあれば修正してから次へ進む。

5. **コミット**: 変更内容に合った prefix（`feat:` `fix:` `refactor:` `perf:` `test:` `docs:` `chore:`）で
   コミットする（要件定義 §121）。

6. **コンフリクト確認**: `git fetch origin` して `main` とのマージ可能性を確認する。

   ```sh
   git merge-tree "$(git merge-base HEAD origin/main)" HEAD origin/main
   ```

   コンフリクトがある場合はユーザーに報告し、続行するか確認を取る。

7. **プッシュ**: `git push -u origin <branch-name>`

8. **PR 作成**: `gh pr create --base main` で作成する。

9. **完了報告**: 作成した PR の URL を報告する。

## 注意事項

- **`main` への直接 push は禁止**（要件定義 §120）。
- `addons/gut/` は上流のコードを vendoring している。変更しない。
- リポジトリ設定（ブランチ保護 / auto-merge / secret）は変更しない。
  手順は [docs/リポジトリ設定手順.md](../docs/リポジトリ設定手順.md) にあり、適用は管理者が行う。
- Issue に対応する PR では、Issue の完了条件を 1 つずつ確認できる形で書く。
  満たせなかった項目は理由を書く。
- プルリクエストは [.github/PULL_REQUEST_TEMPLATE.md](PULL_REQUEST_TEMPLATE.md) の形式に従う。
