extends SceneTree
# Malformed framing must be rejected without reading user data or creating worlds.
const DIR: String="res://artifacts/store-truncated-test/"
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

static func framing_checks(verify: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String=DIR+"fixture.world"
	var valid: Dictionary={"format":StreamStore.LEGACY_FORMAT,"payload":PackedByteArray([1,2,3])}
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_var(valid)
	f.close()
	var original: PackedByteArray=FileAccess.get_file_as_bytes(path)
	verify.call(StreamStore._envelope(path)==valid,"A complete store_var record retains its envelope")
	verify.call(StreamStore._legacy(path),"Legacy detection still recognizes a complete envelope")
	verify.call(StreamStore.read(path).is_empty(),"Legacy envelope is never loaded as current world")
	var huge:=PackedByteArray([255,255,255,255,0,0,0,0])
	var malformed: Array[PackedByteArray]=[
		PackedByteArray(),PackedByteArray([1]),PackedByteArray([1,2,3]),
		PackedByteArray([0,0,0,0,0,0,0,0]),huge,
		original.slice(0,original.size()-1),"not a stillwater world".to_utf8_buffer()]
	for i in malformed.size():
		f=FileAccess.open(path,FileAccess.WRITE)
		f.store_buffer(malformed[i])
		f.close()
		verify.call(StreamStore.read(path).is_empty() and not StreamStore._legacy(path),"Malformed framing rejected: "+str(i))
		verify.call(FileAccess.get_file_as_bytes(path)==malformed[i],"Rejected input remains byte-identical: "+str(i))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(DIR)

func _initialize() -> void:
	framing_checks(check)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
