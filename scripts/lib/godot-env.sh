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

# Godot の出力を走査し、診断行があれば失敗させる。
# Godot はスクリプトエラーが出ても終了コード 0 を返すため、終了コードだけでは
# 品質ゲートにならない。
#
# 第 1 引数: ラベル（ログに出す名前）
# 第 2 引数: 診断とみなす正規表現。GODOT_DIAGNOSTICS_* を使う
# 第 3 引数以降: 実行するコマンド
# source 元のスクリプトから使うため、このファイル内では参照されない。
# shellcheck disable=SC2034
GODOT_DIAGNOSTICS_STRICT='^(SCRIPT )?(ERROR|WARNING)'
# shellcheck disable=SC2034
GODOT_DIAGNOSTICS_ERROR='^(SCRIPT )?ERROR'

run_godot_step() {
  local label="$1"
  shift
  local pattern="$1"
  shift

  echo "==> ${label}"
  local output
  local status=0
  output="$("$@" 2>&1)" || status=$?
  printf '%s\n' "$output"

  if [ "$status" -ne 0 ]; then
    echo "${label} が異常終了しました (exit=${status})" >&2
    return 1
  fi

  local diagnostics
  diagnostics="$(printf '%s\n' "$output" | grep -E "$pattern" || true)"
  if [ -n "$diagnostics" ]; then
    echo "${label} で問題のある出力が検出されました:" >&2
    printf '%s\n' "$diagnostics" >&2
    return 1
  fi

  echo "--> ${label}: OK"
  echo
}

# ダウンロードしたファイルを、チェックサム一覧の該当行と照合する。
#
# sha512sum / shasum の --check --ignore-missing は、一覧の対象ファイルが
# 1 つも存在しなくても成功で終わる。ファイル名が変わった場合などに検証が
# 素通りしてしまうため、対象ファイルの行が存在することを先に確かめる。
#
# 第 1 引数: 検証するファイル
# 第 2 引数: "<sha512>  <ファイル名>" 形式の一覧
verify_sha512() {
  local file="$1"
  local checksums="$2"

  if [ ! -f "$file" ]; then
    echo "検証対象のファイルがありません: ${file}" >&2
    return 1
  fi
  if [ ! -f "$checksums" ]; then
    echo "チェックサム一覧がありません: ${checksums}" >&2
    return 1
  fi

  local name expected actual
  name="$(basename "$file")"
  # "<hash>  <name>" と "<hash>  *<name>"（binary mode）の両方を受ける。
  expected="$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1; exit }' "$checksums")"

  if [ -z "$expected" ]; then
    echo "${checksums} に ${name} の SHA-512 がありません。" >&2
    echo "バージョンを上げた場合は、チェックサム一覧も更新してください。" >&2
    return 1
  fi

  if command -v sha512sum >/dev/null 2>&1; then
    actual="$(sha512sum "$file" | cut -d' ' -f1)"
  else
    # macOS には sha512sum がない
    actual="$(shasum -a 512 "$file" | cut -d' ' -f1)"
  fi

  if [ "$actual" != "$expected" ]; then
    echo "SHA-512 が一致しません: ${name}" >&2
    echo "  期待値: ${expected}" >&2
    echo "  実測値: ${actual}" >&2
    return 1
  fi

  echo "SHA-512 検証 OK: ${name}"
}
