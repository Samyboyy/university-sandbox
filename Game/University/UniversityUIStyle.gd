extends Reference

# Shared T7 University interface palette.  Keeping this in one place prevents the hub,
# inherited frame and player showcase from slowly drifting into different themes.
const BACKGROUND := Color("171518")
const RAIL := Color("211e22")
const CARD := Color("101011")
const CARD_RAISED := Color("19171a")
const BORDER := Color("353139")
const TEXT := Color("eee9e5")
const MUTED := Color("aaa3aa")
const LINK := Color("6f9ee8")
const LINK_HOVER := Color("91b7f2")
const MONEY := Color("71d394")
const GOOD := Color("79cf69")
const WARN := Color("e3b64f")
const BAD := Color("df6767")
const CONTEXT := Color("bd6ed8")
const ACCENT := Color("d783aa")

static func panel(colour:Color, radius:int = 10, border:Color = BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style

static func choice(normal_colour:Color = CARD, hover_colour:Color = CARD_RAISED) -> Dictionary:
	var normal := panel(normal_colour, 5, BORDER)
	normal.content_margin_left = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 12.0
	normal.content_margin_bottom = 8.0
	var hover := panel(hover_colour, 5, LINK)
	hover.content_margin_left = 12.0
	hover.content_margin_top = 8.0
	hover.content_margin_right = 12.0
	hover.content_margin_bottom = 8.0
	var pressed := panel(Color("25222a"), 5, LINK_HOVER)
	pressed.content_margin_left = 12.0
	pressed.content_margin_top = 8.0
	pressed.content_margin_right = 12.0
	pressed.content_margin_bottom = 8.0
	return {"normal": normal, "hover": hover, "pressed": pressed}

static func need_colour(value:float, is_pressure:bool, is_contextual:bool = false) -> Color:
	if(is_contextual):
		return CONTEXT if value < 70.0 else BAD
	if(is_pressure):
		return GOOD if value < 50.0 else (WARN if value < 75.0 else BAD)
	return GOOD if value >= 50.0 else (WARN if value >= 25.0 else BAD)

static func bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c292e")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

static func bar_fill(colour:Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
