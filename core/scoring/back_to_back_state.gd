class_name BackToBackState
extends RefCounted

## Back-to-Back（高難度 Clear の連続。要件定義 §35）。
##
## 対象 Clear が続く限り鎖が伸び、対象外の Clear で途切れる。**Line Clear なしの
## Lock では途切れない**（Combo だけが終了する）。これが Combo との違い。
##
## 対象となる Clear 種別は [GameBalance] のデータで決める。コードに固定しない
## （要件定義 §35）。

var _balance: GameBalance
var _chain: int = 0
var _best_chain: int = 0


func _init(balance: GameBalance = null) -> void:
	_balance = balance if balance != null else GameBalance.create_default()


## 対象 Clear が何回続いているかを返す。
func get_chain() -> int:
	return _chain


## Back-to-Back の効果が乗る状態かを返す（2 回目以降）。
func is_active() -> bool:
	return _chain >= 2


## このゲームでの最長の鎖を返す。
func get_best_chain() -> int:
	return _best_chain


## Piece が Lock されたときに呼ぶ。
##
## [param line_count] が 0 のときは何もしない。Line Clear なしの Lock で B2B は
## 途切れないため（要件定義 §35）。
func on_piece_locked(clear_type: LineClear.Type, line_count: int, is_t_spin: bool = false) -> void:
	if line_count <= 0:
		return

	if _balance.is_b2b_clear(clear_type, is_t_spin):
		_chain += 1
		_best_chain = maxi(_best_chain, _chain)
	else:
		_chain = 0


## 状態を初期化する。
func reset() -> void:
	_chain = 0
	_best_chain = 0
