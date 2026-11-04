extends Node
var world
var tick = 0
var before = 0
func _physics_process(_delta):
 tick+=1
 var p=world.player
 if tick==20:
  before=p.reset_count
  p.position=Vector3(0,-3.2,5.5)
  p.velocity=Vector3.ZERO
 if tick==22:
  var report={"reset_detected":p.reset_count==before+1,"reason":p.last_reset_reason,"returned_to_spawn":p.position.distance_to(p.spawn_point)<0.05,"training_guard":"Collector excludes any action whose reset_count changes; endpoint displacement is not a normal movement label."}
  report.passed=report.reset_detected and report.reason=="fell_below_level" and report.returned_to_spawn
  var file=FileAccess.open("res://inspection/reset-smoke.json",FileAccess.WRITE)
  file.store_string(JSON.stringify(report,"  "))
  print("RESET_SMOKE=",JSON.stringify(report))
  get_tree().quit(0 if report.passed else 1)
