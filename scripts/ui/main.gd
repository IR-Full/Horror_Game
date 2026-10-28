extends Node
var canvas: CanvasLayer
var ui: Control
var screen: Control
var hud: Control
var stats: Label
var task: Label
var hint: Label
var inventory_label: Label
var message_label: Label
var notice_time: float = 0.0
var nickname: String = "Выживший"
var address: String = "127.0.0.1"
var port: int = 27840
var paused: bool = false
var displayed_result: bool = false
var screen_kind: String = ""
var test_mode: bool = false
var rebind_action: String = ""
var rebind_button: Button
var controls_label: Label

func _ready() -> void:
	GameManager.interface = self
	var args := OS.get_cmdline_user_args()
	for value: String in args:
		if value.begins_with("--test="):
			test_mode = true
	canvas = CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	ui.theme = _theme()
	NetworkManager.lobby_changed.connect(_lobby_changed)
	NetworkManager.error_message.connect(show_notice)
	NetworkManager.prepare_world.connect(_load_world)
	NetworkManager.match_started.connect(_show_game)
	NetworkManager.left_room.connect(_clear_world)
	_show_menu()
	if test_mode:
		var runner := Node.new()
		runner.set_script(load("res://tests/network_test.gd"))
		add_child(runner)
	if "--preview" in args:
		var preview := Node.new()
		preview.set_script(load("res://tests/visual_preview.gd"))
		add_child(preview)
	if "--art-check" in args:
		var checker := Node.new()
		checker.set_script(load("res://tests/art_check.gd"))
		add_child(checker)
	if "--feature-check" in args:
		var checker := Node.new()
		checker.set_script(load("res://tests/feature_check.gd"))
		add_child(checker)

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("d3e0da"))
	for type: String in ["Button", "LineEdit", "OptionButton", "SpinBox"]:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("223a3e") if state == "hover" else Color("15282f")
			style.border_color = Color("8ba79b") if state in ["hover", "focus"] else Color("355353")
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			style.content_margin_left = 16
			style.content_margin_right = 16
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			theme.set_stylebox(state, type, style)
	return theme

func _new_screen(kind: String, backdrop: bool = true) -> VBoxContainer:
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
	screen_kind = kind
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(screen)
	if backdrop:
		var art := Control.new()
		art.set_script(preload("res://scripts/ui/backdrop.gd"))
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(art)
	else:
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.06, 0.9)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 600
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.07, 0.09, 0.94)
	box.border_color = Color("3b5754")
	box.set_border_width_all(1)
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 26
	box.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return column

func label_in(parent: Node, text: String, font_size: int = 19, color: String = "d3e0da") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	parent.add_child(label)
	return label

func button_in(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _show_menu() -> void:
	paused = false
	var column := _new_screen("menu")
	label_in(column, "РС–17   /   КООПЕРАТИВНЫЙ ХОРРОР", 15, "80aaa2")
	label_in(column, "ПОСЛЕДНИЙ СИГНАЛ", 34, "e6c18a")
	label_in(column, "В горах снова слышат станцию, которой больше нет.", 17)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Ваш позывной"
	name_edit.text = nickname
	name_edit.max_length = 20
	name_edit.text_changed.connect(func(value: String): nickname = value)
	column.add_child(name_edit)
	var ip_edit := LineEdit.new()
	ip_edit.placeholder_text = "IP хоста в локальной сети"
	ip_edit.text = address
	ip_edit.text_changed.connect(func(value: String): address = value)
	column.add_child(ip_edit)
	var port_row := HBoxContainer.new()
	column.add_child(port_row)
	label_in(port_row, "UDP-порт", 17)
	var port_edit := SpinBox.new()
	port_edit.min_value = 1024
	port_edit.max_value = 65535
	port_edit.value = port
	port_edit.value_changed.connect(func(value: float): port = int(value))
	port_row.add_child(port_edit)
	button_in(column, "СОЗДАТЬ КОМНАТУ", func(): NetworkManager.host_room(nickname, port))
	button_in(column, "ПОДКЛЮЧИТЬСЯ ПО IP", func(): NetworkManager.join_room(address, nickname, port))
	button_in(column, "Настройки", func(): _show_settings(false))
	button_in(column, "Выход", func(): get_tree().quit())
	label_in(column, "LAN • 2–4 игрока  /  Прототип 0.4  /  Без микрофона", 14, "77938f")
	_make_message_label()

func _lobby_changed() -> void:
	if not NetworkManager.in_match and not NetworkManager.loading and not NetworkManager.unloading:
		_show_lobby() if NetworkManager.active else _show_menu()

func _show_lobby() -> void:
	var column := _new_screen("lobby")
	label_in(column, "ЭКСПЕДИЦИЯ / ЛОББИ LAN", 28, "e6c18a")
	var host: bool = multiplayer.is_server()
	var ips := PackedStringArray()
	for ip: String in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			ips.append(ip)
	label_in(column, ("IP хоста: " + (", ".join(ips) if not ips.is_empty() else "127.0.0.1")) if host else "Подключение к хосту", 16)
	label_in(column, "UDP %d  •  %d / 4 игроков" % [NetworkManager.port, NetworkManager.members.size()], 16, "80aaa2")
	var paired: bool = NetworkManager.members.size() <= 2
	var roles: Array = NetworkManager.ROLE_LABELS
	for id: int in NetworkManager.members:
		var entry: Dictionary = NetworkManager.members[id]
		label_in(column, "%s  —  %s%s" % [entry.name, roles[mini(int(entry.role), roles.size() - 1)], "  [хост]" if id == 1 else ""], 19)
	if NetworkManager.members.has(multiplayer.get_unique_id()):
		label_in(column, "Ваша роль:", 16)
		var choice := OptionButton.new()
		for role: String in roles:
			choice.add_item(role)
		choice.selected = int(NetworkManager.members[multiplayer.get_unique_id()].role)
		choice.item_selected.connect(func(index: int): NetworkManager.choose_role(index))
		column.add_child(choice)
	label_in(column, "Техник быстрее чинит. Медик быстрее поднимает.\nОхотник: дробовик и один патрон. Все роли доступны вдвоём.", 16, "8fa9a0")
	if host:
		var start := button_in(column, "НАЧАТЬ ЭКСПЕДИЦИЮ", func(): NetworkManager.start_round())
		start.disabled = NetworkManager.members.size() < 2
		if NetworkManager.members.size() == 1:
			button_in(column, "Учебный запуск одному", func(): NetworkManager.start_round(true))
	else:
		label_in(column, "Ожидайте, пока хост начнёт экспедицию.", 17)
	button_in(column, "Выйти из комнаты", func(): NetworkManager.leave())
	_make_message_label()

func _load_world() -> void:
	displayed_result = false
	var column := _new_screen("loading")
	label_in(column, "ЗАГРУЗКА СТАНЦИИ…", 28, "e6c18a")
	label_in(column, "Ожидаем готовности всех участников.", 18)
	var world := preload("res://scenes/world.tscn").instantiate()
	world.name = "World"
	add_child(world)

func _clear_world() -> void:
	var old := get_node_or_null("World")
	if old:
		remove_child(old)
		old.queue_free()
	if is_instance_valid(hud):
		ui.remove_child(hud)
		hud.queue_free()
	paused = false
	displayed_result = false
	_show_lobby() if NetworkManager.active else _show_menu()

func _show_game() -> void:
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
		screen = null
	screen_kind = "game"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hud()

func _build_hud() -> void:
	if is_instance_valid(hud):
		hud.queue_free()
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(6, 16)
	crosshair.modulate = Color(0.7, 0.9, 0.8, 0.7)
	hud.add_child(crosshair)
	stats = label_in(hud, "", 17, "b8d0c5")
	stats.position = Vector2(28, 22)
	task = label_in(hud, "", 17, "e5c38e")
	task.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task.offset_left = -435
	task.offset_top = 25
	task.offset_right = -20
	task.offset_bottom = 155
	var inventory_bar := Control.new()
	inventory_bar.set_script(preload("res://scripts/ui/inventory_bar.gd"))
	inventory_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory_bar.offset_left = -152
	inventory_bar.offset_top = -82
	inventory_bar.offset_right = 152
	inventory_bar.offset_bottom = -12
	inventory_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(inventory_bar)
	hint = label_in(hud, "", 17, "e5c38e")
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -280
	hint.offset_right = 280
	hint.offset_top = -170
	hint.offset_bottom = -120
	hint.custom_minimum_size.x = 560
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := label_in(hud, "E — взаимодействие • Q — ячейка\nЛКМ — выстрел • T — перезарядка\nH — SOS • Esc — меню", 14, "8ea69c")
	controls_label = controls
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 28
	controls.offset_right = 395
	controls.offset_top = -70
	controls.offset_bottom = -10
	_make_message_label()

func _make_message_label() -> void:
	if is_instance_valid(message_label):
		message_label.queue_free()
	message_label = label_in(ui, "", 18, "e5bd85")
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -500
	message_label.offset_right = 500
	message_label.offset_top = -125
	message_label.offset_bottom = -98
	message_label.custom_minimum_size.x = 1000
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_notice(message: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = message
		notice_time = 5.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and NetworkManager.in_match and not displayed_result:
		if paused:
			_resume()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()

func _show_pause() -> void:
	paused = true
	var player := GameManager.local_player()
	if player:
		player.input_enabled = false
	var column := _new_screen("pause", false)
	label_in(column, "ПОЛЕВОЕ МЕНЮ", 28, "e6c18a")
	label_in(column, "Раунд и сущность продолжают действовать.", 17)
	button_in(column, "Продолжить", _resume)
	button_in(column, "Настройки", func(): _show_settings(true))
	if multiplayer.is_server():
		button_in(column, "Завершить раунд → в лобби", func(): NetworkManager.return_to_lobby())
	button_in(column, "Покинуть комнату", func(): NetworkManager.leave())

func _resume() -> void:
	paused = false
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
		screen = null
	screen_kind = "game"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player := GameManager.local_player()
	if player:
		player.input_enabled = true

func _show_settings(from_game: bool, tab: int = 0) -> void:
	rebind_action = ""
	var column := _new_screen("settings", not from_game)
	preload("res://scripts/ui/settings_panel.gd").build(self, column, from_game, tab)

func _input(event: InputEvent) -> void:
	if rebind_action.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		rebind_action = ""
		_show_settings(NetworkManager.in_match, 2)
		get_viewport().set_input_as_handled()
		return
	var value: Array = []
	if event is InputEventKey:
		value = ["key", event.physical_keycode]
	elif event is InputEventMouseButton:
		value = ["mouse", event.button_index]
	if not value.is_empty():
		SettingsManager.set_binding(rebind_action, value)
		rebind_button.text = SettingsManager.ACTION_LABELS[rebind_action] + "  —  " + SettingsManager.key_label(rebind_action)
		rebind_action = ""
		get_viewport().set_input_as_handled()

func open_safe(id: String) -> void:
	paused = true
	GameManager.local_player().input_enabled = false
	var column := _new_screen("safe", false)
	label_in(column, "КОДОВЫЙ ЗАМОК", 27, "e6c18a")
	label_in(column, "Три цифры. Подсказка — в медпункте.", 18)
	var entry := LineEdit.new()
	entry.max_length = 3
	entry.placeholder_text = "000"
	column.add_child(entry)
	entry.grab_focus()
	button_in(column, "Открыть", func(): GameManager.world.unlock_safe.rpc_id(1, id, entry.text); _resume())
	button_in(column, "Отойти", _resume)

func show_document(title: String, content: String) -> void:
	paused = true
	GameManager.local_player().input_enabled = false
	var column := _new_screen("document", false)
	label_in(column, title.to_upper(), 27, "e6c18a")
	label_in(column, content, 18)
	button_in(column, "Закрыть", _resume)

func _process(delta: float) -> void:
	if notice_time > 0.0:
		notice_time -= delta
		if notice_time <= 0.0 and is_instance_valid(message_label):
			message_label.text = ""
	if not NetworkManager.in_match or not is_instance_valid(GameManager.world):
		return
	var world: Node3D = GameManager.world
	var goal: Node = world.objectives
	if not goal.result.is_empty() and not displayed_result:
		displayed_result = true
		_show_result(goal.result)
	var player := GameManager.local_player()
	if not player or not is_instance_valid(stats):
		return
	var seconds: int = int(goal.seconds_left)
	stats.text = "%s / %s\nЗдоровье %d   •   Фонарь %d%%\n%02d:%02d  •  %d FPS" % [player.nickname, player.ROLE_NAMES.get(player.role, player.role), int(player.health), int(player.battery), seconds / 60, seconds % 60, Engine.get_frames_per_second()]
	task.text = goal.task_text().replace(" E", " " + SettingsManager.key_label("interact"))
	controls_label.text = "%s — взаимодействие • %s — ячейка\n%s — выстрел • %s — перезарядка\n%s — SOS • Esc — меню" % [SettingsManager.key_label("interact"), SettingsManager.key_label("slot"), SettingsManager.key_label("shoot"), SettingsManager.key_label("reload"), SettingsManager.key_label("sos")]
	task.add_theme_color_override("font_color", Color("e47b65") if not goal.emergency.is_empty() else Color("e5c38e"))
	if player.role == "hunter":
		stats.text += "\nДробовик: %d / %d  %s" % [player.loaded_shells, player.reserve_shells, "ПЕРЕЗАРЯДКА" if player.reload_left > 0 else ""]
	if player.health <= 0.0:
		hint.text = "Вы погибли. Ждите исхода экспедиции." if player.dead else "Вы ранены: %d сек. до гибели. Напарник: удерживать E.\n%s — SOS %s" % [maxi(0, ceili(120 - player.down_time)), SettingsManager.key_label("sos"), "готов" if player.sos_cooldown <= 0 else "через %d сек." % ceili(player.sos_cooldown)]
		return
	if paused or displayed_result:
		return
	var origin: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - player.camera.global_basis.z * 2.6, 7, [player.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	hint.text = ""
	if not hit.is_empty():
		var object: Object = hit.collider
		if object.has_meta("door_switch"):
			object = object.get_parent()
		if object.is_in_group("players"):
			if object.health <= 0.0 and not object.dead:
				hint.text = "Удерживайте %s — поднять напарника" % SettingsManager.key_label("interact")
		elif object.get("title") != null:
			hint.text = "[%s] " % SettingsManager.key_label("interact") + object.title.replace(" E", " " + SettingsManager.key_label("interact"))
			if object.kind == "door":
				hint.text = "[%s] " % SettingsManager.key_label("interact") + ("Закрыть дверь" if object.opened else "Открыть дверь")
	if player.role == "hunter" and world.monster.state not in [0, 6] and player.position.distance_to(world.monster.position) < 10.0:
		hint.text += "\nВы слышите присутствие сущности…"

func _show_result(message: String) -> void:
	var column := _new_screen("result", false)
	label_in(column, "СИГНАЛ ПРИНЯТ" if message.begins_with("Победа") else "СВЯЗЬ ПОТЕРЯНА", 30, "e6c18a")
	label_in(column, message, 18)
	if multiplayer.is_server():
		button_in(column, "Вернуться в лобби", func(): NetworkManager.return_to_lobby())
	else:
		label_in(column, "Хост может вернуть команду в лобби.", 17)
	button_in(column, "Покинуть комнату", func(): NetworkManager.leave())
