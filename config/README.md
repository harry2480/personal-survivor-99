# config/

ゲームバランスと既定設定のデータ置き場（要件定義 §39 Game Balance Data）。

| ファイル | 内容 | 追加する Phase |
|---|---|---|
| `game_rules.tres` | Gravity / Lock Delay / DAS / ARR / Soft Drop Speed などのルール値 | Phase 1（#24 / #26） |
| `game_balance.tres` | Line Attack / T-Spin Attack / Combo Table / B2B Bonus / Perfect Clear Attack / Garbage Delay / Multiplier | Phase 2（#28 / #30 / #31）、Phase 4（#37） |
| `cpu_profiles.tres` | CPU Strength Mapping と Preset | Phase 5（#40）、Phase 6（#43 / #44） |
| `defaults.json` | ユーザー設定の既定値 | Phase 9（#52） |

数値をコードへ固定せず、ここで定義する（要件定義 §38）。
現時点ではいずれも中身が空のプレースホルダー。
