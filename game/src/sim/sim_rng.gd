class_name SimRng
extends RefCounted
## Counter-based deterministic randomness: value = hash(seed, tick, region, stream).
## Unlike a sequential RNG, a draw does not depend on how many other draws happened before it,
## so (a) results are reproducible from (seed, tick, region) alone, (b) adding a new system that
## consumes randomness does not shift existing outcomes, and (c) two runs that differ only in
## policy see the SAME hazard events, enabling exact paired comparisons of mitigation.

const M32 := 0xFFFFFFFF

enum Stream { FLOOD_OCCURS = 1, FLOOD_SEVERITY = 2 }


static func _mix(x: int) -> int:
	# 32-bit integer hash (degski/"hash32" variant); all intermediates stay < 2^63.
	x = (x ^ (x >> 16)) & M32
	x = (x * 0x45d9f3b) & M32
	x = (x ^ (x >> 16)) & M32
	x = (x * 0x45d9f3b) & M32
	x = (x ^ (x >> 16)) & M32
	return x


## Uniform float in [0, 1).
static func u01(seed_value: int, tick: int, region: int, stream: int) -> float:
	var h := _mix((seed_value & M32) ^ 0x9E3779B9)
	h = _mix(h ^ ((tick * 0x85EBCA6B) & M32))
	h = _mix(h ^ ((region * 0xC2B2AE35) & M32))
	h = _mix(h ^ ((stream * 0x27D4EB2F) & M32))
	return float(h) / 4294967296.0
