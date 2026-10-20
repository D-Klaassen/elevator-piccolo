class_name StaffRoom
extends PanelContainer
## The staff room between shifts: the bank balance, every upgrade with its level and the
## price of the next one, and what it takes to move up to the next hotel. Buying pays from
## the balance straight away; the upgrade is in the cab from the next shift on. Moving up
## pays the application fee, and the next shift is in the new hotel. From the last hotel
## you apply to the Grand Hotel instead, which ends the demo.

signal bought(id: String)
signal moved
signal finished
signal started
signal settings_opened

var _career: Career
var _title: Label
var _balance: Label
var _next_hotel: VBoxContainer
var _next_name: Label
var _next_terms: Label
var _apply: Button
var _rows := {} ## upgrade id -> {"level": Label, "next": Label, "buy": Button}
var _start: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 20)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_balance)

	for upgrade in Upgrades.CATALOGUE:
		box.add_child(_build_row(upgrade))

	box.add_child(HSeparator.new())
	box.add_child(_build_next_hotel())

	_start = Button.new()
	_start.name = "StartShift"
	_start.text = "Start the shift"
	_start.pressed.connect(started.emit)
	box.add_child(_start)

	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "Settings"
	settings.pressed.connect(settings_opened.emit)
	box.add_child(settings)
	hide()


func _build_row(upgrade: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", 20)
	text.add_child(level)
	var next := Label.new()
	next.modulate = Color(1, 1, 1, 0.7)
	text.add_child(next)

	var buy := Button.new()
	buy.name = "Buy_%s" % upgrade.id
	buy.custom_minimum_size = Vector2(110, 0)
	buy.pressed.connect(_buy.bind(upgrade.id))
	row.add_child(buy)

	_rows[upgrade.id] = {"level": level, "next": next, "buy": buy}
	return row


## The next hotel: its name, what it takes to get in, and the button to apply.
func _build_next_hotel() -> Control:
	_next_hotel = VBoxContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_next_hotel.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_next_name = Label.new()
	_next_name.add_theme_font_size_override("font_size", 20)
	text.add_child(_next_name)
	_next_terms = Label.new()
	_next_terms.modulate = Color(1, 1, 1, 0.7)
	text.add_child(_next_terms)

	_apply = Button.new()
	_apply.name = "MoveUp"
	_apply.custom_minimum_size = Vector2(110, 0)
	_apply.pressed.connect(_move_up)
	row.add_child(_apply)
	return _next_hotel


func show_for(career: Career) -> void:
	_career = career
	_refresh()
	show()
	_start.grab_focus()


func _buy(id: String) -> void:
	if _career.buy(id):
		bought.emit(id)
	_refresh()


func _move_up() -> void:
	if _career.can_finish_demo():
		finished.emit()
	elif _career.move_up():
		moved.emit()
	_refresh()


func _refresh() -> void:
	_title.text = "Staff room · %s" % _career.hotel_info().name
	_refresh_next_hotel()
	_balance.text = "Bank balance: €%.2f" % _career.balance
	for upgrade in Upgrades.CATALOGUE:
		var row: Dictionary = _rows[upgrade.id]
		var buy: Button = row.buy
		buy.get_parent().visible = Upgrades.is_sold_at(upgrade.id, _career.hotel)
		var l := _career.level(upgrade.id)
		var top := Upgrades.max_level(upgrade.id)
		row.level.text = "%s   level %d of %d" % [upgrade.name, l, top]
		if l >= top:
			row.next.text = "Fully upgraded"
			buy.text = "Done"
			buy.disabled = true
		else:
			row.next.text = "Next: %s" % upgrade.effects[l]
			buy.text = "Buy €%d" % _career.next_price(upgrade.id)
			buy.disabled = not _career.can_buy(upgrade.id)


func _refresh_next_hotel() -> void:
	var next := Hotels.next_after(_career.hotel)
	_next_name.text = "Move up to %s (%d floors)" % [next.name, next.floors]
	var rating := "%s: %.1f ★" % [
		"Last %d shifts" % Career.AVERAGE_OVER if _career.ratings.size() >= Career.AVERAGE_OVER
			else "%d of %d shifts so far" % [_career.ratings.size(), Career.AVERAGE_OVER],
		_career.average_rating(),
	]
	var needs := "Needs %.0f ★ on average over your last %d shifts (%s)" % [
		Hotels.UNLOCK_STARS, Career.AVERAGE_OVER, rating]
	if Hotels.is_last(_career.hotel):
		_next_terms.text = "%s.\nThis is as far as the demo goes." % needs
		_apply.text = "Apply"
		_apply.disabled = not _career.can_finish_demo()
		return
	_next_terms.text = "%s\nand an application fee of €%d. Your music box comes along; the cab starts over." % [
		needs, next.fee]
	_apply.text = "Apply €%d" % next.fee
	_apply.disabled = not _career.can_move()
