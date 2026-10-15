extends Node3D

const MAP: Array[String] = [
	"##############",
	"#............#",
	"#..##........#",
	"#..#.....D...#",
	"#..#..A......#",
	"#.....###....#",
	"#............#",
	"#.B......C...#",
	"#............#",
	"#....##......#",
	"#............#",
	"##############",
]

const STATION_COLORS := {
	"A": Color("f8bc46"),
	"B": Color("4cc2ff"),
	"C": Color("d25bff"),
	"D": Color("61e089"),
}

var output_path := ""
var camera_x := 6.5
var camera_z := 9.5
var camera_yaw := 0.0
var capture_width := 256
var capture_height := 256
var audience_signal := "unknown"
var publishing_rail := "stale_route"
var package_status := "absent"
var published := false
var recoveries := 0
var worker_port := -1
var worker_server: TCPServer
var worker_peer: StreamPeerTCP
var worker_buffer := ""
var worker_queue: Array[Dictionary] = []
var worker_busy := false


func _ready() -> void:
	_read_arguments()
	_build_environment()
	_build_world()
	_build_camera()
	if worker_port >= 0:
		_start_worker()
		return
	if output_path.is_empty():
		return
	var image: Image = await _capture_image()
	var error := image.save_png(output_path)
	print(JSON.stringify({
		"type": "garden_capture",
		"path": output_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"error": error,
	}))
	get_tree().quit(0 if error == OK else 1)


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--camera-x="):
			camera_x = argument.trim_prefix("--camera-x=").to_float()
		elif argument.begins_with("--camera-z="):
			camera_z = argument.trim_prefix("--camera-z=").to_float()
		elif argument.begins_with("--camera-yaw="):
			camera_yaw = argument.trim_prefix("--camera-yaw=").to_float()
		elif argument.begins_with("--width="):
			capture_width = clampi(argument.trim_prefix("--width=").to_int(), 64, 1024)
		elif argument.begins_with("--height="):
			capture_height = clampi(argument.trim_prefix("--height=").to_int(), 64, 1024)
		elif argument.begins_with("--audience-signal="):
			audience_signal = argument.trim_prefix("--audience-signal=")
		elif argument.begins_with("--publishing-rail="):
			publishing_rail = argument.trim_prefix("--publishing-rail=")
		elif argument.begins_with("--package-status="):
			package_status = argument.trim_prefix("--package-status=")
		elif argument.begins_with("--published="):
			published = argument.trim_prefix("--published=") == "true"
		elif argument.begins_with("--recoveries="):
			recoveries = argument.trim_prefix("--recoveries=").to_int()
		elif argument.begins_with("--worker-port="):
			worker_port = argument.trim_prefix("--worker-port=").to_int()
	_set_capture_size(capture_width, capture_height)


func _set_capture_size(width: int, height: int) -> void:
	capture_width = clampi(width, 64, 1024)
	capture_height = clampi(height, 64, 1024)
	get_window().content_scale_size = Vector2i(capture_width, capture_height)
	get_window().size = Vector2i(capture_width, capture_height)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161d30")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7b9d6")
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	key_light.light_energy = 1.1
	key_light.shadow_enabled = true
	add_child(key_light)


func _build_world() -> void:
	_add_box(
		"Floor",
		Vector3(MAP[0].length(), 0.1, MAP.size()),
		Vector3(MAP[0].length() / 2.0, -0.05, MAP.size() / 2.0),
		Color("202631"),
	)
	for z in MAP.size():
		for x in MAP[z].length():
			var tile: String = MAP[z].substr(x, 1)
			if tile == "#":
				_add_box("Wall_%d_%d" % [x, z], Vector3(1.0, 2.4, 1.0), Vector3(x + 0.5, 1.2, z + 0.5), Color("237d66"))
			elif STATION_COLORS.has(tile):
				_add_station(tile, Vector3(x + 0.5, 0.75, z + 0.5), _station_color(tile))


func _station_color(station_id: String) -> Color:
	if station_id == "A" and audience_signal == "captured":
		return Color("ffe88b")
	if station_id == "B" and package_status == "ready":
		return Color("8de5ff")
	if station_id == "C" and publishing_rail == "overloaded":
		return Color("ff372f")
	if station_id == "C" and published:
		return Color("f0a9ff")
	if station_id == "D" and recoveries > 0:
		return Color("aeffc0")
	return STATION_COLORS[station_id]


func _add_station(station_id: String, position: Vector3, color: Color) -> void:
	var station := _add_box("Station_%s" % station_id, Vector3(0.72, 1.5, 0.72), position, color)
	station.set_meta("station_id", station_id)
	var beacon := OmniLight3D.new()
	beacon.name = "Beacon_%s" % station_id
	beacon.light_color = color
	beacon.light_energy = 2.0
	beacon.omni_range = 2.4
	beacon.position = position + Vector3(0.0, 0.55, 0.0)
	add_child(beacon)


func _add_box(label: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	body.material_override = material
	add_child(body)
	return body


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "AgentCamera"
	camera.position = Vector3(camera_x, 0.72, camera_z)
	camera.rotation = Vector3(0.0, -camera_yaw - PI / 2.0, 0.0)
	camera.fov = 60.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.current = true
	add_child(camera)


func _apply_state(state: Dictionary) -> void:
	camera_x = float(state.get("x", camera_x))
	camera_z = float(state.get("z", camera_z))
	camera_yaw = float(state.get("yaw", camera_yaw))
	var workflow: Dictionary = state.get("workflow", {})
	audience_signal = str(workflow.get("audienceSignal", audience_signal))
	publishing_rail = str(workflow.get("publishingRail", publishing_rail))
	package_status = str(workflow.get("package", package_status))
	published = bool(workflow.get("published", published))
	recoveries = int(workflow.get("recoveries", recoveries))
	var camera := get_node("AgentCamera") as Camera3D
	camera.position = Vector3(camera_x, 0.72, camera_z)
	camera.rotation = Vector3(0.0, -camera_yaw - PI / 2.0, 0.0)
	for station_id in STATION_COLORS.keys():
		var color := _station_color(station_id)
		var station := get_node("Station_%s" % station_id) as MeshInstance3D
		var material := station.material_override as StandardMaterial3D
		material.albedo_color = color
		var beacon := get_node("Beacon_%s" % station_id) as OmniLight3D
		beacon.light_color = color


func _capture_image() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _start_worker() -> void:
	worker_server = TCPServer.new()
	var error := worker_server.listen(worker_port, "127.0.0.1")
	if error != OK:
		push_error("Garden worker could not listen: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("GARDEN_WORKER " + JSON.stringify({
		"type": "ready",
		"port": worker_server.get_local_port(),
		"protocolVersion": 1,
	}))


func _process(_delta: float) -> void:
	if worker_server == null:
		return
	if worker_peer == null and worker_server.is_connection_available():
		worker_peer = worker_server.take_connection()
	if worker_peer != null:
		worker_peer.poll()
		var available := worker_peer.get_available_bytes()
		if available > 0:
			worker_buffer += worker_peer.get_utf8_string(available)
			_read_worker_lines()
	if not worker_busy and not worker_queue.is_empty():
		worker_busy = true
		_handle_next_request.call_deferred()


func _read_worker_lines() -> void:
	var newline := worker_buffer.find("\n")
	while newline >= 0:
		var line := worker_buffer.substr(0, newline)
		worker_buffer = worker_buffer.substr(newline + 1)
		var parsed = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			worker_queue.push_back(parsed)
		newline = worker_buffer.find("\n")


func _handle_next_request() -> void:
	var request: Dictionary = worker_queue.pop_front()
	var request_id = request.get("id")
	var request_type := str(request.get("type", ""))
	if request_type == "render":
		_apply_state(request.get("state", {}))
		_set_capture_size(int(request.get("width", 256)), int(request.get("height", 256)))
		var image: Image = await _capture_image()
		var response := {
			"id": request_id,
			"ok": true,
			"width": image.get_width(),
			"height": image.get_height(),
			"pngBase64": Marshalls.raw_to_base64(image.save_png_to_buffer()),
		}
		if bool(request.get("includeLabels", false)):
			var segmentation: Image = await _capture_segmentation()
			response["segmentationBase64"] = Marshalls.raw_to_base64(segmentation.save_png_to_buffer())
			response["segmentationLegend"] = _segmentation_legend()
			response["calibration"] = _camera_calibration()
		_send_worker_response(response)
	elif request_type == "ping":
		_send_worker_response({"id": request_id, "ok": true, "type": "pong"})
	elif request_type == "close":
		_send_worker_response({"id": request_id, "ok": true})
		get_tree().quit(0)
		return
	else:
		_send_worker_response({"id": request_id, "ok": false, "error": "unknown_request"})
	worker_busy = false


func _send_worker_response(response: Dictionary) -> void:
	if worker_peer == null:
		return
	worker_peer.put_data((JSON.stringify(response) + "\n").to_utf8_buffer())


func _capture_segmentation() -> Image:
	var world_environment := get_node("WorldEnvironment") as WorldEnvironment
	var original_background := world_environment.environment.background_color
	world_environment.environment.background_color = Color.BLACK
	var saved_materials: Array[Dictionary] = []
	var saved_lights: Array[Dictionary] = []
	for child in get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var material := mesh.material_override as StandardMaterial3D
			saved_materials.push_back({
				"material": material,
				"color": material.albedo_color,
				"shading": material.shading_mode,
			})
			material.albedo_color = _segmentation_color(mesh.name)
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif child is Light3D:
			var light := child as Light3D
			saved_lights.push_back({"light": light, "visible": light.visible})
			light.visible = false
	var image: Image = await _capture_image()
	world_environment.environment.background_color = original_background
	for saved in saved_materials:
		var material := saved["material"] as StandardMaterial3D
		material.albedo_color = saved["color"]
		material.shading_mode = saved["shading"]
	for saved in saved_lights:
		var light := saved["light"] as Light3D
		light.visible = saved["visible"]
	return image


func _segmentation_color(node_name: String) -> Color:
	if node_name == "Floor":
		return Color("ff0000")
	if node_name.begins_with("Wall_"):
		return Color("00ff00")
	if node_name == "Station_A":
		return Color("0000ff")
	if node_name == "Station_B":
		return Color("ffff00")
	if node_name == "Station_C":
		return Color("ff00ff")
	if node_name == "Station_D":
		return Color("00ffff")
	return Color("ffffff")


func _segmentation_legend() -> Dictionary:
	return {
		"000000": {"classId": 0, "name": "background"},
		"ff0000": {"classId": 1, "name": "floor"},
		"00ff00": {"classId": 2, "name": "wall"},
		"0000ff": {"classId": 10, "name": "audience_signal_console"},
		"ffff00": {"classId": 11, "name": "writing_engine_console"},
		"ff00ff": {"classId": 12, "name": "publishing_rail_console"},
		"00ffff": {"classId": 13, "name": "reliability_relay"},
	}


func _camera_calibration() -> Dictionary:
	var focal := 0.5 * capture_height / tan(deg_to_rad(60.0) * 0.5)
	return {
		"intrinsics": {
			"fx": focal,
			"fy": focal,
			"cx": capture_width * 0.5,
			"cy": capture_height * 0.5,
			"width": capture_width,
			"height": capture_height,
			"verticalFovDegrees": 60.0,
		},
		"extrinsics": {
			"position": [camera_x, 0.72, camera_z],
			"yawRadians": camera_yaw,
		},
	}
