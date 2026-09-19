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

godot_bin="${GODOT_BIN:-}"
if [ -z "$godot_bin" ]; then
  if command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
  elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo "Godot が見つかりません。GODOT_BIN で実行ファイルを指定してください。" >&2
    exit 1
  fi
fi

pinned="$(tr -d '[:space:]' < .godot-version)"
actual="$("$godot_bin" --version | head -n 1)"
if [ "${SKIP_GODOT_VERSION_CHECK:-0}" != "1" ]; then
  # .godot-version は "4.7.2-stable"、--version は "4.7.2.stable.official.xxxxxxx"
  expected="${pinned/-/.}"
  case "$actual" in
    "$expected"*) ;;
    *)
      echo "Godot のバージョンが固定値と一致しません。" >&2
      echo "  .godot-version: $pinned" >&2
      echo "  実行ファイル:   $actual" >&2
      echo "意図的に別バージョンを使う場合は SKIP_GODOT_VERSION_CHECK=1 を指定してください。" >&2
      exit 1
      ;;
  esac
fi

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
