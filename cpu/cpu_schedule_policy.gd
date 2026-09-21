class_name CpuSchedulePolicy
extends Resource

## CPU 更新の分散と、負荷が高いときの削り方（要件定義 §84 / §104）。
##
## **削る順番は要件定義 §84 のとおり**。優先度の低いものから削る。
##
## [codeblock]
## Human Input > Game Core > Battle State > Rendering > CPU Search Depth > Visual Effects
## [/codeblock]
##
## Visual Effects は Phase 9（#53 / #54）でまだ無いため、ここで削るのは
## **CPU Search Depth（Lookahead / Beam Width）と Detailed CPU の数**だけ。
## Human Input・Game Core・Battle State には手を触れない（#47 の制約）。
##
## 閾値はコードへ固定せず、この Resource のデータで持つ（要件定義 §38）。

## 削る段階。数が大きいほど強く削る。
enum Level { NONE, LOOKAHEAD, BEAM, DETAILED }

## CPU の更新を何フレームに分けるか（要件定義 §104）。
##
## 1 なら分散しない。4 なら「Frame N で 1/4、N+1 で次の 1/4」と回す。
@export_range(1, 16, 1) var slice_count: int = 4

## これを下回る FPS が続いたら削り始める。
##
## 60 FPS を守るための余裕を見て 55 に置く。下回った状態が
## [member sustained_frames] だけ続いてから動かす（瞬間的な跳ねで削らない）。
@export_range(10.0, 240.0, 1.0) var degrade_fps: float = 55.0

## これを上回る FPS が続いたら 1 段ずつ戻す。
##
## 削る閾値と離してあるのは、境界で行ったり来たりさせないため。
@export_range(10.0, 240.0, 1.0) var restore_fps: float = 58.0

## 閾値を跨いだ状態が何フレーム続いたら段階を動かすか。
@export_range(1, 600, 1) var sustained_frames: int = 30

## Frame Time の平均を取る窓（フレーム数）。
@export_range(1, 600, 1) var sample_frames: int = 30

## [constant Level.BEAM] で Beam Width を何倍にするか。
@export_range(0.05, 1.0, 0.05) var beam_scale: float = 0.25

## [constant Level.DETAILED] で Detailed CPU を何体まで減らすか。
@export_range(0, 32, 1) var degraded_detailed_limit: int = 0


## 既定の設定を作る。
static func create_default() -> CpuSchedulePolicy:
	return CpuSchedulePolicy.new()


## 段階の名前を返す。
static func get_level_name(level: Level) -> String:
	return Level.keys()[level]


## Frame Time（ミリ秒）から FPS を返す。
static func to_fps(frame_msec: float) -> float:
	if frame_msec <= 0.0:
		return 1000.0
	return 1000.0 / frame_msec
