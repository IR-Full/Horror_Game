extends RefCounted

static func build(ui: Node, column: VBoxContainer, from_game: bool, tab: int) -> void:
	ui.label_in(column, "НАСТРОЙКИ", 27, "e6c18a")
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for i: int in range(3):
		var button: Button = ui.button_in(tabs, ["Графика", "Аудио", "Управление"][i], ui._show_settings.bind(from_game, i))
		button.disabled = i == tab
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	if tab == 0:
		var quality := OptionButton.new()
		for name: String in ["Быстрая графика", "Средняя графика", "Высокая графика"]:
			quality.add_item(name)
		quality.selected = SettingsManager.quality
		quality.item_selected.connect(func(i: int): SettingsManager.quality = i; SettingsManager.apply())
		body.add_child(quality)
		ui.label_in(body, "Рельеф материалов, тени, пыль и дальность видимости.", 15)
		var scale_choice := OptionButton.new()
		for name: String in ["Масштаб 3D: 50%", "Масштаб 3D: 75%", "Масштаб 3D: 100%"]:
			scale_choice.add_item(name)
		scale_choice.selected = [0.5, 0.75, 1.0].find(SettingsManager.resolution_scale)
		scale_choice.item_selected.connect(func(i: int): SettingsManager.resolution_scale = [0.5, 0.75, 1.0][i]; SettingsManager.apply())
		body.add_child(scale_choice)
		var fullscreen := CheckButton.new()
		fullscreen.text = "Полный экран"
		fullscreen.button_pressed = SettingsManager.fullscreen
		fullscreen.toggled.connect(func(value: bool): SettingsManager.fullscreen = value; SettingsManager.apply())
		body.add_child(fullscreen)
	elif tab == 1:
		for data: Array in [["Общая громкость", "volume"], ["Музыка", "music_volume"], ["Звуки / монстр / оружие", "effects_volume"], ["Фон станции", "ambience_volume"]]:
			ui.label_in(body, data[0], 17)
			var slider := HSlider.new()
			slider.max_value = 1
			slider.step = .01
			slider.value = SettingsManager.get(data[1])
			slider.value_changed.connect(func(value: float): SettingsManager.set(data[1], value); SettingsManager.apply())
			body.add_child(slider)
		ui.label_in(body,"ГОЛОСОВАЯ СВЯЗЬ",21,"e6c18a")
		ui.label_in(body,"Удерживайте %s, чтобы говорить в лобби и игре.\nГромкий голос привлекает сущность рядом с говорящим." % SettingsManager.key_label("voice"),15)
		var enabled := CheckButton.new()
		enabled.text = "Голосовой чат включён"
		enabled.button_pressed = SettingsManager.voice_enabled
		enabled.toggled.connect(func(value: bool): SettingsManager.voice_enabled = value; SettingsManager.apply())
		body.add_child(enabled)
		var muted := CheckButton.new()
		muted.text = "Выключить свой микрофон"
		muted.button_pressed = SettingsManager.microphone_muted
		muted.toggled.connect(func(value: bool): SettingsManager.microphone_muted = value; SettingsManager.apply())
		body.add_child(muted)
		for data: Array in [["Громкость голосов команды","voice_volume",0.0,1.5],["Усиление микрофона","microphone_gain",.25,3.0]]:
			ui.label_in(body,data[0],17)
			var slider := HSlider.new()
			slider.min_value = data[2]
			slider.max_value = data[3]
			slider.step = .01
			slider.value = SettingsManager.get(data[1])
			slider.value_changed.connect(func(value: float): SettingsManager.set(data[1],value); SettingsManager.apply())
			body.add_child(slider)
		ui.label_in(body,"Порог отсечения фонового шума (дБ)",17)
		var gate := HSlider.new()
		gate.min_value = -60
		gate.max_value = -25
		gate.step = 1
		gate.value = linear_to_db(SettingsManager.microphone_gate)
		gate.value_changed.connect(func(value: float): SettingsManager.microphone_gate = db_to_linear(value))
		body.add_child(gate)
		ui.label_in(body,"Устройство микрофона",17)
		var device := OptionButton.new()
		var devices: PackedStringArray = AudioServer.get_input_device_list()
		if devices.is_empty(): devices.append("Default")
		for name: String in devices: device.add_item(name)
		device.selected = maxi(0,devices.find(SettingsManager.microphone_device))
		device.item_selected.connect(func(index: int): SettingsManager.microphone_device = devices[index]; SettingsManager.apply())
		body.add_child(device)
		var monitor := CheckButton.new()
		monitor.text = "Проверить микрофон — без передачи в комнату"
		monitor.toggled.connect(func(value: bool): VoiceManager.monitor_enabled = value)
		monitor.tree_exiting.connect(func(): VoiceManager.monitor_enabled = false)
		body.add_child(monitor)
		var meter := ProgressBar.new()
		meter.custom_minimum_size.y = 18
		var meter_background := StyleBoxFlat.new()
		meter_background.bg_color = Color("1a343a")
		meter_background.border_color = Color("52716b")
		meter_background.set_border_width_all(1)
		meter.add_theme_stylebox_override("background",meter_background)
		var meter_fill := StyleBoxFlat.new()
		meter_fill.bg_color = Color("94d0b5")
		meter.add_theme_stylebox_override("fill",meter_fill)
		meter.min_value = -60
		meter.max_value = 0
		meter.value = -60
		meter.show_percentage = false
		body.add_child(meter)
		ui.microphone_meter = meter
		ui.microphone_status = ui.label_in(body,"Уровень микрофона",14)
		ui.label_in(body,"Передача только при удержании кнопки.\nЕсли данных нет, разрешите Godot доступ к микрофону в ОС.",14,"8fa9a0")
		for id: int in NetworkManager.members:
			if id == ui.multiplayer.get_unique_id(): continue
			var peer_mute := CheckButton.new()
			peer_mute.text = "Заглушить: "+NetworkManager.members[id].name
			peer_mute.button_pressed = VoiceManager.muted_peers.has(id)
			peer_mute.toggled.connect(func(value: bool): VoiceManager.set_peer_muted(id,value))
			body.add_child(peer_mute)
	else:
		ui.label_in(body, "Нажмите действие, затем клавишу или кнопку мыши.\nEsc отменяет назначение и остаётся кнопкой меню.", 15)
		var sensitivity := HSlider.new()
		sensitivity.min_value = .0005
		sensitivity.max_value = .006
		sensitivity.step = .0001
		sensitivity.value = SettingsManager.sensitivity
		sensitivity.value_changed.connect(func(value: float): SettingsManager.sensitivity = value)
		ui.label_in(body, "Чувствительность мыши", 17)
		body.add_child(sensitivity)
		for action: String in SettingsManager.ACTION_LABELS:
			var button: Button = ui.button_in(body, SettingsManager.ACTION_LABELS[action] + "  —  " + SettingsManager.key_label(action), func(): pass)
			button.pressed.connect(func(): ui.rebind_action = action; ui.rebind_button = button; button.text = "Нажмите новую клавишу…")
		ui.button_in(body, "Восстановить управление", func(): SettingsManager.reset_controls(); ui._show_settings(from_game, 2))
	ui.button_in(column, "Сохранить и вернуться", ui.finish_settings)
