extends SceneTree
var meshes_report = []
func _initialize():
 call_deferred("run")
func bounds_for(model):
 var b = AABB()
 var first = true
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var box = mesh.global_transform * mesh.get_aabb()
  b = box if first else b.merge(box)
  first = false
  meshes_report.append({"path":str(mesh.get_path()),"position":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]})
 return b
func import_model(path):
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 var err = doc.append_from_file(path,state)
 print("PARSE=",path," ",err)
 if err != OK:
  quit(1)
  return null
 return doc.generate_scene(state)
func capture(path):
 await create_timer(0.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run():
 var world = Node3D.new()
 root.add_child(world)
 var env = WorldEnvironment.new()
 var e = Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("b7cad8")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_energy = 0.9
 e.ambient_light_color = Color.WHITE
 env.environment = e
 world.add_child(env)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-50,-25,0)
 sun.light_energy = 0.7
 world.add_child(sun)
 root.msaa_3d = Viewport.MSAA_4X
 var model = import_model("res://assets/gotthard-pass.glb")
 world.add_child(model)
 var b = bounds_for(model)
 print("ENV_BOUNDS=",b)
 var camera = Camera3D.new()
 world.add_child(camera)
 camera.far = 1000000
 camera.near = 0.1
 camera.current = true
 var span = max(b.size.x,b.size.z)
 var center = b.get_center()
 camera.position = center+Vector3(span*0.4,span*0.55,span*0.6)
 camera.look_at(center)
 await capture("res://inspection/environment-overview.png")
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = span*1.05
 camera.position = center+Vector3(0,span*1.5,0)
 camera.look_at(center,Vector3.FORWARD)
 await capture("res://inspection/environment-top.png")
 model.visible = false
 var car = import_model("res://assets/laferrari.glb")
 world.add_child(car)
 var cb = bounds_for(car)
 print("CAR_BOUNDS=",cb)
 camera.projection = Camera3D.PROJECTION_PERSPECTIVE
 var cspan = max(cb.size.x,cb.size.z)
 camera.far = 100
 camera.near = 0.05
 camera.position = cb.get_center()+Vector3(cspan*0.8,cspan*0.4,cspan*0.8)
 camera.look_at(cb.get_center())
 await capture("res://inspection/car-overview.png")
 var f = FileAccess.open("res://inspection/bounds.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"environment":{"position":[b.position.x,b.position.y,b.position.z],"size":[b.size.x,b.size.y,b.size.z]},"car":{"position":[cb.position.x,cb.position.y,cb.position.z],"size":[cb.size.x,cb.size.y,cb.size.z]},"meshes":meshes_report},"  "))
 print("INSPECTION_DONE")
 quit()
