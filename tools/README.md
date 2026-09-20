# tools/

CI では動かさない計測・検証用のスクリプト置き場。

| ファイル | 内容 | 実行 |
|---|---|---|
| `benchmark_cpu_search.gd` | CPU の配置探索にかかる時間を測る | `scripts/benchmark-cpu.sh` |

## benchmark_cpu_search.gd

`PlacementSearch.MAX_SEARCH_DEPTH` を根拠のある数字にするための計測（#39 の完了条件）。

判断の基準は要件定義 §84「CPU 思考が Human Input を遅延させない」。

### 計測結果（2026-09-20 / Apple Silicon / Godot 4.7.2）

積み上がった盤面（高さ 2〜8 の凸凹）で T Piece を 1 手探索したときの時間。

| 深さ | 1 手 | 99 体が同時 | 99 体 × 2 手/秒 |
|---|---|---|---|
| 1 | 6.0 ms | 592 ms | 1184 ms/秒 |
| 2 | 55 ms | 5484 ms | 10968 ms/秒 |
| 3 | **3225 ms** | — | — |

深さ 3 は深さ 2 の **58 倍**。Beam Width を掛けても桁が違うため、`MAX_SEARCH_DEPTH = 2` とした。

深さ 1 でも 99 体を同じフレームで走らせると 1 フレームの予算（60fps = 16.7 ms）を超える。
CPU は Piece ごとにしか考えないので実効的な負荷はもっと低いが、
**更新の分散（Phase 7 / #47）と Lightweight CPU（#42）が前提**になる。

### 上限を見直すとき

探索やコリジョンの実装を変えたら測り直し、この表と
`PlacementSearch.MAX_SEARCH_DEPTH` のコメントを更新する。
