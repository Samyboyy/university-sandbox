extends SceneTree

# University Sandbox - automated headless test harness (T2).
#
# Do not run this directly against your normal user data. Use one of the runners,
# which redirect all user data to a disposable temporary folder first:
#   Linux:   Tests/run_tests.sh --godot /path/to/Godot_v3.6.2
#   Windows: Tests\run_tests.ps1 -Godot C:\path\to\Godot_v3.6.2.exe
#
# The runner sets US_TEST_ROOT. The harness refuses to continue (and writes no save)
# unless user:// resolves inside that folder.
#
# Exit codes: 0 = every assertion passed, 1 = at least one assertion failed or a phase timed out.
# Assertions describe the current baseline; later tickets may update them deliberately.
# T3 adds save identity, University schema and invalid-save rejection coverage (phases 5-7).
# T4 adds the University new-game route: human-only creation, starter outfit and private dorm (phase 4a-4g).

const EXPECTED_DISPLAY_NAME := "University Sandbox"
const EXPECTED_USER_DIR_NAME := "university_sandbox"
const TEST_SAVE_PATH := "user://saves/us_harness_roundtrip.save"
const TEST_PLAYER_NAME := "HarnessTester_RoundTrip"
const MUTATED_PLAYER_NAME := "HarnessTester_Mutated"
const CREDITS_DELTA := 4242
const MUTATED_SCENE_STATE := "__harness_mutated_state__"
const PROBE_SYSTEM_ID := "harness_probe"
const PROBE_DATA := {"marker": "t3-roundtrip", "count": 3, "nested": {"flag": true}}
const REJECT_SAVE_PREFIX := "user://saves/us_harness_reject_"
const LIVE_NAME_BEFORE_REJECTS := "HarnessTester_LiveBeforeRejects"
const NAME_BEFORE_FINAL_LOAD := "HarnessTester_BeforeFinalLoad"
const EXPECTED_GAME_ID := "university_sandbox"
const EXPECTED_SCHEMA_VERSION := 1

# T4: University new-game route
const UNIVERSITY_NEW_GAME_SCENE := "UniversityNewGameScene"
const UNIVERSITY_CREATOR_SCENE := "UniversityCharacterCreatorScene"
const UNIVERSITY_SKIN_SCENE := "UniversityChangeSkinScene"
const DORM_ROOM_ID := "university_private_dorm"
const DORM_ROOM_NAME := "Private Dorm Room"
const DORM_FLOOR_ID := "UniversityDormFloor"
const LEGACY_PRISON_CELL := "cellblock_orange_playercell"
const LEGACY_PRISON_SCENES := ["IntroScene", "IntroIntake", "IntroMedical", "IntroWakeup", "PickStartingPerksScene"]
const PROFILE_SYSTEM_ID := "student_profile"
const PROFILE_ROUTE := "university"
const T3_ERA_FIXTURE_PATH := "user://t3_era_no_student_profile.save" # outside saves/ so the save list ignores it
const ROUTE_PLAYER_NAME := "Harness Student"
const NON_HUMAN_BODYPART_IDS := ["digilegs", "hoofs", "caninepenis", "dragonpenis", "equinepenis", "felinepenis",
	"ovipositorpenis", "anusEggs", "vaginaEggs", "manehair", "felinetail", "caninetail", "felinehead", "caninehead",
	"felineears", "dragonhorns", "demonhorns", "androidhead"]
const SPECIES_WORDS := ["canine", "feline", "dragon", "equine", "demon", "hybrid", "anthro", "species", "fur"]
const PRISON_ITEM_IDS := ["inmateuniform", "inmatecollar", "inmatewristcuffs", "inmateanklecuffs", "policecuffs", "basketmuzzle"]
const PRISON_WORDS := ["prison", "inmate", "cell", "guard", "captain"]
const STARTER_ITEMS_MALE := ["UniversityStarterClothes", "plainBriefs"] # male default body: no panties, no bra
const POLICY_PATH := "res://Game/University/UniversityPlayablePolicy.gd" # loaded at runtime: a preload here compiles before autoloads exist

const LAUNCH_SCENE := "res://UI/LaunchScreen/LaunchScreen.tscn"
const MAIN_MENU_SCENE := "res://UI/MainMenu/MainMenu.tscn"
const MAIN_GAME_SCENE := "res://Game/MainScene.tscn"

const REGISTRY_TIMEOUT_SEC := 180.0
const MENU_TIMEOUT_SEC := 60.0
const NEW_GAME_TIMEOUT_SEC := 60.0
const SETTLE_FRAMES := 10

var passed := 0
var failed := 0
var step := 0
var elapsed := 0.0
var frames := 0
var done := false
var testRoot := ""
var recorded := {}
var lastCheckPassed := false


func _initialize():
	print("HARNESS: University Sandbox test harness starting")
	print("HARNESS: Godot " + str(Engine.get_version_info()["string"]))


func _idle(delta):
	if(done):
		return false
	elapsed += delta
	frames += 1

	if(step == 0):
		phaseStartupAndIdentity()
	elif(step == 1):
		waitForRegistry()
	elif(step == 2):
		waitForMainMenu()
	elif(step == 3):
		waitForNewGame()
	elif(step == 4):
		if(frames >= SETTLE_FRAMES):
			phaseUniversityRoute()
	elif(step == 5):
		if(frames >= SETTLE_FRAMES):
			phaseNewGameAndSave()
	elif(step == 6):
		if(frames >= 2):
			phaseLoad()
	elif(step == 7):
		if(frames >= SETTLE_FRAMES):
			phaseVerifyRoundTrip()
	elif(step == 8):
		phaseRejections()
	elif(step == 9):
		if(frames >= SETTLE_FRAMES):
			phaseMenuLoadRefusalAndFinalLoad()
	elif(step == 10):
		if(frames >= SETTLE_FRAMES):
			phaseVerifyFinalLoad()
	return false


# ---------------------------------------------------------------- helpers

func beginPhase(title:String):
	print("")
	print("== " + title)


func check(condition:bool, description:String, expected, observed):
	lastCheckPassed = condition
	if(condition):
		passed += 1
		print("  [PASS] " + description)
	else:
		failed += 1
		print("  [FAIL] " + description)
		print("         expected: " + str(expected))
		print("         observed: " + str(observed))


func info(text:String):
	print("  [INFO] " + text)


func nextStep(newStep:int):
	step = newStep
	elapsed = 0.0
	frames = 0


func abortRun(reason:String):
	failed += 1
	print("  [ABORT] " + reason)
	finishRun()


func finishRun():
	done = true
	var overallPass:bool = (failed == 0 && passed > 0)
	print("")
	print("==================== HARNESS SUMMARY ====================")
	print("HARNESS: passed=" + str(passed) + " failed=" + str(failed))
	print("HARNESS RESULT: " + ("PASS" if overallPass else "FAIL"))
	print("=========================================================")
	quit(0 if overallPass else 1)


func normalisePath(thePath:String) -> String:
	var result:String = thePath.replace("\\", "/")
	while(result.ends_with("/") && result.length() > 1):
		result = result.substr(0, result.length() - 1)
	if(OS.get_name() == "Windows"):
		result = result.to_lower()
	return result


func isInsideTestRoot(thePath:String) -> bool:
	if(testRoot.empty()):
		return false
	return normalisePath(thePath).begins_with(testRoot + "/")


func getNode(nodeName:String):
	return root.get_node_or_null(nodeName)


func sceneIDsOf(stack:Array) -> Array:
	var result:Array = []
	for scene in stack:
		result.append(scene.sceneID)
	return result


func sortedJSON(value) -> String:
	return JSON.print(value, "", true)


func readJSONFile(thePath:String):
	var theFile := File.new()
	if(theFile.open(thePath, File.READ) != OK):
		return null
	var text:String = theFile.get_as_text()
	theFile.close()
	var parsed = JSON.parse(text)
	if(parsed.error != OK):
		return null
	return parsed.result


func writeTextFile(thePath:String, text:String) -> bool:
	var theFile := File.new()
	if(theFile.open(thePath, File.WRITE) != OK):
		return false
	theFile.store_string(text)
	theFile.close()
	return true


# Everything a rejected load must leave untouched.
func liveStateFingerprint() -> String:
	var gm = getNode("GM")
	var registry = getNode("GlobalRegistry")
	var save = getNode("SAVE")
	var currentScene = gm.main.getCurrentScene()
	return sortedJSON({
		"name": gm.pc.getName(),
		"credits": gm.pc.getCredits(),
		"location": gm.pc.getLocation(),
		"day": gm.main.getDays(),
		"time": gm.main.getTime(),
		"sceneIDs": sceneIDsOf(gm.main.sceneStack),
		"sceneInstances": instanceIDsOf(gm.main.sceneStack),
		"sceneState": currentScene.state if currentScene != null else "",
		"university": gm.main.university.saveData(),
		"uniqueID": registry.currentUniqueID,
		"npcUniqueID": registry.currentNPCUniqueID,
		"currentSave": registry.currentSave,
		"loadedSavefileVersion": save.getLoadedSavefileVersion(),
		"main": gm.main.get_instance_id(),
		"pc": gm.pc.get_instance_id(),
	})


func instanceIDsOf(stack:Array) -> Array:
	var result:Array = []
	for scene in stack:
		result.append(scene.get_instance_id())
	return result


# ---------------------------------------------------------------- phase 1 + 2

func phaseStartupAndIdentity():
	beginPhase("Phase 1: autoload startup")
	var allAutoloads:bool = true
	for autoloadName in ["GlobalRegistry", "GM", "SAVE", "OPTIONS"]:
		var present:bool = getNode(autoloadName) != null
		check(present, "autoload '" + autoloadName + "' is available", "present", "present" if present else "missing")
		allAutoloads = allAutoloads && present
	if(!allAutoloads):
		abortRun("required autoloads are missing; cannot continue")
		return

	beginPhase("Phase 2: project identity and user-data isolation")
	var displayName = ProjectSettings.get_setting("application/config/name")
	var useCustomDir = ProjectSettings.get_setting("application/config/use_custom_user_dir")
	var customDirName = ProjectSettings.get_setting("application/config/custom_user_dir_name")
	check(displayName == EXPECTED_DISPLAY_NAME, "display name", EXPECTED_DISPLAY_NAME, displayName)
	check(useCustomDir == true, "custom user directory is enabled", true, useCustomDir)
	check(customDirName == EXPECTED_USER_DIR_NAME, "custom user directory name", EXPECTED_USER_DIR_NAME, customDirName)

	var userDir:String = OS.get_user_data_dir()
	info("resolved user:// = " + userDir)
	var normalisedUserDir:String = normalisePath(userDir)
	check(normalisedUserDir.find("app_userdata/bdcc") < 0 && normalisedUserDir.find("app_userdata/BDCC") < 0,
		"user:// is not the old BDCC user-data folder", "no 'app_userdata/BDCC' in path", userDir)
	check(normalisedUserDir.ends_with("/" + normalisePath(EXPECTED_USER_DIR_NAME)),
		"user:// ends with the University Sandbox directory name", "*/" + EXPECTED_USER_DIR_NAME, userDir)

	var rawRoot:String = OS.get_environment("US_TEST_ROOT")
	testRoot = normalisePath(rawRoot)
	info("test root (US_TEST_ROOT) = " + rawRoot)
	if(testRoot.empty() || testRoot == "/" || testRoot.length() < 8):
		abortRun("US_TEST_ROOT is missing or unsafe; run the harness through Tests/run_tests.sh or Tests/run_tests.ps1")
		return
	check(isInsideTestRoot(userDir), "user:// resolves inside the temporary test root", testRoot + "/...", userDir)
	if(!lastCheckPassed):
		abortRun("user data is not isolated; refusing to start the game or write saves")
		return

	var theError:int = change_scene(LAUNCH_SCENE)
	check(theError == OK, "launch scene can be opened", OK, theError)
	if(!lastCheckPassed):
		abortRun("could not open " + LAUNCH_SCENE)
		return
	nextStep(1)


# ---------------------------------------------------------------- phase 3

func waitForRegistry():
	var registry = getNode("GlobalRegistry")
	if(registry.isInitialized):
		info("registry initialised after " + str(stepify(elapsed, 0.01)) + " s")
		phaseRegistry()
		return
	if(elapsed > REGISTRY_TIMEOUT_SEC):
		beginPhase("Phase 3: registry initialisation")
		check(false, "registry initialises within " + str(REGISTRY_TIMEOUT_SEC) + " s", "isInitialized == true", "still false after " + str(stepify(elapsed, 0.1)) + " s")
		abortRun("registry initialisation timed out")


func phaseRegistry():
	beginPhase("Phase 3: registry initialisation")
	var registry = getNode("GlobalRegistry")
	check(registry.isInitialized, "GlobalRegistry.isInitialized", true, registry.isInitialized)
	check(registry.scenes.size() > 0, "scene registry is populated", "> 0", registry.scenes.size())
	check(registry.items.size() > 0, "item registry is populated", "> 0", registry.items.size())
	check(registry.bodyparts.size() > 0, "bodypart registry is populated", "> 0", registry.bodyparts.size())
	check(registry.getModules().size() > 0, "module registry is populated", "> 0", registry.getModules().size())
	check(registry.getAllSpecies().has("human"), "species registry contains 'human'", "has 'human'", registry.getAllSpecies().keys())
	info("counts: scenes=" + str(registry.scenes.size()) + " items=" + str(registry.items.size())
		+ " bodyparts=" + str(registry.bodyparts.size()) + " modules=" + str(registry.getModules().size())
		+ " species=" + str(registry.getAllSpecies().size()))
	nextStep(2)


func waitForMainMenu():
	if(current_scene != null && current_scene.filename == MAIN_MENU_SCENE):
		phaseMainMenuRegression()
		return
	if(elapsed > MENU_TIMEOUT_SEC):
		var observed = current_scene.filename if current_scene != null else "no scene"
		check(false, "main menu is reached after registry initialisation", MAIN_MENU_SCENE, observed)
		abortRun("main menu was not reached")


func phaseMainMenuRegression():
	beginPhase("Phase 3b: main menu and T1 no-startup-network regression")
	check(true, "main menu reached (" + str(stepify(elapsed, 0.01)) + " s after registry initialisation)", MAIN_MENU_SCENE, current_scene.filename)
	var registry = getNode("GlobalRegistry")
	var options = getNode("OPTIONS")
	check(registry.donationDataRequest == null, "no donation-data HTTP request was created", null, registry.donationDataRequest)
	check(options.shouldFetchGithubRelease() == false, "GitHub release check is disabled", false, options.shouldFetchGithubRelease())
	var releaseRequest = current_scene.get("http_request")
	if(releaseRequest != null):
		var status:int = releaseRequest.get_http_client_status()
		check(status == HTTPClient.STATUS_DISCONNECTED, "main menu release HTTPRequest is idle", HTTPClient.STATUS_DISCONNECTED, status)
	else:
		info("main menu has no 'http_request' node any more; release-request idle check skipped")

	# The normal New Game button handler (MainMenu._on_NewGameButton_pressed).
	check(current_scene.has_method("_on_NewGameButton_pressed"), "main menu has the New Game action", "_on_NewGameButton_pressed", current_scene.filename)
	if(!lastCheckPassed):
		abortRun("main menu New Game action not found")
		return
	current_scene._on_NewGameButton_pressed()
	nextStep(3)


# ---------------------------------------------------------------- phase 4 + 5

func waitForNewGame():
	var gm = getNode("GM")
	var gameReady:bool = (current_scene != null && gm.main != null && is_instance_valid(gm.main)
		&& gm.main == current_scene && gm.pc != null && gm.main.sceneStack.size() > 0)
	if(gameReady):
		nextStep(4)
		return
	if(elapsed > NEW_GAME_TIMEOUT_SEC):
		beginPhase("Phase 4: new-game startup")
		check(false, "new game starts within " + str(NEW_GAME_TIMEOUT_SEC) + " s", "GM.main is the current scene with a player and a scene stack",
			"current_scene=" + (current_scene.filename if current_scene != null else "none") + " GM.main=" + str(gm.main) + " GM.pc=" + str(gm.pc))
		abortRun("new game did not start")


# ---------------------------------------------------------------- T4: University new-game route

# Every enabled button currently offered by the game UI, as [text, method, args].
func currentButtons() -> Array:
	var ui = getNode("GM").ui
	var result:Array = []
	for key in ui.options.keys():
		var option = ui.options[key]
		if(option.size() >= 5 && option[0]):
			result.append([str(option[1]), str(option[3]), option[4]])
	for key in ui.extraOptions.keys():
		var extra = ui.extraOptions[key]
		if(extra.size() >= 5 && extra[0]):
			result.append([str(extra[1]), str(extra[3]), extra[4]])
	return result


func buttonArgsFor(method:String) -> Array:
	var result:Array = []
	for button in currentButtons():
		if(button[1] == method):
			result.append(button[2])
	return result


func buttonMethods() -> Array:
	var result:Array = []
	for button in currentButtons():
		result.append(button[1])
	return result


func textsContainingAny(words:Array) -> Array:
	var found:Array = []
	for button in currentButtons():
		var lowered:String = button[0].to_lower()
		for word in words:
			if(lowered.find(word) >= 0):
				found.append(button[0])
	return found


func pick(method:String, args:Array = []):
	getNode("GM").main.pickOption(method, args)


func currentSceneID() -> String:
	var scene = getNode("GM").main.getCurrentScene()
	return scene.sceneID if scene != null else ""


func equippedItemIDs() -> Array:
	var result:Array = []
	var equipped:Dictionary = getNode("GM").pc.getInventory().getEquippedItems()
	for slot in equipped.keys():
		result.append(equipped[slot].id)
	result.sort()
	return result


func completedProfile() -> Dictionary:
	return {"onboarding_completed": true, "student_year": 1, "housing_id": DORM_ROOM_ID, "route": PROFILE_ROUTE, "is_adult": true}


# A completed profile with one field changed; value "__erase__" removes the field.
func profileWith(key:String, value) -> Dictionary:
	var data:Dictionary = completedProfile()
	if(value is String && value == "__erase__"):
		var _removed = data.erase(key)
	else:
		data[key] = value
	return data


func sortedArray(values:Array) -> Array:
	var result:Array = values.duplicate()
	result.sort()
	return result


# Male default anatomy plus the longhair customisation, outfit and profile.
func checkMaleStudent(context:String, expectLongHair:bool = true):
	var gm = getNode("GM")
	check(gm.pc.getGender() == Gender.Male, "gender is male " + context, Gender.Male, gm.pc.getGender())
	check(gm.pc.getPronounGender() == Gender.Male, "pronouns are male " + context, Gender.Male, gm.pc.getPronounGender())
	check(gm.pc.hasBodypart("penis") && gm.pc.getBodypart("penis").id == "humanpenis", "penis is humanpenis " + context, "humanpenis",
		gm.pc.getBodypart("penis").id if gm.pc.hasBodypart("penis") else "none")
	check(!gm.pc.hasBodypart("vagina"), "no vagina " + context, false, gm.pc.hasBodypart("vagina"))
	check(gm.pc.hasBodypart("breasts") && gm.pc.getBodypart("breasts").id == "malebreasts", "breasts slot is malebreasts " + context, "malebreasts",
		gm.pc.getBodypart("breasts").id if gm.pc.hasBodypart("breasts") else "none")
	if(expectLongHair):
		check(gm.pc.hasBodypart("hair") && gm.pc.getBodypart("hair").id == "longhair", "hair is longhair " + context, "longhair",
			gm.pc.getBodypart("hair").id if gm.pc.hasBodypart("hair") else "none")
		check(equippedItemIDs() == sortedArray(STARTER_ITEMS_MALE), "starter outfit is T-shirt/shorts and briefs only " + context, sortedArray(STARTER_ITEMS_MALE), equippedItemIDs())


func checkHumanDormPlayer(context:String):
	var gm = getNode("GM")
	var policy = load(POLICY_PATH).new()
	check(gm.pc.getSpecies() == ["human"], "player is human " + context, ["human"], gm.pc.getSpecies())
	check(policy.getViolations(gm.pc).empty(), "player has no non-human or disallowed parts/skins " + context, [], policy.getViolations(gm.pc))
	var partIDs:Array = []
	for slot in gm.pc.getBodyparts().keys():
		if(gm.pc.getBodypart(slot) != null):
			partIDs.append(gm.pc.getBodypart(slot).id)
	var nonHuman:Array = []
	for partID in partIDs:
		if(partID in NON_HUMAN_BODYPART_IDS):
			nonHuman.append(partID)
	check(nonHuman.empty() && !gm.pc.hasBodypart("tail") && !gm.pc.hasBodypart("horns"), "no tail, horns or known non-human parts " + context, [], nonHuman)
	check(gm.pc.getLocation() == DORM_ROOM_ID, "player is in the private dorm " + context, DORM_ROOM_ID, gm.pc.getLocation())
	var prisonItems:Array = []
	for itemID in equippedItemIDs():
		if(itemID in PRISON_ITEM_IDS):
			prisonItems.append(itemID)
	check(prisonItems.empty() && !gm.pc.getInventory().hasRemovableRestraints(), "no prison clothing, collar, cuffs or restraints " + context, [], prisonItems)
	var profile:Dictionary = gm.main.university.getSystemData(PROFILE_SYSTEM_ID)
	check(sortedJSON(profile) == sortedJSON(completedProfile()), "student profile is complete (adult first-year, private dorm, university route) " + context,
		completedProfile(), profile)


func phaseUniversityRoute():
	var gm = getNode("GM")
	var registry = getNode("GlobalRegistry")
	var save = getNode("SAVE")
	var policy = load(POLICY_PATH).new()

	beginPhase("Phase 4a: New Game enters the University route")
	check(currentSceneID() == UNIVERSITY_NEW_GAME_SCENE, "New Game starts the University new-game scene", UNIVERSITY_NEW_GAME_SCENE, currentSceneID())
	if(!lastCheckPassed):
		abortRun("the University route did not start")
		return
	var stackIDs:Array = sceneIDsOf(gm.main.sceneStack)
	var legacyScenes:Array = []
	for sceneID in stackIDs:
		if(sceneID in LEGACY_PRISON_SCENES):
			legacyScenes.append(sceneID)
	check(legacyScenes.empty(), "no prison intro scene is running", [], stackIDs)
	check(gm.pc.getLocation() == DORM_ROOM_ID && gm.pc.getLocation() != LEGACY_PRISON_CELL, "starting location is the private dorm, not the prison cell", DORM_ROOM_ID, gm.pc.getLocation())
	check(gm.pc.getSpecies() == ["human"], "player is human from the first screen", ["human"], gm.pc.getSpecies())
	check(sortedJSON(gm.main.university.getSystemData(PROFILE_SYSTEM_ID)) == sortedJSON(profileWith("onboarding_completed", false)),
		"student profile starts with the onboarding contract (not completed)", profileWith("onboarding_completed", false), gm.main.university.getSystemData(PROFILE_SYSTEM_ID))
	check(!gm.QS.isActive("EscapeQuest") && !gm.QS.getAllQuests().has("EscapeQuest") && !gm.QS.getAllQuests().has("WorkInMinesQuest"),
		"prison quests are not active or listed", "hidden", gm.QS.getAllQuests().keys())

	beginPhase("Phase 4b: name")
	check("askforname" in buttonMethods(), "welcome screen offers Continue to naming", "askforname", buttonMethods())
	pick("askforname")
	var nameBox = gm.ui.getCustomControl("player_name")
	check(nameBox != null, "name text box is shown", "player_name text box", nameBox)
	if(nameBox == null):
		abortRun("name text box missing")
		return
	check("randomname" in buttonMethods() && "setname" in buttonMethods(), "name screen offers Confirm and Random", ["setname", "randomname"], buttonMethods())
	nameBox.text = ROUTE_PLAYER_NAME
	pick("setname")
	check(gm.pc.getName() == ROUTE_PLAYER_NAME, "typed name is applied", ROUTE_PLAYER_NAME, gm.pc.getName())
	check(currentSceneID() == UNIVERSITY_CREATOR_SCENE, "confirming the name opens the University creator", UNIVERSITY_CREATOR_SCENE, currentSceneID())
	if(!lastCheckPassed):
		abortRun("University creator did not open")
		return

	beginPhase("Phase 4c: gender and pronouns")
	var genderArgs:Array = buttonArgsFor("setgender")
	check(genderArgs.size() == 4, "four gender choices are offered", 4, genderArgs.size())
	pick("setgender", [Gender.Male])
	check(gm.pc.getGender() == Gender.Male, "gender is applied", Gender.Male, gm.pc.getGender())
	check(buttonArgsFor("setpronouns").size() == 5, "pronoun choices are offered", 5, buttonArgsFor("setpronouns").size())
	pick("setpronouns", [Gender.Male])

	beginPhase("Phase 4c2: male default anatomy (before any customisation)")
	var defaultPolicy = load(POLICY_PATH).new()
	check(gm.pc.getSpecies() == ["human"], "default species is exactly human", ["human"], gm.pc.getSpecies())
	checkMaleStudent("by default", false)
	var defaultProblems:Array = []
	for slot in ["head", "ears", "body", "arms", "legs"]:
		if(!gm.pc.hasBodypart(slot) || !defaultPolicy.isBodypartAllowed(slot, gm.pc.getBodypart(slot).id)):
			defaultProblems.append(str(slot) + "=" + (gm.pc.getBodypart(slot).id if gm.pc.hasBodypart(slot) else "none"))
	check(defaultProblems.empty(), "default head, ears, body, arms and legs are allowed human parts", [], defaultProblems)
	check(!gm.pc.hasBodypart("tail") && !gm.pc.hasBodypart("horns"), "no default tail or horns", false, gm.pc.hasBodypart("tail") || gm.pc.hasBodypart("horns"))
	check(defaultPolicy.getViolations(gm.pc).empty(), "default male body has no policy violations", [], defaultPolicy.getViolations(gm.pc))
	info("male defaults: " + str(bodypartSummary()))

	beginPhase("Phase 4d: human-only appearance")
	var methods:Array = buttonMethods()
	var speciesMethods:Array = []
	for method in ["setspecies", "pickspecies", "pickhybrid1", "pick2species"]:
		if(method in methods):
			speciesMethods.append(method)
	check(speciesMethods.empty(), "no species or hybrid actions are offered", [], speciesMethods)
	check(textsContainingAny(SPECIES_WORDS).empty(), "no button mentions species, hybrids, anthro or fur", [], textsContainingAny(SPECIES_WORDS))
	check("donecreating" in methods, "appearance screen offers Confirm", "donecreating", methods)
	var offeredSlots:Array = []
	for args in buttonArgsFor("pickbodypart"):
		offeredSlots.append(args[0])
	check(offeredSlots == policy.getOfferedSlots() && !("tail" in offeredSlots) && !("horns" in offeredSlots),
		"only human bodypart slots are offered (no tail or horns)", policy.getOfferedSlots(), offeredSlots)
	checkHumanPartsNow("after choosing gender")

	var offeredParts:Array = []
	var badOffers:Array = []
	for slot in offeredSlots:
		pick("pickbodypart", [slot])
		for args in buttonArgsFor("setbodypart"):
			offeredParts.append(args[0])
			if(!policy.isBodypartAllowed(slot, args[0]) || args[0] in NON_HUMAN_BODYPART_IDS):
				badOffers.append(str(slot) + ":" + str(args[0]))
		if(!textsContainingAny(SPECIES_WORDS).empty()):
			badOffers.append(str(slot) + " labels " + str(textsContainingAny(SPECIES_WORDS)))
		pick("pickedspecies")
	check(badOffers.empty() && offeredParts.size() > 0, "every offered bodypart is on the human allowlist, with neutral labels", [], badOffers)
	info("offered bodypart choices: " + str(offeredParts.size()))

	var registryProblems:Array = []
	for slot in policy.getOfferedSlots():
		for partID in policy.getAllowedBodypartIDs(slot):
			var compat:Array = registry.getBodypartRef(partID).getCompatibleSpeciesFinal()
			if(!("human" in compat || "any" in compat || "anynpc" in compat)):
				registryProblems.append(partID)
	check(registryProblems.empty(), "allowlisted parts are registered as human-compatible", [], registryProblems)

	# A valid customisation works.
	pick("pickbodypart", ["hair"])
	pick("setbodypart", ["longhair"])
	check(gm.pc.getBodypart("hair").id == "longhair", "an allowed hairstyle can be chosen", "longhair", gm.pc.getBodypart("hair").id)
	pick("pickedspecies")

	beginPhase("Phase 4e: non-human attempts are refused or normalised")
	pick("setspecies", [["canine"]])
	check(gm.pc.getSpecies() == ["human"], "setspecies(canine) keeps the player human", ["human"], gm.pc.getSpecies())
	check(gm.pc.getBodypart("hair").id == "longhair", "a refused species change keeps the chosen hairstyle", "longhair", gm.pc.getBodypart("hair").id)
	checkHumanPartsNow("after setspecies(canine)")
	pick("pickspecies")
	check(currentSceneID() == UNIVERSITY_CREATOR_SCENE && !("setspecies" in buttonMethods()), "the species screen can't be reached", "no species buttons", buttonMethods())
	pick("pickbodypart", ["legs"])
	pick("setbodypart", ["digilegs"])
	check(gm.pc.getBodypart("legs").id == "plantilegs", "digitigrade legs are refused", "plantilegs", gm.pc.getBodypart("legs").id)
	pick("pickbodypart", ["penis"])
	pick("setbodypart", ["caninepenis"])
	check(gm.pc.hasBodypart("penis") && gm.pc.getBodypart("penis").id == "humanpenis", "non-human genitals are refused (humanpenis kept)", "humanpenis", gm.pc.getBodypart("penis").id if gm.pc.hasBodypart("penis") else "none")
	pick("pickbodypart", ["tail"])
	pick("setbodypart", ["felinetail"])
	check(!gm.pc.hasBodypart("tail"), "tails can't be added", false, gm.pc.hasBodypart("tail"))
	pick("pickedspecies")
	checkHumanPartsNow("after refused attempts")

	beginPhase("Phase 4f: skin and colours")
	pick("bodyAttributes")
	check("startskinmenu" in buttonMethods(), "body attributes offer Skin/Colors", "startskinmenu", buttonMethods())
	pick("startskinmenu")
	check(currentSceneID() == UNIVERSITY_SKIN_SCENE, "Skin/Colors opens the University skin editor", UNIVERSITY_SKIN_SCENE, currentSceneID())
	pick("basemenu")
	check(!("dorandomcolorsall" in buttonMethods()) && "dorandomcolors" in buttonMethods(), "colour randomising is offered, skin+part randomising isn't", "dorandomcolors only", buttonMethods())
	pick("changebaseskinmenu")
	var offeredSkins:Array = []
	for args in buttonArgsFor("changebaseskinmenu_select"):
		offeredSkins.append(args[0])
	offeredSkins.sort()
	check(offeredSkins == ["EmptySkin", "HumanSkin"], "only plain human skins are offered", ["EmptySkin", "HumanSkin"], offeredSkins)
	pick("changebaseskinmenu_select", ["StripesSkin"])
	check(policy.isSkinAllowed(gm.pc.pickedSkin), "a fur-pattern skin is refused", "allowed skin", gm.pc.pickedSkin)
	pick("changebaseskinmenu_select", ["HumanSkin"])
	check(gm.pc.pickedSkin == "HumanSkin", "an allowed skin can be chosen", "HumanSkin", gm.pc.pickedSkin)
	pick("dorandomcolorsall")
	check(policy.isSkinAllowed(gm.pc.pickedSkin) && policy.getViolations(gm.pc).empty(), "a forced 'randomize all' still leaves a compliant player", [], policy.getViolations(gm.pc))
	pick("endthescene")
	check(currentSceneID() == UNIVERSITY_CREATOR_SCENE, "closing the skin editor returns to the creator", UNIVERSITY_CREATOR_SCENE, currentSceneID())
	pick("pickedspecies")

	beginPhase("Phase 4g: finish creation and move in")
	pick("donecreating")
	check(currentSceneID() == UNIVERSITY_NEW_GAME_SCENE && gm.main.getCurrentScene().state == "movein", "confirming the character leads to move-in", "movein", gm.main.getCurrentScene().state)
	check(equippedItemIDs() == sortedArray(STARTER_ITEMS_MALE), "the fixed starter outfit is equipped (briefs, no panties, no bra)", sortedArray(STARTER_ITEMS_MALE), equippedItemIDs())
	check(gm.main.getFlag("Game_PickedStartingPerks", false) == true, "BDCC starting-perk prompt is skipped", true, gm.main.getFlag("Game_PickedStartingPerks", false))
	check("finish" in buttonMethods(), "move-in screen offers to start the first day", "finish", buttonMethods())
	pick("finish")
	var finalStack:Array = sceneIDsOf(gm.main.sceneStack)
	check(finalStack == ["WorldScene"], "the player ends in the normal world interface", ["WorldScene"], finalStack)
	checkHumanDormPlayer("after onboarding")
	checkMaleStudent("after onboarding")

	var room = gm.world.getRoomByID(DORM_ROOM_ID)
	check(room != null && room.getName() == DORM_ROOM_NAME && room.floorID == DORM_FLOOR_ID, "private dorm room is registered and resolves", DORM_ROOM_NAME + " on " + DORM_FLOOR_ID, (room.getName() + " on " + room.floorID) if room != null else null)
	if(room != null):
		var roomText:String = (room.getName() + " " + room.getDescription()).to_lower()
		var prisonWords:Array = []
		for word in PRISON_WORDS:
			if(roomText.find(word) >= 0):
				prisonWords.append(word)
		check(prisonWords.empty(), "dorm name and description use no prison terms", [], prisonWords)
		check(room.population == 0 && !room.canNorth && !room.canSouth && !room.canEast && !room.canWest, "dorm is private: no NPC population, no exits yet", "isolated", room.population)
	check(save.canSave(), "saving is allowed in the dorm", true, save.canSave())
	check(!gm.QS.isActive("EscapeQuest") && !gm.QS.isActive("WorkInMinesQuest") && gm.QS.getAllQuests().empty(), "no quests are active or listed after onboarding", {}, gm.QS.getAllQuests().keys())
	nextStep(5)


func bodypartSummary() -> Dictionary:
	var gm = getNode("GM")
	var result:Dictionary = {}
	for slot in gm.pc.getBodyparts().keys():
		result[slot] = gm.pc.getBodypart(slot).id if gm.pc.getBodypart(slot) != null else "none"
	return result


func checkHumanPartsNow(context:String):
	var gm = getNode("GM")
	var policy = load(POLICY_PATH).new()
	check(gm.pc.getSpecies() == ["human"] && policy.getViolations(gm.pc).empty(), "player stays human and compliant " + context, [], policy.getViolations(gm.pc))


func phaseNewGameAndSave():
	var gm = getNode("GM")
	var save = getNode("SAVE")
	var registry = getNode("GlobalRegistry")

	beginPhase("Phase 4: new-game startup")
	check(gm.pc != null, "player exists", "GM.pc", gm.pc)
	check(gm.main != null && gm.main.filename == MAIN_GAME_SCENE, "main game state exists", MAIN_GAME_SCENE, gm.main.filename if gm.main != null else null)
	check(gm.main.sceneStack.size() > 0, "active scene stack is not empty", "> 0", gm.main.sceneStack.size())
	var currentScene = gm.main.getCurrentScene()
	var currentSceneID:String = currentScene.sceneID if currentScene != null else ""
	check(currentSceneID != "" && currentSceneID != "UNREGISTERED_SCENE" && registry.scenes.has(currentSceneID),
		"current starting scene is a registered scene", "registered scene id", currentSceneID)
	var startLocation = gm.pc.getLocation()
	check(startLocation is String && !startLocation.empty() && gm.world != null && gm.world.hasRoomID(startLocation),
		"player has a valid starting location (room exists in the world)", "existing room id", startLocation)
	info("scene after onboarding = " + currentSceneID + ", state = '" + currentScene.state + "'")
	info("location after onboarding = " + str(startLocation))
	info("scene stack = " + str(sceneIDsOf(gm.main.sceneStack)))

	beginPhase("Phase 5a: save")
	gm.pc.setName(TEST_PLAYER_NAME)
	gm.pc.addCredits(CREDITS_DELTA)
	check(gm.main.get("university") != null, "live University Sandbox data exists for the new game", "GM.main.university", gm.main.get("university"))
	# T4: a new game now starts with exactly one University system, the student profile
	# (replaces T3's "empty systems" baseline assertion).
	check(gm.main.university.saveData()["systems"].keys() == [PROFILE_SYSTEM_ID], "new game's University systems contain only the student profile", [PROFILE_SYSTEM_ID], gm.main.university.saveData()["systems"].keys())
	recorded["equipped"] = equippedItemIDs()
	gm.main.university.setSystemData(PROBE_SYSTEM_ID, PROBE_DATA)
	recorded["university"] = sortedJSON(gm.main.university.saveData())
	recorded["name"] = gm.pc.getName()
	recorded["credits"] = gm.pc.getCredits()
	recorded["location"] = gm.pc.getLocation()
	recorded["day"] = gm.main.getDays()
	recorded["time"] = gm.main.getTime()
	recorded["sceneIDs"] = sceneIDsOf(gm.main.sceneStack)
	recorded["sceneState"] = currentScene.state
	recorded["sceneInstances"] = instanceIDsOf(gm.main.sceneStack)
	info("recorded name=" + str(recorded["name"]) + " credits=" + str(recorded["credits"]) + " day=" + str(recorded["day"]) + " time=" + str(recorded["time"]))

	var theFile := File.new()
	var savePathOnDisk:String = ProjectSettings.globalize_path(TEST_SAVE_PATH)
	info("test save = " + savePathOnDisk)
	check(isInsideTestRoot(savePathOnDisk), "test save path is inside the temporary test root", testRoot + "/...", savePathOnDisk)
	if(!lastCheckPassed):
		abortRun("refusing to write a save outside the test root")
		return
	check(!theFile.file_exists(TEST_SAVE_PATH), "no test save exists before saving (clean test root)", false, theFile.file_exists(TEST_SAVE_PATH))
	check(save.canSave(), "game reports that it can save", true, save.canSave())
	save.saveGame(TEST_SAVE_PATH)
	var saveExists:bool = theFile.file_exists(TEST_SAVE_PATH)
	check(saveExists, "test save file exists after saving", true, saveExists)
	if(saveExists && theFile.open(TEST_SAVE_PATH, File.READ) == OK):
		var saveSize:int = theFile.get_len()
		theFile.close()
		check(saveSize > 0, "test save file is not empty", "> 0 bytes", str(saveSize) + " bytes")
	if(!saveExists):
		abortRun("save file was not written")
		return
	var onDisk = readJSONFile(TEST_SAVE_PATH)
	check(onDisk is Dictionary, "test save is a JSON dictionary", "Dictionary", typeof(onDisk))
	if(onDisk is Dictionary):
		check(onDisk.get("game_id") == EXPECTED_GAME_ID, "save carries the University Sandbox game id", EXPECTED_GAME_ID, onDisk.get("game_id"))
		var section = onDisk.get("university")
		check(section is Dictionary, "save has a University data section", "Dictionary", typeof(section))
		if(section is Dictionary):
			check(section.get("schema_version") == EXPECTED_SCHEMA_VERSION, "save carries University schema version 1", EXPECTED_SCHEMA_VERSION, section.get("schema_version"))
			var systems = section.get("systems", {})
			var probe = systems.get(PROBE_SYSTEM_ID) if systems is Dictionary else null
			check(probe != null && sortedJSON(probe) == sortedJSON(PROBE_DATA), "save contains the University probe data", sortedJSON(PROBE_DATA), sortedJSON(probe))
			var savedProfile = systems.get(PROFILE_SYSTEM_ID) if systems is Dictionary else null
			check(savedProfile is Dictionary && sortedJSON(savedProfile) == sortedJSON(completedProfile()),
				"save contains the completed student profile", completedProfile(), savedProfile)
		var playerData = onDisk.get("player", {})
		check(playerData.get("pickedSpecies") == ["human"], "saved player species is human", ["human"], playerData.get("pickedSpecies"))
		check(playerData.get("location") == DORM_ROOM_ID, "saved player location is the private dorm", DORM_ROOM_ID, playerData.get("location"))

	beginPhase("Phase 5b: alter in-memory state")
	gm.pc.setName(MUTATED_PLAYER_NAME)
	gm.pc.addCredits(-1111)
	currentScene.state = MUTATED_SCENE_STATE
	gm.main.university.setSystemData(PROBE_SYSTEM_ID, {"marker": "mutated"})
	check(sortedJSON(gm.main.university.saveData()) != recorded["university"], "in-memory University data changed before load", "!= saved", sortedJSON(gm.main.university.saveData()))
	check(gm.pc.getName() == MUTATED_PLAYER_NAME, "in-memory name changed before load", MUTATED_PLAYER_NAME, gm.pc.getName())
	check(gm.pc.getCredits() != recorded["credits"], "in-memory credits changed before load", "!= " + str(recorded["credits"]), gm.pc.getCredits())
	check(currentScene.state == MUTATED_SCENE_STATE, "in-memory scene state changed before load", MUTATED_SCENE_STATE, currentScene.state)
	nextStep(6)


func phaseLoad():
	beginPhase("Phase 5c: load through SaveManager")
	var save = getNode("SAVE")
	var loaded:bool = save.tryLoadGame(TEST_SAVE_PATH)
	check(loaded, "SAVE.tryLoadGame accepts the University Sandbox save", true, loaded)
	check(save.getLastLoadError() == "", "no load error is recorded", "", save.getLastLoadError())
	nextStep(7)


func phaseVerifyRoundTrip():
	var gm = getNode("GM")
	var save = getNode("SAVE")
	beginPhase("Phase 5d: verify restored state")
	check(save.getLoadedSavefileVersion() == save.getCurrentSavefileVersion(), "loaded save version matches the current save version",
		save.getCurrentSavefileVersion(), save.getLoadedSavefileVersion())
	check(gm.pc.getName() == recorded["name"], "player name restored", recorded["name"], gm.pc.getName())
	check(gm.pc.getCredits() == recorded["credits"], "player credits restored", recorded["credits"], gm.pc.getCredits())
	check(gm.pc.getLocation() == recorded["location"], "player location restored", recorded["location"], gm.pc.getLocation())
	check(gm.main.getDays() == recorded["day"], "game day restored", recorded["day"], gm.main.getDays())
	check(gm.main.getTime() == recorded["time"], "time of day restored", recorded["time"], gm.main.getTime())
	var stack:Array = gm.main.sceneStack
	check(sceneIDsOf(stack) == recorded["sceneIDs"], "scene stack restored (same scene ids, same order)", recorded["sceneIDs"], sceneIDsOf(stack))
	var restoredScene = gm.main.getCurrentScene()
	var restoredState = restoredScene.state if restoredScene != null else null
	check(restoredState == recorded["sceneState"], "current scene state restored from the save", "'" + str(recorded["sceneState"]) + "'", "'" + str(restoredState) + "'")
	var oldInstances:Array = recorded["sceneInstances"]
	var anyReused:bool = false
	for instanceID in instanceIDsOf(stack):
		if(oldInstances.has(instanceID)):
			anyReused = true
	check(!anyReused && stack.size() > 0, "scene objects were rebuilt by the load (real save/load path)", "new scene instances", instanceIDsOf(stack))
	check(sortedJSON(gm.main.university.saveData()) == recorded["university"], "University data restored from the save", recorded["university"], sortedJSON(gm.main.university.saveData()))
	check(sortedJSON(gm.main.university.getSystemData(PROBE_SYSTEM_ID)) == sortedJSON(PROBE_DATA), "University probe system data restored", sortedJSON(PROBE_DATA), sortedJSON(gm.main.university.getSystemData(PROBE_SYSTEM_ID)))
	checkHumanDormPlayer("after load")
	checkMaleStudent("after load")
	check(equippedItemIDs() == recorded["equipped"], "starter outfit restored by the load", recorded["equipped"], equippedItemIDs())
	nextStep(8)


# ---------------------------------------------------------------- phase 6 + 7

# Each case: [id, expected error fragment, how to build the file]
func rejectionCases() -> Array:
	return [
		["foreign_game_id", "belongs to another game", {"set": {"game_id": "bdcc"}}],
		["non_text_game_id", "belongs to another game", {"set": {"game_id": 42}}],
		["missing_game_id", "Not a University Sandbox save", {"erase": ["game_id"]}],
		["future_savefile_version", "savefile is not supported", {"set": {"savefile_version": 99}}],
		["missing_savefile_version", "valid version", {"erase": ["savefile_version"]}],
		["missing_player", "missing player data", {"erase": ["player"]}],
		["malformed_main", "missing main game data", {"set": {"main": "not a dictionary"}}],
		["missing_university_section", "missing its University Sandbox data section", {"erase": ["university"]}],
		["malformed_university_section", "University save data is malformed", {"set": {"university": "garbage"}}],
		["missing_schema_version", "has no schema version", {"section_erase": ["schema_version"]}],
		["malformed_schema_version", "schema version is malformed", {"section_set": {"schema_version": "one"}}],
		["boolean_schema_version", "schema version is malformed", {"section_set": {"schema_version": true}}],
		["fractional_schema_version", "schema version is malformed", {"section_set": {"schema_version": 1.5}}],
		["future_schema_version", "only supports up to version 1", {"section_set": {"schema_version": 999}}],
		["older_schema_version", "older than the oldest supported version", {"section_set": {"schema_version": 0}}],
		["missing_systems_table", "missing its systems table", {"section_erase": ["systems"]}],
		["malformed_systems_table", "systems table is malformed", {"section_set": {"systems": [1, 2, 3]}}],
		["malformed_system_entry", "data is malformed", {"section_set": {"systems": {"harness_probe": "not a dictionary"}}}],
		["profile_malformed", "'student_profile' data is malformed", {"section_set": {"systems": {"student_profile": ["not", "a", "dictionary"]}}}],
		["profile_bad_onboarding_flag", "malformed onboarding flag", {"section_set": {"systems": {"student_profile": profileWith("onboarding_completed", "yes")}}}],
		["profile_zero_student_year", "malformed student year", {"section_set": {"systems": {"student_profile": profileWith("student_year", 0)}}}],
		["profile_fractional_student_year", "malformed student year", {"section_set": {"systems": {"student_profile": profileWith("student_year", 1.5)}}}],
		["profile_text_student_year", "malformed student year", {"section_set": {"systems": {"student_profile": profileWith("student_year", "1")}}}],
		["profile_unsupported_housing", "unsupported housing", {"section_set": {"systems": {"student_profile": profileWith("housing_id", "cellblock_orange_playercell")}}}],
		["profile_missing_housing", "unsupported housing", {"section_set": {"systems": {"student_profile": profileWith("housing_id", "__erase__")}}}],
		["profile_old_route_value", "unknown route", {"section_set": {"systems": {"student_profile": profileWith("route", "university_sandbox")}}}],
		["profile_not_adult", "not marked as an adult", {"section_set": {"systems": {"student_profile": profileWith("is_adult", false)}}}],
		["profile_malformed_adult", "malformed adult flag", {"section_set": {"systems": {"student_profile": profileWith("is_adult", "true")}}}],
		["profile_missing_adult", "malformed adult flag", {"section_set": {"systems": {"student_profile": profileWith("is_adult", "__erase__")}}}],
		["not_json", "not valid JSON", {"raw": "{ this is not json"}],
		["json_array", "unexpected file structure", {"raw": "[1, 2, 3]"}],
		["missing_file", "not found", {"missing": true}],
	]


func buildRejectionFile(thePath:String, validSave:Dictionary, recipe:Dictionary) -> bool:
	if(recipe.has("missing")):
		return true
	if(recipe.has("raw")):
		return writeTextFile(thePath, recipe["raw"])
	var data:Dictionary = validSave.duplicate(true)
	for key in recipe.get("erase", []):
		var _had = data.erase(key)
	for key in recipe.get("set", {}).keys():
		data[key] = recipe["set"][key]
	for key in recipe.get("section_erase", []):
		var _hadInSection = data["university"].erase(key)
	for key in recipe.get("section_set", {}).keys():
		data["university"][key] = recipe["section_set"][key]
	return writeTextFile(thePath, JSON.print(data, "\t"))


func phaseRejections():
	var gm = getNode("GM")
	var save = getNode("SAVE")
	var theFile := File.new()
	beginPhase("Phase 6: invalid saves are rejected without touching live state")

	var validSave = readJSONFile(TEST_SAVE_PATH)
	if(!(validSave is Dictionary)):
		abortRun("could not read the valid test save to build rejection cases")
		return
	# Make live state differ from every file, so any partial load would be visible.
	gm.pc.setName(LIVE_NAME_BEFORE_REJECTS)
	gm.pc.addCredits(7)
	gm.main.university.setSystemData(PROBE_SYSTEM_ID, {"marker": "live-before-rejects"})

	for testCase in rejectionCases():
		var caseID:String = testCase[0]
		var expectedError:String = testCase[1]
		var recipe:Dictionary = testCase[2]
		var thePath:String = REJECT_SAVE_PREFIX + caseID + ".save"
		var onDisk:String = ProjectSettings.globalize_path(thePath)
		if(!isInsideTestRoot(onDisk)):
			check(false, caseID + ": fixture path is inside the temporary test root", testRoot + "/...", onDisk)
			abortRun("refusing to write a fixture outside the test root")
			return
		if(!buildRejectionFile(thePath, validSave, recipe)):
			check(false, caseID + ": fixture file can be written", "written", thePath)
			continue
		var isMissing:bool = recipe.has("missing")
		var md5Before:String = "" if isMissing else theFile.get_md5(thePath)

		var before:String = liveStateFingerprint()
		var loaded:bool = save.tryLoadGame(thePath)
		var after:String = liveStateFingerprint()
		var theError:String = save.getLastLoadError()

		check(!loaded, caseID + ": load is refused", false, loaded)
		check(theError.find(expectedError) >= 0, caseID + ": error explains why", "contains '" + expectedError + "'", theError)
		check(after == before, caseID + ": live game state is unchanged", before, after)
		if(isMissing):
			check(!theFile.file_exists(thePath), caseID + ": no file was created", false, theFile.file_exists(thePath))
		else:
			check(theFile.file_exists(thePath) && theFile.get_md5(thePath) == md5Before, caseID + ": file is left exactly as it was", md5Before, theFile.get_md5(thePath))
			var summary = save.loadGameInformationFromSaveRaw(thePath)
			check(summary == null || (summary is Dictionary && summary.get("error", "") != ""), caseID + ": save list marks it as not loadable",
				"null or {error: ...}", summary)

	var latest:String = save.getLatestLoadableSavePath()
	check(latest == TEST_SAVE_PATH, "resume picks the valid save and skips invalid ones", TEST_SAVE_PATH, latest)
	check(save.canResumeGame(), "resume is still offered while a valid save exists", true, save.canResumeGame())

	beginPhase("Phase 6b: T3-era save without a student profile stays valid")
	var t3Era:Dictionary = validSave.duplicate(true)
	var _hadProfile = t3Era["university"]["systems"].erase(PROFILE_SYSTEM_ID)
	var t3EraOnDisk:String = ProjectSettings.globalize_path(T3_ERA_FIXTURE_PATH)
	check(isInsideTestRoot(t3EraOnDisk) && writeTextFile(T3_ERA_FIXTURE_PATH, JSON.print(t3Era, "\t")), "T3-era fixture is written inside the test root", testRoot + "/...", t3EraOnDisk)
	check(save.validateSaveData(t3Era)["ok"], "a save without student_profile passes validation", true, save.validateSaveData(t3Era)["error"])
	var t3Loaded:bool = save.tryLoadGame(T3_ERA_FIXTURE_PATH)
	check(t3Loaded && save.getLastLoadError() == "", "a save without student_profile loads", true, save.getLastLoadError())
	check(!gm.main.university.hasSystemData(PROFILE_SYSTEM_ID) && gm.main.university.hasSystemData(PROBE_SYSTEM_ID),
		"it loads with its other University data and no profile", "probe only", gm.main.university.saveData()["systems"].keys())
	check(gm.QS.getAllQuests().has("EscapeQuest"), "without a profile the game isn't treated as University-route (legacy quests listed)", true, gm.QS.getAllQuests().has("EscapeQuest"))

	# Main-menu load path: must refuse before leaving the current scene.
	recorded["sceneBeforeMenuLoad"] = current_scene.get_instance_id()
	recorded["mainBeforeMenuLoad"] = gm.main.get_instance_id()
	recorded["fingerprintBeforeMenuLoad"] = liveStateFingerprint()
	var _state = save.switchToGameAndLoad(REJECT_SAVE_PREFIX + "foreign_game_id.save")
	nextStep(9)


func phaseMenuLoadRefusalAndFinalLoad():
	var gm = getNode("GM")
	var save = getNode("SAVE")
	check(current_scene.get_instance_id() == recorded["sceneBeforeMenuLoad"] && gm.main.get_instance_id() == recorded["mainBeforeMenuLoad"],
		"switchToGameAndLoad refuses a foreign save without switching scenes", "same scene", "scene changed" if current_scene.get_instance_id() != recorded["sceneBeforeMenuLoad"] else "same scene")
	check(liveStateFingerprint() == recorded["fingerprintBeforeMenuLoad"], "refused menu load leaves live state unchanged", recorded["fingerprintBeforeMenuLoad"], liveStateFingerprint())
	check(save.getLastLoadError().find("belongs to another game") >= 0, "refused menu load records the reason", "belongs to another game", save.getLastLoadError())

	beginPhase("Phase 7: a valid save still loads after rejections")
	gm.pc.setName(NAME_BEFORE_FINAL_LOAD)
	var loaded:bool = save.tryLoadGame(TEST_SAVE_PATH)
	check(loaded, "valid save loads after the rejection cases", true, loaded)
	check(save.getLastLoadError() == "", "load error is cleared after a successful load", "", save.getLastLoadError())
	nextStep(10)


func phaseVerifyFinalLoad():
	var gm = getNode("GM")
	check(gm.pc.getName() == recorded["name"], "player name restored by the final load", recorded["name"], gm.pc.getName())
	check(gm.pc.getCredits() == recorded["credits"], "player credits restored by the final load", recorded["credits"], gm.pc.getCredits())
	check(sortedJSON(gm.main.university.saveData()) == recorded["university"], "University data restored by the final load", recorded["university"], sortedJSON(gm.main.university.saveData()))
	check(sceneIDsOf(gm.main.sceneStack) == recorded["sceneIDs"], "scene stack restored by the final load", recorded["sceneIDs"], sceneIDsOf(gm.main.sceneStack))
	checkHumanDormPlayer("after the final load")
	checkMaleStudent("after the final load")
	finishRun()
