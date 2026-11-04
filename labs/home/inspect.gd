extends SceneTree

func _initialize():
 call_deferred("run")

func run():
 var started = Time.get_ticks_msec()
 var document = GLTFDocument.new()
 var state = GLTFState.new()
 var err = document.append_from_file("res://assets/modern-apartment.glb", state)
 print("GLB_PARSE_ERROR=", err)
 if err != OK:
  quit(1)
  return
 var model = document.generate_scene(state)
 var world = Node3D.new()
 root.add_child(world)
 world.add_child(model)
 var bounds = AABB()
 var first = true
 var meshes = []
 for node in model.find_children("*", "MeshInstance3D", true, false):
  var box = node.global_transform * node.get_aabb()
  bounds = box if first else bounds.merge(box)
  first = false
  meshes.append({"name":str(node.name),"position":str(box.position),"size":str(box.size)})
 print("SCENE_LOADED_MS=",Time.get_ticks_msec()-started)
 print("BOUNDS=", bounds)
 var env = WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(0.18,0.20,0.23)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = 0.7
 world.add_child(env)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-50,-30,0)
 sun.light_energy = 1.2
 world.add_child(sun)
 var camera = Camera3D.new()
 world.add_child(camera)
 var center = bounds.get_center()
 var span = max(bounds.size.x, bounds.size.z)
 camera.position = Vector3(-1.7,1.6,3.8)
 camera.look_at(Vector3(-4.2,1.1,1.7))
 camera.fov = 80
 camera.far = max(1000.0,span*10)
 camera.near = 0.01
 camera.current = true
 await process_frame
 await process_frame
 await create_timer(3).timeout
 var image = root.get_texture().get_image()
 image.save_png("res://apartment-interior.png")
 var report = {"load_ms":Time.get_ticks_msec()-started,"bounds_position":str(bounds.position),"bounds_size":str(bounds.size),"mesh_instances":meshes.size(),"meshes":meshes,"rendered_image":"apartment-interior.png","renderer":RenderingServer.get_video_adapter_name()}
 var file = FileAccess.open("res://godot-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("RENDERED=",image.get_size()," GPU=",RenderingServer.get_video_adapter_name())
 quit()
