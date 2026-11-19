extends CanvasLayer

@export var player_path: NodePath
@export var boss_path: NodePath

var _player: Node = null
var _boss: Node = null
var _joy_touch_idx: int = -1
var _joy_center: Vector2 = Vector2(140.0, 560.0)
var _joy_radius: float = 75.0

@onready var player_hp_bar: ProgressBar = $PlayerBars/HPBar
@onready var player_stam_bar: ProgressBar = $PlayerBars/StaminaBar
@onready var boss_hp_bar: ProgressBar = $BossContainer/BossHPBar
@onready var boss_name_label: Label = $BossContainer/BossName
@onready var end_overlay: ColorRect = $EndOverlay
@onready var end_label: Label = $EndOverlay/VBox/EndLabel
@onready var retry_btn: Button = $EndOverlay/VBox/RetryButton
@onready var joy_base: Control = $TouchControls/JoystickBase
@onready var joy_knob: ColorRect = $TouchControls/JoystickBase/Knob
@onready var dodge_btn: Button = $TouchControls/Actions/DodgeBtn
@onready var attack_btn: Button = $TouchControls/Actions/AttackBtn

func _ready() -> void:
	end_overlay.visible = false
	retry_btn.pressed.connect(_on_retry_pressed)
	_apply_souls_bar_style(player_hp_bar, Color(0.68, 0.10, 0.10))
	_apply_souls_bar_style(player_stam_bar, Color(0.16, 0.58, 0.24))
	_apply_souls_bar_style(boss_hp_bar, Color(0.72, 0.09, 0.09))

	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	if boss_path != NodePath():
		_boss = get_node_or_null(boss_path)

	if _player:
		_player.hp_changed.connect(_on_player_hp)
		_player.stamina_changed.connect(_on_player_stam)
		_player.died.connect(_on_player_died)
		dodge_btn.pressed.connect(_player.trigger_dodge)
		attack_btn.pressed.connect(_player.trigger_attack)

	if boss_name_label:
		boss_name_label.text = "GOD-DEVOURING SERPENT"
	if _boss:
		_boss.hp_changed.connect(_on_boss_hp)
		_boss.phase_changed.connect(_on_boss_phase)
		_boss.staggered.connect(_on_boss_staggered)
		_boss.died.connect(_on_boss_died)

	if joy_base:
		_joy_center = joy_base.global_position + joy_base.size * 0.5

func _apply_souls_bar_style(bar: ProgressBar, fill_color: Color) -> void:
	if not bar:
		return
	bar.modulate = Color.WHITE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.04, 0.04, 0.88)
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(0.36, 0.28, 0.18, 0.95)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_width_left = 1
	fill.border_width_top = 1
	fill.border_width_right = 1
	fill.border_width_bottom = 1
	fill.border_color = Color(0.15, 0.05, 0.05, 0.5)
	bar.add_theme_stylebox_override("fill", fill)

func _input(event: InputEvent) -> void:
	if not joy_base or not _player:
		return
	_joy_center = joy_base.global_position + joy_base.size * 0.5

	if event is InputEventScreenTouch:
		if event.pressed and _joy_touch_idx == -1:
			if event.position.distance_to(_joy_center) <= _joy_radius * 1.8:
				_joy_touch_idx = event.index
				_update_joystick(event.position)
		elif not event.pressed and event.index == _joy_touch_idx:
			_joy_touch_idx = -1
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == _joy_touch_idx:
		_update_joystick(event.position)

func _update_joystick(pos: Vector2) -> void:
	var offset := pos - _joy_center
	if offset.length() > _joy_radius:
		offset = offset.normalized() * _joy_radius
	var norm := offset / _joy_radius
	if _player:
		_player.touch_move_vec = norm
	if joy_knob:
		joy_knob.position = (joy_base.size * 0.5) + offset - (joy_knob.size * 0.5)

func _reset_joystick() -> void:
	if _player:
		_player.touch_move_vec = Vector2.ZERO
	if joy_knob and joy_base:
		joy_knob.position = (joy_base.size * 0.5) - (joy_knob.size * 0.5)

func _on_player_hp(cur: float, mx: float) -> void:
	player_hp_bar.max_value = mx
	player_hp_bar.value = cur

func _on_player_stam(cur: float, mx: float) -> void:
	player_stam_bar.max_value = mx
	player_stam_bar.value = cur

func _on_boss_hp(cur: float, mx: float) -> void:
	boss_hp_bar.max_value = mx
	boss_hp_bar.value = cur

func _on_boss_phase(phase: int) -> void:
	if phase == 2:
		boss_name_label.text = "RYKARD, LORD OF BLASPHEMY  —  TOGETHER WE SHALL DEVOUR THE VERY GODS!"
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func(): boss_name_label.text = "RYKARD, LORD OF BLASPHEMY")

func _on_boss_staggered() -> void:
	var prev := boss_name_label.text
	boss_name_label.text = prev + "   [STAGGERED!]"
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func(): boss_name_label.text = "GOD-DEVOURING SERPENT" if prev.begins_with("GOD") else "RYKARD, LORD OF BLASPHEMY")

func _on_player_died() -> void:
	end_label.text = "YOU DIED"
	end_label.modulate = Color(0.85, 0.12, 0.12)
	end_overlay.visible = true

func _on_boss_died() -> void:
	end_label.text = "DEMIGOD FELLED"
	end_label.modulate = Color(0.95, 0.82, 0.35)
	end_overlay.visible = true

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
