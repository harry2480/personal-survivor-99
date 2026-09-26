extends GutTest

## Target Mode の判定（要件定義 §47〜§52）の Unit テスト。


func test_auto_modes_exclude_manual() -> void:
	for mode in [
		TargetMode.Mode.RANDOM, TargetMode.Mode.KO, TargetMode.Mode.BADGE, TargetMode.Mode.COUNTER
	]:
		assert_true(TargetMode.is_auto(mode), "%s は Auto Target" % TargetMode.get_mode_name(mode))
	assert_false(TargetMode.is_auto(TargetMode.Mode.MANUAL), "Manual は Auto Target ではない")
