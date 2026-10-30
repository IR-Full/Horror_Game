extends RefCounted
## Finite draws and randomized bipartite matching. All callers run on the host.
static func history(name: String,memory: Dictionary={}) -> Dictionary:
	if not memory.is_empty():return memory.duplicate(true)
	var cfg:=ConfigFile.new()
	if cfg.load(SettingsManager.save_path.get_base_dir().path_join("last_"+name+".cfg"))!=OK:return {}
	var saved: Variant=cfg.get_value("puzzles","solutions",{})
	return saved if saved is Dictionary else {}

static func remember(name: String,value: Dictionary) -> void:
	var cfg:=ConfigFile.new();cfg.set_value("puzzles","solutions",value)
	var error: Error=cfg.save(SettingsManager.save_path.get_base_dir().path_join("last_"+name+".cfg"))
	if error!=OK:push_warning("Cannot save round history: "+name+" ("+str(error)+")")

static func digits(base: int,previous: Array,count: int=3) -> Array:
	var result: Array=[]
	for i: int in range(count):
		var options: Array=range(base)
		if i<previous.size():options.erase(previous[i])
		result.append(options.pick_random())
	if result.count(0)==count:
		var index: int=randi_range(0,count-1);var options: Array=range(1,base)
		if index<previous.size():options.erase(previous[index])
		result[index]=options.pick_random()
	return result

static func code(length: int,previous: String,forbidden: Array=[]) -> String:
	var result: String=""
	for i: int in range(length):
		var options: Array=range(1 if i==0 else 0,10)
		if previous.length()==length:options.erase(int(previous.substr(i,1)))
		if i==length-1:
			for value: String in forbidden:
				if value.length()==length and value.begins_with(result):options.erase(int(value.right(1)))
		result+=str(options.pick_random())
	return result

static func order(count: int,previous: Array) -> Array:
	var result: Array=range(count)
	var sorted: Array=previous.duplicate();sorted.sort()
	if sorted!=result:previous=[]
	for attempt: int in range(64):
		result.shuffle();var different: bool=true
		for i: int in range(mini(count,previous.size())):
			if result[i]==previous[i]:different=false;break
		if different:return result
	# A rotation of a valid previous permutation is always a derangement.
	var shift: int=randi_range(1,count-1)
	for i: int in range(count):result[i]=previous[(i+shift)%count]
	return result

static func assign(ids: Array,slots: Array,previous: Dictionary,kinds: Dictionary={},exclude_old_layout: bool=false) -> Dictionary:
	var choices: Dictionary={}
	for id: String in ids:
		var options: Array=slots.duplicate()
		if previous.has(id):options.erase(previous[id])
		for old_id: String in previous:
			if exclude_old_layout or (kinds.has(id) and kinds.get(old_id,"")==kinds[id]):options.erase(previous[old_id])
		options.shuffle();choices[id]=options
	var owners: Dictionary={};var selected: Dictionary={};var shuffled: Array=ids.duplicate();shuffled.shuffle()
	for id: String in shuffled:
		if not _augment(id,choices,owners,selected,{}):
			push_error("No non-repeating loot assignment for "+id)
			return {}
	return selected

static func _augment(id: String,choices: Dictionary,owners: Dictionary,selected: Dictionary,seen: Dictionary) -> bool:
	for slot: Variant in choices[id]:
		if seen.has(slot):continue
		seen[slot]=true
		if not owners.has(slot) or _augment(str(owners[slot]),choices,owners,selected,seen):
			owners[slot]=id;selected[id]=slot;return true
	return false
