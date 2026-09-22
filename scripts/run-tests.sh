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
"$godot_bin" --headless --import >/dev/null

echo "==> GUT 実行"
status=0
"$godot_bin" --headless -s res://addons/gut/gut_cmdln.gd "$@" || status=$?

if [ "$status" -ne 0 ]; then
  echo "テストが失敗しました (exit=$status)" >&2
  exit "$status"
fi

echo "--> テスト: OK"
