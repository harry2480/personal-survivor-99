#!/usr/bin/env bash
# Strength ごとの CPU の強さを計測する。
#
# CPU 同士を戦わせ、Strength ごとの勝率・平均 Rank・平均 Attack を出す（#45 の完了条件）。
# 実行時間が長いため CI では動かさない。Strength Mapping を調整したときに手で実行する。
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
"$godot_bin" --headless -s res://tools/benchmark_cpu_strength.gd
