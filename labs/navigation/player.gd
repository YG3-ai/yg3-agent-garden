extends CharacterBody3D

const WALK_SPEED = 1.7
const FAST_SPEED = 2.8
const MAX_STEP = 0.34
var reset_count = 0
var last_reset_reason = ""
var render_feedback_enabled = true
var visual: Node3D
var animation_player: AnimationPlayer
var walk_animation = ""
var camera: Camera3D
var camera_yaw = 0.0
var camera_pitch = 0.17
var first_person = false
var external_control = false
var external_move = Vector2.ZERO
var external_fast = false
var external_jump = false
var spawn_point = Vector3(0,0.15,5.5)
var step_assists = 0
var last_floor_frame = -100
var animation_root_locked = false
var skeleton: Skeleton3D
var status = ""
var step_debug = ""

func configure(model: Node3D):
 visual = Node3D.new()
 visual.name = "CharacterVisual"
 add_child(visual)
 visual.add_child(model)
 var bounds = AABB()
 var first = true
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var b = mesh.global_transform*mesh.get_aabb()
  bounds = b if first else bounds.merge(b)
  first = false
 var factor = 1.70/bounds.size.y
 model.scale *= factor
 model.position.y = -bounds.position.y*factor
 var shape_node = CollisionShape3D.new()
 var capsule = CapsuleShape3D.new()
 capsule.radius = 0.24
 capsule.height = 1.65
 shape_node.shape = capsule
 shape_node.position.y = 0.825
 add_child(shape_node)
 floor_snap_length = 0.40
 floor_max_angle = deg_to_rad(46)
 floor_stop_on_slope = true
 safe_margin = 0.002
 for node in model.find_children("*","Skeleton3D",true,false): skeleton = node
 for node in model.find_children("*","AnimationPlayer",true,false): animation_player = node
 if animation_player:
  for name in animation_player.get_animation_list():
   if name == "RESET":continue
   walk_animation = name
   var anim = animation_player.get_animation(name)
   anim.loop_mode = Animation.LOOP_LINEAR
   for t in range(anim.get_track_count()):
    if anim.track_get_type(t)==Animation.TYPE_POSITION_3D and "Hips" in str(anim.track_get_path(t)):
     var initial = anim.track_get_key_value(t,0)
     for k in range(anim.track_get_key_count(t)):
      var value = anim.track_get_key_value(t,k)
      value.x = initial.x
      value.z = initial.z
      anim.track_set_key_value(t,k,value)
     animation_root_locked = true
   animation_player.play(name)
   animation_player.seek(0.0,true)
   animation_player.pause()
   break
 camera = Camera3D.new()
 camera.name = "PlayerCamera"
 camera.fov = 66
 camera.near = 0.07
 camera.far = 100
 add_child(camera)
 camera.current = true
 visual.rotation.y = PI
 position = spawn_point

# Both manual input and a future data collector/policy use this movement path.
func set_control(move:Vector2,fast=false,jump=false):
 external_control = true
 external_move = move.limit_length(1)
 external_fast = fast
 external_jump = jump

func reset_player(reason="manual"):
 reset_count += 1
 last_reset_reason = reason
 position = spawn_point
 velocity = Vector3.ZERO
 camera_yaw = 0.0
 camera_pitch = 0.17
 visual.rotation.y = PI

func _unhandled_input(event):
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  camera_yaw -= event.relative.x*0.0025
  camera_pitch = clamp(camera_pitch+event.relative.y*0.0025,-0.38,0.80)
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 if event.is_action_pressed("release_mouse"):Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 if event.is_action_pressed("reset_player"):reset_player()
 if event.is_action_pressed("toggle_view"):first_person = not first_person

func attempt_step(horizontal:Vector3):
 if horizontal.length()<0.0001 or Engine.get_physics_frames()-last_floor_frame>2:return
 if not test_move(global_transform,horizontal):step_debug="no horizontal contact";return
 if test_move(global_transform,Vector3.UP*MAX_STEP):step_debug="up blocked";return
 var raised = global_transform.translated(Vector3.UP*MAX_STEP)
 if test_move(raised,horizontal):step_debug="raised forward blocked";return
 var landing = raised.translated(horizontal)
 var contact = KinematicCollision3D.new()
 if not test_move(landing,Vector3.DOWN*(MAX_STEP+0.05),contact):step_debug="no landing";return
 if contact.get_normal().dot(Vector3.UP)<cos(floor_max_angle):
  # A capsule touching a stair lip has a diagonal edge normal. Confirm the
  # real tread immediately beyond that lip before allowing the step assist.
  var sample_point = contact.get_position()+horizontal.normalized()*0.05
  var query = PhysicsRayQueryParameters3D.create(Vector3(sample_point.x,global_position.y+MAX_STEP+0.05,sample_point.z),Vector3(sample_point.x,global_position.y-0.02,sample_point.z))
  query.exclude = [get_rid()]
  var tread = get_world_3d().direct_space_state.intersect_ray(query)
  if tread.is_empty() or tread.normal.dot(Vector3.UP)<cos(floor_max_angle):
   step_debug="no walkable tread beyond edge"
   return
 var height = MAX_STEP-contact.get_travel().length()
 if height>0.008 and height<=MAX_STEP:
  global_position.y += height+0.003
  velocity.y = 0
  step_assists += 1
  last_floor_frame = Engine.get_physics_frames()

func _physics_process(delta):
 if not visual:return
 var move = external_move if external_control else Input.get_vector("move_left","move_right","move_forward","move_back")
 var fast = external_fast if external_control else Input.is_action_pressed("move_fast")
 var jump = external_jump if external_control else Input.is_action_just_pressed("jump")
 external_jump = false
 var forward = Vector3.FORWARD.rotated(Vector3.UP,camera_yaw)
 var right = Vector3.RIGHT.rotated(Vector3.UP,camera_yaw)
 var direction = (right*move.x-forward*move.y).limit_length(1)
 var target = direction*(FAST_SPEED if fast else WALK_SPEED)
 velocity.x = move_toward(velocity.x,target.x,10*delta)
 velocity.z = move_toward(velocity.z,target.z,10*delta)
 if is_on_floor():
  last_floor_frame = Engine.get_physics_frames()
  if jump:velocity.y=4.4
 else:velocity.y-=12*delta
 if velocity.y<=0:attempt_step(Vector3(velocity.x,0,velocity.z)*delta)
 move_and_slide()
 var speed = Vector2(velocity.x,velocity.z).length()
 if direction.length()>0.05:
  visual.rotation.y = lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),min(1.0,12*delta))
 if render_feedback_enabled and animation_player and walk_animation!="":
  if speed>0.08 and (is_on_floor() or Engine.get_physics_frames()-last_floor_frame<=2):
   if not animation_player.is_playing():animation_player.play(walk_animation)
   animation_player.speed_scale = speed/1.35
  elif animation_player.is_playing():animation_player.pause()
 visual.visible = not first_person
 if render_feedback_enabled:update_camera()
 if global_position.y < -3:reset_player("fell_below_level")
 status = ("Grounded" if is_on_floor() else "In air")+"  |  "+("Walking" if speed>0.08 else "Stopped")

func update_camera():
 var target = global_position+Vector3(0,1.27,0)
 if first_person:
  camera.global_position = global_position+Vector3(0,1.49,0)
  camera.look_at(camera.global_position+Vector3(0,-sin(camera_pitch),-cos(camera_pitch)).rotated(Vector3.UP,camera_yaw))
  return
 var offset = Vector3(0,sin(camera_pitch)*3.15,cos(camera_pitch)*3.15).rotated(Vector3.UP,camera_yaw)
 var desired = target+offset
 var query = PhysicsRayQueryParameters3D.create(target,desired)
 query.exclude = [get_rid()]
 var hit = get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():desired = hit.position+(target-hit.position).normalized()*0.18
 if desired.distance_to(target)<0.85:visual.visible=false
 camera.global_position = desired
 camera.look_at(target)
