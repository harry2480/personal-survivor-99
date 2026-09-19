class_name LineClearResult
extends RefCounted

## Line Clear の結果（要件定義 §32）。
##
## Attack 計算（Phase 2 / #30）や Combo（#28）は、この結果を入力にする。

## 消えた行の y。上から順（昇順）。
var cleared_rows: Array[int] = []

## 消えた行数。
var line_count: int = 0

## 消えた行数に対応する種別。
var type: LineClear.Type = LineClear.Type.NONE


static func create(rows: Array[int]) -> LineClearResult:
	var result := LineClearResult.new()
	result.cleared_rows = rows.duplicate()
	result.line_count = rows.size()
	result.type = LineClear.get_type(result.line_count)
	return result


## 1 行以上消えたかを返す。
func has_cleared() -> bool:
	return line_count > 0
