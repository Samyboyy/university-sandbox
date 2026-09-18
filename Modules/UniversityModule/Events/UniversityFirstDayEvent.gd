extends EventBase

# Advances the first-day objective from real movement: leaving the dorm room onto campus,
# and coming home again when orientation is done. Shows the current objective when the
# player arrives somewhere on campus.

const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")
const StudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")

const CAMPUS_ROOM_IDS := ["university_dorm_corridor", "university_dorm_lobby", "university_quad",
	"university_student_services", "university_lecture_hall"]
const DORM_ROOM_ID := "university_private_dorm"

func _init():
	id = "UniversityFirstDayEvent"

func registerTriggers(es):
	es.addTrigger(self, Trigger.EnteringRoom)

func getPriority():
	return 0

func getFirstDay():
	return FirstDay.new()

func run(_triggerID, _args):
	if(_args.size() == 0 || GM.main == null || GM.main.get("university") == null):
		return
	var roomID = _args[0]
	var firstDay = getFirstDay()
	var universityState = GM.main.university
	# University games only (valid student profile), so legacy/T3 games are untouched.
	if(!StudentProfile.new().isUniversityGame(universityState) || !firstDay.isActive(universityState)):
		return

	if(roomID in CAMPUS_ROOM_IDS):
		var _left = firstDay.advanceFrom(universityState, FirstDay.STAGE_LEAVE_DORM)
	if(roomID == DORM_ROOM_ID):
		var _home = firstDay.advanceFrom(universityState, FirstDay.STAGE_RETURN_DORM)

	if(!firstDay.isCompleted(universityState)):
		saynn("[i]Objective: " + firstDay.getObjectiveText(universityState) + "[/i]")
