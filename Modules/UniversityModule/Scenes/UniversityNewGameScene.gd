extends "res://Scenes/SceneBase.gd"

# University Sandbox production new-game route.
#
#   MainScene.startNewGame() -> UniversityNewGameScene
#     "" (welcome) -> "askforname" -> UniversityCharacterCreatorScene
#     -> "movein" (private dorm) -> "finish" -> WorldScene
#
# Later onboarding steps (majors, background, preferences...) slot in between the
# creator ending and "movein": add a state or child scene in _react_scene_end().
# See Docs/UNIVERSITY_NEW_GAME.md.

const Policy = preload("res://Game/University/UniversityPlayablePolicy.gd")
const StudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")

const STARTER_OUTFIT_ID := "UniversityStarterClothes"
const STARTER_UNDERWEAR_BOTTOM_ID := "plainBriefs"
const STARTER_UNDERWEAR_BOTTOM_VAGINA_ID := "plainPanties"
const STARTER_UNDERWEAR_TOP_ID := "plainBra"

var policy = Policy.new()
var studentProfile = StudentProfile.new()

func _init():
	sceneID = "UniversityNewGameScene"

func _initScene(_args = []):
	studentProfile.begin(GM.main.university)
	GM.pc.setLocation(StudentProfile.DORM_ROOM_ID)
	GM.pc.setSpecies(policy.getPlayerSpecies())
	GM.pc.resetBodypartsToDefault()
	var _corrections = policy.enforceOnPlayer(GM.pc)
	# Dressed from the start so the welcome screen doesn't show a naked preview.
	var _equipped = GM.pc.getInventory().equipItem(GlobalRegistry.createItem(STARTER_OUTFIT_ID))
	GM.pc.updateAppearance()

func _run():
	if(state == ""):
		aimCamera(StudentProfile.DORM_ROOM_ID)
		setLocationName("University Sandbox")
		playAnimation(StageScene.Solo, "stand")
		saynn("Welcome to University Sandbox.")
		saynn("You're an adult about to start your first year at university, with a room of your own waiting on campus. Before you move in, decide who you are.")
		addButton("Continue", "Choose your name", "askforname")

	if(state == "askforname"):
		say("Enter your character's name:")
		var textBox:LineEdit = addTextbox("player_name")
		var _ok = textBox.connect("text_entered", self, "onTextBoxEnterPressed")
		addButton("Confirm", "Choose this name", "setname")
		addButtonAt(4, "Random?", "Help choose a random name", "randomname")

	if(state == "movein"):
		aimCamera(StudentProfile.DORM_ROOM_ID)
		setLocationName(getDormName())
		playAnimation(StageScene.Solo, "stand")
		saynn("Moving day. You carry the last box up the stairs of the first-year residence hall and close the door of your new room behind you.")
		saynn("It's small, bare and entirely yours. No roommate, no schedule yet, nothing but a bed, a desk, a wardrobe and the noise of other students settling in down the hall.")
		addButton("Start unpacking", "Begin your first day on campus", "finish")

func getDormName() -> String:
	var room = GM.world.getRoomByID(StudentProfile.DORM_ROOM_ID) if GM.world != null else null
	if(room == null):
		return "Private Dorm Room"
	return room.getName()

func onTextBoxEnterPressed(_new_text:String):
	GM.main.pickOption("setname", [])

func _react(_action: String, _args):
	if(_action == "setname"):
		var newName:String = ""
		if(_args.size() > 0):
			newName = str(_args[0])
		else:
			newName = str(getTextboxData("player_name"))
		newName = newName.strip_edges()
		if(newName == ""):
			return
		GM.pc.setName(newName)
		runScene("UniversityCharacterCreatorScene", [], "character_creator")
		return

	if(_action == "randomname"):
		runScene("CharacterNameGeneratorScene", [], "name_generator")
		return

	if(_action == "finish"):
		studentProfile.completeOnboarding(GM.main.university)
		runScene("WorldScene")
		endScene()
		return

	setState(_action)

func _react_scene_end(_tag, _result):
	if(_tag == "name_generator"):
		if(_result is Dictionary && _result.has("random_name")):
			GM.main.pickOption("setname", [_result["random_name"]])
	if(_tag == "character_creator"):
		completeCreation()
		setState("movein")

func completeCreation():
	var _corrections = policy.enforceOnPlayer(GM.pc)
	equipStarterOutfit()
	GM.pc.setLocation(StudentProfile.DORM_ROOM_ID)
	# BDCC's starting-perk picker is skipped for now; this also hides its "Pick Perks!" prompt.
	setFlag("Game_PickedStartingPerks", true)

# Fixed placeholder outfit: plain T-shirt and shorts plus plain underwear matched to the body.
func equipStarterOutfit():
	var inventory = GM.pc.getInventory()
	inventory.clear()
	for itemID in getStarterItemIDs():
		var _equipped = inventory.equipItem(GlobalRegistry.createItem(itemID))
	GM.pc.updateAppearance()

# The starter items for the player's current body, in equip order.
func getStarterItemIDs() -> Array:
	var result:Array = [STARTER_OUTFIT_ID]
	result.append(STARTER_UNDERWEAR_BOTTOM_VAGINA_ID if (GM.pc.hasVagina() && !GM.pc.hasPenis()) else STARTER_UNDERWEAR_BOTTOM_ID)
	if(GM.pc.hasNonFlatBreasts()):
		result.append(STARTER_UNDERWEAR_TOP_ID)
	return result
