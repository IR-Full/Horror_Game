extends RefCounted
const LABELS := ["Последний сигнал • станция", "Последний рейс • автобаза"]
const DESCRIPTIONS := ["5 секторов • 30 помещений • восстановить связь", "5 секторов • автобаза 126×172 м • собрать машину и уехать"]
static func layout(id: int) -> Script:
	return preload("res://scripts/world/depot_layout.gd") if id == 1 else preload("res://scripts/world/sector_layout.gd")
static func monster_model(id: int) -> String:
	return "entity_depot" if id == 1 else "entity"
