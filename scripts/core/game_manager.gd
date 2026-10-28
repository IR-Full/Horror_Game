extends Node
## Session-independent entry point; world is replaced on every round.
signal world_changed
var world: Node3D
var interface: Node

func _ready() -> void:
	var keys := {
		"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_CTRL, "interact": KEY_E,
		"flashlight": KEY_F, "shout": KEY_V, "drop": KEY_G,
		"use_item": KEY_R, "slot": KEY_Q, "pause": KEY_ESCAPE
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func local_player() -> Node3D:
	if not is_instance_valid(world):
		return null
	return world.get_node_or_null("Players/%s" % multiplayer.get_unique_id())

func notice(message: String) -> void:
	if is_instance_valid(interface):
		interface.show_notice(message)
