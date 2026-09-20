extends Button
class_name CardView

signal card_selected(index: int)

var card_data: Dictionary = {}
var card_index: int = -1
var _visual_root: Control
var _hover_tween: Tween
var _rest_rotation: float = 0.0
var _rest_offset_y: float = 0.0


func setup(card: Dictionary, index: int, texture: Texture2D, minimum_size: Vector2, tooltip: String) -> void:
    card_data = card
    card_index = index
    flat = true
    custom_minimum_size = minimum_size
    tooltip_text = tooltip
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
    pivot_offset = minimum_size * 0.5

    _visual_root = Control.new()
    _visual_root.name = "Visual"
    _visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _visual_root.pivot_offset = minimum_size * 0.5
    add_child(_visual_root)

    # Ombra locale: rende la carta leggibile sul feltro senza disegnare un riquadro
    # attorno alla zona di gioco.
    var shadow := Panel.new()
    shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shadow.offset_left = 5
    shadow.offset_top = 7
    shadow.offset_right = 5
    shadow.offset_bottom = 7
    var shadow_style := StyleBoxFlat.new()
    shadow_style.bg_color = Color(0.005, 0.012, 0.01, 0.38)
    shadow_style.corner_radius_top_left = 9
    shadow_style.corner_radius_top_right = 9
    shadow_style.corner_radius_bottom_left = 9
    shadow_style.corner_radius_bottom_right = 9
    shadow.add_theme_stylebox_override("panel", shadow_style)
    _visual_root.add_child(shadow)

    var art := TextureRect.new()
    art.name = "Art"
    art.texture = texture
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _visual_root.add_child(art)

    pressed.connect(_emit_selection)
    mouse_entered.connect(_set_hovered.bind(true))
    mouse_exited.connect(_set_hovered.bind(false))
    focus_entered.connect(_set_hovered.bind(true))
    focus_exited.connect(_set_hovered.bind(false))


func set_fan_pose(rotation_degrees: float, vertical_offset: float) -> void:
    _rest_rotation = deg_to_rad(rotation_degrees)
    _rest_offset_y = vertical_offset
    if _visual_root == null:
        return
    _visual_root.rotation = _rest_rotation
    _visual_root.position.y = _rest_offset_y


func get_visual_global_position() -> Vector2:
    if _visual_root == null:
        return global_position
    return _visual_root.global_position


func set_interactive(value: bool) -> void:
    disabled = not value
    mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
    if _visual_root == null:
        return
    if not value:
        z_index = 0
        _visual_root.scale = Vector2.ONE
        _visual_root.position.y = _rest_offset_y
        _visual_root.rotation = _rest_rotation
        _visual_root.modulate = Color(0.91, 0.91, 0.91, 1.0)
    else:
        _visual_root.modulate = Color.WHITE


func _emit_selection() -> void:
    if disabled:
        return
    card_selected.emit(card_index)


func _set_hovered(hovered: bool) -> void:
    if disabled or _visual_root == null:
        return
    if _hover_tween != null and _hover_tween.is_valid():
        _hover_tween.kill()
    z_index = 10 if hovered else 0

    _hover_tween = create_tween()
    _hover_tween.set_parallel(true)
    _hover_tween.set_trans(Tween.TRANS_QUAD)
    _hover_tween.set_ease(Tween.EASE_OUT)

    var target_scale := Vector2(1.055, 1.055) if hovered else Vector2.ONE
    var target_y: float = _rest_offset_y - 14.0 if hovered else _rest_offset_y
    var target_rotation: float = _rest_rotation * 0.25 if hovered else _rest_rotation
    _hover_tween.tween_property(_visual_root, "scale", target_scale, 0.12)
    _hover_tween.tween_property(_visual_root, "position:y", target_y, 0.12)
    _hover_tween.tween_property(_visual_root, "rotation", target_rotation, 0.12)
