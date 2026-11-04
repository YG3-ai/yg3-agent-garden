extends SceneTree
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 var directory=args[0]
 var policy=load("res://navigation/experiment.gd").new()
 policy.weights=JSON.parse_string(FileAccess.get_file_as_string(directory+"/policy.json"))
 var file=FileAccess.open(directory+"/demonstrations.jsonl",FileAccess.READ)
 var outputs=[]
 for i in range(16):
  var row=JSON.parse_string(file.get_line())
  var action=policy.infer(row.x)
  outputs.append({"x":row.x,"action":[action.x,action.y]})
 FileAccess.open(directory+"/godot-inference.json",FileAccess.WRITE).store_string(JSON.stringify(outputs))
 policy.free()
 quit()
