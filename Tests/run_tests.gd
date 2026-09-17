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

const EXPECTED_DISPLAY_NAME := "University Sandbox"
const EXPECTED_USER_DIR_NAME := "university_sandbox"
const TEST_SAVE_PATH := "user://saves/us_harness_roundtrip.save"
const TEST_PLAYER_NAME := "HarnessTester_RoundTrip"
const MUTATED_PLAYER_NAME := "HarnessTester_Mutated"
const CREDITS_DELTA := 4242
const MUTATED_SCENE_STATE := "__harness_mutated_state__"

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
			phaseNewGameAndSave()
	elif(step == 5):
		if(frames >= 2):
			phaseLoad()
	elif(step == 6):
		if(frames >= SETTLE_FRAMES):
			phaseVerifyRoundTrip()
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

	var theError:int = change_scene(MAIN_GAME_SCENE)
	check(theError == OK, "main game scene can be opened", OK, theError)
	if(!lastCheckPassed):
		abortRun("could not open " + MAIN_GAME_SCENE)
		return
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
	info("baseline starting scene = " + currentSceneID + ", state = '" + currentScene.state + "'")
	info("baseline starting location = " + str(startLocation))
	info("scene stack = " + str(sceneIDsOf(gm.main.sceneStack)))

	beginPhase("Phase 5a: save")
	gm.pc.setName(TEST_PLAYER_NAME)
	gm.pc.addCredits(CREDITS_DELTA)
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

	beginPhase("Phase 5b: alter in-memory state")
	gm.pc.setName(MUTATED_PLAYER_NAME)
	gm.pc.addCredits(-1111)
	currentScene.state = MUTATED_SCENE_STATE
	check(gm.pc.getName() == MUTATED_PLAYER_NAME, "in-memory name changed before load", MUTATED_PLAYER_NAME, gm.pc.getName())
	check(gm.pc.getCredits() != recorded["credits"], "in-memory credits changed before load", "!= " + str(recorded["credits"]), gm.pc.getCredits())
	check(currentScene.state == MUTATED_SCENE_STATE, "in-memory scene state changed before load", MUTATED_SCENE_STATE, currentScene.state)
	nextStep(5)


func phaseLoad():
	beginPhase("Phase 5c: load through SaveManager")
	var save = getNode("SAVE")
	save.loadGame(TEST_SAVE_PATH)
	info("SAVE.loadGame(" + TEST_SAVE_PATH + ") returned")
	nextStep(6)


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
	finishRun()
