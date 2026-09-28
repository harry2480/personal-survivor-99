#!/usr/bin/env bash
# 連続試合でメモリが増え続けないかを計測する。
#
# Battle を 50 回作って捨て、メモリと Object 数の推移を出し、増分で合否を判定する（#56 の完了条件）。
# CI では動かさない。Release 前と、参照の持ち方を変えたときに手で実行する。
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

# Godot はスクリプトエラーでも終了コード 0 を返すので、出力の ERROR も見る。
# 増分の判定に落ちたときは stress_battles.gd が終了コード 1 を返す。
run_godot_step "Import" "$GODOT_DIAGNOSTICS_ERROR" "$godot_bin" --headless --import
run_godot_step "Stress battles" "$GODOT_DIAGNOSTICS_ERROR" \
  "$godot_bin" --headless -s res://tools/stress_battles.gd
