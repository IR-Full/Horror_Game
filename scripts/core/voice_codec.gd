extends RefCounted
## Fixed LAN format: 20 ms, mono, 16 kHz, signed little-endian PCM16.
const RATE := 16000
const FRAMES := 320
const BYTES := FRAMES*2

static func resample(source: PackedVector2Array, gain: float = 1.0) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	if source.is_empty(): return result
	result.resize(FRAMES)
	var ratio: float = float(source.size())/FRAMES
	for i: int in range(FRAMES):
		var first: int = mini(int(i*ratio),source.size()-1)
		var end: int = mini(maxi(first+1,int((i+1)*ratio)),source.size())
		var value: float = 0
		for j: int in range(first,end): value += (source[j].x+source[j].y)*.5
		result[i] = clampf(value/maxi(1,end-first)*gain,-.95,.95)
	return result

static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	if samples.size() != FRAMES: return bytes
	bytes.resize(BYTES)
	for i: int in range(FRAMES):
		var value: float = samples[i] if is_finite(samples[i]) else 0.0
		bytes.encode_s16(i*2,roundi(clampf(value,-1,1)*32767))
	return bytes

static func decode(bytes: PackedByteArray) -> PackedVector2Array:
	var result := PackedVector2Array()
	if bytes.size() != BYTES: return result
	result.resize(FRAMES)
	for i: int in range(FRAMES): result[i] = Vector2.ONE*(bytes.decode_s16(i*2)/32768.0)
	return result

static func level(bytes: PackedByteArray) -> float:
	if bytes.size() != BYTES: return 0.0
	var sum: float = 0
	for i: int in range(FRAMES):
		var value: float = bytes.decode_s16(i*2)/32768.0
		sum += value*value
	return sqrt(sum/FRAMES)
