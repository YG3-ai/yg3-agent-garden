extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 print("CHARACTER_PARSE=",doc.append_from_file("res://assets/kana-walk.glb",state))
 var model = doc.generate_scene(state)
 root.add_child(model)
 var b = AABB()
 var first = true
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var bb = mesh.global_transform*mesh.get_aabb()
  b = bb if first else b.merge(bb)
  first = false
 print("CHARACTER_BOUNDS=",b)
 for skeleton in model.find_children("*","Skeleton3D",true,false):
  print("SKELETON=",skeleton.get_path()," bones=",skeleton.get_bone_count())
  for i in range(min(5,skeleton.get_bone_count())): print("BONE ",i," ",skeleton.get_bone_name(i)," parent=",skeleton.get_bone_parent(i)," pose=",skeleton.get_bone_pose_position(i))
 for player in model.find_children("*","AnimationPlayer",true,false):
  print("PLAYER=",player.get_path()," root=",player.root_node," animations=",player.get_animation_list())
  for name in player.get_animation_list():
   var anim = player.get_animation(name)
   print("ANIMATION=",name," length=",anim.length," tracks=",anim.get_track_count())
   for t in range(anim.get_track_count()):
    if anim.track_get_type(t)==Animation.TYPE_POSITION_3D:
     print("POSITION_TRACK=",anim.track_get_path(t)," first=",anim.track_get_key_value(t,0)," last=",anim.track_get_key_value(t,anim.track_get_key_count(t)-1))
 quit()
