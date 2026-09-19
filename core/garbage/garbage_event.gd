class_name GarbageEvent
extends RefCounted

## Garbage 1 件ぶんの情報（要件定義 §40）。
##
## 誰から誰へ、何行、いつ作られ、いつ有効になるかを持つ。Routing（Phase 4）は
## この Event を配るだけで済むようにしている。
##
## 時刻は実時刻ではなく、ゲーム内の経過秒。外から与えられるので決定論的に扱える。

## 送り主の Player ID。
var source_player_id: int = -1

## 送り先の Player ID。
var target_player_id: int = -1

## Garbage の行数。
var line_count: int = 0

## 生成されたゲーム内時刻（秒）。
var created_time: float = 0.0

## 盤面へ適用できるようになるゲーム内時刻（秒）。
var activation_time: float = 0.0

## 元になった Attack の種類（任意。要件定義 §40 の「必要に応じて」）。
var attack_type: LineClear.Type = LineClear.Type.NONE

## 元になった Attack の識別子（任意）。同時刻の順序づけにも使う。
var attack_id: int = 0


static func create(
	source_id: int,
	target_id: int,
	lines: int,
	created: float,
	delay_sec: float,
	source_attack_type: LineClear.Type = LineClear.Type.NONE,
	source_attack_id: int = 0
) -> GarbageEvent:
	var event := GarbageEvent.new()
	event.source_player_id = source_id
	event.target_player_id = target_id
	event.line_count = maxi(0, lines)
	event.created_time = created
	event.activation_time = created + maxf(0.0, delay_sec)
	event.attack_type = source_attack_type
	event.attack_id = source_attack_id
	return event


## 指定時刻に適用できるかを返す。
func is_active_at(current_time: float) -> bool:
	return current_time + GameRules.ACCUMULATION_EPSILON >= activation_time


## まだ行が残っているかを返す。
func has_lines() -> bool:
	return line_count > 0


## 相殺で行を減らす。減らした行数を返す。
func absorb(amount: int) -> int:
	var absorbed: int = mini(maxi(0, amount), line_count)
	line_count -= absorbed
	return absorbed
