#!/usr/bin/env bash
# Player 数ごとの Simulation 負荷を計測する。
#
# 2 → 10 → 30 → 50 → 99 の各構成で Battle を回し、1 フレームの処理時間と FPS 換算を出す（#46 の完了条件）。
# 実行時間が長いため CI では動かさない。負荷の傾向を確認したいときに手で実行する。
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
"$godot_bin" --headless -s res://tools/benchmark_battle_scaling.gd
