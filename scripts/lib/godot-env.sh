#!/usr/bin/env bash
# Godot 実行ファイルの解決と、.godot-version との一致確認を提供する共有関数。
# 直接実行せず、他のスクリプトから source して使う。
#
# 環境変数:
#   GODOT_BIN                   Godot 実行ファイルのパス（未指定なら自動探索）
#   SKIP_GODOT_VERSION_CHECK=1  .godot-version との一致確認を省略する

# Godot 実行ファイルのパスを標準出力へ返す。
resolve_godot_bin() {
  if [ -n "${GODOT_BIN:-}" ]; then
    printf '%s\n' "$GODOT_BIN"
    return 0
  fi

  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi

  if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    printf '%s\n' /Applications/Godot.app/Contents/MacOS/Godot
    return 0
  fi

  echo "Godot が見つかりません。GODOT_BIN で実行ファイルを指定してください。" >&2
  return 1
}

# 実行ファイルのバージョンが .godot-version と一致するか確認し、バージョン文字列を返す。
# 第 1 引数: Godot 実行ファイルのパス
# 第 2 引数: リポジトリルート（.godot-version の場所）
assert_godot_version() {
  local godot_bin="$1"
  local repo_root="$2"

  local pinned actual expected
  pinned="$(tr -d '[:space:]' < "$repo_root/.godot-version")"
  if [ -z "$pinned" ]; then
    echo ".godot-version が空です。固定する Godot のバージョンを記述してください。" >&2
    return 1
  fi
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
        return 1
        ;;
    esac
  fi

  printf '%s\n' "$actual"
}
