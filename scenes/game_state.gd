class_name GameState
extends RefCounted

## アプリ全体の状態。要件定義 §109 Game State に対応する。
## 状態の保持と遷移は SceneRouter が一元管理する。
enum State {
	BOOT,
	MAIN_MENU,
	LOADING,
	PLAYING,
	PAUSED,
	FINISHED,
	RESULT,
}
