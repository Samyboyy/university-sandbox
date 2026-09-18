extends "res://Scenes/SceneBase.gd"

# The orientation talk in the lecture hall. It can only be attended once the player has
# checked in, and attending again afterwards is an empty hall.

const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")

var firstDay = FirstDay.new()

func _init():
	sceneID = "UniversityOrientationScene"

func getUniversityState():
	if(GM.main == null || GM.main.get("university") == null):
		return null
	return GM.main.university

func _run():
	playAnimation(StageScene.Solo, "stand")
	var stage:String = firstDay.getStage(getUniversityState())

	if(stage == FirstDay.STAGE_ATTEND_ORIENTATION):
		saynn("You find a seat near the back. The hall fills up around you with people pretending to read the handbook.")
		saynn("The talk is what you expected: term dates, the library, where not to park, an alarming slide about deadlines, and a long list of clubs that all meet on the same night.")
		saynn("By the end you have a timetable you half understand, a free tote bag and the names of two people sitting near you, neither of which you'll remember by morning.")
		addButton("Head out", "Orientation is over", "attend")
		return

	if(firstDay.hasReachedStage(getUniversityState(), FirstDay.STAGE_RETURN_DORM)):
		saynn("The hall is empty now, chairs folded up and the projector off. Somebody has left a tote bag behind on the front row.")
		addButton("Leave", "Nothing else here today", "leave")
		return

	saynn("The hall is filling up slowly, but the coordinator at Student Services still has to check you in before the talk counts for anything.")
	saynn("A student steward by the door confirms it: check in first, then come back.")
	addButton("Leave", "Head back to Student Services", "leave")

func _react(_action: String, _args):
	if(_action == "attend"):
		var _advanced = firstDay.advanceFrom(getUniversityState(), FirstDay.STAGE_ATTEND_ORIENTATION)
		processTime(3600)
		endScene()
		return
	if(_action == "leave"):
		processTime(60)
		endScene()
		return
	setState(_action)
