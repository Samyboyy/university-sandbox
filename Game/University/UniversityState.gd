extends Reference

# Live University Sandbox data for the current game.
#
# Owned by MainScene as GM.main.university, so every new game starts with a fresh,
# empty instance. SaveManager writes it to the save's "university" section and only
# calls loadData() after UniversitySaveSchema.validateAndMigrate() has accepted the save.
#
# Future systems keep their persistent data under their own stable system id:
#   GM.main.university.setSystemData("calendar", {...})
#   var calendarData = GM.main.university.getSystemData("calendar")
# Values must be JSON-safe dictionaries. See Docs/SAVE_SCHEMA.md.

const Schema = preload("res://Game/University/UniversitySaveSchema.gd")

var systems:Dictionary = {}
# Unknown keys from a loaded section, written back unchanged on the next save.
var preservedKeys:Dictionary = {}

func hasSystemData(systemID:String) -> bool:
	return systems.has(systemID)

# Returns a copy; call setSystemData() to store changes.
func getSystemData(systemID:String) -> Dictionary:
	if(!systems.has(systemID)):
		return {}
	return systems[systemID].duplicate(true)

func setSystemData(systemID:String, data:Dictionary):
	if(systemID == ""):
		Log.printerr("University system id can't be empty")
		return
	systems[systemID] = data.duplicate(true)

func saveData() -> Dictionary:
	var result:Dictionary = preservedKeys.duplicate(true)
	result[Schema.SCHEMA_VERSION_KEY] = Schema.CURRENT_SCHEMA_VERSION
	result[Schema.SYSTEMS_KEY] = systems.duplicate(true)
	return result

# Only pass a section returned by UniversitySaveSchema.validateAndMigrate().
func loadData(validatedSection:Dictionary):
	systems = validatedSection[Schema.SYSTEMS_KEY].duplicate(true)
	preservedKeys = validatedSection.duplicate(true)
	preservedKeys.erase(Schema.SCHEMA_VERSION_KEY)
	preservedKeys.erase(Schema.SYSTEMS_KEY)
