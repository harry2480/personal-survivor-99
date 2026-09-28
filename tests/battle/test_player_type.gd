extends GutTest

## Player 種別の判定（要件定義 §44）の Unit テスト。


func test_mvp_supports_local_human_and_cpu_only() -> void:
	assert_true(PlayerType.is_supported(PlayerType.Type.LOCAL_HUMAN), "Local Human は MVP で使う")
	assert_true(PlayerType.is_supported(PlayerType.Type.CPU), "CPU は MVP で使う")
	assert_false(PlayerType.is_supported(PlayerType.Type.REMOTE_HUMAN), "Remote Human は MVP 外")


func test_human_types_are_detected() -> void:
	assert_true(PlayerType.is_human(PlayerType.Type.LOCAL_HUMAN), "Local Human は人間")
	assert_true(PlayerType.is_human(PlayerType.Type.REMOTE_HUMAN), "Remote Human も人間")
	assert_false(PlayerType.is_human(PlayerType.Type.CPU), "CPU は人間ではない")


func test_type_name_matches_the_enum() -> void:
	for type in PlayerType.Type.values():
		assert_eq(PlayerType.get_type_name(type), PlayerType.Type.keys()[type], "名前は enum のキー")
