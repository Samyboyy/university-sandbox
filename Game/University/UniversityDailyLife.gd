extends Reference

# The central University daily-life service.
#
# Every ordinary action and every journey goes through here, so time, needs, attendance and
# the T5 first-day objective are applied in one place instead of being poked from scenes.
# Actions are data (ACTIONS below): add one by adding an entry, not by writing a new scene.
# See Docs/UNIVERSITY_LIFE.md.

const Locations = preload("res://Game/University/UniversityLocations.gd")
const Needs = preload("res://Game/University/UniversityNeeds.gd")
const Timetable = preload("res://Game/University/UniversityTimetable.gd")
const StudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")
const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")

# Shared effect data: preview and execution both read these, so they can't drift apart.
const SLEEP_EFFECTS := {"rest": 70, "relaxation": 20, "composure": 15, "bladder": 25, "food": -15, "hygiene": -10}
const CLASS_EFFECTS := {"rest": -6, "relaxation": -10, "composure": 4, "attention": 5, "bladder": 8}
const WAKE_HOUR := 6 # MainScene.startNewDay() wakes the player at 06:00

# Central need policy. Reserves below their block value stop demanding actions; pressures above
# theirs do the same. "soft" values only reduce effectiveness, so the player is warned before
# anything is taken away.
const CRITICAL_RESERVE_BLOCK := 10
const CRITICAL_RESERVE_SOFT := 30
const CRITICAL_PRESSURE_BLOCK := 90
const CRITICAL_PRESSURE_SOFT := 70
# Actions that need concentration; they are the ones a critical need can block.
const DEMANDING_ACTIONS := ["study", "attend_class"]
const SOCIAL_ACTIONS := ["socialise"]

# Activity poses for the persistent character showcase. Every entry must be a state the stage
# scene really supports (validated by the harness): Solo has stand/sit/kneel, Sleeping has
# sleep/rub, Showering has body/head/crotch.
const ACTION_ANIMATIONS := {
	"sleep": ["Sleeping", "sleep"],
	"nap": ["Sleeping", "sleep"],
	"private_time": ["Sleeping", "rub"],
	"shower": ["Showering", "body"],
	"toilet": ["Solo", "kneel"],
	"eat": ["Solo", "sit"],
	"snack": ["Solo", "sit"],
	"relax": ["Solo", "sit"],
	"study": ["Solo", "sit"],
	"attend_class": ["Solo", "sit"],
	"socialise": ["Solo", "stand"],
	"check_in": ["Solo", "stand"],
	"orientation": ["Solo", "sit"],
}
const DEFAULT_ANIMATION := ["Solo", "stand"]

# effects are need deltas; "scene" runs an existing scene instead of resolving here.
const ACTIONS := {
	"sleep": {
		"name": "Sleep until morning",
		"locations": ["dorm_room"],
		"minutes": 0, # computed: the hours until the next morning (see getActionMinutes)
		"scene": "UniversitySleepScene",
		"sleep_action": true,
		"effects": SLEEP_EFFECTS,
		"desc": "End the day and wake up tomorrow morning.",
	},
	"private_time": {
		"name": "Take some private time",
		"locations": ["dorm_room"],
		"minutes": 25,
		"effects": {"release": -80, "relaxation": 12, "composure": 6, "arousal": -100},
		"private": true,
		"desc": "Lock the door, draw the curtain and see to yourself. Relieves the release need.",
	},
	"toilet": {
		"name": "Use the toilet",
		"locations": ["dorm_bathroom"],
		"minutes": 5,
		"effects": {"bladder": -100, "hygiene": -2},
		"desc": "Relieve yourself.",
	},
	"shower": {
		"name": "Take a shower",
		"locations": ["dorm_bathroom"],
		"minutes": 20,
		"effects": {"hygiene": 60, "relaxation": 8, "composure": 5},
		"desc": "Wash properly and feel human again.",
	},
	"eat": {
		"name": "Eat a meal",
		"locations": ["cafeteria"],
		"minutes": 40,
		"effects": {"food": 55, "relaxation": 5, "bladder": 8},
		"desc": "A hot meal from the counter.",
	},
	"snack": {
		"name": "Make toast and tea",
		"locations": ["dorm_common"],
		"minutes": 20,
		"effects": {"food": 25, "relaxation": 6, "bladder": 6},
		"desc": "Not a meal, but it takes the edge off.",
	},
	"relax": {
		"name": "Relax for a while",
		"locations": ["dorm_room", "dorm_common", "quad"],
		"minutes": 60,
		"effects": {"relaxation": 30, "composure": 12, "rest": 5},
		"desc": "Sit down, do nothing useful, let your head settle.",
	},
	"study": {
		"name": "Study",
		"locations": ["library", "dorm_room"],
		"minutes": 120,
		"effects": {"relaxation": -12, "composure": -5, "rest": -8},
		"study_progress": 2,
		"desc": "Work through your reading and notes.",
	},
	"socialise": {
		"name": "Chat with other students",
		"locations": ["dorm_common", "cafeteria", "quad"],
		"minutes": 45,
		"effects": {"attention": 35, "relaxation": 10, "composure": 5},
		"desc": "Talk to whoever is around.",
	},
	"attend_class": {
		"name": "Attend the class",
		"locations": ["lecture_hall"],
		"minutes": 0,
		"class_action": true,
		"desc": "Take a seat for the session.",
	},
	"nap": {
		"name": "Nap on your bed",
		"locations": ["dorm_room"],
		"minutes": 90,
		"effects": {"rest": 25, "relaxation": 8},
		"desc": "A short lie-down. Not as good as a night's sleep.",
	},
	"check_in": {
		"name": "Talk to the orientation coordinator",
		"locations": ["student_services"],
		"minutes": 0,
		"scene": "UniversityCoordinatorScene",
		"desc": "Speak to the coordinator at the desk.",
	},
	"orientation": {
		"name": "Attend orientation",
		"locations": ["lecture_hall"],
		"minutes": 0,
		"scene": "UniversityOrientationScene",
		"first_day_only": true,
		"desc": "The first-year orientation talk.",
	},
}

var locations = Locations.new()
var needs = Needs.new()
var timetable = Timetable.new()
var firstDay = FirstDay.new()

# ---------------------------------------------------------------- state and gating

func getUniversityState():
	if(GM.main == null || GM.main.get("university") == null):
		return null
	return GM.main.university

# University life runs only for a valid University game, exactly like the T5 objective.
func isActive() -> bool:
	var universityState = getUniversityState()
	return universityState != null && StudentProfile.new().isUniversityGame(universityState)

# Adds T6 systems to a University game that predates them, leaving profile/first-day alone.
func ensureState():
	if(!isActive()):
		return
	var universityState = getUniversityState()
	needs.ensure(universityState)
	timetable.ensure(universityState)

# ---------------------------------------------------------------- time helpers

func getHourOfDay() -> int:
	return int(GM.main.getTime() / 3600) % 24

func getMinuteOfHour() -> int:
	return int(GM.main.getTime() / 60) % 60

func getTimeString() -> String:
	return "%02d:%02d" % [getHourOfDay(), getMinuteOfHour()]

func getDayString() -> String:
	var weekdayNames := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var day:int = GM.main.getDays()
	return weekdayNames[timetable.getWeekday(day)] + ", day " + str(day + 1)

# ---------------------------------------------------------------- location

func getCurrentLocationID() -> String:
	var locationID:String = locations.getLocationIDForRoom(GM.pc.getLocation())
	return locationID if locationID != "" else "dorm_room"

func getDestinations() -> Array:
	var result:Array = []
	var currentID:String = getCurrentLocationID()
	for locationID in locations.getIDs():
		if(locationID == currentID):
			continue
		result.append(locationID)
	return result

func getClosedReason(locationID) -> String:
	return locations.getClosedReason(locationID, getHourOfDay())

# Travels to a destination: advertised travel time, needs drift, real room move so inherited
# events and saving keep working. Refuses (changing nothing) when the destination is closed.
func travelTo(locationID) -> bool:
	if(!isActive() || !locations.hasLocation(locationID)):
		return false
	if(getClosedReason(locationID) != ""):
		return false
	var seconds:int = locations.getTravelMinutes(locationID) * 60
	GM.pc.setLocation(locations.getRoomID(locationID))
	advanceTime(seconds)
	# Same trigger WorldScene fires, so inherited room events (and the T5 objective) still run.
	GM.ES.triggerRun(Trigger.EnteringRoom, [GM.pc.location])
	return true

# ---------------------------------------------------------------- time and needs

# The single place that spends time: engine clock first, then need drift, then any class
# whose window has now closed.
func advanceTime(seconds:int):
	if(seconds > 0):
		GM.main.processTime(seconds)
	if(!isActive()):
		return
	var universityState = getUniversityState()
	needs.applyTimeDrift(universityState, seconds)
	var _missed = timetable.closeMissedClasses(universityState, GM.main.getDays(), getHourOfDay())

# ---------------------------------------------------------------- actions

func getActionsHere() -> Array:
	var result:Array = []
	var currentID:String = getCurrentLocationID()
	var universityState = getUniversityState()
	for actionID in ACTIONS.keys():
		var action:Dictionary = ACTIONS[actionID]
		if(!(currentID in action["locations"])):
			continue
		if(action.get("first_day_only", false) && firstDay.isCompleted(universityState)):
			continue
		if(actionID == "check_in" && firstDay.isCompleted(universityState)):
			continue
		if(action.get("class_action", false) && timetable.getClassInSession(universityState, GM.main.getDays(), getHourOfDay(), currentID).empty()):
			continue
		result.append(actionID)
	return result

func getAction(actionID) -> Dictionary:
	if(!(actionID is String) || !ACTIONS.has(actionID)):
		return {}
	return ACTIONS[actionID]

func getActionMinutes(actionID) -> int:
	var action:Dictionary = getAction(actionID)
	if(action.get("sleep_action", false)):
		return getMinutesUntilMorning()
	if(action.get("class_action", false)):
		var session:Dictionary = timetable.getClassInSession(getUniversityState(), GM.main.getDays(), getHourOfDay(), getCurrentLocationID())
		if(session.empty()):
			return 0
		return int(max(0, (int(session["end_hour"]) - getHourOfDay()) * 60 - getMinuteOfHour()))
	return int(action.get("minutes", 0))

func getMinutesUntilMorning() -> int:
	var minutesNow:int = getHourOfDay() * 60 + getMinuteOfHour()
	var minutesAtWake:int = WAKE_HOUR * 60
	if(minutesNow < minutesAtWake):
		return minutesAtWake - minutesNow
	return 24 * 60 - minutesNow + minutesAtWake

func getActionEffects(actionID) -> Dictionary:
	var action:Dictionary = getAction(actionID)
	if(action.get("class_action", false)):
		return CLASS_EFFECTS
	return action.get("effects", {})

# The policy is evaluated against the state at the instant the player commits. It can adjust
# need effects and non-need rewards, but never writes state itself. Keeping this here means the
# UI preview and execution cannot quietly disagree about low-need penalties.
func getResolvedActionEffects(actionID) -> Dictionary:
	var resolved:Dictionary = getActionEffects(actionID).duplicate(true)
	var universityState = getUniversityState()
	if(universityState == null):
		return resolved

	# Poor hygiene or composure makes social contact less restorative, without trapping the
	# player: showering and quiet relaxation remain available recovery routes.
	if(actionID in SOCIAL_ACTIONS && (needs.getValue(universityState, Needs.HYGIENE) <= CRITICAL_RESERVE_SOFT \
		|| needs.getValue(universityState, Needs.COMPOSURE) <= CRITICAL_RESERVE_SOFT)):
		for needID in [Needs.ATTENTION, Needs.RELAXATION]:
			if(float(resolved.get(needID, 0.0)) > 0.0):
				resolved[needID] = float(resolved[needID]) * 0.5

	# These are light, previewed costs rather than hard locks. They make every ordinary need
	# influence a decision while preserving a clear route back to a healthy state.
	if(actionID in DEMANDING_ACTIONS):
		if(needs.getValue(universityState, Needs.RELAXATION) <= CRITICAL_RESERVE_SOFT):
			resolved[Needs.COMPOSURE] = float(resolved.get(Needs.COMPOSURE, 0.0)) - 4.0
		if(needs.getValue(universityState, Needs.ATTENTION) <= CRITICAL_RESERVE_SOFT):
			resolved[Needs.COMPOSURE] = float(resolved.get(Needs.COMPOSURE, 0.0)) - 3.0
		if(needs.getValue(universityState, Needs.COMPOSURE) <= CRITICAL_RESERVE_SOFT):
			resolved[Needs.RELAXATION] = float(resolved.get(Needs.RELAXATION, 0.0)) - 3.0
		if(needs.getValue(universityState, Needs.RELEASE) >= CRITICAL_PRESSURE_SOFT):
			resolved[Needs.COMPOSURE] = float(resolved.get(Needs.COMPOSURE, 0.0)) - 4.0
			resolved[Needs.RELAXATION] = float(resolved.get(Needs.RELAXATION, 0.0)) - 4.0
	return resolved

# Non-need academic rewards are halved once when any soft concentration problem applies. The
# penalties do not stack, which prevents a low-need spiral from reducing progress to zero.
func getActionRewardMultiplier(actionID) -> float:
	if(!(actionID in DEMANDING_ACTIONS)):
		return 1.0
	var universityState = getUniversityState()
	if(universityState == null):
		return 1.0
	if(needs.getValue(universityState, Needs.REST) <= CRITICAL_RESERVE_SOFT \
		|| needs.getValue(universityState, Needs.FOOD) <= CRITICAL_RESERVE_SOFT \
		|| needs.getValue(universityState, Needs.BLADDER) >= CRITICAL_PRESSURE_SOFT \
		|| needs.getValue(universityState, Needs.ATTENTION) <= CRITICAL_RESERVE_SOFT \
		|| needs.getValue(universityState, Needs.COMPOSURE) <= CRITICAL_RESERVE_SOFT \
		|| needs.getValue(universityState, Needs.RELEASE) >= CRITICAL_PRESSURE_SOFT):
		return 0.5
	return 1.0

func getActionPolicyNotes(actionID) -> Array:
	var result:Array = []
	var universityState = getUniversityState()
	if(universityState == null):
		return result
	if(actionID in DEMANDING_ACTIONS):
		if(needs.getValue(universityState, Needs.REST) <= CRITICAL_RESERVE_SOFT): result.append("tired: reduced academic progress")
		if(needs.getValue(universityState, Needs.FOOD) <= CRITICAL_RESERVE_SOFT): result.append("hungry: reduced academic progress")
		if(needs.getValue(universityState, Needs.BLADDER) >= CRITICAL_PRESSURE_SOFT): result.append("uncomfortable: reduced academic progress")
		if(needs.getValue(universityState, Needs.RELAXATION) <= CRITICAL_RESERVE_SOFT): result.append("stressed: extra composure cost")
		if(needs.getValue(universityState, Needs.ATTENTION) <= CRITICAL_RESERVE_SOFT): result.append("distracted: reduced academic progress")
		if(needs.getValue(universityState, Needs.COMPOSURE) <= CRITICAL_RESERVE_SOFT): result.append("flustered: reduced academic progress")
		if(needs.getValue(universityState, Needs.RELEASE) >= CRITICAL_PRESSURE_SOFT): result.append("pent-up: reduced focus")
	if(actionID in SOCIAL_ACTIONS && needs.getValue(universityState, Needs.HYGIENE) <= CRITICAL_RESERVE_SOFT):
		result.append("self-conscious: reduced social recovery")
	if(actionID in SOCIAL_ACTIONS && needs.getValue(universityState, Needs.COMPOSURE) <= CRITICAL_RESERVE_SOFT):
		result.append("flustered: reduced social recovery")
	return result

func getActionPolicyText(actionID) -> String:
	var notes:Array = getActionPolicyNotes(actionID)
	return PoolStringArray(notes).join("; ")

# The exact state-aware change the player will receive. This simulates the production sequence
# against local values only: drift + clamp, then resolved action effects + clamp. It never writes
# to UniversityState. Sleeping skips drift because startNewDay jumps the clock.
func getActionNetEffects(actionID) -> Dictionary:
	var universityState = getUniversityState()
	if(universityState == null):
		return {}
	var before:Dictionary = {}
	var after:Dictionary = {}
	for needID in Needs.NEEDS + Needs.CONTEXTUAL:
		before[needID] = needs.getValue(universityState, needID)
		after[needID] = before[needID]
	var action:Dictionary = getAction(actionID)
	if(!action.get("sleep_action", false)):
		var hours:float = float(getActionMinutes(actionID) * 60) / 3600.0
		for needID in Needs.HOURLY_DRIFT.keys():
			after[needID] = needs.clampValue(float(after[needID]) + float(Needs.HOURLY_DRIFT[needID]) * hours)
	var resolvedEffects:Dictionary = getResolvedActionEffects(actionID)
	for needID in resolvedEffects.keys():
		if(after.has(needID)):
			after[needID] = needs.clampValue(float(after[needID]) + float(resolvedEffects[needID]))
	var net:Dictionary = {}
	for needID in after.keys():
		var delta:float = float(after[needID]) - float(before[needID])
		if(!is_equal_approx(delta, 0.0)):
			net[needID] = delta
	return net

# Shown on the button. Values are the exact state-aware net change, rounded to whole points.
func getActionPreview(actionID) -> String:
	var parts:Array = []
	var action:Dictionary = getAction(actionID)
	var minutes:int = getActionMinutes(actionID)
	if(action.get("sleep_action", false)):
		parts.append("until " + ("%02d:00" % WAKE_HOUR) + " tomorrow, " + str(int(round(minutes / 60.0))) + "h")
	elif(minutes > 0):
		parts.append(str(minutes) + " min")
	var net:Dictionary = getActionNetEffects(actionID)
	for needID in net.keys():
		var delta:float = float(net[needID])
		if(abs(delta) < 1.0):
			continue
		var signText:String = "+" if delta > 0 else ""
		parts.append(needs.getName(needID) + " " + signText + str(int(round(delta))))
	var policyText:String = getActionPolicyText(actionID)
	if(policyText != ""):
		parts.append(policyText)
	if(parts.empty()):
		return ""
	return PoolStringArray(parts).join(", ")

# Central threshold policy: why a demanding action can't be done right now ("" when it can).
func getActionBlockReason(actionID) -> String:
	var universityState = getUniversityState()
	if(universityState == null):
		return ""
	if(actionID in SOCIAL_ACTIONS && needs.getValue(universityState, Needs.HYGIENE) <= CRITICAL_RESERVE_BLOCK):
		return "You feel too unwashed to face people. Take a shower first."
	if(!(actionID in DEMANDING_ACTIONS)):
		return ""
	if(needs.getValue(universityState, Needs.BLADDER) >= CRITICAL_PRESSURE_BLOCK):
		return "You need a toilet before you can concentrate on that."
	if(needs.getValue(universityState, Needs.REST) <= CRITICAL_RESERVE_BLOCK):
		return "You're too exhausted to take anything in. Sleep or nap first."
	if(needs.getValue(universityState, Needs.FOOD) <= CRITICAL_RESERVE_BLOCK):
		return "You're too hungry to focus. Eat something first."
	return ""

# Soft consequence: demanding actions are half as productive when a reserve is low.
func isImpaired(actionID:String = "study") -> bool:
	return getActionRewardMultiplier(actionID) < 1.0

func getActionAnimation(actionID) -> Array:
	if(ACTION_ANIMATIONS.has(actionID)):
		return ACTION_ANIMATIONS[actionID]
	return DEFAULT_ANIMATION

# Resolves an ordinary action. Scene-backed actions are run by the interface instead.
# Returns a short result line for the player.
func performAction(actionID) -> String:
	if(!isActive() || !(actionID in getActionsHere())):
		return ""
	var universityState = getUniversityState()
	var action:Dictionary = getAction(actionID)

	if(getActionBlockReason(actionID) != ""):
		return getActionBlockReason(actionID)

	if(action.get("class_action", false)):
		return attendClassNow()

	var rewardMultiplier:float = getActionRewardMultiplier(actionID)
	var resolvedEffects:Dictionary = getResolvedActionEffects(actionID)
	var policyText:String = getActionPolicyText(actionID)
	var minutes:int = getActionMinutes(actionID)
	advanceTime(minutes * 60)
	needs.applyEffects(universityState, resolvedEffects)
	if(action.has("study_progress")):
		var progress:int = int(max(1, round(float(action["study_progress"]) * rewardMultiplier)))
		timetable.addStudyProgress(universityState, progress)
	if(policyText != ""):
		return str(action.get("name", actionID)) + " - done, but " + policyText + "."
	return str(action.get("name", actionID)) + " - done."

# Attending the class sitting in this room right now.
func attendClassNow() -> String:
	var universityState = getUniversityState()
	var day:int = GM.main.getDays()
	var session:Dictionary = timetable.getClassInSession(universityState, day, getHourOfDay(), getCurrentLocationID())
	if(session.empty()):
		return "There's no class in here right now."
	var onTime:bool = timetable.isOnTime(session, getHourOfDay(), getMinuteOfHour())
	var rewardMultiplier:float = getActionRewardMultiplier("attend_class")
	var resolvedEffects:Dictionary = getResolvedActionEffects("attend_class")
	var policyText:String = getActionPolicyText("attend_class")
	var minutes:int = getActionMinutes("attend_class")
	advanceTime(minutes * 60)
	needs.applyEffects(universityState, resolvedEffects)
	timetable.recordAttendance(universityState, day, session["id"], onTime, rewardMultiplier)
	var policySuffix:String = (" Your focus suffers: " + policyText + ".") if policyText != "" else ""
	if(onTime):
		return "You get a seat before " + str(session["name"]) + " starts, and follow most of it." + policySuffix
	return "You slip in late to " + str(session["name"]) + " and miss the start." + policySuffix

# Sleeping: the day advances through the inherited day system, then needs recover.
func sleepUntilMorning() -> String:
	var universityState = getUniversityState()
	var _missedToday = timetable.closeMissedClasses(universityState, GM.main.getDays(), 24)
	GM.main.startNewDay()
	needs.applyEffects(universityState, SLEEP_EFFECTS)
	return "You sleep through until morning."
