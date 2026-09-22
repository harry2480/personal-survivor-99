#!/usr/bin/env bash
# Godot プロジェクトの import と起動を検証する。
#
# Godot はスクリプトエラーが発生しても終了コード 0 を返すため、
# 終了コードだけでは品質ゲートにならない。出力を走査してエラー行を検出する。
# #16 の完了条件が「Import エラー・警告が出ない」ため、警告も失敗として扱う。
#
# 環境変数:
#   GODOT_BIN              Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=lib/godot-env.sh
. "$repo_root/scripts/lib/godot-env.sh"

godot_bin="$(resolve_godot_bin)"
actual="$(assert_godot_version "$godot_bin" "$repo_root")"

echo "Godot: $actual"
echo

run_godot_step "Import 検証" "$GODOT_DIAGNOSTICS_STRICT" "$godot_bin" --headless --import
run_godot_step "起動検証" "$GODOT_DIAGNOSTICS_STRICT" "$godot_bin" --headless --quit-after 30

echo "検証に成功しました"
