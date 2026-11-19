extends RefCounted
var t


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/map/art/diorama.json"))


func test_display_derivation_matches_immutable_gis_and_keeps_every_region() -> void:
	var config := _config()
	t.check(config.source_sha256 == FileAccess.get_sha256("res://data/map/v2/kabkota_lod1.bin"), "art derivation identifies exact canonical GIS input")
	t.check(config.meaning.begins_with("ARTISTIC_DECORATION"), "decoration is not claimed as measured terrain")
	var lod := MapLod.new()
	t.check(lod.load_from("res://data/map/v2/kabkota_lod1") == "", "canonical geometry loads")
	var mismatch := 0
	for prop in config.props:
		var index := lod.entry_at(Vector2(prop.x, prop.z))
		if index < 0 or str(lod.ids[index]) != str(lod.ids[int(prop.region)]):
			mismatch += 1
	t.check(mismatch == 0, "all decorative anchors stay in their own canonical region (%d mismatches)" % mismatch)
	t.check(config.props.size() > 20000, "expanded archipelago dressing is packaged")
	var vessels: Array = config.get("vessels", [])
	t.check(vessels.size() >= 100, "maritime vessels are packaged")
	var land_vessel := 0
	for v in vessels:
		if lod.entry_at(Vector2(v.x, v.z)) >= 0:
			land_vessel += 1
	t.check(land_vessel == 0, "all vessels float outside land polygons (%d inland)" % land_vessel)
	var cores := {}
	for prop in config.props:
		if str(prop.role).ends_with("_core"):
			cores[int(prop.region)] = true
	t.check(cores.size() == 514, "each canonical region has an interior decorative settlement core")
	var canonical := 0
	for kind in lod.kinds:
		if kind == "kabkota":
			canonical += 1
	t.check(canonical == 514, "all 514 semantic regions remain selectable")


func test_settlement_footprints_stay_inside_their_canonical_region() -> void:
	var config := _config()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/art_catalog.json"))
	var lod := MapLod.new()
	lod.load_from("res://data/map/v2/kabkota_lod1")
	var mismatch := 0
	for prop in config.props:
		if prop.role == "decoration":
			continue
		var width := float(catalog.groups[prop.kind].footprint) * float(prop.size)
		for x in [-0.5, 0.0, 0.5]:
			for z in [-0.5, 0.0, 0.5]:
				var offset := Vector2(x, z).rotated(-float(prop.rotation)) * width
				var index := lod.entry_at(Vector2(prop.x, prop.z) + offset)
				if index != int(prop.region):
					mismatch += 1
	t.check(mismatch == 0, "settlement footprints fit their own region (%d mismatches)" % mismatch)


func test_pinned_cc0_models_and_checksums() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/kenney/manifest.json"))
	t.check(manifest.commit.length() == 40, "asset mirror is pinned to a Git commit")
	t.check(manifest.assets.size() == 129, "129 curated CC0 models are packaged")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/art_catalog.json"))
	t.check(_config().catalog_sha256 == FileAccess.get_sha256("res://data/map/art_catalog.json"), "placements identify exact model catalog")
	var used := {}
	for prop in _config().props:
		var grp: Dictionary = catalog.groups[prop.kind]
		var sub := str(grp.get("subdir", ""))
		var m := str(grp.models[int(prop.variant)])
		used[("%s/%s.glb" % [sub, m]) if sub != "" else (m + ".glb")] = true
	for vessel in _config().get("vessels", []):
		var grp: Dictionary = catalog.groups[vessel.kind]
		var sub := str(grp.get("subdir", ""))
		var m := str(grp.models[int(vessel.variant)])
		used[("%s/%s.glb" % [sub, m]) if sub != "" else (m + ".glb")] = true
	t.check(used.size() == 129, "every packaged model is used in the map (%d/129)" % used.size())
	for asset in manifest.assets:
		var path := "res://assets/map/kenney/" + str(asset.file)
		t.check(asset.license == "CC0-1.0" and asset.creator == "Kenney", "upstream provenance retained")
		t.check(str(asset.get("commit", manifest.commit)).length() == 40, "asset commit pinned")
		t.check(FileAccess.get_sha256(path) == asset.sha256, "model SHA-256 " + str(asset.file))
	t.check(FileAccess.file_exists("res://assets/map/kenney/LICENSE.txt"), "primary CC0 notice is packaged")
	t.check(FileAccess.file_exists("res://assets/map/kenney/LICENSE-SHOREPINE.txt"), "secondary mirror CC0 notice is packaged")


func test_distance_field_contract_and_clouds_are_separate_from_simulation() -> void:
	var config := _config()
	var texture: Texture2D = load("res://data/map/art/coast_field.png")
	var image := texture.get_image()
	t.check(image.get_width() == int(config.field_size[0]) and image.get_height() == int(config.field_size[1]), "coast field dimensions match build metadata")
	var detail_tex: Texture2D = load("res://data/map/art/landscape_detail.png")
	var detail_img := detail_tex.get_image()
	t.check(detail_img.get_width() == int(config.field_size[0]) and detail_img.get_height() == int(config.field_size[1]), "landscape detail dimensions match build metadata")
	t.check(config.seed == 20261119 and config.clouds.size() == 120 and config.get("high_clouds", []).size() == 64, "independent deterministic decoration seed with 184 cloud clusters")
	var b: Array = config.field_bounds
	for point in config.clouds:
		var uv := Vector2((float(point[0]) - float(b[0])) / float(b[2]), (float(point[1]) - float(b[1])) / float(b[3]))
		var pixel := image.get_pixel(clampi(int(uv.x * (image.get_width() - 1)), 0, image.get_width() - 1),
			clampi(int(uv.y * (image.get_height() - 1)), 0, image.get_height() - 1))
		t.check(pixel.r < 0.5 and pixel.g > 0.7, "ambient cloud is anchored above open water")


func test_neighbor_backdrop_and_camera_safe_zone() -> void:
	var npath := "res://data/map/art/neighbor_land.json"
	t.check(FileAccess.file_exists(npath), "non-canonical neighboring landmasses backdrop packaged")
	var ndata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(npath))
	t.check(str(ndata.get("schema", "")) == "nusantara.neighbor_land/1", "neighbor backdrop schema verified")
	t.check(ndata.get("rings", []).size() > 100 and ndata.get("countries", []).has("Malaysia") and ndata.get("countries", []).has("Papua New Guinea"),
		"surrounding countries surround Indonesia without polluting 514 simulation regions")

	var cam := MapCamera3D.new()
	var rect := Rect2(-2300.6, -607.7, 4600.4, 1708.4)
	cam.fit(rect, Vector2(1600, 900))
	t.check(cam.min_distance >= 120.0 and cam.max_distance <= 3200.0, "3D camera zoom limits stay bounded around Indonesia")
	cam.distance = 10.0
	cam._zoom_step(0.5, Vector2(800, 450))
	t.check(cam.distance >= cam.min_distance, "zoom-in stops cleanly at min_distance")
	cam.distance = 99999.0
	cam._zoom_step(2.0, Vector2(800, 450))
	t.check(cam.distance <= cam.max_distance, "zoom-out stops cleanly at max_distance")
	cam.drag_orbit_step(Vector2(2000.0, 2000.0))
	t.check(cam.pitch >= cam.min_pitch and cam.pitch <= cam.max_pitch and cam.yaw >= cam.min_yaw and cam.yaw <= cam.max_yaw,
		"3D orbit/tilt angles stay bounded")
	cam.target = Vector3(50000.0, 0.0, -50000.0)
	cam._clamp_target()
	t.check(cam.target.x >= rect.position.x - 30.0 and cam.target.x <= rect.end.x + 30.0 and cam.target.z >= rect.position.y - 30.0 and cam.target.z <= rect.end.y + 30.0,
		"3D pan safe zone locks camera target inside Indonesian archipelago")
	cam.free()
