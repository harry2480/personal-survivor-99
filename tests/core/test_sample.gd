# GUT が headless で動作することを確認するサンプルテスト。
#
# Phase 1 で Game Core の実装が入ったら、このファイルは実際の Core Test に
# 置き換えてよい（テスト実行の仕組み自体の確認が目的のため）。
extends GutTest


func test_gut_runs_in_headless() -> void:
	assert_true(true, "GUT が headless で実行できている")


func test_seeded_rng_is_reproducible() -> void:
	# 要件定義 §110: 乱数は Seed 指定で再現できるようにする。
	# Game Core のテストが依存する前提なので、ここで担保を確認しておく。
	var first := RandomNumberGenerator.new()
	first.seed = 20260919
	var second := RandomNumberGenerator.new()
	second.seed = 20260919

	for _i in range(8):
		assert_eq(first.randi(), second.randi(), "同じ Seed なら同じ乱数列になる")
