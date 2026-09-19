# Project 99

macOS（Apple Silicon）向けの 99 人対戦型 落ちものパズルゲーム。Godot 4 / GDScript で開発する。

- 1 人の Human と 98 体の CPU が同時に対戦し、最後の 1 人になるまで戦う
- オフライン専用。サーバーもアカウントも不要
- CPU の強さを広い範囲で変更でき、標準最高難易度を超える設定も可能

詳細は [docs/要件定義.md](docs/要件定義.md) と [docs/サービスコンセプト.md](docs/サービスコンセプト.md) を参照。

## 必要なもの

| 項目 | バージョン |
|---|---|
| Godot Engine | `.godot-version` に記載（現在 4.7.2-stable） |
| OS | macOS / Apple Silicon |

Godot のバージョンは `.godot-version` を唯一の参照元とする。CI はこのファイルを読んで
同じバージョンを取得するため、バージョンを上げるときはこのファイルと
[`ci/godot-checksums.txt`](ci/README.md) を更新すればよい。
無計画なマイナーバージョン変更は行わない（[要件定義.md](docs/要件定義.md) §7）。

### Godot の導入

```sh
brew install --cask godot
scripts/verify-godot.sh   # .godot-version と一致しない場合はここで失敗する
```

`brew` の cask は常に最新版のため、`.godot-version` とずれることがある。
バージョンを確実に合わせたい場合は、[GitHub Releases](https://github.com/godotengine/godot/releases) から
`Godot_v<version>_macos.universal.zip` を取得する。
取得したファイルは [`ci/godot-checksums.txt`](ci/README.md) の SHA-512 で検証できる。

```sh
shasum -a 512 -c --ignore-missing ci/godot-checksums.txt
```

## 起動

```sh
# エディタで開く
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .

# import + 起動を検証する（CI と同じ内容）
scripts/verify-godot.sh
```

`scripts/verify-godot.sh` は `.godot-version` との一致確認、import 検証、起動検証をまとめて行う。
Godot はスクリプトエラーが出ても終了コード 0 を返すため、このスクリプトが出力を走査して失敗させる。

`godot` をパスに通しておくと自動で見つかる。別の場所にある場合は `GODOT_BIN` で指定する。

```sh
GODOT_BIN=/path/to/godot scripts/verify-godot.sh
```

## テスト

自動テストは [GUT](https://github.com/bitwes/Gut) で書き、`godot --headless` で実行する。
GUT は `addons/gut/` にバージョン固定で同梱している（[addons/README.md](addons/README.md)）。

```sh
# tests/ 配下をすべて実行する
scripts/run-tests.sh

# ディレクトリやテスト名を絞る（GUT のオプションをそのまま渡せる）
scripts/run-tests.sh -gdir=res://tests/core
scripts/run-tests.sh -gunit_test_name=test_seeded_rng_is_reproducible
```

テストが 1 件でも失敗すると非 0 の終了コードで終わる。実行対象ディレクトリなどの
既定値は `.gutconfig.json` に定義する。

テストの書き方と対象は [テストガイドライン.md](docs/テストガイドライン.md) を参照。

## 品質チェック

CI と同じ内容をローカルで実行できる。PR を出す前にこの 3 つを通す。

```sh
scripts/static-check.sh   # GDScript の Lint / フォーマット / 命名規約 / 依存方向
scripts/verify-godot.sh   # import + 起動検証
scripts/run-tests.sh      # 自動テスト
```

`scripts/static-check.sh` は gdtoolkit（gdlint / gdformat）を使う。未導入なら次で入れる。

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r ci/requirements-static-check.txt
```

gdtoolkit を入れずに命名規約と依存方向だけ見たい場合は `SKIP_GDTOOLKIT=1` を付ける。
`shellcheck` と `actionlint` は導入済みの場合だけ実行される。

macOS Export の検証は Export Templates（約 1GB）の取得を伴うため、通常は CI に任せる。
ローカルで確認する場合は次を実行する。

```sh
scripts/export-macos.sh   # build/Project99.zip を生成して検証する
```

## CI

`.github/workflows/ci.yml` が PR と push で以下を実行する。Godot は `.godot-version` の
バージョンを取得し、`ci/godot-checksums.txt` の SHA-512 で検証してから使う。

| Job | Runner | 内容 |
|---|---|---|
| Static Check | ubuntu | `scripts/static-check.sh` |
| Import / 起動検証 | ubuntu | `scripts/verify-godot.sh` |
| Headless テスト | ubuntu | `scripts/run-tests.sh` |
| macOS Export Validation | macOS | `scripts/export-macos.sh` |
| CI ステータス確認 | ubuntu | 上記すべての成否を集約（branch protection はこれを required にする） |

実機が必要な Controller Test と Performance Test は自動化せず、Release 前の手動検証として扱う。

## ディレクトリ構成

[要件定義.md](docs/要件定義.md) §119 に従う。

```text
project.godot
├── addons/     # 外部アドオン（GUT）
├── assets/     # フォント・画像・音源・テーマ
├── core/       # Game Core Layer（Board / Piece / Rotation / Scoring / Attack / Garbage / Rules）
├── battle/     # Battle Layer（BattlePlayer / Target / Garbage Routing / KO / Rank / Multiplier）
├── cpu/        # CPU AI（評価・探索・Strength・Detailed / Lightweight）
├── input/      # Input Action → Game Command の抽象化
├── scenes/     # Boot / MainMenu / Battle / Settings / Result
├── ui/         # Presentation Layer のビュー
├── audio/      # Audio / BGM 管理
├── config/     # ゲームバランスと既定設定のデータ
├── tests/      # 自動テスト（core / battle / cpu / integration）
└── docs/       # 要件定義・設計ドキュメント
```

依存方向は `Presentation → Battle → Game Core` で、逆転させない。
Game Core は UI / Audio / Controller / Scene / FileSystem を知らない（[要件定義.md](docs/要件定義.md) §16〜§19）。

## 開発の進め方

開発は [docs/実装計画.md](docs/実装計画.md) の Phase 0〜10 の順に進める。各 Phase は GitHub Issue に分割済み。

Issue から実装・修復・PR までを反復する Loop Engineering を使う場合は、
[docs/loop-engineering.md](docs/loop-engineering.md) のラベル運用と安全境界に従う。

```sh
scripts/setup-loop-labels.sh   # Loop 用ラベルの作成・更新
scripts/loop-once.sh           # Loop を1回だけ実行
scripts/loop.sh                # 最大5回まで反復
bash scripts/merge-pr.sh       # PR マージ + ブランチ整理
```

`main` への直接 push は禁止。変更は feature / fix / refactor / perf / chore ブランチから PR を出す
（[要件定義.md](docs/要件定義.md) §120・§121）。

## ドキュメント

| ファイル | 内容 |
|---|---|
| [要件定義.md](docs/要件定義.md) | 全 144 節の完全要件定義。すべての判断の一次情報 |
| [実装計画.md](docs/実装計画.md) | Phase 0〜10 の開発計画と MVP 受入条件 |
| [アーキテクチャ.md](docs/アーキテクチャ.md) | 3 層構造・依存ルール・命名規約 |
| [コーディング規約.md](docs/コーディング規約.md) | GDScript の命名・型・Signal・Commit Convention |
| [テストガイドライン.md](docs/テストガイドライン.md) | 自動テストと手動検証の方針 |
| [品質チェック・テスト規約.md](docs/品質チェック・テスト規約.md) | 品質ゲートの定義 |
| [インフラストラクチャ規約.md](docs/インフラストラクチャ規約.md) | ビルド・配布・CI |
| [スタイルガイド.md](docs/スタイルガイド.md) | 表記・UI の統一ルール |
| [loop-engineering.md](docs/loop-engineering.md) | Loop 運用と安全境界 |
| [リポジトリ設定手順.md](docs/リポジトリ設定手順.md) | ブランチ保護 / auto-merge の適用手順（管理者作業） |

## ライセンス

[LICENSE](LICENSE) を参照。
