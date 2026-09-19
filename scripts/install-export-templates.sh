#!/usr/bin/env bash
# .godot-version と同じバージョンの Export Templates を導入する。
#
# 導入済みなら何もしない。CI でキャッシュヒットした場合もここで早期終了する。
# ダウンロードした tpz は ci/godot-checksums.txt の SHA-512 で検証してから展開する。
#
# 環境変数:
#   GODOT_TEMPLATES_DIR  展開先（未指定なら OS ごとの既定パス）
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="$(tr -d '[:space:]' < .godot-version)"
if [ -z "$version" ]; then
  echo ".godot-version が空です" >&2
  exit 1
fi

# "4.7.2-stable" → "4.7.2.stable"（Godot が参照するディレクトリ名）
templates_version="${version/-/.}"

if [ -n "${GODOT_TEMPLATES_DIR:-}" ]; then
  templates_root="$GODOT_TEMPLATES_DIR"
elif [ "$(uname -s)" = "Darwin" ]; then
  templates_root="$HOME/Library/Application Support/Godot/export_templates"
else
  templates_root="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
fi

target="$templates_root/$templates_version"

if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
  echo "Export Templates は導入済みです: $target"
  exit 0
fi

archive="Godot_v${version}_export_templates.tpz"
url="https://github.com/godotengine/godot/releases/download/${version}/${archive}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Export Templates を取得します: $archive"
curl -fsSL -o "$work/$archive" "$url"

# HTTPS は経路しか守らないため、リポジトリに固定した公式 SHA-512 で中身を検証する。
cp ci/godot-checksums.txt "$work/checksums.txt"
if command -v sha512sum >/dev/null 2>&1; then
  ( cd "$work" && sha512sum --check --ignore-missing checksums.txt )
else
  ( cd "$work" && shasum -a 512 --check --ignore-missing checksums.txt )
fi

# tpz は zip。展開すると templates/ 配下にファイルが並ぶ。
unzip -q "$work/$archive" -d "$work/extracted"
mkdir -p "$target"
cp -R "$work/extracted/templates/." "$target/"

echo "Export Templates を導入しました: $target"
