extends Node
# The map is an offline teacher only. Learned-policy action selection calls no path queries.
var world
var rng=RandomNumberGenerator.new()
var navmap:RID
var region:NavigationRegion3D
var output=""
var mode="collect"
var split="test"
var controller="ffn"
var episodes=0
var task_index=0
var tasks=[]
var records:FileAccess
var results=[]
var trajectory=[]
var phase="boot"
var wait_ticks=10
var tick=0
var episode_ticks=0
var goal=Vector3.ZERO
var start=Vector3.ZERO
var reset_start=0
var wall_ticks=0
var travelled=0.0
var previous=Vector3.ZERO
var initial_distance=0.0
var weights={}
var dense_layers=[]
var rays=[]
var demo=false
var marker:MeshInstance3D
var start_time=0
var dagger=false
var task_id=""
var filming_yaw=0.0

func _ready():
 process_physics_priority=20
 Engine.physics_ticks_per_second=60
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--nav-mode":mode=args[i+1]
  if args[i]=="--output":output=args[i+1]
  if args[i]=="--split":split=args[i+1]
  if args[i]=="--controller":controller=args[i+1]
  if args[i]=="--episodes":episodes=int(args[i+1])
  if args[i]=="--task":task_id=args[i+1]
 demo=mode=="replay"
 dagger=mode=="dagger"
 if mode=="collect":controller="teacher"
 if output=="":output=ProjectSettings.globalize_path("res://experiments/navigation-v1")
 DirAccess.make_dir_recursive_absolute(output)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 world.player.set_control(Vector2.ZERO)
 world.player.render_feedback_enabled=demo
 if not demo and world.player.animation_player:world.player.animation_player.active=false
 for height in [0.25,0.8,1.4]:
  for angle in range(32):rays.append([height,Vector3(sin(angle*TAU/32),0,-cos(angle*TAU/32))])
 # This map is used for task creation, labels and the explicit teacher baseline.
 navmap=NavigationServer3D.map_create()
 NavigationServer3D.map_set_active(navmap,true)
 NavigationServer3D.map_set_cell_size(navmap,0.12)
 NavigationServer3D.map_set_cell_height(navmap,0.05)
 region=NavigationRegion3D.new()
 region.navigation_mesh=load("res://cache/lobby-navigation.tres")
 add_child(region)
 NavigationServer3D.region_set_map(region.get_rid(),navmap)
 if mode!="collect":
  tasks=JSON.parse_string(FileAccess.get_file_as_string(output+"/tasks.json"))[split]
  if controller=="ffn" or dagger:weights=JSON.parse_string(FileAccess.get_file_as_string(output+"/policy.json"))
 if mode=="collect" or dagger:
  records=FileAccess.open(output+("/dagger.jsonl" if dagger else "/demonstrations.jsonl"),FileAccess.WRITE)
 if demo:
  marker=MeshInstance3D.new()
  var sphere=SphereMesh.new()
  sphere.radius=0.18
  sphere.height=0.36
  marker.mesh=sphere
  var material=StandardMaterial3D.new()
  material.albedo_color=Color("64e5be")
  material.emission_enabled=true
  material.emission=Color("64e5be")
  marker.material_override=material
  world.add_child(marker)
 start_time=Time.get_ticks_msec()

func array3(v:Vector3):return [v.x,v.y,v.z]
func vector3(a):return Vector3(a[0],a[1],a[2])
func flat(v:Vector3):return Vector2(v.x,v.z)
func sample_point():
 # Central halls on both floors, and the four stair flights/landings.
 var raw=Vector3(rng.randf_range(-2.0,2.0),0.1 if rng.randf()<0.6 else 4.6,rng.randf_range(-9.5,9.5))
 if rng.randf()<0.25:
  raw=Vector3(rng.randf_range(2.8,6.5)*(1 if rng.randf()<0.5 else -1),rng.randf_range(0.4,4.3),rng.randf_range(7.6,9.3)*(1 if rng.randf()<0.5 else -1))
 return NavigationServer3D.map_get_closest_point(navmap,raw)
func generate_tasks():
 var groups={}
 for s in ["train","validation","test"]:
  rng.seed={"train":4511,"validation":7853,"test":9917}[s]
  var group=[]
  var count=300 if s=="train" else 50
  while group.size()<count:
   var a=sample_point()
   var b=sample_point()
   if a.distance_to(b)<3:continue
   var path=NavigationServer3D.map_get_path(navmap,a,b,true)
   if path.size()<2 or path[-1].distance_to(b)>0.3:continue
   var length=0.0
   for j in range(1,path.size()):length+=path[j-1].distance_to(path[j])
   if length<3 or length>38:continue
   group.append({"id":s+"-%04d"%group.size(),"start":array3(a),"goal":array3(b),"yaw":rng.randf_range(-PI,PI),"path_length":length})
  groups[s]=group
 FileAccess.open(output+"/tasks.json",FileAccess.WRITE).store_string(JSON.stringify(groups))
 # Entire episodes stay together. Positions may overlap across splits in this one known lobby.
 tasks=[]
 for s in ["train","validation"]:
  for task in groups[s]:
   task["split"]=s
   tasks.append(task)

func features():
 var p=world.player
 var values=[]
 var space=world.get_world_3d().direct_space_state
 for ray in rays:
  var origin=p.position+Vector3.UP*ray[0]
  var query=PhysicsRayQueryParameters3D.create(origin,origin+ray[1].rotated(Vector3.UP,p.camera_yaw)*6.0)
  query.exclude=[p.get_rid()]
  var hit=space.intersect_ray(query)
  values.append(origin.distance_to(hit.position)/6.0 if not hit.is_empty() else 1.0)
 var relative=(goal-p.position).rotated(Vector3.UP,-p.camera_yaw)
 var direction=flat(relative).normalized()
 var velocity=p.velocity.rotated(Vector3.UP,-p.camera_yaw)
 values.append_array([relative.x/12.0,relative.z/12.0,relative.y/5.0,direction.x,direction.y,min(flat(relative).length()/20.0,2.0),velocity.x/1.7,velocity.z/1.7])
 return values

func teacher_action():
 var p=world.player
 var path=NavigationServer3D.map_get_path(navmap,p.position,goal,true)
 if path.size()<2:return Vector2.ZERO
 # Short lookahead respects narrow turns and the stair landing.
 var target=path[-1]
 var remaining=0.45
 for j in range(1,path.size()):
  var segment=path[j]-path[j-1]
  var length=segment.length()
  if length>=remaining:
   target=path[j-1]+segment*(remaining/max(length,0.001))
   break
  remaining-=length
 var direction=flat((target-p.position).rotated(Vector3.UP,-p.camera_yaw)).normalized()
 return direction

func infer(x:Array):
 if dense_layers.is_empty():
  for layer in weights.layers:
   var rows=[]
   for row in layer.weight:rows.append(PackedFloat64Array(row))
   dense_layers.append({"rows":rows,"bias":PackedFloat64Array(layer.bias),"relu":layer.activation=="relu"})
 var h=PackedFloat64Array()
 for i:int in range(x.size()):h.append((x[i]-weights.mean[i])/weights.scale[i])
 for layer in dense_layers:
  var out=PackedFloat64Array()
  for i:int in range(layer.bias.size()):
   var value:float=layer.bias[i]
   var row:PackedFloat64Array=layer.rows[i]
   for j:int in range(h.size()):value+=row[j]*h[j]
   out.append(max(value,0.0) if layer.relu else tanh(value))
  h=out
 return Vector2(h[0],h[1]).limit_length(1.0)

func begin_episode():
 if task_index>=tasks.size() or (episodes>0 and task_index>=episodes):
  finish()
  return
 var task=tasks[task_index]
 var p=world.player
 start=vector3(task.start)
 goal=vector3(task.goal)
 p.position=start+Vector3.UP*0.015
 p.velocity=Vector3.ZERO
 p.camera_yaw=task.yaw
 filming_yaw=p.camera_yaw
 p.last_floor_frame=-100
 p.set_control(Vector2.ZERO)
 reset_start=p.reset_count
 episode_ticks=0
 wall_ticks=0
 travelled=0
 trajectory=[]
 wait_ticks=15
 phase="settle"
 if demo:marker.position=goal+Vector3.UP*0.7

func end_episode(reason):
 var p=world.player
 p.set_control(Vector2.ZERO)
 var task=tasks[task_index]
 var result={"id":task.id,"controller":controller,"reason":reason,"success":reason=="reached","seconds":episode_ticks/60.0,"travelled":travelled,"teacher_path_length":task.path_length,"wall_ticks":wall_ticks,"resets":p.reset_count-reset_start,"start":task.start,"goal":task.goal,"end":array3(p.position),"trajectory":trajectory}
 results.append(result)
 if task_index%10==0 or demo:print("NAV_EPISODE ",task_index," ",controller," ",reason," seconds=",episode_ticks/60.0)
 task_index+=1
 phase="prepare"
 if demo:
  phase="hold"
  wait_ticks=120
  world.hud.text="AGENT GARDEN / LEARNED NAVIGATION\n"+("Destination reached" if reason=="reached" else "Trial ended: "+reason)+"\nLocal FFN | No LLM calls | Full results in the experiment report"

func film_camera():
 var p=world.player
 if flat(p.velocity).length()>0.3:
  filming_yaw=lerp_angle(filming_yaw,atan2(-p.velocity.x,-p.velocity.z),0.08)
 var target=p.position+Vector3.UP*1.05
 var best=target+Vector3.UP
 var best_score=-INF
 # Pick an unobstructed close view around the actor, including front views on stairs.
 # Camera rays are visualization only and are never fed to the actor.
 for k in range(12):
  var angle=filming_yaw+k*TAU/12.0
  var desired=target+Vector3(0,0.94,2.2).rotated(Vector3.UP,angle)
  var query=PhysicsRayQueryParameters3D.create(target,desired)
  query.exclude=[p.get_rid()]
  var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():desired=hit.position+(target-hit.position).normalized()*0.16
  var score=desired.distance_to(target)+0.25*cos(angle-filming_yaw)
  if score>best_score:
   best_score=score
   best=desired
 p.camera.position=Vector3.ZERO
 p.camera.global_position=best
 p.camera.look_at(target)
 p.visual.visible=best.distance_to(target)>0.65

func _physics_process(_delta):
 tick+=1
 var p=world.player
 if demo and phase in ["move","hold"]:film_camera()
 if phase=="boot":
  wait_ticks-=1
  if wait_ticks>0:return
  NavigationServer3D.map_force_update(navmap)
  if mode=="collect":generate_tasks()
  if demo:
   # Optional illustrative task selection must be disclosed with the video.
   tasks=tasks.filter(func(t):return t.id==task_id) if task_id!="" else [tasks[0]]
  phase="prepare"
 if phase=="prepare":
  begin_episode()
  return
 if phase=="hold":
  wait_ticks-=1
  if wait_ticks<=0:finish()
  return
 if phase=="settle":
  wait_ticks-=1
  if wait_ticks>0:return
  if p.reset_count!=reset_start or not p.is_on_floor() or p.position.distance_to(start)>0.5:
   end_episode("invalid_start")
   return
  previous=p.position
  initial_distance=p.position.distance_to(goal)
  phase="move"
 if phase!="move":return
 episode_ticks+=1
 var distance=p.position.distance_to(previous)
 if p.reset_count!=reset_start:
  end_episode("respawn")
  return
 travelled+=distance
 previous=p.position
 if p.is_on_wall():wall_ticks+=1
 if episode_ticks%6==1:
  trajectory.append(array3(p.position))
  if flat(goal-p.position).length()<0.42 and abs(goal.y-p.position.y)<0.35:
   end_episode("reached")
   return
  if episode_ticks>=2700:
   end_episode("timeout")
   return
  var x=features()
  var action=Vector2.ZERO
  if mode=="collect" or dagger:
   var label=teacher_action()
   records.store_line(JSON.stringify({"episode":tasks[task_index].id,"split":tasks[task_index].get("split",split),"x":x,"action":[label.x,label.y],"position":array3(p.position),"goal":array3(goal),"reset_count":p.reset_count-reset_start}))
   action=infer(x) if dagger else label
  elif controller=="teacher":action=teacher_action()
  elif controller=="goal":action=flat((goal-p.position).rotated(Vector3.UP,-p.camera_yaw)).normalized()
  else:action=infer(x)
  p.set_control(action)
 if demo:
  var instruction="Go upstairs" if goal.y-start.y>3 else "Go downstairs" if start.y-goal.y>3 else "Reach the destination"
  world.hud.text="AGENT GARDEN / LEARNED NAVIGATION\n%s | Local FFN chooses each move\nHeld-out task: %s | %.1f seconds"%[instruction,tasks[task_index].id,episode_ticks/60.0]

func finish():
 phase="done"
 if records:records.close()
 var summary={"mode":mode,"controller":controller,"split":split,"episodes":results.size(),"reached":results.filter(func(r):return r.success).size(),"wall_clock_seconds":(Time.get_ticks_msec()-start_time)/1000.0,"results":results}
 var filename="collection" if mode=="collect" else mode+"-"+controller+"-"+split
 FileAccess.open(output+"/"+filename+".json",FileAccess.WRITE).store_string(JSON.stringify(summary))
 print("NAV_FINISHED ",filename," reached=",summary.reached,"/",summary.episodes)
 NavigationServer3D.free_rid(navmap)
 get_tree().quit()
