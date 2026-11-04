extends SceneTree
var body: CharacterBody3D
var capture_index = 0
var camera: Camera3D
var environment: Environment
var daylight: OmniLight3D
var practical: OmniLight3D
var busy = false
var last_id = -1
var mode = "daylight"
var base_dir = ProjectSettings.globalize_path("res://walk-session/")

func _initialize():
 call_deferred("setup")

func setup():
 DirAccess.make_dir_recursive_absolute(base_dir)
 var document = GLTFDocument.new()
 var state = GLTFState.new()
 var err = document.append_from_file("res://assets/modern-apartment.glb", state)
 if err != OK:
  push_error("GLB failed: " + str(err))
  quit(1)
  return
 var world = Node3D.new()
 root.add_child(world)
 var model = document.generate_scene(state)
 world.add_child(model)
 var collider_count = 0
 for mesh in model.find_children("*", "MeshInstance3D", true, false):
  if mesh.mesh:
   mesh.create_trimesh_collision()
   for collision in mesh.find_children("*", "CollisionShape3D", true, false):
    if collision.shape is ConcavePolygonShape3D:
     collision.shape.backface_collision = true
   collider_count += 1
 print("STATIC_COLLIDERS=", collider_count)
 root.msaa_3d = Viewport.MSAA_4X
 root.use_taa = true
 var env_node = WorldEnvironment.new()
 environment = Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("b5c4d4")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("dce6ef")
 environment.ambient_light_energy = 0.32
 environment.tonemap_mode = Environment.TONE_MAPPER_AGX
 environment.ssao_enabled = true
 environment.ssao_radius = 0.55
 environment.ssao_intensity = 1.4
 environment.ssil_enabled = true
 environment.ssil_intensity = 0.5
 environment.glow_enabled = true
 environment.glow_intensity = 0.05
 env_node.environment = environment
 world.add_child(env_node)
 daylight = OmniLight3D.new()
 daylight.position = Vector3(-4.0,2.1,-0.3)
 daylight.light_color = Color("ecf3ff")
 daylight.light_specular = 0.08
 daylight.light_energy = 2.2
 daylight.omni_range = 9.0
 daylight.omni_attenuation = 0.65
 daylight.shadow_enabled = true
 daylight.light_size = 1.5
 world.add_child(daylight)
 practical = OmniLight3D.new()
 practical.position = Vector3(-0.1,2.5,1.5)
 practical.light_color = Color("ffcf98")
 practical.light_specular = 0.08
 practical.light_energy = 0.55
 practical.omni_range = 7.0
 practical.omni_attenuation = 0.7
 practical.shadow_enabled = true
 practical.light_size = 0.6
 world.add_child(practical)
 var fill = OmniLight3D.new()
 fill.position = Vector3(-2.3,2.5,3.0)
 fill.light_color = Color("fff0db")
 fill.light_specular = 0.0
 fill.light_energy = 0.35
 fill.omni_range = 7.0
 world.add_child(fill)
 body = CharacterBody3D.new()
 world.add_child(body)
 body.position = Vector3(-1.7,1.02,3.8)
 var shape_node = CollisionShape3D.new()
 var capsule = CapsuleShape3D.new()
 capsule.radius = 0.18
 capsule.height = 1.5
 shape_node.shape = capsule
 body.add_child(shape_node)
 camera = Camera3D.new()
 body.add_child(camera)
 camera.position = Vector3(0,0.58,0)
 camera.look_at(Vector3(-4.2,1.1,1.7))
 camera.fov = 75
 camera.near = 0.05
 camera.far = 60
 camera.current = true
 await create_timer(2).timeout
 root.get_texture().get_image().save_png(base_dir + "ready.png")
 write_json(base_dir+"ready.json", {"ready":true})
 print("HOME_READY")
 var timer = Timer.new()
 timer.wait_time = 0.1
 timer.timeout.connect(check_request)
 root.add_child(timer)
 timer.start()

func write_json(path, data):
 var f = FileAccess.open(path, FileAccess.WRITE)
 f.store_string(JSON.stringify(data))
 f.close()

func check_request():
 if busy or not FileAccess.file_exists(base_dir+"request.json"):
  return
 var data = JSON.parse_string(FileAccess.get_file_as_string(base_dir+"request.json"))
 if not data is Dictionary or int(data.get("id",-1)) <= last_id:
  return
 busy = true
 last_id = int(data.id)
 var collided = false
 var actual_distance = 0.0
 var clip_start = capture_index
 if data.action == "turn":
  for i in range(15):
   camera.rotate_y(deg_to_rad(-float(data.degrees)/15.0))
   await capture_frame()
 elif data.action == "move":
  var forward = -camera.global_basis.z
  forward.y = 0
  forward = forward.normalized()
  var right = camera.global_basis.x
  right.y = 0
  right = right.normalized()
  var direction = forward
  if data.direction == "backward": direction = -forward
  elif data.direction == "left": direction = -right
  elif data.direction == "right": direction = right
  var increment = float(data.distance)/15.0
  for i in range(15):
   await physics_frame
   var before = body.position
   var target = before + direction*increment
   var query = PhysicsRayQueryParameters3D.create(target+Vector3(0,0.4,0),target-Vector3(0,1.3,0))
   query.exclude = [body.get_rid()]
   if root.world_3d.direct_space_state.intersect_ray(query).is_empty():
    collided = true
    break
   var hit = body.move_and_collide(direction*increment)
   actual_distance += body.position.distance_to(before)
   await capture_frame()
   if hit:
    collided = true
    break
 elif data.action == "set_lighting":
  mode = data.mode
  if mode == "evening":
   daylight.light_energy = 0.12
   practical.light_energy = 2.1
   environment.ambient_light_energy = 0.15
   environment.ambient_light_color = Color("dfc8b7")
  else:
   daylight.light_energy = 2.2
   practical.light_energy = 0.55
   environment.ambient_light_energy = 0.32
   environment.ambient_light_color = Color("dce6ef")
 for i in range(8):
  await capture_frame()
 await create_timer(0.3).timeout
 var name = "observation-%03d.png" % last_id
 root.get_texture().get_image().save_png(base_dir+name)
 write_json(base_dir+"response.json", {"id":last_id,"image":name,"lighting":mode,"collision":collided,"distance_moved":snapped(actual_distance,0.001),"clip_start":clip_start,"clip_end":capture_index})
 busy = false

func capture_frame():
 await create_timer(1.0/15.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(base_dir + ("motion-%05d.jpg" % capture_index), 0.92)
 capture_index += 1
