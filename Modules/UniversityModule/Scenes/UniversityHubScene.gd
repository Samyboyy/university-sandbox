extends "res://Scenes/SceneBase.gd"

# T7 University normal-play shell. Gameplay remains in UniversityDailyLife; this scene only
# presents the same actions, destinations, previews and disabled reasons as clickable controls.
const DailyLife = preload("res://Game/University/UniversityDailyLife.gd")
const Needs = preload("res://Game/University/UniversityNeeds.gd")
const FirstDay = preload("res://Game/University/UniversityFirstDay.gd")
const UIStyle = preload("res://Game/University/UniversityUIStyle.gd")
const NormalFont = preload("res://UI/FontResources/Normal/NormalFont.tres")
const BoldFont = preload("res://UI/FontResources/Normal/BoldFont.tres")

const STATUS_PANEL_ID := "university_status_panel"
const MAIN_PANEL_ID := "university_main_panel"
const NEEDS_BAR_MIN_WIDTH := 104.0

var dailyLife = DailyLife.new()
var needs = Needs.new()
var firstDay = FirstDay.new()
var lastResult:String = ""
var currentPose:Array = ["Solo", "stand"]
var compactFont = null
var bodyFont = null
var headingFont = null

func _init():
	sceneID = "UniversityHubScene"
	compactFont = NormalFont.duplicate()
	compactFont.size = 15
	bodyFont = NormalFont.duplicate()
	bodyFont.size = 18
	headingFont = BoldFont.duplicate()
	headingFont.size = 24

func _initScene(_args = []):
	dailyLife.ensureState()

func getUniversityState():
	return dailyLife.getUniversityState()

func _run():
	# This is the sole presentation switch: invalid/profile-free games retain the original UI.
	if(!dailyLife.isActive()):
		GM.ui.setUniversityMode(false)
		runScene("WorldScene")
		endScene()
		return
	dailyLife.ensureState()
	GM.ui.setUniversityMode(true)
	GM.ui.setUniversityCustomOptions(true)
	var locationID:String = dailyLife.getCurrentLocationID()
	setLocationName(dailyLife.locations.getName(locationID))
	playAnimation(currentPose[0], currentPose[1])
	addStatusPanel(locationID)
	addAccessibilityMirror(locationID)
	addMainPanel(locationID)

# --- left information rail --------------------------------------------------------

func addStatusPanel(_locationID:String):
	var universityState = getUniversityState()
	var panel := PanelContainer.new()
	panel.name = "UniversityStatusPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_stylebox_override("panel", UIStyle.panel(UIStyle.RAIL, 0, UIStyle.RAIL))

	var rows := VBoxContainer.new()
	rows.name = "StatusRows"
	rows.add_constant_override("separation", 10)
	panel.add_child(rows)

	var headline := Label.new()
	headline.name = "StatusHeadline"
	headline.text = "$" + str(GM.pc.getCredits())
	headline.add_color_override("font_color", UIStyle.MONEY)
	headline.add_font_override("font", headingFont)
	rows.add_child(headline)

	var clock := Label.new()
	clock.name = "StatusClock"
	clock.text = "◷  " + dailyLife.getTimeString() + "\n▣  " + dailyLife.getDayString()
	clock.add_color_override("font_color", UIStyle.TEXT)
	clock.add_font_override("font", bodyFont)
	rows.add_child(clock)

	rows.add_child(HSeparator.new())

	var obligation := Label.new()
	obligation.name = "StatusObligation"
	obligation.autowrap = true
	obligation.text = getObligationText()
	obligation.add_color_override("font_color", UIStyle.MUTED)
	obligation.add_font_override("font", compactFont)
	rows.add_child(obligation)

	var needsGrid := GridContainer.new()
	needsGrid.name = "NeedsGrid"
	needsGrid.columns = 2
	needsGrid.add_constant_override("hseparation", 10)
	needsGrid.add_constant_override("vseparation", 7)
	needsGrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(needsGrid)
	for needID in Needs.NEEDS:
		needsGrid.add_child(makeNeedBar(needID, universityState, false))

	var contextual:Array = needs.getVisibleContextual(universityState)
	if(!contextual.empty()):
		var contextualTitle := Label.new()
		contextualTitle.text = "Current pressures"
		contextualTitle.add_color_override("font_color", UIStyle.ACCENT)
		contextualTitle.add_font_override("font", compactFont)
		rows.add_child(contextualTitle)
		var contextualGrid := GridContainer.new()
		contextualGrid.name = "ContextualGrid"
		contextualGrid.columns = 2
		contextualGrid.add_constant_override("hseparation", 10)
		rows.add_child(contextualGrid)
		for meterID in contextual:
			contextualGrid.add_child(makeNeedBar(meterID, universityState, true))

	GM.ui.setUniversityInfoControl(STATUS_PANEL_ID, panel)

func makeNeedBar(needID:String, universityState, contextual:bool) -> Control:
	var value:float = needs.getValue(universityState, needID)
	var box := VBoxContainer.new()
	box.name = "Need_" + needID
	box.rect_min_size = Vector2(NEEDS_BAR_MIN_WIDTH, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.text = needs.getName(needID) + "  " + str(int(round(value)))
	label.add_color_override("font_color", UIStyle.TEXT)
	label.add_font_override("font", compactFont)
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = Needs.MIN_VALUE
	bar.max_value = Needs.MAX_VALUE
	bar.value = value
	bar.percent_visible = false
	bar.rect_min_size = Vector2(NEEDS_BAR_MIN_WIDTH, 9)
	bar.add_stylebox_override("bg", UIStyle.bar_background())
	bar.add_stylebox_override("fg", UIStyle.bar_fill(UIStyle.need_colour(value, needID in Needs.PRESSURES, contextual)))
	box.add_child(bar)
	return box

func getObligationText() -> String:
	var universityState = getUniversityState()
	var lines:Array = []
	var nextClass:Dictionary = dailyLife.timetable.getNextClass(universityState, GM.main.getDays(), dailyLife.getHourOfDay())
	if(!nextClass.empty()):
		lines.append("Next class\n" + str(nextClass["name"]) + "\n" + dailyLife.timetable.describeWhen(nextClass)
			+ " · " + dailyLife.locations.getName(nextClass["location"]))
	if(!firstDay.isCompleted(universityState) && firstDay.isActive(universityState)):
		lines.append("Objective\n" + firstDay.getObjectiveText(universityState))
	if(lines.empty()):
		return "No scheduled obligations."
	return PoolStringArray(lines).join("\n\n")

# TextOutput is hidden in this shell, but retaining a plain status mirror keeps translation,
# accessibility extraction and older automation consumers useful without duplicating the UI.
func addAccessibilityMirror(locationID:String):
	var universityState = getUniversityState()
	say(dailyLife.locations.getName(locationID) + "  " + dailyLife.getTimeString() + "  " + dailyLife.getDayString() + "  $" + str(GM.pc.getCredits()) + "\n")
	say("Next: " + getObligationText() + "\n")
	for needID in Needs.NEEDS:
		say(needs.getName(needID) + " " + str(int(round(needs.getValue(universityState, needID)))) + " ")
	say("\n")

# --- central location card --------------------------------------------------------

func addMainPanel(locationID:String):
	var card := PanelContainer.new()
	card.name = "UniversityMainPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_stylebox_override("panel", UIStyle.panel(UIStyle.CARD, 12, UIStyle.BORDER))

	var content := VBoxContainer.new()
	content.name = "UniversityMainContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_constant_override("separation", 10)
	card.add_child(content)

	var title := Label.new()
	title.name = "LocationTitle"
	title.text = dailyLife.locations.getName(locationID)
	title.add_color_override("font_color", UIStyle.TEXT)
	title.add_font_override("font", headingFont)
	content.add_child(title)

	var description := Label.new()
	description.name = "LocationDescription"
	description.autowrap = true
	description.text = dailyLife.locations.getDescription(locationID)
	description.add_color_override("font_color", UIStyle.MUTED)
	description.add_font_override("font", bodyFont)
	content.add_child(description)

	if(lastResult != ""):
		var resultPanel := PanelContainer.new()
		resultPanel.name = "LastResult"
		resultPanel.add_stylebox_override("panel", UIStyle.panel(UIStyle.CARD_RAISED, 6, UIStyle.ACCENT))
		var resultLabel := Label.new()
		resultLabel.autowrap = true
		resultLabel.text = lastResult
		resultLabel.add_color_override("font_color", UIStyle.TEXT)
		resultLabel.add_font_override("font", bodyFont)
		resultPanel.add_child(resultLabel)
		content.add_child(resultPanel)
		lastResult = ""

	addSectionHeading(content, "What you can do here")
	var shortcut:int = 1
	for actionID in dailyLife.getActionsHere():
		var action:Dictionary = dailyLife.getAction(actionID)
		var preview:String = dailyLife.getActionPreview(actionID)
		var label:String = "[" + str(shortcut) + "]  " + str(action["name"])
		var blockReason:String = dailyLife.getActionBlockReason(actionID)
		addInlineChoice(content, label, preview, str(action.get("desc", "")), "doaction", [actionID], blockReason)
		shortcut += 1

	addSectionHeading(content, "Where you can go")
	for destinationID in dailyLife.getDestinations():
		var minutes:int = dailyLife.locations.getTravelMinutes(destinationID)
		var label:String = "Go: " + dailyLife.locations.getName(destinationID) + "  (" + str(minutes) + " min)"
		var closedReason:String = dailyLife.getClosedReason(destinationID)
		addInlineChoice(content, label, "", "Travel there", "travel", [destinationID], closedReason)
		shortcut += 1

	GM.ui.addUniversityMainControl(MAIN_PANEL_ID, card)

func addSectionHeading(parent:Control, text:String):
	var spacer := Control.new()
	spacer.rect_min_size.y = 8
	parent.add_child(spacer)
	var heading := Label.new()
	heading.text = text
	heading.add_color_override("font_color", UIStyle.ACCENT)
	heading.add_font_override("font", bodyFont)
	parent.add_child(heading)

func addInlineChoice(parent:Control, text:String, preview:String, tooltip:String, method:String, args:Array, disabledReason:String):
	var enabled:bool = disabledReason == ""
	var registryText:String = text + ("  (" + preview + ")" if preview != "" else "")
	# Preserve the engine's option registry and keyboard/test semantics while hiding its old grid.
	if(enabled):
		addButton(registryText, tooltip, method, args)
	else:
		addDisabledButton(registryText, disabledReason)

	var button := Button.new()
	button.name = "UniversityChoice"
	button.text = text
	button.hint_tooltip = tooltip if enabled else disabledReason
	button.disabled = !enabled
	button.align = Button.ALIGN_LEFT
	button.rect_min_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_color_override("font_color", UIStyle.LINK)
	button.add_color_override("font_color_hover", UIStyle.LINK_HOVER)
	button.add_color_override("font_color_disabled", UIStyle.MUTED)
	button.add_font_override("font", bodyFont)
	var styles:Dictionary = UIStyle.choice()
	button.add_stylebox_override("normal", styles["normal"])
	button.add_stylebox_override("hover", styles["hover"])
	button.add_stylebox_override("pressed", styles["pressed"])
	button.add_stylebox_override("disabled", UIStyle.panel(UIStyle.CARD, 5, UIStyle.BORDER))
	if(enabled):
		button.connect("pressed", self, "_onInlineChoice", [method, args])
	parent.add_child(button)
	if(preview != "" || disabledReason != ""):
		var detail := Label.new()
		detail.name = "UniversityChoiceDetail"
		detail.autowrap = true
		detail.text = disabledReason if disabledReason != "" else preview
		detail.add_color_override("font_color", UIStyle.BAD if disabledReason != "" else UIStyle.MUTED)
		detail.add_font_override("font", compactFont)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(detail)

func _onInlineChoice(method:String, args:Array):
	GM.ui.emit_signal("on_option_button", method, args)

# --- reactions -------------------------------------------------------------------

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
			# The generic inline presenter keeps the University shell around T5 scene flows.
			runScene(str(action["scene"]))
			return
		lastResult = dailyLife.performAction(actionID)
		return

	setState(_action)

func _react_scene_end(_tag, _result):
	dailyLife.ensureState()
