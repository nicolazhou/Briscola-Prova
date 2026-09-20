extends Control

const MODE := GameModes.TEAMS_4P
const BACK_TEXTURE := "res://assets/cards/retro.svg"
const TABLE_TEXTURE := "res://assets/ui/table_felt.svg"
const SFX_CARD := "res://assets/audio/card_play.wav"
const SFX_TAKE := "res://assets/audio/card_take.wav"
const SFX_SHUFFLE := "res://assets/audio/shuffle.wav"
const SFX_WIN := "res://assets/audio/win.wav"
const SFX_LOSE := "res://assets/audio/lose.wav"
const SFX_DRAW := "res://assets/audio/card_play.wav"

var engine := FourPlayerEngine.new()
var persistence := GamePersistence.new()
var settings: Dictionary = {}
var difficulty := "normal"
var busy := false

var header: HBoxContainer
var score_label: Label
var trick_label: Label
var status_label: Label
var stage: Control
var human_hand: HBoxContainer
var partner_hand: HBoxContainer
var left_hand: VBoxContainer
var right_hand: VBoxContainer
var trick_layer: Control
var deck_layer: Control
var result_overlay: Control
var result_title: Label
var result_detail: Label
var start_overlay: Control
var continue_button: Button
var difficulty_option: OptionButton
var sfx_player: AudioStreamPlayer
var _table_nodes: Dictionary = {}
var _player_labels: Dictionary = {}
var _turn_badges: Dictionary = {}
var deal_layer: Control
var capture_layer: Control
var our_pile: Control
var their_pile: Control
var our_pile_label: Label
var their_pile_label: Label
var _trump_revealed := true
var _visible_hand_counts: Dictionary = {}
var _last_indicated_player := ""

var card_size := Vector2(92, 148)
var back_size := Vector2(62, 100)
var table_card_size := Vector2(96, 155)


func _ready() -> void:
    settings = persistence.load_settings()
    difficulty = str(settings.get("difficulty", "normal"))
    _build_interface()
    get_viewport().size_changed.connect(_layout_stage)
    await get_tree().process_frame
    _layout_stage()
    _show_start_overlay()
    if OS.has_feature("web"):
        call_deferred("_maybe_run_web_qa")


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_progress()


func _build_interface() -> void:
    var background := TextureRect.new()
    background.texture = load(TABLE_TEXTURE)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var shade := ColorRect.new()
    shade.color = Color(0.005, 0.025, 0.02, 0.18)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 4)
    add_child(root)

    header = HBoxContainer.new()
    header.custom_minimum_size.y = 58
    header.add_theme_constant_override("separation", 12)
    root.add_child(header)

    var back_button := Button.new()
    back_button.text = "← Menu"
    back_button.custom_minimum_size = Vector2(90, 42)
    _style_button(back_button, false)
    back_button.pressed.connect(_back_to_main)
    header.add_child(back_button)

    var title := Label.new()
    title.text = "BRISCOLA A 4 · SQUADRE"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("#f5efe1"))
    header.add_child(title)

    trick_label = Label.new()
    trick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    trick_label.add_theme_color_override("font_color", Color("#c8d7d0"))
    header.add_child(trick_label)

    score_label = Label.new()
    score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color("#d6b45b"))
    header.add_child(score_label)

    stage = Control.new()
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_child(stage)

    partner_hand = HBoxContainer.new()
    partner_hand.alignment = BoxContainer.ALIGNMENT_CENTER
    partner_hand.add_theme_constant_override("separation", -22)
    stage.add_child(partner_hand)

    human_hand = HBoxContainer.new()
    human_hand.alignment = BoxContainer.ALIGNMENT_CENTER
    human_hand.add_theme_constant_override("separation", -18)
    stage.add_child(human_hand)

    left_hand = VBoxContainer.new()
    left_hand.alignment = BoxContainer.ALIGNMENT_CENTER
    left_hand.add_theme_constant_override("separation", -36)
    stage.add_child(left_hand)

    right_hand = VBoxContainer.new()
    right_hand.alignment = BoxContainer.ALIGNMENT_CENTER
    right_hand.add_theme_constant_override("separation", -36)
    stage.add_child(right_hand)

    for spec in [
        {"player": "human", "name": "TU", "anchor": Vector2(0.5, 0.90)},
        {"player": "partner", "name": "MARCO  ·  COMPAGNO", "anchor": Vector2(0.5, 0.08)},
        {"player": "left", "name": "SARA", "anchor": Vector2(0.08, 0.48)},
        {"player": "right", "name": "LUCA", "anchor": Vector2(0.92, 0.48)},
    ]:
        var player: String = str(spec["player"])
        var label := Label.new()
        label.text = str(spec["name"])
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 14)
        label.add_theme_color_override("font_color", Color("#e9f0ec"))
        label.set_meta("anchor", spec["anchor"])
        label.set_meta("player", player)
        stage.add_child(label)
        _player_labels[player] = label

        var badge := Label.new()
        badge.text = "DI MANO"
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        badge.add_theme_font_size_override("font_size", 10)
        badge.add_theme_color_override("font_color", Color("#102a23"))
        var badge_style := StyleBoxFlat.new()
        badge_style.bg_color = Color("#d6b45b")
        badge_style.corner_radius_top_left = 8
        badge_style.corner_radius_top_right = 8
        badge_style.corner_radius_bottom_left = 8
        badge_style.corner_radius_bottom_right = 8
        badge_style.content_margin_left = 8
        badge_style.content_margin_right = 8
        badge_style.content_margin_top = 3
        badge_style.content_margin_bottom = 3
        badge.add_theme_stylebox_override("normal", badge_style)
        badge.visible = false
        badge.set_meta("player", player)
        stage.add_child(badge)
        _turn_badges[player] = badge

    trick_layer = Control.new()
    trick_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(trick_layer)

    deck_layer = Control.new()
    deck_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(deck_layer)

    capture_layer = Control.new()
    capture_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(capture_layer)
    _build_capture_piles()

    deal_layer = Control.new()
    deal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deal_layer.z_index = 18
    stage.add_child(deal_layer)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("#f5efe1"))
    stage.add_child(status_label)

    sfx_player = AudioStreamPlayer.new()
    sfx_player.volume_db = -7.0
    add_child(sfx_player)

    _build_start_overlay()
    _build_result_overlay()


func _build_start_overlay() -> void:
    start_overlay = Control.new()
    start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    start_overlay.z_index = 30
    add_child(start_overlay)

    var blocker := ColorRect.new()
    blocker.color = Color(0.005, 0.02, 0.017, 0.82)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    start_overlay.add_child(blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    start_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(490, 470)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.095, 0.075, 0.98)
    style.corner_radius_top_left = 26
    style.corner_radius_top_right = 26
    style.corner_radius_bottom_left = 26
    style.corner_radius_bottom_right = 26
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.84, 0.70, 0.34, 0.28)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 38)
    margin.add_theme_constant_override("margin_right", 38)
    margin.add_theme_constant_override("margin_top", 32)
    margin.add_theme_constant_override("margin_bottom", 32)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 16)
    margin.add_child(column)

    var title := Label.new()
    title.text = "BRISCOLA A 4"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Tu e Marco contro Sara e Luca\nLe coppie siedono una di fronte all'altra."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 15)
    subtitle.add_theme_color_override("font_color", Color("#b8ccc3"))
    column.add_child(subtitle)

    var rule := Label.new()
    rule.text = "4 carte per presa · chi prende apre la successiva\nSi pesca a partire dal vincitore · 120 punti totali"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_font_size_override("font_size", 13)
    rule.add_theme_color_override("font_color", Color("#d7c78d"))
    column.add_child(rule)

    difficulty_option = OptionButton.new()
    difficulty_option.add_item("Facile")
    difficulty_option.add_item("Normale")
    difficulty_option.add_item("Difficile")
    difficulty_option.select(_difficulty_index(difficulty))
    difficulty_option.custom_minimum_size = Vector2(280, 46)
    _style_button(difficulty_option, false)
    column.add_child(difficulty_option)

    continue_button = Button.new()
    continue_button.text = "CONTINUA PARTITA A 4"
    continue_button.custom_minimum_size = Vector2(280, 48)
    _style_button(continue_button, false)
    continue_button.pressed.connect(_resume_game)
    column.add_child(continue_button)

    var new_button := Button.new()
    new_button.text = "NUOVA PARTITA A 4"
    new_button.custom_minimum_size = Vector2(280, 54)
    _style_button(new_button, true)
    new_button.pressed.connect(_new_game)
    column.add_child(new_button)

    var back := Button.new()
    back.text = "Torna alla Briscola classica"
    back.custom_minimum_size = Vector2(280, 42)
    _style_button(back, false)
    back.pressed.connect(_back_to_main)
    column.add_child(back)


func _build_result_overlay() -> void:
    result_overlay = Control.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.z_index = 35
    result_overlay.visible = false
    add_child(result_overlay)

    var blocker := ColorRect.new()
    blocker.color = Color(0.004, 0.015, 0.013, 0.80)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.add_child(blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(430, 330)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.095, 0.075, 0.98)
    style.corner_radius_top_left = 24
    style.corner_radius_top_right = 24
    style.corner_radius_bottom_left = 24
    style.corner_radius_bottom_right = 24
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 34)
    margin.add_theme_constant_override("margin_right", 34)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 16)
    margin.add_child(column)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 34)
    column.add_child(result_title)

    result_detail = Label.new()
    result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_detail.add_theme_font_size_override("font_size", 17)
    result_detail.add_theme_color_override("font_color", Color("#c8d7d0"))
    column.add_child(result_detail)

    var replay := Button.new()
    replay.text = "RIVINCITA"
    replay.custom_minimum_size = Vector2(250, 50)
    _style_button(replay, true)
    replay.pressed.connect(_new_game)
    column.add_child(replay)

    var menu := Button.new()
    menu.text = "Menu modalità 4 giocatori"
    menu.custom_minimum_size = Vector2(250, 44)
    _style_button(menu, false)
    menu.pressed.connect(_show_start_overlay)
    column.add_child(menu)


func _show_start_overlay() -> void:
    result_overlay.visible = false
    start_overlay.visible = true
    continue_button.visible = persistence.has_mode_game(MODE)


func _new_game() -> void:
    difficulty = _difficulty_from_index(difficulty_option.selected)
    persistence.clear_mode_game(MODE)
    engine.new_game("human")
    busy = true
    start_overlay.visible = false
    result_overlay.visible = false
    _trump_revealed = false
    _visible_hand_counts = {"human": 0, "partner": 0, "left": 0, "right": 0}
    _play_sfx(SFX_SHUFFLE)
    _refresh_all()
    await get_tree().process_frame
    await _animate_initial_deal()
    _trump_revealed = true
    await _animate_trump_reveal()
    _visible_hand_counts.clear()
    busy = false
    _refresh_all()
    _save_progress()
    status_label.text = "Tocca a te · apri la prima presa"
    _set_human_interaction(true)


func _resume_game() -> void:
    var payload: Dictionary = persistence.load_mode_game(MODE)
    if payload.is_empty():
        _show_start_overlay()
        return
    var state: Dictionary = payload.get("engine", {})
    if not engine.load_from_dict(state):
        persistence.clear_mode_game(MODE)
        _show_start_overlay()
        return
    difficulty = str(payload.get("difficulty", "normal"))
    difficulty_option.select(_difficulty_index(difficulty))
    start_overlay.visible = false
    result_overlay.visible = false
    busy = false
    _refresh_all()
    if engine.is_game_over():
        _show_result()
    elif engine.current_player == "human":
        status_label.text = "Partita ripristinata · tocca a te"
        _set_human_interaction(true)
    else:
        status_label.text = "Partita ripristinata"
        await _advance_until_human()


func _on_human_card(index: int) -> void:
    if busy or engine.current_player != "human":
        return
    busy = true
    _set_human_interaction(false)
    var source: Vector2 = _hand_card_global_position("human", index)
    var card: Dictionary = engine.play_card("human", index)
    if card.is_empty():
        busy = false
        _set_human_interaction(true)
        return
    _refresh_hands()
    await _animate_card_to_table("human", card, source)
    _play_sfx(SFX_CARD)
    _refresh_table()
    _refresh_header()
    _refresh_turn_indicators()
    _save_progress()
    if engine.table.size() == 4:
        await _finish_trick()
    busy = false
    await _advance_until_human()


func _advance_until_human() -> void:
    if engine.is_game_over():
        _show_result()
        return
    busy = true
    while not engine.is_game_over() and engine.current_player != "human":
        var player: String = engine.current_player
        status_label.text = "%s pensa…" % _player_name(player)
        await get_tree().create_timer(0.42).timeout
        var index: int = engine.choose_bot_card(player, difficulty)
        if index < 0:
            break
        var source: Vector2 = _hand_card_global_position(player, index)
        var card: Dictionary = engine.play_card(player, index)
        if card.is_empty():
            break
        _refresh_hands()
        await _animate_card_to_table(player, card, source)
        _play_sfx(SFX_CARD)
        _refresh_table()
        _refresh_header()
        _refresh_turn_indicators()
        _save_progress()
        if engine.table.size() == 4:
            await _finish_trick()
    busy = false
    if engine.is_game_over():
        _show_result()
    elif engine.current_player == "human":
        status_label.text = "Tocca a te"
        _set_human_interaction(true)


func _finish_trick() -> void:
    var winner_before: String = engine.current_table_winner()
    var winning_team: String = engine.team_for(winner_before)
    var points_before: int = engine.table_points()
    var before_counts: Dictionary = _current_hand_counts()
    _highlight_table_winner(winner_before)
    status_label.text = "%s prende · +%d" % [_player_name(winner_before), points_before]
    await get_tree().create_timer(0.42).timeout
    await _animate_trick_to_team(winning_team)

    var result: Dictionary = engine.resolve_trick()
    if result.is_empty():
        return
    var ours: bool = str(result.get("team", "")) == FourPlayerEngine.TEAM_US
    status_label.text = ("PRENDIAMO NOI" if ours else "PRENDONO LORO") + " · +%d" % int(result.get("points", 0))
    _play_sfx(SFX_TAKE)
    _refresh_capture_piles()
    _refresh_header()
    _pulse_score()
    _refresh_turn_indicators()
    await _animate_draw_sequence(result.get("draws", []), before_counts)
    _visible_hand_counts.clear()
    _refresh_all()
    _save_progress()


func _show_result() -> void:
    persistence.clear_mode_game(MODE)
    _set_human_interaction(false)
    result_overlay.visible = true
    var ours: int = int(engine.scores[FourPlayerEngine.TEAM_US])
    var theirs: int = int(engine.scores[FourPlayerEngine.TEAM_THEM])
    if ours > theirs:
        result_title.text = "ABBIAMO VINTO"
        _play_sfx(SFX_WIN)
    elif theirs > ours:
        result_title.text = "HANNO VINTO LORO"
        _play_sfx(SFX_LOSE)
    else:
        result_title.text = "PAREGGIO"
    result_detail.text = "%d – %d\nPrese: noi %d · loro %d" % [ours, theirs, int(engine.trick_wins[FourPlayerEngine.TEAM_US]), int(engine.trick_wins[FourPlayerEngine.TEAM_THEM])]


func _save_progress() -> void:
    if engine.trump_suit == "" or engine.is_game_over():
        return
    persistence.save_mode_game(MODE, engine.to_dict(), difficulty)


func _refresh_all() -> void:
    _refresh_hands()
    _refresh_table()
    _refresh_deck()
    _refresh_header()
    _refresh_capture_piles()
    _refresh_turn_indicators()


func _refresh_hands() -> void:
    _clear(human_hand)
    var human_cards: Array = engine.hands.get("human", [])
    var human_limit: int = _visible_count_for("human", human_cards.size())
    for i in range(human_limit):
        var card: Dictionary = human_cards[i]
        var view := CardView.new()
        view.setup(card, i, load(engine.card_texture_path(card)), card_size, engine.card_name(card))
        var center_index: float = (float(human_limit) - 1.0) * 0.5
        var fan: float = (float(i) - center_index) * 5.0
        var drop: float = abs(float(i) - center_index) * 4.0
        view.set_fan_pose(fan, drop)
        view.card_selected.connect(_on_human_card)
        human_hand.add_child(view)

    var partner_cards: Array = engine.hands.get("partner", [])
    var left_cards: Array = engine.hands.get("left", [])
    var right_cards: Array = engine.hands.get("right", [])
    _render_back_hand(partner_hand, _visible_count_for("partner", partner_cards.size()), false)
    _render_back_hand(left_hand, _visible_count_for("left", left_cards.size()), true)
    _render_back_hand(right_hand, _visible_count_for("right", right_cards.size()), true)
    _set_human_interaction(not busy and engine.current_player == "human")


func _visible_count_for(player: String, actual: int) -> int:
    if _visible_hand_counts.has(player):
        return clampi(int(_visible_hand_counts[player]), 0, actual)
    return actual


func _render_back_hand(container: BoxContainer, count: int, vertical: bool) -> void:
    _clear(container)
    for _i in range(count):
        var back := TextureRect.new()
        back.texture = load(BACK_TEXTURE)
        back.custom_minimum_size = back_size
        back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        back.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if vertical:
            back.rotation = deg_to_rad(90)
            back.custom_minimum_size = Vector2(back_size.y, back_size.x)
        container.add_child(back)


func _refresh_table() -> void:
    _clear(trick_layer)
    _table_nodes.clear()
    var positions: Dictionary = _trick_positions()
    for value in engine.table:
        var play: Dictionary = value
        var player: String = str(play["player"])
        var card: Dictionary = play["card"]
        var art := TextureRect.new()
        art.texture = load(engine.card_texture_path(card))
        art.custom_minimum_size = table_card_size
        art.size = table_card_size
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art.position = positions[player]
        art.pivot_offset = table_card_size * 0.5
        art.rotation = deg_to_rad(float({"human": -3, "right": 4, "partner": 3, "left": -4}.get(player, 0)))
        trick_layer.add_child(art)
        _table_nodes[player] = art


func _highlight_table_winner(player: String) -> void:
    if not _table_nodes.has(player):
        return
    var node: TextureRect = _table_nodes[player]
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(node, "scale", Vector2(1.12, 1.12), 0.16)
    tween.tween_property(node, "scale", Vector2.ONE, 0.20)


func _refresh_deck() -> void:
    _clear(deck_layer)
    if engine.deck.is_empty():
        return
    var back := TextureRect.new()
    back.texture = load(BACK_TEXTURE)
    back.size = Vector2(66, 106)
    back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    deck_layer.add_child(back)

    if _trump_revealed:
        var trump := TextureRect.new()
        trump.texture = load(engine.card_texture_path(engine.trump_card))
        trump.name = "Trump"
        trump.size = Vector2(62, 100)
        trump.position = Vector2(45, 10)
        trump.rotation = deg_to_rad(90)
        trump.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        trump.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        deck_layer.add_child(trump)

    var count := Label.new()
    count.text = "%d" % engine.deck.size()
    count.position = Vector2(18, 110)
    count.add_theme_color_override("font_color", Color("#f5efe1"))
    deck_layer.add_child(count)


func _refresh_header() -> void:
    score_label.text = "NOI %d  ·  LORO %d" % [int(engine.scores[FourPlayerEngine.TEAM_US]), int(engine.scores[FourPlayerEngine.TEAM_THEM])]
    trick_label.text = "Presa %d/10" % min(engine.trick_number, 10)
    _refresh_turn_indicators()


func _set_human_interaction(enabled: bool) -> void:
    for child in human_hand.get_children():
        if child is CardView:
            (child as CardView).set_interactive(enabled)


func _layout_stage() -> void:
    if stage == null:
        return
    var size := stage.size
    var compact: bool = size.x < 760 or size.y < 560
    card_size = Vector2(78, 126) if compact else Vector2(92, 148)
    back_size = Vector2(52, 84) if compact else Vector2(62, 100)
    table_card_size = Vector2(82, 132) if compact else Vector2(96, 155)

    human_hand.position = Vector2(size.x * 0.5 - 170, size.y - (170 if compact else 205))
    human_hand.size = Vector2(340, 160)
    partner_hand.position = Vector2(size.x * 0.5 - 150, 36)
    partner_hand.size = Vector2(300, 120)
    left_hand.position = Vector2(18, size.y * 0.5 - 120)
    left_hand.size = Vector2(100, 240)
    right_hand.position = Vector2(size.x - 118, size.y * 0.5 - 120)
    right_hand.size = Vector2(100, 240)

    trick_layer.position = Vector2.ZERO
    trick_layer.size = size
    deal_layer.position = Vector2.ZERO
    deal_layer.size = size
    capture_layer.position = Vector2.ZERO
    capture_layer.size = size
    deck_layer.position = Vector2(size.x * 0.18, size.y * 0.52)
    deck_layer.size = Vector2(130, 150)
    status_label.position = Vector2(size.x * 0.5 - 180, size.y * 0.70)
    status_label.size = Vector2(360, 44)

    for child in stage.get_children():
        if child is Label and child.has_meta("anchor"):
            var anchor: Vector2 = child.get_meta("anchor")
            child.position = Vector2(size.x * anchor.x - 85, size.y * anchor.y - 14)
            child.size = Vector2(170, 28)

    for player in _turn_badges.keys():
        var badge: Label = _turn_badges[player]
        var player_label: Label = _player_labels[player]
        badge.position = player_label.position + Vector2(48, 24)
        badge.size = Vector2(74, 22)

    _layout_capture_piles(size)
    _refresh_all()



func _build_capture_piles() -> void:
    our_pile = _make_capture_pile("NOI")
    their_pile = _make_capture_pile("LORO")
    capture_layer.add_child(our_pile)
    capture_layer.add_child(their_pile)
    our_pile_label = our_pile.get_node("Count") as Label
    their_pile_label = their_pile.get_node("Count") as Label


func _make_capture_pile(team_name: String) -> Control:
    var pile := Control.new()
    pile.custom_minimum_size = Vector2(92, 78)
    pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in range(3):
        var card := TextureRect.new()
        card.texture = load(BACK_TEXTURE)
        card.size = Vector2(45, 72)
        card.position = Vector2(float(i) * 3.0, float(i) * -2.0)
        card.rotation = deg_to_rad(float(i - 1) * 4.0)
        card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pile.add_child(card)
    var count := Label.new()
    count.name = "Count"
    count.text = team_name + " · 0 prese"
    count.position = Vector2(-16, 72)
    count.size = Vector2(130, 24)
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.add_theme_font_size_override("font_size", 11)
    count.add_theme_color_override("font_color", Color("#d8e4de"))
    pile.add_child(count)
    return pile


func _layout_capture_piles(size: Vector2) -> void:
    if our_pile == null or their_pile == null:
        return
    our_pile.position = Vector2(size.x * 0.27, size.y * 0.73)
    their_pile.position = Vector2(size.x * 0.68, size.y * 0.17)


func _refresh_capture_piles() -> void:
    if our_pile_label == null or their_pile_label == null:
        return
    var our_wins: int = int(engine.trick_wins[FourPlayerEngine.TEAM_US])
    var their_wins: int = int(engine.trick_wins[FourPlayerEngine.TEAM_THEM])
    our_pile_label.text = "NOI · %d prese" % our_wins
    their_pile_label.text = "LORO · %d prese" % their_wins
    for i in range(3):
        our_pile.get_child(i).visible = our_wins > i
        their_pile.get_child(i).visible = their_wins > i
    our_pile.modulate = Color.WHITE if engine.current_player in ["human", "partner"] else Color(0.82, 0.82, 0.82, 1)
    their_pile.modulate = Color.WHITE if engine.current_player in ["left", "right"] else Color(0.82, 0.82, 0.82, 1)


func _refresh_turn_indicators() -> void:
    var changed: bool = _last_indicated_player != engine.current_player
    for player in _player_labels.keys():
        var label: Label = _player_labels[player]
        var active: bool = str(player) == engine.current_player and not engine.is_game_over()
        label.add_theme_color_override("font_color", Color("#f1d682") if active else Color("#e9f0ec"))
        label.add_theme_font_size_override("font_size", 16 if active else 14)
        if _turn_badges.has(player):
            var badge: Label = _turn_badges[player]
            badge.visible = active
            if active and changed:
                badge.scale = Vector2(0.82, 0.82)
                var pulse := create_tween()
                pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
                pulse.tween_property(badge, "scale", Vector2.ONE, 0.20)
    _last_indicated_player = engine.current_player
    _refresh_capture_piles()



func _pulse_score() -> void:
    if score_label == null:
        return
    score_label.scale = Vector2(1.0, 1.0)
    score_label.pivot_offset = score_label.size * 0.5
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(score_label, "scale", Vector2(1.10, 1.10), 0.11)
    tween.tween_property(score_label, "scale", Vector2.ONE, 0.16)



func _current_hand_counts() -> Dictionary:
    var result: Dictionary = {}
    for player in FourPlayerEngine.PLAYERS:
        var hand: Array = engine.hands.get(player, [])
        result[player] = hand.size()
    return result


func _hand_card_global_position(player: String, index: int = 0) -> Vector2:
    var container: Control = human_hand
    if player == "partner":
        container = partner_hand
    elif player == "left":
        container = left_hand
    elif player == "right":
        container = right_hand
    if player == "human" and index >= 0 and index < container.get_child_count():
        var child := container.get_child(index) as Control
        if child is CardView:
            return (child as CardView).get_visual_global_position() + card_size * 0.5
    if container.get_child_count() > 0:
        var approximate_index: int = clampi(index, 0, container.get_child_count() - 1)
        var child_node := container.get_child(approximate_index) as Control
        return child_node.global_position + child_node.size * 0.5
    return container.global_position + container.size * 0.5


func _deck_global_center() -> Vector2:
    return deck_layer.global_position + Vector2(34, 52)


func _table_global_center_for(player: String) -> Vector2:
    var local: Vector2 = _trick_positions().get(player, Vector2.ZERO)
    return trick_layer.global_position + local + table_card_size * 0.5


func _capture_global_center(team: String) -> Vector2:
    var pile: Control = our_pile if team == FourPlayerEngine.TEAM_US else their_pile
    return pile.global_position + Vector2(28, 34)


func _animate_initial_deal() -> void:
    status_label.text = "Distribuzione…"
    var order: Array = engine.order_from("human")
    for round_index in range(3):
        for player_value in order:
            var player: String = str(player_value)
            var hand: Array = engine.hands[player]
            var card: Dictionary = hand[round_index]
            var target: Vector2 = _hand_target_for_deal(player, round_index)
            await _animate_flying_card(_deck_global_center(), target, card, player == "human", 0.28)
            _visible_hand_counts[player] = int(_visible_hand_counts.get(player, 0)) + 1
            _refresh_hands()
            _play_sfx(SFX_DRAW)
            await get_tree().create_timer(0.055).timeout


func _hand_target_for_deal(player: String, card_index: int) -> Vector2:
    var base: Vector2 = _hand_card_global_position(player, card_index)
    if player == "human":
        var spread: float = float(card_index - 1) * (card_size.x * 0.62)
        return human_hand.global_position + human_hand.size * 0.5 + Vector2(spread, 10)
    if player == "partner":
        var spread_top: float = float(card_index - 1) * (back_size.x * 0.58)
        return partner_hand.global_position + partner_hand.size * 0.5 + Vector2(spread_top, 0)
    var vertical_spread: float = float(card_index - 1) * 36.0
    var side: Control = left_hand if player == "left" else right_hand
    return side.global_position + side.size * 0.5 + Vector2(0, vertical_spread)


func _animate_trump_reveal() -> void:
    status_label.text = "Si scopre la briscola"
    var from: Vector2 = _deck_global_center()
    var target: Vector2 = deck_layer.global_position + Vector2(88, 58)
    await _animate_flying_card(from, target, engine.trump_card, true, 0.34, 90.0)
    _refresh_deck()
    await get_tree().create_timer(0.18).timeout


func _animate_card_to_table(player: String, card: Dictionary, source: Vector2) -> void:
    var target: Vector2 = _table_global_center_for(player)
    await _animate_flying_card(source, target, card, true, 0.30, float({"human": -3, "right": 4, "partner": 3, "left": -4}.get(player, 0)))


func _animate_flying_card(from_global: Vector2, to_global: Vector2, card: Dictionary, face_up: bool, duration: float, rotation_degrees: float = 0.0) -> void:
    var art := TextureRect.new()
    art.texture = load(engine.card_texture_path(card)) if face_up else load(BACK_TEXTURE)
    art.size = table_card_size
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.pivot_offset = table_card_size * 0.5
    art.global_position = from_global - table_card_size * 0.5
    art.scale = Vector2(0.82, 0.82)
    deal_layer.add_child(art)

    var mid: Vector2 = (from_global + to_global) * 0.5 + Vector2(0, -42)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(art, "global_position", mid - table_card_size * 0.5, duration * 0.46)
    tween.parallel().tween_property(art, "scale", Vector2(0.95, 0.95), duration * 0.46)
    tween.tween_property(art, "global_position", to_global - table_card_size * 0.5, duration * 0.54)
    tween.parallel().tween_property(art, "scale", Vector2.ONE, duration * 0.54)
    tween.parallel().tween_property(art, "rotation", deg_to_rad(rotation_degrees), duration * 0.54)
    await tween.finished
    art.queue_free()


func _animate_trick_to_team(team: String) -> void:
    var target: Vector2 = _capture_global_center(team)
    var tweens: Array[Tween] = []
    for player in _table_nodes.keys():
        var node: TextureRect = _table_nodes[player]
        node.z_index = 12
        var tween := create_tween()
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(node, "global_position", target - table_card_size * 0.5, 0.34)
        tween.tween_property(node, "scale", Vector2(0.55, 0.55), 0.34)
        tween.tween_property(node, "rotation", deg_to_rad(float(randi_range(-10, 10))), 0.34)
        tweens.append(tween)
    if not tweens.is_empty():
        await tweens[0].finished


func _animate_draw_sequence(draws: Array, before_counts: Dictionary) -> void:
    if draws.is_empty():
        return
    _visible_hand_counts = before_counts.duplicate(true)
    _refresh_hands()
    for value in draws:
        var draw: Dictionary = value
        var player: String = str(draw.get("player", ""))
        var card: Dictionary = draw.get("card", {})
        if player == "" or card.is_empty():
            continue
        var is_trump: bool = bool(draw.get("is_trump_card", false))
        var source: Vector2 = deck_layer.global_position + (Vector2(88, 58) if is_trump else Vector2(34, 52))
        var target: Vector2 = _hand_target_for_deal(player, int(_visible_hand_counts.get(player, 0)))
        await _animate_flying_card(source, target, card, player == "human" or is_trump, 0.25)
        _visible_hand_counts[player] = int(_visible_hand_counts.get(player, 0)) + 1
        _refresh_hands()
        _play_sfx(SFX_DRAW)
        await get_tree().create_timer(0.045).timeout
    _refresh_deck()



func _trick_positions() -> Dictionary:
    var size := stage.size
    var center := Vector2(size.x * 0.5, size.y * 0.48)
    return {
        "human": center + Vector2(-table_card_size.x * 0.5, 62),
        "partner": center + Vector2(-table_card_size.x * 0.5, -table_card_size.y - 55),
        "left": center + Vector2(-table_card_size.x - 65, -table_card_size.y * 0.5),
        "right": center + Vector2(65, -table_card_size.y * 0.5),
    }



func _maybe_run_web_qa() -> void:
    if not OS.has_feature("web"):
        return
    var mode_value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') || ''", true)
    if str(mode_value) != "4p":
        return
    await _run_web_qa_4p()


func _set_web_qa_status(status: String) -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.__briscolaQaStatus = %s;" % JSON.stringify(status), true)


func _run_web_qa_4p() -> void:
    _set_web_qa_status("4p-starting")
    start_overlay.visible = false
    result_overlay.visible = false
    difficulty = "hard"
    persistence.clear_mode_game(MODE)
    engine.new_game("human")
    busy = true
    _trump_revealed = true
    _visible_hand_counts.clear()
    _refresh_all()
    var safety: int = 0
    while not engine.is_game_over() and safety < 80:
        safety += 1
        var player: String = engine.current_player
        var hand: Array = engine.hands[player]
        if hand.is_empty():
            break
        var index: int = 0 if player == "human" else engine.choose_bot_card(player, "hard")
        if index < 0 or index >= hand.size():
            _set_web_qa_status("4p-failed-ai")
            return
        if engine.play_card(player, index).is_empty():
            _set_web_qa_status("4p-failed-play")
            return
        if engine.table.size() == 4:
            var result: Dictionary = engine.resolve_trick()
            if result.is_empty():
                _set_web_qa_status("4p-failed-resolve")
                return
        await get_tree().process_frame
    busy = false
    _refresh_all()
    var total_score: int = int(engine.scores[FourPlayerEngine.TEAM_US]) + int(engine.scores[FourPlayerEngine.TEAM_THEM])
    if engine.is_game_over() and total_score == 120 and int(engine.trick_wins[FourPlayerEngine.TEAM_US]) + int(engine.trick_wins[FourPlayerEngine.TEAM_THEM]) == 10:
        _set_web_qa_status("4p-complete")
    else:
        _set_web_qa_status("4p-failed-timeout")



func _back_to_main() -> void:
    _save_progress()
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _play_sfx(path: String) -> void:
    if not bool(settings.get("sound_enabled", true)):
        return
    var stream: AudioStream = load(path)
    if stream == null:
        return
    sfx_player.stream = stream
    sfx_player.play()


func _player_name(player: String) -> String:
    return str({"human": "Tu", "partner": "Marco", "left": "Sara", "right": "Luca"}.get(player, player))


func _difficulty_index(value: String) -> int:
    if value == "easy":
        return 0
    if value == "hard":
        return 2
    return 1


func _difficulty_from_index(index: int) -> String:
    if index == 0:
        return "easy"
    if index == 2:
        return "hard"
    return "normal"


func _style_button(button: Button, primary: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#d6b45b") if primary else Color(1, 1, 1, 0.07)
    normal.corner_radius_top_left = 10
    normal.corner_radius_top_right = 10
    normal.corner_radius_bottom_left = 10
    normal.corner_radius_bottom_right = 10
    button.add_theme_stylebox_override("normal", normal)

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#e1c56f") if primary else Color(1, 1, 1, 0.12)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_color_override("font_color", Color("#102a23") if primary else Color("#f5efe1"))
    button.add_theme_color_override("font_hover_color", Color("#102a23") if primary else Color.WHITE)


func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()
