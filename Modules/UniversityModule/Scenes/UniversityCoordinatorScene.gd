extends "res://Scenes/SceneBase.gd"

# Talking to the orientation coordinator at Student Services. What she says depends on the
# player's current first-day stage, and checking in twice is harmless: the check-in only
# advances the sequence when the player is actually at that stage.

const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")
const NPC_ID := "universityCoordinator"

var firstDay = FirstDay.new()

func _init():
	sceneID = "UniversityCoordinatorScene"

func getUniversityState():
	if(GM.main == null || GM.main.get("university") == null):
		return null
	return GM.main.university

func _run():
	var coordinator = GM.main.getCharacter(NPC_ID)
	var coordinatorName:String = coordinator.getName() if coordinator != null else "the coordinator"
	if(coordinator != null):
		setCharactersEasyList([NPC_ID])
	playAnimation(StageScene.Duo, "stand", {npc = NPC_ID})

	var stage:String = firstDay.getStage(getUniversityState())

	if(stage == FirstDay.STAGE_CHECK_IN):
		saynn("A woman behind the desk looks up from a laptop and a landslide of paperwork. Her name badge reads " + coordinatorName + ", First-Year Orientation.")
		saynn("\"You look like someone who moved in about an hour ago,\" she says. \"Name, and I'll find you on the list.\"")
		saynn("You give her your name. She scratches a line through it, hands you a lanyard and a folded campus map, and taps the map twice with her pen.")
		saynn("\"Checked in. Orientation is in the lecture hall, straight across the quad and west. Sit anywhere, it's not that formal.\"")
		addButton("Thanks", "Take the lanyard and go", "checkin")
		return

	if(stage == FirstDay.STAGE_ATTEND_ORIENTATION):
		saynn(coordinatorName + " glances up. \"Still here? You're checked in, you're on the list. Lecture hall, west side of the quad.\"")
		saynn("\"Go on. I promise it's only about twenty minutes of me talking at you.\"")
		addButton("Leave", "Head off", "leave")
		return

	if(stage == FirstDay.STAGE_RETURN_DORM || stage == FirstDay.STAGE_SLEEP):
		saynn(coordinatorName + " is stacking leaflets into a box. \"That's orientation done,\" she says. \"Go and unpack, sleep badly, and turn up to something tomorrow.\"")
		saynn("\"If anything about your room isn't working, this desk is where you complain. Loudly, preferably at someone else.\"")
		addButton("Leave", "Head off", "leave")
		return

	if(stage == FirstDay.STAGE_COMPLETE):
		saynn(coordinatorName + " nods at you over the desk. \"Settling in all right?\" she asks, and doesn't wait for an answer before taking a phone call.")
		addButton("Leave", "Head off", "leave")
		return

	saynn(coordinatorName + " is halfway through a phone call, and holds up a finger. Whatever you need, it can wait a moment.")
	addButton("Leave", "Head off", "leave")

func _react(_action: String, _args):
	if(_action == "checkin"):
		var _advanced = firstDay.advanceFrom(getUniversityState(), FirstDay.STAGE_CHECK_IN)
		processTime(120)
		endScene()
		return
	if(_action == "leave"):
		processTime(60)
		endScene()
		return
	setState(_action)
