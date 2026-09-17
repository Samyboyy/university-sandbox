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
# Transformations the University player may start. Everything else registered is suppressed
# through EncounterSettings TF weights (see suppressTransformationsFor()).
const ALLOWED_TRANSFORMATION_IDS := []
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

# Parts with a custom skin pattern (ears, hair, penis) use pickedSkin as a *part skin* id from
# that exact part's registered table: colour, piercing, tattoo and scar variants, not fur.
# Any id not registered for that part (e.g. a wolf-ear pattern on human ears) is foreign.
func isPartSkinAllowed(bodypart) -> bool:
	if(bodypart == null || bodypart.pickedSkin == null):
		return true
	if(bodypart.hasCustomSkinPattern()):
		return GlobalRegistry.getPartSkins(bodypart.id).has(bodypart.pickedSkin)
	return isSkinAllowed(bodypart.pickedSkin)


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
		elif(!isPartSkinAllowed(bodypart)):
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
func enforceOnPlayer(character, refreshAppearance:bool = true) -> Array:
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
		if(part != null && !isPartSkinAllowed(part)):
			corrections.append("bodypart " + str(part.id) + " skin " + str(part.pickedSkin) + " -> base")
			part.pickedSkin = null

	if(!isSkinAllowed(character.pickedSkin)):
		corrections.append("base skin " + str(character.pickedSkin) + " -> " + DEFAULT_SKIN)
		character.pickedSkin = DEFAULT_SKIN

	if(!corrections.empty() && refreshAppearance):
		character.updateAppearance()
	return corrections


# University games don't start inherited (prison/furry) transformations. The definitions stay
# registered and NPCs are unaffected; only the player-side start gate
# (TFHolder.canStartTransformation -> EncounterSettings.getTFWeight) is set to zero.
func suppressTransformationsFor(encounterSettings) -> int:
	if(encounterSettings == null):
		return 0
	var suppressed:int = 0
	for transformationID in GlobalRegistry.transformations.keys():
		if(transformationID in ALLOWED_TRANSFORMATION_IDS):
			continue
		if(encounterSettings.getTFWeight(transformationID) != 0.0):
			encounterSettings.setTFWeight(transformationID, 0.0)
			suppressed += 1
	return suppressed
