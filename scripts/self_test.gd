extends SceneTree

func _initialize() -> void:
    seed(123456)
    _test_card_rules()
    _test_initial_state()
    _test_complete_random_games()
    print("BriscolaEngine: self-test OK (rules + 200 simulated games)")
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

    var seen := {}
    for value in engine.deck:
        var card: Dictionary = value
        seen["%s-%d" % [str(card["suit"]), int(card["rank"])]] = true
    for player in ["human", "cpu"]:
        for value in engine.hands[player]:
            var card: Dictionary = value
            seen["%s-%d" % [str(card["suit"]), int(card["rank"])]] = true
    assert(seen.size() == 40)


func _test_complete_random_games() -> void:
    for _game_index in range(200):
        var engine := BriscolaEngine.new()
        engine.new_game()
        var guard := 0
        while not engine.is_game_over():
            guard += 1
            assert(guard < 100)
            var player: String = engine.current_player
            var hand: Array = engine.hands[player]
            assert(not hand.is_empty())
            var index := randi_range(0, hand.size() - 1)
            var card := engine.play_card(player, index)
            assert(not card.is_empty())
            if engine.table.size() == 2:
                var result := engine.resolve_trick()
                assert(not result.is_empty())

        assert(engine.scores["human"] + engine.scores["cpu"] == 120)
        assert(engine.trick_number == 21)
        assert(engine.deck.is_empty())
        assert(engine.hands["human"].is_empty())
        assert(engine.hands["cpu"].is_empty())
