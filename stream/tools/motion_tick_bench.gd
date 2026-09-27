extends SceneTree
# Live motion tick benchmark and fingerprint (not a test). For each seed it builds
# StreamWorld.new(seed, 1000) and steps advance_live(0.2) for 2 simulated hours that cover day,
# night and dawn, one pinch of food, one tap on the glass and one cursor lure, then prints the
# SHA-256 of var_to_bytes(export_state()) ("final") and of every 10-minute checkpoint chained
# ("chain"). A speed-up must leave every hash bit-identical. Timing covers the advance_live
# loop only (motion plus the ecology tick every 300 motion ticks), in microseconds per 0.2 s tick,
# median of the repetitions. Other processes loading the CPU skew it; compare runs made back to back.
# godot --headless --path <absolute stream path> --script tools/motion_tick_bench.gd [-- reps=3]
#
# Baseline (ab2b263, before the motion tick speed-ups; 3 reps, load average ~4 from other agents):
#   seed 42      final 4ec6cb4ad0be14c6c9f9194fcf2ae879e2a460b0b3c1352310eab4817b3ae96c
#                chain 985c3e932a37ca73513e9ca923e9100dbcb24acef81631a73fc55fdcdd8b0a9f  143.7 us/tick
#   seed 812     final 3721e64ab5e1587792bcf2f2e891afe83192cfdf6bc2d756315234db5a815a04
#                chain 0e5c707046687bc2a4816b44d02f909de3d5664bdbe681fa2c5c854b730a4b6a  145.1 us/tick
#   seed 240921  final 2e2f298195336b9bdcf00410a05c58791c7f2a9854bf8247e1c28cdfb894ba4c
#                chain 8abc49c84cc1fbe3704b31617cd977eb33f53bfbdd42731521b2dd7ac990e54f  142.9 us/tick

const SEEDS: Array[int] = [42, 812, 240921]
const TICKS: int = 36000 # 2 simulated hours of 0.2 s ticks
const CHECK_EVERY: int = 3000 # 10 simulated minutes

func _initialize() -> void:
	var reps: int = 3
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("reps="):
			reps = maxi(1, int(arg.substr(5)))
	var out: Dictionary = {"ticks_per_seed": TICKS, "reps": reps, "seeds": {}}
	var all_us: Array[float] = []
	var stable: bool = true
	for s: int in SEEDS:
		var per_rep: Array[float] = []
		var hashes: Dictionary = {}
		for r in reps:
			var run: Dictionary = _run(s)
			per_rep.append(run.us_per_tick)
			if r == 0:
				hashes = {"final": run.final, "chain": run.chain}
			elif run.final != hashes.final or run.chain != hashes.chain:
				stable = false
		per_rep.sort()
		out.seeds[str(s)] = {"final": hashes.final, "chain": hashes.chain, "us_per_tick": per_rep, "median": per_rep[per_rep.size() / 2]}
		all_us.append(per_rep[per_rep.size() / 2])
	var total: float = 0.0
	for u: float in all_us:
		total += u
	out.mean_of_medians_us = snappedf(total / all_us.size(), 0.01)
	out.repeatable = stable
	print(JSON.stringify(out))
	quit()

func _run(world_seed: int) -> Dictionary:
	var w := StreamWorld.new(world_seed, 1000)
	var chain := HashingContext.new()
	chain.start(HashingContext.HASH_SHA256)
	var busy: int = 0
	var t0: int = Time.get_ticks_usec()
	for i in TICKS:
		# Fixed interaction schedule (tick index): day from 12:00, a pinch of food, a tap, a lure
		# held then cleared, night from 21:00, then the dawn crossing from 06:50.
		match i:
			0: w.state.light_hour = 12.0
			3000: w.feed(640.0)
			4500: w.startle(600.0, 300.0)
			6000: w.set_lure(Vector2(500.0, 320.0))
			7500: w.clear_lure()
			18000: w.state.light_hour = 21.0
			30000: w.state.light_hour = 6.0 + 50.0 / 60.0
		w.advance_live(0.2)
		if (i + 1) % CHECK_EVERY == 0:
			# The checkpoint hash is left out of the timing.
			busy += Time.get_ticks_usec() - t0
			chain.update(var_to_bytes(w.export_state()))
			t0 = Time.get_ticks_usec()
	var final := HashingContext.new()
	final.start(HashingContext.HASH_SHA256)
	final.update(var_to_bytes(w.export_state()))
	return {"final": final.finish().hex_encode(), "chain": chain.finish().hex_encode(), "us_per_tick": float(busy) / TICKS}
