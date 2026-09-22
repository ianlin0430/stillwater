extends RefCounted
# One absence, one summary. While the window is hidden the world is advanced in
# roughly minute-long pieces; every piece folds into the same total so resuming
# reports the whole absence once instead of only the last fragment.

static func fresh(since: float) -> Dictionary:
	return {"since":since,"simulated":0.0,"seconds":0.0,"capped":false,"advances":0,"events":{}}

# Advance `world` over the part of the absence not simulated yet, and fold it in.
static func advance(total: Dictionary, world: StreamWorld, now: float) -> Dictionary:
	var pending: float=maxf(0,now-total.since-total.simulated)
	if pending<=0:
		return total
	var report: Dictionary=world.advance_offline(pending)
	total.simulated+=pending
	total.seconds+=report.seconds
	total.capped=total.capped or report.capped
	total.advances+=1
	for key: String in report.events:
		total.events[key]=total.events.get(key,0)+report.events[key]
	return total

static func text(report: Dictionary) -> String:
	if report.get("seconds",0)<120:
		return ""
	var out: String="While you were away: %.1f hours of stream life" % (report.seconds/3600)
	var events: Dictionary=report.get("events",{})
	for key: String in ["birth","arrival","departure","death"]:
		if events.get(key,0)>0:
			out+=" · %d %s" % [events[key],{"birth":"births","arrival":"arrivals","departure":"departures","death":"deaths"}[key]]
	if report.get("capped",false):
		out+=" · limited to three days"
	return out
