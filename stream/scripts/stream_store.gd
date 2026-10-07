class_name StreamStore
extends RefCounted
const DEFAULT_PATH: String = "user://reef.world"
# World v3 (Stillwater Reef, 2026-09-28): a new world in a new file. Stillwater Stream saves
# (world v1/v2) used LEGACY_FORMAT; they are never loaded, converted, rewritten or deleted.
const FORMAT: String = "stillwater-reef-3"
const LEGACY_FORMAT: String = "stillwater-stream-1"

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
	f.store_var({"format":FORMAT,"payload":bytes,"hash":_digest(bytes)})
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

static func _envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()<8 or f.get_length()>4000000:
		return {}
	# FileAccess.store_var prefixes the encoded Variant with its 32-bit size.
	# Reject incomplete records before get_var allocates/reads their payload.
	var length: int=f.get_32()
	if length<4 or length>f.get_length()-4:
		return {}
	f.seek(0)
	var envelope: Variant = f.get_var(false)
	return envelope if envelope is Dictionary else {}

static func read(path: String) -> Dictionary:
	var envelope: Dictionary=_envelope(path)
	if envelope.get("format")!=FORMAT:
		return {}
	var bytes: Variant = envelope.get("payload")
	if not bytes is PackedByteArray or envelope.get("hash")!=_digest(bytes):
		return {}
	var saved: Variant = bytes_to_var(bytes)
	return saved if saved is Dictionary and StreamWorld.validate(saved) else {}

# Only the envelope label is looked at; the old world inside is never decoded.
static func _legacy(path: String) -> bool:
	for candidate: String in [path,path+".bak"]:
		var envelope: Dictionary=_envelope(candidate)
		if envelope.get("format")==LEGACY_FORMAT:
			return true
	return false

# `path` may still name a Stillwater Stream save (preferences.cfg keeps the path of the last
# launch). Then the world lives in reef.world beside it instead, and the returned "path" says so:
# the old files stay as they are and no recovery world is made for them.
static func load_or_create(path: String, now: float, seed_value: int=240921) -> Dictionary:
	var legacy: bool = _legacy(path)
	if legacy:
		path=path.get_base_dir().path_join(DEFAULT_PATH.get_file())
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
	return {"world":world,"path":destination,"backup":backup,"preserved":preserved,"legacy":legacy,"away":report,"error":err}
