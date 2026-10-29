extends RefCounted
## Place visible geometry on supports without moving interaction anchors.
const FLOOR_PROPS: Array[String]=["desk","shelf","cot","chair","crate","radio_rack","barrel","boiler","operating_table","hospital_trolley","surgical_lamp","escape_car"]
const FLOOR_EQUIPMENT: Array[String]=["generator","transmitter","ventilation","purifier","drain_pump","hospital_station"]
const STANDING_CONTROLS: Array[String]=["circuit","tuner","drain_switch","depot_dial","hospital_control","valve"]

static func bounds(root: Node3D) -> AABB:
	var result:=AABB();var first: bool=true
	for part: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if not part.visible: continue
		var box: AABB=part.global_transform*part.get_aabb()
		result=box if first else result.merge(box);first=false
	return result

static func settle(world: Node3D) -> void:
	for node: Node in world.find_children("*","Node3D",true,false):
		if not node.has_meta("art_kind"):continue
		var kind: String=node.get_meta("art_kind")
		if kind in FLOOR_PROPS and node.get_parent() is not StaticBody3D and node.global_position.y<.15:
			var box: AABB=bounds(node)
			node.global_position.y+=world.support_height(node.global_position)+.004-box.position.y
			box=bounds(node)
			for proxy: StaticBody3D in world.find_children("*","StaticBody3D",true,false):
				if not proxy.has_meta("prop_proxy") or Vector2(proxy.position.x,proxy.position.z).distance_to(Vector2(node.global_position.x,node.global_position.z))>.08:continue
				proxy.global_position=box.get_center()
				for shape: CollisionShape3D in proxy.find_children("*","CollisionShape3D",true,false):shape.shape.size=box.size
				break
			if kind in ["desk","shelf","crate","operating_table","hospital_trolley"]: world.support_surfaces.append(bounds(node))
		elif kind=="lamp":
			var box: AABB=bounds(node)
			for x: float in [-.4,.4]: world.block(Vector3(node.global_position.x+x,(box.end.y+3.3)*.5,node.global_position.z),Vector3(.014,maxf(.02,3.3-box.end.y),.014),"293e40",false)
		elif kind in ["recorder","rotary_phone","scalpel"] and node.global_position.y>.1 and node.get_parent() is not StaticBody3D:
			var box: AABB=bounds(node)
			node.global_position.y+=world.support_height(node.global_position)+.006-box.position.y
	for object: Node3D in world.objects.values():
		if object.kind in FLOOR_EQUIPMENT:
			var box: AABB=bounds(object.mesh)
			object.mesh.position.y+=world.support_height(object.position)+.004-box.position.y
			box=bounds(object.mesh)
			object.collider.position=object.to_local(box.get_center())
			object.collider.shape.size=box.size.max(Vector3(.1,.1,.1))
		elif object.kind in STANDING_CONTROLS:
			var box: AABB=bounds(object.mesh)
			var height: float=maxf(.1,box.position.y)
			world.block(Vector3(object.position.x,height*.5,object.position.z+.06),Vector3(.11,height,.11),"293e40",false)
			world.block(Vector3(object.position.x,.035,object.position.z+.06),Vector3(.42,.07,.35),"293e40",false)
	for rect: Rect2 in world.layout.FLOORS:
		for i: int in range(1,int(rect.size.y/8)+1): world.block(Vector3(rect.get_center().x,3.24,rect.position.y+i*8-.3),Vector3(rect.size.x,.12,.12),"293e40",false)
