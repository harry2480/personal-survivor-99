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
#   RELEASE_VERSION             成果物名に付けるバージョン（未指定なら project.godot から）。
#                               指定する場合は project.godot の config/version と一致させる
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
# .app の Info.plist（export_presets.cfg を空欄にして config/version へ任せている）と
# 成果物名がずれないよう、RELEASE_VERSION を指定するなら同じ値でなければ止める。
project_version="$(grep -E '^config/version=' project.godot | head -1 | cut -d'"' -f2)"
if [ -z "$project_version" ]; then
  echo "バージョンを特定できませんでした（project.godot の config/version）" >&2
  exit 1
fi
version="${RELEASE_VERSION:-$project_version}"
if [ "$version" != "$project_version" ]; then
  echo "RELEASE_VERSION（${version}）が project.godot の config/version（${project_version}）と違います。" >&2
  echo "先に config/version を上げる PR を main へ入れてください（docs/リリース手順.md 3.）。" >&2
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
# 消すのはこのスクリプトが作るファイルだけにする。PACKAGE_DIR は外から変えられるので、
# 出力先の中身をまとめて消すと、"." などを渡されたときにリポジトリごと消えてしまう。
rm -rf -- "$app_path"
rm -f -- "$zip_path" "$checksum_path"
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
