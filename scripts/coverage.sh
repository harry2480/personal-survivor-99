#!/usr/bin/env bash
# GUT の自動テストを実行し、GDScript のカバレッジを LCOV で出力する。
#
# 計測には gd-tools（ci/requirements-coverage.txt でバージョン固定）を使う。
# gd-tools init は project.godot に計測用の Autoload を足し、.gutconfig.json も
# 書き換える。計測用のコードを製品へ混ぜないため、**一時ディレクトリへ写した
# プロジェクトの上で**計測し、作業ツリーには結果（build/coverage/lcov.info）だけを戻す。
#
# 計測は通常のテストより数倍遅い（手元で約 3 分）。テストの合否ゲートは
# scripts/run-tests.sh が担い、こちらはカバレッジを Codecov へ送るためだけに使う。
#
# 使い方:
#   pip install -r ci/requirements-coverage.txt   # Python 3.10 以上
#   scripts/coverage.sh
#
# 環境変数:
#   GODOT_BIN                   Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する
#   COVERAGE_OUTPUT             出力先（既定: build/coverage/lcov.info）
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=lib/godot-env.sh
. "$repo_root/scripts/lib/godot-env.sh"

if ! command -v gd-tools >/dev/null 2>&1; then
  echo "gd-tools が見つかりません。pip install -r ci/requirements-coverage.txt を実行してください。" >&2
  exit 1
fi

godot_bin="$(resolve_godot_bin)"
version="$(assert_godot_version "$godot_bin" "$repo_root")"
output="${COVERAGE_OUTPUT:-$repo_root/build/coverage/lcov.info}"

echo "Godot: $version"
echo

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# .git と import キャッシュは写さない。import は写した先でやり直す。
echo "==> 計測用にプロジェクトを写す: $work_dir"
tar -C "$repo_root" --exclude=./.git --exclude=./.godot --exclude=./build -cf - . \
  | tar -C "$work_dir" -xf -

cd "$work_dir"
export GODOT_BIN="$godot_bin"

echo "==> gd-tools init（写した先だけを書き換える）"
gd-tools init --non-interactive

# import 済みでないと addons のクラスが解決できないため、先に import を通す。
run_godot_step "Import" "$GODOT_DIAGNOSTICS_ERROR" "$godot_bin" --headless --import

echo "==> テスト + カバレッジ計測"
# CPU を実際に走らせて強さを比べるテストは、計測下では極端に遅いので飛ばす
# （tests/cpu/test_cpu_presets.gd）。合否ゲートの scripts/run-tests.sh では走る。
PROJECT99_COVERAGE=1 gd-tools test --coverage

echo "==> LCOV を出力"
gd-tools coverage report --format lcov

mkdir -p "$(dirname "$output")"
cp .gd-tools/coverage/coverage.info "$output"
echo "--> カバレッジ: $output"
