#!/usr/bin/env bash
# 配布用の macOS 成果物を作る（要件定義 §124 / §127）。
#
#   1. Export     … Project99.app を作る（Apple Silicon を含む universal）
#   2. Package    … .app を .zip に詰める（ditto で symlink と属性を保つ）
#   3. Checksum   … SHA-256 を出す
#
# Export Validation（scripts/export-macos.sh）は「Export が通るか」を見るもので、
# こちらは「配布する形」を作る。CI の Release ワークフローが呼ぶ。
#
# 環境変数:
#   GODOT_BIN                   Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する
#   GODOT_TEMPLATES_DIR         Export Templates の場所
#   RELEASE_VERSION             成果物名に付けるバージョン（未指定なら project.godot から）
#   PACKAGE_DIR                 出力先（既定: dist）
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=lib/godot-env.sh
. "$repo_root/scripts/lib/godot-env.sh"

preset="macOS"
app_name="Project99"
package_dir="${PACKAGE_DIR:-dist}"
app_path="${package_dir}/${app_name}.app"

# バージョンは project.godot の config/version を唯一の出どころにする。
version="${RELEASE_VERSION:-}"
if [ -z "$version" ]; then
  version="$(grep -E '^config/version=' project.godot | head -1 | cut -d'"' -f2)"
fi
if [ -z "$version" ]; then
  echo "バージョンを特定できませんでした（project.godot の config/version）" >&2
  exit 1
fi

zip_name="${app_name}-${version}-macos.zip"
zip_path="${package_dir}/${zip_name}"
checksum_path="${zip_path}.sha256"

godot_bin="$(resolve_godot_bin)"
godot_version="$(assert_godot_version "$godot_bin" "$repo_root")"

echo "Godot: ${godot_version}"
echo "バージョン: ${version}"
echo

"$repo_root/scripts/install-export-templates.sh"
echo

# 前回の成果物が残っていると、Export が失敗しても成功に見えてしまう。
# 消すのは自分が作った出力先だけに限定する。
if [ -e "$package_dir" ]; then
  find "$package_dir" -mindepth 1 -delete
fi
mkdir -p "$package_dir"

# Export は import 済みのプロジェクトを前提にする。
run_godot_step "Import" "$GODOT_DIAGNOSTICS_ERROR" "$godot_bin" --headless --import

echo "==> Export（preset: ${preset} → ${app_path}）"
status=0
export_log="$("$godot_bin" --headless --export-release "$preset" "$app_path" 2>&1)" || status=$?
printf '%s\n' "$export_log"

if [ "$status" -ne 0 ]; then
  echo "Export が異常終了しました (exit=${status})" >&2
  exit 1
fi

diagnostics="$(printf '%s\n' "$export_log" | grep -E '^(SCRIPT )?ERROR' || true)"
if [ -n "$diagnostics" ]; then
  echo "Export でエラーが出力されました:" >&2
  printf '%s\n' "$diagnostics" >&2
  exit 1
fi

if [ ! -d "$app_path" ]; then
  echo "アプリが生成されていません: ${app_path}" >&2
  exit 1
fi

echo
echo "==> Package（${zip_path}）"
# ditto は macOS の属性と symlink を保ったまま詰める（zip コマンドより安全）。
if command -v ditto >/dev/null 2>&1; then
  (cd "$package_dir" && ditto -c -k --sequesterRsrc --keepParent "${app_name}.app" "$zip_name")
else
  (cd "$package_dir" && zip -qry "$zip_name" "${app_name}.app")
fi

if [ ! -s "$zip_path" ]; then
  echo "配布物が生成されていません: ${zip_path}" >&2
  exit 1
fi

echo "==> Checksum（${checksum_path}）"
if command -v shasum >/dev/null 2>&1; then
  (cd "$package_dir" && shasum -a 256 "$zip_name" >"${zip_name}.sha256")
else
  (cd "$package_dir" && sha256sum "$zip_name" >"${zip_name}.sha256")
fi
cat "$checksum_path"

zip_size="$(wc -c <"$zip_path" | tr -d ' ')"
echo
echo "--> Package: OK"
echo "    app      : ${app_path}"
echo "    zip      : ${zip_path}（${zip_size} bytes）"
echo "    checksum : ${checksum_path}"
