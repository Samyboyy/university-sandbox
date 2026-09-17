extends Reference

# University Sandbox student profile.
#
# The long-lived record of who the player is as a University student. Stored in the T3
# save section as university.systems["student_profile"]:
#   {
#     "onboarding_completed": bool,              # false while the player is still in creation
#     "student_year": 1,                         # whole number >= 1 (1 = first year)
#     "housing_id": "university_private_dorm",   # the player's room
#     "route": "university",                     # the new-game route that created the profile
#     "is_adult": true,                          # every University student is an adult
#   }
#
# validate() is called by UniversitySaveSchema.checkCurrentStructure() when the system is
# present, so malformed data rejects the load before anything is applied. The system is
# optional in schema version 1: saves without it (T3 era) still load, and simply aren't
# treated as University-route games. See Docs/UNIVERSITY_NEW_GAME.md.

const SYSTEM_ID := "student_profile"
const ROUTE_ID := "university"
const DORM_ROOM_ID := "university_private_dorm"
const SUPPORTED_HOUSING_IDS := [DORM_ROOM_ID]
const FIRST_YEAR := 1

func createInitial() -> Dictionary:
	return {
		"onboarding_completed": false,
		"student_year": FIRST_YEAR,
		"housing_id": DORM_ROOM_ID,
		"route": ROUTE_ID,
		"is_adult": true,
	}

# Returns "" when the data matches the contract above.
func validate(data) -> String:
	if(!(data is Dictionary)):
		return "Student profile is malformed (expected a dictionary)"
	if(typeof(data.get("onboarding_completed")) != TYPE_BOOL):
		return "Student profile has a malformed onboarding flag"
	var year = data.get("student_year")
	if(!(typeof(year) in [TYPE_INT, TYPE_REAL]) || year != floor(year) || year < FIRST_YEAR):
		return "Student profile has a malformed student year"
	if(!(data.get("housing_id") is String) || !(data["housing_id"] in SUPPORTED_HOUSING_IDS)):
		return "Student profile has unsupported housing '" + str(data.get("housing_id")) + "'"
	if(!(data.get("route") is String) || data["route"] != ROUTE_ID):
		return "Student profile has an unknown route '" + str(data.get("route")) + "'"
	if(typeof(data.get("is_adult")) != TYPE_BOOL):
		return "Student profile has a malformed adult flag"
	if(data["is_adult"] != true):
		return "Student profile is not marked as an adult"
	return ""

# A University-route game is one whose state holds a valid student profile.
func isUniversityGame(universityState) -> bool:
	if(universityState == null || !universityState.hasSystemData(SYSTEM_ID)):
		return false
	return validate(universityState.getSystemData(SYSTEM_ID)) == ""

func begin(universityState):
	universityState.setSystemData(SYSTEM_ID, createInitial())

func completeOnboarding(universityState):
	var data:Dictionary = universityState.getSystemData(SYSTEM_ID)
	if(data.empty()):
		data = createInitial()
	data["onboarding_completed"] = true
	universityState.setSystemData(SYSTEM_ID, data)

func isOnboardingCompleted(universityState) -> bool:
	if(!isUniversityGame(universityState)):
		return false
	return universityState.getSystemData(SYSTEM_ID).get("onboarding_completed", false) == true
