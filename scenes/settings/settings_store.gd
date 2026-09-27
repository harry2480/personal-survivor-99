class_name SettingsStore
extends RefCounted

## 保存と読み込み（要件定義 §98 Persistence）。
##
## **保存方式は JSON 1 本に統一する**（#52 の完了条件）。Settings も Statistics も
## Input Bindings も、すべてこの入り口を通って `user://` 配下の JSON になる。
##
## [codeblock]
## user://settings.json   … Settings / Input Bindings / CPU Settings（要件定義 §97）
## user://stats.json      … Statistics（要件定義 §99。中身は #54）
## [/codeblock]
##
## **壊れていても落ちない。**ファイルが無い・読めない・JSON として壊れている・
## 中身が Dictionary でない、のどれでも既定値で起動する（#52 の完了条件）。

## Settings の保存先。
const SETTINGS_DOCUMENT: String = "settings"

## Statistics の保存先（中身は #54）。
const STATISTICS_DOCUMENT: String = "stats"

## 保存先のディレクトリ。
const BASE_DIR: String = "user://"

var _dir: String


func _init(base_dir: String = BASE_DIR) -> void:
	_dir = base_dir if base_dir.ends_with("/") else base_dir + "/"


## 保存先のパスを返す。
func get_path(document: String) -> String:
	return "%s%s.json" % [_dir, document]


## その保存先があるかを返す。
func has_document(document: String) -> bool:
	return FileAccess.file_exists(get_path(document))


## JSON を読む。読めなければ空の Dictionary を返す（落ちない）。
func load_document(document: String) -> Dictionary:
	var path: String = get_path(document)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("設定ファイルを開けませんでした: %s" % path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	# JSON.parse_string は壊れた入力でエンジンのエラーログを出すため、
	# 戻り値で判定できる JSON.parse を使う（壊れたファイルは想定内なので）。
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		# 壊れている場合は既定値で起動する（要件定義 §98 / #52 の完了条件）。
		push_warning("設定ファイルが壊れています。既定値で起動します: %s" % path)
		return {}
	return json.data


## JSON として書く。書けたら [code]true[/code]。
func save_document(document: String, data: Dictionary) -> bool:
	var path: String = get_path(document)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("設定ファイルを保存できませんでした: %s" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## 保存先を消す。テストと「設定を初期化」で使う。
func delete_document(document: String) -> void:
	var path: String = get_path(document)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Settings を読む。無ければ既定値を返す。
func load_settings() -> UserSettings:
	var settings: UserSettings = UserSettings.create_default()
	settings.apply_dictionary(load_document(SETTINGS_DOCUMENT))
	return settings


## Settings を書く。
func save_settings(settings: UserSettings) -> bool:
	if settings == null:
		return false
	return save_document(SETTINGS_DOCUMENT, settings.to_dictionary())
