extends Reference

# University Sandbox playable-content policy.
#
# The single boundary that decides what the player may be in the University Sandbox
# new-game route: species, bodyparts, skins and visible labels. BDCC's species,
# bodyparts and skins stay registered (the renderer, items and legacy modules still
# depend on them); this policy only controls what the University route offers and
# what the finished player is allowed to keep. See Docs/UNIVERSITY_NEW_GAME.md.
#
# Loaded with preload (no class_name) so headless runs don't depend on the editor
# regenerating project.godot's global class list.

const PLAYER_SPECIES := "human"

# Allowed bodypart ids per slot. Slots missing here (tail, horns) are not offered.
# Anything not listed is treated as non-human or out of scope for now.
const ALLOWED_BODYPARTS := {
	"body": ["anthrobody"], # BDCC's shared body mesh; it is the human body (HumanBody.tscn)
	"arms": ["anthroarms", "buffarms"],
	"legs": ["plantilegs"],
	"head": ["humanhead", "humanoldhead"],
	"ears": ["humanears"],
	"breasts": ["humanbreasts", "malebreasts"],
	"penis": ["humanpenis"],
	"vagina": ["vagina"],
	"anus": ["anus"],
	"hair": [
		"baldhair", "bunhair", "combedbackhair", "coolhair", "ferrihair", "jackihair",
		"longhair", "messyhair", "messyhair2", "mohawkhair", "overeyehair", "overeyehair2",
		"ponytailhair", "ponytailhair2", "ponytailhair3", "ponytailhair4", "shorthair",
		"shorthair2", "simplehair", "sockethair", "tavihair",
		"SongHair1", "songhair2", "Songhair3", "SongHair4", "SongHair5", "SongHair6",
		"SongHair7a", "SongHair7b", "SongHair8", "SongHair9", "SongHair10a", "SongHair10b",
		"SongHair11a", "SongHair11b", "SongHair12a", "SongHair12B", "SongHair13", "SongHair14",
		"SongHair15", "SongHair16", "SongHair17", "SongHair18", "SongHair19A", "SongHair19B",
		"SongHair20", "SongHair21a", "SongHair21b", "SongHair22", "SongHair23", "SongHair24a",
		"SongHair24b", "SongHair25", "SongHair26", "SongHair27", "SongHair28", "SongHair29",
		"SongHair30", "SongHair31a", "SongHair31b", "SongHair32", "SongHair33A", "SongHair33B",
	],
}

# Base skins with no fur, scale or fantasy pattern. Skin colours stay fully customisable.
const ALLOWED_SKINS := ["HumanSkin", "EmptySkin"]
const DEFAULT_SKIN := "EmptySkin"

# Player-facing labels that would otherwise expose BDCC/anthro terminology.
const DISPLAY_NAMES := {
	"anthrobody": "Body",
	"anthroarms": "Arms",
	"buffarms": "Muscular arms",
	"plantilegs": "Legs",
	"humanhead": "Head",
	"humanoldhead": "Head (beard)",
	"humanears": "Ears",
	"humanbreasts": "Breasts",
	"malebreasts": "Flat chest",
	"humanpenis": "Penis",
}

func getPlayerSpecies() -> Array:
	return [PLAYER_SPECIES]

func getOfferedSlots() -> Array:
	var result:Array = []
	for slot in BodypartSlot.getAll():
		if(ALLOWED_BODYPARTS.has(slot)):
			result.append(slot)
	return result

func isSlotOffered(slot) -> bool:
	return ALLOWED_BODYPARTS.has(slot)

func isBodypartAllowed(slot, bodypartID) -> bool:
	if(!(bodypartID is String) || !ALLOWED_BODYPARTS.has(slot)):
		return false
	return bodypartID in ALLOWED_BODYPARTS[slot]

# Registered ids for a slot that the University route may offer, in registry order.
func getAllowedBodypartIDs(slot) -> Array:
	var result:Array = []
	if(!ALLOWED_BODYPARTS.has(slot)):
		return result
	for bodypartID in GlobalRegistry.getBodypartsIdsBySlot(slot):
		if(bodypartID in ALLOWED_BODYPARTS[slot]):
			result.append(bodypartID)
	return result

func isSkinAllowed(skinID) -> bool:
	return skinID is String && skinID in ALLOWED_SKINS

func getAllowedSkinIDs() -> Array:
	var result:Array = []
	for skinID in GlobalRegistry.getSkinsAllKeys():
		if(skinID in ALLOWED_SKINS):
			result.append(skinID)
	return result

func getDisplayName(bodypart) -> String:
	if(bodypart == null):
		return "None"
	if(DISPLAY_NAMES.has(bodypart.id)):
		return DISPLAY_NAMES[bodypart.id]
	return bodypart.getCharacterCreatorName()

# Every way the player currently breaks the policy. Empty means compliant.
func getViolations(character) -> Array:
	var result:Array = []
	if(character.getSpecies() != getPlayerSpecies()):
		result.append("species is " + str(character.getSpecies()) + ", expected " + str(getPlayerSpecies()))
	var bodyparts:Dictionary = character.getBodyparts()
	for slot in bodyparts.keys():
		var bodypart = bodyparts[slot]
		if(bodypart == null):
			continue
		if(!isBodypartAllowed(slot, bodypart.id)):
			result.append("bodypart '" + str(bodypart.id) + "' is not allowed in slot '" + str(slot) + "'")
		elif(bodypart.pickedSkin != null && !bodypart.hasCustomSkinPattern() && !isSkinAllowed(bodypart.pickedSkin)):
			result.append("bodypart '" + str(bodypart.id) + "' uses skin '" + str(bodypart.pickedSkin) + "'")
	for slot in getOfferedSlots():
		if(BodypartSlot.isEssential(slot) && !character.hasBodypart(slot)):
			result.append("essential slot '" + str(slot) + "' is empty")
	if(!isSkinAllowed(character.pickedSkin)):
		result.append("base skin is '" + str(character.pickedSkin) + "'")
	return result

# Forces the player into policy: human species, allowed parts and skins.
# Disallowed parts are replaced with the human default for that slot, or removed
# when the slot is not offered (tails, horns). Returns the corrections made.
func enforceOnPlayer(character) -> Array:
	var corrections:Array = []
	if(character.getSpecies() != getPlayerSpecies()):
		corrections.append("species " + str(character.getSpecies()) + " -> " + str(getPlayerSpecies()))
		character.setSpecies(getPlayerSpecies())

	var humanSpecies = GlobalRegistry.getSpecies(PLAYER_SPECIES)
	var bodyparts:Dictionary = character.getBodyparts()
	for slot in bodyparts.keys():
		var bodypart = bodyparts[slot]
		if(bodypart == null || isBodypartAllowed(slot, bodypart.id)):
			continue
		var defaultID = humanSpecies.getDefaultForSlot(slot, character.getGender()) if humanSpecies != null else null
		if(isSlotOffered(slot) && isBodypartAllowed(slot, defaultID)):
			character.giveBodypartUnlessSame(GlobalRegistry.createBodypart(defaultID))
			corrections.append("bodypart " + str(bodypart.id) + " -> " + str(defaultID))
		else:
			character.removeBodypart(slot)
			corrections.append("bodypart " + str(bodypart.id) + " removed")

	for slot in getOfferedSlots():
		if(!BodypartSlot.isEssential(slot) || character.hasBodypart(slot) || humanSpecies == null):
			continue
		var fallbackID = humanSpecies.getDefaultForSlot(slot, character.getGender())
		if(!isBodypartAllowed(slot, fallbackID)):
			fallbackID = ALLOWED_BODYPARTS[slot][0]
		character.giveBodypartUnlessSame(GlobalRegistry.createBodypart(fallbackID))
		corrections.append("empty " + str(slot) + " -> " + str(fallbackID))

	for slot in character.getBodyparts().keys():
		var part = character.getBodypart(slot)
		if(part != null && part.pickedSkin != null && !part.hasCustomSkinPattern() && !isSkinAllowed(part.pickedSkin)):
			corrections.append("bodypart " + str(part.id) + " skin " + str(part.pickedSkin) + " -> base")
			part.pickedSkin = null

	if(!isSkinAllowed(character.pickedSkin)):
		corrections.append("base skin " + str(character.pickedSkin) + " -> " + DEFAULT_SKIN)
		character.pickedSkin = DEFAULT_SKIN

	if(!corrections.empty()):
		character.updateAppearance()
	return corrections
