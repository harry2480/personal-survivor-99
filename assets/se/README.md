# assets/se/

SE（効果音）の置き場所。

## 出典とライセンス（要件定義 §138 / #53 の完了条件）

**現在、この repository に外部から持ち込んだ音源は 1 つもない。**
SE はすべて `audio/sound_bank.gd` が実行時に生成している（減衰付きのサイン波）。

| 項目 | 内容 |
|---|---|
| 音源 | 本プロジェクトのコードによる生成（独自制作） |
| ライセンス | 本 repository の LICENSE に従う |
| 第三者の権利 | なし（外部素材を使用していない） |

## 差し替えるとき

`assets/se/` に Event 名（小文字）のファイルを置くと、そちらが使われる。

```text
assets/se/hard_drop.wav
assets/se/line_clear.ogg
```

対応する Event 名は `AudioManager.Event`（要件定義 §100 の 16 種類）。

```text
move / rotate / hold / soft_drop / hard_drop / lock / line_clear /
high_value_clear / combo / garbage_send / garbage_receive /
target_change / danger / ko / victory / defeat
```

**差し替えた音源は、出典とライセンスをこの表へ追記すること。**
権利の不明な音源は置かない（要件定義 §138）。
