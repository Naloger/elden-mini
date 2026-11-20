extends CharacterBody3D

signal hp_changed(current: float, max_hp: float)
signal stamina_changed(current: float, max_stamina: float)
signal died

enum State {
	IDLE,
	WALK,
	RUN,
	ROLL,
	ATTACK
}

@export var move_speed: float = 7.0
@export var run_speed: float = 11.5
@export var dodge_speed: float = 18.0
@export var dodge_duration: float = 0.45
@export var dodge_stamina_cost: float = 25.0
@export var attack_stamina_cost: float = 20.0
@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
@export var arena_radius: float = 20.5
@export var boss_path: NodePath

var current_state: State = State.IDLE
var hp: float = 100.0
var stamina: float = 100.0
var touch_move_vec: Vector2 = Vector2.ZERO

var _state_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _stamina_regen_delay: float = 0.0
var _dodge_dir: Vector3 = Vector3.FORWARD
var _invulnerable: bool = false
var _dead: bool = false
var _boss: Node3D = null
var _anim_players: Array[AnimationPlayer] = []
var _current_anim: String = ""

@onready var visual: Node3D = $Visual
@onready var weapon_pivot: Node3D = $Visual/WeaponPivot
@onready var shield_pivot: Node3D = $Visual/ShieldPivot

const BEAM_SCRIPT := preload("res://scripts/serpent_beam.gd")
# Weapon points along -Z when identity, shield faces along -Z when rotated -90 deg on X
const WEAPON_REST_BASIS := Basis.IDENTITY
const SHIELD_REST_BASIS := Basis(Vector3(1, 0, 0), -PI / 2.0)

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	stamina = max_stamina
	if boss_path != NodePath():
		_boss = get_node_or_null(boss_path)
	_setup_player_real_anims()
	_attach_equipment_to_hands()
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)
	change_state(State.IDLE, true)

func _setup_player_real_anims() -> void:
	var ap := _find_ap(visual)
	if not ap:
		return
	for cname in ["idle", "walk", "run", "roll", "attack"]:
		if ap.has_animation(cname):
			var anim := ap.get_animation(cname)
			anim.loop_mode = Animation.LOOP_LINEAR if cname in ["idle", "walk", "run"] else Animation.LOOP_NONE
	_anim_players = [ap]

func _attach_equipment_to_hands() -> void:
	var sk := _find_skeleton(visual)
	if not sk:
		return
	# c0000 glTF convention: L_Weapon/L_Hand is physical right arm (+X), R_Weapon/R_Hand is physical left arm (-X)
	var right_hand_bone := "L_Weapon" if sk.find_bone("L_Weapon") != -1 else "L_Hand"
	if sk.find_bone(right_hand_bone) != -1 and weapon_pivot:
		var ba_r := BoneAttachment3D.new()
		ba_r.name = "RightWeaponAttachment"
		ba_r.bone_name = right_hand_bone
		sk.add_child(ba_r)
		weapon_pivot.reparent(ba_r, false)
		weapon_pivot.transform = Transform3D(WEAPON_REST_BASIS, Vector3.ZERO)

	var left_hand_bone := "R_Weapon" if sk.find_bone("R_Weapon") != -1 else "R_Hand"
	if sk.find_bone(left_hand_bone) != -1 and shield_pivot:
		var ba_l := BoneAttachment3D.new()
		ba_l.name = "LeftWeaponAttachment"
		ba_l.bone_name = left_hand_bone
		sk.add_child(ba_l)
		shield_pivot.reparent(ba_l, false)
		shield_pivot.transform = Transform3D(SHIELD_REST_BASIS, Vector3.ZERO)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var res := _find_skeleton(c)
		if res:
			return res
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var res := _find_ap(c)
		if res:
			return res
	return null

func change_state(new_state: State, force: bool = false) -> void:
	if not force and current_state == new_state:
		return

	# State Exit Logic
	match current_state:
		State.ROLL:
			_invulnerable = false
			visual.rotation.x = 0.0
			visual.position.y = 0.0
		State.ATTACK:
			pass

	current_state = new_state

	# State Enter Logic
	match current_state:
		State.IDLE:
			_play_player_anim("idle")
		State.WALK:
			_play_player_anim("walk")
		State.RUN:
			_play_player_anim("run")
		State.ROLL:
			_invulnerable = true
			_state_timer = dodge_duration
			_play_player_anim("roll", true)
		State.ATTACK:
			_state_timer = 0.60
			_attack_cooldown = 0.65
			_play_player_anim("attack", true)

func _play_player_anim(cname: String, force_restart: bool = false) -> void:
	if not force_restart and _current_anim == cname:
		return
	if _anim_players.is_empty():
		return
	_current_anim = cname
	for ap in _anim_players:
		if ap.has_animation(cname):
			if force_restart:
				ap.stop()
			ap.play(cname, 0.12)

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		trigger_dodge()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		trigger_attack()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		trigger_attack()

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)

	if _stamina_regen_delay <= 0.0 and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + 34.0 * delta)
		emit_signal("stamina_changed", stamina, max_stamina)

	# State Machine Update
	match current_state:
		State.ROLL:
			_state_timer -= delta
			velocity.x = _dodge_dir.x * dodge_speed
			velocity.z = _dodge_dir.z * dodge_speed
			if _state_timer <= 0.0:
				_transition_after_action()

		State.ATTACK:
			_state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
			if _state_timer <= 0.0:
				_transition_after_action()

		State.IDLE, State.WALK, State.RUN:
			var input_dir := _get_move_input()
			var cam := get_viewport().get_camera_3d()
			var move_dir := Vector3.ZERO

			if input_dir.length() > 0.05:
				if cam:
					var forward := -cam.global_transform.basis.z
					forward.y = 0.0
					forward = forward.normalized()
					var right := cam.global_transform.basis.x
					right.y = 0.0
					right = right.normalized()
					move_dir = (right * input_dir.x + forward * (-input_dir.y)).normalized()
				else:
					move_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

			if move_dir.length() > 0.05:
				var is_running := input_dir.length() > 0.7 or Input.is_key_pressed(KEY_SHIFT)
				var cur_speed := run_speed if is_running else move_speed
				velocity.x = move_dir.x * cur_speed
				velocity.z = move_dir.z * cur_speed

				var target_rot := atan2(-move_dir.x, -move_dir.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, target_rot, 14.0 * delta)

				if is_running:
					change_state(State.RUN)
				else:
					change_state(State.WALK)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)

				if _boss and is_instance_valid(_boss):
					var to_boss := (_boss.global_position - global_position)
					to_boss.y = 0.0
					if to_boss.length() > 0.1:
						var lock_rot := atan2(-to_boss.x, -to_boss.z)
						visual.rotation.y = lerp_angle(visual.rotation.y, lock_rot, 5.0 * delta)

				change_state(State.IDLE)

	velocity.y = 0.0
	move_and_slide()

	# Keep inside volcanic arena
	var flat_pos := Vector2(global_position.x, global_position.z)
	if flat_pos.length() > arena_radius:
		flat_pos = flat_pos.normalized() * arena_radius
		global_position.x = flat_pos.x
		global_position.z = flat_pos.y

func _transition_after_action() -> void:
	var input_dir := _get_move_input()
	if input_dir.length() > 0.7 or Input.is_key_pressed(KEY_SHIFT):
		change_state(State.RUN, true)
	elif input_dir.length() > 0.05:
		change_state(State.WALK, true)
	else:
		change_state(State.IDLE, true)

func _get_move_input() -> Vector2:
	var kb := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if Input.is_key_pressed(KEY_D):
		kb.x += 1.0
	if Input.is_key_pressed(KEY_A):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		kb.y += 1.0
	if Input.is_key_pressed(KEY_W):
		kb.y -= 1.0

	var combined := kb + touch_move_vec
	if combined.length() > 1.0:
		combined = combined.normalized()
	return combined

func trigger_dodge() -> void:
	if _dead or current_state == State.ROLL or stamina < dodge_stamina_cost:
		return
	stamina -= dodge_stamina_cost
	_stamina_regen_delay = 0.55
	emit_signal("stamina_changed", stamina, max_stamina)

	var input_dir := _get_move_input()
	var cam := get_viewport().get_camera_3d()
	if input_dir.length() > 0.1 and cam:
		var forward := -cam.global_transform.basis.z
		forward.y = 0.0
		var right := cam.global_transform.basis.x
		right.y = 0.0
		_dodge_dir = (right.normalized() * input_dir.x + forward.normalized() * (-input_dir.y)).normalized()
	else:
		_dodge_dir = -visual.global_transform.basis.z.normalized()

	change_state(State.ROLL, true)

func trigger_attack() -> void:
	if _dead or current_state == State.ROLL or current_state == State.ATTACK or _attack_cooldown > 0.0 or stamina < attack_stamina_cost:
		return
	stamina -= attack_stamina_cost
	_stamina_regen_delay = 0.65
	emit_signal("stamina_changed", stamina, max_stamina)

	# Face boss on Serpent-Hunter strike
	var aim_dir := -visual.global_transform.basis.z.normalized()
	if _boss and is_instance_valid(_boss):
		var to_boss := (_boss.global_position + Vector3(0.0, 2.2, 0.0) - (global_position + Vector3(0.0, 1.4, 0.0)))
		if to_boss.length() > 0.1:
			aim_dir = to_boss.normalized()
			var flat_dir := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
			if flat_dir.length() > 0.05:
				visual.rotation.y = atan2(-flat_dir.x, -flat_dir.z)

	change_state(State.ATTACK, true)
	_spawn_serpent_beam(aim_dir)

func _spawn_serpent_beam(aim_dir: Vector3) -> void:
	var beam := Area3D.new()
	beam.set_script(BEAM_SCRIPT)
	beam.direction = aim_dir

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.25, 4.0)
	mesh_inst.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 3.5
	mesh_inst.material_override = mat
	beam.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	beam.add_child(col)

	get_tree().current_scene.add_child(beam)
	beam.global_position = global_position + Vector3(0.0, 1.4, 0.0) + aim_dir * 1.4
	beam.look_at(beam.global_position + aim_dir, Vector3.UP)

func take_damage(amount: float) -> void:
	if _dead or _invulnerable:
		return
	hp = maxf(0.0, hp - amount)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0.0:
		_dead = true
		visible = false
		emit_signal("died")
