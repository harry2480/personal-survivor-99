# config/

ゲームバランスと既定設定のデータ置き場（要件定義 §39 Game Balance Data）。

| ファイル | 内容 | 追加する Phase |
|---|---|---|
| `game_rules.tres` | Gravity / Lock Delay / DAS / ARR / Soft Drop Speed などのルール値 | Phase 1（#24 / #26） |
| `game_balance.tres` | Combo Table / B2B 対象 Clear（#28）、Line Attack / T-Spin Attack / T-Spin Mini Attack / B2B Bonus / Perfect Clear Attack（#30）、Garbage Delay / Hole Mode（#31）。Multiplier は Phase 4 で追加 | Phase 2（#28 / #30 / #31）、Phase 4（#37） |
| `cpu_profiles.tres` | Board Evaluation の重みと CPU のパラメータ（#38 / #40） | Phase 5（#38 / #40）、Phase 6（#43 / #44） |
| `cpu_strength_mapping.tres` | Strength から各パラメータへの変換表（#40）と Human-like の限界（#43） | Phase 5（#40）、Phase 6（#43） |
| `cpu_distribution.tres` | 99 人戦の CPU Strength 分布と Fixed Strength Mode（#44） | Phase 6（#44） |
| `dynamic_difficulty.tres` | 成績に応じた難易度の自動調整（既定 OFF。#44） | Phase 6（#44） |
| `cpu_scheduling.tres` | CPU 更新の分散と負荷時の削り方（#47） | Phase 7（#47） |
| `defaults.json` | ユーザー設定の既定値（UserSettings が読む） | Phase 9（#52） |

数値をコードへ固定せず、ここで定義する（要件定義 §38）。
ユーザーが変更した設定は `user://settings.json` に保存する（要件定義 §98 / #52）。
`game_rules.tres` は Phase 1（#24 / #26）、`game_balance.tres` は #28 / #30 / #31 で中身が入った。
`cpu_profiles.tres` は #38 で評価の重み、`cpu_strength_mapping.tres` は #40 で変換表が入った。
#43 で変換表の節点を Machine 相当（Strength 150）まで伸ばし、Human-like の上限・下限を足した。
