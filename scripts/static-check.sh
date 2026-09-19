#!/usr/bin/env bash
# GDScript の Static Check。
#
#   1. gdlint    — 構文・未使用・命名規約（gdtoolkit）
#   2. gdformat  — フォーマット崩れの検出（書き換えはしない）
#   3. 命名規約   — ファイル・ディレクトリが snake_case であること（要件定義 §119）
#   4. 依存方向   — Presentation → Battle → Game Core を逆転させていないこと（§16〜§19）
#   5. shellcheck — scripts/ 配下のシェルスクリプト（未導入なら省略）
#   6. actionlint — GitHub Actions のワークフロー（未導入なら省略）
#   7. 変数展開    — 全角文字の直前で波括弧を省略していないか（bash 3.2 対策）
#   8. 設定ファイル — project.godot 等のコメントが ";" になっているか
#
# 1〜2 は gdtoolkit が必要。未導入なら次で入れる。
#
#   python3 -m venv .venv && . .venv/bin/activate
#   pip install -r ci/requirements-static-check.txt
#
# 環境変数:
#   SKIP_GDTOOLKIT=1  gdlint / gdformat を省略する（3〜4 だけ実行する）
#
# 対象ファイル名は 3. で snake_case を強制しているため空白を含まない。
# その前提で、ファイルリストを単語分割して各ツールへ渡している。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failed=0

fail() {
  echo "$1" >&2
  failed=1
}

# 検査対象。addons/ は vendoring した上流コードなので除外する。
# commit 前のファイルも検査したいので、追跡済み + 未追跡（gitignore 対象外）を見る。
ls_files() {
  git ls-files --cached --others --exclude-standard "$@" | sort -u
}

gd_files="$(ls_files '*.gd' | grep -v '^addons/' || true)"
gd_file_count="$(printf '%s' "$gd_files" | grep -c . || true)"

echo "==> 検査対象: ${gd_file_count} ファイル"

# ---- 1. gdlint / 2. gdformat ----------------------------------------------
if [ "${SKIP_GDTOOLKIT:-0}" = "1" ]; then
  echo "==> gdlint / gdformat: SKIP_GDTOOLKIT=1 のため省略"
elif [ "$gd_file_count" -eq 0 ]; then
  echo "==> gdlint / gdformat: 対象なし"
elif ! command -v gdlint >/dev/null 2>&1 || ! command -v gdformat >/dev/null 2>&1; then
  fail "gdtoolkit が見つかりません。pip install -r ci/requirements-static-check.txt を実行してください。"
else
  # gdlint は実行時のカレントディレクトリから上へ設定ファイルを探す。
  # tests/ には tests/gdlintrc（テスト向けに緩めた設定）があるため、
  # 製品コードとテストコードを分けて実行する。
  local_files="$(printf '%s\n' "$gd_files" | grep -v '^tests/' || true)"
  test_files="$(printf '%s\n' "$gd_files" | grep '^tests/' | sed 's|^tests/||' || true)"

  echo "==> gdlint（製品コード）"
  if [ -n "$local_files" ]; then
    # shellcheck disable=SC2086
    gdlint $local_files || fail "gdlint で問題が見つかりました（製品コード）"
  else
    echo "対象なし"
  fi

  echo "==> gdlint（テスト）"
  if [ -n "$test_files" ]; then
    # shellcheck disable=SC2086
    ( cd tests && gdlint $test_files ) || fail "gdlint で問題が見つかりました（テスト）"
  else
    echo "対象なし"
  fi

  echo "==> gdformat --check"
  # shellcheck disable=SC2086
  gdformat --check $gd_files || fail "gdformat の整形結果と差分があります。gdformat <file> で整形してください。"
fi

# ---- 3. 命名規約 -----------------------------------------------------------
echo "==> 命名規約（snake_case）"
bad_names="$(
  ls_files '*.gd' '*.tscn' '*.tres' \
    | grep -v '^addons/' \
    | grep -vE '^([a-z0-9_]+/)*[a-z0-9_]+\.(gd|tscn|tres)$' || true
)"
if [ -n "$bad_names" ]; then
  printf '%s\n' "$bad_names" >&2
  fail "ファイル・ディレクトリ名は snake_case にしてください（要件定義 §119）"
fi

# ---- 4. 依存方向 -----------------------------------------------------------
# GDScript には依存方向を機械検証する標準ツールがないため、res:// 参照を走査する。
echo "==> 依存方向（Presentation → Battle → Game Core）"
check_layer() {
  local layer_dir="$1"
  local forbidden="$2" # "|" 区切り

  [ -d "$layer_dir" ] || return 0

  local files
  files="$(ls_files "$layer_dir" | grep '\.gd$' || true)"
  [ -n "$files" ] || return 0

  local hits
  # shellcheck disable=SC2086
  hits="$(grep -HnE "res://(${forbidden})/" $files || true)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" >&2
    fail "$layer_dir が参照してはいけないレイヤー（${forbidden}）を参照しています"
  fi
}

check_layer core "ui|scenes|audio|input|battle|cpu"
check_layer battle "ui|scenes|audio"
check_layer cpu "ui|scenes|audio"

# ---- 5. shellcheck ---------------------------------------------------------
# 品質ゲート自体がシェルスクリプトなので、ここも検査対象にする。
if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  shellcheck -x --source-path=SCRIPTDIR scripts/*.sh scripts/lib/*.sh || fail "shellcheck で問題が見つかりました"
else
  echo "==> shellcheck: 未導入のため省略"
fi

# ---- 6. actionlint ---------------------------------------------------------
# ubuntu runner には同梱されていないため、導入済みの環境だけで実行する。
if command -v actionlint >/dev/null 2>&1; then
  echo "==> actionlint"
  actionlint .github/workflows/*.yml || fail "actionlint で問題が見つかりました"
else
  echo "==> actionlint: 未導入のため省略"
fi

# ---- 7. 変数展開 -----------------------------------------------------------
# macOS の /bin/bash は 3.2 で、波括弧なしの変数展開の直後に全角文字が続くと、
# マルチバイトの先頭バイトまで変数名として読み、unbound variable になる。
# 本リポジトリはメッセージが日本語なので踏みやすい。${var} と書けば防げる。
echo "==> 変数展開（全角文字の直前は \${var} を使う）"
bare_expansions="$(
  LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' scripts/*.sh scripts/lib/*.sh || true
)"
if [ -n "$bare_expansions" ]; then
  printf '%s\n' "$bare_expansions" >&2
  fail "全角文字の直前の変数展開は \${var} の形にしてください（bash 3.2 で unbound variable になります）"
fi

# ---- 8. 設定ファイルのコメント --------------------------------------------
# Godot の設定ファイルのコメントは ";" 始まり。"#" で書くとその行以降の
# セクションが黙って読み捨てられ、設定が効かないまま気づけない。
echo '==> 設定ファイルのコメント（";" を使う）'
hash_comments="$(
  ls_files 'project.godot' 'export_presets.cfg' '*.tres' \
    | grep -v '^addons/' \
    | while IFS= read -r f; do grep -Hn '^[[:space:]]*#' "$f" || true; done
)"
if [ -n "$hash_comments" ]; then
  printf '%s\n' "$hash_comments" >&2
  fail 'Godot の設定ファイルのコメントは ";" で書いてください（"#" は後続行ごと無視されます）'
fi

# ---------------------------------------------------------------------------
if [ "$failed" -ne 0 ]; then
  echo
  echo "Static Check に失敗しました" >&2
  exit 1
fi

echo
echo "Static Check に成功しました"
