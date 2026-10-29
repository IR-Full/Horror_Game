extends Node
## Server-owned stress, exertion tiers and audible breathing; local audio is cosmetic.
var actor: CharacterBody3D
var noise_clock: float = 0
var light_breath: Node
var heavy_breath: Node
var intensity: float = 0

static func breath_level(stamina: float,stress: float) -> float:
	var effort: float = 0.0 if stamina >= 65 else (.25 if stamina >= 35 else (.6 if stamina >= 15 else 1.0))
	return maxf(effort,clampf((stress-65)/35,0,1)*.8)

func server_tick(delta: float) -> void:
	actor.calm_cooldown = maxf(0,actor.calm_cooldown-delta)
	if actor.dead or actor.health <= 0 or actor.in_vehicle or actor.vent_time > 0: return
	var world: Node3D = GameManager.world
	if not is_instance_valid(world) or not world.objectives.result.is_empty(): return
	var ally: float = INF
	for other: Node3D in world.players.get_children():
		if other != actor and other.health > 0: ally = minf(ally,actor.position.distance_to(other.position))
	var threat: float = 0
	var monster: Node3D = world.monster
	if bool(world.rules.monster) and monster.state not in [0,6]:
		var distance: float = actor.position.distance_to(monster.position)
		if distance < 20 and world.can_see(actor.eye_position(),monster,[actor.get_rid()]): threat = (1-distance/20)*2.4
		if monster.state == monster.State.CHASE and monster.target_id == actor.peer_id: threat += 1.0
	var gain: float = (.38 if not actor.lamp_on or actor.battery <= 0 else 0.0)+(.12 if ally > 12 else 0.0)+threat
	var recovery: float = .15 if actor.lamp_on and actor.battery > 0 else 0.0
	if threat <= 0:
		if ally < 5: recovery += .45
		for zone: Vector3 in world.calm_zones:
			if actor.position.distance_to(zone) < 4 and (world.objectives.generator_on or actor.lamp_on): recovery += 1.1; break
	actor.stress = clampf(actor.stress+(gain-recovery)*delta,0,100)
	noise_clock -= delta
	var radius: float = 10.0 if actor.stress >= 85 and actor.stamina < 35 else (4.0 if actor.stamina < 15 else 0.0)
	if radius > 0 and noise_clock <= 0:
		noise_clock = 4
		world.make_noise(actor.position,radius)

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	for kind: String in ["player_breath_calm","player_breath_heavy"]:
		if not AudioManager.sounds.has(kind): continue
		var stream: AudioStream = AudioManager.stream_for(kind)
		var player: Node
		if actor.is_local(): player = AudioStreamPlayer.new()
		else:
			player = AudioStreamPlayer3D.new()
			player.max_distance = 10
			player.unit_size = 2
			player.position.y = 1.45
		player.stream = stream
		player.bus = "Effects"
		player.volume_db = -60
		actor.add_child.call_deferred(player)
		if kind == "player_breath_calm": light_breath = player
		else: heavy_breath = player

func _process(delta: float) -> void:
	if not is_instance_valid(light_breath) or not light_breath.is_inside_tree(): return
	var target: float = breath_level(actor.stamina,actor.stress) if actor.health > 0 and not actor.in_vehicle and NetworkManager.in_match else 0.0
	intensity = move_toward(intensity,target,delta*(.9 if target > intensity else .4))
	for player: Node in [light_breath,heavy_breath]:
		if not is_instance_valid(player): continue
		if intensity > .02:
			if not player.playing: player.play()
			var loudness: float = (1-intensity)*intensity if player == light_breath else intensity*intensity
			player.volume_db = linear_to_db(maxf(loudness,.001))-11
			player.pitch_scale = lerpf(.94,1.16,intensity)
		else: player.stop()

func _exit_tree() -> void:
	for player: Node in [light_breath,heavy_breath]:
		if is_instance_valid(player): player.stop(); player.stream = null
