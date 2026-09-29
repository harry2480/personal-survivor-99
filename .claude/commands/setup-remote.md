---
allowed-tools: Bash(gh:*), Bash(git:*), Read, AskUserQuestion
description: GitHub 側の設定（ブランチ保護 / auto-merge / ラベル）を確認して案内する
---

## タスク

リポジトリの GitHub 側の設定が、[docs/リポジトリ設定手順.md](../../docs/リポジトリ設定手順.md) の
とおりになっているかを確認し、足りないものを**案内する**。

> **設定の変更は管理者が行う。**このコマンドは確認と案内までで、`gh api` での変更は行わない
> （要件定義 §120 / CLAUDE.md「リポジトリ設定は変更しない」）。

---

### Step 1: 前提の確認

```sh
gh auth status
gh repo view --json name,defaultBranchRef
```

- `gh` が未導入なら `brew install gh` を案内する
- default branch が `main` であることを確認する

### Step 2: ブランチ保護

```sh
if protection="$(gh api "repos/{owner}/{repo}/branches/main/protection" 2>&1)"; then
  printf '%s\n' "$protection"
elif printf '%s' "$protection" | grep -q 'Branch not protected'; then
  echo "branch protection: 未設定"
else
  printf '%s\n' "$protection" >&2
  echo "ブランチ保護を確認できませんでした" >&2
fi

# Ruleset で保護している場合はこちらに出る（branch protection が未設定でも保護されうる）
gh api "repos/{owner}/{repo}/rules/branches/main"
```

「未設定」と報告してよいのは、GitHub が `Branch not protected`（HTTP 404）を返したときだけ。
権限不足（HTTP 403）や通信障害などで確認できなかったときは、エラーをそのまま見せて**ここで止める**
（未設定と報告しない）。branch protection が未設定でも、Ruleset 側に `pull_request` などの
ルールがあれば保護はされている。

確認する内容（[docs/リポジトリ設定手順.md](../../docs/リポジトリ設定手順.md) の「必要な状態」）。

- `main` への直接 push が禁止されているか（PR 必須になっているか）
- `allow_force_pushes.enabled` が `false` で、`main` への force push が禁止されているか
- `allow_deletions.enabled` が `false` で、`main` の削除が禁止されているか
- required status check が **`CI ステータス確認`**（`.github/workflows/ci.yml` の `ci-status`）**のみ**になっているか
  （ほかの check が required に入っていれば、それも案内する）

### Step 3: auto-merge

```sh
gh repo view --json autoMergeAllowed
```

Loop を使う場合は auto-merge が有効である必要がある（[docs/loop-engineering.md](../../docs/loop-engineering.md)）。

### Step 4: ラベル

```sh
gh label list
```

Loop 用のラベルが無ければ、作るコマンドを案内する。

```sh
scripts/setup-loop-labels.sh
```

### Step 5: Secret

Release で署名する場合に要る Secret（未決定。要件定義 §125）。
現時点では不要。必要になったら [docs/リリース手順.md](../../docs/リリース手順.md) を更新する。

---

## 完了報告

以下を表にして報告する。

| 項目 | 現在 | あるべき姿 | 対応 |
|---|---|---|---|

**変更を行った場合は、何をどう変えたかを正確に報告する。行っていない設定を「設定した」と書かない。**
