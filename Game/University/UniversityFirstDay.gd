extends Reference

# University Sandbox first-day objective.
#
# The player's first campus day, stored in the T3 save section as
# university.systems["first_day"]:
#   {
#     "stage": "leave_dorm",   # one of STAGES, in order
#     "completed_on_day": -1,  # game day the sequence finished, -1 while unfinished
#   }
#
# Stages advance only through real player actions (leaving the dorm, talking to the
# orientation coordinator, attending orientation, returning home, sleeping), always in
# order, and each advance is idempotent. validate() is called by
# UniversitySaveSchema.checkCurrentStructure() when the system is present, so malformed
# data rejects the load before anything is applied. The system is optional in schema
# version 1: profile-free legacy saves simply don't have it and never run the sequence.
# See Docs/UNIVERSITY_NEW_GAME.md.

const StudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")

const SYSTEM_ID := "first_day"

const STAGE_LEAVE_DORM := "leave_dorm"
const STAGE_CHECK_IN := "check_in"
const STAGE_ATTEND_ORIENTATION := "attend_orientation"
const STAGE_RETURN_DORM := "return_dorm"
const STAGE_SLEEP := "sleep"
const STAGE_COMPLETE := "complete"

const STAGES := [STAGE_LEAVE_DORM, STAGE_CHECK_IN, STAGE_ATTEND_ORIENTATION, STAGE_RETURN_DORM, STAGE_SLEEP, STAGE_COMPLETE]

const STAGE_OBJECTIVES := {
	STAGE_LEAVE_DORM: "Leave your dorm room and find your way onto campus.",
	STAGE_CHECK_IN: "Check in for orientation at Student Services, east of the quad.",
	STAGE_ATTEND_ORIENTATION: "Attend orientation in the lecture hall, west of the quad.",
	STAGE_RETURN_DORM: "Head back to your dorm room.",
	STAGE_SLEEP: "Get some sleep and finish your first day.",
	STAGE_COMPLETE: "You've settled in. Your first day is over.",
}

func createInitial() -> Dictionary:
	return {
		"stage": STAGE_LEAVE_DORM,
		"completed_on_day": -1,
	}

# Returns "" when the data matches the contract above.
func validate(data) -> String:
	if(!(data is Dictionary)):
		return "First day data is malformed (expected a dictionary)"
	if(!(data.get("stage") is String) || !(data["stage"] in STAGES)):
		return "First day data has an unknown stage '" + str(data.get("stage")) + "'"
	var completedOnDay = data.get("completed_on_day")
	if(!(typeof(completedOnDay) in [TYPE_INT, TYPE_REAL]) || completedOnDay != floor(completedOnDay) || completedOnDay < -1):
		return "First day data has a malformed completion day"
	if(data["stage"] == STAGE_COMPLETE && completedOnDay < 0):
		return "First day data is complete but has no completion day"
	if(data["stage"] != STAGE_COMPLETE && completedOnDay >= 0):
		return "First day data has a completion day but is not complete"
	return ""

# Raw presence of the stored dictionary, whatever game it belongs to.
func hasData(universityState) -> bool:
	return universityState != null && universityState.hasSystemData(SYSTEM_ID)

# The single gate for all gameplay use. A profile-free legacy/T3 save may still carry copied
# first-day data; it stays stored and untouched, but is inert: no stage, no advancement and no
# stage-specific buttons in the campus scenes.
func isActive(universityState) -> bool:
	return hasData(universityState) && StudentProfile.new().isUniversityGame(universityState)

func begin(universityState):
	if(!hasData(universityState)):
		universityState.setSystemData(SYSTEM_ID, createInitial())

func getData(universityState) -> Dictionary:
	if(!isActive(universityState)):
		return {}
	return universityState.getSystemData(SYSTEM_ID)

func getStage(universityState) -> String:
	var data:Dictionary = getData(universityState)
	if(data.empty()):
		return ""
	return str(data.get("stage", STAGE_LEAVE_DORM))

func getStageIndex(universityState) -> int:
	return STAGES.find(getStage(universityState))

func isAtStage(universityState, stage:String) -> bool:
	return getStage(universityState) == stage

# True once the given stage has been passed (or is complete).
func hasReachedStage(universityState, stage:String) -> bool:
	var current:int = getStageIndex(universityState)
	return current >= 0 && current >= STAGES.find(stage)

func isCompleted(universityState) -> bool:
	return getStage(universityState) == STAGE_COMPLETE

func getObjectiveText(universityState) -> String:
	var stage:String = getStage(universityState)
	if(!STAGE_OBJECTIVES.has(stage)):
		return ""
	return STAGE_OBJECTIVES[stage]

# Advances only from `fromStage` to the next stage, so steps can't be skipped and repeating
# a finished interaction changes nothing. Returns true when this call advanced the sequence.
func advanceFrom(universityState, fromStage:String) -> bool:
	if(!isActive(universityState) || !isAtStage(universityState, fromStage)):
		return false
	var nextIndex:int = STAGES.find(fromStage) + 1
	if(nextIndex <= 0 || nextIndex >= STAGES.size()):
		return false
	var data:Dictionary = getData(universityState)
	data["stage"] = STAGES[nextIndex]
	if(data["stage"] == STAGE_COMPLETE):
		data["completed_on_day"] = GM.main.getDays() if GM.main != null else 0
	universityState.setSystemData(SYSTEM_ID, data)
	return true
