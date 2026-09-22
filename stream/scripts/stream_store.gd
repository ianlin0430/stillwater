class_name StreamStore
extends RefCounted
const DEFAULT_PATH: String = "user://stream.world"

static func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func save(path: String, world: StreamWorld) -> Error:
	var saved: Dictionary = world.export_state()
	if not StreamWorld.validate(saved):
		return ERR_INVALID_DATA
	var bytes: PackedByteArray = var_to_bytes(saved)
	var f := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:
		return FileAccess.get_open_error()
	f.store_var({"format":"stillwater-stream-1","payload":bytes,"hash":_digest(bytes)})
	f.flush()
	f.close()
	if read(path+".tmp").is_empty():
		return ERR_FILE_CORRUPT
	if not read(path).is_empty():
		var error: Error = DirAccess.copy_absolute(path,path+".bak.tmp")
		if error!=OK:
			return error
		if read(path+".bak.tmp").is_empty():
			return ERR_FILE_CORRUPT
		error=DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if error!=OK:
			return error
	return DirAccess.rename_absolute(path+".tmp",path)

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()>4000000:
		return {}
	var envelope: Variant = f.get_var(false)
	if not envelope is Dictionary or envelope.get("format")!="stillwater-stream-1":
		return {}
	var bytes: Variant = envelope.get("payload")
	if not bytes is PackedByteArray or envelope.get("hash")!=_digest(bytes):
		return {}
	var saved: Variant = bytes_to_var(bytes)
	return saved if saved is Dictionary and StreamWorld.validate(saved) else {}

static func load_or_create(path: String, now: float, seed_value: int=240921) -> Dictionary:
	var saved: Dictionary = read(path)
	var backup: bool = false
	if saved.is_empty():
		saved=read(path+".bak")
		backup=not saved.is_empty()
	var world := StreamWorld.new(seed_value,now)
	var destination: String = path
	var report: Dictionary = {"seconds":0.0,"events":{},"capped":false}
	var preserved: bool = false
	if not saved.is_empty():
		world.restore(saved)
		report=world.catch_up(now)
	elif FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
		preserved=true
		destination=path.get_basename()+"-recovery-"+str(int(now))+".world"
		var index: int = 1
		while FileAccess.file_exists(destination):
			destination=path.get_basename()+"-recovery-"+str(int(now))+"-"+str(index)+".world"
			index+=1
	# The progressed state and checkpoint commit in a single atomic replacement.
	# A crash before commit replays from the old state, not an already progressed one.
	var err: Error = save(destination,world)
	return {"world":world,"path":destination,"backup":backup,"preserved":preserved,"away":report,"error":err}
