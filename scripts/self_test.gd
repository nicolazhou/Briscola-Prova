extends SceneTree

const DIFFICULTIES := ["easy", "normal", "hard"]

func _initialize() -> void:
    seed(123456)
    _test_card_rules()
    _test_initial_state()
    _test_assets_exist()
    _test_state_roundtrip()
    _test_persistence_roundtrip()
    _test_ai_memory_contract()
    _test_draw_contract()
    _test_four_player_mode(300)
    _test_four_player_hard_ai_legality()
    _test_complete_random_games(300)
    _test_games_against_ai(100)
    print("BriscolaEngine: self-test OK (1v1 production + 4p teams + persistence + assets + 900 simulated games)")
    quit()


func _test_card_rules() -> void:
    var engine := BriscolaEngine.new()
    var asso_coppe := {"suit": "coppe", "rank": 1}
    var tre_coppe := {"suit": "coppe", "rank": 3}
    var due_bastoni := {"suit": "bastoni", "rank": 2}
    var tre_spade := {"suit": "spade", "rank": 3}

    assert(engine.points_for(asso_coppe) == 11)
    assert(engine.points_for(tre_coppe) == 10)
    assert(engine.points_for({"suit": "spade", "rank": 10}) == 4)
    assert(not engine.second_card_wins(asso_coppe, tre_coppe, "bastoni"))
    assert(engine.second_card_wins(asso_coppe, due_bastoni, "bastoni"))
    assert(not engine.second_card_wins(tre_spade, asso_coppe, "bastoni"))


func _test_initial_state() -> void:
    var engine := BriscolaEngine.new()
    engine.new_game()
    assert(engine.deck.size() == 34)
    assert(engine.hands["human"].size() == 3)
    assert(engine.hands["cpu"].size() == 3)
    assert(engine.trump_suit in BriscolaEngine.SUITS)
    assert(engine.played_history.is_empty())

    var seen := {}
    for value in engine.deck:
        var card: Dictionary = value
        seen[engine.card_key(card)] = true
    for player in ["human", "cpu"]:
        for value in engine.hands[player]:
            var card: Dictionary = value
            seen[engine.card_key(card)] = true
    assert(seen.size() == 40)
    assert(engine.unknown_cards_for_cpu().size() == 36)


func _test_assets_exist() -> void:
    var engine := BriscolaEngine.new()
    for suit in BriscolaEngine.SUITS:
        for rank in BriscolaEngine.RANKS:
            var card: Dictionary = {"suit": suit, "rank": rank}
            assert(FileAccess.file_exists(engine.card_texture_path(card)))
    assert(FileAccess.file_exists("res://assets/cards/retro.svg"))
    assert(FileAccess.file_exists("res://assets/audio/card_play.wav"))
    assert(FileAccess.file_exists("res://assets/audio/card_take.wav"))


func _test_state_roundtrip() -> void:
    var engine := BriscolaEngine.new()
    engine.new_game()

    # Salva anche uno stato a metà presa, il caso più importante per il resume.
    var human_card: Dictionary = engine.play_card("human", 0)
    assert(not human_card.is_empty())
    assert(engine.table.size() == 1)
    assert(engine.current_player == "cpu")

    var state: Dictionary = engine.to_dict()
    var json_text: String = JSON.stringify(state)
    var parsed: Variant = JSON.parse_string(json_text)
    assert(typeof(parsed) == TYPE_DICTIONARY)
    var restored_state: Dictionary = parsed
    var restored := BriscolaEngine.new()
    assert(restored.load_from_dict(restored_state))
    assert(restored.table.size() == 1)
    assert(restored.current_player == "cpu")
    assert(restored.deck.size() == engine.deck.size())
    assert(restored.hands["human"].size() == engine.hands["human"].size())
    assert(restored.hands["cpu"].size() == engine.hands["cpu"].size())
    var restored_play: Dictionary = restored.table[0]
    var original_play: Dictionary = engine.table[0]
    var restored_card: Dictionary = restored_play["card"]
    var original_card: Dictionary = original_play["card"]
    assert(restored.card_key(restored_card) == engine.card_key(original_card))

    var cpu_index: int = restored.choose_cpu_card("hard")
    assert(cpu_index >= 0 and cpu_index < restored.hands["cpu"].size())
    assert(not restored.play_card("cpu", cpu_index).is_empty())
    assert(not restored.resolve_trick().is_empty())
    assert(restored.played_history.size() == 2)


func _test_persistence_roundtrip() -> void:
    var persistence := GamePersistence.new()
    var settings_schema: Dictionary = persistence.load_settings()
    assert(settings_schema.has("tutorial_seen"))
    persistence.clear_saved_game()
    var engine := BriscolaEngine.new()
    engine.new_game()
    assert(persistence.save_game(engine.to_dict(), "hard"))
    assert(persistence.has_saved_game())
    var payload: Dictionary = persistence.load_game()
    assert(not payload.is_empty())
    assert(str(payload.get("difficulty", "")) == "hard")
    var state: Dictionary = payload.get("engine", {})
    var restored := BriscolaEngine.new()
    assert(restored.load_from_dict(state))
    assert(restored.deck.size() == 34)
    assert(restored.hands["human"].size() == 3)
    assert(restored.hands["cpu"].size() == 3)
    persistence.clear_saved_game()
    assert(not persistence.has_saved_game())


func _test_ai_memory_contract() -> void:
    var engine := BriscolaEngine.new()
    engine.new_game()
    assert(engine.unknown_cards_for_cpu().size() == 36)

    # La CPU risponde a una carta umana; la carta sul tavolo entra tra le informazioni note.
    assert(not engine.play_card("human", 0).is_empty())
    assert(engine.unknown_cards_for_cpu().size() == 35)
    var hard_index: int = engine.choose_cpu_card("hard")
    assert(hard_index >= 0 and hard_index < engine.hands["cpu"].size())
    assert(not engine.play_card("cpu", hard_index).is_empty())
    assert(engine.unknown_cards_for_cpu().size() == 35)
    assert(not engine.resolve_trick().is_empty())
    assert(engine.played_history.size() == 2)
    assert(engine.unknown_cards_for_cpu().size() == 34)



func _test_draw_contract() -> void:
    var engine := BriscolaEngine.new()
    engine.new_game()

    while engine.deck.size() > 2:
        var first_player: String = engine.current_player
        assert(not engine.play_card(first_player, 0).is_empty())
        var second_player: String = engine.current_player
        assert(not engine.play_card(second_player, 0).is_empty())
        var mid_result: Dictionary = engine.resolve_trick()
        assert(not mid_result.is_empty())
        var mid_draws: Array = mid_result.get("draws", [])
        assert(mid_draws.size() == 2)

    assert(engine.deck.size() == 2)
    var leader: String = engine.current_player
    assert(not engine.play_card(leader, 0).is_empty())
    var responder: String = engine.current_player
    assert(not engine.play_card(responder, 0).is_empty())
    var result: Dictionary = engine.resolve_trick()
    var draws: Array = result.get("draws", [])
    assert(draws.size() == 2)
    var first_draw: Dictionary = draws[0]
    var second_draw: Dictionary = draws[1]
    assert(not bool(first_draw.get("is_trump_card", false)))
    assert(bool(second_draw.get("is_trump_card", false)))
    var trump_drawn: Dictionary = second_draw.get("card", {})
    assert(engine.card_key(trump_drawn) == engine.card_key(engine.trump_card))
    assert(engine.deck.is_empty())

func _test_four_player_mode(count: int) -> void:
    var rules4 := FourPlayerEngine.new()
    rules4.trump_suit = "bastoni"
    rules4.table = [
        {"player": "human", "card": {"suit": "coppe", "rank": 5}},
        {"player": "right", "card": {"suit": "spade", "rank": 1}},
        {"player": "partner", "card": {"suit": "coppe", "rank": 1}},
        {"player": "left", "card": {"suit": "bastoni", "rank": 2}},
    ]
    assert(rules4.current_table_winner() == "left")

    var initial := FourPlayerEngine.new()
    initial.new_game("human")
    assert(initial.deck.size() == 28)
    for player in FourPlayerEngine.PLAYERS:
        var initial_hand: Array = initial.hands[player]
        assert(initial_hand.size() == 3)
    assert(initial.trump_suit in BriscolaEngine.SUITS)

    var serialized: Variant = JSON.parse_string(JSON.stringify(initial.to_dict()))
    assert(typeof(serialized) == TYPE_DICTIONARY)
    var restored := FourPlayerEngine.new()
    assert(restored.load_from_dict(serialized))
    assert(restored.deck.size() == 28)

    var mode_persistence := GamePersistence.new()
    mode_persistence.clear_mode_game(GameModes.TEAMS_4P)
    assert(mode_persistence.save_mode_game(GameModes.TEAMS_4P, initial.to_dict(), "normal"))
    var saved_4p: Dictionary = mode_persistence.load_mode_game(GameModes.TEAMS_4P)
    assert(str(saved_4p.get("mode", "")) == GameModes.TEAMS_4P)
    var restored_saved := FourPlayerEngine.new()
    assert(restored_saved.load_from_dict(saved_4p.get("engine", {})))
    mode_persistence.clear_mode_game(GameModes.TEAMS_4P)

    for game_index in range(count):
        var engine4 := FourPlayerEngine.new()
        engine4.new_game("human")
        var guard: int = 0
        while not engine4.is_game_over():
            guard += 1
            assert(guard < 100)
            var player: String = engine4.current_player
            var hand: Array = engine4.hands[player]
            assert(not hand.is_empty())
            var index: int = randi_range(0, hand.size() - 1) if player == "human" else engine4.choose_bot_card(player, "hard")
            assert(index >= 0 and index < hand.size())
            assert(not engine4.play_card(player, index).is_empty())
            if engine4.table.size() == 4:
                var result: Dictionary = engine4.resolve_trick()
                assert(not result.is_empty())
        assert(int(engine4.scores[FourPlayerEngine.TEAM_US]) + int(engine4.scores[FourPlayerEngine.TEAM_THEM]) == 120)
        assert(engine4.trick_number == 11)
        assert(engine4.played_history.size() == 40)
        assert(engine4.deck.is_empty())
        assert(engine4.table.is_empty())
        for player in FourPlayerEngine.PLAYERS:
            var final_hand: Array = engine4.hands[player]
            assert(final_hand.is_empty())


func _test_four_player_hard_ai_legality() -> void:
    var engine4 := FourPlayerEngine.new()
    engine4.new_game("right")
    var guard: int = 0
    while not engine4.is_game_over():
        guard += 1
        assert(guard < 100)
        var player: String = engine4.current_player
        var hand: Array = engine4.hands[player]
        assert(not hand.is_empty())
        var chosen: int = 0 if player == "human" else engine4.choose_bot_card(player, "hard")
        assert(chosen >= 0 and chosen < hand.size())
        assert(not engine4.play_card(player, chosen).is_empty())
        if engine4.table.size() == 4:
            assert(not engine4.resolve_trick().is_empty())
    assert(int(engine4.scores[FourPlayerEngine.TEAM_US]) + int(engine4.scores[FourPlayerEngine.TEAM_THEM]) == 120)


func _test_complete_random_games(count: int) -> void:
    for _game_index in range(count):
        var engine := BriscolaEngine.new()
        engine.new_game()
        _play_game(engine, "random")
        _assert_finished_game(engine)


func _test_games_against_ai(per_difficulty: int) -> void:
    for difficulty in DIFFICULTIES:
        for _game_index in range(per_difficulty):
            var engine := BriscolaEngine.new()
            engine.new_game()
            _play_game(engine, difficulty)
            _assert_finished_game(engine)


func _play_game(engine: BriscolaEngine, cpu_mode: String) -> void:
    var guard := 0
    while not engine.is_game_over():
        guard += 1
        assert(guard < 100)
        var player: String = engine.current_player
        var hand: Array = engine.hands[player]
        assert(not hand.is_empty())

        var index: int = 0
        if player == "cpu" and cpu_mode != "random":
            index = engine.choose_cpu_card(cpu_mode)
        else:
            index = randi_range(0, hand.size() - 1)
        assert(index >= 0 and index < hand.size())

        var card: Dictionary = engine.play_card(player, index)
        assert(not card.is_empty())
        _assert_live_invariants(engine)
        if engine.table.size() == 2:
            var result: Dictionary = engine.resolve_trick()
            assert(not result.is_empty())
            _assert_live_invariants(engine)


func _assert_live_invariants(engine: BriscolaEngine) -> void:
    assert(engine.table.size() <= 2)
    assert(engine.hands["human"].size() <= 3)
    assert(engine.hands["cpu"].size() <= 3)
    assert(int(engine.scores["human"]) >= 0)
    assert(int(engine.scores["cpu"]) >= 0)
    assert(int(engine.scores["human"]) + int(engine.scores["cpu"]) <= 120)

    var seen: Dictionary = {}
    var physical_count: int = 0
    for value in engine.deck:
        var card: Dictionary = value
        var key: String = engine.card_key(card)
        assert(not seen.has(key))
        seen[key] = true
        physical_count += 1
    for player in ["human", "cpu"]:
        for value in engine.hands[player]:
            var card: Dictionary = value
            var key: String = engine.card_key(card)
            assert(not seen.has(key))
            seen[key] = true
            physical_count += 1
        for value in engine.captured[player]:
            var card: Dictionary = value
            var key: String = engine.card_key(card)
            assert(not seen.has(key))
            seen[key] = true
            physical_count += 1
    for value in engine.table:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        var key: String = engine.card_key(card)
        assert(not seen.has(key))
        seen[key] = true
        physical_count += 1

    assert(physical_count == 40)


func _assert_finished_game(engine: BriscolaEngine) -> void:
    assert(engine.scores["human"] + engine.scores["cpu"] == 120)
    assert(engine.trick_number == 21)
    assert(engine.played_history.size() == 40)
    assert(engine.deck.is_empty())
    assert(engine.hands["human"].is_empty())
    assert(engine.hands["cpu"].is_empty())
    assert(engine.table.is_empty())
