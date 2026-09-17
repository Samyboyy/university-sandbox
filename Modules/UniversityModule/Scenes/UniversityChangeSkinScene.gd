extends "res://Scenes/ChangeSkinScene.gd"

# University Sandbox skin/colour editor.
#
# Reuses BDCC's colour pickers and per-bodypart editing, but only offers the plain skins
# allowed by UniversityPlayablePolicy (no fur, scale or fantasy patterns), drops
# "Randomize ALL" (it re-rolls skins and bodyparts) and never enters debug mode.
# Skin colours stay fully customisable.

const Policy = preload("res://Game/University/UniversityPlayablePolicy.gd")

var policy = Policy.new()

func _init():
	sceneID = "UniversityChangeSkinScene"

func _initScene(_args = []):
	._initScene(["pc"])
	debugMode = false

func _run():
	if(state == "basemenu"):
		savedPage = 0
		addButton("Back", "Go back", "")
		addButton("Skin", "Change base skin", "changebaseskinmenu")
		addButton("Primary color", "Change base primary color", "changebasecolormenu", [0])
		addButton("Secondary color", "Change base secondary color", "changebasecolormenu", [1])
		addButton("Tertiary color", "Change base tertiary color", "changebasecolormenu", [2])
		addButton("Randomize colors", "Pick random colors", "dorandomcolors")
		return

	if(state == "changebaseskinmenu"):
		addButton("Back", "Go back", "basemenu")
		for skinID in policy.getAllowedSkinIDs():
			var theSkin = GlobalRegistry.getSkin(skinID)
			var theSkinIsActive:bool = (thePC.pickedSkin == skinID)
			var theSkinName:String = ("[" + theSkin.getName() + "]") if theSkinIsActive else theSkin.getName()
			var theSkinDesc:String = "This is the currently selected skin" if theSkinIsActive else "Pick this skin"
			addButton(theSkinName, theSkinDesc, "changebaseskinmenu_select", [skinID])
		return

	if(state == "changepartskinmenu" && thePC.hasBodypart(pickedBodypartSlot) && !thePC.getBodypart(pickedBodypartSlot).hasCustomSkinPattern()):
		var bodypart = thePC.getBodypart(pickedBodypartSlot)
		addButton("Back", "Go back", "bodypartmenu")
		var inheritedSkinIsActive:bool = (bodypart.pickedSkin == null)
		addButton("[Same as base]" if inheritedSkinIsActive else "Same as base",
			"Currently inheriting the skin from the base" if inheritedSkinIsActive else "Inherit the skin from the base",
			"changepartskinmenu_select", [null])
		for skinID in policy.getAllowedSkinIDs():
			var theSkin = GlobalRegistry.getSkin(skinID)
			var theSkinIsActive:bool = (bodypart.pickedSkin == skinID)
			var theSkinName:String = ("[" + theSkin.getName() + "]") if theSkinIsActive else theSkin.getName()
			addButton(theSkinName, "This is the currently selected skin" if theSkinIsActive else "Pick this skin", "changepartskinmenu_select", [skinID])
		return

	._run()

func _react(_action: String, _args):
	if(_action == "do_reload_skins"):
		return
	if(_action == "dorandomcolorsall"):
		_action = "dorandomcolors"

	if(_action == "changebaseskinmenu_select"):
		if(_args.size() == 0 || !policy.isSkinAllowed(_args[0])):
			Log.printerr("University skin editor refused base skin '" + (str(_args[0]) if _args.size() > 0 else "") + "'")
			return

	if(_action == "changepartskinmenu_select" && thePC.hasBodypart(pickedBodypartSlot)):
		var bodypart = thePC.getBodypart(pickedBodypartSlot)
		var requested = _args[0] if _args.size() > 0 else null
		if(!bodypart.hasCustomSkinPattern() && requested != null && !policy.isSkinAllowed(requested)):
			Log.printerr("University skin editor refused part skin '" + str(requested) + "'")
			return

	var result = ._react(_action, _args)
	var _corrections = policy.enforceOnPlayer(thePC)
	return result
