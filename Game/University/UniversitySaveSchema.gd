extends Reference

# University Sandbox save identity and schema.
#
# validateAndMigrate() is the single entry point for checking and upgrading the
# university-owned section of a save. Game systems must not check schema versions
# themselves. When the saved shape changes:
#   1. increase CURRENT_SCHEMA_VERSION,
#   2. add migrateFrom<old version>(section) -> Dictionary below,
#   3. extend checkCurrentStructure() if the new version adds required fields,
#   4. add a harness test in Tests/run_tests.gd.
# See Docs/SAVE_SCHEMA.md.
#
# Loaded without class_name (via preload) so headless runs don't depend on the
# editor regenerating project.godot's global class list.

const GAME_ID := "university_sandbox"
const GAME_ID_KEY := "game_id"
const SECTION_KEY := "university"
const SCHEMA_VERSION_KEY := "schema_version"
const SYSTEMS_KEY := "systems"

const CURRENT_SCHEMA_VERSION := 1

# Optional systems whose data shape is checked when present (system id -> validator script).
# Validators expose validate(data) -> String and must not touch live state.
const SYSTEM_VALIDATORS := {
	"student_profile": preload("res://Game/University/UniversityStudentProfile.gd"),
}
const MIN_SUPPORTED_SCHEMA_VERSION := 1

# Returns {"ok": bool, "error": String, "warnings": Array, "section": Dictionary}.
# "section" is a migrated deep copy ready for UniversityState.loadData().
# The input is never modified, and nothing in the live game is touched.
func validateAndMigrate(section) -> Dictionary:
	if(!(section is Dictionary)):
		return makeFailure("University save data is malformed (expected a dictionary, found " + describeType(section) + ")")
	if(!section.has(SCHEMA_VERSION_KEY)):
		return makeFailure("University save data has no schema version")

	var rawVersion = section[SCHEMA_VERSION_KEY]
	if(!isWholeNumber(rawVersion)):
		return makeFailure("University schema version is malformed (" + describeType(rawVersion) + " '" + str(rawVersion) + "')")
	var version:int = int(rawVersion)
	if(version > CURRENT_SCHEMA_VERSION):
		return makeFailure("Save uses University schema version " + str(version) + ", but this build only supports up to version "
			+ str(CURRENT_SCHEMA_VERSION) + ". A newer version of the game is needed to load it")
	if(version < MIN_SUPPORTED_SCHEMA_VERSION):
		return makeFailure("Save uses University schema version " + str(version) + ", which is older than the oldest supported version ("
			+ str(MIN_SUPPORTED_SCHEMA_VERSION) + ")")

	var migrated:Dictionary = section.duplicate(true)
	while(version < CURRENT_SCHEMA_VERSION):
		var stepName:String = "migrateFrom" + str(version)
		if(!has_method(stepName)):
			return makeFailure("No migration step exists from University schema version " + str(version))
		var stepResult = call(stepName, migrated)
		if(!(stepResult is Dictionary)):
			return makeFailure("Migration from University schema version " + str(version) + " failed")
		migrated = stepResult
		version += 1
	migrated[SCHEMA_VERSION_KEY] = CURRENT_SCHEMA_VERSION

	var structureError:String = checkCurrentStructure(migrated)
	if(structureError != ""):
		return makeFailure(structureError)

	var warnings:Array = []
	for key in migrated.keys():
		if(!(key in [SCHEMA_VERSION_KEY, SYSTEMS_KEY])):
			warnings.append("Unknown University save key '" + str(key) + "' was kept unchanged")
	return {"ok": true, "error": "", "warnings": warnings, "section": migrated}

# Required shape of a section at CURRENT_SCHEMA_VERSION. Returns "" when valid.
func checkCurrentStructure(section:Dictionary) -> String:
	if(!section.has(SYSTEMS_KEY)):
		return "University save data is missing its systems table"
	var systems = section[SYSTEMS_KEY]
	if(!(systems is Dictionary)):
		return "University systems table is malformed (expected a dictionary, found " + describeType(systems) + ")"
	for systemID in systems.keys():
		if(!(systemID is String) || systemID == ""):
			return "University systems table has an invalid system id '" + str(systemID) + "'"
		if(!(systems[systemID] is Dictionary)):
			return "University system '" + systemID + "' data is malformed (expected a dictionary, found " + describeType(systems[systemID]) + ")"
		if(SYSTEM_VALIDATORS.has(systemID)):
			var systemError:String = SYSTEM_VALIDATORS[systemID].new().validate(systems[systemID])
			if(systemError != ""):
				return systemError
	return ""

# JSON numbers load as floats, so 1.0 counts as 1. Booleans and fractions do not.
func isWholeNumber(value) -> bool:
	if(typeof(value) == TYPE_INT):
		return true
	if(typeof(value) == TYPE_REAL):
		return is_equal_approx(value, floor(value)) && abs(value) < 1000000000.0
	return false

func describeType(value) -> String:
	match(typeof(value)):
		TYPE_NIL:
			return "nothing"
		TYPE_BOOL:
			return "a boolean"
		TYPE_INT, TYPE_REAL:
			return "a number"
		TYPE_STRING:
			return "text"
		TYPE_ARRAY:
			return "a list"
		TYPE_DICTIONARY:
			return "a dictionary"
	return "an unsupported value"

func makeFailure(message:String) -> Dictionary:
	return {"ok": false, "error": message, "warnings": [], "section": {}}

# Migration steps go here, one per version, e.g.:
# func migrateFrom1(section:Dictionary) -> Dictionary:
# 	section[SYSTEMS_KEY]["calendar"] = {}
# 	return section
