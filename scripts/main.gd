extends Control

const BASE_CARD_SIZE := Vector2(108, 174)
const BASE_SMALL_CARD_SIZE := Vector2(82, 132)
const BASE_TABLE_CARD_SIZE := Vector2(116, 187)
const COMPACT_CARD_SIZE := Vector2(150, 242)
const COMPACT_SMALL_CARD_SIZE := Vector2(88, 142)
const COMPACT_TABLE_CARD_SIZE := Vector2(130, 210)
const MOBILE_LANDSCAPE_CARD_SIZE := Vector2(116, 187)
const MOBILE_LANDSCAPE_SMALL_CARD_SIZE := Vector2(72, 116)
const MOBILE_LANDSCAPE_TABLE_CARD_SIZE := Vector2(105, 169)
const BACK_TEXTURE := "res://assets/cards/retro.svg"
const TABLE_TEXTURE := "res://assets/ui/table_felt.svg"
const SFX_CARD := "res://assets/audio/card_play.wav"
const SFX_TAKE := "res://assets/audio/card_take.wav"
const SFX_SHUFFLE := "res://assets/audio/shuffle.wav"
const SFX_WIN := "res://assets/audio/win.wav"
const SFX_LOSE := "res://assets/audio/lose.wav"

const TUTORIAL_STEPS: Array[Dictionary] = [
    {
        "title": "1 · Obiettivo",
        "body": "Fai più punti di Tony. Nel mazzo ci sono 120 punti totali: con 61 o più vinci, 60 a 60 è pareggio.",
    },
    {
        "title": "2 · Come si prende",
        "body": "Se giochi lo stesso seme, vince la carta più forte. Se i semi sono diversi, prende chi ha giocato per primo, salvo che entri una briscola.",
    },
    {
        "title": "3 · Valore delle carte",
        "body": "Asso 11 · Tre 10 · Re 4 · Cavallo 3 · Fante 2. Le altre carte valgono 0 punti, ma possono comunque vincere una presa.",
    },
    {
        "title": "4 · Ritmo della partita",
        "body": "Chi prende gioca per primo nella presa successiva. Dopo ogni presa si pesca; la briscola scoperta è l’ultima carta del mazzo.",
    },
]

var engine := BriscolaEngine.new()
var persistence := GamePersistence.new()
var settings: Dictionary = {}
var busy := false
var cpu_difficulty := "normal"
var result_recorded := false
var compact_layout := false
var card_size := BASE_CARD_SIZE
var small_card_size := BASE_SMALL_CARD_SIZE
var table_card_size := BASE_TABLE_CARD_SIZE
var _last_leader := ""
var _assets_warmed := false
var tutorial_step := 0
var _start_game_after_tutorial := false

var game_screen: Control
var game_margin: MarginContainer
var root_column: VBoxContainer
var header: HBoxContainer
var menu_button: Button
var title_block: VBoxContainer
var score_row: HBoxContainer
var opponent_zone: VBoxContainer
var opponent_name_label: Label
var table_panel: PanelContainer
var table_margin: MarginContainer
var table_row: HBoxContainer
var deck_panel: PanelContainer
var play_zone: VBoxContainer
var trick_surface: Control
var trick_outcome_label: Label
var info_panel: PanelContainer
var player_zone: VBoxContainer
var player_caption: Label
var footer: PanelContainer
var footer_row: HBoxContainer
var restart_button: Button
var help_button: Button
var restart_dialog: ConfirmationDialog

var menu_overlay: Control
var menu_panel: PanelContainer
var menu_margin: MarginContainer
var difficulty_option: OptionButton
var sound_toggle: CheckButton
var reduced_motion_toggle: CheckButton
var continue_button: Button
var pwa_update_button: Button
var stats_label: Label
var tutorial_overlay: Control
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_body: Label
var tutorial_progress: Label
var tutorial_back_button: Button
var tutorial_next_button: Button
var animation_layer: Control
var sfx_player: AudioStreamPlayer

var opponent_hand: HBoxContainer
var player_hand: HBoxContainer
var deck_box: HBoxContainer
var cpu_slot: Control
var human_slot: Control
var cpu_taken_pile: Control
var human_taken_pile: Control
var table_deck_anchor: Control
var table_turn_label: Label
var table_phase_label: Label
var cpu_lead_badge: Label
var human_lead_badge: Label
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
var result_panel: PanelContainer
var result_title: Label
var result_score: Label
var result_detail: Label
var result_feedback_label: Label
var result_feedback_row: HBoxContainer
var result_feedback_status: Label


func _ready() -> void:
    settings = persistence.load_settings()
    cpu_difficulty = str(settings.get("difficulty", "normal"))
    _warm_runtime_assets()
    _build_interface()
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    _apply_responsive_layout()
    _show_menu()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.__briscolaAppReady = true;", true)
        var pwa_timer := Timer.new()
        pwa_timer.wait_time = 2.0
        pwa_timer.autostart = true
        pwa_timer.timeout.connect(_refresh_pwa_update_button)
        add_child(pwa_timer)
        call_deferred("_refresh_pwa_update_button")
        call_deferred("_maybe_run_web_qa")


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
        if engine.trump_suit != "" and not engine.is_game_over():
            _save_progress()


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
    _build_tutorial_overlay()
    _build_restart_dialog()


func _build_game_screen() -> void:
    game_margin = MarginContainer.new()
    var margin := game_margin
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    game_screen.add_child(margin)

    root_column = VBoxContainer.new()
    root_column.add_theme_constant_override("separation", 10)
    margin.add_child(root_column)

    header = HBoxContainer.new()
    header.custom_minimum_size.y = 54
    header.add_theme_constant_override("separation", 14)
    root_column.add_child(header)

    menu_button = Button.new()
    menu_button.text = "☰  Menu"
    menu_button.custom_minimum_size = Vector2(108, 42)
    _style_button(menu_button, false)
    menu_button.pressed.connect(_on_menu_pressed)
    header.add_child(menu_button)

    help_button = Button.new()
    help_button.text = "?"
    help_button.tooltip_text = "Come si gioca"
    help_button.custom_minimum_size = Vector2(44, 42)
    _style_button(help_button, false)
    help_button.pressed.connect(_show_tutorial.bind(false))
    header.add_child(help_button)

    title_block = VBoxContainer.new()
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

    score_row = HBoxContainer.new()
    score_row.add_theme_constant_override("separation", 8)
    header.add_child(score_row)

    human_capture_target = _score_pill("TU", true)
    score_row.add_child(human_capture_target)
    human_score_label = human_capture_target.find_child("Score", true, false) as Label

    cpu_capture_target = _score_pill("TONY", false)
    score_row.add_child(cpu_capture_target)
    cpu_score_label = cpu_capture_target.find_child("Score", true, false) as Label

    opponent_zone = VBoxContainer.new()
    opponent_zone.custom_minimum_size.y = 132
    opponent_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    opponent_zone.add_theme_constant_override("separation", 4)
    root_column.add_child(opponent_zone)

    opponent_name_label = Label.new()
    opponent_name_label.text = "TONY · CPU"
    opponent_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent_name_label.add_theme_font_size_override("font_size", 15)
    opponent_name_label.add_theme_color_override("font_color", Color("#d7e4df"))
    opponent_zone.add_child(opponent_name_label)

    var opponent_center := CenterContainer.new()
    opponent_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    opponent_zone.add_child(opponent_center)

    opponent_hand = HBoxContainer.new()
    opponent_hand.add_theme_constant_override("separation", -42)
    opponent_center.add_child(opponent_hand)

    table_panel = _panel(Color(0.025, 0.13, 0.10, 0.52), 26, Color(0.88, 0.76, 0.44, 0.18))
    table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_column.add_child(table_panel)

    table_margin = MarginContainer.new()
    table_margin.add_theme_constant_override("margin_left", 22)
    table_margin.add_theme_constant_override("margin_right", 22)
    table_margin.add_theme_constant_override("margin_top", 14)
    table_margin.add_theme_constant_override("margin_bottom", 14)
    table_panel.add_child(table_margin)

    table_row = HBoxContainer.new()
    table_row.add_theme_constant_override("separation", 18)
    table_margin.add_child(table_row)

    # I dati del mazzo non vivono più in un pannello laterale: il mazzo e la
    # briscola vengono appoggiati direttamente sul feltro, come in una partita reale.
    deck_panel = PanelContainer.new()
    deck_panel.visible = false
    table_row.add_child(deck_panel)

    play_zone = VBoxContainer.new()
    play_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    play_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
    play_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    table_row.add_child(play_zone)

    # Area di gioco volutamente "nuda": nessun riquadro o slot visibile.
    # Le due carte vengono appoggiate e leggermente sovrapposte sul feltro.
    trick_surface = Control.new()
    trick_surface.custom_minimum_size = Vector2(380, 250)
    trick_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trick_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
    trick_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    play_zone.add_child(trick_surface)
    trick_surface.resized.connect(_layout_trick_slots)

    table_deck_anchor = Control.new()
    table_deck_anchor.name = "TableDeck"
    table_deck_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table_deck_anchor.z_index = 2
    trick_surface.add_child(table_deck_anchor)

    deck_box = HBoxContainer.new()
    deck_box.alignment = BoxContainer.ALIGNMENT_CENTER
    deck_box.add_theme_constant_override("separation", -34)
    deck_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table_deck_anchor.add_child(deck_box)

    table_phase_label = Label.new()
    table_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    table_phase_label.add_theme_font_size_override("font_size", 12)
    table_phase_label.add_theme_color_override("font_color", Color("#d8c98e"))
    table_phase_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.9))
    table_phase_label.add_theme_constant_override("outline_size", 4)
    table_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table_deck_anchor.add_child(table_phase_label)

    table_turn_label = Label.new()
    table_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    table_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    table_turn_label.add_theme_font_size_override("font_size", 14)
    table_turn_label.add_theme_color_override("font_color", Color("#f1e2ad"))
    table_turn_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.92))
    table_turn_label.add_theme_constant_override("outline_size", 5)
    table_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table_turn_label.z_index = 12
    trick_surface.add_child(table_turn_label)
    turn_label = table_turn_label

    cpu_lead_badge = _lead_badge()
    trick_surface.add_child(cpu_lead_badge)
    human_lead_badge = _lead_badge()
    trick_surface.add_child(human_lead_badge)

    cpu_slot = _card_slot()
    cpu_slot.rotation = deg_to_rad(-4.0)
    trick_surface.add_child(cpu_slot)

    human_slot = _card_slot()
    human_slot.rotation = deg_to_rad(4.0)
    trick_surface.add_child(human_slot)

    # Mazzetti delle prese: restano sul feltro e danno un riferimento fisico
    # a dove finiscono le carte vinte, come su un tavolo reale.
    cpu_taken_pile = Control.new()
    cpu_taken_pile.name = "CpuTakenPile"
    cpu_taken_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cpu_taken_pile.z_index = 1
    trick_surface.add_child(cpu_taken_pile)

    human_taken_pile = Control.new()
    human_taken_pile.name = "HumanTakenPile"
    human_taken_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    human_taken_pile.z_index = 1
    trick_surface.add_child(human_taken_pile)

    trick_outcome_label = Label.new()
    trick_outcome_label.visible = false
    trick_outcome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trick_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    trick_outcome_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    trick_outcome_label.add_theme_font_size_override("font_size", 22)
    trick_outcome_label.add_theme_color_override("font_color", Color("#f4e5ae"))
    trick_outcome_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.96))
    trick_outcome_label.add_theme_constant_override("outline_size", 7)
    trick_outcome_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    trick_outcome_label.offset_top = 2
    trick_outcome_label.offset_bottom = 44
    trick_outcome_label.z_index = 20
    trick_surface.add_child(trick_outcome_label)

    # Il vecchio pannello laterale del turno resta come nodo compatibile ma è
    # volutamente nascosto: le informazioni essenziali sono ora sul tavolo.
    info_panel = PanelContainer.new()
    info_panel.visible = false
    table_row.add_child(info_panel)

    player_zone = VBoxContainer.new()
    player_zone.custom_minimum_size.y = 194
    player_zone.alignment = BoxContainer.ALIGNMENT_CENTER
    player_zone.add_theme_constant_override("separation", 5)
    root_column.add_child(player_zone)

    var player_center := CenterContainer.new()
    player_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    player_zone.add_child(player_center)

    player_hand = HBoxContainer.new()
    player_hand.add_theme_constant_override("separation", -8)
    player_center.add_child(player_hand)

    player_caption = Label.new()
    player_caption.text = "LA TUA MANO  ·  scegli una carta"
    player_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_caption.add_theme_font_size_override("font_size", 13)
    player_caption.add_theme_color_override("font_color", Color("#c7d8d0"))
    player_zone.add_child(player_caption)

    footer = _panel(Color(0.015, 0.055, 0.045, 0.56), 14, Color(1, 1, 1, 0.05))
    footer.custom_minimum_size.y = 50
    root_column.add_child(footer)

    var footer_margin := MarginContainer.new()
    footer_margin.add_theme_constant_override("margin_left", 16)
    footer_margin.add_theme_constant_override("margin_right", 10)
    footer.add_child(footer_margin)

    footer_row = HBoxContainer.new()
    footer_row.add_theme_constant_override("separation", 10)
    footer_margin.add_child(footer_row)

    status_label = Label.new()
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 15)
    status_label.add_theme_color_override("font_color", Color("#e8f2ee"))
    footer_row.add_child(status_label)

    restart_button = Button.new()
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

    menu_panel = _panel(Color(0.025, 0.095, 0.075, 0.98), 28, Color(0.86, 0.73, 0.38, 0.28))
    menu_panel.custom_minimum_size = Vector2(520, 690)
    center.add_child(menu_panel)

    var menu_scroll := ScrollContainer.new()
    menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    menu_scroll.follow_focus = true
    menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    menu_panel.add_child(menu_scroll)

    menu_margin = MarginContainer.new()
    menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    menu_margin.add_theme_constant_override("margin_left", 42)
    menu_margin.add_theme_constant_override("margin_right", 42)
    menu_margin.add_theme_constant_override("margin_top", 30)
    menu_margin.add_theme_constant_override("margin_bottom", 28)
    menu_scroll.add_child(menu_margin)
    var margin := menu_margin

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 15)
    margin.add_child(column)

    var brand_mark := TextureRect.new()
    brand_mark.texture = load("res://icon.svg")
    brand_mark.custom_minimum_size = Vector2(72, 72)
    brand_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    brand_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    brand_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(brand_mark)

    var eyebrow := Label.new()
    eyebrow.text = "CLASSICO ITALIANO · MAZZO NAPOLETANO"
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
    subtitle.text = "1 contro 1 stabile · 4 giocatori a squadre Beta"
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
    difficulty_option.select(_difficulty_index(cpu_difficulty))
    difficulty_option.item_selected.connect(_on_difficulty_selected)
    _style_button(difficulty_option, false)
    column.add_child(difficulty_option)

    sound_toggle = CheckButton.new()
    sound_toggle.text = "Effetti sonori"
    sound_toggle.button_pressed = bool(settings.get("sound_enabled", true))
    sound_toggle.custom_minimum_size = Vector2(290, 40)
    sound_toggle.toggled.connect(_on_sound_toggled)
    column.add_child(sound_toggle)

    reduced_motion_toggle = CheckButton.new()
    reduced_motion_toggle.text = "Riduci animazioni"
    reduced_motion_toggle.button_pressed = bool(settings.get("reduced_motion", false))
    reduced_motion_toggle.custom_minimum_size = Vector2(290, 40)
    reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
    column.add_child(reduced_motion_toggle)

    continue_button = Button.new()
    continue_button.text = "CONTINUA PARTITA"
    continue_button.custom_minimum_size = Vector2(290, 50)
    _style_button(continue_button, false)
    continue_button.pressed.connect(_resume_saved_game)
    column.add_child(continue_button)

    var play_button := Button.new()
    play_button.text = "GIOCA · 1 CONTRO 1"
    play_button.custom_minimum_size = Vector2(290, 56)
    play_button.add_theme_font_size_override("font_size", 18)
    _style_button(play_button, true)
    play_button.pressed.connect(_start_selected_game)
    column.add_child(play_button)

    var four_player_button := Button.new()
    four_player_button.text = "4 GIOCATORI · SQUADRE  · BETA"
    four_player_button.custom_minimum_size = Vector2(290, 50)
    _style_button(four_player_button, false)
    four_player_button.pressed.connect(_open_four_player)
    column.add_child(four_player_button)

    var install_button := Button.new()
    install_button.text = "INSTALLA APP / GIOCA OFFLINE"
    install_button.custom_minimum_size = Vector2(290, 42)
    install_button.visible = OS.has_feature("web")
    _style_button(install_button, false)
    install_button.pressed.connect(_install_pwa)
    column.add_child(install_button)

    pwa_update_button = Button.new()
    pwa_update_button.text = "AGGIORNAMENTO DISPONIBILE · APPLICA"
    pwa_update_button.custom_minimum_size = Vector2(290, 42)
    pwa_update_button.visible = false
    _style_button(pwa_update_button, true)
    pwa_update_button.pressed.connect(_apply_pwa_update)
    column.add_child(pwa_update_button)

    var tutorial_button := Button.new()
    tutorial_button.text = "COME SI GIOCA"
    tutorial_button.custom_minimum_size = Vector2(290, 44)
    _style_button(tutorial_button, false)
    tutorial_button.pressed.connect(_show_tutorial.bind(false))
    column.add_child(tutorial_button)

    var support_button := Button.new()
    support_button.text = "SEGNALA UN PROBLEMA / FEEDBACK"
    support_button.custom_minimum_size = Vector2(290, 40)
    _style_button(support_button, false)
    support_button.pressed.connect(_open_feedback.bind("general"))
    column.add_child(support_button)

    var rules := Label.new()
    rules.text = "Prendi con la carta più forte del seme giocato,\no con una briscola. Vince chi supera 60 punti."
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rules.add_theme_font_size_override("font_size", 13)
    rules.add_theme_color_override("font_color", Color("#a8bdb4"))
    column.add_child(rules)

    stats_label = Label.new()
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats_label.add_theme_font_size_override("font_size", 12)
    stats_label.add_theme_color_override("font_color", Color("#9db4aa"))
    column.add_child(stats_label)

    var note := Label.new()
    note.text = "Mazzo napoletano · 40 carte · modalità classica e squadre"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", Color("#819b90"))
    column.add_child(note)

    var version_label := Label.new()
    version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "dev"))
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_font_size_override("font_size", 10)
    version_label.add_theme_color_override("font_color", Color("#6f887d"))
    column.add_child(version_label)


func _build_tutorial_overlay() -> void:
    tutorial_overlay = Control.new()
    tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_overlay.visible = false
    tutorial_overlay.z_index = 85
    add_child(tutorial_overlay)

    var blocker := ColorRect.new()
    blocker.color = Color(0.005, 0.02, 0.017, 0.80)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    tutorial_overlay.add_child(blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_overlay.add_child(center)

    tutorial_panel = _panel(Color(0.025, 0.095, 0.075, 0.99), 26, Color(0.86, 0.73, 0.38, 0.30))
    tutorial_panel.custom_minimum_size = Vector2(520, 390)
    center.add_child(tutorial_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 38)
    margin.add_theme_constant_override("margin_right", 38)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 28)
    tutorial_panel.add_child(margin)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 18)
    margin.add_child(column)

    tutorial_progress = Label.new()
    tutorial_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tutorial_progress.add_theme_font_size_override("font_size", 12)
    tutorial_progress.add_theme_color_override("font_color", Color("#d5bf7a"))
    column.add_child(tutorial_progress)

    tutorial_title = Label.new()
    tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tutorial_title.add_theme_font_size_override("font_size", 28)
    column.add_child(tutorial_title)

    tutorial_body = Label.new()
    tutorial_body.custom_minimum_size = Vector2(400, 145)
    tutorial_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tutorial_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tutorial_body.add_theme_font_size_override("font_size", 16)
    tutorial_body.add_theme_color_override("font_color", Color("#d9e6e0"))
    column.add_child(tutorial_body)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    column.add_child(actions)

    tutorial_back_button = Button.new()
    tutorial_back_button.text = "Indietro"
    tutorial_back_button.custom_minimum_size = Vector2(135, 46)
    _style_button(tutorial_back_button, false)
    tutorial_back_button.pressed.connect(_tutorial_previous)
    actions.add_child(tutorial_back_button)

    tutorial_next_button = Button.new()
    tutorial_next_button.text = "Avanti"
    tutorial_next_button.custom_minimum_size = Vector2(150, 46)
    _style_button(tutorial_next_button, true)
    tutorial_next_button.pressed.connect(_tutorial_next)
    actions.add_child(tutorial_next_button)

    var skip_button := Button.new()
    skip_button.text = "Chiudi"
    skip_button.custom_minimum_size = Vector2(110, 42)
    _style_button(skip_button, false)
    skip_button.pressed.connect(_close_tutorial)
    column.add_child(skip_button)


func _build_restart_dialog() -> void:
    restart_dialog = ConfirmationDialog.new()
    restart_dialog.title = "Ricominciare la partita?"
    restart_dialog.dialog_text = "La partita attuale verrà eliminata e ne inizierà una nuova."
    restart_dialog.ok_button_text = "Ricomincia"
    restart_dialog.cancel_button_text = "Annulla"
    restart_dialog.confirmed.connect(_confirm_restart)
    add_child(restart_dialog)


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

    result_panel = _panel(Color(0.025, 0.095, 0.075, 0.99), 28, Color(0.86, 0.73, 0.38, 0.3))
    result_panel.custom_minimum_size = Vector2(540, 500)
    center.add_child(result_panel)
    var panel := result_panel

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

    result_feedback_label = Label.new()
    result_feedback_label.text = "Com'è stata la difficoltà della CPU?"
    result_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_feedback_label.add_theme_font_size_override("font_size", 14)
    result_feedback_label.add_theme_color_override("font_color", Color("#d9e6e0"))
    column.add_child(result_feedback_label)

    result_feedback_row = HBoxContainer.new()
    result_feedback_row.alignment = BoxContainer.ALIGNMENT_CENTER
    result_feedback_row.add_theme_constant_override("separation", 8)
    column.add_child(result_feedback_row)

    for feedback_data in [["Troppo facile", "too_easy"], ["Giusta", "fair"], ["Troppo difficile", "too_hard"]]:
        var feedback_button := Button.new()
        feedback_button.text = str(feedback_data[0])
        feedback_button.custom_minimum_size = Vector2(142, 40)
        _style_button(feedback_button, str(feedback_data[1]) == "fair")
        feedback_button.pressed.connect(_record_ai_feedback.bind(str(feedback_data[1])))
        result_feedback_row.add_child(feedback_button)

    result_feedback_status = Label.new()
    result_feedback_status.text = ""
    result_feedback_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_feedback_status.add_theme_font_size_override("font_size", 12)
    result_feedback_status.add_theme_color_override("font_color", Color("#d5bf7a"))
    column.add_child(result_feedback_status)

    var feedback := Button.new()
    feedback.text = "Invia feedback dettagliato"
    feedback.custom_minimum_size = Vector2(250, 42)
    _style_button(feedback, false)
    feedback.pressed.connect(_open_feedback.bind("playtest"))
    column.add_child(feedback)

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
    _save_progress()
    _show_menu()


func _on_restart_pressed() -> void:
    if busy:
        _set_status("Completo prima l'animazione in corso...")
        return
    if restart_dialog != null:
        restart_dialog.popup_centered(Vector2i(430, 190))


func _confirm_restart() -> void:
    await _new_game()


func _on_difficulty_selected(index: int) -> void:
    if index == 0:
        cpu_difficulty = "easy"
    elif index == 2:
        cpu_difficulty = "hard"
    else:
        cpu_difficulty = "normal"
    settings["difficulty"] = cpu_difficulty
    persistence.save_settings(settings)


func _on_sound_toggled(enabled: bool) -> void:
    settings["sound_enabled"] = enabled
    persistence.save_settings(settings)


func _on_reduced_motion_toggled(enabled: bool) -> void:
    settings["reduced_motion"] = enabled
    persistence.save_settings(settings)


func _show_menu() -> void:
    busy = false
    result_overlay.visible = false
    game_screen.visible = false
    menu_overlay.visible = true
    _clear_animation_layer()
    _refresh_menu_state()
    _apply_responsive_layout()


func _refresh_menu_state() -> void:
    if continue_button == null:
        return
    var saved: Dictionary = persistence.load_game()
    if saved.is_empty() and persistence.has_saved_game():
        persistence.clear_saved_game()
    continue_button.visible = not saved.is_empty()
    continue_button.disabled = saved.is_empty()
    if not saved.is_empty():
        var state: Dictionary = saved.get("engine", {})
        var trick: int = int(state.get("trick_number", 1))
        continue_button.text = "CONTINUA · PRESA %d" % min(trick, 20)

    var games: int = int(settings.get("games", 0))
    var wins: int = int(settings.get("wins", 0))
    var losses: int = int(settings.get("losses", 0))
    var draws: int = int(settings.get("draws", 0))
    stats_label.text = "Partite %d · Vittorie %d · Sconfitte %d · Pareggi %d" % [games, wins, losses, draws]


func _show_tutorial(start_game_after: bool = false) -> void:
    if tutorial_overlay == null:
        return
    _start_game_after_tutorial = start_game_after
    tutorial_step = 0
    tutorial_overlay.visible = true
    _refresh_tutorial_step()


func _refresh_tutorial_step() -> void:
    if tutorial_overlay == null or TUTORIAL_STEPS.is_empty():
        return
    tutorial_step = clampi(tutorial_step, 0, TUTORIAL_STEPS.size() - 1)
    var data: Dictionary = TUTORIAL_STEPS[tutorial_step]
    tutorial_progress.text = "COME SI GIOCA  ·  %d/%d" % [tutorial_step + 1, TUTORIAL_STEPS.size()]
    tutorial_title.text = str(data.get("title", ""))
    tutorial_body.text = str(data.get("body", ""))
    tutorial_back_button.disabled = tutorial_step == 0
    tutorial_next_button.text = "GIOCA" if tutorial_step == TUTORIAL_STEPS.size() - 1 and _start_game_after_tutorial else ("Fine" if tutorial_step == TUTORIAL_STEPS.size() - 1 else "Avanti")


func _tutorial_previous() -> void:
    tutorial_step = max(0, tutorial_step - 1)
    _refresh_tutorial_step()


func _tutorial_next() -> void:
    if tutorial_step < TUTORIAL_STEPS.size() - 1:
        tutorial_step += 1
        _refresh_tutorial_step()
        return
    _close_tutorial()


func _close_tutorial() -> void:
    if tutorial_overlay == null:
        return
    tutorial_overlay.visible = false
    settings["tutorial_seen"] = true
    persistence.save_settings(settings)
    var should_start: bool = _start_game_after_tutorial
    _start_game_after_tutorial = false
    if should_start:
        await _new_game()


func _open_four_player() -> void:
    if engine.trump_suit != "" and not engine.is_game_over():
        _save_progress()
    get_tree().change_scene_to_file("res://scenes/four_player.tscn")


func _install_pwa() -> void:
    if not OS.has_feature("web"):
        return
    JavaScriptBridge.eval("window.BriscolaPWA && window.BriscolaPWA.install();", true)


func _refresh_pwa_update_button() -> void:
    if not OS.has_feature("web") or pwa_update_button == null:
        return
    var available: Variant = JavaScriptBridge.eval("Boolean(window.BriscolaPWA && window.BriscolaPWA.state().updateAvailable)", true)
    pwa_update_button.visible = bool(available)


func _apply_pwa_update() -> void:
    if not OS.has_feature("web"):
        return
    JavaScriptBridge.eval("window.BriscolaPWA && window.BriscolaPWA.applyUpdate();", true)


func _start_selected_game() -> void:
    _on_difficulty_selected(difficulty_option.selected)
    if not bool(settings.get("tutorial_seen", false)):
        _show_tutorial(true)
        return
    await _new_game()


func _new_game() -> void:
    busy = true
    result_recorded = false
    _last_leader = ""
    persistence.clear_saved_game()
    menu_overlay.visible = false
    result_overlay.visible = false
    game_screen.visible = true
    _clear_animation_layer()
    engine.new_game()
    _play_sfx(SFX_SHUFFLE)
    _clear_container(player_hand)
    _clear_container(opponent_hand)
    _refresh_table()
    _refresh_capture_piles()
    _prepare_initial_deck_visual()
    _refresh_header()
    difficulty_label.text = "CPU · %s" % _difficulty_display_name()
    _set_status("Distribuzione delle carte...")
    await get_tree().process_frame
    await _animate_initial_deal()
    # Le carte finali sono già i nodi reali della mano: non ricrearle qui.
    # Evita il piccolo "pop" che si vedeva al termine della distribuzione.
    busy = false
    _refresh_header()
    _save_progress()
    _set_hand_interaction(true)
    _set_status("Tocca a te. Scegli una carta.")
    _pulse_human_turn()


func _resume_saved_game() -> void:
    var payload: Dictionary = persistence.load_game()
    if payload.is_empty():
        _refresh_menu_state()
        return
    var state: Dictionary = payload.get("engine", {})
    if not engine.load_from_dict(state):
        persistence.clear_saved_game()
        _refresh_menu_state()
        return

    cpu_difficulty = str(payload.get("difficulty", settings.get("difficulty", "normal")))
    settings["difficulty"] = cpu_difficulty
    persistence.save_settings(settings)
    difficulty_option.select(_difficulty_index(cpu_difficulty))
    result_recorded = false
    _last_leader = ""
    busy = true
    menu_overlay.visible = false
    result_overlay.visible = false
    game_screen.visible = true
    _clear_animation_layer()
    difficulty_label.text = "CPU · %s" % _difficulty_display_name()
    _refresh_hands()
    _refresh_deck()
    _refresh_table()
    _refresh_capture_piles()
    _refresh_header()
    _set_status("Partita ripristinata.")
    await get_tree().process_frame

    if engine.is_game_over():
        busy = false
        _show_result()
    elif engine.table.size() == 2:
        await _finish_trick()
    elif engine.current_player == "cpu":
        await _cpu_turn()
    else:
        busy = false
        _set_hand_interaction(true)
        _refresh_header()
        _set_status("Partita ripristinata · tocca a te.")
        _pulse_human_turn()


func _save_progress() -> void:
    if engine.trump_suit == "" or engine.is_game_over():
        return
    if not persistence.save_game(engine.to_dict(), cpu_difficulty):
        push_warning("Impossibile salvare lo stato corrente della partita.")
        return
    if OS.has_feature("web"):
        JavaScriptBridge.force_fs_sync()


func _animate_initial_deal() -> void:
    _clear_container(player_hand)
    _clear_container(opponent_hand)

    # Prima costruiamo le vere carte della mano, ma invisibili. I Container
    # possono così calcolare la posizione finale esatta prima che parta la
    # prima animazione: nessuna carta "salta" quando il floater viene rimosso.
    for index in range(3):
        _append_initial_card("human", index, true)
        _append_initial_card("cpu", index, true)

    await get_tree().process_frame
    await get_tree().process_frame
    await _animate_deck_ready()

    # Tony fa da mazziere: la prima carta va a chi gioca, poi a Tony, per tre
    # giri. Ogni carta resta immediatamente nella posizione definitiva.
    for round_index in range(3):
        await _animate_initial_card("human", round_index)
        await get_tree().create_timer(_anim_duration(0.035)).timeout
        await _animate_initial_card("cpu", round_index)
        if round_index < 2:
            await get_tree().create_timer(_anim_duration(0.055)).timeout

    await _animate_initial_trump_reveal()

    # Guardrail in caso di resize durante la distribuzione.
    for child in player_hand.get_children():
        child.modulate.a = 1.0
    for child in opponent_hand.get_children():
        child.modulate.a = 1.0


func _prepare_initial_deck_visual() -> void:
    _clear_container(deck_box)
    var display_size: Vector2 = _deck_display_size()
    for layer in range(3):
        var back := _texture_card(BACK_TEXTURE, display_size)
        back.rotation = deg_to_rad(-2.0 + float(layer) * 1.4)
        back.pivot_offset = display_size * 0.5
        deck_box.add_child(back)
    if table_phase_label != null:
        table_phase_label.text = "DISTRIBUZIONE"


func _animate_initial_trump_reveal() -> void:
    # Il motore conosce già la briscola, ma visivamente la scopriamo soltanto
    # dopo la sesta carta, come su un tavolo reale.
    _refresh_deck()
    if deck_box == null or deck_box.get_child_count() == 0:
        return
    var trump := deck_box.get_child(deck_box.get_child_count() - 1) as Control
    trump.modulate.a = 0.0
    trump.scale = Vector2(0.82, 0.82)
    trump.rotation = deg_to_rad(2.0)
    await get_tree().process_frame
    trump.pivot_offset = trump.size * 0.5
    if bool(settings.get("reduced_motion", false)):
        trump.modulate.a = 1.0
        trump.scale = Vector2.ONE
        trump.rotation = deg_to_rad(10.0)
        return
    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(trump, "modulate:a", 1.0, _anim_duration(0.14))
    tween.tween_property(trump, "scale", Vector2.ONE, _anim_duration(0.20))
    tween.tween_property(trump, "rotation", deg_to_rad(10.0), _anim_duration(0.20))
    await tween.finished
    await get_tree().create_timer(_anim_duration(0.10)).timeout


func _animate_deck_ready() -> void:
    if bool(settings.get("reduced_motion", false)):
        return
    if deck_box == null:
        return
    deck_box.pivot_offset = deck_box.size * 0.5
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(deck_box, "rotation", deg_to_rad(-1.8), 0.055)
    tween.tween_property(deck_box, "rotation", deg_to_rad(1.5), 0.070)
    tween.tween_property(deck_box, "rotation", 0.0, 0.060)
    await tween.finished


func _animate_initial_card(player: String, index: int) -> void:
    var target_control: Control
    var target_position: Vector2
    var target_size: Vector2
    var target_rotation: float = 0.0

    if player == "human":
        if index >= player_hand.get_child_count():
            return
        var view := player_hand.get_child(index) as CardView
        target_control = view
        target_position = view.get_visual_global_position()
        target_size = view.size
        target_rotation = view.get_visual_global_rotation()
    else:
        if index >= opponent_hand.get_child_count():
            return
        target_control = opponent_hand.get_child(index) as Control
        target_position = target_control.global_position
        target_size = target_control.size
        target_rotation = target_control.global_rotation

    if target_size.x <= 1.0 or target_size.y <= 1.0:
        target_size = card_size if player == "human" else small_card_size

    var source: Vector2 = _deck_source_position()
    var source_size: Vector2 = _deck_display_size()
    var floating := _floating_card(BACK_TEXTURE, source_size, source)
    floating.z_index = 60
    floating.rotation = deg_to_rad(-5.0 if player == "human" else 5.0)

    # Un arco breve con accelerazione iniziale e atterraggio morbido. La carta
    # finisce esattamente sopra il nodo reale della mano.
    var direction: float = 1.0 if player == "human" else -1.0
    var midpoint: Vector2 = source.lerp(target_position, 0.56)
    midpoint += Vector2(18.0 * direction, -34.0)

    var travel := create_tween()
    travel.set_parallel(true)
    travel.set_trans(Tween.TRANS_QUAD)
    travel.set_ease(Tween.EASE_OUT)
    travel.tween_property(floating, "position", midpoint, _anim_duration(0.095))
    travel.tween_property(floating, "size", source_size.lerp(target_size, 0.58), _anim_duration(0.095))
    travel.tween_property(floating, "rotation", target_rotation * 0.35, _anim_duration(0.095))
    await travel.finished

    var land := create_tween()
    land.set_parallel(true)
    land.set_trans(Tween.TRANS_CUBIC)
    land.set_ease(Tween.EASE_OUT)
    land.tween_property(floating, "position", target_position, _anim_duration(0.115))
    land.tween_property(floating, "size", target_size, _anim_duration(0.115))
    land.tween_property(floating, "rotation", target_rotation, _anim_duration(0.115))
    await land.finished
    _play_sfx(SFX_CARD)

    if player == "human":
        # La carta arriva coperta e si gira una sola volta già nella posizione
        # definitiva. Il nodo vero viene rivelato durante l'ultimo frame del flip.
        floating.pivot_offset = target_size * 0.5
        var close_flip := create_tween()
        close_flip.set_trans(Tween.TRANS_QUAD)
        close_flip.set_ease(Tween.EASE_IN)
        close_flip.tween_property(floating, "scale:x", 0.035, _anim_duration(0.052))
        await close_flip.finished

        var card: Dictionary = engine.hands["human"][index]
        floating.texture = load(engine.card_texture_path(card))
        var open_flip := create_tween()
        open_flip.set_trans(Tween.TRANS_QUAD)
        open_flip.set_ease(Tween.EASE_OUT)
        open_flip.tween_property(floating, "scale:x", 1.0, _anim_duration(0.070))
        await open_flip.finished

    target_control.modulate.a = 1.0
    # Un cross-fade quasi impercettibile evita qualunque seam tra carta volante
    # e carta interattiva finale, soprattutto su browser/mobile lenti.
    var settle := create_tween()
    settle.tween_property(floating, "modulate:a", 0.0, _anim_duration(0.035))
    await settle.finished
    floating.queue_free()


func _append_initial_card(player: String, index: int, hidden: bool = false) -> void:
    if player == "human":
        var card: Dictionary = engine.hands["human"][index]
        var view := CardView.new()
        view.setup(card, index, load(engine.card_texture_path(card)), card_size, "%s · %d punti" % [engine.card_name(card), engine.points_for(card)])
        view.card_selected.connect(_on_player_card_pressed)
        var fan_delta: float = float(index) - 1.0
        view.set_fan_pose(fan_delta * 5.0, abs(fan_delta) * 4.0)
        view.set_interactive(false)
        view.modulate.a = 0.0 if hidden else 1.0
        player_hand.add_child(view)
    else:
        var back := _texture_card(BACK_TEXTURE, small_card_size)
        back.pivot_offset = small_card_size * 0.5
        back.rotation = deg_to_rad((float(index) - 1.0) * 5.0)
        back.modulate.a = 0.0 if hidden else 1.0
        opponent_hand.add_child(back)


func _initial_deal_target(player: String, index: int, target_size: Vector2) -> Vector2:
    # Usato per le pescate successive. La prima distribuzione usa invece la
    # posizione reale dei placeholder, già calcolata dai Container.
    var zone: Control = player_zone if player == "human" else opponent_zone
    var separation: float = -34.0
    if player == "human":
        separation = -14.0 if compact_layout else -8.0
    elif not compact_layout:
        separation = -42.0
    var stride: float = target_size.x + separation
    var count: int = int(max(1, engine.hands[player].size()))
    var total_width: float = target_size.x + stride * float(max(0, count - 1))
    var start_x: float = zone.global_position.x + (zone.size.x - total_width) * 0.5
    var y: float = zone.global_position.y + (zone.size.y - target_size.y) * 0.5
    return Vector2(start_x + stride * float(index), y)


func _on_player_card_pressed(index: int) -> void:
    if busy or engine.current_player != "human":
        return
    if index < 0 or index >= player_hand.get_child_count():
        return

    busy = true
    _set_hand_interaction(false)

    var source := player_hand.get_child(index) as Control
    var start_position: Vector2 = source.global_position
    var start_size: Vector2 = source.size
    if source is CardView:
        start_position = (source as CardView).get_visual_global_position()
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
    _save_progress()

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
    await get_tree().create_timer(_anim_duration(0.48)).timeout

    var index: int = engine.choose_cpu_card(cpu_difficulty)
    if index < 0:
        busy = false
        return

    var start_position := _control_center_position(opponent_hand, small_card_size)
    var start_size := small_card_size
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
    _save_progress()
    _set_status("Tony gioca %s." % engine.card_name(card))
    await get_tree().create_timer(_anim_duration(0.30)).timeout

    if engine.table.size() == 2:
        await _finish_trick()
    else:
        busy = false
        _refresh_header()
        _set_hand_interaction(true)
        _set_status("Tocca a te.")
        _pulse_human_turn()


func _finish_trick() -> void:
    await get_tree().create_timer(_anim_duration(0.52)).timeout

    var played: Array = engine.table.duplicate(true)
    var deck_before: int = engine.deck.size()
    var result: Dictionary = engine.resolve_trick()
    if result.is_empty():
        busy = false
        return
    _save_progress()

    var winner: String = str(result["winner"])
    var winner_name: String = "Tu" if winner == "human" else "Tony"
    _set_status("%s prende la mano · +%d punti" % [winner_name, int(result["points"])])
    await _animate_trick_collection(played, winner, int(result["points"]))
    _play_sfx(SFX_TAKE)
    _refresh_capture_piles()
    _refresh_header()

    var draws: Array = result.get("draws", [])
    if deck_before > 0 and not draws.is_empty():
        var visual_count: int = deck_before
        for draw_value in draws:
            var draw_info: Dictionary = draw_value
            await _animate_draw_card(draw_info, _anim_duration(0.28))
            visual_count = max(0, visual_count - 1)
            _refresh_deck(visual_count)
            await get_tree().create_timer(_anim_duration(0.06)).timeout

        if visual_count == 0:
            await _show_phase_notice("MAZZO ESAURITO  ·  NIENTE PIÙ PESCA")

    _refresh_hands()
    _refresh_deck()
    _refresh_table()
    _refresh_capture_piles()
    _refresh_header()

    if engine.is_game_over():
        busy = false
        await get_tree().create_timer(_anim_duration(0.35)).timeout
        _show_result()
        return

    if engine.current_player == "cpu":
        await get_tree().create_timer(_anim_duration(0.22)).timeout
        await _cpu_turn()
    else:
        busy = false
        _set_hand_interaction(true)
        _refresh_header()
        _set_status("Hai preso la mano: inizi tu.")
        _pulse_human_turn()


func _pulse_human_turn() -> void:
    if player_caption == null or bool(settings.get("reduced_motion", false)):
        return
    player_caption.pivot_offset = player_caption.size * 0.5
    player_caption.scale = Vector2(0.97, 0.97)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(player_caption, "scale", Vector2(1.06, 1.06), 0.12)
    tween.tween_property(player_caption, "scale", Vector2.ONE, 0.16)


func _show_result() -> void:
    persistence.clear_saved_game()
    if result_feedback_status != null:
        result_feedback_status.text = ""
    if result_feedback_row != null:
        for child in result_feedback_row.get_children():
            if child is Button:
                (child as Button).disabled = false
    if not result_recorded:
        settings = persistence.record_result(settings, int(engine.scores["human"]), int(engine.scores["cpu"]))
        result_recorded = true

    result_score.text = "%d  —  %d" % [int(engine.scores["human"]), int(engine.scores["cpu"])]
    if engine.scores["human"] > engine.scores["cpu"]:
        result_title.text = "Hai vinto!"
        _play_sfx(SFX_WIN)
    elif engine.scores["human"] < engine.scores["cpu"]:
        result_title.text = "Tony ha vinto"
        _play_sfx(SFX_LOSE)
    else:
        result_title.text = "Pareggio"
    result_detail.text = "20 prese · difficoltà %s · %d partite totali" % [_difficulty_display_name().to_lower(), int(settings.get("games", 0))]
    result_overlay.visible = true
    _set_status("Partita conclusa.")


func _refresh_header() -> void:
    human_score_label.text = str(int(engine.scores["human"]))
    cpu_score_label.text = str(int(engine.scores["cpu"]))
    trick_label.text = "Presa %d / 20" % min(engine.trick_number, 20)
    if trump_label != null:
        trump_label.text = "Briscola · %s" % BriscolaEngine.SUIT_NAMES.get(engine.trump_suit, "")
    if deck_label != null:
        deck_label.text = "%d carte da pescare" % engine.deck.size()

    var human_turn: bool = engine.current_player == "human"
    if turn_label != null:
        turn_label.text = "TOCCA A TE" if human_turn else "TONY PENSA"

    var leader: String = _current_trick_leader()
    var leader_changed: bool = leader != _last_leader
    if cpu_lead_badge != null:
        cpu_lead_badge.visible = leader == "cpu"
    if human_lead_badge != null:
        human_lead_badge.visible = leader == "human"
    if leader_changed:
        _last_leader = leader
        _pulse_lead_badge(leader)
    if opponent_name_label != null:
        opponent_name_label.add_theme_color_override("font_color", Color("#d5bf7a") if not human_turn else Color("#a9bbb4"))
    if player_caption != null:
        if human_turn and not busy:
            player_caption.text = "TOCCA A TE  ·  scegli una carta" if not compact_layout else "TOCCA A TE"
            player_caption.add_theme_color_override("font_color", Color("#f0dc9b"))
        elif human_turn:
            player_caption.text = "LA TUA MANO"
            player_caption.add_theme_color_override("font_color", Color("#c7d8d0"))
        else:
            player_caption.text = "ATTENDI · Tony sta giocando" if not compact_layout else "ATTENDI TONY"
            player_caption.add_theme_color_override("font_color", Color("#96aaa2"))


func _pulse_lead_badge(leader: String) -> void:
    if bool(settings.get("reduced_motion", false)):
        return
    var badge: Label = human_lead_badge if leader == "human" else cpu_lead_badge
    if badge == null or not badge.visible:
        return
    badge.pivot_offset = badge.size * 0.5
    badge.scale = Vector2(0.88, 0.88)
    badge.modulate = Color(1, 1, 1, 0.55)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(badge, "scale", Vector2.ONE, _anim_duration(0.18))
    tween.tween_property(badge, "modulate", Color.WHITE, _anim_duration(0.14))


func _current_trick_leader() -> String:
    if not engine.table.is_empty():
        var first_play: Dictionary = engine.table[0]
        return str(first_play.get("player", engine.current_player))
    return engine.current_player


func _refresh_hands() -> void:
    _refresh_opponent_hand()
    _refresh_player_hand()


func _refresh_opponent_hand() -> void:
    _clear_container(opponent_hand)
    var count: int = engine.hands["cpu"].size()
    for i in range(count):
        var back := _texture_card(BACK_TEXTURE, small_card_size)
        back.pivot_offset = small_card_size * 0.5
        var center_index: float = (float(count) - 1.0) * 0.5
        back.rotation = deg_to_rad((float(i) - center_index) * 5.0)
        opponent_hand.add_child(back)


func _refresh_player_hand() -> void:
    _clear_container(player_hand)
    var count: int = engine.hands["human"].size()
    for i in range(count):
        var card: Dictionary = engine.hands["human"][i]
        var view := CardView.new()
        view.setup(card, i, load(engine.card_texture_path(card)), card_size, "%s · %d punti" % [engine.card_name(card), engine.points_for(card)])
        view.card_selected.connect(_on_player_card_pressed)

        # Piccolo ventaglio: il bottone conserva un hit-box regolare, mentre
        # solo la parte visiva ruota e si alza al passaggio del mouse/touch focus.
        var center_index: float = (float(count) - 1.0) * 0.5
        var fan_delta: float = float(i) - center_index
        view.set_fan_pose(fan_delta * 5.0, abs(fan_delta) * 4.0)
        view.set_interactive(not busy and engine.current_player == "human")
        player_hand.add_child(view)


func _refresh_deck(visual_count: int = -1) -> void:
    _clear_container(deck_box)
    var remaining: int = engine.deck.size() if visual_count < 0 else visual_count
    var display_size: Vector2 = _deck_display_size()

    # Un piccolo spessore visivo comunica quante carte restano senza usare un
    # riquadro o un contatore invadente. La briscola resta scoperta di lato.
    if remaining > 1:
        var stack_layers: int = 1
        if remaining > 12:
            stack_layers = 2
        if remaining > 24:
            stack_layers = 3
        for layer in range(stack_layers):
            var back := _texture_card(BACK_TEXTURE, display_size)
            back.rotation = deg_to_rad(-2.0 + float(layer) * 1.4)
            back.pivot_offset = display_size * 0.5
            deck_box.add_child(back)

    if remaining > 0:
        var trump_view := _texture_card(engine.card_texture_path(engine.trump_card), display_size)
        trump_view.rotation = deg_to_rad(10.0)
        trump_view.pivot_offset = display_size * 0.5
        trump_view.tooltip_text = "Briscola: %s" % engine.card_name(engine.trump_card)
        deck_box.add_child(trump_view)

    if table_phase_label != null:
        if remaining > 0:
            var suit_name: String = str(BriscolaEngine.SUIT_NAMES.get(engine.trump_suit, engine.trump_suit)).to_upper()
            if remaining == 1:
                if compact_layout:
                    table_phase_label.text = "BRISCOLA · %s\nULTIMA CARTA" % suit_name
                else:
                    table_phase_label.text = "BRISCOLA · %s · ULTIMA CARTA" % suit_name
            else:
                if compact_layout:
                    table_phase_label.text = "BRISCOLA · %s\n%d CARTE" % [suit_name, remaining]
                else:
                    table_phase_label.text = "BRISCOLA · %s · %d CARTE" % [suit_name, remaining]
        else:
            table_phase_label.text = "FINALE · NIENTE PIÙ PESCA"


func _refresh_table() -> void:
    _clear_container(cpu_slot)
    _clear_container(human_slot)
    cpu_slot.z_index = 2
    human_slot.z_index = 2
    _apply_natural_table_pose()

    for i in range(engine.table.size()):
        var play: Dictionary = engine.table[i]
        var card: Dictionary = play["card"]
        var view := _texture_card(engine.card_texture_path(card), table_card_size)
        view.tooltip_text = engine.card_name(card)
        var slot: Control = cpu_slot if str(play["player"]) == "cpu" else human_slot
        slot.z_index = 4 + i
        slot.add_child(view)


func _apply_natural_table_pose() -> void:
    # Angoli leggermente diversi a ogni presa: la carta non sembra incastrata
    # in uno slot invisibile ma appoggiata naturalmente sul feltro.
    var phase: float = float(engine.trick_number)
    cpu_slot.rotation = deg_to_rad(-5.0 + sin(phase * 1.77) * 2.4)
    human_slot.rotation = deg_to_rad(4.0 + cos(phase * 1.31) * 2.4)


func _refresh_capture_piles() -> void:
    if cpu_taken_pile == null or human_taken_pile == null:
        return
    _render_capture_pile(cpu_taken_pile, "cpu")
    _render_capture_pile(human_taken_pile, "human")


func _render_capture_pile(pile: Control, player: String) -> void:
    _clear_container(pile)
    var tricks: int = int(engine.captured[player].size() / 2)
    pile.visible = tricks > 0
    if tricks <= 0:
        return

    var pile_card_size: Vector2 = small_card_size * 0.58
    pile.size = pile_card_size + Vector2(18, 16)
    var layers: int = min(3, tricks)
    for i in range(layers):
        var back := _texture_card(BACK_TEXTURE, pile_card_size)
        back.size = pile_card_size
        back.position = Vector2(float(i) * 4.0, float(i) * -2.5)
        back.rotation = deg_to_rad((-4.0 if player == "cpu" else 4.0) + float(i) * 1.2)
        back.pivot_offset = pile_card_size * 0.5
        pile.add_child(back)

    var count := Label.new()
    count.text = str(tricks)
    count.tooltip_text = "%d prese" % tricks
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count.position = Vector2(pile_card_size.x - 9.0, pile_card_size.y - 20.0)
    count.size = Vector2(30, 30)
    count.add_theme_font_size_override("font_size", 13)
    count.add_theme_color_override("font_color", Color("#fff5cf"))
    count.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.98))
    count.add_theme_constant_override("outline_size", 5)
    pile.add_child(count)


func _set_hand_interaction(enabled: bool) -> void:
    for child in player_hand.get_children():
        if child is CardView:
            var card_view := child as CardView
            card_view.set_interactive(enabled and engine.current_player == "human")


func _animate_card_to_slot(path: String, start_position: Vector2, start_size: Vector2, slot: Control, reveal_after_move: bool) -> void:
    var initial_texture: String = BACK_TEXTURE if reveal_after_move else path
    var floating := _floating_card(initial_texture, start_size, start_position)
    var target_position: Vector2 = slot.global_position + (slot.size - table_card_size) * 0.5
    var target_rotation: float = slot.rotation
    floating.rotation = target_rotation * -0.6

    # Lancio in due tempi con un piccolo arco: la carta non scorre più in linea
    # retta come un elemento UI, ma sembra realmente buttata sul tavolo.
    var midpoint: Vector2 = start_position.lerp(target_position, 0.60)
    midpoint.y -= max(28.0, abs(target_position.y - start_position.y) * 0.10)
    var mid_size: Vector2 = start_size.lerp(table_card_size, 0.62)

    var flight_a := create_tween()
    flight_a.set_parallel(true)
    flight_a.set_trans(Tween.TRANS_QUAD)
    flight_a.set_ease(Tween.EASE_OUT)
    flight_a.tween_property(floating, "position", midpoint, _anim_duration(0.15))
    flight_a.tween_property(floating, "size", mid_size, _anim_duration(0.15))
    flight_a.tween_property(floating, "rotation", target_rotation * 0.35, _anim_duration(0.15))
    await flight_a.finished

    var flight_b := create_tween()
    flight_b.set_parallel(true)
    flight_b.set_trans(Tween.TRANS_CUBIC)
    flight_b.set_ease(Tween.EASE_OUT)
    flight_b.tween_property(floating, "position", target_position, _anim_duration(0.19))
    flight_b.tween_property(floating, "size", table_card_size, _anim_duration(0.19))
    flight_b.tween_property(floating, "rotation", target_rotation, _anim_duration(0.19))
    await flight_b.finished

    if reveal_after_move:
        floating.pivot_offset = floating.size * 0.5
        var close_flip := create_tween()
        close_flip.set_trans(Tween.TRANS_QUAD)
        close_flip.set_ease(Tween.EASE_IN)
        close_flip.tween_property(floating, "scale:x", 0.045, _anim_duration(0.07))
        await close_flip.finished
        floating.texture = load(path)
        var open_flip := create_tween()
        open_flip.set_trans(Tween.TRANS_QUAD)
        open_flip.set_ease(Tween.EASE_OUT)
        open_flip.tween_property(floating, "scale:x", 1.0, _anim_duration(0.09))
        await open_flip.finished

    # Piccolo impatto finale sul feltro.
    var settle := create_tween()
    settle.set_trans(Tween.TRANS_SINE)
    settle.set_ease(Tween.EASE_OUT)
    settle.tween_property(floating, "scale", Vector2(1.022, 0.985), _anim_duration(0.045))
    settle.tween_property(floating, "scale", Vector2.ONE, _anim_duration(0.075))
    await settle.finished
    floating.queue_free()


func _animate_trick_collection(played: Array, winner: String, points: int) -> void:
    if table_turn_label != null:
        table_turn_label.visible = false
    var floaters: Array = []
    var winner_floater: TextureRect = null
    var loser_floater: TextureRect = null

    for value in played:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        var slot: Control = human_slot if str(play["player"]) == "human" else cpu_slot
        var start: Vector2 = slot.global_position + (slot.size - table_card_size) * 0.5
        var floating := _floating_card(engine.card_texture_path(card), table_card_size, start)
        floating.rotation = slot.rotation
        floaters.append(floating)
        if str(play["player"]) == winner:
            winner_floater = floating
        else:
            loser_floater = floating

    _clear_container(cpu_slot)
    _clear_container(human_slot)

    # 1) La carta vincente si stacca chiaramente dal tavolo.
    if winner_floater != null:
        winner_floater.z_index = 6
    if loser_floater != null:
        loser_floater.z_index = 5

    var highlight := create_tween()
    highlight.set_parallel(true)
    highlight.set_trans(Tween.TRANS_BACK)
    highlight.set_ease(Tween.EASE_OUT)
    if winner_floater != null:
        highlight.tween_property(winner_floater, "scale", Vector2(1.12, 1.12), _anim_duration(0.18))
        highlight.tween_property(winner_floater, "position", winner_floater.position + Vector2(0, -18.0), _anim_duration(0.18))
        highlight.tween_property(winner_floater, "modulate", Color(1.08, 1.04, 0.82, 1.0), _anim_duration(0.18))
    if loser_floater != null:
        highlight.tween_property(loser_floater, "scale", Vector2(0.95, 0.95), _anim_duration(0.18))
        highlight.tween_property(loser_floater, "modulate", Color(0.62, 0.65, 0.63, 0.86), _anim_duration(0.18))
    await highlight.finished

    await _show_trick_outcome(winner, points)
    await get_tree().create_timer(_anim_duration(0.34)).timeout

    # 2) La carta perdente scivola sotto quella vincente: visivamente è il
    # vincitore che raccoglie la presa, prima ancora del volo verso il mazzetto.
    var gather_point: Vector2 = Vector2.ZERO
    if winner_floater != null:
        gather_point = winner_floater.position
    elif not floaters.is_empty():
        gather_point = (floaters[0] as TextureRect).position

    var gather := create_tween()
    gather.set_parallel(true)
    gather.set_trans(Tween.TRANS_QUAD)
    gather.set_ease(Tween.EASE_IN_OUT)
    if loser_floater != null:
        var gather_rotation: float = 0.0
        if winner_floater != null:
            gather_rotation = winner_floater.rotation + deg_to_rad(2.0)
        gather.tween_property(loser_floater, "position", gather_point + Vector2(9, 6), _anim_duration(0.17))
        gather.tween_property(loser_floater, "rotation", gather_rotation, _anim_duration(0.17))
        gather.tween_property(loser_floater, "modulate", Color.WHITE, _anim_duration(0.17))
    if winner_floater != null:
        gather.tween_property(winner_floater, "scale", Vector2(1.0, 1.0), _anim_duration(0.17))
        gather.tween_property(winner_floater, "modulate", Color.WHITE, _anim_duration(0.17))
    await gather.finished

    # 3) L'intera presa vola nel mazzetto fisico del vincitore.
    var target: Vector2 = _capture_target_position(winner)
    var collect := create_tween()
    collect.set_parallel(true)
    collect.set_trans(Tween.TRANS_CUBIC)
    collect.set_ease(Tween.EASE_IN)
    for i in range(floaters.size()):
        var floating := floaters[i] as TextureRect
        var offset := Vector2(float(i) * 5.0, float(i) * 2.5)
        collect.tween_property(floating, "position", target + offset, _anim_duration(0.34))
        collect.tween_property(floating, "scale", Vector2(0.38, 0.38), _anim_duration(0.34))
        collect.tween_property(floating, "rotation", deg_to_rad(-4.0 if winner == "cpu" else 4.0), _anim_duration(0.34))
        collect.tween_property(floating, "modulate:a", 0.12, _anim_duration(0.34)).set_delay(_anim_duration(0.18))
    _pulse_capture_target(winner, points)
    await collect.finished

    for value in floaters:
        var floating := value as TextureRect
        floating.queue_free()

    trick_outcome_label.visible = false
    trick_outcome_label.modulate = Color.WHITE
    trick_outcome_label.scale = Vector2.ONE
    if table_turn_label != null:
        table_turn_label.visible = true


func _show_trick_outcome(winner: String, points: int) -> void:
    var winner_name: String = "PRENDI TU" if winner == "human" else "PRENDE TONY"
    trick_outcome_label.text = "%s  ·  +%d" % [winner_name, points]
    trick_outcome_label.visible = true
    trick_outcome_label.modulate = Color(1, 1, 1, 0)
    trick_outcome_label.scale = Vector2(0.92, 0.92)
    trick_outcome_label.pivot_offset = trick_outcome_label.size * 0.5

    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(trick_outcome_label, "modulate:a", 1.0, _anim_duration(0.18))
    tween.tween_property(trick_outcome_label, "scale", Vector2.ONE, _anim_duration(0.22))
    await tween.finished


func _capture_target_position(winner: String) -> Vector2:
    var pile: Control = human_taken_pile if winner == "human" else cpu_taken_pile
    var pile_card_size: Vector2 = small_card_size * 0.58
    return pile.global_position + pile_card_size * 0.18


func _pulse_capture_target(winner: String, points: int) -> void:
    var target_control: Control = human_capture_target if winner == "human" else cpu_capture_target
    var score_label := target_control.find_child("Score", true, false) as Label
    var new_score: int = int(engine.scores[winner])
    var old_score: int = max(0, new_score - points)
    if score_label != null:
        score_label.text = str(old_score)
        var count_tween := create_tween()
        count_tween.tween_method(_set_score_counter.bind(score_label), float(old_score), float(new_score), _anim_duration(0.28))

    target_control.pivot_offset = target_control.size * 0.5
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(target_control, "scale", Vector2(1.12, 1.12), _anim_duration(0.12))
    tween.tween_property(target_control, "scale", Vector2.ONE, _anim_duration(0.18))


func _set_score_counter(value: float, label: Label) -> void:
    label.text = str(int(round(value)))


func _animate_draw_card(draw_info: Dictionary, duration: float) -> void:
    var player: String = str(draw_info.get("player", ""))
    var card: Dictionary = draw_info.get("card", {})
    if player == "" or card.is_empty():
        return

    var is_trump_card: bool = bool(draw_info.get("is_trump_card", false))
    var source: Vector2 = _trump_source_position() if is_trump_card else _deck_source_position()
    var target_size: Vector2 = card_size if player == "human" else small_card_size
    var target_index: int = max(0, engine.hands[player].size() - 1)
    var target: Vector2 = _initial_deal_target(player, target_index, target_size)
    var start_texture: String = engine.card_texture_path(card) if is_trump_card else BACK_TEXTURE
    var floating := _floating_card(start_texture, small_card_size, source)
    floating.rotation = deg_to_rad(9.0 if is_trump_card else (-6.0 if player == "human" else 6.0))

    var midpoint: Vector2 = source.lerp(target, 0.58) + Vector2(0, -24.0)
    var first := create_tween()
    first.set_parallel(true)
    first.set_trans(Tween.TRANS_QUAD)
    first.set_ease(Tween.EASE_OUT)
    first.tween_property(floating, "position", midpoint, duration * 0.48)
    first.tween_property(floating, "size", small_card_size.lerp(target_size, 0.55), duration * 0.48)
    first.tween_property(floating, "rotation", floating.rotation * 0.35, duration * 0.48)
    await first.finished

    # Le pescate coperte si girano solo per il giocatore umano. L'ultima
    # briscola è già pubblica: vola scoperta verso chi la riceve.
    if player == "human" and not is_trump_card:
        floating.pivot_offset = floating.size * 0.5
        var close_flip := create_tween()
        close_flip.set_trans(Tween.TRANS_QUAD)
        close_flip.set_ease(Tween.EASE_IN)
        close_flip.tween_property(floating, "scale:x", 0.04, _anim_duration(0.055))
        await close_flip.finished
        floating.texture = load(engine.card_texture_path(card))
        var open_flip := create_tween()
        open_flip.set_trans(Tween.TRANS_QUAD)
        open_flip.set_ease(Tween.EASE_OUT)
        open_flip.tween_property(floating, "scale:x", 1.0, _anim_duration(0.07))
        await open_flip.finished

    var second := create_tween()
    second.set_parallel(true)
    second.set_trans(Tween.TRANS_CUBIC)
    second.set_ease(Tween.EASE_OUT)
    second.tween_property(floating, "position", target, duration * 0.52)
    second.tween_property(floating, "size", target_size, duration * 0.52)
    second.tween_property(floating, "rotation", 0.0, duration * 0.52)
    await second.finished

    _append_drawn_visual(player, card)
    floating.queue_free()


func _append_drawn_visual(player: String, card: Dictionary) -> void:
    if player == "human":
        var index: int = max(0, engine.hands["human"].size() - 1)
        var view := CardView.new()
        view.setup(card, index, load(engine.card_texture_path(card)), card_size, "%s · %d punti" % [engine.card_name(card), engine.points_for(card)])
        view.card_selected.connect(_on_player_card_pressed)
        var center_index: float = (float(engine.hands["human"].size()) - 1.0) * 0.5
        var fan_delta: float = float(index) - center_index
        view.set_fan_pose(fan_delta * 5.0, abs(fan_delta) * 4.0)
        view.set_interactive(false)
        player_hand.add_child(view)
    else:
        var back := _texture_card(BACK_TEXTURE, small_card_size)
        opponent_hand.add_child(back)


func _trump_source_position() -> Vector2:
    if deck_box != null and deck_box.get_child_count() > 0:
        var last := deck_box.get_child(deck_box.get_child_count() - 1) as Control
        return last.global_position
    return _deck_source_position()


func _show_phase_notice(text: String) -> void:
    if trick_outcome_label == null:
        return
    if table_turn_label != null:
        table_turn_label.visible = false
    trick_outcome_label.add_theme_font_size_override("font_size", 16)
    trick_outcome_label.text = text
    trick_outcome_label.visible = true
    trick_outcome_label.modulate = Color(1, 1, 1, 0)
    trick_outcome_label.scale = Vector2(0.96, 0.96)
    var appear := create_tween()
    appear.set_parallel(true)
    appear.set_trans(Tween.TRANS_QUAD)
    appear.set_ease(Tween.EASE_OUT)
    appear.tween_property(trick_outcome_label, "modulate:a", 1.0, _anim_duration(0.16))
    appear.tween_property(trick_outcome_label, "scale", Vector2.ONE, _anim_duration(0.18))
    await appear.finished
    await get_tree().create_timer(_anim_duration(0.62)).timeout
    var fade := create_tween()
    fade.tween_property(trick_outcome_label, "modulate:a", 0.0, _anim_duration(0.18))
    await fade.finished
    trick_outcome_label.visible = false
    trick_outcome_label.modulate = Color.WHITE
    trick_outcome_label.add_theme_font_size_override("font_size", 22)
    if table_turn_label != null:
        table_turn_label.visible = true


func _warm_runtime_assets() -> void:
    if _assets_warmed:
        return
    var paths: Array[String] = [BACK_TEXTURE, TABLE_TEXTURE, SFX_CARD, SFX_TAKE, SFX_SHUFFLE, SFX_WIN, SFX_LOSE]
    for suit in BriscolaEngine.SUITS:
        for rank in BriscolaEngine.RANKS:
            var card: Dictionary = {"suit": suit, "rank": rank}
            paths.append(engine.card_texture_path(card))

    var failed: Array[String] = []
    for path in paths:
        if ResourceLoader.load(path) == null:
            failed.append(path)
    if not failed.is_empty():
        push_error("Asset mancanti o non caricabili: %s" % [failed])
    _assets_warmed = failed.is_empty()


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


func _deck_display_size() -> Vector2:
    return small_card_size * 0.72 if compact_layout else small_card_size


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


func _card_slot() -> CenterContainer:
    var slot := CenterContainer.new()
    slot.custom_minimum_size = table_card_size
    slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _lead_badge() -> Label:
    var label := Label.new()
    label.text = "DI MANO"
    label.visible = false
    label.custom_minimum_size = Vector2(82, 28)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color("#f2dda0"))
    label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.96))
    label.add_theme_constant_override("outline_size", 5)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.z_index = 9
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


func _record_ai_feedback(rating: String) -> void:
    if rating not in ["too_easy", "fair", "too_hard"]:
        return
    var key: String = "ai_feedback_%s_%s" % [cpu_difficulty, rating]
    settings[key] = int(settings.get(key, 0)) + 1
    persistence.save_settings(settings)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.BriscolaSupport && window.BriscolaSupport.recordPlaytest(%s, %s, %d, %d);" % [JSON.stringify(cpu_difficulty), JSON.stringify(rating), int(engine.scores["human"]), int(engine.scores["cpu"])], true)
    if result_feedback_status != null:
        result_feedback_status.text = "Grazie · feedback salvato"
    if result_feedback_row != null:
        for child in result_feedback_row.get_children():
            if child is Button:
                (child as Button).disabled = true


func _open_feedback(kind: String = "general") -> void:
    if OS.has_feature("web"):
        var js_kind: String = JSON.stringify(kind)
        var opened: Variant = JavaScriptBridge.eval("Boolean(window.BriscolaSupport && window.BriscolaSupport.openFeedback(%s))" % js_kind, true)
        if bool(opened):
            return
    _set_status("Feedback: usa il link di supporto pubblicato insieme al gioco.")


func _maybe_run_web_qa() -> void:
    if not OS.has_feature("web"):
        return
    var mode_value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') || ''", true)
    var mode: String = str(mode_value)
    if mode.is_empty():
        return
    await _run_web_qa(mode)


func _set_web_qa_status(status: String) -> void:
    if not OS.has_feature("web"):
        return
    JavaScriptBridge.eval("window.__briscolaQaStatus = %s;" % JSON.stringify(status), true)


func _run_web_qa(mode: String) -> void:
    if mode == "4p":
        _set_web_qa_status("switching-4p")
        get_tree().change_scene_to_file("res://scenes/four_player.tscn")
        return
    _set_web_qa_status("starting")
    settings["tutorial_seen"] = true
    settings["reduced_motion"] = true
    settings["sound_enabled"] = false
    cpu_difficulty = "normal"
    settings["difficulty"] = cpu_difficulty
    persistence.save_settings(settings)
    if reduced_motion_toggle != null:
        reduced_motion_toggle.button_pressed = true
    if sound_toggle != null:
        sound_toggle.button_pressed = false

    if mode == "fresh":
        persistence.clear_saved_game()
        await _new_game()
        var human_moves := 0
        while not engine.is_game_over() and human_moves < 5:
            if not busy and engine.current_player == "human":
                human_moves += 1
                await _on_player_card_pressed(0)
            else:
                await get_tree().process_frame
        _save_progress()
        JavaScriptBridge.force_fs_sync()
        _set_web_qa_status("saved")
        return

    if mode == "resume":
        if not persistence.has_saved_game():
            _set_web_qa_status("failed-no-save")
            return
        await _resume_saved_game()
        var safety_moves := 0
        while not engine.is_game_over() and safety_moves < 40:
            if not busy and engine.current_player == "human":
                safety_moves += 1
                await _on_player_card_pressed(0)
            else:
                await get_tree().process_frame
        if engine.is_game_over():
            _set_web_qa_status("complete")
        else:
            _set_web_qa_status("failed-timeout")
        return

    if mode == "full":
        persistence.clear_saved_game()
        await _new_game()
        var full_safety_moves := 0
        while not engine.is_game_over() and full_safety_moves < 40:
            if not busy and engine.current_player == "human":
                full_safety_moves += 1
                await _on_player_card_pressed(0)
            else:
                await get_tree().process_frame
        _set_web_qa_status("complete" if engine.is_game_over() else "failed-timeout")
        return

    _set_web_qa_status("failed-unknown-mode")


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


func _on_viewport_size_changed() -> void:
    _apply_responsive_layout()


func _apply_responsive_layout() -> void:
    if game_margin == null:
        return
    var viewport_size: Vector2 = get_viewport_rect().size
    var window_size: Vector2i = DisplayServer.window_get_size()
    var short_side: int = min(window_size.x, window_size.y)
    var portrait_mode: bool = viewport_size.y > viewport_size.x
    compact_layout = portrait_mode or short_side < 650

    if compact_layout:
        if portrait_mode:
            card_size = COMPACT_CARD_SIZE
            small_card_size = COMPACT_SMALL_CARD_SIZE
            table_card_size = COMPACT_TABLE_CARD_SIZE
        else:
            card_size = MOBILE_LANDSCAPE_CARD_SIZE
            small_card_size = MOBILE_LANDSCAPE_SMALL_CARD_SIZE
            table_card_size = MOBILE_LANDSCAPE_TABLE_CARD_SIZE
        game_margin.add_theme_constant_override("margin_left", 10)
        game_margin.add_theme_constant_override("margin_right", 10)
        game_margin.add_theme_constant_override("margin_top", 8)
        game_margin.add_theme_constant_override("margin_bottom", 8)
        root_column.add_theme_constant_override("separation", 6)
        header.add_theme_constant_override("separation", 5)
        menu_button.text = "☰"
        menu_button.custom_minimum_size = Vector2(52, 42)
        help_button.custom_minimum_size = Vector2(44, 42)
        title_block.visible = false
        trick_label.custom_minimum_size = Vector2(102, 40)
        human_capture_target.custom_minimum_size = Vector2(88, 42)
        cpu_capture_target.custom_minimum_size = Vector2(88, 42)
        score_row.add_theme_constant_override("separation", 4)
        opponent_zone.custom_minimum_size.y = 172 if portrait_mode else 140
        player_zone.custom_minimum_size.y = 278 if portrait_mode else 205
        player_caption.text = "TOCCA UNA CARTA"
        player_caption.add_theme_font_size_override("font_size", 12)
        deck_panel.visible = false
        deck_panel.custom_minimum_size.x = 0
        info_panel.visible = false
        table_row.add_theme_constant_override("separation", 6)
        table_margin.add_theme_constant_override("margin_left", 10)
        table_margin.add_theme_constant_override("margin_right", 10)
        table_margin.add_theme_constant_override("margin_top", 9)
        table_margin.add_theme_constant_override("margin_bottom", 9)
        player_hand.add_theme_constant_override("separation", -14)
        opponent_hand.add_theme_constant_override("separation", -34)
        restart_button.text = "↻"
        restart_button.custom_minimum_size = Vector2(52, 38)
        status_label.add_theme_font_size_override("font_size", 13)
        menu_panel.custom_minimum_size = Vector2(560, 690)
        tutorial_panel.custom_minimum_size = Vector2(520, 410)
        menu_margin.add_theme_constant_override("margin_left", 32)
        menu_margin.add_theme_constant_override("margin_right", 32)
        result_panel.custom_minimum_size = Vector2(560, 520)
    else:
        card_size = BASE_CARD_SIZE
        small_card_size = BASE_SMALL_CARD_SIZE
        table_card_size = BASE_TABLE_CARD_SIZE
        game_margin.add_theme_constant_override("margin_left", 28)
        game_margin.add_theme_constant_override("margin_right", 28)
        game_margin.add_theme_constant_override("margin_top", 18)
        game_margin.add_theme_constant_override("margin_bottom", 18)
        root_column.add_theme_constant_override("separation", 10)
        header.add_theme_constant_override("separation", 14)
        menu_button.text = "☰  Menu"
        menu_button.custom_minimum_size = Vector2(108, 42)
        help_button.custom_minimum_size = Vector2(44, 42)
        title_block.visible = true
        trick_label.custom_minimum_size = Vector2(150, 38)
        human_capture_target.custom_minimum_size = Vector2(112, 44)
        cpu_capture_target.custom_minimum_size = Vector2(112, 44)
        score_row.add_theme_constant_override("separation", 8)
        opponent_zone.custom_minimum_size.y = 132
        player_zone.custom_minimum_size.y = 194
        player_caption.text = "LA TUA MANO  ·  scegli una carta"
        player_caption.add_theme_font_size_override("font_size", 13)
        deck_panel.visible = false
        deck_panel.custom_minimum_size.x = 0
        info_panel.visible = false
        table_row.add_theme_constant_override("separation", 18)
        table_margin.add_theme_constant_override("margin_left", 22)
        table_margin.add_theme_constant_override("margin_right", 22)
        table_margin.add_theme_constant_override("margin_top", 14)
        table_margin.add_theme_constant_override("margin_bottom", 14)
        player_hand.add_theme_constant_override("separation", 12)
        opponent_hand.add_theme_constant_override("separation", -42)
        restart_button.text = "Ricomincia"
        restart_button.custom_minimum_size = Vector2(128, 38)
        status_label.add_theme_font_size_override("font_size", 15)
        menu_panel.custom_minimum_size = Vector2(520, 690)
        tutorial_panel.custom_minimum_size = Vector2(520, 390)
        menu_margin.add_theme_constant_override("margin_left", 42)
        menu_margin.add_theme_constant_override("margin_right", 42)
        result_panel.custom_minimum_size = Vector2(540, 500)

    cpu_slot.custom_minimum_size = table_card_size
    human_slot.custom_minimum_size = table_card_size
    call_deferred("_layout_trick_slots")
    if game_screen.visible and not busy and engine.trump_suit != "":
        call_deferred("_refresh_after_layout_change")


func _layout_trick_slots() -> void:
    if trick_surface == null or cpu_slot == null or human_slot == null:
        return

    var surface_size: Vector2 = trick_surface.size
    if surface_size.x <= 1.0 or surface_size.y <= 1.0:
        return

    var slot_size: Vector2 = table_card_size
    cpu_slot.size = slot_size
    human_slot.size = slot_size
    cpu_slot.pivot_offset = slot_size * 0.5
    human_slot.pivot_offset = slot_size * 0.5

    var center: Vector2 = surface_size * 0.5
    var overlap_x: float = slot_size.x * 0.28
    cpu_slot.position = center - slot_size * 0.5 + Vector2(-overlap_x, -12.0)
    human_slot.position = center - slot_size * 0.5 + Vector2(overlap_x, 15.0)
    _apply_natural_table_pose()

    # Mazzo e briscola stanno fisicamente sul lato sinistro del tavolo.
    if table_deck_anchor != null:
        var deck_display: Vector2 = _deck_display_size()
        var deck_width: float = deck_display.x * 2.0
        var deck_height: float = deck_display.y + 48.0
        table_deck_anchor.size = Vector2(deck_width, deck_height)
        table_deck_anchor.position = Vector2(7.0, center.y - deck_height * 0.5)
        deck_box.position = Vector2(0, 0)
        deck_box.size = Vector2(deck_width, deck_display.y + 8.0)
        deck_box.add_theme_constant_override("separation", int(round(-deck_display.x * 0.70)))
        table_phase_label.position = Vector2(0, deck_display.y + 5.0)
        table_phase_label.size = Vector2(deck_width, 42.0)

    if table_turn_label != null:
        table_turn_label.position = Vector2(center.x - 90.0, 34.0)
        table_turn_label.size = Vector2(180.0, 30.0)

    if cpu_lead_badge != null:
        cpu_lead_badge.position = Vector2(center.x - 41.0, 4.0)
        cpu_lead_badge.size = Vector2(82.0, 28.0)
    if human_lead_badge != null:
        human_lead_badge.position = Vector2(center.x - 41.0, surface_size.y - 32.0)
        human_lead_badge.size = Vector2(82.0, 28.0)

    # Le prese vinte rimangono ai bordi del feltro: Tony in alto a destra,
    # il giocatore in basso a sinistra.
    if cpu_taken_pile != null and human_taken_pile != null:
        var pile_size: Vector2 = small_card_size * 0.58 + Vector2(18, 16)
        cpu_taken_pile.size = pile_size
        human_taken_pile.size = pile_size
        cpu_taken_pile.position = Vector2(surface_size.x - pile_size.x - 12.0, 12.0)
        human_taken_pile.position = Vector2(12.0, surface_size.y - pile_size.y - 12.0)


func _refresh_after_layout_change() -> void:
    if busy or not game_screen.visible:
        return
    _refresh_hands()
    _refresh_deck()
    _refresh_table()
    _refresh_capture_piles()
    _refresh_header()
    _set_hand_interaction(engine.current_player == "human")


func _anim_duration(base: float) -> float:
    if bool(settings.get("reduced_motion", false)):
        return min(base, 0.04)
    return base


func _difficulty_index(value: String) -> int:
    if value == "easy":
        return 0
    if value == "hard":
        return 2
    return 1


func _difficulty_display_name() -> String:
    if cpu_difficulty == "easy":
        return "Facile"
    if cpu_difficulty == "hard":
        return "Difficile"
    return "Normale"
