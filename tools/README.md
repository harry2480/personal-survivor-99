# tools/

CI では動かさない計測・検証用のスクリプト置き場。

| ファイル | 内容 | 実行 |
|---|---|---|
| `benchmark_cpu_search.gd` | CPU の配置探索にかかる時間を測る | `scripts/benchmark-cpu.sh` |
| `benchmark_cpu_strength.gd` | Strength ごとの CPU の強さを測る | `scripts/benchmark-cpu-strength.sh` |

## benchmark_cpu_search.gd

`PlacementSearch.MAX_SEARCH_DEPTH` を根拠のある数字にするための計測（#39 の完了条件）。

判断の基準は要件定義 §84「CPU 思考が Human Input を遅延させない」。

### 計測結果（2026-09-25 / Apple Silicon / Godot 4.7.2）

積み上がった盤面（高さ 2〜8 の凸凹）で T Piece を 1 手探索したときの時間。

| 深さ | 1 手 | 99 体が同時 | 99 体 × 2 手/秒 |
|---|---|---|---|
| 1 | 5.9 ms | 586 ms | 1173 ms/秒 |
| 2 | 45 ms | 4414 ms | 8828 ms/秒 |
| 3 | **670 ms** | 66334 ms | 132669 ms/秒 |

深さ 3 は深さ 2 の **15 倍**。Beam Width を掛けても桁が違うため、`MAX_SEARCH_DEPTH = 2` とした。

深さ 1 でも 99 体を同じフレームで走らせると 1 フレームの予算（60fps = 16.7 ms）を超える。
CPU は Piece ごとにしか考えないので実効的な負荷はもっと低いが、
**更新の分散（Phase 7 / #47）と Lightweight CPU（#42）が前提**になる。

深さ 3 は上限の先なので、計測では `PlacementSearch` に `MAX_SEARCH_DEPTH + 1` を渡して測っている
（ゲームからは渡さない）。

### 上限を見直すとき

探索やコリジョンの実装を変えたら測り直し、この表と
`PlacementSearch.MAX_SEARCH_DEPTH` のコメントを更新する。

## benchmark_cpu_strength.gd

Strength Mapping（要件定義 §78）が素直に効いているかを数字で確かめる計測（#45 の完了条件）。

CPU 同士を戦わせ、Strength ごとの**勝率・平均 Rank・平均 Attack・平均生存時間**を出す。
1 試合につき、測る Strength を 1 体ずつ並べる。Seed を固定してあるので結果は再現する。

```sh
scripts/benchmark-cpu-strength.sh
```

Simulation は Lightweight（要件定義 §82）。盤面を持たずに指標だけを進めるため、
「探索の質」ではなく **Strength から決まる PPS・Garbage 処理・Attack 量の差**を見ることになる。
探索そのものの速さは `benchmark_cpu_search.gd` の担当。

### 計測結果（2026-09-22 / Seed 20260922 / 5 試合）

各 Strength を 1 体ずつ並べた 7 人戦。

| Strength | 勝率 | 平均 Rank | 平均 Attack | 平均生存 (秒) |
|---|---|---|---|---|
| 10 | 0% | 5.80 | 0.0 | 12.7 |
| 30 | 0% | 5.20 | 1.0 | 14.7 |
| 50 | 0% | 5.00 | 3.8 | 14.3 |
| 70 | 0% | 4.80 | 8.0 | 16.5 |
| 85 | 0% | 3.40 | 14.4 | 17.7 |
| 100 | 0% | 2.80 | 23.6 | 19.3 |
| 150 | **100%** | 1.00 | 167.4 | 20.7 |

平均 Rank は Strength の順に並んでおり、Strength を上げたぶんだけ強くなっている。
Machine 相当（150）は 5 試合すべてで優勝した。

### 見るところ

平均 Rank が Strength の順に並んでいれば、Strength を上げたぶんだけ強くなっている。
並びが崩れていたら `config/cpu_strength_mapping.tres` のカーブを見直す。

### CI では動かさない

試合を最後まで回すため実行時間が長い。通常の CI の必須 check には含めず、
Strength Mapping を調整したときに手で実行する（#45 の制約）。
