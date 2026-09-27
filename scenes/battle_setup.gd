class_name BattleSetup
extends Resource

## Battle を始めるときの設定（要件定義 §95 Game Start Flow）。
##
## Main Menu で決めた内容を Battle 画面へ渡すための入れ物。Presentation の中
## だけで使い、Game Core / Battle Layer はこの型を知らない。
##
## Seed を持たせてあるので、同じ設定で始め直せる（Restart）。

## Player の総数（Human 1 人を含む。要件定義 §44）。
@export_range(2, 99, 1) var player_count: int = 99

## CPU の難易度（要件定義 §77 / §79）。
@export var cpu_settings: CpuSettings = CpuSettings.create_default()

## Battle の Seed。0 なら開始時に決める（要件定義 §110）。
@export var battle_seed: int = 0


## 既定の設定（99 人 / Normal）を作る。
static func create_default() -> BattleSetup:
	return BattleSetup.new()


## CPU の人数を返す。
func get_cpu_count() -> int:
	return maxi(0, player_count - 1)


## この設定から CPU の分布を作る。
func build_distribution() -> CpuDistribution:
	return cpu_settings.build_distribution()


## Seed を決める。0 のままなら乱数で決めて残す。
##
## 一度決めた Seed は残るので、Restart すると同じ並びで始められる。
func resolve_seed() -> int:
	if battle_seed == 0:
		battle_seed = randi()
	return battle_seed


## Seed を捨てる。次に始めるときに引き直す。
func clear_seed() -> void:
	battle_seed = 0
