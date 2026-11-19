extends Camera3D

@export var player_path: NodePath
@export var boss_path: NodePath
@export var follow_distance: float = 8.5
@export var follow_height: float = 4.2
@export var smooth_speed: float = 7.0

var _player: Node3D = null
var _boss: Node3D = null
var _shake: float = 0.0

func _ready() -> void:
	add_to_group("boss_camera")
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	if boss_path != NodePath():
		_boss = get_node_or_null(boss_path)

func add_shake(amount: float) -> void:
	_shake = minf(1.2, _shake + amount)

func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return

	var target_dir := Vector3.FORWARD
	var look_target := _player.global_position + Vector3(0.0, 1.5, 0.0)

	if _boss and is_instance_valid(_boss) and _boss.visible:
		var to_boss := _boss.global_position - _player.global_position
		to_boss.y = 0.0
		if to_boss.length() > 0.2:
			target_dir = to_boss.normalized()
		look_target = _player.global_position.lerp(_boss.global_position, 0.45) + Vector3(0.0, 2.3, 0.0)

	var desired_pos := _player.global_position - target_dir * follow_distance + Vector3(0.0, follow_height, 0.0)
	global_position = global_position.lerp(desired_pos, clampf(smooth_speed * delta, 0.0, 1.0))
	if _shake > 0.005:
		global_position += Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake), randf_range(-_shake, _shake)) * 0.45
		_shake = lerpf(_shake, 0.0, 9.0 * delta)
	look_at(look_target, Vector3.UP)
