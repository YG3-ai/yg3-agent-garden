extends SceneTree
var camera: Camera3D
var body: CharacterBody3D
var model: Node3D
var wheel_pivots = []
var wheel_radii = []
var grounding = {}
var busy = false
var last_id = -1
var capture_index = 0
var session = ProjectSettings.globalize_path("res://dramatic-session/")
var driver = false
var total_distance = 0.0
var collisions = 0
var current_view = "front"

func _initialize():
 call_deferred("setup")
func material(color,metal=0.0,rough=0.8):
 var m = StandardMaterial3D.new()
 m.albedo_color = Color(color)
 m.metallic = metal
 m.roughness = rough
 return m
func box(world,position,size,mat,collide=false):
 var node = MeshInstance3D.new()
 var mesh = BoxMesh.new()
 mesh.size = size
 node.mesh = mesh
 node.material_override = mat
 node.position = position
 world.add_child(node)
 if collide: node.create_trimesh_collision()
 return node
func load_car():
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 var err = doc.append_from_file("res://assets/laferrari.glb",state)
 if err != OK:
  push_error("Car failed to load: "+str(err))
  quit(1)
  return null
 return doc.generate_scene(state)
func setup():
 DirAccess.make_dir_recursive_absolute(session)
 var world = Node3D.new()
 root.add_child(world)
 var env = WorldEnvironment.new()
 var e = Environment.new()
 var sky = Sky.new()
 var panorama = PanoramaSkyMaterial.new()
 var image = Image.load_from_file("res://assets/gotthard-panorama.png")
 panorama.panorama = ImageTexture.create_from_image(image)
 panorama.filter = true
 sky.sky_material = panorama
 e.sky = sky
 e.background_mode = Environment.BG_SKY
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color("cbd1e2")
 e.ambient_light_energy = 0.33
 panorama.energy_multiplier = 0.70
 e.tonemap_exposure = 0.95
 e.glow_enabled = true
 e.glow_intensity = 0.12
 e.fog_enabled = true
 e.fog_light_color = Color("b6a28c")
 e.fog_density = 0.0015
 e.fog_sky_affect = 0.22
 e.tonemap_mode = Environment.TONE_MAPPER_AGX
 e.ssao_enabled = true
 e.ssao_intensity = 1.0
 e.ssao_radius = 1.0
 env.environment = e
 world.add_child(env)
 root.msaa_3d = Viewport.MSAA_4X
 root.use_taa = true
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-13,-58,0)
 sun.light_energy = 2.6
 sun.light_angular_distance = 0.8
 sun.light_color = Color("ffd0a0")
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 120
 world.add_child(sun)
 var asphalt = material("373d40",0,0.95)
 var ground = material("6b7053",0,1)
 var white = material("e3e1d7")
 var rail = material("a6b0b2",0.6,0.4)
 box(world,Vector3(0,-0.25,-8),Vector3(70,0.4,100),ground)
 box(world,Vector3(0,-0.06,-8),Vector3(10,0.1,90),asphalt,true)
 for x in [-4.6,4.6]:
  box(world,Vector3(x,0.002,-8),Vector3(0.12,0.012,88),white)
  box(world,Vector3(x*1.08,0.7,-8),Vector3(0.13,0.22,90),rail,true)
  for z in range(-52,38,4):
   box(world,Vector3(x*1.08,0.37,z),Vector3(0.12,0.7,0.12),rail,true)
 for z in range(-50,37,6):
  box(world,Vector3(0,0.008,z),Vector3(0.12,0.015,2.7),white)
 box(world,Vector3(-2.3,0.015,-30),Vector3(4.2,0.02,0.3),white)
 for end_z in [-52,36]:
  box(world,Vector3(0,0.7,end_z),Vector3(10,0.3,0.2),rail,true)
 var green = material("26b69e")
 for x in [-4.0,-0.4]:
  for z in [-28,-31.5]:
   var cone = MeshInstance3D.new()
   var cm = CylinderMesh.new()
   cm.top_radius = 0.035
   cm.bottom_radius = 0.22
   cm.height = 0.65
   cone.mesh = cm
   cone.material_override = green
   cone.position = Vector3(x,0.325,z)
   world.add_child(cone)
 body = CharacterBody3D.new()
 world.add_child(body)
 body.position = Vector3(-2.0,0.04,18)
 var collision = CollisionShape3D.new()
 var shape = BoxShape3D.new()
 shape.size = Vector3(2.05,0.95,4.48)
 collision.shape = shape
 collision.position.y = 0.55
 body.add_child(collision)
 model = load_car()
 body.add_child(model)
 model.rotation.y = PI
 # Preserve original wheel geometry, add body-space pivots for rolling only.
 for node in model.find_children("*","Node3D",true,false):
  if str(node.name).begins_with("tire ") and not "_" in str(node.name).split(" ")[0]:
   if node.get_child_count() < 2: continue
   var b = AABB()
   var first = true
   for mesh in node.find_children("*","MeshInstance3D",true,false):
    var bb = mesh.global_transform*mesh.get_aabb()
    b = bb if first else b.merge(bb)
    first = false
   if first: continue
   var pivot = Node3D.new()
   body.add_child(pivot)
   pivot.global_position = b.get_center()
   node.reparent(pivot,true)
   wheel_pivots.append(pivot)
   wheel_radii.append(b.size.y*0.5)
 camera = Camera3D.new()
 world.add_child(camera)
 camera.fov = 15
 camera.near = 0.08
 camera.far = 200
 var optics = CameraAttributesPractical.new()
 optics.dof_blur_far_enabled = true
 optics.dof_blur_far_distance = 18.0
 optics.dof_blur_far_transition = 12.0
 optics.dof_blur_amount = 0.17
 camera.attributes = optics
 await physics_frame
 snap_to_road()
 camera.current = true
 var layer = CanvasLayer.new()
 layer.layer = 10
 root.add_child(layer)
 var grade = ColorRect.new()
 grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader = Shader.new()
 shader.code = FileAccess.get_file_as_string("res://dramatic-grade.gdshader")
 var grade_material = ShaderMaterial.new()
 grade_material.shader = shader
 grade.material = grade_material
 layer.add_child(grade)
 position_camera()
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(session+"ready.png")
 write_json("ready.json",{"ready":true,"wheel_pivots":wheel_pivots.size()})
 print("DRAMATIC_READY wheels=",wheel_pivots.size())
 if OS.get_environment("DRIVE_PREVIEW_ONLY") == "1":
  quit()
  return
 var timer = Timer.new()
 root.add_child(timer)
 timer.wait_time = 0.1
 timer.timeout.connect(check_request)
 timer.start()
func position_camera():
 var offset = Vector3(14.7,3.3,-17.5)
 if driver:
  offset = Vector3(1.4,2.6,18.0)
 elif current_view == "rear":
  offset = Vector3(-16,3.0,19)
 elif current_view == "side":
  offset = Vector3(21,2.3,0)
 camera.global_position = body.global_position+body.global_basis*offset
 var look = body.global_position+Vector3(0,0.7,0)
 if driver: look += -body.global_basis.z*3
 camera.look_at(look)
 camera.attributes.dof_blur_far_distance = camera.global_position.distance_to(body.global_position)+3.0
func write_json(name,data):
 var f = FileAccess.open(session+name,FileAccess.WRITE)
 f.store_string(JSON.stringify(data))
 f.close()
func capture_frame():
 await create_timer(1.0/15.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(session+("motion-%05d.jpg"%capture_index),0.93)
 capture_index += 1
func check_request():
 if busy or not FileAccess.file_exists(session+"request.json"):return
 var data = JSON.parse_string(FileAccess.get_file_as_string(session+"request.json"))
 if not data is Dictionary or int(data.get("id",-1))<=last_id:return
 busy = true
 last_id = int(data.id)
 var first_frame = capture_index
 var actual = 0.0
 var hit_obstacle = false
 var message = "Exterior inspection view."
 if data.action == "inspect_car":
  driver = false
  current_view = data.view
  var start = camera.global_position
  position_camera()
  var target = camera.global_position
  for i in range(15):
   camera.global_position = start.lerp(target,float(i+1)/15.0)
   camera.look_at(body.global_position+Vector3(0,0.7,0))
   await capture_frame()
 elif data.action == "enter_car":
  driver = true
  position_camera()
  message = "Control enabled. Chase-camera observation. Each drive command ends stopped. Stay on the added 3D test road; stop at the white line between green cones."
 elif data.action == "drive":
  if not driver:
   message = "Enable driving with enter_car first."
  else:
   var requested_speed = float(data.get("speed",8.0))
   var steps = max(2,int(ceil(float(data.distance)/requested_speed*15.0)))
   var step = float(data.distance)/steps
   for i in range(steps):
    await physics_frame
    var before = body.global_position
    var old_yaw = body.rotation.y
    body.rotate_y(-tan(deg_to_rad(float(data.steering)))*step/2.65)
    var motion = -body.global_basis.z*step
    var collision = body.move_and_collide(motion)
    actual += body.global_position.distance_to(before)
    for wi in range(wheel_pivots.size()):
     wheel_pivots[wi].rotate_x(-step/wheel_radii[wi])
    snap_to_road()
    position_camera()
    await capture_frame()
    if collision:
     body.rotation.y = old_yaw
     hit_obstacle = true
     collisions += 1
     break
   total_distance += actual
   message = "Drive ended stopped. " + ("Contact with a barrier." if hit_obstacle else "No barrier contact.")
 elif data.action == "finish":
  message = "Episode ended."
 for i in range(6):await capture_frame()
 write_json("grounding.json",grounding)
 var name = "observation-%03d.png"%last_id
 root.get_texture().get_image().save_png(session+name)
 var goal = body.position.z>=-31.6 and body.position.z<=-27.5 and abs(body.position.x+2.0)<1.2 and collisions==0
 write_json("response.json",{"id":last_id,"image":name,"feedback":message,"distance_moved":snapped(actual,0.001),"collision":hit_obstacle,"driver":driver,"speed":data.get("speed",0),"clip_start":first_frame,"clip_end":capture_index,"completed":goal if data.action=="finish" else false,"total_distance":snapped(total_distance,0.001) if data.action=="finish" else null})
 busy = false

func snap_to_road():
 var query = PhysicsRayQueryParameters3D.create(body.global_position+Vector3(0,4,0),body.global_position-Vector3(0,4,0))
 query.exclude = [body.get_rid()]
 var hit = root.world_3d.direct_space_state.intersect_ray(query)
 if hit.is_empty():
  grounding = {"supported":false}
  return
 var lowest = INF
 for wi in range(wheel_pivots.size()):
  lowest = min(lowest,wheel_pivots[wi].global_position.y-wheel_radii[wi])
 var correction = hit.position.y-lowest
 body.global_position.y += correction
 var gaps = []
 for wi in range(wheel_pivots.size()):
  gaps.append(snapped(wheel_pivots[wi].global_position.y-wheel_radii[wi]-hit.position.y,0.0001))
 grounding = {"supported":true,"road_y":hit.position.y,"body_y":body.global_position.y,"wheel_bottom_gaps":gaps,"method":"Ground ray and invariant rolling-wheel radius; no rotating AABB inflation."}
