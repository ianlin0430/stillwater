class_name SaveStore
extends RefCounted

static func fresh_path_if_unreadable(path: String) -> String:
	if not load_world(path).is_empty():
		return path
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return path
	# Preserve incompatible or damaged files, including an unreadable backup.
	var base: String = path.get_basename() + "-recovery-" + str(int(Time.get_unix_time_from_system()))
	var candidate: String = base + ".world"
	var suffix: int = 1
	while FileAccess.file_exists(candidate) or FileAccess.file_exists(candidate + ".bak"):
		candidate = base + "-%d.world" % suffix
		suffix += 1
	return candidate

static func save_world(path: String, sim: Ecosystem) -> Error:
	var payload: PackedByteArray = var_to_bytes(sim.export_state())
	var envelope: Dictionary = {"format": "stillwater-1", "payload": payload, "sha256": _hash(payload)}
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(envelope)
	file.flush()
	file.close()
	if read_world(temp).is_empty():
		return ERR_FILE_CORRUPT
	# Only rotate a verified previous version; retain good backup if primary was corrupt.
	if FileAccess.file_exists(path) and not read_world(path).is_empty():
		var copy_error: Error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if copy_error != OK:
			return copy_error
		var rotate_error: Error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if rotate_error != OK:
			return rotate_error
	return DirAccess.rename_absolute(temp, path)

static func _hash(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

static func read_world(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > 100000000:
		return {}
	var envelope: Variant = f.get_var(false)
	if not envelope is Dictionary or envelope.get("format", "") != "stillwater-1":
		return {}
	var payload: Variant = envelope.get("payload")
	if not payload is PackedByteArray or _hash(payload) != envelope.get("sha256", ""):
		return {}
	var saved: Variant = bytes_to_var(payload)
	if not saved is Dictionary or not Ecosystem.validate(saved):
		return {}
	return saved

static func load_world(path: String) -> Dictionary:
	var saved: Dictionary = read_world(path)
	if not saved.is_empty():
		return {"state": saved, "backup": false}
	saved = read_world(path + ".bak")
	return {} if saved.is_empty() else {"state": saved, "backup": true}
