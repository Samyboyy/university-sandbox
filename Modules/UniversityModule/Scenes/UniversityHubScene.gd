extends "res://Scenes/SceneBase.gd"

# The University life interface: the normal-play screen for a valid University game.
#
# Layout, using the inherited scene/GameUI frame so the layered character doll stays visible
# in the stage panel throughout ordinary play:
#   - status block: location, time, day, money, next obligation, needs bars, contextual meters
#   - location block: title and description
#   - numbered action buttons with their time cost and previewed need effects
#   - destination buttons with travel time, disabled with a reason when closed
# All gameplay resolution happens in UniversityDailyLife; this scene only presents it.
# See Docs/UNIVERSITY_LIFE.md.

const DailyLife = preload("res://Game/University/UniversityDailyLife.gd")
const Needs = preload("res://Game/University/UniversityNeeds.gd")
const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")

# Original University Sandbox palette: charcoal surfaces, muted purple, restrained rose accents.
const COLOUR_ACCENT := "#e8a0bf"   # rose: headings and the player's own state
const COLOUR_INFO := "#9db8e8"     # muted blue: navigation and information
const COLOUR_GOOD := "#7ad4a0"     # green: wellbeing
const COLOUR_WARN := "#ffc46b"     # amber: warnings
const COLOUR_MUTED := "#b9a8c4"    # muted purple: secondary text

const STATUS_PANEL_ID := "university_status_panel"
const NEEDS_BAR_MIN_WIDTH := 120.0 # keeps two bar columns readable at 1280x720

var dailyLife = DailyLife.new()
var needs = Needs.new()
var firstDay = FirstDay.new()
var lastResult:String = ""
var currentPose:Array = ["Solo", "stand"] # activity shown by the persistent character showcase

func _init():
	sceneID = "UniversityHubScene"

func _initScene(_args = []):
	dailyLife.ensureState()

func getUniversityState():
	return dailyLife.getUniversityState()

func _run():
	# University-only interface: a legacy/profile-free game falls back to the inherited world.
	if(!dailyLife.isActive()):
		runScene("WorldScene")
		endScene()
		return
	dailyLife.ensureState()
	var locationID:String = dailyLife.getCurrentLocationID()
	aimCamera(dailyLife.locations.getRoomID(locationID))
	setLocationName(dailyLife.locations.getName(locationID))
	# The showcase reflects what the player just did, not a permanent standing pose.
	playAnimation(currentPose[0], currentPose[1])

	addStatusPanel(locationID)
	sayStatusBlock(locationID)
	sayLocationBlock(locationID)
	addActionButtons(locationID)
	addDestinationButtons()

# --- persistent information region -------------------------------------------------

# An additive University shell built from real Godot controls, added into the inherited
# GameUI text container (which is already inside a scroll container, so it scrolls and keeps
# keyboard/button behaviour). The proven GameUI itself is untouched.
func addStatusPanel(locationID:String):
	var universityState = getUniversityState()
	var panel := PanelContainer.new()
	panel.name = "UniversityStatusPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rows := VBoxContainer.new()
	rows.name = "StatusRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(rows)

	var headline := Label.new()
	headline.name = "StatusHeadline"
	headline.autowrap = true
	headline.text = dailyLife.locations.getName(locationID) + "   " + dailyLife.getTimeString() \
		+ "   " + dailyLife.getDayString() + "   " + str(GM.pc.getCredits()) + " credits"
	rows.add_child(headline)

	var obligation := Label.new()
	obligation.name = "StatusObligation"
	obligation.autowrap = true
	obligation.text = getObligationText()
	rows.add_child(obligation)

	var needsGrid := GridContainer.new()
	needsGrid.name = "NeedsGrid"
	needsGrid.columns = 4
	needsGrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(needsGrid)
	for needID in Needs.NEEDS:
		needsGrid.add_child(makeNeedBar(needID, universityState))

	var contextual:Array = needs.getVisibleContextual(universityState)
	if(!contextual.empty()):
		var contextualGrid := GridContainer.new()
		contextualGrid.name = "ContextualGrid"
		contextualGrid.columns = 4
		rows.add_child(contextualGrid)
		for meterID in contextual:
			contextualGrid.add_child(makeNeedBar(meterID, universityState))

	GM.ui.addCustomControl(STATUS_PANEL_ID, panel)

func makeNeedBar(needID:String, universityState) -> Control:
	var box := VBoxContainer.new()
	box.name = "Need_" + needID
	box.rect_min_size = Vector2(NEEDS_BAR_MIN_WIDTH, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.name = "Label"
	label.text = needs.getName(needID) + " " + str(int(round(needs.getValue(universityState, needID))))
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = Needs.MIN_VALUE
	bar.max_value = Needs.MAX_VALUE
	bar.value = needs.getValue(universityState, needID)
	bar.percent_visible = false
	bar.rect_min_size = Vector2(NEEDS_BAR_MIN_WIDTH, 14)
	box.add_child(bar)
	return box

func getObligationText() -> String:
	var universityState = getUniversityState()
	var parts:Array = []
	var nextClass:Dictionary = dailyLife.timetable.getNextClass(universityState, GM.main.getDays(), dailyLife.getHourOfDay())
	if(!nextClass.empty()):
		parts.append("Next: " + str(nextClass["name"]) + ", " + dailyLife.timetable.describeWhen(nextClass)
			+ ", " + dailyLife.locations.getName(nextClass["location"]))
	if(!firstDay.isCompleted(universityState) && firstDay.isActive(universityState)):
		parts.append("Objective: " + firstDay.getObjectiveText(universityState))
	if(parts.empty()):
		return "No scheduled obligations."
	return PoolStringArray(parts).join("    ")

func sayStatusBlock(locationID:String):
	var universityState = getUniversityState()
	say("[color=" + COLOUR_ACCENT + "][b]" + dailyLife.locations.getName(locationID) + "[/b][/color]   "
		+ "[color=" + COLOUR_INFO + "]" + dailyLife.getTimeString() + "  " + dailyLife.getDayString() + "[/color]   "
		+ "[color=" + COLOUR_GOOD + "]" + str(GM.pc.getCredits()) + " credits[/color]\n")

	say("[color=" + COLOUR_WARN + "]" + getObligationText() + "[/color]\n")
	# Text mirror of the bars: keeps the needs searchable/readable for screen text and tests.
	var barLine:String = ""
	var column:int = 0
	for needID in Needs.NEEDS:
		barLine += needs.getBarText(universityState, needID) + "    "
		column += 1
		if(column % 4 == 0):
			barLine += "\n"
	say(barLine + "\n")

# --- main location region ----------------------------------------------------------

func sayLocationBlock(locationID:String):
	saynn("[color=" + COLOUR_MUTED + "]" + dailyLife.locations.getDescription(locationID) + "[/color]")
	if(lastResult != ""):
		saynn("[color=" + COLOUR_ACCENT + "]" + lastResult + "[/color]")
		lastResult = ""

func addActionButtons(_locationID:String):
	saynn("[color=" + COLOUR_INFO + "][b]What you can do here[/b][/color]")
	var shortcut:int = 1
	for actionID in dailyLife.getActionsHere():
		var action:Dictionary = dailyLife.getAction(actionID)
		var preview:String = dailyLife.getActionPreview(actionID)
		var label:String = str(shortcut) + ". " + str(action["name"])
		if(preview != ""):
			label += "  (" + preview + ")"
		var blockReason:String = dailyLife.getActionBlockReason(actionID)
		if(blockReason == ""):
			addButton(label, str(action.get("desc", "")), "doaction", [actionID])
		else:
			addDisabledButton(label, blockReason)
		shortcut += 1

func addDestinationButtons():
	saynn("[color=" + COLOUR_INFO + "][b]Where you can go[/b][/color]")
	for destinationID in dailyLife.getDestinations():
		var minutes:int = dailyLife.locations.getTravelMinutes(destinationID)
		var label:String = "Go: " + dailyLife.locations.getName(destinationID) + "  (" + str(minutes) + " min)"
		var closedReason:String = dailyLife.getClosedReason(destinationID)
		if(closedReason == ""):
			addButton(label, "Travel there, taking " + str(minutes) + " minutes", "travel", [destinationID])
		else:
			addDisabledButton(label, closedReason)

# --- reactions ---------------------------------------------------------------------

func _react(_action: String, _args):
	if(_action == "travel"):
		var destinationID = _args[0] if _args.size() > 0 else ""
		if(dailyLife.travelTo(destinationID)):
			currentPose = DailyLife.DEFAULT_ANIMATION
			lastResult = "You walk over to " + dailyLife.locations.getName(destinationID) + "."
		return

	if(_action == "doaction"):
		var actionID = _args[0] if _args.size() > 0 else ""
		var action:Dictionary = dailyLife.getAction(actionID)
		if(action.empty() || !(actionID in dailyLife.getActionsHere())):
			return
		if(dailyLife.getActionBlockReason(actionID) != ""):
			lastResult = dailyLife.getActionBlockReason(actionID)
			return
		currentPose = dailyLife.getActionAnimation(actionID)
		if(action.has("scene")):
			# Inherited T5 scenes keep their own text and flow.
			runScene(str(action["scene"]))
			return
		lastResult = dailyLife.performAction(actionID)
		return

	setState(_action)

func _react_scene_end(_tag, _result):
	dailyLife.ensureState()
