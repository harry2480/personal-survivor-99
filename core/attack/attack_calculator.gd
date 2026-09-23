class_name AttackCalculator
extends RefCounted

## Attack 値の算出（要件定義 §38）。
##
## 構成は要件定義のとおり。
## [codeblock]
## Base Attack + Clear Type + Combo + Back-to-Back + Perfect Clear
##   → Attack Multiplier / Multiple Attackers Adjustment
## [/codeblock]
##
## 前半（素の Attack）をこのクラスが担い、後半の倍率・人数補正は
## [method apply_multipliers] として口だけ用意してある。獲得ロジックと実際の
## 倍率値は Battle Layer（Phase 4 / #37）の責務。
##
## **数値は 1 つもコードに持たない。** すべて [GameBalance] のデータから引く
## （要件定義 §38）。Battle Layer も Board も知らない純粋な計算。

var _balance: GameBalance


func _init(balance: GameBalance = null) -> void:
	_balance = balance if balance != null else GameBalance.create_default()


## 素の Attack を算出する。
##
## Perfect Clear が成立している場合、[member GameBalance.perfect_clear_replaces_attack]
## が true なら Perfect Clear の値で置き換え、false なら加算する。
func calculate(context: AttackContext) -> int:
	if context == null or not context.has_clear():
		return 0

	var attack: int = _balance.get_base_attack(context.clear_type, context.t_spin)

	if context.b2b_active:
		attack += _balance.b2b_bonus

	attack += _balance.get_combo_attack(context.combo_count)

	if context.perfect_clear:
		var perfect: int = _balance.get_perfect_clear_attack(context.clear_type)
		attack = perfect if _balance.perfect_clear_replaces_attack else attack + perfect

	return maxi(0, attack)


## Attack Multiplier と Multiple Attackers Adjustment を適用する（要件定義 §38）。
##
## 倍率の獲得条件と人数補正の値は Battle Layer（Phase 4）が決め、ここには
## 決まった値だけが渡ってくる。Phase 2 の時点では倍率 1.0 / 補正 0 で呼ばれる。
static func apply_multipliers(
	attack: int, multiplier: float = 1.0, attackers_bonus: int = 0
) -> int:
	if attack <= 0:
		return 0
	return maxi(0, int(floor(float(attack) * maxf(0.0, multiplier))) + attackers_bonus)


## 算出の内訳を返す。デバッグとバランス調整で使う。
func explain(context: AttackContext) -> Dictionary:
	if context == null or not context.has_clear():
		return {"base": 0, "b2b": 0, "combo": 0, "perfect_clear": 0, "total": 0}

	var base: int = _balance.get_base_attack(context.clear_type, context.t_spin)
	var b2b: int = _balance.b2b_bonus if context.b2b_active else 0
	var combo: int = _balance.get_combo_attack(context.combo_count)
	var perfect: int = (
		_balance.get_perfect_clear_attack(context.clear_type) if context.perfect_clear else 0
	)

	return {
		"base": base,
		"b2b": b2b,
		"combo": combo,
		"perfect_clear": perfect,
		"total": calculate(context),
	}
