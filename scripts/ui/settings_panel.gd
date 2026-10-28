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
	ui.button_in(column, "Сохранить и вернуться", func(): SettingsManager.save(); ui._show_pause() if from_game else ui._show_menu())
