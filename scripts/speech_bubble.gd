class_name SpeechBubble
extends Sprite3D
## A guest's speech bubble: a dark rounded box with a gold border, the line in white and
## what you understood in gold under it, with a tail whose tip sits on the guest's mouth.
## A small badge on its top right corner says which language they speak (ES, EN).
## The box is drawn into a texture and billboarded, so it turns to face you; it draws over
## the walls, so whoever shows it hides it while a wall is in between.

const BACKGROUND := Color(0.1, 0.1, 0.13, 0.92)
const BORDER := Color(1, 0.8, 0.3)
const BORDER_WIDTH := 2
const FONT_SIZE := 26
const MAX_WIDTH := 440.0 ## pixels; longer lines wrap
const TAIL_HEIGHT := 34.0 ## pixels
const SIDE := 18.0 ## pixels the tail's tip sits beside its base, so the box clears the face
## Room above the box for the language badge, which sits across its top border.
const BADGE_ROOM := 14.0
const BADGE_INSET := 14.0 ## pixels between the badge and the box's right edge
## The badge's colour per language; others get [constant BADGE_OTHER].
const BADGE_COLOURS := {"es": Color(0.75, 0.15, 0.1), "en": Color(0.15, 0.3, 0.6)}
const BADGE_OTHER := Color(0.3, 0.3, 0.35)

var _viewport: SubViewport
var _panel: PanelContainer
var _text: Label
var _under: Label
var _badge: Label
var _tail: Polygon2D
var _tail_fill: Polygon2D


func _init() -> void:
	name = "SpeechBubble"
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 2
	centered = false
	pixel_size = 0.003

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_tail = Polygon2D.new()
	_tail.color = BORDER
	_viewport.add_child(_tail)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.border_color = BORDER
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 11
	box.content_margin_bottom = 11
	_panel.add_theme_stylebox_override("panel", box)
	_viewport.add_child(_panel)
	var lines := VBoxContainer.new()
	_panel.add_child(lines)
	_text = _label(FONT_SIZE, Color.WHITE)
	lines.add_child(_text)
	_under = _label(int(FONT_SIZE * 0.8), BORDER)
	lines.add_child(_under)

	_tail_fill = Polygon2D.new()
	_tail_fill.color = BACKGROUND
	_viewport.add_child(_tail_fill)

	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.add_theme_color_override("font_color", Color.WHITE)
	_badge.hide()
	_viewport.add_child(_badge)
	texture = _viewport.get_texture()
	hide()


static func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Shows [param text], with [param under] beneath it unless that's empty, sized to fit,
## and a badge for [param language] (a code such as "es") unless that's empty.
func set_lines(text: String, under: String, language := "") -> void:
	_text.text = text
	_under.text = under
	_under.visible = not under.is_empty()
	_badge.text = " %s " % language.to_upper()
	_badge.visible = not language.is_empty()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = BADGE_COLOURS.get(language, BADGE_OTHER)
	badge_box.set_corner_radius_all(6)
	badge_box.content_margin_left = 4
	badge_box.content_margin_right = 4
	badge_box.content_margin_top = 2
	badge_box.content_margin_bottom = 2
	_badge.add_theme_stylebox_override("normal", badge_box)
	var width := 0.0
	for l: Label in [_text, _under]:
		var font := l.get_theme_font("font")
		var size := l.get_theme_font_size("font_size")
		width = maxf(width, font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	width = minf(ceilf(width) + 8, MAX_WIDTH)
	_text.custom_minimum_size.x = width
	_under.custom_minimum_size.x = width
	_fit()


func _process(_delta: float) -> void:
	# Redrawn only while it shows: a viewport doesn't count a sprite using it as visible.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if visible:
		_fit()


## Sizes the box, the tail and the texture to the text. A wrapped label only knows its
## height once it has its width, a frame later, so this runs every frame it shows.
func _fit() -> void:
	_panel.reset_size()
	var box := _panel.get_combined_minimum_size()
	_panel.position.y = BADGE_ROOM
	# The badge's middle on the box's top border, a little in from its right edge.
	_badge.reset_size()
	var badge := _badge.get_combined_minimum_size()
	_badge.position = Vector2(box.x - BADGE_INSET - badge.x, BADGE_ROOM - badge.y / 2)

	var bottom := BADGE_ROOM + box.y
	var w := float(BORDER_WIDTH)
	var tip := Vector2(4, bottom + TAIL_HEIGHT - 2)
	_tail.polygon = PackedVector2Array([Vector2(22, bottom - w), Vector2(58, bottom - w), tip])
	_tail_fill.polygon = PackedVector2Array([Vector2(22 + w * 1.5, bottom - w - 1), Vector2(58 - w * 1.5, bottom - w - 1), tip + Vector2(w * 1.7, -w * 2.5)])
	_viewport.size = Vector2i(ceili(box.x), ceili(bottom + TAIL_HEIGHT))
	# The sprite's origin is the texture's bottom-left: shift it so the tail's tip is the origin.
	offset = Vector2(SIDE - tip.x, tip.y - _viewport.size.y)


func text() -> String:
	return _text.text


func language_badge() -> String:
	return _badge.text.strip_edges() if _badge.visible else ""


## Where the box and the badge are in the bubble's texture, in pixels: [box, badge].
func layout() -> Array[Rect2]:
	return [Rect2(_panel.position, _panel.get_combined_minimum_size()), Rect2(_badge.position, _badge.get_combined_minimum_size())]


func under_text() -> String:
	return _under.text
