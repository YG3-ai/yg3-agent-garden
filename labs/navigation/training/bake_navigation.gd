extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://cache/"))
 var root=Node3D.new()
 get_root().add_child(root)
 var colliders=load("res://cache/lobby-colliders.tscn").instantiate()
 root.add_child(colliders)
 var mesh=NavigationMesh.new()
 mesh.agent_radius=0.30
 mesh.agent_height=1.65
 mesh.agent_max_climb=0.34
 mesh.agent_max_slope=46
 mesh.cell_size=0.12
 mesh.cell_height=0.05
 mesh.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
 var source=NavigationMeshSourceGeometryData3D.new()
 NavigationServer3D.parse_source_geometry_data(mesh,source,root)
 NavigationServer3D.bake_from_source_geometry_data(mesh,source)
 print("NAV_BAKE polygons=",mesh.get_polygon_count()," vertices=",mesh.get_vertices().size())
 ResourceSaver.save(mesh,"res://cache/lobby-navigation.tres")
 quit()
