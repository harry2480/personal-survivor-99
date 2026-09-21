---
description: 機能を追加する。ユーザーが「〇〇な機能を作って」と指示したとき、3 層のどこに置くかを決めてファイルとテストを作る
---

# 機能追加スキル

Godot 4 / GDScript のプロジェクト。追加する前に**どの層の話か**を決める（要件定義 §16〜§19）。

```text
Presentation Layer  →  Battle Layer  →  Game Core Layer
```

## 1. 置き場所を決める

| 追加したいもの | 層 | 置き場所 |
|---|---|---|
| 盤面・Piece・回転・重力・Line Clear・Attack・Garbage の規則 | Game Core | `core/`（`board/` `piece/` `rotation/` `scoring/` `attack/` `garbage/` `rules/`） |
| Player の状態・Target・KO・順位・倍率・Battle の段階 | Battle | `battle/` |
| CPU の評価・探索・強さ・Simulation | CPU | `cpu/` |
| 入力の抽象化 | Input | `input/` |
| 画面・HUD・盤面表示・Audio | Presentation | `scenes/` `ui/` `audio/` |

迷ったら [docs/要件定義.md](../../../docs/要件定義.md) の該当する節を読む（§119 にファイル配置がある）。

## 2. 守ること

- **Game Core は UI / Audio / Controller / Scene / Animation / FileSystem を知らない**
- **UI から Game Core の内部状態を直接変更しない**
- 数値をコードへ固定しない。`config/` の `.tres` / `.json` に置く（§38・§39）
- 時間に関わる処理は時間ベースで書く。FPS に依存させない
- 乱数は Seed 指定で再現できるようにする（§110）
- Battle Layer が持つ判定（Danger など）を UI 側で作り直さない

## 3. 作るもの

1. **本体**（例: `core/rules/lock_delay.gd`）
   - `class_name` は PascalCase、ファイルは snake_case
   - クラスの冒頭に `##` で「何をするものか」と対応する要件定義の節を書く
   - 状態を持たないなら `static func` にする

2. **設定**（必要なら `config/*.tres` の項目を増やす）
   - `@export` を足し、`config/README.md` の表を更新する

3. **テスト**（`tests/core/` `tests/battle/` `tests/cpu/` `tests/integration/`）
   - `extends GutTest`、Seed 固定、外部依存なし
   - 「何を確かめているか」がテスト名から分かるようにする

## 4. 確認

```sh
scripts/static-check.sh
scripts/verify-godot.sh
scripts/run-tests.sh
```

3 つとも通ってから PR を出す。Godot は終了コード 0 でもエラーを出すことがあるため、
出力まで見る（スクリプト側で走査している）。
