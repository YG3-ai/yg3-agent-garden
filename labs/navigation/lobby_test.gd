extends Node3D
var player
var ready_for_test = false
var hud: Label
var collider_count = 0
func load_model(path):
 var document = GLTFDocument.new()
 var state = GLTFState.new()
 var err = document.append_from_file(path,state)
 if err != OK:
  push_error("Cannot load "+path+": "+str(err))
  get_tree().quit(1)
  return null
 return document.generate_scene(state)
func _ready():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://cache/"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://inspection/"))
 var actions = {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"move_fast":KEY_SHIFT,"jump":KEY_SPACE,"reset_player":KEY_R,"toggle_view":KEY_F,"release_mouse":KEY_ESCAPE}
 for name in actions:
  if not InputMap.has_action(name):InputMap.add_action(name)
  var key = InputEventKey.new()
  key.physical_keycode = actions[name]
  InputMap.action_add_event(name,key)
 var level = load_model("res://assets/lobby.glb")
 add_child(level)
 if FileAccess.file_exists("res://cache/lobby-colliders.tscn"):
  var colliders = load("res://cache/lobby-colliders.tscn").instantiate()
  add_child(colliders)
  collider_count = colliders.get_child_count()
 else:
  if DisplayServer.get_name()=="headless":
   push_error("Open the manual scene once with graphics to bake skinned lobby collisions, then headless tests can reuse the cache.")
   get_tree().quit(1)
   return
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  var colliders = Node3D.new()
  colliders.name = "LobbyStaticColliders"
  add_child(colliders)
  for mesh in level.find_children("*","MeshInstance3D",true,false):
   if not mesh.mesh:continue
   var geometry = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin else mesh.mesh
   if not geometry:
    push_error("Cannot bake collider for "+str(mesh.name))
    get_tree().quit(1)
    return
   var static_body = StaticBody3D.new()
   static_body.name = "Collider_"+str(mesh.name)
   colliders.add_child(static_body)
   static_body.global_transform = mesh.global_transform
   static_body.owner = colliders
   var shape = CollisionShape3D.new()
   shape.shape = geometry.create_trimesh_shape()
   shape.shape.backface_collision = true
   static_body.add_child(shape)
   shape.owner = colliders
   collider_count += 1
  var packed = PackedScene.new()
  packed.pack(colliders)
  ResourceSaver.save(packed,"res://cache/lobby-colliders.tscn")
  print("BAKED_VISIBLE_COLLIDERS=",collider_count)
 var environment = WorldEnvironment.new()
 var e = Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("aebdca")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color("e5e2dd")
 e.ambient_light_energy = 0.72
 environment.environment = e
 add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-50,-30,0)
 sun.light_energy = 0.55
 add_child(sun)
 var model = load_model("res://assets/kana-walk.glb")
 player = load("res://player.gd").new()
 player.name = "KanaPlayer"
 add_child(player)
 player.configure(model)
 var layer = CanvasLayer.new()
 add_child(layer)
 hud = Label.new()
 hud.position = Vector2(20,16)
 hud.add_theme_font_size_override("font_size",20)
 hud.add_theme_color_override("font_color",Color.WHITE)
 hud.add_theme_color_override("font_shadow_color",Color.BLACK)
 hud.add_theme_constant_override("shadow_offset_x",2)
 hud.add_theme_constant_override("shadow_offset_y",2)
 layer.add_child(hud)
 ready_for_test = true
 print("LOBBY_MANUAL_READY colliders=",collider_count," bones=",player.skeleton.get_bone_count()," root_locked=",player.animation_root_locked)
 if "--navigation" in OS.get_cmdline_user_args():
  var experiment = load("res://navigation/experiment.gd").new()
  experiment.world = self
  add_child(experiment)
  set_process(false)
 elif "--collect" in OS.get_cmdline_user_args():
  var collector = load("res://training/collect.gd").new()
  collector.world = self
  add_child(collector)
  set_process(false)
 elif "--smoke" in OS.get_cmdline_user_args():
  var test = load("res://manual_smoke.gd").new()
  test.world = self
  add_child(test)
 elif "--stairs-smoke" in OS.get_cmdline_user_args():
  var test = load("res://stairs_smoke.gd").new()
  test.world = self
  add_child(test)
 elif "--reset-smoke" in OS.get_cmdline_user_args():
  var test = load("res://training/reset_smoke.gd").new()
  test.world = self
  add_child(test)
 else:Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _process(_delta):
 if player and hud:
  hud.text = "AGENT GARDEN / LOBBY MANUAL TEST\nWASD move  |  Mouse look  |  Shift faster  |  Space jump\nF first/third person  |  R reset  |  Esc release mouse  |  Click to capture\n"+player.status
