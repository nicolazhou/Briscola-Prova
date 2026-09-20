extends Control

const CARD_SIZE := Vector2(96, 155)
const TABLE_CARD_SIZE := Vector2(102, 165)
const BACK_TEXTURE := "res://assets/cards/retro.svg"

var engine := BriscolaEngine.new()
var busy := false

var opponent_hand: HBoxContainer
var player_hand: HBoxContainer
var deck_box: HBoxContainer
var cpu_slot: PanelContainer
var human_slot: PanelContainer
var score_label: Label
var deck_label: Label
var trump_label: Label
var turn_label: Label
var status_label: Label
var trick_label: Label
var result_overlay: CenterContainer
var result_title: Label
var result_score: Label


func _ready() -> void:
    _build_interface()
    _new_game()


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.is_pressed() or key_event.is_echo():
        return
    if busy or engine.current_player != "human":
        return

    var index := -1
    if key_event.keycode == KEY_1:
        index = 0
    elif key_event.keycode == KEY_2:
        index = 1
    elif key_event.keycode == KEY_3:
        index = 2

    if index >= 0 and index < engine.hands["human"].size():
        _on_player_card_pressed(index)


func _build_interface() -> void:
    var background := ColorRect.new()
    background.color = Color("#123d2d")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var vignette := ColorRect.new()
    vignette.color = Color(0.02, 0.08, 0.06, 0.20)
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(vignette)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    add_child(margin)

    var root_column := VBoxContainer.new()
    root_column.add_theme_constant_override("separation", 10)
    margin.add_child(root_column)

    # Header
    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 48
    root_column.add_child(header)

    var title := Label.new()
    title.text = "BRISCOLA"
    title.add_theme_font_size_override("font_size", 30)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    trick_label = Label.new()
    trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    trick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trick_label.add_theme_font_size_override("font_size", 18)
    header.add_child(trick_label)

    score_label = Label.new()
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    score_label.add_theme_font_size_override("font_size", 22)
    header.add_child(score_label)

    # Opponent
    var opponent_panel := _panel(Color("#173a30aa"), 14)
    opponent_panel.custom_minimum_size.y = 132
    root_column.add_child(opponent_panel)

    var opponent_column := VBoxContainer.new()
    opponent_column.alignment = BoxContainer.ALIGNMENT_CENTER
    opponent_column.add_theme_constant_override("separation", 6)
    opponent_panel.add_child(opponent_column)

    var opponent_name := Label.new()
    opponent_name.text = "TONY · CPU"
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent_name.add_theme_font_size_override("font_size", 16)
    opponent_column.add_child(opponent_name)

    var opponent_center := CenterContainer.new()
    opponent_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    opponent_column.add_child(opponent_center)

    opponent_hand = HBoxContainer.new()
    opponent_hand.add_theme_constant_override("separation", -46)
    opponent_center.add_child(opponent_hand)

    # Main table zone
    var table_panel := _panel(Color("#0c2d23b8"), 18)
    table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_column.add_child(table_panel)

    var table_margin := MarginContainer.new()
    table_margin.add_theme_constant_override("margin_left", 20)
    table_margin.add_theme_constant_override("margin_right", 20)
    table_margin.add_theme_constant_override("margin_top", 12)
    table_margin.add_theme_constant_override("margin_bottom", 12)
    table_panel.add_child(table_margin)

    var table_row := HBoxContainer.new()
    table_row.add_theme_constant_override("separation", 22)
    table_margin.add_child(table_row)

    # Deck/trump zone
    var deck_column := VBoxContainer.new()
    deck_column.custom_minimum_size.x = 286
    deck_column.alignment = BoxContainer.ALIGNMENT_CENTER
    deck_column.add_theme_constant_override("separation", 8)
    table_row.add_child(deck_column)

    var deck_title := Label.new()
    deck_title.text = "MAZZO"
    deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    deck_title.add_theme_font_size_override("font_size", 15)
    deck_column.add_child(deck_title)

    deck_box = HBoxContainer.new()
    deck_box.alignment = BoxContainer.ALIGNMENT_CENTER
    deck_box.add_theme_constant_override("separation", 10)
    deck_column.add_child(deck_box)

    deck_label = Label.new()
    deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    deck_column.add_child(deck_label)

    trump_label = Label.new()
    trump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    trump_label.add_theme_font_size_override("font_size", 15)
    deck_column.add_child(trump_label)

    # Played cards zone
    var trick_column := VBoxContainer.new()
    trick_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trick_column.alignment = BoxContainer.ALIGNMENT_CENTER
    trick_column.add_theme_constant_override("separation", 10)
    table_row.add_child(trick_column)

    var table_title := Label.new()
    table_title.text = "TAVOLO"
    table_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    table_title.add_theme_font_size_override("font_size", 15)
    trick_column.add_child(table_title)

    var trick_row := HBoxContainer.new()
    trick_row.alignment = BoxContainer.ALIGNMENT_CENTER
    trick_row.add_theme_constant_override("separation", 24)
    trick_column.add_child(trick_row)

    var cpu_column := VBoxContainer.new()
    cpu_column.add_theme_constant_override("separation", 4)
    trick_row.add_child(cpu_column)
    var cpu_name := Label.new()
    cpu_name.text = "Tony"
    cpu_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cpu_column.add_child(cpu_name)
    cpu_slot = _card_slot()
    cpu_column.add_child(cpu_slot)

    var versus := Label.new()
    versus.text = "VS"
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    versus.add_theme_font_size_override("font_size", 20)
    trick_row.add_child(versus)

    var human_column := VBoxContainer.new()
    human_column.add_theme_constant_override("separation", 4)
    trick_row.add_child(human_column)
    var human_name := Label.new()
    human_name.text = "Tu"
    human_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    human_column.add_child(human_name)
    human_slot = _card_slot()
    human_column.add_child(human_slot)

    # Status/info zone
    var info_panel := _panel(Color("#173a30aa"), 14)
    info_panel.custom_minimum_size.x = 276
    table_row.add_child(info_panel)

    var info_margin := MarginContainer.new()
    info_margin.add_theme_constant_override("margin_left", 16)
    info_margin.add_theme_constant_override("margin_right", 16)
    info_margin.add_theme_constant_override("margin_top", 14)
    info_margin.add_theme_constant_override("margin_bottom", 14)
    info_panel.add_child(info_margin)

    var info_column := VBoxContainer.new()
    info_column.alignment = BoxContainer.ALIGNMENT_CENTER
    info_column.add_theme_constant_override("separation", 10)
    info_margin.add_child(info_column)

    var info_title := Label.new()
    info_title.text = "PARTITA"
    info_title.add_theme_font_size_override("font_size", 15)
    info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_column.add_child(info_title)

    turn_label = Label.new()
    turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn_label.add_theme_font_size_override("font_size", 20)
    turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_column.add_child(turn_label)

    var rules := Label.new()
    rules.text = "Asso 11 · Tre 10\nRe 4 · Cavallo 3 · Fante 2"
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rules.add_theme_color_override("font_color", Color("#c5d8cf"))
    info_column.add_child(rules)

    # Player
    var player_panel := _panel(Color("#173a30aa"), 14)
    player_panel.custom_minimum_size.y = 186
    root_column.add_child(player_panel)

    var player_column := VBoxContainer.new()
    player_column.alignment = BoxContainer.ALIGNMENT_CENTER
    player_column.add_theme_constant_override("separation", 6)
    player_panel.add_child(player_column)

    var player_name := Label.new()
    player_name.text = "TU · scegli una carta (1 / 2 / 3)"
    player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_name.add_theme_font_size_override("font_size", 16)
    player_column.add_child(player_name)

    var player_center := CenterContainer.new()
    player_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    player_column.add_child(player_center)

    player_hand = HBoxContainer.new()
    player_hand.add_theme_constant_override("separation", 12)
    player_center.add_child(player_hand)

    # Footer
    var footer := HBoxContainer.new()
    footer.custom_minimum_size.y = 44
    footer.add_theme_constant_override("separation", 12)
    root_column.add_child(footer)

    status_label = Label.new()
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("#e3eee9"))
    footer.add_child(status_label)

    var new_game_button := Button.new()
    new_game_button.text = "Nuova partita"
    new_game_button.custom_minimum_size = Vector2(150, 42)
    new_game_button.pressed.connect(_new_game)
    footer.add_child(new_game_button)

    # End-game overlay.
    result_overlay = CenterContainer.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.visible = false
    add_child(result_overlay)

    var result_panel := _panel(Color("#0a211af2"), 22)
    result_panel.custom_minimum_size = Vector2(460, 260)
    result_overlay.add_child(result_panel)

    var result_margin := MarginContainer.new()
    result_margin.add_theme_constant_override("margin_left", 36)
    result_margin.add_theme_constant_override("margin_right", 36)
    result_margin.add_theme_constant_override("margin_top", 30)
    result_margin.add_theme_constant_override("margin_bottom", 30)
    result_panel.add_child(result_margin)

    var result_column := VBoxContainer.new()
    result_column.alignment = BoxContainer.ALIGNMENT_CENTER
    result_column.add_theme_constant_override("separation", 16)
    result_margin.add_child(result_column)

    result_title = Label.new()
    result_title.text = "Partita terminata"
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 28)
    result_column.add_child(result_title)

    result_score = Label.new()
    result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_score.add_theme_font_size_override("font_size", 21)
    result_column.add_child(result_score)

    var replay := Button.new()
    replay.text = "Gioca ancora"
    replay.custom_minimum_size = Vector2(190, 48)
    replay.pressed.connect(_new_game)
    result_column.add_child(replay)


func _new_game() -> void:
    busy = false
    result_overlay.visible = false
    engine.new_game()
    _refresh_all()
    _set_status("Tocca a te. Scegli una carta.")


func _on_player_card_pressed(index: int) -> void:
    if busy or engine.current_player != "human":
        return

    var card: Dictionary = engine.play_card("human", index)
    if card.is_empty():
        return

    busy = true
    _refresh_all()
    _set_status("Hai giocato %s." % engine.card_name(card))
    await get_tree().create_timer(0.28).timeout

    if engine.table.size() == 2:
        await _finish_trick()
    else:
        await _cpu_turn()


func _cpu_turn() -> void:
    if engine.current_player != "cpu" or engine.hands["cpu"].is_empty():
        busy = false
        _refresh_all()
        return

    busy = true
    _set_status("Tony sta scegliendo...")
    await get_tree().create_timer(0.52).timeout

    var index: int = engine.choose_cpu_card()
    if index < 0:
        busy = false
        return

    var card: Dictionary = engine.play_card("cpu", index)
    _refresh_all()
    _set_status("Tony gioca %s." % engine.card_name(card))
    await get_tree().create_timer(0.42).timeout

    if engine.table.size() == 2:
        await _finish_trick()
    else:
        busy = false
        _refresh_all()
        _set_status("Tocca a te.")


func _finish_trick() -> void:
    # Lascia le due carte sul tavolo per un momento prima di assegnare la presa.
    await get_tree().create_timer(0.62).timeout
    var result: Dictionary = engine.resolve_trick()
    if result.is_empty():
        busy = false
        return

    _refresh_all()
    var winner_name: String = "Tu" if result["winner"] == "human" else "Tony"
    _set_status("%s prende la mano (+%d punti)." % [winner_name, result["points"]])
    await get_tree().create_timer(0.62).timeout

    if engine.is_game_over():
        busy = false
        _show_result()
        return

    if engine.current_player == "cpu":
        await _cpu_turn()
    else:
        busy = false
        _refresh_all()
        _set_status("Hai preso la mano: inizi tu.")


func _show_result() -> void:
    result_score.text = engine.result_text()
    if engine.scores["human"] > engine.scores["cpu"]:
        result_title.text = "Hai vinto!"
    elif engine.scores["human"] < engine.scores["cpu"]:
        result_title.text = "Tony ha vinto"
    else:
        result_title.text = "Pareggio"
    result_overlay.visible = true
    _set_status("Partita conclusa.")


func _refresh_all() -> void:
    score_label.text = "TU %d  ·  %d TONY" % [engine.scores["human"], engine.scores["cpu"]]
    trick_label.text = "Presa %d / 20" % min(engine.trick_number, 20)
    trump_label.text = "Briscola: %s" % BriscolaEngine.SUIT_NAMES[engine.trump_suit]
    deck_label.text = "%d carte da pescare" % engine.deck.size()
    turn_label.text = "Tocca a te" if engine.current_player == "human" else "Turno di Tony"

    _refresh_opponent_hand()
    _refresh_player_hand()
    _refresh_deck()
    _refresh_table()


func _refresh_opponent_hand() -> void:
    _clear_container(opponent_hand)
    for _card in engine.hands["cpu"]:
        opponent_hand.add_child(_texture_card(BACK_TEXTURE, CARD_SIZE * 0.72))


func _refresh_player_hand() -> void:
    _clear_container(player_hand)
    for i in range(engine.hands["human"].size()):
        var card: Dictionary = engine.hands["human"][i]
        var button := _clickable_card(card, i)
        button.disabled = busy or engine.current_player != "human"
        player_hand.add_child(button)


func _refresh_deck() -> void:
    _clear_container(deck_box)

    # La briscola resta visibile finché non viene pescata.
    if engine.deck.size() > 1:
        deck_box.add_child(_texture_card(BACK_TEXTURE, CARD_SIZE * 0.72))
    else:
        var empty_space := Control.new()
        empty_space.custom_minimum_size = CARD_SIZE * 0.72
        deck_box.add_child(empty_space)

    if engine.deck.size() > 0:
        deck_box.add_child(_texture_card(engine.card_texture_path(engine.trump_card), CARD_SIZE * 0.72))
    else:
        var empty_trump := Control.new()
        empty_trump.custom_minimum_size = CARD_SIZE * 0.72
        deck_box.add_child(empty_trump)


func _refresh_table() -> void:
    _clear_slot(cpu_slot)
    _clear_slot(human_slot)

    for play in engine.table:
        var card: Dictionary = play["card"]
        var view := _texture_card(engine.card_texture_path(card), TABLE_CARD_SIZE)
        view.tooltip_text = engine.card_name(card)
        if play["player"] == "cpu":
            cpu_slot.add_child(view)
        else:
            human_slot.add_child(view)


func _clickable_card(card: Dictionary, index: int) -> Button:
    var button := Button.new()
    button.flat = true
    button.custom_minimum_size = CARD_SIZE
    button.tooltip_text = "%s · %d punti" % [engine.card_name(card), engine.points_for(card)]
    button.focus_mode = Control.FOCUS_ALL
    button.pressed.connect(_on_player_card_pressed.bind(index))

    var texture_rect := TextureRect.new()
    texture_rect.texture = load(engine.card_texture_path(card))
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(texture_rect)
    texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var number := Label.new()
    number.text = str(index + 1)
    number.position = Vector2(4, 4)
    number.custom_minimum_size = Vector2(24, 24)
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    number.add_theme_color_override("font_color", Color.WHITE)
    number.add_theme_color_override("font_shadow_color", Color.BLACK)
    number.add_theme_constant_override("shadow_offset_x", 1)
    number.add_theme_constant_override("shadow_offset_y", 1)
    number.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(number)

    button.mouse_entered.connect(_on_card_hover.bind(button, true))
    button.mouse_exited.connect(_on_card_hover.bind(button, false))
    return button


func _on_card_hover(button: Button, entered: bool) -> void:
    if button.disabled:
        return
    button.modulate = Color("#ffffff") if entered else Color("#eeeeee")


func _texture_card(path: String, minimum_size: Vector2) -> TextureRect:
    var texture_rect := TextureRect.new()
    texture_rect.texture = load(path)
    texture_rect.custom_minimum_size = minimum_size
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return texture_rect


func _card_slot() -> PanelContainer:
    var slot := PanelContainer.new()
    slot.custom_minimum_size = TABLE_CARD_SIZE + Vector2(16, 16)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#08261e80")
    style.border_color = Color("#91a99f45")
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    slot.add_theme_stylebox_override("panel", style)
    return slot


func _clear_slot(slot: PanelContainer) -> void:
    _clear_container(slot)


func _clear_container(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _panel(color: Color, radius: int) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.border_color = Color("#cce2d719")
    style.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel", style)
    return panel


func _set_status(text: String) -> void:
    status_label.text = text
