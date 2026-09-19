class_name BattlePlayerState
extends RefCounted

## Battle における Player 1 人ぶんの状態（要件定義 §45）。
##
## Game Core（[PuzzleSession]）を「持つ」が、その内部状態を直接書き換えない。
## 盤面への反映は Game Core 側の API を通す（要件定義 §18）。
##
## Presentation は知らない。表示は Battle Layer が出す値を読むだけにする。

## 一意の Player ID。
var player_id: int = -1

## Player の種別（[enum PlayerType.Type]）。
var player_type: PlayerType.Type = PlayerType.Type.CPU

## 生存しているか。Top Out すると false になる。
var alive: bool = true

## 確定した順位。未確定は 0。
var rank: int = 0

## この Player が奪った KO の数。
var ko_count: int = 0

## Attack Multiplier のための蓄積値（要件定義 §57）。
var attack_points: int = 0

## 現在の Attack 倍率。
var attack_multiplier: float = 1.0

## Target の選び方。値の定義は #35 の Target Manager が持つ。
var target_mode: int = 0

## 現在の攻撃先 Player ID。いなければ -1。
var current_target: int = -1

## 受信待ちの Garbage 行数。
var incoming_garbage: int = 0

## 盤面の危険度（[enum DangerLevel.Level]）。
var danger_level: DangerLevel.Level = DangerLevel.Level.SAFE

## Detailed Simulation 対象に紐付く Game Core の進行（要件定義 §45）。
##
## Lightweight Simulation の Player（Phase 5）では null のままにする。
var session: PuzzleSession = null


static func create(id: int, type: PlayerType.Type) -> BattlePlayerState:
	var state := BattlePlayerState.new()
	state.player_id = id
	state.player_type = type
	return state


## Detailed Simulation 用の Game Core を紐付ける。
func attach_session(new_session: PuzzleSession) -> void:
	session = new_session


## Board State を持っている（Detailed Simulation 対象）かを返す。
func has_board_state() -> bool:
	return session != null


## 紐付いた盤面を返す。無ければ null。
func get_board() -> Board:
	return session.get_board() if session != null else null


## 盤面から危険度を再計算して保持する（要件定義 §92）。
func refresh_danger_level() -> DangerLevel.Level:
	var board: Board = get_board()
	danger_level = DangerLevel.get_level(board) if board != null else DangerLevel.Level.SAFE
	return danger_level


## 受信待ちの Garbage 行数を盤面側の Queue から取り込む。
func refresh_incoming_garbage() -> int:
	incoming_garbage = session.get_garbage_queue().get_pending_lines() if session != null else 0
	return incoming_garbage


## 人間が操作する Player かを返す。
func is_human() -> bool:
	return PlayerType.is_human(player_type)


## 攻撃対象になりうるかを返す。
func is_targetable() -> bool:
	return alive
