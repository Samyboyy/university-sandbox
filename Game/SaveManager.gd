extends Node

var currentSavefileVersion = 2
var maxBackupQuicksaves = 3

var loadedSavefileVersion = -1

var saveInfoCache:Dictionary = {}
const SAVE_INFO_CACHE_VERSION = 2 # 2: entries carry an "error" field (University Sandbox save validation)

# University Sandbox save identity and schema (see Docs/SAVE_SCHEMA.md)
const UniversitySaveSchema = preload("res://Game/University/UniversitySaveSchema.gd")
var universitySchema = UniversitySaveSchema.new()
var lastLoadError:String = ""

func _ready():
	loadSaveInfoCacheFromFile()

func saveData():
	var data = {
		"savefile_version": currentSavefileVersion,
		"currentUniqueID_DONT_TOUCH": GlobalRegistry.currentUniqueID,
		"currentChildUniqueID_DONT_TOUCH": GlobalRegistry.currentChildUniqueID,
		"currentNPCUniqueID_DONT_TOUCH": GlobalRegistry.currentNPCUniqueID,
		"currentTFID_DONT_TOUCH": GlobalRegistry.currentTFID,
		"currentSave": GlobalRegistry.currentSave,
	}
	data[UniversitySaveSchema.GAME_ID_KEY] = UniversitySaveSchema.GAME_ID
	data[UniversitySaveSchema.SECTION_KEY] = GM.main.university.saveData()
	
	data["player"] = GM.main.getOriginalPC().saveData()
	if(GM.main.getOverriddenPC() != null):
		data["player_override"] = GM.main.getOverriddenPC().saveData()
	
	data["characters"] = GM.main.saveCharactersData()
	data["dynamicCharacters"] = GM.main.saveDynamicCharactersData()
	
	data["main"] = GM.main.saveData()
	
	return data

# The single validation gate for a whole save. Reads only; never changes live state or `data`.
# Order: structure -> savefile_version -> game identity -> base sections -> University schema/migration.
# Returns {"ok": bool, "error": String, "university": Dictionary (validated and migrated)}.
func validateSaveData(data) -> Dictionary:
	if(!(data is Dictionary)):
		return makeValidationFailure("Not a save file (unexpected file structure)")
	if(!data.has("savefile_version") || !universitySchema.isWholeNumber(data["savefile_version"])):
		return makeValidationFailure("Save file doesn't have a valid version in it. It might not be a savefile")
	if(data["savefile_version"] > currentSavefileVersion):
		return makeValidationFailure("This savefile is not supported, sorry. Current supported version: "+str(currentSavefileVersion)+". Savefile version: "+str(data["savefile_version"]))
	if(!data.has(UniversitySaveSchema.GAME_ID_KEY)):
		return makeValidationFailure("Not a University Sandbox save (it has no game id, so it may be from BDCC or an older test build)")
	var gameID = data[UniversitySaveSchema.GAME_ID_KEY]
	if(!(gameID is String) || gameID != UniversitySaveSchema.GAME_ID):
		return makeValidationFailure("This save belongs to another game ('"+str(gameID)+"'), not University Sandbox")
	if(!data.has("player") || !(data["player"] is Dictionary)):
		return makeValidationFailure("Save is missing player data")
	if(!data.has("main") || !(data["main"] is Dictionary)):
		return makeValidationFailure("Save is missing main game data")
	if(!data.has(UniversitySaveSchema.SECTION_KEY)):
		return makeValidationFailure("Save is missing its University Sandbox data section")
	var university:Dictionary = universitySchema.validateAndMigrate(data[UniversitySaveSchema.SECTION_KEY])
	if(!university["ok"]):
		return makeValidationFailure(university["error"])
	for warningText in university["warnings"]:
		Log.warning("Warning: "+str(warningText))
	return {"ok": true, "error": "", "university": university["section"]}

func makeValidationFailure(message:String) -> Dictionary:
	return {"ok": false, "error": message, "university": {}}

func getLastLoadError() -> String:
	return lastLoadError

func rejectLoad(message:String):
	lastLoadError = message
	Log.printerr("Error: Save was not loaded: "+message)

func loadData(data: Dictionary):
	var _loaded = tryLoadData(data)

# Returns false (and changes nothing) if the save fails validation.
func tryLoadData(data) -> bool:
	var validation:Dictionary = validateSaveData(data)
	if(!validation["ok"]):
		rejectLoad(validation["error"])
		return false
	lastLoadError = ""
	
	loadedSavefileVersion = int(data["savefile_version"])
		
	GlobalRegistry.currentUniqueID = SAVE.loadVar(data, "currentUniqueID_DONT_TOUCH", 0)
	GlobalRegistry.currentChildUniqueID = SAVE.loadVar(data, "currentChildUniqueID_DONT_TOUCH", 0)
	GlobalRegistry.currentNPCUniqueID = SAVE.loadVar(data, "currentNPCUniqueID_DONT_TOUCH", 0)
	GlobalRegistry.currentTFID = SAVE.loadVar(data, "currentTFID_DONT_TOUCH", 0)
	GlobalRegistry.currentSave = SAVE.loadVar(data, "currentSave", 1)
	
	GM.main.getOriginalPC().loadData(data["player"])
	
	if(GM.main.getOverriddenPC() != null):
		GM.main.clearOverridePC()
	if(data.has("player_override") && data["player_override"] != null):
		GM.main.overridePC()
		GM.main.getOverriddenPC().loadData(data["player_override"])
	
	# I should do all of this inside GM.main.loadData()
	GM.main.loadDynamicCharactersData(SAVE.loadVar(data, "dynamicCharacters", {}))
	GM.main.loadData(SAVE.loadVar(data, "main", {}))
	GM.main.updateStaticCharacters()
	GM.main.loadCharactersData(SAVE.loadVar(data, "characters", {}))
	GM.main.university.loadData(validation["university"])
	
	# post loading refresh
	GM.main.loadingSavefileFinished()
	GM.ui.loadingSavefileFinished()
	return true
	
func canSave():
	return GM.main.canSave()
	
func saveGame(_path):
	if(!canSave()):
		Log.printerr("Can't save because one of the scenes doesn't support saving")
		return
	
	var saveData = saveData()
	var save_game = File.new()
	save_game.open(_path, File.WRITE)
	
	save_game.store_line(JSON.print(saveData, "\t", true))
	
	save_game.close()
	
	invalidateCachedSaveInfoByPath(_path)

const saveInfoCachePath = "user://saveInfoCache.json"

func loadSaveInfoCacheFromFile():
	var save_game = File.new()
	if !save_game.file_exists(saveInfoCachePath):
		return
	
	save_game.open(saveInfoCachePath, File.READ)
	var jsonResult = JSON.parse(save_game.get_as_text())
	if(jsonResult.error != OK):
		Log.printerr("Save info cache is not a valid json file")
		return
	
	var saveData:Dictionary = jsonResult.result
	if(!saveData.has("version") || !saveData.has("saves")):
		Log.printerr("Save info cache is not valid")
		return
	if(saveData["version"] != SAVE_INFO_CACHE_VERSION):
		Log.print("Save info cache version changed, it will be rebuilt")
		return
	if(!(saveData["saves"] is Dictionary)):
		Log.printerr("Save info cache is not valid")
		return
	saveInfoCache = saveData["saves"]

func saveInfoCacheToFile():
	var save_game = File.new()
	save_game.open(saveInfoCachePath, File.WRITE)
	save_game.store_line(JSON.print({
		version = SAVE_INFO_CACHE_VERSION,
		saves = saveInfoCache,
	}, "\t", true))
	save_game.close()
	isSavingCache = false
	#print("SAVED CACHE!")

var isSavingCache:bool = false
func triggerSaveCacheSave():
	if(isSavingCache):
		return
	isSavingCache = true # De-bouncing. Only save once at the end of the frame in case there are many requests
	call_deferred("saveInfoCacheToFile")

func invalidateCachedSaveInfoByPath(_path:String):
	if(saveInfoCache.has(_path)):
		saveInfoCache.erase(_path)
	triggerSaveCacheSave()

func saveGameFromText(filepath: String, savedatastring):
	var save_game = File.new()
	save_game.open("user://saves/"+filepath.get_file().get_basename()+".save", File.WRITE)
	save_game.store_line(savedatastring)
	save_game.close()
	
	invalidateCachedSaveInfoByPath(filepath)

func loadGameRelative(_name):
	loadGame("user://saves/"+_name+".save")
	
func saveGameRelative(_name):
	GlobalRegistry.currentSave += 1
	saveGame("user://saves/"+_name+".save")
	
# Reads and parses a save file without applying it. Never modifies the file.
# Returns {"ok": bool, "error": String, "data": parsed JSON or null}.
func readSaveFile(_path) -> Dictionary:
	var save_game = File.new()
	if(!save_game.file_exists(_path)):
		return {"ok": false, "error": "Save file is not found in "+str(_path), "data": null}
	if(save_game.open(_path, File.READ) != OK):
		return {"ok": false, "error": "Save file can't be opened: "+str(_path), "data": null}
	var text:String = save_game.get_as_text()
	save_game.close()
	var jsonResult = JSON.parse(text)
	if(jsonResult.error != OK):
		return {"ok": false, "error": "Save file is not valid JSON: "+str(_path), "data": null}
	return {"ok": true, "error": "", "data": jsonResult.result}

# Read + validate without applying anything. "data" is null when the file couldn't be parsed.
func inspectSaveFile(_path) -> Dictionary:
	var readResult:Dictionary = readSaveFile(_path)
	if(!readResult["ok"]):
		return {"ok": false, "error": readResult["error"], "data": null}
	var validation:Dictionary = validateSaveData(readResult["data"])
	return {"ok": validation["ok"], "error": validation["error"], "data": readResult["data"]}

func loadGame(_path):
	var _loaded = tryLoadGame(_path)

# Returns false (and changes nothing in the running game) if the file can't be read or fails validation.
func tryLoadGame(_path) -> bool:
	var readResult:Dictionary = readSaveFile(_path)
	if(!readResult["ok"]):
		rejectLoad(readResult["error"])
		return false
	return tryLoadData(readResult["data"])

func switchToGameAndLoad(_path):
	# Validate before leaving the menu: MainScene starts a fresh game when it opens.
	var inspection:Dictionary = inspectSaveFile(_path)
	if(!inspection["ok"]):
		rejectLoad(inspection["error"])
		return
	var _ok = get_tree().change_scene("res://Game/MainScene.tscn")
	yield(get_tree(),"idle_frame")
	call_deferred("loadGameAfterSceneSwitch", _path)

func switchToGameAndResumeLatestSave():
	var latestSave:String = getLatestLoadableSavePath()
	if(latestSave == ""):
		return
	var _ok = get_tree().change_scene("res://Game/MainScene.tscn")
	yield(get_tree(),"idle_frame")
	call_deferred("loadGameAfterSceneSwitch", latestSave)

func loadGameAfterSceneSwitch(_path):
	if(!tryLoadGame(_path)):
		# The file changed or broke after it was checked. Don't leave the player in the fresh game silently.
		var _ok = get_tree().change_scene("res://UI/MainMenu/MainMenu.tscn")

func getLoadedSavefileVersion():
	return loadedSavefileVersion
	
func getCurrentSavefileVersion():
	return currentSavefileVersion

func isUpdatingFromSaveVersion(oldSaveVersion: int):
	if(loadedSavefileVersion < 0):
		return false

	if(currentSavefileVersion <= oldSaveVersion):
		return false
		
	if(oldSaveVersion >= loadedSavefileVersion):
		return true

	return false

func loadVar(data, key, nullvalue = null):
	if(!(data is Dictionary)):
		Log.printerr("Warning: Loaded key "+key+" is not a dictionary. Using "+str(nullvalue)+" as default value. "+Util.getStackFunction())
		return nullvalue
	
	if(!data.has(key)):
		Log.warning("Warning: Save doesn't have key "+key+". Using "+str(nullvalue)+" as default value. "+Util.getStackFunction())
		return nullvalue
		
	if(nullvalue != null && typeof(data[key]) != typeof(nullvalue) && !(typeof(data[key]) == TYPE_REAL && typeof(nullvalue) == TYPE_INT) && !(typeof(data[key]) == TYPE_INT && typeof(nullvalue) == TYPE_REAL)):
		Log.printerr("Warning: value mismatch when loading a save. Key '"+key+"' has type "+Util.variantTypeToString(typeof(data[key]))+" and default value has type "+Util.variantTypeToString(typeof(nullvalue))+". Is that an error? "+Util.getStackFunction())
		
	if(data[key] == null && nullvalue != null):
		Log.printerr("Warning: loaded value is null while the default value isn't. Is that correct? "+Util.getStackFunction())
		
	return data[key]

func canQuickLoad() -> bool:
	var d := File.new()
	if(!d.file_exists("user://saves/quicksave.save")):
		return false
	return true

func recursiveQuickSaveMakeBackup(currentI = 1):
	var quickSaveName = "quicksave"
	if(currentI > 1):
		quickSaveName += " backup" + str(currentI)
	var quickSaveFullname = "user://saves/"+quickSaveName+".save"
	
	var d = Directory.new()
	if(d.file_exists(quickSaveFullname)):
		recursiveQuickSaveMakeBackup(currentI + 1)
		
		if(currentI >= maxBackupQuicksaves):
			d.remove(quickSaveFullname)
			invalidateCachedSaveInfoByPath(quickSaveFullname)
			#print("I REMOVED "+quickSaveFullname)
			return
		
		var i = currentI + 1
		var newQuickSaveName = "quicksave backup"+str(i)
		var newQuickSaveFullname = "user://saves/"+newQuickSaveName+".save"
		d.rename(quickSaveFullname, newQuickSaveFullname)
		invalidateCachedSaveInfoByPath(quickSaveFullname)
		#print("RENAMING "+quickSaveFullname+" TO "+newQuickSaveFullname)

func makeQuickSave():
	recursiveQuickSaveMakeBackup()
	
	saveGame("user://saves/quicksave.save")

func loadQuickSave():
	if(!tryLoadGame("user://saves/quicksave.save") && GM.ui != null):
		GM.ui.say("\n\n[center][i]Quickload failed: "+lastLoadError.replace("[", "[lb]")+"[/i][/center]\n")

var isAutoSaving = false
func triggerAutosave():
	if(isAutoSaving):
		return
	if(!OPTIONS.shouldAutosave()):
		return
	isAutoSaving = true
	# Apparently autosaves can crash the game if they happen during rollback thread stuff
	GM.main.rollbacker.waitRollbackerThread()
		
	# To make sure we're not in a middle of calculating something
	yield(get_tree().create_timer(0.1), "timeout")
	if(GM.main == null || GM.pc == null):
		isAutoSaving = false
		return
	saveGame("user://saves/autosave_"+Util.stripBadFilenameCharacters(GM.pc.getName())+".save")
	if(GM.ui != null):
		GM.ui.say("\n\n[center][i]Autosave completed[/i][/center]\n")
	isAutoSaving = false

func getAllSavePathsInFolder(path = "user://saves/"):
	var saves = []
	
	var dir = Directory.new()
	var hasHolder = dir.open(path)
	if(hasHolder != OK):
		return []
	dir.list_dir_begin(true)
	
	var subpath = dir.get_next()
	while(!subpath.empty()):
		if dir.current_is_dir():
			subpath = dir.get_next()
			continue
			
		if(subpath.get_extension() == "save"):
			saves.append(path.plus_file(subpath))
		subpath = dir.get_next()
	dir.list_dir_end()
	return saves

func getAllSavePaths():
	var saves = getAllSavePathsInFolder("user://saves/")
	if(OS.get_name() == "Android"):
		var externalDir:String = Util.getAndroidSaveFolder()#OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		var androidSavesDir = externalDir.plus_file("BDCCSaves")
		saves.append_array(getAllSavePathsInFolder(androidSavesDir))
	return saves

func canResumeGame():
	return getLatestLoadableSavePath() != ""

# Newest save that passes validation, or "" if there is none.
func getLatestLoadableSavePath() -> String:
	for path in getSavesSortedByDate():
		var info = loadGameInformationFromSave(path)
		if(info is Dictionary && info.get("error", "") == ""):
			return path
	return ""

func customSavePathComparison(a, b):
	return a[1] > b[1]

func getSavesSortedByDate():
	var savesPaths = getAllSavePaths()
	var sortedSavePaths = []
	#var file = File.new()
	for path in savesPaths:
		var fileModifTime = Util.getFileModifiedTime(path)#file.get_modified_time(path)
		sortedSavePaths.append([path, fileModifTime])
	sortedSavePaths.sort_custom(self, "customSavePathComparison")
	
	var result = []
	for sortedSaveData in sortedSavePaths:
		result.append(sortedSaveData[0])
	return result

func loadGameInformationFromSave(_path):
	if(saveInfoCache.has(_path)):
		return saveInfoCache[_path]
	
	var theInfo = loadGameInformationFromSaveRaw(_path)
	if(theInfo != null):
		saveInfoCache[_path] = theInfo
		#Log.print("CREATED SAVE INFO CACHE FOR: "+str(_path))
		triggerSaveCacheSave()
	return theInfo

# Returns null if the file can't be read or parsed, {"error": reason} if it isn't loadable,
# otherwise the summary shown in the save list (with "error" = "").
func loadGameInformationFromSaveRaw(_path):
	var inspection:Dictionary = inspectSaveFile(_path)
	if(inspection["data"] == null):
		return null
	if(!inspection["ok"]):
		return {"error": inspection["error"]}
	
	var data:Dictionary = inspection["data"]
	var playerData:Dictionary = data["player"]
	var mainData:Dictionary = data["main"]
	return {
		"error": "",
		"gamename": playerData.get("gamename", "?"),
		"credits": playerData.get("credits", 0),
		"location": playerData.get("location", ""),
		"currentDay": mainData.get("currentDay", 0),
		"timeOfDay": mainData.get("timeOfDay", 0),
	}

func deleteSave(path):
	var dir = Directory.new()
	dir.remove(path)
	invalidateCachedSaveInfoByPath(path)
