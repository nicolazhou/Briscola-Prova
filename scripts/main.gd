extends Control

const CARD_SIZE := Vector2(108, 174)
const SMALL_CARD_SIZE := Vector2(82, 132)
const TABLE_CARD_SIZE := Vector2(116, 187)
const BACK_TEXTURE := "res://assets/cards/retro.svg"
const TABLE_TEXTURE := "res://assets/ui/table_felt.svg"
const SFX_CARD := "res://assets/audio/card_play.wav"
const SFX_TAKE := "res://assets/audio/card_take.wav"
const SFX_SHUFFLE := "res://assets/audio/shuffle.wav"
const SFX_WIN := "res://assets/audio/win.wav"
const SFX_LOSE := "res://assets/audio/lose.wav"

var engine := BriscolaEngine.new()
var busy := false
var cpu_difficulty := "normal"

var game_screen: Control
var menu_overlay: Control
var difficulty_option: OptionButton
var sound_toggle: CheckButton
var animation_layer: Control
var sfx_player: AudioStreamPlayer

var opponent_hand: HBoxContainer
var player_hand: HBoxContainer
var deck_box: HBoxContainer
var cpu_slot: PanelContainer
var human_slot: PanelContainer
var human_capture_target: Control
var cpu_capture_target: Control

var human_score_label: Label
var cpu_score_label: Label
var deck_label: Label
var trump_label: Label
var turn_label: Label
var status_label: Label
var trick_label: Label
var difficulty_label: Label

var result_overlay: Control
var result_title: Label
var result_score: Label
var result_detail: Label


func _ready() -> void:
    _build_interface()
    _show_menu()


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.is_pressed() or key_event.is_echo():
        return
    if not game_screen.visible or busy or engine.current_player != "human":
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
    var background := TextureRect.new()
    background.texture = load(TABLE_TEXTURE)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.04, 0.035, 0.22)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    game_screen = Control.new()
    game_screen.name = "GameScreen"
    game_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(game_screen)
    _build_game_screen()

    animation_layer = Control.new()
    animation_layer.name = "AnimationLayer"
    animation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    animation_layer.z_index = 40
    add_child(animation_layer)

    sfx_player = AudioStreamPlayer.new()
    sfx_player.volume_db = -7.0
    add_child(sfx_player)

    _build_menu_overlay()
    _build_result_overlay()


func _build_game_screen() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    game_screen.add_child(margin)

    var root_column := VBoxContainer.new()
    root_column.add_theme_constant_override("separation", 10)
    margin.add_child(root_column)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 54
    header.add_theme_constant_override("separation", 14)
    root_column.add_child(header)

    var menu_button := Button.new()
    menu_button.text = "☰  Menu"
    menu_button.custom_minimum_size = Vector2(108, 42)
    _style_button(menu_button, false)
    menu_button.pressed.connect(_on_menu_pressed)
    header.add_child(menu_button)

    var title_block := VBoxContainer.new()
    title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_block.add_theme_constant_override("separation", -2)
    header.add_child(title_block)

    var title := Label.new()
    title.text = "BRISCOLA NAPOLETANA"
    title.add_theme_font_size_override("font_size", 27)
    title_block.add_child(title)

    difficulty_label = Label.new()
    difficulty_label.text = "CPU · Normale"
    difficulty_label.add_theme_font_size_override("font_size", 13)
    difficulty_label.add_theme_color_override("font_color", Color("#c8d7d0"))
    title_block.add_child(difficulty_label)

    trick_label = _badge_label(150)
    trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(trick_label)

    var score_row := HBoxContainer.new()
    score_row.add_theme_constant_override("separation", 8)
    header.add_child(score_row)

    human_capture_target = _score_pill("TU", true)
    score_row.add_child(human_capture_target)
    human_score_label = human_capture_target.find_child("Score", true, false) as Label

    cpu_capture_target = _score_pill("TONY", false)
    score_row.add_child(cpu_capture_target)
    cpu_score_label = cpu_capture_target.find_child("Score", true, false) as Label

    var opponent_zone := VBoxContainer.new()
    opponent_zone.custom_minimum_size.y = 132
    opponent_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    opponent_zone.add_theme_constant_override("separation", 4)
    root_column.add_child(opponent_zone)

    var opponent_name := Label.new()
    opponent_name.text = "TONY · CPU"
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent_name.add_theme_font_size_override("font_size", 15)
    opponent_name.add_theme_color_override("font_color", Color("#d7e4df"))
    opponent_zone.add_child(opponent_name)

    var opponent_center := CenterContainer.new()
    opponent_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    opponent_zone.add_child(opponent_center)

    opponent_hand = HBoxContainer.new()
    opponent_hand.add_theme_constant_override("separation", -42)
    opponent_center.add_child(opponent_hand)

    var table_panel := _panel(Color(0.025, 0.13, 0.10, 0.52), 26, Color(0.88, 0.76, 0.44, 0.18))
    table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_column.add_child(table_panel)

    var table_margin := MarginContainer.new()
    table_margin.add_theme_constant_override("margin_left", 22)
    table_margin.add_theme_constant_override("margin_right", 22)
    table_margin.add_theme_constant_override("margin_top", 14)
    table_margin.add_theme_constant_override("margin_bottom", 14)
    table_panel.add_child(table_margin)

    var table_row := HBoxContainer.new()
    table_row.add_theme_constant_override("separation", 18)
    table_margin.add_child(table_row)

    var deck_panel := _panel(Color(0.02, 0.08, 0.065, 0.46), 18, Color(1, 1, 1, 0.06))
    deck_panel.custom_minimum_size.x = 255
    table_row.add_child(deck_panel)

    var deck_margin := MarginContainer.new()
    deck_margin.add_theme_constant_override("margin_left", 14)
    deck_margin.add_theme_constant_override("margin_right", 14)
    deck_margin.add_theme_constant_override("margin_top", 12)
    deck_margin.add_theme_constant_override("margin_bottom", 12)
    deck_panel.add_child(deck_margin)

    var deck_column := VBoxContainer.new()
    deck_column.alignment = BoxContainer.ALIGNMENT_CENTER
    deck_column.add_theme_constant_override("separation", 7)
    deck_margin.add_child(deck_column)

    var deck_title := Label.new()
    deck_title.text = "MAZZO"
    deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    deck_title.add_theme_font_size_override("font_size", 13)
    deck_title.add_theme_color_override("font_color", Color("#c9d8d2"))
    deck_column.add_child(deck_title)

    deck_box = HBoxContainer.new()
    deck_box.alignment = BoxContainer.ALIGNMENT_CENTER
    deck_box.add_theme_constant_override("separation", 8)
    deck_column.add_child(deck_box)

    trump_label = Label.new()
    trump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    trump_label.add_theme_font_size_override("font_size", 14)
    deck_column.add_child(trump_label)

    deck_label = Label.new()
    deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    deck_label.add_theme_font_size_override("font_size", 12)
    deck_label.add_theme_color_override("font_color", Color("#abc0b7"))
    deck_column.add_child(deck_label)

    var play_zone := VBoxContainer.new()
    play_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    play_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    play_zone.add_theme_constant_override("separation", 8)
    table_row.add_child(play_zone)

    var play_title := Label.new()
    play_title.text = "PRESA IN CORSO"
    play_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    play_title.add_theme_font_size_override("font_size", 13)
    play_title.add_theme_color_override("font_color", Color("#bdd0c8"))
    play_zone.add_child(play_title)

    var trick_row := HBoxContainer.new()
    trick_row.alignment = BoxContainer.ALIGNMENT_CENTER
    trick_row.add_theme_constant_override("separation", 30)
    play_zone.add_child(trick_row)

    var cpu_column := VBoxContainer.new()
    cpu_column.add_theme_constant_override("separation", 4)
    trick_row.add_child(cpu_column)
    var cpu_name := Label.new()
    cpu_name.text = "Tony"
    cpu_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cpu_name.add_theme_font_size_override("font_size", 13)
    cpu_column.add_child(cpu_name)
    cpu_slot = _card_slot()
    cpu_column.add_child(cpu_slot)

    var center_mark := Label.new()
    center_mark.text = "✦"
    center_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    center_mark.add_theme_font_size_override("font_size", 24)
    center_mark.add_theme_color_override("font_color", Color(0.86, 0.76, 0.48, 0.55))
    trick_row.add_child(center_mark)

    var human_column := VBoxContainer.new()
    human_column.add_theme_constant_override("separation", 4)
    trick_row.add_child(human_column)
    var human_name := Label.new()
    human_name.text = "Tu"
    human_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    human_name.add_theme_font_size_override("font_size", 13)
    human_column.add_child(human_name)
    human_slot = _card_slot()
    human_column.add_child(human_slot)

    var info_panel := _panel(Color(0.02, 0.08, 0.065, 0.46), 18, Color(1, 1, 1, 0.06))
    info_panel.custom_minimum_size.x = 245
    table_row.add_child(info_panel)

    var info_margin := MarginContainer.new()
    info_margin.add_theme_constant_override("margin_left", 16)
    info_margin.add_theme_constant_override("margin_right", 16)
    info_margin.add_theme_constant_override("margin_top", 14)
    info_margin.add_theme_constant_override("margin_bottom", 14)
    info_panel.add_child(info_margin)

    var info_column := VBoxContainer.new()
    info_column.alignment = BoxContainer.ALIGNMENT_CENTER
    info_column.add_theme_constant_override("separation", 12)
    info_margin.add_child(info_column)

    var info_title := Label.new()
    info_title.text = "TURNO"
    info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_title.add_theme_font_size_override("font_size", 13)
    info_title.add_theme_color_override("font_color", Color("#b9cbc4"))
    info_column.add_child(info_title)

    turn_label = Label.new()
    turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn_label.add_theme_font_size_override("font_size", 23)
    turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_column.add_child(turn_label)

    var hint := Label.new()
    hint.text = "Asso 11 · Tre 10\nRe 4 · Cavallo 3 · Fante 2"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color("#9db4aa"))
    info_column.add_child(hint)

    var player_zone := VBoxContainer.new()
    player_zone.custom_minimum_size.y = 194
    player_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    player_zone.add_theme_constant_override("separation", 5)
    root_column.add_child(player_zone)

    var player_center := CenterContainer.new()
    player_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    player_zone.add_child(player_center)

    player_hand = HBoxContainer.new()
    player_hand.add_theme_constant_override("separation", 12)
    player_center.add_child(player_hand)

    var player_caption := Label.new()
    player_caption.text = "LA TUA MANO  ·  clicca una carta oppure usa 1 / 2 / 3"
    player_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_caption.add_theme_font_size_override("font_size", 13)
    player_caption.add_theme_color_override("font_color", Color("#c7d8d0"))
    player_zone.add_child(player_caption)

    var footer := _panel(Color(0.015, 0.055, 0.045, 0.56), 14, Color(1, 1, 1, 0.05))
    footer.custom_minimum_size.y = 50
    root_column.add_child(footer)

    var footer_margin := MarginContainer.new()
    footer_margin.add_theme_constant_override("margin_left", 16)
    footer_margin.add_theme_constant_override("margin_right", 10)
    footer.add_child(footer_margin)

    var footer_row := HBoxContainer.new()
    footer_row.add_theme_constant_override("separation", 10)
    footer_margin.add_child(footer_row)

    status_label = Label.new()
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 15)
    status_label.add_theme_color_override("font_color", Color("#e8f2ee"))
    footer_row.add_child(status_label)

    var restart_button := Button.new()
    restart_button.text = "Ricomincia"
    restart_button.custom_minimum_size = Vector2(128, 38)
    _style_button(restart_button, false)
    restart_button.pressed.connect(_on_restart_pressed)
    footer_row.add_child(restart_button)


func _build_menu_overlay() -> void:
    menu_overlay = Control.new()
    menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_overlay.z_index = 60
    add_child(menu_overlay)

    var blocker := ColorRect.new()
    blocker.color = Color(0.005, 0.02, 0.017, 0.72)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    menu_overlay.add_child(blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_overlay.add_child(center)

    var panel := _panel(Color(0.025, 0.095, 0.075, 0.98), 28, Color(0.86, 0.73, 0.38, 0.28))
    panel.custom_minimum_size = Vector2(520, 520)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 42)
    margin.add_theme_constant_override("margin_right", 42)
    margin.add_theme_constant_override("margin_top", 36)
    margin.add_theme_constant_override("margin_bottom", 34)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 15)
    margin.add_child(column)

    var eyebrow := Label.new()
    eyebrow.text = "CLASSICO ITALIANO"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 13)
    eyebrow.add_theme_color_override("font_color", Color("#d5bf7a"))
    column.add_child(eyebrow)

    var title := Label.new()
    title.text = "BRISCOLA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 48)
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Una partita veloce contro Tony"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", Color("#b8ccc3"))
    column.add_child(subtitle)

    var separator := HSeparator.new()
    separator.modulate = Color(1, 1, 1, 0.12)
    column.add_child(separator)

    var diff_title := Label.new()
    diff_title.text = "Difficoltà CPU"
    diff_title.add_theme_font_size_override("font_size", 14)
    column.add_child(diff_title)

    difficulty_option = OptionButton.new()
    difficulty_option.custom_minimum_size = Vector2(290, 46)
    difficulty_option.add_item("Facile")
    difficulty_option.add_item("Normale")
    difficulty_option.add_item("Difficile")
    difficulty_option.select(1)
    _style_button(difficulty_option, false)
    column.add_child(difficulty_option)

    sound_toggle = CheckButton.new()
    sound_toggle.text = "Effetti sonori"
    sound_toggle.button_pressed = true
    sound_toggle.custom_minimum_size = Vector2(290, 40)
    column.add_child(sound_toggle)

    var play_button := Button.new()
    play_button.text = "GIOCA"
    play_button.custom_minimum_size = Vector2(290, 56)
    play_button.add_theme_font_size_override("font_size", 18)
    _style_button(play_button, true)
    play_button.pressed.connect(_start_selected_game)
    column.add_child(play_button)

    var rules := Label.new()
    rules.text = "Prendi con la carta più forte del seme giocato,\no con una briscola. Vince chi supera 60 punti."
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rules.add_theme_font_size_override("font_size", 13)
    rules.add_theme_color_override("font_color", Color("#a8bdb4"))
    column.add_child(rules)

    var note := Label.new()
    note.text = "Mazzo napoletano · 40 carte · 20 prese"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", Color("#819b90"))
    column.add_child(note)


func _build_result_overlay() -> void:
    result_overlay = Control.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.visible = false
    result_overlay.z_index = 70
    add_child(result_overlay)

    var blocker := ColorRect.new()
    blocker.color = Color(0.005, 0.02, 0.017, 0.74)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    result_overlay.add_child(blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.add_child(center)

    var panel := _panel(Color(0.025, 0.095, 0.075, 0.99), 28, Color(0.86, 0.73, 0.38, 0.3))
    panel.custom_minimum_size = Vector2(500, 350)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 42)
    margin.add_theme_constant_override("margin_right", 42)
    margin.add_theme_constant_override("margin_top", 34)
    margin.add_theme_constant_override("margin_bottom", 32)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)

    var eyebrow := Label.new()
    eyebrow.text = "PARTITA CONCLUSA"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 13)
    eyebrow.add_theme_color_override("font_color", Color("#d5bf7a"))
    column.add_child(eyebrow)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 34)
    column.add_child(result_title)

    result_score = Label.new()
    result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_score.add_theme_font_size_override("font_size", 25)
    column.add_child(result_score)

    result_detail = Label.new()
    result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_detail.add_theme_font_size_override("font_size", 13)
    result_detail.add_theme_color_override("font_color", Color("#a9beb5"))
    column.add_child(result_detail)

    var replay := Button.new()
    replay.text = "RIVINCITA"
    replay.custom_minimum_size = Vector2(250, 50)
    _style_button(replay, true)
    replay.pressed.connect(_new_game)
    column.add_child(replay)

    var menu := Button.new()
    menu.text = "Torna al menu"
    menu.custom_minimum_size = Vector2(250, 44)
    _style_button(menu, false)
    menu.pressed.connect(_show_menu)
    column.add_child(menu)


func _on_menu_pressed() -> void:
    if busy:
        _set_status("Completo prima l'animazione in corso...")
        return
    _show_menu()


func _on_restart_pressed() -> void:
    if busy:
        _set_status("Completo prima l'animazione in corso...")
        return
    _new_game()


func _show_menu() -> void:
    busy = false
    result_overlay.visible = false
    game_screen.visible = false
    menu_overlay.visible = true
    _clear_animation_layer()


func _start_selected_game() -> void:
    if difficulty_option.selected == 0:
        cpu_difficulty = "easy"
    elif difficulty_option.selected == 2:
        cpu_difficulty = "hard"
    else:
        cpu_difficulty = "normal"
    _new_game()


func _new_game() -> void:
    busy = true
    menu_overlay.visible = false
    result_overlay.visible = false
    game_screen.visible = true
    _clear_animation_layer()
    engine.new_game()
    _play_sfx(SFX_SHUFFLE)
    _clear_container(player_hand)
    _clear_container(opponent_hand)
    _refresh_table()
    _refresh_deck()
    _refresh_header()
    difficulty_label.text = "CPU · %s" % _difficulty_display_name()
    _set_status("Distribuzione delle carte...")
    await get_tree().process_frame
    await _animate_initial_deal()
    _refresh_hands()
    _refresh_deck()
    _refresh_header()
    busy = false
    _set_status("Tocca a te. Scegli una carta.")


func _animate_initial_deal() -> void:
    for _round in range(3):
        await _animate_draw_to("human", 0.13)
        await _animate_draw_to("cpu", 0.13)


func _on_player_card_pressed(index: int) -> void:
    if busy or engine.current_player != "human":
        return
    if index < 0 or index >= player_hand.get_child_count():
        return

    busy = true
    _set_hand_interaction(false)

    var source := player_hand.get_child(index) as Control
    var start_position := source.global_position
    var start_size := source.size
    source.visible = false

    var card: Dictionary = engine.play_card("human", index)
    if card.is_empty():
        source.visible = true
        busy = false
        _set_hand_interaction(true)
        return

    _set_status("Giochi %s." % engine.card_name(card))
    _play_sfx(SFX_CARD)
    await _animate_card_to_slot(engine.card_texture_path(card), start_position, start_size, human_slot, false)
    _refresh_player_hand()
    _refresh_table()
    _refresh_header()

    if engine.table.size() == 2:
        await _finish_trick()
    else:
        await _cpu_turn()


func _cpu_turn() -> void:
    if engine.current_player != "cpu" or engine.hands["cpu"].is_empty():
        busy = false
        _refresh_header()
        _set_hand_interaction(true)
        return

    busy = true
    _set_hand_interaction(false)
    _set_status("Tony sta pensando...")
    await get_tree().create_timer(0.48).timeout

    var index: int = engine.choose_cpu_card(cpu_difficulty)
    if index < 0:
        busy = false
        return

    var start_position := _control_center_position(opponent_hand, SMALL_CARD_SIZE)
    var start_size := SMALL_CARD_SIZE
    if index < opponent_hand.get_child_count():
        var source := opponent_hand.get_child(index) as Control
        start_position = source.global_position
        start_size = source.size
        source.visible = false

    var card: Dictionary = engine.play_card("cpu", index)
    if card.is_empty():
        busy = false
        _refresh_hands()
        return

    await _animate_card_to_slot(engine.card_texture_path(card), start_position, start_size, cpu_slot, true)
    _play_sfx(SFX_CARD)
    _refresh_opponent_hand()
    _refresh_table()
    _refresh_header()
    _set_status("Tony gioca %s." % engine.card_name(card))
    await get_tree().create_timer(0.30).timeout

    if engine.table.size() == 2:
        await _finish_trick()
    else:
        busy = false
        _refresh_header()
        _set_hand_interaction(true)
        _set_status("Tocca a te.")


func _finish_trick() -> void:
    await get_tree().create_timer(0.52).timeout

    var played: Array = engine.table.duplicate(true)
    var deck_before: int = engine.deck.size()
    var result: Dictionary = engine.resolve_trick()
    if result.is_empty():
        busy = false
        return

    var winner: String = str(result["winner"])
    var winner_name: String = "Tu" if winner == "human" else "Tony"
    _set_status("%s prende la mano · +%d punti" % [winner_name, int(result["points"])])
    await _animate_trick_collection(played, winner)
    _play_sfx(SFX_TAKE)
    _refresh_header()

    if deck_before > 0:
        await _animate_draw_to(winner, 0.22)
        await _animate_draw_to(str(result["loser"]), 0.22)

    _refresh_hands()
    _refresh_deck()
    _refresh_table()
    _refresh_header()

    if engine.is_game_over():
        busy = false
        await get_tree().create_timer(0.35).timeout
        _show_result()
        return

    if engine.current_player == "cpu":
        await get_tree().create_timer(0.22).timeout
        await _cpu_turn()
    else:
        busy = false
        _set_hand_interaction(true)
        _set_status("Hai preso la mano: inizi tu.")


func _show_result() -> void:
    result_score.text = "%d  —  %d" % [int(engine.scores["human"]), int(engine.scores["cpu"])]
    if engine.scores["human"] > engine.scores["cpu"]:
        result_title.text = "Hai vinto!"
        _play_sfx(SFX_WIN)
    elif engine.scores["human"] < engine.scores["cpu"]:
        result_title.text = "Tony ha vinto"
        _play_sfx(SFX_LOSE)
    else:
        result_title.text = "Pareggio"
    result_detail.text = "20 prese · difficoltà %s" % _difficulty_display_name().to_lower()
    result_overlay.visible = true
    _set_status("Partita conclusa.")


func _refresh_header() -> void:
    human_score_label.text = str(int(engine.scores["human"]))
    cpu_score_label.text = str(int(engine.scores["cpu"]))
    trick_label.text = "Presa %d / 20" % min(engine.trick_number, 20)
    if engine.trump_suit != "":
        trump_label.text = "Briscola · %s" % BriscolaEngine.SUIT_NAMES[engine.trump_suit]
    else:
        trump_label.text = "Briscola"
    deck_label.text = "%d carte da pescare" % engine.deck.size()
    turn_label.text = "Tocca a te" if engine.current_player == "human" else "Tony gioca"


func _refresh_hands() -> void:
    _refresh_opponent_hand()
    _refresh_player_hand()


func _refresh_opponent_hand() -> void:
    _clear_container(opponent_hand)
    for _card in engine.hands["cpu"]:
        opponent_hand.add_child(_texture_card(BACK_TEXTURE, SMALL_CARD_SIZE))


func _refresh_player_hand() -> void:
    _clear_container(player_hand)
    for i in range(engine.hands["human"].size()):
        var card: Dictionary = engine.hands["human"][i]
        var view := CardView.new()
        view.setup(card, i, load(engine.card_texture_path(card)), CARD_SIZE, "%s · %d punti" % [engine.card_name(card), engine.points_for(card)])
        view.pressed.connect(_on_player_card_pressed.bind(i))
        view.set_interactive(not busy and engine.current_player == "human")
        player_hand.add_child(view)


func _refresh_deck() -> void:
    _clear_container(deck_box)

    if engine.deck.size() > 1:
        deck_box.add_child(_texture_card(BACK_TEXTURE, SMALL_CARD_SIZE))
    else:
        var empty_back := Control.new()
        empty_back.custom_minimum_size = SMALL_CARD_SIZE
        deck_box.add_child(empty_back)

    if engine.deck.size() > 0:
        var trump_view := _texture_card(engine.card_texture_path(engine.trump_card), SMALL_CARD_SIZE)
        trump_view.rotation = deg_to_rad(8.0)
        trump_view.pivot_offset = SMALL_CARD_SIZE * 0.5
        deck_box.add_child(trump_view)
    else:
        var empty_trump := Control.new()
        empty_trump.custom_minimum_size = SMALL_CARD_SIZE
        deck_box.add_child(empty_trump)


func _refresh_table() -> void:
    _clear_container(cpu_slot)
    _clear_container(human_slot)

    for value in engine.table:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        var view := _texture_card(engine.card_texture_path(card), TABLE_CARD_SIZE)
        view.tooltip_text = engine.card_name(card)
        if str(play["player"]) == "cpu":
            cpu_slot.add_child(view)
        else:
            human_slot.add_child(view)


func _set_hand_interaction(enabled: bool) -> void:
    for child in player_hand.get_children():
        if child is CardView:
            var card_view := child as CardView
            card_view.set_interactive(enabled and engine.current_player == "human")


func _animate_card_to_slot(path: String, start_position: Vector2, start_size: Vector2, slot: Control, reveal_after_move: bool) -> void:
    var initial_texture: String = BACK_TEXTURE if reveal_after_move else path
    var floating := _floating_card(initial_texture, start_size, start_position)
    var target_position := slot.global_position + (slot.size - TABLE_CARD_SIZE) * 0.5

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.set_parallel(true)
    tween.tween_property(floating, "position", target_position, 0.30)
    tween.tween_property(floating, "size", TABLE_CARD_SIZE, 0.30)
    tween.tween_property(floating, "rotation", deg_to_rad(2.0 if reveal_after_move else -2.0), 0.30)
    await tween.finished

    if reveal_after_move:
        floating.texture = load(path)
        floating.pivot_offset = floating.size * 0.5
        floating.scale = Vector2(0.08, 1.0)
        var flip := create_tween()
        flip.set_trans(Tween.TRANS_QUAD)
        flip.set_ease(Tween.EASE_OUT)
        flip.tween_property(floating, "scale", Vector2.ONE, 0.14)
        await flip.finished

    floating.queue_free()


func _animate_trick_collection(played: Array, winner: String) -> void:
    var target_control: Control = human_capture_target if winner == "human" else cpu_capture_target
    var target := target_control.global_position + target_control.size * 0.5
    var floaters: Array = []

    for value in played:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        var slot: Control = human_slot if str(play["player"]) == "human" else cpu_slot
        var start := slot.global_position + (slot.size - TABLE_CARD_SIZE) * 0.5
        floaters.append(_floating_card(engine.card_texture_path(card), TABLE_CARD_SIZE, start))

    _clear_container(cpu_slot)
    _clear_container(human_slot)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN_OUT)
    for i in range(floaters.size()):
        var floating := floaters[i] as TextureRect
        var offset := Vector2(12.0 * i, 5.0 * i)
        tween.tween_property(floating, "position", target - TABLE_CARD_SIZE * 0.28 + offset, 0.38)
        tween.tween_property(floating, "scale", Vector2(0.54, 0.54), 0.38)
        tween.tween_property(floating, "modulate:a", 0.15, 0.38)
    await tween.finished

    for value in floaters:
        var floating := value as TextureRect
        floating.queue_free()


func _animate_draw_to(player: String, duration: float) -> void:
    var source := _deck_source_position()
    var target_container: Control = player_hand if player == "human" else opponent_hand
    var target_size: Vector2 = CARD_SIZE if player == "human" else SMALL_CARD_SIZE
    var target := _control_center_position(target_container, target_size)
    var floating := _floating_card(BACK_TEXTURE, SMALL_CARD_SIZE, source)
    floating.rotation = deg_to_rad(-5.0 if player == "human" else 5.0)

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.set_parallel(true)
    tween.tween_property(floating, "position", target, duration)
    tween.tween_property(floating, "size", target_size, duration)
    tween.tween_property(floating, "rotation", 0.0, duration)
    await tween.finished
    floating.queue_free()


func _floating_card(path: String, card_size: Vector2, position_value: Vector2) -> TextureRect:
    var floating := TextureRect.new()
    floating.texture = load(path)
    floating.position = position_value
    floating.size = card_size
    floating.pivot_offset = card_size * 0.5
    floating.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    floating.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
    animation_layer.add_child(floating)
    return floating


func _deck_source_position() -> Vector2:
    if deck_box != null and deck_box.get_child_count() > 0:
        var first := deck_box.get_child(0) as Control
        return first.global_position
    return deck_box.global_position


func _control_center_position(control: Control, card_size: Vector2) -> Vector2:
    return control.global_position + (control.size - card_size) * 0.5


func _texture_card(path: String, minimum_size: Vector2) -> TextureRect:
    var texture_rect := TextureRect.new()
    texture_rect.texture = load(path)
    texture_rect.custom_minimum_size = minimum_size
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return texture_rect


func _card_slot() -> PanelContainer:
    var slot := _panel(Color(0.015, 0.07, 0.055, 0.28), 18, Color(0.86, 0.75, 0.45, 0.14))
    slot.custom_minimum_size = TABLE_CARD_SIZE + Vector2(20, 20)
    return slot


func _score_pill(player_name: String, human: bool) -> PanelContainer:
    var panel := _panel(Color(0.015, 0.065, 0.052, 0.74), 14, Color(1, 1, 1, 0.08))
    panel.custom_minimum_size = Vector2(112, 44)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 11)
    margin.add_theme_constant_override("margin_right", 11)
    panel.add_child(margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    margin.add_child(row)

    var name_label := Label.new()
    name_label.text = player_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.add_theme_color_override("font_color", Color("#afc2b9") if human else Color("#c7b7ad"))
    row.add_child(name_label)

    var score := Label.new()
    score.name = "Score"
    score.text = "0"
    score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    score.add_theme_font_size_override("font_size", 20)
    row.add_child(score)
    return panel


func _badge_label(min_width: int) -> Label:
    var label := Label.new()
    label.custom_minimum_size = Vector2(min_width, 38)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("#d9e5df"))
    return label


func _panel(color: Color, radius: int, border_color: Color = Color(1, 1, 1, 0.06)) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.border_color = border_color
    style.set_border_width_all(1)
    style.shadow_color = Color(0, 0, 0, 0.18)
    style.shadow_size = 8
    panel.add_theme_stylebox_override("panel", style)
    return panel


func _play_sfx(path: String) -> void:
    if sfx_player == null:
        return
    if sound_toggle != null and not sound_toggle.button_pressed:
        return
    sfx_player.stream = load(path)
    sfx_player.play()


func _style_button(button: Button, primary: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#d3b45f") if primary else Color(0.03, 0.11, 0.09, 0.92)
    normal.border_color = Color("#e3ca7d") if primary else Color(1, 1, 1, 0.11)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 16
    normal.content_margin_right = 16
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#e0c36b") if primary else Color(0.05, 0.16, 0.125, 0.98)
    hover.border_color = Color("#f0d990") if primary else Color(1, 1, 1, 0.2)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#b99a49") if primary else Color(0.02, 0.08, 0.065, 1.0)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_color_override("font_color", Color("#11251e") if primary else Color("#e6f0eb"))
    button.add_theme_color_override("font_hover_color", Color("#11251e") if primary else Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#11251e") if primary else Color("#dbe8e2"))
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _clear_container(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _clear_animation_layer() -> void:
    if animation_layer == null:
        return
    _clear_container(animation_layer)


func _set_status(text: String) -> void:
    status_label.text = text


func _difficulty_display_name() -> String:
    if cpu_difficulty == "easy":
        return "Facile"
    if cpu_difficulty == "hard":
        return "Difficile"
    return "Normale"
