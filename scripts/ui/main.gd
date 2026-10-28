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
var nickname: String = "Техник"
var address: String = "127.0.0.1"
var port: int = 27840
var paused: bool = false
var displayed_result: bool = false
var screen_kind: String = ""
var test_mode: bool = false

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
	label_in(column, "LAN • 2–4 игрока  /  Прототип 0.3  /  Без микрофона", 14, "77938f")
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
	var roles: Array = ["Техник-разведчик", "Медик-оператор"] if paired else ["Техник", "Разведчик", "Медик", "Оператор"]
	for id: int in NetworkManager.members:
		var entry: Dictionary = NetworkManager.members[id]
		label_in(column, "%s  —  %s%s" % [entry.name, roles[mini(int(entry.role), roles.size() - 1)], "  [хост]" if id == 1 else ""], 19)
	if NetworkManager.members.has(multiplayer.get_unique_id()):
		label_in(column, "Ваша роль (занятая — обмен ролями):", 16)
		var choice := OptionButton.new()
		for role: String in roles:
			choice.add_item(role)
		choice.selected = int(NetworkManager.members[multiplayer.get_unique_id()].role)
		choice.item_selected.connect(func(index: int): NetworkManager.choose_role(index))
		column.add_child(choice)
	label_in(column, "Вдвоём роли объединяются. С тремя игроками доступны\nчетыре отдельных роли; обязательных классов нет.", 16, "8fa9a0")
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
	inventory_label = label_in(hud, "", 17)
	inventory_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	inventory_label.offset_left = 28
	inventory_label.offset_top = -100
	inventory_label.offset_right = 1150
	inventory_label.offset_bottom = -65
	hint = label_in(hud, "", 17, "e5c38e")
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -280
	hint.offset_right = 280
	hint.offset_top = -170
	hint.offset_bottom = -120
	hint.custom_minimum_size.x = 560
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := label_in(hud, "WASD движение • Shift бег • Ctrl тихо • F фонарь • E удерживать\nQ предмет • G положить • R использовать • V шум • Esc меню", 14, "8ea69c")
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 28
	controls.offset_right = 1150
	controls.offset_top = -52
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

func _show_settings(from_game: bool) -> void:
	var column := _new_screen("settings", not from_game)
	label_in(column, "НАСТРОЙКИ", 28, "e6c18a")
	var quality := OptionButton.new()
	for title: String in ["Быстрая графика", "Средняя графика", "Высокая графика"]:
		quality.add_item(title)
	quality.selected = SettingsManager.quality
	quality.item_selected.connect(func(index: int): SettingsManager.quality = index)
	column.add_child(quality)
	label_in(column, "Compatibility: обычный туман и тени.\nОбъёмный туман и отражения — будущий Forward+ режим.", 15, "8fa9a0")
	var scale_choice := OptionButton.new()
	for title: String in ["Масштаб 3D: 50%", "Масштаб 3D: 75%", "Масштаб 3D: 100%"]:
		scale_choice.add_item(title)
	scale_choice.selected = [0.5, 0.75, 1.0].find(SettingsManager.resolution_scale)
	scale_choice.item_selected.connect(func(index: int): SettingsManager.resolution_scale = [0.5, 0.75, 1.0][index])
	column.add_child(scale_choice)
	label_in(column, "Общая громкость", 16)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = SettingsManager.volume
	volume.value_changed.connect(func(value: float): SettingsManager.volume = value)
	column.add_child(volume)
	label_in(column, "Чувствительность мыши", 16)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = SettingsManager.sensitivity
	sensitivity.value_changed.connect(func(value: float): SettingsManager.sensitivity = value)
	column.add_child(sensitivity)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Полный экран"
	fullscreen.button_pressed = SettingsManager.fullscreen
	fullscreen.toggled.connect(func(value: bool): SettingsManager.fullscreen = value)
	column.add_child(fullscreen)
	button_in(column, "Сохранить и вернуться", func():
		SettingsManager.save()
		_show_pause() if from_game else _show_menu()
	)

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
	task.text = goal.task_text()
	var slots := PackedStringArray()
	for index: int in range(player.inventory.size()):
		slots.append(("▸ " if index == player.selected_slot % maxi(1, player.inventory.size()) else "") + str(world.items.NAMES.get(player.inventory[index], "?")))
	inventory_label.text = "ИНВЕНТАРЬ %d/%d  /  %s" % [player.inventory.size(), player.capacity(), " • ".join(slots)]
	if player.health <= 0.0:
		hint.text = "Вы погибли. Ждите исхода экспедиции." if player.dead else "Вы оглушены. Напарник может поднять вас: удерживать E."
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
				hint.text = "Удерживайте E — поднять напарника"
		elif object.get("title") != null:
			hint.text = "[E] " + object.title
			if object.kind == "door":
				hint.text = "[E] " + ("Закрыть дверь" if object.opened else "Открыть дверь")
	if player.role in ["scout", "tech_scout"] and world.monster.state != 0 and player.position.distance_to(world.monster.position) < 10.0:
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
