extends Reference

# Data-driven University destinations.
#
# Each destination wraps an existing world room (so saving, events and the inherited room
# registry keep working) and adds what the destination-based interface needs: a display name,
# original description, travel time and access rules. Add a location by adding one entry here
# plus its room in Modules/UniversityModule/World/UniversityDormFloor.tscn.
# See Docs/UNIVERSITY_LIFE.md.

const MINUTE := 60

# travel_minutes: time to reach this destination from anywhere else on campus.
# opens/closes: hour-of-day window (24h). null means always open.
const LOCATIONS := {
	"dorm_room": {
		"name": "Private Dorm Room",
		"room": "university_private_dorm",
		"travel_minutes": 5,
		"area": "residence",
		"description": "Your own room: a single bed, a desk under the window, a wardrobe and the boxes you still haven't finished unpacking.",
	},
	"dorm_bathroom": {
		"name": "Dorm Bathroom",
		"room": "university_dorm_bathroom",
		"travel_minutes": 2,
		"area": "residence",
		"description": "Shared showers and toilets at the end of the corridor. Someone has taped a rota to the mirror that nobody follows.",
	},
	"dorm_common": {
		"name": "Dorm Common Room",
		"room": "university_dorm_lobby",
		"travel_minutes": 3,
		"area": "residence",
		"description": "Mismatched sofas, a kettle, a noticeboard layered with flyers, and whoever is avoiding their reading this evening.",
	},
	"quad": {
		"name": "Campus Quad",
		"room": "university_quad",
		"travel_minutes": 6,
		"area": "campus",
		"description": "A wide lawn criss-crossed by paths and bike racks, with the rest of campus signposted around its edges.",
	},
	"student_services": {
		"name": "Student Services",
		"room": "university_student_services",
		"travel_minutes": 8,
		"area": "campus",
		"opens": 8,
		"closes": 18,
		"closed_reason": "Student Services is closed until 8am.",
		"description": "A bright reception office: a queue rope nobody uses, a rack of leaflets and a long desk.",
	},
	"lecture_hall": {
		"name": "Lecture Hall",
		"room": "university_lecture_hall",
		"travel_minutes": 9,
		"area": "campus",
		"opens": 7,
		"closes": 22,
		"closed_reason": "The lecture hall is locked outside teaching hours.",
		"description": "A raked hall of folding seats facing a projector screen and a scuffed lectern.",
	},
	"cafeteria": {
		"name": "Cafeteria",
		"room": "university_cafeteria",
		"travel_minutes": 7,
		"area": "campus",
		"opens": 7,
		"closes": 20,
		"closed_reason": "The cafeteria is shut for the night.",
		"description": "Long tables, a hot counter with an optimistic menu board, and the permanent smell of coffee and chips.",
	},
	"library": {
		"name": "Library",
		"room": "university_library",
		"travel_minutes": 8,
		"area": "campus",
		"opens": 8,
		"closes": 23,
		"closed_reason": "The library is closed at this hour.",
		"description": "Quiet desks under high windows, a wall of terminals, and shelves that go back further than you expected.",
	},
}

func getAll() -> Dictionary:
	return LOCATIONS

func getIDs() -> Array:
	return LOCATIONS.keys()

func hasLocation(locationID) -> bool:
	return locationID is String && LOCATIONS.has(locationID)

# Named getLocation(), not get(): Object.get() must not be shadowed.
func getLocation(locationID) -> Dictionary:
	if(!hasLocation(locationID)):
		return {}
	return LOCATIONS[locationID]

func getName(locationID) -> String:
	return str(getLocation(locationID).get("name", "Unknown"))

func getDescription(locationID) -> String:
	return str(getLocation(locationID).get("description", ""))

func getRoomID(locationID) -> String:
	return str(getLocation(locationID).get("room", ""))

func getTravelMinutes(locationID) -> int:
	return int(getLocation(locationID).get("travel_minutes", 5))

# Which destination a world room belongs to, so a loaded save resolves to the right place.
func getLocationIDForRoom(roomID) -> String:
	for locationID in LOCATIONS:
		if(LOCATIONS[locationID]["room"] == roomID):
			return locationID
	return ""

# Returns "" when open, otherwise the player-facing reason it can't be entered.
func getClosedReason(locationID, hourOfDay:int) -> String:
	var location:Dictionary = getLocation(locationID)
	if(location.empty()):
		return "You don't know how to get there."
	if(!location.has("opens") || !location.has("closes")):
		return ""
	if(hourOfDay >= int(location["opens"]) && hourOfDay < int(location["closes"])):
		return ""
	return str(location.get("closed_reason", "That's closed right now."))

func isOpen(locationID, hourOfDay:int) -> bool:
	return getClosedReason(locationID, hourOfDay) == ""
