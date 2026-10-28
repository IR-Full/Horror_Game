extends RefCounted
## Bounded per-speaker reorder queue. Old audio is dropped instead of accumulating.
const CODEC := preload("res://scripts/core/voice_codec.gd")
const LIMIT := 12
var pending: Dictionary = {}
var next_sequence: int = -1
var start_at: float = 0
var last_packet: float = -100
var started: bool = false
var concealed: int = 0

func insert(sequence: int, bytes: PackedByteArray, now: float) -> bool:
	if bytes.size() != CODEC.BYTES or pending.has(sequence): return false
	if started and sequence < next_sequence: return false
	if now-last_packet > .18:
		pending.clear()
		started = false
		next_sequence = sequence
		start_at = now+.06
	if pending.size() >= LIMIT or (next_sequence >= 0 and sequence-next_sequence > LIMIT*4):
		pending.clear()
		started = false
		next_sequence = sequence
		start_at = now+.06
	if not started: next_sequence = mini(next_sequence,sequence)
	pending[sequence] = bytes
	last_packet = now
	return true

func pop(now: float) -> PackedByteArray:
	if now < start_at or pending.is_empty(): return PackedByteArray()
	started = true
	if pending.has(next_sequence):
		var result: PackedByteArray = pending[next_sequence]
		pending.erase(next_sequence)
		next_sequence += 1
		return result
	# A later packet has arrived; conceal a lost 20 ms frame with silence.
	concealed += 1
	next_sequence += 1
	var silence := PackedByteArray()
	silence.resize(CODEC.BYTES)
	return silence
