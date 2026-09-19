class_name PlayerType
extends RefCounted

## Player の種別（要件定義 §46）。
##
## MVP で使うのは [constant Type.LOCAL_HUMAN] と [constant Type.CPU] のみ。
## [constant Type.REMOTE_HUMAN] は将来のオンライン対戦のために定義だけしておく。

enum Type { LOCAL_HUMAN, CPU, REMOTE_HUMAN }

## MVP で使用する種別。
const MVP_TYPES: Array[int] = [Type.LOCAL_HUMAN, Type.CPU]


## MVP で使用する種別かを返す。
static func is_supported(type: Type) -> bool:
	return type in MVP_TYPES


## 人間が操作する種別かを返す。
static func is_human(type: Type) -> bool:
	return type == Type.LOCAL_HUMAN or type == Type.REMOTE_HUMAN


## 種別の名前を返す。ログとテスト用。
static func get_type_name(type: Type) -> String:
	return Type.keys()[type]
