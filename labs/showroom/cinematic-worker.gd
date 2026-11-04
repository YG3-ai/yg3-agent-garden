extends SceneTree
var camera: Camera3D
var body: CharacterBody3D
var model: Node3D
var wheel_pivots = []
var busy = false
var last_id = -1
var capture_index = 0
var session = ProjectSettings.globalize_path("res://cinematic-session/")
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
 box(world,Vector3(-2.3,0.015,-12),Vector3(4.2,0.02,0.3),white)
 var green = material("26b69e")
 for x in [-4.0,-0.4]:
  for z in [-10,-13.5]:
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
 camera = Camera3D.new()
 world.add_child(camera)
 camera.fov = 22
 camera.near = 0.08
 camera.far = 200
 var optics = CameraAttributesPractical.new()
 optics.dof_blur_far_enabled = true
 optics.dof_blur_far_distance = 18.0
 optics.dof_blur_far_transition = 12.0
 optics.dof_blur_amount = 0.12
 camera.attributes = optics
 camera.current = true
 var layer = CanvasLayer.new()
 layer.layer = 10
 root.add_child(layer)
 var grade = ColorRect.new()
 grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader = Shader.new()
 shader.code = FileAccess.get_file_as_string("res://cinematic-grade.gdshader")
 var grade_material = ShaderMaterial.new()
 grade_material.shader = shader
 grade.material = grade_material
 layer.add_child(grade)
 position_camera()
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(session+"ready.png")
 write_json("ready.json",{"ready":true,"wheel_pivots":wheel_pivots.size()})
 print("CINEMATIC_READY wheels=",wheel_pivots.size())
 if OS.get_environment("DRIVE_PREVIEW_ONLY") == "1":
  quit()
  return
 var timer = Timer.new()
 root.add_child(timer)
 timer.wait_time = 0.1
 timer.timeout.connect(check_request)
 timer.start()
func position_camera():
 var offset = Vector3(10.5,2.7,-12.5)
 if driver:
  offset = Vector3(1.0,2.3,12.5)
 elif current_view == "rear":
  offset = Vector3(-11,2.5,13)
 elif current_view == "side":
  offset = Vector3(15,2.0,0)
 camera.global_position = body.global_position+body.global_basis*offset
 var look = body.global_position+Vector3(0,0.7,0)
 if driver: look += -body.global_basis.z*3
 camera.look_at(look)
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
   var steps = max(15,int(float(data.distance)*6))
   var step = float(data.distance)/steps
   for i in range(steps):
    await physics_frame
    var before = body.global_position
    var old_yaw = body.rotation.y
    body.rotate_y(-tan(deg_to_rad(float(data.steering)))*step/2.65)
    var motion = -body.global_basis.z*step
    var collision = body.move_and_collide(motion)
    actual += body.global_position.distance_to(before)
    position_camera()
    for wheel in wheel_pivots: wheel.rotate_x(-step/0.34)
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
 var name = "observation-%03d.png"%last_id
 root.get_texture().get_image().save_png(session+name)
 var goal = body.position.z>=-13.6 and body.position.z<=-9.5 and abs(body.position.x+2.0)<1.2 and collisions==0
 write_json("response.json",{"id":last_id,"image":name,"feedback":message,"distance_moved":snapped(actual,0.001),"collision":hit_obstacle,"driver":driver,"clip_start":first_frame,"clip_end":capture_index,"completed":goal if data.action=="finish" else false,"total_distance":snapped(total_distance,0.001) if data.action=="finish" else null})
 busy = false
