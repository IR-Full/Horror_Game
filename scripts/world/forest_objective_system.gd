extends Node
## Host-owned logging escape: noisy machinery, hydraulic route and cooperative rail departure.
const RANDOM:=preload("res://scripts/core/round_random.gd")
const PARTS := ["car_battery","drive_belt"]
var station: Node3D
var seconds_left: float=2700
var result: String=""
var generator_on: bool=false
var powered: bool=false
var emergency: String=""
var emergency_left: float=0
var emergency_repair: float=0
var power_progress: float=0
var log_solution: Array=[0,1,2,3]
var log_input: Array=[]
var log_ready: bool=false
var control_lock: float=0
var pressure: Array=[0,0,0]
var pressure_solution: Array=[1,2,3]
var pump_ready: bool=false
var pump_progress: float=0
var rail_values: Array=[0,0,0]
var signal_solution: Array=[1,2,3]
var signals_ready: bool=false
var winch_progress: float=0
var winch_ready: bool=false
var installed: Array=[]
var install_progress: float=0
var install_kind: String=""
var install_owner: int=0
var fueled: bool=false
var exit_progress: float=0
var escape_time: float=-1
var noise_clock: float=0
var holders: Dictionary={}
func randomize_round() -> void:
	if not multiplayer.is_server():return
	var old: Dictionary=RANDOM.history("forest_puzzles")
	var safe: String=RANDOM.code(4,str(old.get("safe","")));var battery: String=RANDOM.code(4,str(old.get("battery","")),[safe])
	station.objects.forest_safe.code=safe;station.objects.battery_safe.code=battery
	log_solution=RANDOM.order(4,old.get("logs",[]));pressure_solution=RANDOM.digits(6,old.get("pressure",[]));signal_solution=RANDOM.digits(4,old.get("rail_values",[]))
	var order: PackedStringArray=[]
	for i: int in log_solution:order.append(str(i+1))
	station.objects.forest_office_note.description="ЧЁРНЫЙ БОР. ПРИКАЗ № 17\nПоиски пропавшей смены прекращены. Мастер велел запереть ворота, но ночью забор обошли снаружи. Мы нашли его каску внутри ствола.\nПервая половина кода сейфа конторы: "+safe.left(2)+". Вторая — в бараке F.\nДля дизеля A нужны предохранитель из сейфа и канистра из любого шкафа снабжения.\nУехать можно только на дрезине E. Не пытайтесь пробежать через лес: за оградой болото."
	station.objects.forest_barracks_note.description="ЗАПИСКА БРИГАДЫ\nПоследние две цифры сейфа A: "+safe.right(2)+".\nМастер приходит на голоса и треск механизмов. Его нельзя отогнать светом. Пока он лежит после выстрела, не задерживайтесь.\nКлюч зажигания — в личном шкафу F. Служебный ключ ищите в шкафчиках базы.\nЗдесь ещё тёплый чай. Держитесь вместе. Не отвечайте тому, кто зовёт из леса."
	station.objects.forest_winch_note.description="ЖУРНАЛ СТРОПАЛЬЩИКА\nПосле включения питания поднимите захваты пилорамы C в порядке: "+" → ".join(order)+".\nОшибка сбрасывает цепь и включает сирену. Затем удерживайте E у лебёдки B шесть секунд: она стянет завал с рельсов и откроет шкаф ремня C.\nАккумулятор — в сейфе B; его код остался у насосной D.\nВчера трос тянул в обратную сторону. Там никого не было."
	station.objects.forest_pump_note.description="ПОСЛЕДНЯЯ СМЕНА НАСОСНОЙ\nДавление I / II / III: %d / %d / %d (0–5). После настройки удерживать E у насоса D четыре секунды.\nНасос откроет топливную клетку: эта канистра нужна дрезине.\nКод аккумуляторного сейфа B: %s.\nПри утечке дизеля — две минуты на ремонт насоса, иначе пары загорятся.\nВода под настилом тёплая. Даже в мороз." % [pressure_solution[0],pressure_solution[1],pressure_solution[2],battery]
	station.objects.forest_signal_note.description="МАРШРУТ НА СТАНЦИЮ\nСтрелки A / B / C этой смены: %d / %d / %d (0–3).\nУ дрезины установите аккумулятор и ремень, заправьте канистрой. Нужны снятый завал, работающий дизель базы и служебные стрелки.\nВозьмите ключ зажигания F, соберите всех выживших в шести метрах от дрезины и удерживайте E восемь секунд. Гудок услышит весь лес.\nМы уйдём без мастера. Если в кабине окажется лишний человек — не оборачивайтесь." % signal_solution
	RANDOM.remember("forest_puzzles",{"safe":safe,"battery":battery,"logs":log_solution,"pressure":pressure_solution,"rail_values":signal_solution})
func begin_frame() -> void:holders.clear()
func interact(player: Node3D,object: Node3D) -> void:
	if not result.is_empty() or escape_time>=0:return
	if not holders.has(object.object_id):holders[object.object_id]=[]
	holders[object.object_id].append(player.peer_id)
func actor(id: String) -> Node3D:
	for peer: int in holders.get(id,[]):
		var p: Node3D=station.players.get_node_or_null(str(peer))
		if p and p.health>0 and not p.dead:return p
	return null
func tell(p: Node3D,message: String) -> void:
	if p.action_cooldown<=0:station.tell(p.peer_id,message);p.action_cooldown=1.5
func is_unlocked(rule: String) -> bool:
	match rule:
		"forest_winch":return winch_ready
		"forest_pump":return pump_ready
		"forest_exit":return escape_time>=0
	return true
func control(p: Node3D,object: Node3D) -> void:
	if not result.is_empty() or escape_time>=0:return
	if not generator_on or not emergency.is_empty():tell(p,"Нужно резервное питание A; сначала устраните аварию.");return
	var i: int=int(object.object_id.get_slice("_",1))
	if object.object_id.begins_with("log_"):
		if log_ready or control_lock>0:return
		log_input.append(i)
		if log_input!=log_solution.slice(0,log_input.size()):
			log_input.clear();control_lock=4;p.stress=minf(100,p.stress+7);station.make_noise(object.position,46);station.sound_event.rpc("alarm",object.position);tell(p,"Неверный захват. Сирена выдала ваше положение.")
		elif log_input.size()==4:log_ready=true;station.announce.rpc("Захваты пилорамы сняты. Лебёдка B готова к работе.")
	elif object.object_id.begins_with("pump_") and not pump_ready:
		pressure[i]=(int(pressure[i])+1)%6;tell(p,"Давление I / II / III: %d / %d / %d" % pressure)
	elif object.object_id.begins_with("signal_") and not signals_ready:
		rail_values[i]=(int(rail_values[i])+1)%4;signals_ready=rail_values==signal_solution;tell(p,"Стрелки A / B / C: %d / %d / %d" % rail_values)
		if signals_ready:station.announce.rpc("Маршрут на станцию установлен. Стрелки заблокированы в правильном положении.")
	station.sound_event.rpc("switch",object.position);station.sync_state()
func tick(delta: float) -> void:
	if not result.is_empty():return
	seconds_left=maxf(0,seconds_left-delta);control_lock=maxf(0,control_lock-delta);noise_clock=maxf(0,noise_clock-delta)
	var living: int=0
	for p: Node3D in station.players.get_children():
		if p.health>0:living+=1
	if station.players.get_child_count()>0 and living==0:finish("Вся бригада ранена. Лесник начал новую смену.");return
	if seconds_left<=0:finish("Туман сомкнулся. Лесобаза осталась без свидетелей.");return
	if escape_time>=0:_ride(delta);return
	if not emergency.is_empty():
		emergency_left=maxf(0,emergency_left-delta);var repairer: Node3D=actor(emergency)
		if repairer:
			emergency_repair+=delta*(1.5 if repairer.is_technician() else 1)
			if emergency_repair>=6:emergency="";emergency_repair=0;emergency_left=0;generator_on=powered;station.announce.rpc("Авария лесобазы устранена.")
		else:emergency_repair=maxf(0,emergency_repair-delta*.3)
		if not emergency.is_empty() and emergency_left<=0:finish("Пары дизеля вспыхнули. Бригада не успела восстановить аварийный контур.");return
	var p: Node3D=actor("generator")
	if not powered and emergency.is_empty():
		if p and "fuse" in p.inventory and "fuel" in p.inventory:
			power_progress+=delta*(1.5 if p.is_technician() else 1)
			if power_progress>=4:
				station.items.consume(p,"fuse");station.items.consume(p,"fuel");powered=true;generator_on=true;station.make_noise(station.objects.generator.position,40);station.announce.rpc("Дизель запущен. Захваты C, насос D и стрелки E получили питание.")
		else:
			power_progress=maxf(0,power_progress-delta)
			if p:tell(p,"Нужны предохранитель из сейфа A и канистра из шкафчика снабжения.")
	if not generator_on or not emergency.is_empty():exit_progress=maxf(0,exit_progress-delta);return
	p=actor("winch")
	if not winch_ready:
		if p and log_ready:
			winch_progress+=delta*(1.5 if p.is_technician() else 1);station.objects.rail_logs.position.x=9*minf(1,winch_progress/6);_noise(station.objects.winch.position)
			if winch_progress>=6:winch_ready=true;station.objects.rail_logs.position.x=9;station._refresh_equipment_navigation();station.announce.rpc("Завал стянут с рельсов. Шкаф ремня C разблокирован.")
		elif p:tell(p,"Сначала снимите четыре захвата C в порядке из журнала B.")
	p=actor("ventilation")
	if not pump_ready:
		if p and pressure==pressure_solution:
			pump_progress+=delta*(1.5 if p.is_technician() else 1);_noise(station.objects.ventilation.position)
			if pump_progress>=4:pump_ready=true;station.announce.rpc("Насос откачал топливо. Клетка канистры D разблокирована.")
		else:
			pump_progress=maxf(0,pump_progress-delta*.5)
			if p:tell(p,"Выставьте давление по журналу насосной D.")
	_tick_cart(delta)
func _noise(at: Vector3) -> void:
	if noise_clock>0:return
	noise_clock=2;station.make_noise(at,48);station.sound_event.rpc("scrape",at)
func _tick_cart(delta: float) -> void:
	var p: Node3D=actor("rail_cart")
	if install_owner!=0:
		var owner: Node3D=station.players.get_node_or_null(str(install_owner))
		if owner and owner.peer_id in holders.get("rail_cart",[]) and owner.health>0 and install_kind in owner.inventory:
			p=owner
		else:
			install_progress=maxf(0,install_progress-delta)
			if install_progress<=0:install_kind="";install_owner=0
			return
	if not p:
		install_progress=maxf(0,install_progress-delta)
		if install_progress<=0:install_kind="";install_owner=0
		exit_progress=maxf(0,exit_progress-delta);return
	if installed.size()<2 or not fueled:
		if install_owner!=0 and install_owner!=p.peer_id:return
		var needed: Array=PARTS.duplicate()
		if not fueled:needed.append("fuel")
		for kind: String in needed:
			if kind in installed or not kind in p.inventory:continue
			if install_kind!=kind:install_kind=kind;install_owner=p.peer_id;install_progress=0
			install_progress+=delta*(1.5 if p.is_technician() else 1)
			if install_progress>=2.5 and station.items.consume(p,kind):
				if kind=="fuel":fueled=true
				else:installed.append(kind)
				install_progress=0;install_kind="";install_owner=0;station.sync_state()
			return
		tell(p,"Нужны аккумулятор из B, ремень из C и канистра из D.");return
	if not winch_ready or not signals_ready:tell(p,"Путь не готов: нужны снятый завал B и стрелки E.");return
	if not "car_key" in p.inventory:tell(p,"Нужен ключ зажигания из личного шкафа F.");return
	for other: Node3D in station.players.get_children():
		if not other.dead and other.position.distance_to(station.objects.rail_cart.position)>6:tell(p,"Соберите всех выживших в шести метрах от дрезины.");exit_progress=0;return
	exit_progress+=delta;_noise(station.objects.rail_cart.position)
	if exit_progress>=8 and station.items.consume(p,"car_key"):
		escape_time=0;station.objects.exit_gate.locked=false;station.objects.exit_gate.opened=true;station.objects.exit_gate.refresh();station._update_doors_navigation()
		var seat: int=0
		for other: Node3D in station.players.get_children():
			if not other.dead:other.in_vehicle=true;other.vehicle_seat=seat;seat+=1
		station.announce.rpc("ДЕРЖИТЕСЬ! Дрезина тронулась. Лесник услышал гудок.");station.sound_event.rpc("alarm",station.objects.rail_cart.position);station.make_noise(station.objects.rail_cart.position,95)
		if bool(station.rules.monster):station.monster.change_state(station.monster.State.CHASE,station.objects.rail_cart.position)
func _ride(delta: float) -> void:
	escape_time+=delta;station.objects.rail_cart.position=Vector3(0,.8,lerpf(-74,-102,smoothstep(0,1,minf(1,escape_time/8))))
	for p: Node3D in station.players.get_children():
		if p.in_vehicle:
			p.position=station.objects.rail_cart.position+Vector3(-.45 if p.vehicle_seat%2==0 else .45,-.05,.35+floori(p.vehicle_seat/2)*.7);p.net_position=p.position
	if escape_time>=8:finish("Победа! Дрезина вывезла бригаду из Чёрного бора. В ведомости осталась одна лишняя фамилия.")
func sabotage(kind: String) -> bool:
	if not multiplayer.is_server() or not result.is_empty() or not emergency.is_empty() or escape_time>=0:return false
	emergency=kind if kind in ["generator","ventilation"] else "ventilation";emergency_left=120;emergency_repair=0
	if emergency=="generator":generator_on=false
	station.announce.rpc("АВАРИЯ: Лесник повредил "+("дизель A" if emergency=="generator" else "топливный насос D")+". Пары топлива: две минуты на ремонт, удерживайте E.");station.sound_event.rpc("alarm",station.objects[emergency].position);station.sync_state();return true
func finish(message: String) -> void:result=message;station.sync_state()
func task_text() -> String:
	if escape_time>=0:return "ДРЕЗИНА УХОДИТ • ДЕРЖИТЕСЬ\nЧёрный бор не хочет отпускать бригаду."
	if not emergency.is_empty():return "УТЕЧКА ДИЗЕЛЯ • %02d:%02d\n%s • ремонт %d%%" % [ceili(emergency_left)/60,ceili(emergency_left)%60,"Дизель A" if emergency=="generator" else "Насос D",int(emergency_repair/6*100)]
	if not powered:return "ЧЁРНЫЙ БОР • ВОССТАНОВИТЕ ПИТАНИЕ\nЖурналы A + F → сейф A → предохранитель. Канистра в шкафах.\nДизель A • удерживать E: %d%%" % int(power_progress/4*100)
	return "ПОДГОТОВЬТЕ ПОБЕГ НА ДРЕЗИНЕ\nЗахваты C: %d/4 • лебёдка B: %d%% • насос D: %d%%\nСтрелки E: %s • детали: %d/2 • топливо: %s\nКлюч F → вся команда у дрезины E • запуск: %d%%" % [4 if log_ready else log_input.size(),100 if winch_ready else int(winch_progress/6*100),100 if pump_ready else int(pump_progress/4*100),"готовы" if signals_ready else "настроить",installed.size(),"да" if fueled else "нет",int(exit_progress/8*100)]
func snapshot() -> Dictionary:
	var data: Dictionary={}
	for key: String in fields():data[key]=get(key)
	return data
func apply_snapshot(data: Dictionary) -> void:
	for key: String in fields():
		var value: Variant=data[key];set(key,value.duplicate() if value is Array else value)
static func fields() -> Array[String]:return ["seconds_left","result","generator_on","powered","emergency","emergency_left","emergency_repair","power_progress","log_solution","log_input","log_ready","control_lock","pressure","pressure_solution","pump_ready","pump_progress","rail_values","signal_solution","signals_ready","winch_progress","winch_ready","installed","install_progress","fueled","exit_progress","escape_time"]
