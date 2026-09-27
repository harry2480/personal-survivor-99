# assets/music/

BGM の置き場所。

## 出典とライセンス（要件定義 §138 / #53 の完了条件）

**現在、この repository に外部から持ち込んだ音源は 1 つもない。**
BGM はすべて `audio/music_manager.gd` が実行時に生成している（2 音を重ねたループ）。

| 項目 | 内容 |
|---|---|
| 音源 | 本プロジェクトのコードによる生成（独自制作） |
| ライセンス | 本 repository の LICENSE に従う |
| 第三者の権利 | なし（外部素材を使用していない） |

## 状態（要件定義 §101）

```text
Menu / Battle Normal / Battle Mid / Battle Late / Final / Victory / Defeat
```

Battle 中の切り替えは残存人数の段階（要件定義 §93）に従う。
段階の判定は Battle Layer（`BattlePhase`）が持っており、BGM 側では判定しない。

**差し替えた音源は、出典とライセンスをこの表へ追記すること。**
