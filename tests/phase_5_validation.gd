extends "res://tests/rework_c_validation.gd"

# 旧独立搜刮／准备／切出断言迁移为同一领域系统的真实手牌事务。
func label() -> String:
	return "Phase 5 migrated: finite resources and cut-out"

func tests() -> void:
	_test_resource_cards()
	_test_cutout_cards()
	_test_anti_soft_lock()
	_test_invalid_modes()
