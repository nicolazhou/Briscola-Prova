extends Button
class_name CardView

var card_data: Dictionary = {}
var card_index: int = -1
var _hover_tween: Tween

func setup(card: Dictionary, index: int, texture: Texture2D, minimum_size: Vector2, tooltip: String) -> void:
    card_data = card
    card_index = index
    flat = true
    custom_minimum_size = minimum_size
    tooltip_text = tooltip
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    pivot_offset = minimum_size * 0.5

    var art := TextureRect.new()
    art.name = "Art"
    art.texture = texture
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(art)

    var shortcut := Label.new()
    shortcut.name = "Shortcut"
    shortcut.text = str(index + 1)
    shortcut.position = Vector2(7, 6)
    shortcut.size = Vector2(26, 26)
    shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shortcut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    shortcut.add_theme_font_size_override("font_size", 14)
    shortcut.add_theme_color_override("font_color", Color.WHITE)
    shortcut.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    shortcut.add_theme_constant_override("shadow_offset_x", 1)
    shortcut.add_theme_constant_override("shadow_offset_y", 1)
    shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shortcut)

    mouse_entered.connect(_set_hovered.bind(true))
    mouse_exited.connect(_set_hovered.bind(false))
    focus_entered.connect(_set_hovered.bind(true))
    focus_exited.connect(_set_hovered.bind(false))


func set_interactive(value: bool) -> void:
    disabled = not value
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
    if not value:
        scale = Vector2.ONE
        modulate = Color(0.88, 0.88, 0.88, 1.0)
    else:
        modulate = Color.WHITE


func _set_hovered(hovered: bool) -> void:
    if disabled:
        return
    if _hover_tween != null and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.set_trans(Tween.TRANS_QUAD)
    _hover_tween.set_ease(Tween.EASE_OUT)
    var target_scale := Vector2(1.065, 1.065) if hovered else Vector2.ONE
    _hover_tween.tween_property(self, "scale", target_scale, 0.11)
