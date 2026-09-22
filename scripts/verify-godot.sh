#!/usr/bin/env bash
# Godot プロジェクトの import と起動を検証する。
#
# Godot はスクリプトエラーが発生しても終了コード 0 を返すため、
# 終了コードだけでは品質ゲートにならない。出力を走査してエラー行を検出する。
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

# Godot の出力を走査し、エラーまたは警告の行があれば失敗させる。
# #16 の完了条件が「Import エラー・警告が出ない」ため、警告も失敗として扱う。
run_step() {
  local label="$1"
  shift

  echo "==> $label"
  local output
  local status=0
  output="$("$@" 2>&1)" || status=$?
  printf '%s\n' "$output"

  if [ "$status" -ne 0 ]; then
    echo "$label が異常終了しました (exit=$status)" >&2
    return 1
  fi

  local diagnostics
  diagnostics="$(printf '%s\n' "$output" | grep -E '^(SCRIPT )?(ERROR|WARNING)' || true)"
  if [ -n "$diagnostics" ]; then
    echo "$label でエラーまたは警告が出力されました:" >&2
    printf '%s\n' "$diagnostics" >&2
    return 1
  fi

  echo "--> $label: OK"
  echo
}

run_step "Import 検証" "$godot_bin" --headless --import
run_step "起動検証" "$godot_bin" --headless --quit-after 30

echo "検証に成功しました"
