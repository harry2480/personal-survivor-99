# ci/

## godot-checksums.txt

CI と開発者が取得する Godot バイナリの SHA-512。
[公式リリースの `SHA512-SUMS.txt`](https://github.com/godotengine/godot/releases) から該当行を転記したもの。

HTTPS は通信経路しか守らないため、取得した ZIP がリリース時点のものと同一であることを
この値で検証してから展開する。

Godot のバージョンを上げるときは `.godot-version` と同時にこのファイルも更新する。

```sh
version="$(tr -d '[:space:]' < .godot-version)"
curl -fsSL "https://github.com/godotengine/godot/releases/download/${version}/SHA512-SUMS.txt" \
  | grep -E "Godot_v${version}_(linux\.x86_64|macos\.universal)\.zip$" > ci/godot-checksums.txt
```
