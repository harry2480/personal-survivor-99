extends Node

## 起動時の入口。初期化が済み次第 Main Menu へ遷移する。
## 本格的な Initial Loading（要件定義 §106）は Phase 9 で扱う。


func _ready() -> void:
	SceneRouter.change_state(GameState.State.MAIN_MENU)
