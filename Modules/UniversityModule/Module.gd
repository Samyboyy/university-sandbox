extends Module

# University Sandbox core module.
#
# Owns the production new-game route (main menu -> name -> human creator -> private dorm),
# its placeholder starter outfit and the dorm floor. Legacy BDCC modules stay registered;
# this module only adds University-owned content. See Docs/UNIVERSITY_NEW_GAME.md.
#
# No class_name on purpose: modules are loaded by path, and a new global class would need
# the editor to regenerate project.godot before headless runs could resolve it.

const DORM_FLOOR_ID := "UniversityDormFloor"
const DORM_FLOOR_PATH := "res://Modules/UniversityModule/World/UniversityDormFloor.tscn"

func getFlags():
	return {}

func _init():
	id = "UniversityModule"
	author = "University Sandbox"

	scenes = [
		"res://Modules/UniversityModule/Scenes/UniversityNewGameScene.gd",
		"res://Modules/UniversityModule/Scenes/UniversityCharacterCreatorScene.gd",
		"res://Modules/UniversityModule/Scenes/UniversityChangeSkinScene.gd",
	]
	items = [
		"res://Modules/UniversityModule/Items/UniversityStarterClothes.gd",
	]

func preInit():
	GlobalRegistry.registerMapFloor(DORM_FLOOR_ID, DORM_FLOOR_PATH)
