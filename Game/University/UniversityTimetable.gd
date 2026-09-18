extends Reference

# Data-driven class timetable and attendance.
#
# Stored in the T3 save section as university.systems["timetable"]:
#   {"attended": 0, "missed": 0, "study_progress": 0, "handled": ["<day>:<class id>", ...]}
#
# "handled" records class sessions already resolved (attended or written off as missed), so a
# session is never counted twice. Add a class by adding an entry to CLASSES.
# See Docs/UNIVERSITY_LIFE.md.

const SYSTEM_ID := "timetable"
const DAYS_PER_WEEK := 7
const ON_TIME_MINUTES := 15 # arriving within this many minutes of the start counts as on time

# weekday: day number modulo 7 (day 0 of a new game is weekday 0).
const CLASSES := {
	"intro_lecture": {
		"name": "Introduction to Your Subject",
		"weekdays": [0, 2, 4],
		"start_hour": 10,
		"end_hour": 12,
		"location": "lecture_hall",
	},
	"study_skills": {
		"name": "Academic Study Skills",
		"weekdays": [1, 3],
		"start_hour": 14,
		"end_hour": 16,
		"location": "lecture_hall",
	},
}

func createInitial() -> Dictionary:
	return {"attended": 0, "missed": 0, "study_progress": 0, "handled": []}

func validate(data) -> String:
	if(!(data is Dictionary)):
		return "Timetable data is malformed (expected a dictionary)"
	for key in ["attended", "missed", "study_progress"]:
		var value = data.get(key)
		if(!(typeof(value) in [TYPE_INT, TYPE_REAL]) || value != floor(value) || value < 0):
			return "Timetable data has a malformed '" + key + "' count"
	if(!(data.get("handled") is Array)):
		return "Timetable data is missing its handled-session list"
	return ""

func hasData(universityState) -> bool:
	return universityState != null && universityState.hasSystemData(SYSTEM_ID)

func ensure(universityState):
	if(!hasData(universityState)):
		universityState.setSystemData(SYSTEM_ID, createInitial())

func getData(universityState) -> Dictionary:
	if(!hasData(universityState)):
		return createInitial()
	return universityState.getSystemData(SYSTEM_ID)

func setData(universityState, data:Dictionary):
	universityState.setSystemData(SYSTEM_ID, data)

func getWeekday(day:int) -> int:
	return int(day) % DAYS_PER_WEEK

func getClassesOnDay(day:int) -> Array:
	var result:Array = []
	for classID in CLASSES:
		if(getWeekday(day) in CLASSES[classID]["weekdays"]):
			result.append(classID)
	return result

func getSessionKey(day:int, classID:String) -> String:
	return str(day) + ":" + classID

func isHandled(universityState, day:int, classID:String) -> bool:
	return getSessionKey(day, classID) in getData(universityState)["handled"]

func markHandled(universityState, day:int, classID:String):
	var data:Dictionary = getData(universityState)
	var key:String = getSessionKey(day, classID)
	if(!(key in data["handled"])):
		data["handled"].append(key)
	setData(universityState, data)

# The next unhandled class today (or the first one tomorrow), as
# {"id", "name", "location", "start_hour", "end_hour", "day", "today"} or {}.
# Searches forward across a full week, so Friday evening and weekends still show Monday's class.
func getNextClass(universityState, day:int, hourOfDay:int) -> Dictionary:
	for offset in range(DAYS_PER_WEEK + 1):
		var searchDay:int = day + offset
		var best:Dictionary = {}
		for classID in getClassesOnDay(searchDay):
			var theClass:Dictionary = CLASSES[classID]
			if(offset == 0 && (hourOfDay >= int(theClass["end_hour"]) || isHandled(universityState, searchDay, classID))):
				continue
			if(best.empty() || int(theClass["start_hour"]) < int(best["start_hour"])):
				best = describeSession(classID, searchDay, offset == 0)
		if(!best.empty()):
			best["days_ahead"] = offset
			return best
	return {}

# "today 10:00" / "tomorrow 14:00" / "Mon 10:00" for anything further out.
func describeWhen(session:Dictionary) -> String:
	if(session.empty()):
		return ""
	var hourText:String = "%02d:00" % int(session["start_hour"])
	var daysAhead:int = int(session.get("days_ahead", 0))
	if(daysAhead == 0):
		return "today " + hourText
	if(daysAhead == 1):
		return "tomorrow " + hourText
	var weekdayNames := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	return weekdayNames[getWeekday(int(session["day"]))] + " " + hourText

func describeSession(classID:String, day:int, today:bool) -> Dictionary:
	var theClass:Dictionary = CLASSES[classID]
	return {
		"id": classID,
		"name": theClass["name"],
		"location": theClass["location"],
		"start_hour": theClass["start_hour"],
		"end_hour": theClass["end_hour"],
		"day": day,
		"today": today,
	}

# The class sitting right now in this location, if any.
func getClassInSession(universityState, day:int, hourOfDay:int, locationID:String) -> Dictionary:
	for classID in getClassesOnDay(day):
		var theClass:Dictionary = CLASSES[classID]
		if(theClass["location"] != locationID):
			continue
		if(hourOfDay < int(theClass["start_hour"]) || hourOfDay >= int(theClass["end_hour"])):
			continue
		if(isHandled(universityState, day, classID)):
			continue
		return describeSession(classID, day, true)
	return {}

func isOnTime(session:Dictionary, hourOfDay:int, minuteOfHour:int) -> bool:
	if(session.empty()):
		return false
	if(hourOfDay > int(session["start_hour"])):
		return false
	return minuteOfHour <= ON_TIME_MINUTES

func getAttendanceProgress(onTime:bool, rewardMultiplier:float = 1.0) -> int:
	# Late attendance is worth less than punctual attendance, while still leaving enough room
	# for the central need policy to reduce the reward truthfully (2 -> 1 instead of 1 -> 1).
	var baseProgress:int = 3 if onTime else 2
	return int(max(1, round(baseProgress * rewardMultiplier)))

func recordAttendance(universityState, day:int, classID:String, onTime:bool, rewardMultiplier:float = 1.0):
	var data:Dictionary = getData(universityState)
	data["attended"] = int(data["attended"]) + 1
	data["study_progress"] = int(data["study_progress"]) + getAttendanceProgress(onTime, rewardMultiplier)
	setData(universityState, data)
	markHandled(universityState, day, classID)

func recordMissed(universityState, day:int, classID:String):
	var data:Dictionary = getData(universityState)
	data["missed"] = int(data["missed"]) + 1
	setData(universityState, data)
	markHandled(universityState, day, classID)

func addStudyProgress(universityState, amount:int):
	var data:Dictionary = getData(universityState)
	data["study_progress"] = int(data["study_progress"]) + amount
	setData(universityState, data)

# Writes off any class whose window has passed today without being attended.
func closeMissedClasses(universityState, day:int, hourOfDay:int) -> Array:
	var missed:Array = []
	for classID in getClassesOnDay(day):
		if(isHandled(universityState, day, classID)):
			continue
		if(hourOfDay >= int(CLASSES[classID]["end_hour"])):
			recordMissed(universityState, day, classID)
			missed.append(classID)
	return missed
