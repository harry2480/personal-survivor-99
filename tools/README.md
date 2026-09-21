# tools/

CI では動かさない計測・検証用のスクリプト置き場。

| ファイル | 内容 | 実行 |
|---|---|---|
| `benchmark_cpu_search.gd` | CPU の配置探索にかかる時間を測る | `scripts/benchmark-cpu.sh` |
| `benchmark_cpu_strength.gd` | Strength ごとの CPU の強さを測る | `scripts/benchmark-cpu-strength.sh` |
| `benchmark_battle_scaling.gd` | Player 数ごとの Simulation 負荷を測る | `scripts/benchmark-battle-scaling.sh` |
| `benchmark_cpu_scheduling.gd` | CPU 更新の分散の効き方を測る | `scripts/benchmark-cpu-scheduling.sh` |

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

席（Player ID）は試合ごとに 1 つずつずらす。時間切れで畳むときや Target の同点処理は
Player ID の順に決まるので、席を固定すると結果が席に寄る。試合数は Strength の数の倍数にする。

```sh
scripts/benchmark-cpu-strength.sh
```

Simulation は Lightweight（要件定義 §82）。盤面を持たずに指標だけを進めるため、
「探索の質」ではなく **Strength から決まる PPS・Garbage 処理・Attack 量の差**を見ることになる。
探索そのものの速さは `benchmark_cpu_search.gd` の担当。

### 計測結果（2026-09-26 / Seed 20260922 / 28 試合）

各 Strength を 1 体ずつ並べた 7 人戦。席は試合ごとにずらしている。計測時間は約 6 秒。

| Strength | 勝率 | 平均 Rank | 平均 Attack | 平均生存 (秒) |
|---|---|---|---|---|
| 10 | 0% | 5.68 | 0.0 | 11.7 |
| 30 | 0% | 4.89 | 1.0 | 13.2 |
| 50 | 0% | 5.43 | 3.5 | 12.7 |
| 70 | 0% | 4.54 | 7.2 | 14.7 |
| 85 | 0% | 4.00 | 12.9 | 15.7 |
| 100 | 0% | 2.46 | 21.5 | 17.6 |
| 150 | **100%** | 1.00 | 148.8 | 18.2 |

Attack 量は Strength の順に並ぶ。平均 Rank も 70 以上は順に並ぶが、**30 と 50 が逆転している**。
Machine 相当（150）の Attack が桁違いで 20 秒足らずで決着するため、下位の順位は
「150 に狙われたか」で決まりやすい。Strength Mapping を見直すときの確認事項として残す。

以前（2026-09-22）の表は席を固定して測っており、平均 Rank がきれいに並んでいたのは
席の偏りによるところがあった。

### 見るところ

平均 Rank が Strength の順に並んでいれば、Strength を上げたぶんだけ強くなっている。
並びが崩れていたら `config/cpu_strength_mapping.tres` のカーブを見直す。

### CI では動かさない

試合を最後まで回すため実行時間が長い。通常の CI の必須 check には含めず、
Strength Mapping を調整したときに手で実行する（#45 の制約）。

## benchmark_battle_scaling.gd

Player 数を 2 → 10 → 30 → 50 → 99 と上げたときの Simulation 負荷（#46 の完了条件）。

```sh
scripts/benchmark-battle-scaling.sh
```

Human 1 人 + CPU の構成で Battle を回し、1 フレームの処理時間・FPS 換算・Detailed CPU の数を出す。
**描画を含まない Simulation だけ**の値。描画込みの実機 FPS は Phase 10（#55）で測る。

### 計測結果（2026-09-22 / Apple Silicon / Godot 4.7.2 / Seed 20260922）

| Player | 平均 (ms) | 最大 (ms) | FPS 換算 | Detailed CPU | Top Out | 決着 |
|---|---|---|---|---|---|---|
| 2 | 0.030 | 0.049 | 1000+ | 0 | 0 | 決着 |
| 10 | 0.075 | 0.262 | 1000+ | 0 | 6 | 時間切れ |
| 30 | 0.519 | 134.100 | 1000+ | 0 | 23 | 時間切れ |
| 50 | 0.817 | 3.622 | 1000+ | 0 | 41 | 時間切れ |
| 99 | 1.762 | 13.167 | 568 | 0 | 79 | 時間切れ |

99 人でも平均 1.8 ms で、1 フレームの予算（16.7 ms）の約 1 割。**平均では 60 FPS に十分届く**。

ただし**最大値が跳ねる**（30 人で 134 ms、99 人で 13 ms）。脱落が重なったフレームで
Ranking / Multiplier / Target の更新が同時に走るため。1 フレームの偏りをならすのは
CPU Update Scheduling（Phase 7 / #47）の担当。

### 「時間切れ」について

Lightweight Simulation（要件定義 §82）では、強い CPU ほど Garbage を捌き切ってしまい、
終盤に残った数体が相殺し合って決着しない。上限時間（300 秒）で盤面の悪い順に畳んでいる。
99 人戦では 98 体中 79 体が実際に Top Out して脱落し、残りが畳み込みになった。

Detailed Simulation では Misdrop（要件定義 §67）があるため決着する。
Lightweight の近似精度を上げるかは Phase 10（#55）で判断する。

## benchmark_cpu_scheduling.gd

CPU 更新の分散（要件定義 §104）が 1 フレームのコストに効くかの計測（#47 の完了条件）。

```sh
scripts/benchmark-cpu-scheduling.sh
```

98 体の CPU を、分散なし（毎フレーム全員）と分散あり（組に分ける）で 1800 フレーム回す。

### 計測結果（2026-09-22 / Apple Silicon / Godot 4.7.2 / CPU 98 体）

| 分散 | 平均 (ms) | p99 (ms) | 1 フレームで動かす CPU |
|---|---|---|---|
| なし | 0.084 | 0.685 | 98 |
| 2 分割 | 0.021 | 0.053 | 49 |
| 4 分割 | 0.012 | 0.027 | 25 |
| 8 分割 | 0.007 | 0.016 | 13 |

**分散しても CPU の仕事の総量は変わらない。**効くのは重いフレームで、
p99 が 0.685 ms → 0.016 ms（8 分割）まで下がる。Human Input は前のフレームの
処理が終わるまで待つため、重いフレームが減るほど Input の待ちも短くなる
（MVP 受入条件 29）。

既定は 4 分割（`CpuSchedulePolicy.slice_count`）。Lightweight CPU では元々軽いので
差は小さいが、Detailed CPU（1 手 6〜55 ms。`benchmark_cpu_search.gd` の計測）が
混ざるほど効きが大きくなる。

### 注意

最初に測る行はプロセス起動直後の影響を受け、最大値が跳ねることがある。
傾向は平均と p99 で見る。
