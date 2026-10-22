class_name SaveCodec
extends RefCounted
## Exact, JSON-safe encoding of simulation state.
##
## Why: Godot's JSON writes doubles with 16 significant digits; ~9% of arbitrary doubles do not
## round-trip (measured 2026-10-05: 9,277/100,000). Saves must restore state bit-exactly
## (determinism, docs/11), so:
##   - regional arrays (PackedFloat64Array) -> base64 of raw little-endian float64 bytes
##   - any other float -> "f64:<16 hex chars>" (raw bytes)
##   - plain JSON numbers on decode can only have come from ints -> restored as int
## Strings, bools, nulls, ints, nested Dictionaries/Arrays pass through. Dictionary keys are Strings.

const FLOAT_PREFIX := "f64:"


static func encode_array(a: PackedFloat64Array) -> String:
	return Marshalls.raw_to_base64(a.to_byte_array())


static func decode_array(s: String) -> PackedFloat64Array:
	return Marshalls.base64_to_raw(s).to_float64_array()


static func encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return FLOAT_PREFIX + PackedFloat64Array([v]).to_byte_array().hex_encode()
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = encode(v[k])
			return d
		TYPE_ARRAY:
			return (v as Array).map(func(x): return encode(x))
		TYPE_PACKED_FLOAT64_ARRAY:
			return {"__f64_array__": encode_array(v)}
		TYPE_STRING_NAME:
			return str(v)
	return v


static func decode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			var s: String = v
			if s.begins_with(FLOAT_PREFIX) and s.length() == FLOAT_PREFIX.length() + 16:
				return s.substr(FLOAT_PREFIX.length()).hex_decode().to_float64_array()[0]
			return s
		TYPE_FLOAT:
			return int(v)  # exact floats are always encoded as strings; bare numbers were ints
		TYPE_DICTIONARY:
			if (v as Dictionary).size() == 1 and v.has("__f64_array__"):
				return decode_array(v["__f64_array__"])
			var d := {}
			for k in v:
				d[str(k)] = decode(v[k])
			return d
		TYPE_ARRAY:
			return (v as Array).map(func(x): return decode(x))
	return v
