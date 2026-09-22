class_name NextQueue
extends RefCounted

## NEXT Queue（要件定義 §23）。
##
## [PieceRandomizer] から Piece を引いて内部に溜める。UI が表示するのは先頭 5 個以上
## だが、内部はそれより多く保持する。CPU の先読み（Phase 5）も同じ Queue を使う。
##
## Randomizer が Seed 制御されているため、同じ Seed からは同じ並びになる。

## UI が最低限表示する個数（要件定義 §23）。
const MINIMUM_VISIBLE: int = 5

## 内部で保持する個数。1 Bag ぶん先まで見えるようにしている。
const DEFAULT_CAPACITY: int = 7

var _randomizer: PieceRandomizer
var _capacity: int = DEFAULT_CAPACITY
var _queue: Array[int] = []


func _init(randomizer: PieceRandomizer = null, capacity: int = DEFAULT_CAPACITY) -> void:
	_randomizer = randomizer if randomizer != null else PieceRandomizer.new()
	_capacity = maxi(MINIMUM_VISIBLE, capacity)
	refill()


## 内部で保持する個数を返す。
func get_capacity() -> int:
	return _capacity


## 現在 Queue に入っている個数を返す。
func size() -> int:
	return _queue.size()


## 先頭の Piece を取り出し、Queue を補充する。
func pop() -> int:
	refill()
	var next_type: int = _queue.pop_front()
	refill()
	return next_type


## 先頭から [param count] 個を、取り出さずに返す。
##
## [param count] を省略すると UI が表示する最低個数を返す。
func peek(count: int = MINIMUM_VISIBLE) -> Array[int]:
	var wanted: int = maxi(0, count)
	while _queue.size() < wanted:
		_queue.append(_randomizer.next())
	return _queue.slice(0, wanted)


## Queue の中身をすべて返す。
func peek_all() -> Array[int]:
	return _queue.duplicate()


## Queue を規定の個数まで補充する。
func refill() -> void:
	while _queue.size() < _capacity:
		_queue.append(_randomizer.next())


## Randomizer を Seed から作り直し、Queue も作り直す。
func reset(new_seed: int) -> void:
	_randomizer.reset(new_seed)
	_queue.clear()
	refill()
