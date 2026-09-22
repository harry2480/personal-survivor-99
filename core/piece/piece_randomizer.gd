class_name PieceRandomizer
extends RefCounted

## 7-Bag 方式の Piece Randomizer（要件定義 §22）。
##
## 1 つの Bag に 7 種を 1 個ずつ入れて Shuffle し、順に払い出す。Bag が空になったら
## 新しい Bag を作る。これにより「同じ Piece が長く来ない」ことが保証される。
##
## Seed を指定でき、同じ Seed からは必ず同じ列が再現される（要件定義 §110）。
## Bug 再現・自動テスト・CPU 比較・将来の Replay がこの性質に依存する。
##
## グローバル乱数（[method @GlobalScope.randi] や [method Array.shuffle]）は使わない。
## 自身の [RandomNumberGenerator] だけで完結させ、他所の乱数消費に影響されないようにする。

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
var _bag: Array[int] = []


func _init(initial_seed: int = 0) -> void:
	reset(initial_seed)


## Seed を指定して初期状態へ戻す。Bag の残りも捨てる。
func reset(new_seed: int) -> void:
	_seed = new_seed
	_rng.seed = new_seed
	_bag.clear()


## 現在の Seed を返す。
func get_seed() -> int:
	return _seed


## 次の Piece を 1 つ払い出す。返り値は [enum Piece.Type]。
func next() -> int:
	if _bag.is_empty():
		_refill_bag()
	return _bag.pop_front()


## 現在の Bag に残っている個数を返す。
func get_remaining_in_bag() -> int:
	return _bag.size()


## 次に払い出される Piece を、払い出さずに [param count] 個ぶん先読みする。
##
## Bag をまたぐ場合も正しい順序を返す。先読みのために乱数を消費するため、
## 先読みした内容はそのまま [method next] で返る。
func peek(count: int) -> Array[int]:
	while _bag.size() < count:
		_refill_bag()
	return _bag.slice(0, count)


func _refill_bag() -> void:
	var bag: Array[int] = Piece.get_all_types()

	# Fisher-Yates。Array.shuffle() はグローバル乱数を使うため使わない（要件定義 §110）。
	for i in range(bag.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swapped: int = bag[i]
		bag[i] = bag[j]
		bag[j] = swapped

	_bag.append_array(bag)
