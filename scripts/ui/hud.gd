class_name HUD
extends CanvasLayer
## Touch-friendly heads-up display, built entirely in code.
##
## Top bar: resources, supply and quick-select buttons.
## Bottom panel: info about the selection and large action buttons
## (build, train, attack-move, stop, place/cancel).

const BUTTON_SIZE := Vector2(124, 64)
const REFRESH_INTERVAL := 0.2

var input_ctrl: TouchInput
var team := 0

var _root: Control
var _top_bar: PanelContainer
var _res_labels := {}
var _supply_label: Label
var _select_btn: Button
var _bottom: PanelContainer
var _info: Label
var _actions: HFlowContainer
var _action_entries: Array = []   # [{"button": Button, "check": Callable}]
var _message: Label
var _message_time := 0.0
var _box: SelectionBox
var _overlay: Control
var _overlay_label: Label
var _context_key := ""
var _refresh := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	_box = SelectionBox.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box)

	_build_top_bar()
	_build_bottom_panel()
	_build_message()
	_build_overlay()

	Game.message_posted.connect(show_message)
	Game.match_ended.connect(_on_match_ended)
	if input_ctrl:
		input_ctrl.selection_changed.connect(_on_selection_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_on_selection_changed()


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH_INTERVAL
	_update_resources()
	if _compute_context_key() != _context_key:
		_rebuild_actions()
	_update_info()
	_update_action_states()


## True if a screen position is covered by HUD panels (so the world should ignore it).
func blocks(pos: Vector2) -> bool:
	for c in [_top_bar, _bottom, _overlay]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


func show_box(r: Rect2) -> void:
	_box.box = r
	_box.showing = true
	_box.queue_redraw()


func hide_box() -> void:
	_box.showing = false
	_box.queue_redraw()


func show_message(text: String) -> void:
	_message.text = text
	_message_time = 2.5
	_message.modulate.a = 1.0


# ---------------------------------------------------------------- layout

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.1, 0.86)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel)
	var states := {
		"normal": Color(0.2, 0.24, 0.3),
		"hover": Color(0.26, 0.31, 0.38),
		"pressed": Color(0.33, 0.55, 0.36),
		"disabled": Color(0.15, 0.16, 0.18),
	}
	for s in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[s]
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(6)
		t.set_stylebox(s, "Button", sb)
	var hover_pressed := StyleBoxFlat.new()
	hover_pressed.bg_color = states["pressed"]
	hover_pressed.set_corner_radius_all(10)
	hover_pressed.set_content_margin_all(8)
	t.set_stylebox("hover_pressed", "Button", hover_pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 17)
	return t


func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 8
	_top_bar.offset_right = -8
	_top_bar.offset_top = 8
	_root.add_child(_top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_top_bar.add_child(row)
	for r in GameData.RESOURCE_TYPES:
		var swatch := ColorRect.new()
		swatch.color = GameData.RESOURCE_COLORS[r]
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var l := Label.new()
		l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		_res_labels[r] = l
	_supply_label = Label.new()
	row.add_child(_supply_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_small_button("Army", func(): input_ctrl.select_army()))
	row.add_child(_small_button("Idle Worker", func(): input_ctrl.select_idle_builder()))
	_select_btn = _small_button("Box Select", func(): pass)
	_select_btn.toggle_mode = true
	_select_btn.toggled.connect(func(on): input_ctrl.toggle_select_mode(on))
	row.add_child(_select_btn)


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110, 44)
	b.pressed.connect(cb)
	return b


func _build_bottom_panel() -> void:
	_bottom = PanelContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_left = 8
	_bottom.offset_right = -8
	_bottom.offset_bottom = -8
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bottom.add_child(row)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(250, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_info)
	_actions = HFlowContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	row.add_child(_actions)


func _build_message() -> void:
	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 80
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 24)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	_root.add_child(_message)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 24)
	_overlay.add_child(box)
	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 56)
	box.add_child(_overlay_label)
	var again := _small_button("Play Again", func(): get_tree().reload_current_scene())
	again.custom_minimum_size = Vector2(240, 70)
	box.add_child(again)


## Keeps the HUD clear of the notch / home indicator on iPhone and iPad.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or safe.size.x <= 0.0:
		return
	var vp := _root.get_viewport_rect().size
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	_root.offset_left = maxf(0.0, safe.position.x * sx)
	_root.offset_top = maxf(0.0, safe.position.y * sy)
	_root.offset_right = -maxf(0.0, (win.x - safe.end.x) * sx)
	_root.offset_bottom = -maxf(0.0, (win.y - safe.end.y) * sy)


# ---------------------------------------------------------------- updates

func _on_selection_changed() -> void:
	if input_ctrl:
		_select_btn.set_pressed_no_signal(input_ctrl.select_mode)
	_rebuild_actions()
	_update_info()
	_update_action_states()


func _update_resources() -> void:
	for r in _res_labels:
		_res_labels[r].text = str(Game.get_resource(team, r))
	_supply_label.text = "Supply %d/%d" % [Game.supply_used(team), Game.supply_cap(team)]


func _compute_context_key() -> String:
	var parts: PackedStringArray = [input_ctrl.placing, str(input_ctrl.attack_move_armed)]
	for e in input_ctrl.selection:
		if Entity.alive(e):
			parts.append(str(e.get_instance_id()))
			if e is Building:
				parts.append(str(e.is_complete) + str(e.train_queue.is_empty()))
	return "|".join(parts)


func _rebuild_actions() -> void:
	_context_key = _compute_context_key()
	for c in _actions.get_children():
		c.queue_free()
	_action_entries.clear()

	if input_ctrl.placing != "":
		_add_action("Place", "", _confirm_place)
		_add_action("Cancel", "", func(): input_ctrl.cancel_placement())
		_bottom.visible = true
		return

	var building := input_ctrl.selected_own_building()
	if building:
		if building.is_complete:
			for uid in building.trains:
				var udef := GameData.get_unit_def(building.faction_id, uid)
				_add_action(str(udef.get("name", uid)), GameData.cost_to_string(udef.get("cost", {})),
						_train.bind(building, uid), building.can_train.bind(uid))
			if not building.train_queue.is_empty():
				_add_action("Cancel", "last in queue", func(): building.cancel_last())
		_bottom.visible = true
		return

	var units := input_ctrl.selected_own_units()
	if not units.is_empty():
		if not input_ctrl.selected_builders().is_empty():
			var fid := Game.faction_of(team)
			for bid in GameData.building_ids(fid):
				var bdef := GameData.get_building_def(fid, bid)
				if not bdef.get("buildable", true):
					continue
				_add_action(str(bdef.get("name", bid)), GameData.cost_to_string(bdef.get("cost", {})),
						_start_build.bind(bid), Game.build_blocker.bind(team, bid))
		if units.any(func(u): return u.can_fight()):
			_add_action("Attack-move" if not input_ctrl.attack_move_armed else "Tap target...", "",
					func(): input_ctrl.arm_attack_move())
		_add_action("Stop", "", func():
			for u in input_ctrl.selected_own_units():
				u.command_stop())
	_bottom.visible = not input_ctrl.selection.is_empty()


func _add_action(title: String, subtitle: String, on_press: Callable, check: Callable = Callable()) -> void:
	var b := Button.new()
	b.text = title if subtitle == "" else "%s\n%s" % [title, subtitle]
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		on_press.call()
		_refresh = 0.0)
	_actions.add_child(b)
	_action_entries.append({"button": b, "check": check})


func _update_action_states() -> void:
	# Unavailable actions stay tappable (they explain why) but are dimmed.
	for entry in _action_entries:
		var check: Callable = entry["check"]
		var ok := true
		if check.is_valid():
			ok = str(check.call()) == ""
		entry["button"].modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)


func _update_info() -> void:
	if input_ctrl.placing != "":
		var bdef := GameData.get_building_def(Game.faction_of(team), input_ctrl.placing)
		_info.text = "Place %s\nTap to move it, then tap it again or press Place." % bdef.get("name", "")
		return
	if input_ctrl.attack_move_armed:
		_info.text = "Attack-move\nTap the ground to advance and fight anything on the way."
		return
	var sel := input_ctrl.selection
	if sel.is_empty():
		_info.text = ""
		return
	if sel.size() == 1:
		var e = sel[0]
		var lines: PackedStringArray = [e.display_name, "HP %d / %d" % [ceili(e.hp), int(e.max_hp)]]
		if e.team != team:
			lines.append("(enemy)")
		elif e is Unit:
			lines.append(e.status_text())
		elif e is Building:
			if not e.is_complete:
				lines.append("Under construction %d%%" % int(100.0 * e.build_progress / e.build_time))
			elif not e.train_queue.is_empty():
				var udef := GameData.get_unit_def(e.faction_id, e.train_queue[0])
				var extra := "  (+%d queued)" % (e.train_queue.size() - 1) if e.train_queue.size() > 1 else ""
				lines.append("Training %s %d%%%s" % [udef.get("name", ""), int(100.0 * e.current_train_fraction()), extra])
			if not e.drop_off.is_empty():
				lines.append("Accepts " + ", ".join(PackedStringArray(e.drop_off)))
		_info.text = "\n".join(lines)
		return
	var counts := {}
	for e in sel:
		counts[e.display_name] = counts.get(e.display_name, 0) + 1
	var parts: PackedStringArray = []
	for n in counts:
		parts.append("%d %s" % [counts[n], n])
	_info.text = "%d selected\n%s" % [sel.size(), ", ".join(parts)]


# ---------------------------------------------------------------- actions

func _train(building: Building, unit_id: String) -> void:
	if not Entity.alive(building):
		return
	var err := building.enqueue(unit_id)
	if err != "":
		show_message(err)


func _start_build(building_id: String) -> void:
	var err := Game.build_blocker(team, building_id)
	if err != "":
		show_message(err)
		return
	input_ctrl.start_placement(building_id)


func _confirm_place() -> void:
	var err := input_ctrl.confirm_placement()
	if err != "":
		show_message(err)


func _on_match_ended(winning_team: int) -> void:
	_overlay_label.text = "Victory!" if winning_team == team else "Defeat"
	_overlay.visible = true
