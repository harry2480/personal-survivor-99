# Project 99

macOS（Apple Silicon）向けの 99 人対戦型 落ちものパズルゲーム。Godot 4 / GDScript。

## 使い方（利用者向け）

- エディタで開く: `/Applications/Godot.app/Contents/MacOS/Godot --editor --path .`
- 変更後の確認: `scripts/verify-godot.sh`
- 機能を追加したいときは Claude Code に「〇〇な機能を作って」と指示するだけでOK
- 画面を作りたいときは「〇〇な画面を作って」と指示
- エラーが出たらエラーメッセージを貼り付けて「直して」と指示

### コマンド一覧

```sh
# エディタ起動
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .

scripts/static-check.sh         # Lint / フォーマット / 命名規約 / 依存方向
scripts/verify-godot.sh         # import + 起動検証（CI と同じ）
scripts/run-tests.sh            # GUT の自動テストを headless 実行
scripts/coverage.sh             # カバレッジ計測（LCOV。gd-tools が必要）
scripts/export-macos.sh         # macOS Export Validation（Export Templates が必要）
scripts/benchmark-cpu.sh        # CPU の配置探索の計測（CI では動かさない）
scripts/benchmark-cpu-strength.sh  # Strength ごとの CPU の強さの計測（CI では動かさない）
scripts/setup-loop-labels.sh   # Loop 用ラベルの作成・更新
scripts/loop-once.sh           # Loopを1回だけ実行
scripts/loop.sh                # 最大5回までLoopを反復（LOOP_MAX_ITERATIONSで調整）
bash scripts/merge-pr.sh       # PR マージ + ブランチ整理
```

自動テストは GUT で書き、`scripts/run-tests.sh` で実行する。
CI（Static Check / Import / Headless テスト / macOS Export Validation）は
`.github/workflows/ci.yml` で、ローカルと同じスクリプトを呼ぶ。
Coverage job は `scripts/coverage.sh` の結果を Codecov へ送る（合否ゲートには含めない）。

Loopを使う場合は [docs/loop-engineering.md](docs/loop-engineering.md) の初期設定、Issue信頼境界、auto-merge条件に従う。Loop関連コマンドは `.claude/commands/loop-*.md` に定義する。

---

## Claude Code への指示（利用者は読まなくてOK）

### 一次情報

判断に迷ったら [docs/要件定義.md](docs/要件定義.md)（全144節）を読むこと。このファイルと docs が食い違う場合は要件定義を優先する。
開発の順序は [docs/実装計画.md](docs/実装計画.md) の Phase 0〜10 に従い、先のフェーズの作業を前倒ししない。

### アーキテクチャ

Godot 4 プロジェクト。3層構造で、依存方向を逆転させない（要件定義 §16〜§19）。

```
Presentation Layer  →  Battle Layer  →  Game Core Layer
```

- **Game Core (`core/`)** — Board / Piece / Rotation / Collision / Gravity / Lock / Hold / Line Clear / Combo / B2B / T-Spin / Perfect Clear / Attack / Garbage。可能な限り決定論的な状態遷移として実装する
- **Battle (`battle/`)** — BattlePlayer / Targeting / Garbage Routing / KO / Ranking / Attack Multiplier / Battle Phase
- **Presentation (`scenes/`, `ui/`, `audio/`)** — Player Board / Opponent Grid / HUD / Menu / Settings / Result / Effects / Audio
- **CPU (`cpu/`)** — Board Evaluation / Placement Search / Strength / Detailed・Lightweight Simulation
- **Input (`input/`)** — Input Action → Game Command の抽象化

**Game Core が知ってはいけないもの**: UI / Audio / Controller / Scene / Animation / File System / Opponent Grid。
**UI から Game Core の内部状態を直接変更しない。**

### ファイル配置ルール

要件定義 §119 に従う。

```
core/
├── board/      # Board、Line Clear
├── piece/      # Piece 定義、7-Bag、NEXT、Hold
├── rotation/   # SRS Rotation、Wall Kick、Collision
├── scoring/    # Combo、B2B、Score
├── attack/     # Attack Calculator
├── garbage/    # Garbage Event / Queue / Hole / Cancellation
└── rules/      # Gravity、Lock Delay、DAS/ARR、T-Spin 判定
battle/         # battle_manager.gd, battle_player_state.gd, target_manager.gd,
                # garbage_router.gd, ko_system.gd, ranking_system.gd, multiplier_system.gd
cpu/            # cpu_manager.gd, cpu_profile.gd, cpu_strength.gd, board_evaluator.gd,
                # placement_search.gd, detailed_cpu.gd, lightweight_cpu.gd
input/          # input_manager.gd, keyboard.gd, gamepad.gd
scenes/         # boot/ main_menu/ battle/ settings/ result/ + scene_router.gd, game_state.gd
ui/             # board/ opponent/ hud/ menu/ components/
audio/          # audio_manager.gd, music_manager.gd
config/         # game_rules.tres, game_balance.tres, cpu_profiles.tres, defaults.json
tests/          # core/ battle/ cpu/ integration/（ソース構造を mirror）
```

### Key Rules

- ファイル・ディレクトリ命名は snake_case。クラス名は PascalCase
- 数値をコードへ固定しない。Gravity / Lock Delay / DAS / ARR / Attack / Combo Table / CPU Parameters はすべて `config/` のデータで定義する（要件定義 §38・§39）
- 時間に関わる処理は時間ベースで実装する。FPS 依存にしない（Gravity / Lock Delay / DAS / ARR / Reaction Time）
- 乱数は Seed 指定で再現できるようにする。グローバルな乱数状態に依存しない（要件定義 §110）
- Game Core は決定論的に保つ。将来の Replay（Seed + Input Sequence）の前提になる（要件定義 §111）
- ゲームロジックで物理ボタン番号を扱わない。Input Action → Game Command を経由する（要件定義 §11）
- Danger 判定など、Battle Layer が持つべき判定を UI 側で独自に行わない
- Scene 遷移と Game State は `scenes/scene_router.gd`（Autoload `SceneRouter`）に集約する
- 負荷が高い場合の優先順位: `Human Input > Game Core > Battle State > Rendering > CPU Search Depth > Visual Effects`（要件定義 §84）

### テスト

- `tests/core/`, `tests/battle/`, `tests/cpu/` — Unit テスト（外部依存なし、Seed 固定）
- `tests/integration/` — Battle 完走などの統合テスト
- すべて `godot --headless` で実行できること
- 実機が必要な Controller Test と Performance Test は自動化せず、Release 前の手動検証として扱う

テストは `extends GutTest` で書き、`scripts/run-tests.sh` で実行する。
GUT は `addons/gut/` にバージョン固定で同梱している（更新手順は `addons/README.md`）。
`addons/gut/` 配下は上流のコードなので変更しない。

### 品質チェック

コード変更後は最低限これを実行して、エラーが出ないことを確認する。

```sh
scripts/static-check.sh   # Lint / フォーマット / 命名規約 / 依存方向
scripts/verify-godot.sh   # import + 起動検証
scripts/run-tests.sh      # 自動テスト
```

Godot はスクリプトエラーが出ても終了コード 0 を返すため、終了コードだけで成否を判断しない。
`scripts/verify-godot.sh` は出力に `ERROR` / `SCRIPT ERROR` / `WARNING` があれば失敗する。
CI も同じスクリプトを使う。

`scripts/static-check.sh` は gdtoolkit を使う。未導入の環境では
`pip install -r ci/requirements-static-check.txt` を実行するか、`SKIP_GDTOOLKIT=1` を付ける。

### Git

- default branch は `main`。`main` への直接 commit / push は禁止（要件定義 §120）
- ブランチは `feature/*` `fix/*` `refactor/*` `perf/*` `chore/*`
- Commit prefix は `feat:` `fix:` `refactor:` `perf:` `test:` `docs:` `chore:`（要件定義 §121）
- 命名・型・Signal・commit の書き方の詳細は docs/コーディング規約.md
- リポジトリ設定（ブランチ保護 / auto-merge / secret）は変更しない。手順は docs/リポジトリ設定手順.md に記載し、適用は管理者が行う

### 詳細ルール

詳細な設計ルールは必要に応じて docs/ を読むこと:

- docs/要件定義.md — 全144節の一次情報
- docs/実装計画.md — Phase 0〜10・MVP 受入条件・主要リスク
- docs/アーキテクチャ.md — 3層構造・依存ルール・命名規約
- docs/コーディング規約.md — GDScript の命名・型・Signal・ファイル分割・Commit Convention
- docs/フロントエンドアーキテクチャ.md — Presentation Layer のデータフローとUI規約
- docs/インフラストラクチャ規約.md — ビルド・配布・CI
- docs/品質チェック・テスト規約.md — 品質ゲートの定義
- docs/テストガイドライン.md — テスト方針と手動検証手順
- docs/スタイルガイド.md — 表記・UI の統一ルール
- docs/loop-engineering.md — Loop運用と安全境界
- docs/リポジトリ設定手順.md — ブランチ保護 / auto-merge（管理者作業。AI は変更しない）
