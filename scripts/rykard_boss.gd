extends CharacterBody3D

signal hp_changed(current: float, max_hp: float)
signal phase_changed(phase: int)
signal staggered
signal died

enum State {
	IDLE,
	TELEGRAPH,
	P1_BITE_LUNGE,
	P1_MULTI_BITE,
	P1_MAGMA_SPIT,
	P1_BODY_SLAM,
	P1_SERPENT_SWEEP,
	P2_TAKERS_FLAMES,
	P2_SWORD_COMBO,
	P2_RYKARDS_RANCOR,
	P2_RAIN_OF_SKULLS,
	STAGGERED,
	RECOVER,
	DEAD
}

@export var max_hp: float = 1800.0
@export var player_path: NodePath

var hp: float = 1800.0
var phase: int = 1
var state: State = State.IDLE
var poise: float = 0.0
const POISE_THRESHOLD: float = 360.0

var _player: Node3D = null
var _state_timer: float = 1.4
var _state_duration: float = 1.4
var _queued_attack: State = State.P1_BITE_LUNGE
var _attack_idx: int = 0
var _sway_time: float = 0.0
var _lunge_dir: Vector3 = Vector3.FORWARD
var _melee_hit_done: bool = false
var _home_pos: Vector3 = Vector3.ZERO
var _rain_spawn_accum: float = 0.0
var _flame_step: int = 0
var _flame_dir: Vector3 = Vector3.BACK
var _combo_step: int = 0

var _skel: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _spine_bones: Array[int] = []
var _arm_l_bone: int = -1
var _arm_r_bone: int = -1
var _forearm_r_bone: int = -1
var _hand_r_bone: int = -1
var _sword_bone: int = -1
var _head_bone: int = -1
var _jaw_bone: int = -1
var _head11_bone: int = -1
var _rest_rot: Dictionary = {}
var _rest_pos: Dictionary = {}

@onready var model_pivot: Node3D = $ModelPivot
@onready var telegraph_ring: MeshInstance3D = $TelegraphRing

const PROJECTILE_SCRIPT := preload("res://scripts/boss_projectile.gd")

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	_home_pos = global_position
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	if telegraph_ring:
		telegraph_ring.visible = false

	_setup_model_and_skeleton(model_pivot)
	emit_signal("hp_changed", hp, max_hp)

func _setup_model_and_skeleton(root: Node) -> void:
	if not root:
		return
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var m := mi.get_active_material(s)
					if m is StandardMaterial3D:
						var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
						sm.roughness = 0.80
						sm.metallic = 0.14
						mi.set_surface_override_material(s, sm)
		elif child is Skeleton3D and _skel == null:
			_skel = child as Skeleton3D
			_cache_bones()
			_setup_real_animations()
		_setup_model_and_skeleton(child)

func _setup_real_animations() -> void:
	if not _skel:
		return
	var parent := _skel.get_parent()
	if not parent:
		return
	_anim_player = AnimationPlayer.new()
	parent.add_child(_anim_player)
	var lib := AnimationLibrary.new()
	var clip_map := {
		"idle": ["res://assets/anims/rykard/a000_000020.glb", true],
		"atk_0": ["res://assets/anims/rykard/a000_003000.glb", false],
		"atk_1": ["res://assets/anims/rykard/a000_003001.glb", false],
		"atk_2": ["res://assets/anims/rykard/a000_003002.glb", false],
		"atk_3": ["res://assets/anims/rykard/a000_003003.glb", false],
	}
	for cname in clip_map.keys():
		var info: Array = clip_map[cname]
		var anim := _extract_anim(info[0], info[1])
		if anim:
			lib.add_animation(cname, anim)
	_anim_player.add_animation_library("", lib)
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")

func _extract_anim(glb_path: String, loop: bool) -> Animation:
	var ps: PackedScene = load(glb_path)
	if not ps:
		return null
	var tmp := ps.instantiate()
	var src_ap: AnimationPlayer = _find_anim_player(tmp)
	var out_anim: Animation = null
	if src_ap and src_ap.has_animation("Motion"):
		out_anim = src_ap.get_animation("Motion").duplicate() as Animation
		out_anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		# Strip Master root-motion position track so boss stays on CharacterBody3D
		for i in range(out_anim.get_track_count() - 1, -1, -1):
			var tp := str(out_anim.track_get_path(i))
			if tp.ends_with(":Master") and out_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				out_anim.remove_track(i)
	tmp.queue_free()
	return out_anim

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var res := _find_anim_player(c)
		if res:
			return res
	return null

func _cache_bones() -> void:
	if not _skel:
		return
	for i in range(_skel.get_bone_count()):
		var bname := _skel.get_bone_name(i)
		if bname.begins_with("Body1_") or bname.begins_with("Body2_") or bname.begins_with("Body4_") or bname.begins_with("Body6_"):
			_spine_bones.append(i)
			_rest_rot[i] = _skel.get_bone_pose_rotation(i)
			_rest_pos[i] = _skel.get_bone_pose_position(i)

	_arm_l_bone = _skel.find_bone("L UpperArmSub")
	if _arm_l_bone != -1:
		_rest_rot[_arm_l_bone] = _skel.get_bone_pose_rotation(_arm_l_bone)

	_arm_r_bone = _skel.find_bone("R UpperArmSub")
	if _arm_r_bone != -1:
		_rest_rot[_arm_r_bone] = _skel.get_bone_pose_rotation(_arm_r_bone)

	_forearm_r_bone = _skel.find_bone("R ForearmSub")
	if _forearm_r_bone != -1:
		_rest_rot[_forearm_r_bone] = _skel.get_bone_pose_rotation(_forearm_r_bone)

	_hand_r_bone = _skel.find_bone("R Hand")
	if _hand_r_bone != -1:
		_rest_rot[_hand_r_bone] = _skel.get_bone_pose_rotation(_hand_r_bone)

	_sword_bone = _skel.find_bone("R_Sword1")
	if _sword_bone != -1:
		_rest_rot[_sword_bone] = _skel.get_bone_pose_rotation(_sword_bone)

	_head_bone = _skel.find_bone("Head21")
	if _head_bone != -1:
		_rest_rot[_head_bone] = _skel.get_bone_pose_rotation(_head_bone)

	_jaw_bone = _skel.find_bone("Jaw21")
	if _jaw_bone != -1:
		_rest_rot[_jaw_bone] = _skel.get_bone_pose_rotation(_jaw_bone)

	_head11_bone = _skel.find_bone("Head11")
	if _head11_bone != -1:
		_rest_rot[_head11_bone] = _skel.get_bone_pose_rotation(_head11_bone)

func _set_bone_offset(idx: int, euler: Vector3, weight: float = 1.0) -> void:
	if idx == -1 or not _skel or not _rest_rot.has(idx):
		return
	var base_q: Quaternion = _rest_rot[idx]
	var target_q := base_q * Quaternion.from_euler(euler)
	var cur_q := _skel.get_bone_pose_rotation(idx)
	_skel.set_bone_pose_rotation(idx, cur_q.slerp(target_q, weight))

func _animate_skeleton(delta: float) -> void:
	# Real Elden Ring Havok animations are driven by _anim_player
	if _anim_player and _anim_player.has_animation("idle"):
		var target_clip := "idle"
		match state:
			State.P1_BITE_LUNGE, State.P1_MULTI_BITE:
				target_clip = "atk_0" if _anim_player.has_animation("atk_0") else "idle"
			State.P1_SERPENT_SWEEP, State.P2_SWORD_COMBO:
				target_clip = "atk_1" if _anim_player.has_animation("atk_1") else "idle"
			State.P1_BODY_SLAM, State.P2_TAKERS_FLAMES:
				target_clip = "atk_2" if _anim_player.has_animation("atk_2") else "idle"
			State.P1_MAGMA_SPIT, State.P2_RYKARDS_RANCOR, State.P2_RAIN_OF_SKULLS:
				target_clip = "atk_3" if _anim_player.has_animation("atk_3") else "idle"
		if _anim_player.current_animation != target_clip:
			_anim_player.play(target_clip, 0.25)
		return

	var blend := clampf(delta * 9.0, 0.0, 1.0)
	var t := 0.0
	if _state_duration > 0.0:
		t = clampf(1.0 - (_state_timer / _state_duration), 0.0, 1.0)

	var spine_pitch := 0.0
	var spine_yaw := 0.0
	var sword_pitch := -0.15
	var sword_roll := 0.0
	var jaw_open := 0.14 + sin(_sway_time * 2.4) * 0.08
	var pivot_y_offset := sin(_sway_time * 2.0) * 0.18
	var pivot_pitch := 0.0
	var pivot_yaw := sin(_sway_time * 1.1) * 0.06

	match state:
		State.IDLE, State.RECOVER:
			spine_pitch = sin(_sway_time * 1.8) * 0.08
			spine_yaw = sin(_sway_time * 1.1) * 0.14

		State.TELEGRAPH:
			# Rear back & coil up depending on queued attack
			spine_pitch = lerpf(0.0, -0.34, t)
			sword_pitch = lerpf(-0.15, -0.95, t)
			sword_roll = lerpf(0.0, -0.35, t)
			jaw_open = lerpf(0.15, 0.78, t)
			pivot_y_offset += lerpf(0.0, 0.8, t)
			pivot_pitch = lerpf(0.0, -0.18, t)

		State.P1_BITE_LUNGE:
			spine_pitch = 0.42
			jaw_open = 0.92 if t < 0.6 else 0.1
			pivot_pitch = 0.28

		State.P1_MULTI_BITE:
			var snap_wave := sin(t * PI * 3.0)
			spine_pitch = 0.28 + absf(snap_wave) * 0.25
			spine_yaw = snap_wave * 0.65
			jaw_open = 0.85 if snap_wave > 0.0 else 0.15
			pivot_yaw = snap_wave * 0.32

		State.P1_BODY_SLAM:
			var slam_curve := smoothstep(0.0, 0.55, t)
			spine_pitch = lerpf(-0.55, 0.55, slam_curve)
			pivot_y_offset += lerpf(2.1, -0.3, slam_curve)
			pivot_pitch = lerpf(-0.32, 0.34, slam_curve)

		State.P1_MAGMA_SPIT:
			spine_pitch = -0.25
			jaw_open = 0.78 + sin(_sway_time * 16.0) * 0.14
			pivot_pitch = -0.14

		State.P1_SERPENT_SWEEP:
			spine_pitch = 0.24
			spine_yaw = lerpf(-0.85, 0.95, t)
			pivot_yaw = lerpf(-0.5, 0.5, t)

		State.P2_SWORD_COMBO:
			var swing := sin(t * PI * 2.0)
			spine_pitch = 0.22
			spine_yaw = swing * 0.85
			sword_pitch = 0.35
			sword_roll = swing * 1.15
			pivot_yaw = swing * 0.48

		State.P2_TAKERS_FLAMES:
			# Raise sword high then slam straight down!
			var slam := smoothstep(0.0, 0.45, t)
			spine_pitch = lerpf(-0.35, 0.45, slam)
			sword_pitch = lerpf(-1.05, 0.95, slam)
			pivot_pitch = lerpf(-0.22, 0.28, slam)

		State.P2_RYKARDS_RANCOR, State.P2_RAIN_OF_SKULLS:
			# Raise sword skyward & roar
			spine_pitch = -0.30
			sword_pitch = -0.85
			jaw_open = 0.82 + sin(_sway_time * 18.0) * 0.08
			pivot_y_offset += 0.65
			pivot_pitch = -0.20

		State.STAGGERED:
			spine_pitch = 0.42
			sword_pitch = 0.55
			jaw_open = 0.4
			pivot_y_offset = -0.55
			pivot_pitch = 0.26

	if _skel:
		for i in range(_spine_bones.size()):
			var idx: int = _spine_bones[i]
			var phase_i := _sway_time * 3.0 - float(i) * 0.65
			var wave := sin(phase_i) * 0.38
			_set_bone_offset(idx, Vector3(spine_pitch * 0.45 + wave * 0.6, spine_yaw * 0.35 + wave, wave * 0.4), blend)
			if _rest_pos.has(idx) and _skel.get_bone_parent(idx) == -1:
				var base_p: Vector3 = _rest_pos[idx]
				var slither_offset := Vector3(sin(phase_i) * 0.45, cos(phase_i * 0.8) * 0.22, cos(phase_i) * 0.25)
				_skel.set_bone_pose_position(idx, _skel.get_bone_pose_position(idx).lerp(base_p + slither_offset, blend))
		_set_bone_offset(_arm_r_bone, Vector3(sword_pitch * 1.35, 0.0, sword_roll * 1.2), blend)
		_set_bone_offset(_forearm_r_bone, Vector3(sword_pitch * 1.0, 0.0, sword_roll * 0.9), blend)
		_set_bone_offset(_hand_r_bone, Vector3(sword_pitch * 0.8, 0.0, sword_roll * 0.7), blend)
		_set_bone_offset(_sword_bone, Vector3(sword_pitch * 1.2, 0.0, sword_roll * 1.1), blend)
		_set_bone_offset(_arm_l_bone, Vector3(sword_pitch * 1.0, 0.0, -sword_roll * 0.9), blend)
		_set_bone_offset(_head_bone, Vector3(-spine_pitch * 0.55, sin(_sway_time * 2.2) * 0.35, 0.0), blend)
		_set_bone_offset(_jaw_bone, Vector3(jaw_open * 1.4, 0.0, 0.0), blend)
		_set_bone_offset(_head11_bone, Vector3(spine_pitch * 0.6, sin(_sway_time * 1.8) * 0.25, 0.0), blend)

	if model_pivot:
		model_pivot.position.y = lerpf(model_pivot.position.y, 0.85 + pivot_y_offset, blend)
		model_pivot.rotation.x = lerpf(model_pivot.rotation.x, pivot_pitch, blend)
		model_pivot.rotation.y = lerpf(model_pivot.rotation.y, pivot_yaw, blend)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_sway_time += delta
	_animate_skeleton(delta)
	_state_timer -= delta

	match state:
		State.IDLE:
			_face_player(delta, 3.5)
			var back := (_home_pos - global_position)
			back.y = 0.0
			if back.length() > 0.5:
				global_position += back.normalized() * 3.5 * delta
			if _state_timer <= 0.0:
				_begin_telegraph()

		State.TELEGRAPH:
			_face_player(delta, 5.5)
			if telegraph_ring:
				telegraph_ring.visible = true
				var pulse := 1.0 + sin(_sway_time * 18.0) * 0.14
				telegraph_ring.scale = Vector3(pulse, 1.0, pulse)
			if _state_timer <= 0.0:
				if telegraph_ring:
					telegraph_ring.visible = false
				_execute_queued_attack()

		State.P1_BITE_LUNGE:
			global_position += _lunge_dir * 18.0 * delta
			if not _melee_hit_done and _player and is_instance_valid(_player):
				if global_position.distance_to(_player.global_position) < 5.8 and _player.has_method("take_damage"):
					_player.take_damage(26.0)
					_melee_hit_done = true
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 1.25)

		State.P1_MULTI_BITE:
			global_position += _lunge_dir * 10.5 * delta
			var elapsed := _state_duration - _state_timer
			var step := int(elapsed / 0.42)
			if step > _combo_step:
				_combo_step = step
				_melee_hit_done = false
			if not _melee_hit_done and _player and is_instance_valid(_player):
				if global_position.distance_to(_player.global_position) < 6.0 and _player.has_method("take_damage"):
					_player.take_damage(18.0)
					_melee_hit_done = true
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 1.3)

		State.P1_BODY_SLAM:
			var elapsed := _state_duration - _state_timer
			if _combo_step == 0 and elapsed >= 0.55:
				_combo_step = 1
				_shake_camera(0.65)
				_spawn_shockwave()
				if _player and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 7.2:
					if _player.has_method("take_damage"):
						_player.take_damage(30.0)
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 1.35)

		State.P1_MAGMA_SPIT, State.P1_SERPENT_SWEEP, State.P2_RYKARDS_RANCOR:
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 1.1 if phase == 1 else 0.85)

		State.P2_SWORD_COMBO:
			global_position += _lunge_dir * 11.0 * delta
			var elapsed := _state_duration - _state_timer
			var step := int(elapsed / 0.52)
			if step > _combo_step:
				_combo_step = step
				_melee_hit_done = false
				_shake_camera(0.45)
				_spawn_flame_pillar(global_position + _lunge_dir * 5.0 + Vector3(randf_range(-3.0, 3.0), 0.0, 0.0))
			if not _melee_hit_done and _player and is_instance_valid(_player):
				if global_position.distance_to(_player.global_position) < 6.8 and _player.has_method("take_damage"):
					_player.take_damage(26.0)
					_melee_hit_done = true
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 0.9)

		State.P2_TAKERS_FLAMES:
			var elapsed := _state_duration - _state_timer
			var desired_step := int(elapsed / 0.12)
			while _flame_step < desired_step and _flame_step < 7:
				_flame_step += 1
				_spawn_flame_pillar(global_position + _flame_dir * (float(_flame_step) * 3.4))
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 0.95)

		State.P2_RAIN_OF_SKULLS:
			_rain_spawn_accum -= delta
			if _rain_spawn_accum <= 0.0:
				_rain_spawn_accum = 0.22
				_spawn_sky_skull()
			if _state_timer <= 0.0:
				_set_state(State.RECOVER, 1.1)

		State.STAGGERED:
			if _state_timer <= 0.0:
				_set_state(State.IDLE, 0.7)

		State.RECOVER:
			_face_player(delta, 2.2)
			if _state_timer <= 0.0:
				_set_state(State.IDLE, 0.95 if phase == 1 else 0.55)

func _set_state(new_state: State, duration: float) -> void:
	state = new_state
	_state_timer = duration
	_state_duration = duration

func _face_player(delta: float, turn_speed: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var to_p := _player.global_position - global_position
	to_p.y = 0.0
	if to_p.length() > 0.1:
		var target_rot := atan2(to_p.x, to_p.z)
		rotation.y = lerp_angle(rotation.y, target_rot, turn_speed * delta)

func _begin_telegraph() -> void:
	if phase == 1:
		var p1_seq := [State.P1_BITE_LUNGE, State.P1_MAGMA_SPIT, State.P1_MULTI_BITE, State.P1_BODY_SLAM, State.P1_SERPENT_SWEEP]
		_queued_attack = p1_seq[_attack_idx % p1_seq.size()]
		_set_state(State.TELEGRAPH, 0.82)
	else:
		var p2_seq := [State.P2_SWORD_COMBO, State.P2_TAKERS_FLAMES, State.P2_RYKARDS_RANCOR, State.P2_RAIN_OF_SKULLS]
		_queued_attack = p2_seq[_attack_idx % p2_seq.size()]
		_set_state(State.TELEGRAPH, 0.92 if _queued_attack == State.P2_RAIN_OF_SKULLS else 0.62)
	_attack_idx += 1

func _execute_queued_attack() -> void:
	_melee_hit_done = false
	_combo_step = 0
	if _player and is_instance_valid(_player):
		_lunge_dir = (_player.global_position - global_position)
		_lunge_dir.y = 0.0
		_lunge_dir = _lunge_dir.normalized()
	else:
		_lunge_dir = Vector3.BACK

	match _queued_attack:
		State.P1_BITE_LUNGE:
			_set_state(State.P1_BITE_LUNGE, 0.52)

		State.P1_MULTI_BITE:
			_set_state(State.P1_MULTI_BITE, 1.25)

		State.P1_BODY_SLAM:
			_set_state(State.P1_BODY_SLAM, 1.0)

		State.P1_MAGMA_SPIT:
			_set_state(State.P1_MAGMA_SPIT, 0.65)
			_spawn_magma_spit(4)

		State.P1_SERPENT_SWEEP:
			_set_state(State.P1_SERPENT_SWEEP, 0.65)
			_spawn_shockwave()

		State.P2_SWORD_COMBO:
			_set_state(State.P2_SWORD_COMBO, 1.05)
			_spawn_shockwave()

		State.P2_TAKERS_FLAMES:
			_flame_step = 0
			_flame_dir = _lunge_dir
			_shake_camera(0.55)
			_set_state(State.P2_TAKERS_FLAMES, 1.0)

		State.P2_RYKARDS_RANCOR:
			_set_state(State.P2_RYKARDS_RANCOR, 0.75)
			_spawn_rancor_skulls(6)

		State.P2_RAIN_OF_SKULLS:
			_rain_spawn_accum = 0.0
			_shake_camera(0.4)
			_set_state(State.P2_RAIN_OF_SKULLS, 3.1)

func _shake_camera(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("boss_camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(amount)

func _spawn_magma_spit(count: int) -> void:
	for i in range(count):
		var blob := Area3D.new()
		blob.set_script(PROJECTILE_SCRIPT)
		blob.kind = PROJECTILE_SCRIPT.Kind.LAVA_BLOB
		blob.damage = 18.0
		blob.lifetime = 5.0
		blob.target = _player

		var spread := (float(i) - float(count - 1) * 0.5) * 0.38
		var dir := _lunge_dir.rotated(Vector3.UP, spread).normalized()
		blob.velocity_vec = dir * randf_range(11.0, 17.0) + Vector3(0.0, randf_range(7.0, 10.5), 0.0)

		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.65
		sphere.height = 0.85
		mesh_inst.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.35, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.25, 0.02)
		mat.emission_energy_multiplier = 3.2
		mesh_inst.material_override = mat
		blob.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.7
		col.shape = s
		blob.add_child(col)

		get_tree().current_scene.add_child(blob)
		blob.global_position = global_position + Vector3(0.0, 3.2, 0.0)

func _spawn_shockwave() -> void:
	var wave := Area3D.new()
	wave.set_script(PROJECTILE_SCRIPT)
	wave.kind = PROJECTILE_SCRIPT.Kind.SHOCKWAVE
	wave.damage = 24.0 if phase == 1 else 32.0
	wave.lifetime = 1.9

	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.3
	torus.outer_radius = 1.85
	mesh_inst.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.02)
	mat.emission_energy_multiplier = 3.2
	mesh_inst.material_override = mat
	wave.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.75
	cyl.height = 1.2
	col.shape = cyl
	wave.add_child(col)

	get_tree().current_scene.add_child(wave)
	wave.global_position = Vector3(global_position.x, 0.35, global_position.z)

func _spawn_flame_pillar(pos: Vector3) -> void:
	var pillar := Area3D.new()
	pillar.set_script(PROJECTILE_SCRIPT)
	pillar.kind = PROJECTILE_SCRIPT.Kind.FLAME_PILLAR
	pillar.damage = 30.0
	pillar.lifetime = 0.65

	var mesh_inst := MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.8
	cyl_mesh.bottom_radius = 1.6
	cyl_mesh.height = 4.5
	mesh_inst.mesh = cyl_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.04)
	mat.emission_energy_multiplier = 4.5
	mesh_inst.material_override = mat
	pillar.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 4.5
	col.shape = shape
	pillar.add_child(col)

	get_tree().current_scene.add_child(pillar)
	pillar.global_position = Vector3(pos.x, 1.8, pos.z)

func _spawn_rancor_skulls(count: int) -> void:
	for i in range(count):
		var skull := Area3D.new()
		skull.set_script(PROJECTILE_SCRIPT)
		skull.kind = PROJECTILE_SCRIPT.Kind.HOMING_SKULL
		skull.speed = 11.5
		skull.damage = 20.0
		skull.target = _player

		var spread := (float(i) - float(count - 1) * 0.5) * 0.45
		skull.direction = _lunge_dir.rotated(Vector3.UP, spread).normalized()

		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.55
		sphere.height = 1.1
		mesh_inst.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.05)
		mat.emission_energy_multiplier = 4.0
		mesh_inst.material_override = mat
		skull.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.65
		col.shape = shape
		skull.add_child(col)

		get_tree().current_scene.add_child(skull)
		skull.global_position = global_position + Vector3(spread * 2.5, 3.4, 0.0)

func _spawn_sky_skull() -> void:
	var skull := Area3D.new()
	skull.set_script(PROJECTILE_SCRIPT)
	skull.kind = PROJECTILE_SCRIPT.Kind.SKY_SKULL
	skull.damage = 22.0
	skull.lifetime = 2.5

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.2
	mesh_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.02)
	mat.emission_energy_multiplier = 4.8
	mesh_inst.material_override = mat
	skull.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	col.shape = shape
	skull.add_child(col)

	var target_pos := _player.global_position if (_player and is_instance_valid(_player)) else Vector3.ZERO
	var rx := target_pos.x + randf_range(-6.0, 6.0)
	var rz := target_pos.z + randf_range(-6.0, 6.0)
	get_tree().current_scene.add_child(skull)
	skull.global_position = Vector3(rx, 18.0, rz)

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	hp = maxf(0.0, hp - amount)
	poise += amount
	emit_signal("hp_changed", hp, max_hp)

	if model_pivot:
		var tw := create_tween()
		tw.tween_property(model_pivot, "scale", Vector3(1.04, 0.96, 1.04), 0.06)
		tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.08)

	# Poise break stagger! (Interrupts Rain of Skulls or other casts)
	if poise >= POISE_THRESHOLD and hp > 0.0 and state != State.STAGGERED:
		poise = 0.0
		if telegraph_ring:
			telegraph_ring.visible = false
		_set_state(State.STAGGERED, 1.8)
		emit_signal("staggered")

	if phase == 1 and hp <= max_hp * 0.55 and hp > 0.0:
		phase = 2
		_attack_idx = 0
		emit_signal("phase_changed", 2)
		_spawn_shockwave()

	if hp <= 0.0:
		state = State.DEAD
		if telegraph_ring:
			telegraph_ring.visible = false
		emit_signal("died")
		var die_tw := create_tween()
		die_tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 1.2)
		die_tw.tween_callback(func(): visible = false)
