extends RefCounted
const LABELS := ["Последний сигнал • станция", "Последний рейс • автобаза", "Павильон 13 • психбольница", "Чёрный бор • лесобаза", "Нулевая отметка • шахта"]
const DESCRIPTIONS := ["5 секторов • 30 помещений • восстановить связь", "5 секторов • автобаза 126×172 м • собрать машину и уехать", "5 отделений • 24 помещения • кровавый доктор • образцы и эвакуационный лифт", "6 зон • ночной лес • Лесник • лебёдка, стрелки и побег на дрезине", "6 камер • шахтный газ • Штрековый • эвакуационная клеть"]
static func layout(id: int) -> Script:
	if id == 4: return preload("res://scripts/world/mine_layout.gd")
	if id == 3: return preload("res://scripts/world/forest_layout.gd")
	if id == 2: return preload("res://scripts/world/hospital_layout.gd")
	return preload("res://scripts/world/depot_layout.gd") if id == 1 else preload("res://scripts/world/sector_layout.gd")
static func monster_model(id: int) -> String:
	if id == 4: return "entity_miner"
	if id == 3: return "entity_forester"
	if id == 2: return "entity_doctor"
	return "entity_depot" if id == 1 else "entity"
static func objectives(id: int) -> Script:
	if id == 4: return preload("res://scripts/world/mine_objective_system.gd")
	if id == 3: return preload("res://scripts/world/forest_objective_system.gd")
	if id == 2: return preload("res://scripts/world/hospital_objective_system.gd")
	return preload("res://scripts/world/vehicle_objective_system.gd") if id == 1 else preload("res://scripts/world/objective_system.gd")
static func safe_hint(id: int) -> String:
	return ["Три цифры. Подсказка — в медпункте.","Четыре цифры. Накладная D + журнал охраны E.","Четыре цифры. Сейф A: журналы A + B. Морг D: журнал лаборатории E.","Четыре цифры. Сейф A: журналы A + F. Аккумулятор B: журнал насосной D.","Четыре цифры. Сейф A: журналы A + F. Сейф B: журнал D."][id]
static func plan_title(id: int) -> String: return ["ПЛАН РС–17","ПЛАН АВТОБАЗЫ","ПЛАН ПАВИЛЬОНА 13","ПЛАН ЛЕСОБАЗЫ • ЧЁРНЫЙ БОР","ПЛАН ШАХТЫ • НУЛЕВАЯ ОТМЕТКА"][id]
static func victory_title(id: int) -> String: return ["СИГНАЛ ПРИНЯТ","ВЫЕЗД ЗАВЕРШЁН","ЭВАКУАЦИЯ ЗАВЕРШЕНА","БРИГАДА ПОКИНУЛА ЛЕС","ПОДЪЁМ ЗАВЕРШЁН"][id]
