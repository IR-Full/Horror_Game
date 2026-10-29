extends Node3D
## Bounded world-space wounds. A new hit grows one pool; old pools stay after recovery.
var actor: CharacterBody3D
var seen_serial: int = 0
var pools: Array[MeshInstance3D] = []
var records: Array[Dictionary] = []
func _process(_delta: float) -> void:
	if actor.hit_serial>seen_serial:
		seen_serial=actor.hit_serial
		var pool: MeshInstance3D=preload("res://scripts/art/blood_traces.gd").make_pool(Vector3.ZERO,Vector2(1.0,1.2),float(seen_serial*17+actor.station.map_id))
		add_child(pool); pool.top_level=true; pool.hide()
		pools.append(pool)
		records.append({"serial":seen_serial,"born":Time.get_ticks_msec()-int((60-actor.stunned_left)*1000),"impact":actor.fall_duration()-.25,"spread":0.0})
		if pools.size()>4: pools.pop_front().queue_free(); records.pop_front()
	for i: int in range(pools.size()):
		var pool: MeshInstance3D=pools[i]
		var record: Dictionary=records[i]
		var age: float=(Time.get_ticks_msec()-int(record.born))*.001
		if int(record.serial)==actor.hit_serial and actor.state==actor.State.STUNNED:
			pool.global_position=actor.blood_anchor
			pool.rotation.y=actor.net_rotation
		var bleeding: float=maxf(0,age-float(record.impact))
		pool.visible=age>=float(record.impact)
		var spread: float=.06+.94*clampf(bleeding/32,0,1)
		record.spread=spread
		pool.material_override.set_shader_parameter("spread",spread)
		pool.material_override.set_shader_parameter("age",clampf(age/150,0,.75))
		pool.material_override.set_shader_parameter("fresh_boost",1-clampf(age/150,0,1))
		pool.set_meta("blood_radius",Vector2(1.0,1.2)*spread)
