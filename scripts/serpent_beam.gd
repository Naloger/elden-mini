extends Area3D

@export var speed: float = 36.0
@export var damage: float = 95.0
@export var lifetime: float = 1.6

var direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _hit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	scale = Vector3(1.0 + _age * 0.4, 1.0, 1.0 + _age * 0.25)

func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body.is_in_group("boss"):
		_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_trigger_impact()
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _hit:
		return
	if area.is_in_group("boss"):
		_hit = true
		if area.has_method("take_damage"):
			area.take_damage(damage)
		_trigger_impact()
		queue_free()

func _trigger_impact() -> void:
	var cam := get_tree().get_first_node_in_group("boss_camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(0.22)
