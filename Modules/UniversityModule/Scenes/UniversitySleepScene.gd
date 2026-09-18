extends "res://Scenes/SceneBase.gd"

# Sleeping in the private dorm room. Finishing the first day here completes the objective
# and advances the day through the existing day/time system (MainScene.startNewDay()).

const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")
const DailyLife = preload("res://Game/University/UniversityDailyLife.gd")

var firstDay = FirstDay.new()

func _init():
	sceneID = "UniversitySleepScene"

func getUniversityState():
	if(GM.main == null || GM.main.get("university") == null):
		return null
	return GM.main.university

func _run():
	playAnimation(StageScene.Sleeping, "sleep")
	var stage:String = firstDay.getStage(getUniversityState())

	if(stage == FirstDay.STAGE_SLEEP):
		saynn("You push the last box off the bed with your foot, and the day finally catches up with you.")
		saynn("Moved in, checked in, oriented. Tomorrow is somebody else's problem.")
		addButton("Sleep", "End your first day", "sleep")
		return

	if(stage != "" && stage != FirstDay.STAGE_COMPLETE):
		saynn("You could lie down, but you'd only stare at the ceiling. There's still something you're supposed to be doing today.")
		saynn("[i]Objective: " + firstDay.getObjectiveText(getUniversityState()) + "[/i]")
		addButton("Get up", "Better get on with it", "leave")
		return

	saynn("You climb into bed and pull the covers up.")
	addButton("Sleep", "Sleep until morning", "sleep")

func _react(_action: String, _args):
	if(_action == "sleep"):
		var _advanced = firstDay.advanceFrom(getUniversityState(), FirstDay.STAGE_SLEEP)
		# University games recover needs and close off missed classes through the daily-life
		# service; legacy games just get the inherited day advance.
		var dailyLife = DailyLife.new()
		if(dailyLife.isActive()):
			var _result = dailyLife.sleepUntilMorning()
		else:
			GM.main.startNewDay()
		endScene()
		return
	if(_action == "leave"):
		endScene()
		return
	setState(_action)
