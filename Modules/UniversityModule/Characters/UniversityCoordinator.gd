extends Character

# Priya Raman, the first-year orientation coordinator: the University Sandbox
# introductory NPC. Persistent (serialized with the save) and human, staffing the
# Student Services desk. See Docs/UNIVERSITY_NEW_GAME.md.

func _init():
	id = "universityCoordinator"
	npcCharacterType = CharacterType.Generic

	pickedSkin = "HumanSkin"
	pickedSkinRColor = Color("ffE8B98F")
	pickedSkinGColor = Color("ffC98F63")
	pickedSkinBColor = Color("ff8A5A3B")
	npcSkinData = {
		"hair": {"r": Color("ff2B2118"), "g": Color("ff3D2E20"), "b": Color("ff4A3828"),},
	}

func _getName():
	return "Priya Raman"

func getGender():
	return Gender.Female

func getSmallDescription() -> String:
	return "The first-year orientation coordinator."

func getSpecies():
	return ["human"]

func getThickness() -> int:
	return 50

func getFemininity() -> int:
	return 70

func createBodyparts():
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("humanhead"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("bunhair"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("anthrobody"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("anthroarms"))
	var breasts = GlobalRegistry.createBodypart("humanbreasts")
	breasts.size = 2
	giveBodypartUnlessSame(breasts)
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("plantilegs"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("humanears"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("vagina"))
	giveBodypartUnlessSame(GlobalRegistry.createBodypart("anus"))

func getDefaultEquipment():
	return ["UniversityStarterClothes"]

func getLocation():
	return "university_student_services"
