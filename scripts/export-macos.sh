#!/usr/bin/env bash
# macOS 向け Export が通ることを検証する（Export Validation）。
#
# Export Preset は export_presets.cfg の "macOS" を使い、ローカルと CI で同一にする。
# Godot は Export に失敗しても終了コード 0 を返すことがあるため、
# 出力の走査と成果物の存在確認で判定する。
#
# 環境変数:
#   GODOT_BIN                   Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する
#   GODOT_TEMPLATES_DIR         Export Templates の場所
#   EXPORT_OUTPUT               出力先（既定: build/Project99.zip）
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=lib/godot-env.sh
. "$repo_root/scripts/lib/godot-env.sh"

preset="macOS"
output="${EXPORT_OUTPUT:-build/Project99.zip}"

godot_bin="$(resolve_godot_bin)"
version="$(assert_godot_version "$godot_bin" "$repo_root")"

echo "Godot: $version"
echo

"$repo_root/scripts/install-export-templates.sh"
echo

mkdir -p "$(dirname "$output")"

# 前回の成果物が残っていると、Export が失敗しても成功に見えてしまう。
if [ -e "$output" ]; then
  unlink "$output"
fi

# Export は import 済みのプロジェクトを前提にする。
"$godot_bin" --headless --import >/dev/null

echo "==> Export 検証（preset: $preset → $output）"
status=0
export_log="$("$godot_bin" --headless --export-release "$preset" "$output" 2>&1)" || status=$?
printf '%s\n' "$export_log"

if [ "$status" -ne 0 ]; then
  echo "Export が異常終了しました (exit=$status)" >&2
  exit 1
fi

diagnostics="$(printf '%s\n' "$export_log" | grep -E '^(SCRIPT )?ERROR' || true)"
if [ -n "$diagnostics" ]; then
  echo "Export でエラーが出力されました:" >&2
  printf '%s\n' "$diagnostics" >&2
  exit 1
fi

if [ ! -s "$output" ]; then
  echo "成果物が生成されていません: $output" >&2
  exit 1
fi

size="$(wc -c < "$output" | tr -d ' ')"
echo
echo "--> Export 検証: OK（$output / ${size} bytes）"
