extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var d = GLTFDocument.new()
 var s = GLTFState.new()
 var err = d.append_from_file("res://assets/lobby.glb",s)
 print("GLB_PARSE=",err)
 if err != OK:
  quit(1)
  return
 var world = Node3D.new()
 root.add_child(world)
 var model = d.generate_scene(s)
 world.add_child(model)
 var b = AABB()
 var first = true
 var meshes = []
 for node in model.find_children("*","MeshInstance3D",true,false):
  var box = node.global_transform*node.get_aabb()
  b = box if first else b.merge(box)
  first = false
  meshes.append({"name":str(node.name),"position":str(box.position),"size":str(box.size)})
 print("BOUNDS=",b)
 var environment = WorldEnvironment.new()
 var e = Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("c3ced8")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color.WHITE
 e.ambient_light_energy = 0.8
 environment.environment = e
 world.add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 sun.light_energy = 0.8
 world.add_child(sun)
 root.msaa_3d = Viewport.MSAA_4X
 var camera = Camera3D.new()
 world.add_child(camera)
 camera.current = true
 var span = max(b.size.x,b.size.z)
 camera.near = max(0.01,span*0.0001)
 camera.far = max(200,span*10)
 camera.position = b.get_center()+Vector3(span*0.65,span*0.55,span*0.65)
 camera.look_at(b.get_center())
 await create_timer(1.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://inspection/lobby-overview.png")
 camera.position = Vector3(b.get_center().x,b.position.y+b.size.y*0.19,b.position.z+b.size.z*0.72)
 camera.look_at(Vector3(b.get_center().x,b.position.y+b.size.y*0.2,b.position.z+b.size.z*0.35))
 await create_timer(0.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://inspection/lobby-inside.png")
 var f = FileAccess.open("res://inspection/bounds.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"position":str(b.position),"size":str(b.size),"meshes":meshes},"  "))
 print("LOBBY_RENDERED meshes=",meshes.size())
 quit()
