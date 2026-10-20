class_name StaffRoom
extends PanelContainer
## The staff room between shifts: the bank balance and every upgrade with its level and
## the price of the next one. Buying pays from the balance straight away; the upgrade is
## in the cab from the next shift on.

signal bought(id: String)
signal started

var _career: Career
var _balance: Label
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

	var title := Label.new()
	title.text = "Staff room"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 20)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_balance)

	for upgrade in Upgrades.CATALOGUE:
		box.add_child(_build_row(upgrade))

	_start = Button.new()
	_start.name = "StartShift"
	_start.text = "Start the shift"
	_start.pressed.connect(started.emit)
	box.add_child(_start)
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


func show_for(career: Career) -> void:
	_career = career
	_refresh()
	show()
	_start.grab_focus()


func _buy(id: String) -> void:
	if _career.buy(id):
		bought.emit(id)
	_refresh()


func _refresh() -> void:
	_balance.text = "Bank balance: €%.2f" % _career.balance
	for upgrade in Upgrades.CATALOGUE:
		var row: Dictionary = _rows[upgrade.id]
		var l := _career.level(upgrade.id)
		var top := Upgrades.max_level(upgrade.id)
		row.level.text = "%s   level %d of %d" % [upgrade.name, l, top]
		var buy: Button = row.buy
		if l >= top:
			row.next.text = "Fully upgraded"
			buy.text = "Done"
			buy.disabled = true
		else:
			row.next.text = "Next: %s" % upgrade.effects[l]
			buy.text = "Buy €%d" % _career.next_price(upgrade.id)
			buy.disabled = not _career.can_buy(upgrade.id)
