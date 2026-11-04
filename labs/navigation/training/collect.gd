extends Node

const COLS = 16
const ROWS = 12
const RANGE = 6.0
const SENSOR_HEIGHT = 1.20
const CELL = 2.5
const BORDER = 0.15
var world
var rng = RandomNumberGenerator.new()
var seed_value = 20261104
var wanted = 12000
var output = ""
var file: FileAccess
var phase = "prepare"
var frames = 0
var ticks_left = 0
var starting: Dictionary
var record: Dictionary
var wall_contact = false
var crossed_region = false
var accepted = 0
var attempted = 0
var candidates = 0
var rejects = {}
var quotas = {}
var counts = {"train":0,"validation":0,"test":0}
var started = 0
var finished = false
var directions = []

func _ready():
 process_physics_priority = 20
 Engine.physics_ticks_per_second = 60
 Engine.max_fps = 0
 var args = OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--samples":wanted=int(args[i+1])
  if args[i]=="--seed":seed_value=int(args[i+1])
  if args[i]=="--output":output=args[i+1]
 if output=="":output=ProjectSettings.globalize_path("res://experiments/pilot")
 DirAccess.make_dir_recursive_absolute(output)
 rng.seed = seed_value
 quotas={"train":int(wanted*0.70),"validation":int(wanted*0.15)}
 quotas.test=wanted-quotas.train-quotas.validation
 file=FileAccess.open(output+"/attempts.jsonl",FileAccess.WRITE)
 world.player.render_feedback_enabled=false
 if world.player.animation_player:world.player.animation_player.active=false
 world.player.set_control(Vector2.ZERO)
 for row in range(ROWS):
  var elevation=deg_to_rad(25.0-float(row)*100.0/(ROWS-1))
  for col in range(COLS):
   var azimuth=deg_to_rad(-50.0+float(col)*100.0/(COLS-1))
   directions.append(Vector3(sin(azimuth)*cos(elevation),sin(elevation),-cos(azimuth)*cos(elevation)))
 started=Time.get_ticks_msec()
 print("COLLECT_START ",JSON.stringify({"samples":wanted,"seed":seed_value,"output":output,"sensor":[COLS,ROWS],"quotas":quotas}))

func region(position:Vector3):
 return [int(floor((position.x+8)/CELL)),int(floor((position.z+11)/CELL)),1 if position.y>3.3 else 0]
func split_for(group:Array):
 var value=((group[0]*73856093) ^ (group[1]*19349663) ^ (group[2]*83492791)) & 0x7fffffff
 var slot=value%100
 return "test" if slot<15 else "validation" if slot<30 else "train"
func group_id(group:Array):return "%d:%d:%d"%group
func away_from_border(position:Vector3):
 var x=fposmod(position.x+8,CELL)
 var z=fposmod(position.z+11,CELL)
 return x>BORDER and x<CELL-BORDER and z>BORDER and z<CELL-BORDER
func nominal_distance(ticks:int):
 var distance=0.0
 for k in range(ticks):distance+=min(1.7,float(k+1)*10.0/60.0)/60.0
 return distance
func choose_start():
 var p=world.player
 for _try in range(100):
  candidates+=1
  var x=rng.randf_range(-7.1,7.1)
  var z=rng.randf_range(-10.0,10.0)
  var top=7.8 if rng.randf()<0.35 else 3.8
  var query=PhysicsRayQueryParameters3D.create(Vector3(x,top,z),Vector3(x,-0.2,z))
  query.exclude=[p.get_rid()]
  var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty() or hit.normal.y<0.75:continue
  var position=hit.position+Vector3.UP*0.015
  if not away_from_border(position):continue
  var group=region(position)
  var split=split_for(group)
  if counts[split]>=quotas[split]:continue
  var ticks=[12,24,36,48][rng.randi_range(0,3)]
  var yaw=rng.randf_range(-PI,PI)
  var forward=Vector3.FORWARD.rotated(Vector3.UP,yaw)
  var expected=nominal_distance(ticks)
  var endpoint=position+forward*expected
  # Keep the entire ideal action within one spatial region, including a buffer.
  if region(endpoint)!=group or not away_from_border(endpoint):continue
  var shape=PhysicsShapeQueryParameters3D.new()
  shape.shape=p.get_node("CollisionShape3D").shape if p.has_node("CollisionShape3D") else p.get_children().filter(func(n):return n is CollisionShape3D)[0].shape
  shape.transform=Transform3D(Basis.IDENTITY,position+Vector3.UP*0.825)
  shape.exclude=[p.get_rid()]
  shape.margin=0.001
  if not world.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():continue
  starting={"position":position,"yaw":yaw,"forward":forward,"ticks":ticks,"expected":expected,"group":group,"split":split}
  p.position=position
  p.velocity=Vector3.ZERO
  p.camera_yaw=yaw
  p.last_floor_frame=-100
  p.set_control(Vector2.ZERO)
  frames=10
  phase="settle"
  return true
 return false
func observe():
 var p=world.player
 var origin=p.global_position+Vector3.UP*SENSOR_HEIGHT
 var values=[]
 for direction in directions:
  var end=origin+direction.rotated(Vector3.UP,p.camera_yaw)*RANGE
  var query=PhysicsRayQueryParameters3D.create(origin,end)
  query.exclude=[p.get_rid()]
  var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
  values.append(origin.distance_to(hit.position)/RANGE if not hit.is_empty() else 1.0)
 return values
func reject(reason):rejects[reason]=rejects.get(reason,0)+1
func _physics_process(_delta):
 if finished:return
 var p=world.player
 if phase=="prepare":
  if accepted>=wanted:
   finish()
   return
  if not choose_start() and candidates>wanted*1000:
   push_error("Cannot fill sample quotas")
   finish(false)
  return
 if phase=="settle":
  frames-=1
  if frames>0:return
  if not p.is_on_floor() or p.position.distance_to(starting.position)>0.06:
   reject("unstable_start");phase="prepare";return
  var group=region(p.position)
  if group!=starting.group:reject("settle_changed_region");phase="prepare";return
  p.velocity=Vector3.ZERO
  attempted+=1
  record={"id":attempted,"split":starting.split,"region":group_id(group),"start":[p.position.x,p.position.y,p.position.z],"yaw":p.camera_yaw,"ticks":starting.ticks,"requested_distance":starting.expected,"ray_depth":observe(),"start_velocity":[p.velocity.x,p.velocity.y,p.velocity.z],"start_floor":p.is_on_floor(),"reset_before":p.reset_count,"step_assists_before":p.step_assists}
  starting.position=p.position
  wall_contact=false
  crossed_region=false
  ticks_left=starting.ticks
  p.set_control(Vector2(0,-1))
  phase="move"
  return
 if phase=="move":
  wall_contact=wall_contact or p.is_on_wall()
  crossed_region=crossed_region or region(p.position)!=starting.group
  ticks_left-=1
  if ticks_left>0 and p.reset_count==record.reset_before:return
  p.set_control(Vector2.ZERO)
  var delta=p.position-starting.position
  var projected=delta.dot(starting.forward)
  var resets=p.reset_count-record.reset_before
  var grounded=p.is_on_floor() or Engine.get_physics_frames()-p.last_floor_frame<=2
  var reason=""
  if resets>0:reason="respawn"
  elif not grounded or delta.y < -0.45:reason="unsupported_or_falling"
  elif crossed_region:reason="crossed_region"
  elif projected < -0.03 or projected>starting.expected*1.05+0.02:reason="recovery_or_overshoot"
  record.end=[p.position.x,p.position.y,p.position.z]
  record.actual_distance=projected
  record.distance_fraction=clamp(projected/starting.expected,0.0,1.0)
  record.collision=wall_contact
  record.movement_limited=projected/starting.expected<0.85
  record.delta_y=delta.y
  record.reset_count=resets
  record.reset_reason=p.last_reset_reason if resets>0 else ""
  record.step_assists=p.step_assists-record.step_assists_before
  record.eligible=reason==""
  record.excluded_reason=reason
  file.store_line(JSON.stringify(record))
  if reason=="":
   accepted+=1
   counts[starting.split]+=1
   if accepted%500==0:
    file.flush()
    print("COLLECT_PROGRESS ",JSON.stringify({"accepted":accepted,"attempted":attempted,"splits":counts,"seconds":(Time.get_ticks_msec()-started)/1000.0}))
  else:reject(reason)
  p.velocity=Vector3.ZERO
  phase="prepare"
func finish(success=true):
 finished=true
 file.flush()
 file.close()
 var manifest={"success":success,"seed":seed_value,"eligible":accepted,"attempted":attempted,"candidate_positions":candidates,"splits":counts,"excluded":rejects,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"physics_hz":60,"sensor":{"columns":COLS,"rows":ROWS,"max_range":RANGE,"height":SENSOR_HEIGHT,"azimuth_min":-50,"azimuth_max":50,"elevation_top":25,"elevation_bottom":-75,"kind":"ray distance, not RGB or rendered camera-space depth"},"action":"forward from rest for 12/24/36/48 fixed physics ticks using the manual character controller","split_method":"2.5-unit spatial cells and floor band; deterministic hash; 0.15-unit border buffer; nominal and actual actions retained within start region","limitation":"One fixed lobby only; spatial holdout is not new-building generalization."}
 var output_file=FileAccess.open(output+"/collection.json",FileAccess.WRITE)
 output_file.store_string(JSON.stringify(manifest,"  "))
 print("COLLECT_DONE ",JSON.stringify(manifest))
 get_tree().quit(0 if success else 1)
