---
description: エラーを直す。エラーメッセージから原因を特定し、アーキテクチャのルールに沿って修正する
---

# エラー修正スキル

## 1. まず再現する

| 出どころ | 再現のしかた |
|---|---|
| 起動時・import 時 | `scripts/verify-godot.sh` |
| テスト | `scripts/run-tests.sh`（1 本だけなら `-gselect=<ファイル名の一部>`） |
| Lint / フォーマット | `scripts/static-check.sh` |
| 実機プレイ中 | `/Applications/Godot.app/Contents/MacOS/Godot --path .` で再現手順をなぞる |

**Godot はスクリプトエラーが出ても終了コード 0 を返すことがある。**出力の
`ERROR` / `SCRIPT ERROR` / `WARNING` を読む。

## 2. よくある原因

| 症状 | 見るところ |
|---|---|
| `Assigned value for constant ... isn't a constant expression` | `PackedFloat32Array(...)` などは `const` にできない。`static func` で返す |
| `Trying to assign an array of type "Array" to ... Array[int]` | `duplicate()` は型なし配列を返す。`assign()` を使う |
| `Parameter "obj" is null` | 解放済みの相手の signal を切ろうとしている。`is_instance_valid()` で守る |
| `resources still in use at exit` | 購読の切り忘れ。lambda で `self` を捕まえると循環する（`dispose()` を用意する） |
| 依存方向のエラー | Game Core が上位層を参照している。`scripts/static-check.sh` が検出する |
| 結果が再現しない | グローバル乱数を使っている。Seed 付きの `RandomNumberGenerator` にする |

似た症状は `docs/` と過去の PR にも記録がある。

## 3. 直す

- **対症療法にしない。**なぜその値・その状態になったのかまで辿る
- 直したら**その不具合を捕まえるテストを足す**（同じ壊れ方を二度しないため）
- 数値の調整で直す場合は `config/` のデータを変える。コードへ埋めない

## 4. 確認

```sh
scripts/static-check.sh
scripts/verify-godot.sh
scripts/run-tests.sh
```

直した内容と、**なぜそれで直るのか**を報告する。
