---
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep
description: 開発環境の初期セットアップ（Godot と品質チェックの前提ツール）
---

## タスク

Mac をクリーンインストールした直後の人でも、このプロジェクトを動かせる状態にする。
各ステップで **コマンドの存在確認を行い、未導入なら案内またはインストールする**。
進捗は都度報告する。

---

### Step 1: Godot の確認

`.godot-version` に書かれているバージョンと同じ Godot が要る。

```sh
cat .godot-version
/Applications/Godot.app/Contents/MacOS/Godot --version
```

- 未導入なら [Godot 公式](https://godotengine.org/download/macos/) からダウンロードして
  `/Applications` へ置くよう案内する
- バージョンが違う場合は、**合わせる必要がある**ことを伝える（CI と揃えるため）

### Step 2: プロジェクトの import

```sh
scripts/verify-godot.sh
```

import と起動検証がここで通る。失敗したら出力の `ERROR` / `SCRIPT ERROR` を読む。

### Step 3: 自動テスト

```sh
scripts/run-tests.sh
```

GUT（`addons/gut/`）は同梱しているので追加の導入は要らない。

### Step 4: 静的チェックの前提ツール

`scripts/static-check.sh` は gdtoolkit（gdlint / gdformat）を使う。

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r ci/requirements-static-check.txt
scripts/static-check.sh
```

導入しない場合は `SKIP_GDTOOLKIT=1 scripts/static-check.sh` で省略できるが、
**CI では実行される**ので、push 前にどこかで通す必要があることを伝える。

### Step 5: Export Templates（配布物を作る場合のみ）

```sh
scripts/install-export-templates.sh
scripts/export-macos.sh
```

1GB 近いダウンロードになるため、配布物を作らないなら省略してよい。

### Step 6: Loop Engineering（使う場合のみ）

[docs/loop-engineering.md](../../docs/loop-engineering.md) を読み、初期設定・Issue 信頼境界・
auto-merge 条件を確認する。ラベルは `scripts/setup-loop-labels.sh` で作れる。

**GitHub の branch protection と Allow auto-merge は、この作業では変更しない。**
必要な設定は [docs/リポジトリ設定手順.md](../../docs/リポジトリ設定手順.md) にあり、適用は管理者が行う。
設定したと偽らないこと。

---

## 完了報告

以下を報告する。

- Godot のバージョン（`.godot-version` と一致しているか）
- `scripts/verify-godot.sh` / `scripts/run-tests.sh` / `scripts/static-check.sh` の結果
- 省略したステップとその理由
