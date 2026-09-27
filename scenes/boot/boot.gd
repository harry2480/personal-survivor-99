extends Node

## 起動時の入口。ユーザー設定を読み込んで反映してから Main Menu へ遷移する。
##
## 設定の読み込みで落ちないこと（壊れていても既定値で起動すること）は
## [SettingsStore] が受け持つ（要件定義 §98 / #52）。


func _ready() -> void:
	SettingsApplier.apply_all(SceneRouter.get_user_settings())
	SceneRouter.change_state(GameState.State.MAIN_MENU)
