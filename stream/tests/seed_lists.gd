extends RefCounted
# Fixed wide seed lists (docs/plans/2026-09-28-redesign-backend.md §6.3), fixed on 2026-09-28
# before any probe of the new cast was run: they were written down, not picked from results.
# Ecology numbers must pass on EVERY seed here, not on most. Never edit or reorder these;
# new seeds may only be appended at the end.
const WIDE: Array[int] = [42, 812, 240921, 1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 101, 202, 303, 404, 505, 606, 707, 808, 909, 1234, 4321, 9999, 31337, 65537, 123456, 999983]
# Motion tests are slower: the first eight of WIDE.
const MOTION_COUNT: int = 8

static func motion() -> Array[int]:
	return WIDE.slice(0,MOTION_COUNT)
