extends Node
var world
var tick = 0
var report = {}
var start = Vector3.ZERO
var wall_start = Vector3.ZERO
var foot_bone = -1
var foot_pose = Vector3.ZERO
func _physics_process(_delta):
 if not world.ready_for_test:return
 tick += 1
 var player = world.player
 if tick==10:
  var probes = []
  var lines = []
  for zi in range(41):
   var line = ""
   for xi in range(29):
    var x = -7.0+xi*0.5
    var z = -10.0+zi*0.5
    var query = PhysicsRayQueryParameters3D.create(Vector3(x,8.2,z),Vector3(x,-0.5,z))
    query.exclude = [player.get_rid()]
    var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():line += " "
    else:
     probes.append({"x":x,"z":z,"y":hit.position.y,"normal_y":hit.normal.y})
     line += "." if hit.position.y<0.2 else "U" if hit.position.y>4.4 else str(clamp(int(hit.position.y),0,4))
   lines.append(line)
  write_json("inspection/floor-probes.json",probes)
  var f = FileAccess.open("res://inspection/floor-map.txt",FileAccess.WRITE)
  f.store_string("x=-7..7 by .5, rows z=-10..10 by .5; . lower floor; U upper; digits intermediate\n"+"\n".join(lines))
 if tick==30:
  report.rig_bones = player.skeleton.get_bone_count()
  report.root_translation_locked = player.animation_root_locked
  report.settled_on_floor = player.is_on_floor()
  report.spawn_position = str(player.position)
  start = player.position
  for b in range(player.skeleton.get_bone_count()):
   if "LeftFoot" in player.skeleton.get_bone_name(b):foot_bone=b;break
  Input.action_press("move_forward")
 if tick==70 and foot_bone>=0:foot_pose=player.skeleton.get_bone_global_pose(foot_bone).origin
 if tick==85 and foot_bone>=0:
  report.animated_foot_delta = foot_pose.distance_to(player.skeleton.get_bone_global_pose(foot_bone).origin)
 if tick==150:
  Input.action_release("move_forward")
  report.forward_distance = start.distance_to(player.position)
  report.forward_position = str(player.position)
  if DisplayServer.get_name()!="headless":capture("inspection/manual-walking.png")
 if tick==175:
  player.position = Vector3(1.4,0.08,5.5)
  player.velocity = Vector3.ZERO
 if tick==190:
  wall_start = player.position
  var query = PhysicsRayQueryParameters3D.create(player.global_position+Vector3(0,1,0),player.global_position+Vector3(6,1,0))
  query.exclude = [player.get_rid()]
  var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
  report.wall_ray = str(hit.position) if not hit.is_empty() else "none"
  report.wall_collider = str(hit.collider.get_path()) if not hit.is_empty() else "none"
  Input.action_press("move_right")
 if tick==330:
  Input.action_release("move_right")
  report.wall_test_distance = wall_start.distance_to(player.position)
  report.wall_test_position = str(player.position)
  report.wall_contact = player.is_on_wall()
  report.wall_stopped = report.wall_test_distance<2.0 and player.is_on_wall()
  report.passed = report.rig_bones==66 and report.root_translation_locked and report.settled_on_floor and report.forward_distance>2.0 and report.get("animated_foot_delta",0)>0.1 and report.wall_stopped
  report.step_assists = player.step_assists
  write_json("inspection/manual-smoke.json",report)
  print("MANUAL_SMOKE=",JSON.stringify(report))
  if DisplayServer.get_name()!="headless":capture("inspection/manual-wall.png")
 if tick==345:get_tree().quit(0 if report.passed else 1)
func write_json(path,data):
 var file = FileAccess.open("res://"+path,FileAccess.WRITE)
 file.store_string(JSON.stringify(data,"  "))
func capture(path):
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://"+path)
