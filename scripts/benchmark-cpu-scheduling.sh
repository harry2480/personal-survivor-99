#!/usr/bin/env bash
# CPU 更新の分散が 1 フレームのコストに効くかを計測する。
#
# 98 体の CPU を分散あり / なしで回し、1 フレームあたりの CPU 更新時間を出す（#47 の完了条件）。
# CI では動かさない。分散の設定を見直すときに手で実行する。
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

echo "Godot: ${version}"
echo

"$godot_bin" --headless --import >/dev/null
"$godot_bin" --headless -s res://tools/benchmark_cpu_scheduling.gd
