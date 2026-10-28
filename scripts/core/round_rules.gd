extends RefCounted
## Host selects one immutable profile before the world is created.
const LABELS := ["Лёгкая", "Обычная", "Тяжёлая", "Без монстра"]

static func profile(level: int) -> Dictionary:
	var result := {"monster":true, "ammo":4, "chase_speed":3.4, "sabotage_delay":35.0, "sabotage_cooldown":70.0, "ambient":.012, "lighting":.42}
	match level:
		0: result.ammo = 6; result.ambient = .024; result.lighting = .6
		2: result.ammo = 2; result.chase_speed = 5.3; result.sabotage_delay = 18.0; result.sabotage_cooldown = 45.0; result.ambient = .004; result.lighting = .23
		3: result.monster = false; result.ambient = .024; result.lighting = .6
	return result
