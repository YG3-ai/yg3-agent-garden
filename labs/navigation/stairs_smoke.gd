extends Node
var world
var tick = 0
var stage = 0
var wait = 0
var report = {}
var finishing = false
func _physics_process(_delta):
 tick += 1
 var p = world.player
 if tick==20:
  p.position = Vector3(2.15,0.08,7.65)
  p.velocity = Vector3.ZERO
  p.set_control(Vector2.ZERO)
 if tick<50:return
 if stage==0:
  p.set_control(Vector2(1,0))
  if p.position.x>=6.35:
   report.first_flight = str(p.position)
   report.first_flight_height = p.position.y
   p.set_control(Vector2.ZERO)
   stage=1;wait=20
 elif stage==1:
  if wait>0:wait-=1;return
  p.set_control(Vector2(0,1))
  if p.position.z>=9.35:
   report.landing = str(p.position)
   p.set_control(Vector2.ZERO)
   stage=2;wait=20
 elif stage==2:
  if wait>0:wait-=1;return
  p.set_control(Vector2(-1,0))
  if p.position.x<=2.15:
   p.set_control(Vector2.ZERO)
   stage=3;wait=30
 elif stage==3:
  if wait>0:wait-=1;return
  report.final_position = str(p.position)
  report.final_height = p.position.y
  report.grounded = p.is_on_floor()
  report.step_assists = p.step_assists
  report.passed = p.position.y>4.3 and p.is_on_floor() and p.step_assists>5
  if DisplayServer.get_name()!="headless":capture_upper()
  p.set_control(Vector2(1,0))
  stage=4
 elif stage==4:
  p.set_control(Vector2(1,0))
  if p.position.x>=6.35:
   p.set_control(Vector2.ZERO)
   stage=5;wait=20
 elif stage==5:
  if wait>0:wait-=1;return
  p.set_control(Vector2(0,-1))
  if p.position.z<=7.65:
   p.set_control(Vector2.ZERO)
   stage=6;wait=20
 elif stage==6:
  if wait>0:wait-=1;return
  p.set_control(Vector2(-1,0))
  if p.position.x<=2.15:
   p.set_control(Vector2.ZERO)
   stage=7;wait=30
 elif stage==7:
  if wait>0:wait-=1;return
  report.descent_position = str(p.position)
  report.descent_grounded = p.is_on_floor()
  report.passed = report.passed and p.position.y<0.1 and p.is_on_floor()
  finish()
 if tick>1600:
  report.passed = false
  report.stage = stage
  report.step_debug = p.step_debug
  var rays = []
  for y in [0.15,0.38,0.7,1.0,1.6]:
   var query = PhysicsRayQueryParameters3D.create(Vector3(2.4,y,7.65),Vector3(3.2,y,7.65))
   query.exclude=[p.get_rid()]
   var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
   rays.append({"height":y,"hit":str(hit.position) if not hit.is_empty() else "none","collider":str(hit.collider.get_path()) if not hit.is_empty() else "none"})
  report.rays=rays
  report.final_position = str(p.position)
  report.grounded = p.is_on_floor()
  report.step_assists = p.step_assists
  finish()
func finish():
 if finishing:return
 finishing = true
 set_physics_process(false)
 var file = FileAccess.open("res://inspection/stairs-smoke.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("STAIRS_SMOKE=",JSON.stringify(report))
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://inspection/manual-stairs.png")
 get_tree().quit(0 if report.passed else 1)

func capture_upper():
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://inspection/manual-upper-floor.png")
