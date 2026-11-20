extends Area3D

enum Kind { HOMING_SKULL, SHOCKWAVE, LAVA_BLOB, LAVA_POOL, FLAME_PILLAR, SKY_SKULL }

@export var kind: Kind = Kind.HOMING_SKULL
@export var speed: float = 11.0
@export var damage: float = 20.0
@export var lifetime: float = 4.5
@export var homing_strength: float = 1.6

var direction: Vector3 = Vector3.FORWARD
var velocity_vec: Vector3 = Vector3.ZERO
var target: Node3D = null
var _age: float = 0.0
var _hit_player: bool = false
var _pool_tick: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	match kind:
		Kind.SHOCKWAVE:
			var grow := 1.0 + delta * 5.2
			scale = Vector3(scale.x * grow, 1.0, scale.z * grow)

		Kind.HOMING_SKULL:
			if target and is_instance_valid(target):
				var desired := (target.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
				direction = direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			global_position += direction * speed * delta

		Kind.LAVA_BLOB:
			velocity_vec.y -= 18.0 * delta
			global_position += velocity_vec * delta
			if global_position.y <= 0.12:
				_transform_to_lava_pool()

		Kind.LAVA_POOL:
			_pool_tick -= delta
			if _pool_tick <= 0.0 and target and is_instance_valid(target):
				var dist := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
				if dist < 2.2 and target.has_method("take_damage"):
					target.take_damage(10.0)
					_pool_tick = 0.55

		Kind.FLAME_PILLAR:
			# Erupt upward quickly then fade
			var t := _age / lifetime
			var h := sin(t * PI) * 2.6 + 0.2
			scale = Vector3(1.0, h, 1.0)

		Kind.SKY_SKULL:
			global_position += Vector3(0.0, -16.0, 0.0) * delta
			if global_position.y <= 0.25:
				queue_free()

const LAVA_SHADER := preload("res://shaders/lava.gdshader")

func _transform_to_lava_pool() -> void:
	kind = Kind.LAVA_POOL
	_age = 0.0
	lifetime = 4.2
	global_position.y = 0.04
	scale = Vector3(3.4, 0.08, 3.4)
	for c in get_children():
		if c is MeshInstance3D:
			var sm := ShaderMaterial.new()
			sm.shader = LAVA_SHADER
			sm.set_shader_parameter("speed", 0.35)
			(c as MeshInstance3D).set_surface_override_material(0, sm)

func _on_body_entered(body: Node) -> void:
	if _hit_player or kind == Kind.LAVA_POOL:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_hit_player = true
		body.take_damage(damage)
		if kind == Kind.HOMING_SKULL or kind == Kind.SKY_SKULL or kind == Kind.LAVA_BLOB:
			queue_free()
