extends Node
class_name QuestSystem

var quests: Dictionary = {}

func _ready():
	GM.QS = self
	name = "QuestSystem"
	
	registerQuests()

func registerQuests():
	var loadedquests = GlobalRegistry.getQuests()
	for questID in loadedquests:
		var quest = loadedquests[questID]
		
		quests[questID] = quest

func isCompleted(questID):
	assert(quests.has(questID))
	
	return quests[questID].isCompleted()

func isActive(questID):
	assert(quests.has(questID))
	if(isHiddenByUniversityRoute(questID)):
		return false
	
	return quests[questID].isVisible() && !quests[questID].isCompleted()

# University Sandbox: games with a valid student profile (University route) don't expose
# BDCC's prison/story quests. Quests stay registered; only University-owned ids ("university_")
# would be shown. See Docs/UNIVERSITY_NEW_GAME.md.
const UniversityStudentProfile = preload("res://Game/University/UniversityStudentProfile.gd")
const UNIVERSITY_QUEST_PREFIX = "university_"

func isHiddenByUniversityRoute(questID) -> bool:
	if(str(questID).begins_with(UNIVERSITY_QUEST_PREFIX)):
		return false
	if(GM.main == null || GM.main.get("university") == null):
		return false
	return UniversityStudentProfile.new().isUniversityGame(GM.main.university)

func getQuests():
	return quests

func getAllQuests():
	var result = quests.duplicate()
	
	for datapackID in GM.main.loadedDatapacks:
		var datapack = GlobalRegistry.getDatapack(datapackID)
		if(datapack == null):
			continue
		
		for questID in datapack.quests:
			var datapackQuest = datapack.quests[questID]
			
			var newQuestBase:DatapackQuestBase = DatapackQuestBase.new()
			newQuestBase.id = (datapackID+":"+questID)
			newQuestBase.setDatapackAndQuest(datapack, datapackQuest)
			
			result[datapackID+":"+questID] = newQuestBase
	
	for missionID in GlobalRegistry.missionQuests:
		result["mission#"+missionID] = GlobalRegistry.missionQuests[missionID]
	
	for questID in result.keys():
		if(isHiddenByUniversityRoute(questID)):
			var _removed = result.erase(questID)

	return result
