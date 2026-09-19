#!/usr/bin/env bash
# GUT の自動テストを godot --headless で実行する。
#
# 使い方:
#   scripts/run-tests.sh                        # tests/ 配下をすべて実行
#   scripts/run-tests.sh -gdir=res://tests/core # GUT のオプションをそのまま渡す
#   scripts/run-tests.sh -gunit_test_name=test_seeded
#
# 実行対象ディレクトリ・ログレベル等の既定値は .gutconfig.json に定義する。
# テストが 1 件でも失敗すると非 0 の終了コードで終わるため、CI ゲートとして使える。
#
# 環境変数:
#   GODOT_BIN                   Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=lib/godot-env.sh
. "$repo_root/scripts/lib/godot-env.sh"

godot_bin="$(resolve_godot_bin)"
version="$(assert_godot_version "$godot_bin" "$repo_root")"

echo "Godot: $version"
echo

# import 済みでないと addons/gut のクラスが解決できないため、先に import を通す。
# Godot は import に失敗しても終了コード 0 を返すため、出力も走査する。
run_godot_step "Import" "$GODOT_DIAGNOSTICS_ERROR" "$godot_bin" --headless --import

echo "==> GUT 実行"
status=0
output="$("$godot_bin" --headless -s res://addons/gut/gut_cmdln.gd "$@" 2>&1)" || status=$?
printf '%s\n' "$output"

if [ "$status" -ne 0 ]; then
  echo "テストが失敗しました (exit=$status)" >&2
  exit "$status"
fi

# RefCounted 同士が signal で参照し合うと循環して解放されない。Godot は終了時に
# これを報告するが、終了コードには表れないため出力を走査する。
# 99 人戦（Phase 7）と連戦のリーク検証（Phase 10 / #56）の前提になる。
if printf '%s\n' "$output" | grep -q "resources still in use at exit"; then
  printf '%s\n' "$output" | grep "resources still in use at exit" >&2
  echo "解放されていないオブジェクトがあります。signal の購読を解除してください。" >&2
  exit 1
fi

echo "--> テスト: OK"
