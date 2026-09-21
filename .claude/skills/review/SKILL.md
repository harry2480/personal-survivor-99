---
description: 変更内容をレビューする。設計・テスト・性能の観点をまとめて確認する
---

# レビュースキル

`git diff` の内容に対して、このプロジェクトの決まりに沿っているかを見る。

## 1. 変更を把握する

```sh
git diff --stat
git diff
```

## 2. 観点

### 設計（要件定義 §16〜§19）

- [ ] 依存方向を逆転させていないか（Presentation → Battle → Game Core）
- [ ] Game Core が UI / Audio / Scene / FileSystem を参照していないか
- [ ] UI から Game Core の内部状態を直接書き換えていないか
- [ ] Battle Layer の判定（Danger など）を UI 側で作り直していないか
- [ ] Scene 遷移と Game State が `SceneRouter` に集約されているか

### 決定論と時間（§110 / §111）

- [ ] 乱数が Seed 指定で再現できるか。グローバル乱数を使っていないか
- [ ] 時間の処理が時間ベースか（FPS に依存していないか）

### データ（§38 / §39）

- [ ] 数値がコードへ埋まっていないか（`config/` の `.tres` / `.json`）
- [ ] 追加した設定項目が `config/README.md` に載っているか

### テスト

- [ ] 変更に対応するテストがあるか
- [ ] headless で通るか（`scripts/run-tests.sh`）
- [ ] Seed が固定されているか
- [ ] 「何を確かめているか」がテスト名と失敗メッセージから分かるか

### 性能（§84 / §102 / §105）

- [ ] 99 人戦で毎フレーム全走査していないか
- [ ] signal 経由で更新できるところを毎フレーム読み直していないか
- [ ] 重い処理を足したなら計測しているか（[docs/性能計測と最適化.md](../../../docs/性能計測と最適化.md)）

### 後片付け

- [ ] signal の購読を解除しているか（連続試合でのリーク）
- [ ] lambda で `self` を捕まえた購読に `dispose()` があるか

## 3. 品質チェック

```sh
scripts/static-check.sh
scripts/verify-godot.sh
scripts/run-tests.sh
```

## 4. 報告

指摘は**根拠（要件定義の節・計測結果・テスト）とセット**で書く。
好みの問題と、ルール違反は分けて書く。
