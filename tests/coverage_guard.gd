extends RefCounted

## カバレッジ計測で重いテストを飛ばすための判定。
##
## CPU や Battle を実際に走らせるテストは同じ行を何万回も通るので、行ごとに記録する
## カバレッジ計測では数倍遅くなる。確かめたいのは「強さの差が出るか」「決着するか」で、
## どの行を通るかは軽いテストで足りている。
##
## scripts/coverage.sh が [constant COVERAGE_ENV] を立てたときだけ飛ばす。
## 合否ゲートの scripts/run-tests.sh では立たないので、毎回走る。
##
## ファイル名が test_ で始まらないので、GUT はテストとして読み込まない。

## scripts/coverage.sh が立てる環境変数。
const COVERAGE_ENV: String = "PROJECT99_COVERAGE"


## カバレッジ計測中なら [param test] を保留にして [code]true[/code] を返す。
##
## 呼び出し側は [code]true[/code] ならそのまま return する。
static func skip_heavy_test(test: GutTest) -> bool:
	if OS.get_environment(COVERAGE_ENV) != "1":
		return false
	test.pending("カバレッジ計測中は重いテストを飛ばす（scripts/run-tests.sh では走る）")
	return true
