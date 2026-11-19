extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://assets/rykard.glb")
	if scene:
		_inspect(scene.instantiate())
	quit()

func _inspect(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var m := mi.get_active_material(s)
				var has_albedo := false
				if m is StandardMaterial3D:
					has_albedo = (m as StandardMaterial3D).albedo_texture != null
				print(mi.name + " surf[" + str(s) + "] mat=" + (m.resource_name if m else "null") + " albedo_tex=" + str(has_albedo))
	for c in node.get_children():
		_inspect(c)
