extends "res://Scenes/CharacterCreatorScene.gd"

# University Sandbox character creator.
#
# Reuses BDCC's creator (gender, pronouns, attribute editing, colour pickers and the
# visual preview) but never shows species or hybrid choices, only offers bodyparts and
# skins allowed by UniversityPlayablePolicy, relabels BDCC part names, and forces the
# finished player back into policy before the scene ends.

const Policy = preload("res://Game/University/UniversityPlayablePolicy.gd")

# BDCC creator states that expose species choices. They are never shown here.
const SPECIES_STATES := ["pickspecies", "pickhybrid1", "pick2species"]
# Actions that would change species. They are refused; the player stays human.
const SPECIES_ACTIONS := ["setspecies", "pickspecies", "pickhybrid1", "pick2species"]
const APPEARANCE_STATE := "pickedspecies" # BDCC's name for the appearance summary

var policy = Policy.new()

func _init():
	sceneID = "UniversityCharacterCreatorScene"

func _initScene(_args = []):
	# No debug mode: the University route always applies the policy.
	debugMode = false
	resetToHumanBody()

func resetToHumanBody():
	GM.pc.setSpecies(policy.getPlayerSpecies())
	GM.pc.resetBodypartsToDefault()
	var _corrections = policy.enforceOnPlayer(GM.pc)
	GM.pc.updateAppearance()

func _run():
	if(state in SPECIES_STATES):
		state = APPEARANCE_STATE
	if(state == APPEARANCE_STATE):
		runAppearanceMenu()
		return
	if(state == "pickbodypart"):
		runBodypartMenu()
		return
	if(state == "bodypartAttributes"):
		runBodypartAttributesMenu()
		return
	if(state == "bodyAttributes"):
		runBodyAttributesMenu()
		return
	._run()

func runAppearanceMenu():
	savedPage = 0
	playAnimation(StageScene.Solo, "stand", {bodyState={naked=true,hard=true}})
	saynn("Customise how your student looks. You can keep adjusting everything until you confirm.")
	for slot in policy.getOfferedSlots():
		var bodypart = GM.pc.getBodypart(slot) if GM.pc.hasBodypart(slot) else null
		say(BodypartSlot.getVisibleName(slot) + ": " + policy.getDisplayName(bodypart) + "\n")
		if(bodypart != null):
			for curAttrib in bodypart.getAttributesText():
				sayn(" - " + curAttrib[0] + ": " + str(curAttrib[1]))
	say("\n")
	sayn("Body attributes:")
	for curAttrib in GM.pc.getAttributesText():
		sayn(curAttrib[0] + ": " + str(curAttrib[1]))

	addExtraButtonAt(0, "Confirm", "Confirm your character", "donecreating")
	addExtraButtonAt(3, "Body attributes", "Change your femininity, thickness, skin and colours", "bodyAttributes")
	for slot in policy.getOfferedSlots():
		addButton(BodypartSlot.getVisibleName(slot), "Change this bodypart", "pickbodypart", [slot])

func runBodypartMenu():
	saynn("Choose the bodypart or change the attributes of the current one")
	addButton("Back", "go back", APPEARANCE_STATE)

	var playerBodypart = GM.pc.getBodypart(pickingBodypartType) if GM.pc.hasBodypart(pickingBodypartType) else null
	if(playerBodypart != null):
		sayn("Currently selected: " + policy.getDisplayName(playerBodypart))
		for curAttrib in playerBodypart.getAttributesText():
			sayn(curAttrib[0] + ": " + str(curAttrib[1]))
		if(playerBodypart.getPickableAttributes().size() > 0):
			addButton("Change current", "Change the attributes of the current bodypart instead of creating a new one", "bodypartAttributes")

	if(!BodypartSlot.isEssential(pickingBodypartType)):
		var bodypartIsMissing:bool = (playerBodypart == null)
		addButton("[Nothing]" if bodypartIsMissing else "Nothing",
			"This is the currently selected option" if bodypartIsMissing else "Remove the bodypart.\n\nNOTE: This resets the colors and skin of this bodypart.",
			"removebodypart", [pickingBodypartType])

	for bodypartID in policy.getAllowedBodypartIDs(pickingBodypartType):
		var bodypart = GlobalRegistry.getBodypartRef(bodypartID)
		if(!bodypart):
			continue
		var bodypartIsActive:bool = (playerBodypart != null) && (playerBodypart.id == bodypartID)
		var bodypartName:String = policy.getDisplayName(bodypart)
		if(bodypartIsActive):
			bodypartName = "[" + bodypartName + "]"
		addButton(bodypartName, bodypart.getCharacterCreatorDescFinal(bodypartIsActive), "setbodypart", [bodypartID])

	if(savedPage != 0):
		GM.ui.setCurrentPage(savedPage)

func runBodypartAttributesMenu():
	playAnimation(StageScene.Solo, "stand", {bodyState={naked=true,hard=true}})
	addButton("Done", "You're done changing attributes", APPEARANCE_STATE)
	if(!GM.pc.hasBodypart(pickingBodypartType)):
		return
	var bodypart = GM.pc.getBodypart(pickingBodypartType)
	saynn("Change the attributes of: " + policy.getDisplayName(bodypart))
	for curAttrib in bodypart.getAttributesText():
		sayn(curAttrib[0] + ": " + str(curAttrib[1]))
	var attributes = bodypart.getPickableAttributes()
	for attributeID in attributes:
		var attribute = attributes[attributeID]
		addButton(attribute["textButton"], attribute["buttonDesc"], "attributeMenu", [attributeID])

func runBodyAttributesMenu():
	saynn("Pick what you want to change about your body")
	for curAttrib in GM.pc.getAttributesText():
		sayn(curAttrib[0] + ": " + str(curAttrib[1]))

	addButton("Done", "You're done changing attributes", APPEARANCE_STATE)
	addButton("Skin/Colors", "Change your skin tone and colours", "startskinmenu")

	var attributes = GM.pc.getPickableAttributes()
	for attributeID in attributes:
		var attribute = attributes[attributeID]
		addButton(attribute["textButton"], attribute["buttonDesc"], "bodyAttributeMenu", [attributeID])

	for slot in policy.getOfferedSlots():
		if(!GM.pc.hasBodypart(slot)):
			continue
		var bodypart = GM.pc.getBodypart(slot)
		if(bodypart.getPickableAttributes().size() == 0):
			continue
		addButton(policy.getDisplayName(bodypart) + " attributes", "Change the attributes of this bodypart", "openBodypartAttributes", [slot])

func _react(_action: String, _args):
	if(_action in SPECIES_ACTIONS):
		# Species can't be chosen in University Sandbox. Refuse the action: the player stays
		# human and keeps their current (policy-compliant) appearance choices.
		var _corrections = policy.enforceOnPlayer(GM.pc)
		setState(APPEARANCE_STATE)
		return

	if(_action == "setpronouns"):
		GM.pc.setPronounGender(_args[0])
		resetToHumanBody()
		setState(APPEARANCE_STATE)
		return

	if(_action == "pickbodypart" || _action == "openBodypartAttributes"):
		if(_args.size() > 0 && !policy.isSlotOffered(_args[0])):
			return

	if(_action == "setbodypart"):
		var requestedID = _args[0] if _args.size() > 0 else null
		if(!policy.isBodypartAllowed(pickingBodypartType, requestedID)):
			Log.printerr("University creator refused bodypart '" + str(requestedID) + "' for slot '" + str(pickingBodypartType) + "'")
			return

	if(_action == "removebodypart"):
		var slot = _args[0] if _args.size() > 0 else ""
		if(!policy.isSlotOffered(slot) || BodypartSlot.isEssential(slot)):
			return

	if(_action == "startskinmenu"):
		runScene("UniversityChangeSkinScene")
		return

	if(_action == "endthescene" || _action == "donecreating"):
		var _corrections = policy.enforceOnPlayer(GM.pc)
		endScene()
		return

	var result = ._react(_action, _args)
	var _stillCompliant = policy.enforceOnPlayer(GM.pc)
	return result

func _react_scene_end(_tag, _result):
	var _corrections = policy.enforceOnPlayer(GM.pc)
