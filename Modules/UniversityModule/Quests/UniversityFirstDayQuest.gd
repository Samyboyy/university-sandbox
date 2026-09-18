extends QuestBase

# The player's first campus day, shown in the existing Tasks screen. Reads the
# University first-day state; it holds no state of its own. Its id uses the
# "university_" prefix, so QuestSystem's containment keeps it visible while legacy
# BDCC quests stay hidden.

const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")
const StudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")

func _init():
	id = "university_first_day"

func getVisibleName():
	return "Your first day"

func isMainQuest():
	return true

func getPriority():
	return 100

func getFirstDay():
	return FirstDay.new()

func getUniversityState():
	if(GM.main == null || GM.main.get("university") == null):
		return null
	return GM.main.university

# University games only: a legacy/T3 game that happens to carry first-day data (for example a
# save derived from a University one) must not run or show the objective.
func isUniversityGame() -> bool:
	return StudentProfile.new().isUniversityGame(getUniversityState())

func isVisible():
	return isUniversityGame() && getFirstDay().isActive(getUniversityState())

func isCompleted():
	return isUniversityGame() && getFirstDay().isCompleted(getUniversityState())

func getProgress():
	var firstDay = getFirstDay()
	var universityState = getUniversityState()
	if(!isUniversityGame() || !firstDay.isActive(universityState)):
		return []
	var result:Array = []
	var currentIndex:int = firstDay.getStageIndex(universityState)
	for i in range(FirstDay.STAGES.size() - 1):
		var stage:String = FirstDay.STAGES[i]
		var text:String = FirstDay.STAGE_OBJECTIVES[stage]
		if(i < currentIndex):
			result.append("[s]" + text + "[/s]")
		elif(i == currentIndex):
			result.append("[b]" + text + "[/b]")
	if(firstDay.isCompleted(universityState)):
		result.append(FirstDay.STAGE_OBJECTIVES[FirstDay.STAGE_COMPLETE])
	return result
