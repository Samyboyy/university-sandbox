extends "res://Inventory/Items/Clothes/CasualClothes.gd"

# Placeholder University Sandbox starter outfit.
# Reuses BDCC's plain shirt-and-shorts model and state (CasualClothes) with neutral,
# non-prison wording. No buffs, style tags or stats. Replace when real student clothing exists.

func _init():
	id = "UniversityStarterClothes"

func getVisibleName():
	return "Plain T-shirt and shorts"

func getDescription():
	return "An ordinary T-shirt and a pair of shorts. Comfortable, clean and completely forgettable."

func getTakingOffStringLong(withS):
	if(withS):
		return "pulls off your T-shirt and pulls down the shorts"
	else:
		return "pull off your T-shirt and pull down the shorts"

func getPuttingOnStringLong(withS):
	if(withS):
		return "puts on your T-shirt and the shorts"
	else:
		return "put on your T-shirt and the shorts"
