extends Reference

# University daily needs.
#
# Stored in the T3 save section as university.systems["needs"]:
#   {"values": {<need id>: 0-100, ...}, "contextual": {<meter id>: 0-100, ...}}
#
# Direction (documented once, used everywhere):
#   RESERVES  - higher is better; they fall with time and are restored by actions
#               (rest, relaxation, attention, food, hygiene, composure)
#   PRESSURES - higher is worse; they build with time and are relieved by actions
#               (bladder, release)
#   CONTEXTUAL- arousal and humiliation; 0 means "not currently relevant" and the
#               interface hides them until they rise above zero.
#
# All writes go through this class so values stay clamped to 0-100 and no scene pokes the
# dictionary directly. See Docs/UNIVERSITY_LIFE.md.

const MIN_VALUE := 0
const MAX_VALUE := 100

const REST := "rest"
const RELAXATION := "relaxation"
const ATTENTION := "attention"
const BLADDER := "bladder"
const FOOD := "food"
const HYGIENE := "hygiene"
const COMPOSURE := "composure"
const RELEASE := "release"

const AROUSAL := "arousal"
const HUMILIATION := "humiliation"

const RESERVES := [REST, RELAXATION, ATTENTION, FOOD, HYGIENE, COMPOSURE]
const PRESSURES := [BLADDER, RELEASE]
const NEEDS := [REST, RELAXATION, ATTENTION, BLADDER, FOOD, HYGIENE, COMPOSURE, RELEASE]
const CONTEXTUAL := [AROUSAL, HUMILIATION]

const NEED_NAMES := {
	REST: "Rest", RELAXATION: "Relaxation", ATTENTION: "Attention", BLADDER: "Bladder",
	FOOD: "Food", HYGIENE: "Hygiene", COMPOSURE: "Composure", RELEASE: "Release",
	AROUSAL: "Arousal", HUMILIATION: "Humiliation",
}

# Change per hour of elapsed time. Reserves drain, pressures build.
const HOURLY_DRIFT := {
	REST: -4.0, RELAXATION: -3.0, ATTENTION: -2.5, FOOD: -5.0, HYGIENE: -3.0, COMPOSURE: -1.5,
	BLADDER: 6.0, RELEASE: 2.0,
}

const SYSTEM_ID := "needs"

func createInitial() -> Dictionary:
	var values:Dictionary = {}
	for needID in RESERVES:
		values[needID] = 80
	for needID in PRESSURES:
		values[needID] = 10
	var contextual:Dictionary = {}
	for meterID in CONTEXTUAL:
		contextual[meterID] = 0
	return {"values": values, "contextual": contextual}

func validate(data) -> String:
	if(!(data is Dictionary)):
		return "Needs data is malformed (expected a dictionary)"
	for key in ["values", "contextual"]:
		if(!(data.get(key) is Dictionary)):
			return "Needs data is missing its '" + key + "' table"
	for needID in NEEDS:
		if(!isValidValue(data["values"].get(needID))):
			return "Need '" + needID + "' has a malformed value"
	for meterID in CONTEXTUAL:
		if(!isValidValue(data["contextual"].get(meterID))):
			return "Contextual meter '" + meterID + "' has a malformed value"
	return ""

func isValidValue(value) -> bool:
	if(!(typeof(value) in [TYPE_INT, TYPE_REAL])):
		return false
	return value >= MIN_VALUE && value <= MAX_VALUE

func hasData(universityState) -> bool:
	return universityState != null && universityState.hasSystemData(SYSTEM_ID)

func ensure(universityState):
	# Older University saves (T5 and earlier) get stable defaults without touching anything else.
	if(!hasData(universityState)):
		universityState.setSystemData(SYSTEM_ID, createInitial())

func getData(universityState) -> Dictionary:
	if(!hasData(universityState)):
		return createInitial()
	var data:Dictionary = universityState.getSystemData(SYSTEM_ID)
	var defaults:Dictionary = createInitial()
	for needID in NEEDS:
		if(!isValidValue(data["values"].get(needID))):
			data["values"][needID] = defaults["values"][needID]
	for meterID in CONTEXTUAL:
		if(!isValidValue(data["contextual"].get(meterID))):
			data["contextual"][meterID] = defaults["contextual"][meterID]
	return data

func getValue(universityState, needID) -> float:
	var data:Dictionary = getData(universityState)
	if(needID in CONTEXTUAL):
		return float(data["contextual"].get(needID, 0))
	return float(data["values"].get(needID, 0))

func clampValue(value) -> float:
	return float(clamp(value, MIN_VALUE, MAX_VALUE))

func setValue(universityState, needID, value):
	if(universityState == null):
		return
	var data:Dictionary = getData(universityState)
	if(needID in CONTEXTUAL):
		data["contextual"][needID] = clampValue(value)
	elif(needID in NEEDS):
		data["values"][needID] = clampValue(value)
	else:
		return
	universityState.setSystemData(SYSTEM_ID, data)

func addValue(universityState, needID, delta):
	setValue(universityState, needID, getValue(universityState, needID) + delta)

# The single entry point for an action's or event's need effects: {need id: delta}.
func applyEffects(universityState, effects:Dictionary):
	if(universityState == null || effects.empty()):
		return
	var data:Dictionary = getData(universityState)
	for needID in effects.keys():
		if(needID in CONTEXTUAL):
			data["contextual"][needID] = clampValue(float(data["contextual"].get(needID, 0)) + effects[needID])
		elif(needID in NEEDS):
			data["values"][needID] = clampValue(float(data["values"].get(needID, 0)) + effects[needID])
	universityState.setSystemData(SYSTEM_ID, data)

# Drift for elapsed time, applied once per action/travel rather than per frame.
func applyTimeDrift(universityState, seconds:int):
	if(universityState == null || seconds <= 0):
		return
	var hours:float = float(seconds) / 3600.0
	var effects:Dictionary = {}
	for needID in HOURLY_DRIFT.keys():
		effects[needID] = HOURLY_DRIFT[needID] * hours
	applyEffects(universityState, effects)

# Contextual meters are only shown once they matter.
func getVisibleContextual(universityState) -> Array:
	var result:Array = []
	for meterID in CONTEXTUAL:
		if(getValue(universityState, meterID) > 0):
			result.append(meterID)
	return result

func getName(needID) -> String:
	return str(NEED_NAMES.get(needID, needID))

# "Rest 62/100" style bar for the interface, drawn with block characters.
func getBarText(universityState, needID) -> String:
	var value:float = getValue(universityState, needID)
	var filled:int = int(round(value / 10.0))
	var bar:String = ""
	for i in range(10):
		bar += "|" if i < filled else "."
	var colour:String = "#e8a0bf"
	if(needID in PRESSURES || needID in CONTEXTUAL):
		colour = "#e8a0bf" if value < 70 else "#ff7a7a"
	else:
		colour = "#7ad4a0" if value >= 50 else ("#ffc46b" if value >= 25 else "#ff7a7a")
	return "[color=" + colour + "]" + bar + "[/color] " + getName(needID) + " " + str(int(round(value)))
