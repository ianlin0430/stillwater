#!/usr/bin/env python3
"""S2 (2026-09-28) sizing sweep for the reef v3 cast; criteria in docs/ecology.md
"Reef v3 cast sizing". Runs tools/cast_probe.gd offline and judges its JSON lines.

  s2_sweep.py config --mf=1.0 --caps=8,3,4,3 [--out=file.json]      write one probe config
  s2_sweep.py run --mf=1.0 --caps=8,3,4,3 --seeds=42,812 --days=180 --log=out.jsonl [--mid=180]
  s2_sweep.py judge out.jsonl [...] [--year]                         table of criteria per config
"""
import json, math, os, subprocess, sys, tempfile

STREAM = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ORDER = ["green_chromis", "clownfish", "seahorse", "royal_gramma"]
OPENING = {"green_chromis": 6, "clownfish": 2, "seahorse": 2, "royal_gramma": 2}
OPENING_AGE = [40.0, 150.0]
# Authored design numbers (docs/ecology.md, written before probing). Chromis is the world's own entry.
NEW = {
    "clownfish": {"label": "Clownfish", "latin": "Amphiprion ocellaris", "initial": 2, "mature": 45.0, "lifespan": 300.0, "body": 0.6, "reserve": 4.0, "cost": 0.2, "bite": 0.5, "brood": 2, "breed": 0.06, "cooldown": 12.0, "pool": "microfauna", "k_food": 10.0},
    "seahorse": {"label": "Seahorse", "latin": "Hippocampus kuda", "initial": 2, "mature": 60.0, "lifespan": 300.0, "body": 0.5, "reserve": 3.5, "cost": 0.16, "bite": 0.4, "brood": 2, "breed": 0.05, "cooldown": 14.0, "pool": "microfauna", "k_food": 10.0},
    "royal_gramma": {"label": "Royal gramma", "latin": "Gramma loreto", "initial": 2, "mature": 40.0, "lifespan": 240.0, "body": 0.4, "reserve": 3.0, "cost": 0.16, "bite": 0.4, "brood": 2, "breed": 0.07, "cooldown": 10.0, "pool": "microfauna", "k_food": 10.0},
}
LIFESPAN = {"green_chromis": 180.0, **{k: v["lifespan"] for k, v in NEW.items()}}


def opt(args, key, default=None):
    for a in args:
        if a.startswith("--" + key + "="):
            return a.split("=", 1)[1]
    return default


def caps_of(text):
    return dict(zip(ORDER, [int(x) for x in text.split(",")]))


def config(mf, caps):
    return {"name": "mf%s-%s" % (mf, "/".join(str(caps[k]) for k in ORDER)), "active": ORDER, "cap": caps,
            "species": NEW, "initial": {"green_chromis": OPENING["green_chromis"]},
            "stream_in": {"nutrients": 0.7, "microfauna": float(mf)}, "opening_age": {"fish": OPENING_AGE},
            "rescue_at": 1, "floor": 0.1}


def run(args):
    cfg = config(opt(args, "mf"), caps_of(opt(args, "caps")))
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(cfg, f)
    cmd = ["godot", "--headless", "--path", STREAM, "--script", "tools/cast_probe.gd", "--", "--config=" + f.name,
           "--seeds=" + opt(args, "seeds"), "--days=" + opt(args, "days", "180"), "--mid=" + opt(args, "mid", "0")]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=int(opt(args, "timeout", "3000")))
    os.unlink(f.name)
    lines = [l for l in out.stdout.splitlines() if l.startswith("{")]
    bad = [l for l in (out.stdout + out.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
    if out.returncode != 0 or bad or not lines:
        sys.exit("probe failed (%d): %s" % (out.returncode, (bad or [out.stderr[-500:]])[0]))
    with open(opt(args, "log"), "a") as log:
        for l in lines:
            log.write(l + "\n")


# --- criteria (docs/ecology.md, C1-C6) ---
def openers_low(sp):
    n = OPENING[sp]
    return [OPENING_AGE[0] + (OPENING_AGE[1] - OPENING_AGE[0]) * i / n for i in range(n)]


def certain_old_age(days):
    return sum(1 for sp in ORDER for lo in openers_low(sp) if lo + days > LIFESPAN[sp] * 1.15)


def first_old_bound():
    return math.ceil(min(LIFESPAN[sp] * 1.15 - openers_low(sp)[-1] for sp in ORDER))


def judge_one(r, cap_sum, year=False):
    fails = []
    hits = sum(r["floor_hits"].values()) if "floor_hits" in r else None
    if hits is None:
        fails.append("C1:no-floor-measure")
    elif hits > 0 or r["starvation"]:
        fails.append("C1:floor_hits=%d" % hits)
    if r["microfauna_min_mean"][0] < 10.0:
        fails.append("C2:mf_min=%.2f" % r["microfauna_min_mean"][0])
    births, arrivals = sum(r["births"].values()), r["arrivals"]
    if not births > arrivals:
        fails.append("C4:births=%d<=arrivals=%d" % (births, arrivals))
    if year:
        gone = [sp for sp in ORDER if r["end"].get(sp, 0) < 1]
        if gone:
            fails.append("end:absent=" + ",".join(gone))
        return fails
    sizes = r["sizes_by_day"]
    inband = sum(1 for s in sizes if 12 <= s <= cap_sum) / len(sizes)
    if max(sizes) > cap_sum or inband < 0.8:
        fails.append("C3:max=%d,inband=%.2f" % (max(sizes), inband))
    for sp in ORDER:
        p = r["presence"][sp]
        if (len(sizes) - p["absent_days"]) / len(sizes) < 0.95 or p["longest_absence"] > 30:
            fails.append("C5:%s absent %d d" % (sp, p["absent_days"]))
    days = r["days"]
    old = sum(r["old_age"].values())
    if old < certain_old_age(days) or r["first_old_age_day"] <= 0 or r["first_old_age_day"] > first_old_bound():
        fails.append("C6:old=%d first=%d" % (old, r["first_old_age_day"]))
    need = certain_old_age(days) + cap_sum - sum(OPENING.values())
    produced = births + sum(r["dispersal"].values())
    if produced < need:
        fails.append("C6:offspring=%d<%d" % (produced, need))
    return fails


def judge(args):
    year = "--year" in args
    by = {}
    for path in [a for a in args if not a.startswith("--")]:
        for l in open(path):
            r = json.loads(l)
            if not year and r["days"] != 180:
                r = r.get("at_180", r)
            by.setdefault(r["name"], []).append(r)
    print("| config | seeds | pass | worst seed (mf min) | mf min range | min energy/reserve | size range (mean) | births/arrivals (tightest seed) | failures |")
    print("|---|---|---|---|---|---|---|---|---|")
    cap_sum_of = lambda n: sum(int(x) for x in n.split("-")[1].split("/"))
    for name in sorted(by, key=lambda n: (-cap_sum_of(n), n)):
        rs = by[name]
        res = [(r, judge_one(r, cap_sum_of(name), year)) for r in rs]
        worst = min(rs, key=lambda r: r["microfauna_min_mean"][0])
        mfs = [r["microfauna_min_mean"][0] for r in rs]
        me = min(min(r.get("min_energy", {"?": float("nan")}).values()) for r in rs)
        tight = min(rs, key=lambda r: sum(r["births"].values()) - r["arrivals"])
        fails = {}
        for r, f in res:
            for x in f:
                fails.setdefault(x.split(":")[0], []).append("%d(%s)" % (r["seed"], x.split(":", 1)[1]))
        print("| %s | %d | %d | %d (%.2f) | %.2f–%.2f | %.3f | %d–%d (%.1f–%.1f) | %d/%d (seed %d) | %s |" % (
            name, len(rs), sum(1 for _, f in res if not f), worst["seed"], worst["microfauna_min_mean"][0], min(mfs), max(mfs), me,
            min(r["size_min"] for r in rs), max(r["size_max"] for r in rs), min(r["size_mean"] for r in rs), max(r["size_mean"] for r in rs),
            sum(tight["births"].values()), tight["arrivals"], tight["seed"],
            "; ".join("%s: %s" % (k, ", ".join(v[:6]) + (" …+%d" % (len(v) - 6) if len(v) > 6 else "")) for k, v in fails.items()) or "—"))


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "config":
        text = json.dumps(config(opt(args, "mf"), caps_of(opt(args, "caps"))), indent=1)
        if opt(args, "out"):
            open(opt(args, "out"), "w").write(text + "\n")
        else:
            print(text)
    elif cmd == "run":
        run(args)
    elif cmd == "judge":
        judge(args)
