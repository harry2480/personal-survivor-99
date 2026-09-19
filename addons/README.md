# addons/

## gut/

自動テストフレームワーク [GUT](https://github.com/bitwes/Gut) を、リポジトリに直接配置（vendoring）している。

| 項目 | 値 |
|---|---|
| バージョン | `9.7.1`（唯一の参照元は [`gut/plugin.cfg`](gut/plugin.cfg) の `version`） |
| 対応 Godot | `4.7.0` 〜 `4.7.999`（[`gut/versions.json`](gut/versions.json)） |
| 取得元 | `https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz` |
| SHA-512 | `c4c609944b0853942bfe4ed47162503651ae1246e3eec740e4432e0786bd48781783ce2c05bcd7a4fb52d29d60866af8175226b88c9725eb938d06f426d2c5a5` |

`.godot-version`（`4.7.2-stable`）は GUT 9.7.1 の対応範囲に収まっている。
Godot のバージョンを上げるときは、GUT 側の対応範囲も同時に確認する。

submodule やパッケージマネージャを使わないのは、CI で追加の取得ステップを挟まずに
`godot --headless` でテストを実行できるようにするため。

`gut/` 配下は上流のコードなので、**独自の修正を加えない**。挙動を変えたい場合は
`.gutconfig.json` かテスト側で対応する。

### 更新手順

```sh
version=9.7.2   # 上げたいバージョン
curl -fsSL -o /tmp/gut.tar.gz "https://github.com/bitwes/Gut/archive/refs/tags/v${version}.tar.gz"
shasum -a 512 /tmp/gut.tar.gz          # この値を上の表へ転記する
tar xzf /tmp/gut.tar.gz -C /tmp
git rm -r --quiet addons/gut
cp -R "/tmp/Gut-${version}/addons/gut" addons/gut
scripts/run-tests.sh                    # 既存テストが通ることを確認する
```
