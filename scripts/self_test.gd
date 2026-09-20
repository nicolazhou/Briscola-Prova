extends SceneTree

func _initialize() -> void:
    var engine := BriscolaEngine.new()

    var asso_coppe := {"suit": "coppe", "rank": 1}
    var tre_coppe := {"suit": "coppe", "rank": 3}
    var due_bastoni := {"suit": "bastoni", "rank": 2}
    var tre_spade := {"suit": "spade", "rank": 3}

    assert(engine.points_for(asso_coppe) == 11)
    assert(engine.points_for(tre_coppe) == 10)
    assert(not engine.second_card_wins(asso_coppe, tre_coppe, "bastoni"))
    assert(engine.second_card_wins(asso_coppe, due_bastoni, "bastoni"))
    assert(not engine.second_card_wins(tre_spade, asso_coppe, "bastoni"))

    engine.new_game()
    assert(engine.deck.size() == 34)
    assert(engine.hands["human"].size() == 3)
    assert(engine.hands["cpu"].size() == 3)
    assert(engine.trump_suit in BriscolaEngine.SUITS)

    print("BriscolaEngine: self-test OK")
    quit()
