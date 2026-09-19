# ci/

## godot-checksums.txt

CI と開発者が取得する Godot バイナリと Export Templates の SHA-512。
[公式リリースの `SHA512-SUMS.txt`](https://github.com/godotengine/godot/releases) から該当行を転記したもの。

HTTPS は通信経路しか守らないため、取得した ZIP がリリース時点のものと同一であることを
この値で検証してから展開する。

Godot のバージョンを上げるときは `.godot-version` と同時にこのファイルも更新する。

```sh
version="$(tr -d '[:space:]' < .godot-version)"
curl -fsSL "https://github.com/godotengine/godot/releases/download/${version}/SHA512-SUMS.txt" \
  | grep -E "Godot_v${version}_(linux\.x86_64\.zip|macos\.universal\.zip|export_templates\.tpz)$" \
  > ci/godot-checksums.txt
```

| ファイル | 使う場所 |
|---|---|
| `..._linux.x86_64.zip` | CI の Static Check 以外の ubuntu job |
| `..._macos.universal.zip` | CI の macOS Export Validation、ローカルの macOS 開発 |
| `..._export_templates.tpz` | `scripts/install-export-templates.sh`（Export Validation） |

## requirements-static-check.txt

`scripts/static-check.sh` が使う GDScript の Linter / Formatter（gdtoolkit）をバージョン固定する。
CI とローカルで同じ結果になるよう、更新するときは実際に `scripts/static-check.sh` を通してから上げる。
