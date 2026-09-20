extends RefCounted
class_name BriscolaEngine

const SUITS := ["bastoni", "coppe", "denari", "spade"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

const RANK_NAMES := {
    1: "Asso",
    2: "Due",
    3: "Tre",
    4: "Quattro",
    5: "Cinque",
    6: "Sei",
    7: "Sette",
    8: "Fante",
    9: "Cavallo",
    10: "Re",
}

const SUIT_NAMES := {
    "bastoni": "Bastoni",
    "coppe": "Coppe",
    "denari": "Denari",
    "spade": "Spade",
}

const POINTS := {
    1: 11,
    3: 10,
    10: 4,
    9: 3,
    8: 2,
}

const STRENGTH := {
    1: 10,
    3: 9,
    10: 8,
    9: 7,
    8: 6,
    7: 5,
    6: 4,
    5: 3,
    4: 2,
    2: 1,
}

var deck: Array = []
var hands := {"human": [], "cpu": []}
var table: Array = []
var captured := {"human": [], "cpu": []}
var scores := {"human": 0, "cpu": 0}
var current_player := "human"
var trump_card: Dictionary = {}
var trump_suit := ""
var trick_number := 1
var played_history: Array = []


func new_game() -> void:
    deck = []
    for suit in SUITS:
        for rank in RANKS:
            deck.append({"suit": suit, "rank": rank})
    deck.shuffle()

    hands = {"human": [], "cpu": []}
    table = []
    captured = {"human": [], "cpu": []}
    scores = {"human": 0, "cpu": 0}
    played_history = []
    trick_number = 1

    for _i in range(3):
        hands["human"].append(deck.pop_back())
    for _i in range(3):
        hands["cpu"].append(deck.pop_back())

    trump_card = deck.pop_back()
    trump_suit = str(trump_card["suit"])
    deck.push_front(trump_card)
    current_player = "human"


func play_card(player: String, hand_index: int) -> Dictionary:
    if player != current_player:
        return {}
    if table.size() >= 2:
        return {}
    if hand_index < 0 or hand_index >= hands[player].size():
        return {}

    var card: Dictionary = hands[player].pop_at(hand_index)
    table.append({"player": player, "card": card})

    if table.size() == 1:
        current_player = other_player(player)

    return card


func resolve_trick() -> Dictionary:
    if table.size() != 2:
        return {}

    var first: Dictionary = table[0]
    var second: Dictionary = table[1]
    var first_card: Dictionary = first["card"]
    var second_card: Dictionary = second["card"]
    var winner: String = str(first["player"])

    if second_card_wins(first_card, second_card, trump_suit):
        winner = str(second["player"])

    var trick_points: int = points_for(first_card) + points_for(second_card)
    scores[winner] += trick_points
    captured[winner].append(first_card)
    captured[winner].append(second_card)
    played_history.append(first_card.duplicate(true))
    played_history.append(second_card.duplicate(true))

    var loser: String = other_player(winner)
    for player in [winner, loser]:
        if not deck.is_empty():
            hands[player].append(deck.pop_back())

    current_player = winner
    table.clear()

    var result: Dictionary = {
        "winner": winner,
        "loser": loser,
        "points": trick_points,
        "trick": trick_number,
    }
    trick_number += 1
    return result


func choose_cpu_card(difficulty: String = "normal") -> int:
    var hand: Array = hands["cpu"]
    if hand.is_empty():
        return -1

    if difficulty == "easy":
        return randi_range(0, hand.size() - 1)
    if difficulty == "hard":
        return _choose_hard_card(hand)
    return _choose_normal_card(hand)


func _choose_normal_card(hand: Array) -> int:
    if table.size() == 1:
        var lead_play: Dictionary = table[0]
        var lead_card: Dictionary = lead_play["card"]
        var winning_indices: Array = []
        for i in range(hand.size()):
            var candidate: Dictionary = hand[i]
            if second_card_wins(lead_card, candidate, trump_suit):
                winning_indices.append(i)

        if not winning_indices.is_empty():
            return _lowest_cost_from_indices(hand, winning_indices)

    return _lowest_cost_index(hand)


func _choose_hard_card(hand: Array) -> int:
    # La difficoltà difficile usa solo informazioni legittimamente visibili:
    # mano CPU, briscola, tavolo e storico delle carte già uscite.
    if table.size() == 1:
        return _choose_hard_response(hand)
    return _choose_hard_lead(hand)


func _choose_hard_response(hand: Array) -> int:
    var lead_play: Dictionary = table[0]
    var lead_card: Dictionary = lead_play["card"]
    var winning_indices: Array = []
    var losing_indices: Array = []

    for i in range(hand.size()):
        var candidate: Dictionary = hand[i]
        if second_card_wins(lead_card, candidate, trump_suit):
            winning_indices.append(i)
        else:
            losing_indices.append(i)

    var lead_points: int = points_for(lead_card)
    var unknown_trumps: int = _count_unknown_trumps_for_cpu()
    var late_game: bool = deck.is_empty()

    if not winning_indices.is_empty():
        var cheapest_winner: int = _lowest_cost_from_indices(hand, winning_indices)
        var winner_card: Dictionary = hand[cheapest_winner]
        var total_prize: int = lead_points + points_for(winner_card)
        var spends_trump: bool = str(winner_card["suit"]) == trump_suit and str(lead_card["suit"]) != trump_suit

        # Prende carichi e prese importanti. Nel finale, senza più pesca, dà più peso
        # al controllo della mano e usa la memoria delle carte rimaste.
        if late_game or total_prize >= 10:
            return cheapest_winner
        if lead_points >= 4 and (not spends_trump or unknown_trumps <= 2):
            return cheapest_winner
        if not spends_trump and total_prize >= 4:
            return cheapest_winner

    if not losing_indices.is_empty():
        return _lowest_cost_from_indices(hand, losing_indices)
    if not winning_indices.is_empty():
        return _lowest_cost_from_indices(hand, winning_indices)
    return _lowest_cost_index(hand)


func _choose_hard_lead(hand: Array) -> int:
    var unknown_cards: Array = unknown_cards_for_cpu()
    var selected: int = 0
    var selected_score: int = _hard_lead_score(hand[0], unknown_cards)

    for i in range(1, hand.size()):
        var score: int = _hard_lead_score(hand[i], unknown_cards)
        if score < selected_score:
            selected = i
            selected_score = score
    return selected


func _hard_lead_score(card: Dictionary, unknown_cards: Array) -> int:
    var score: int = cpu_card_cost(card)
    var threats: int = 0
    for value in unknown_cards:
        var unknown: Dictionary = value
        if second_card_wins(card, unknown, trump_suit):
            threats += 1

    # Più carte non viste possono batterla, più è rischioso aprire con questa carta.
    score += threats * 17

    # Evita di aprire con carichi quando molte risposte avversarie possono prenderli.
    score += points_for(card) * threats * 5

    # A mazzo esaurito le carte non viste coincidono con quelle che possono essere
    # in mano all'avversario: una carta imbattibile diventa molto preziosa da giocare.
    if deck.is_empty() and threats == 0:
        score -= 170 + points_for(card) * 35 + strength_for(card) * 4

    # Conserva le briscole finché servono, tranne quando nel finale sono dominanti.
    if str(card["suit"]) == trump_suit and not deck.is_empty():
        score += 24
    return score


func unknown_cards_for_cpu() -> Array:
    var known: Dictionary = {}
    for value in hands["cpu"]:
        var own_card: Dictionary = value
        known[card_key(own_card)] = true
    for value in played_history:
        var played: Dictionary = value
        known[card_key(played)] = true
    for value in table:
        var play: Dictionary = value
        var table_card: Dictionary = play["card"]
        known[card_key(table_card)] = true

    # Finché il mazzo non è esaurito, la carta di briscola scoperta è nota e
    # non può trovarsi nella mano avversaria: la CPU la esclude dalle incognite.
    if not deck.is_empty() and not trump_card.is_empty():
        known[card_key(trump_card)] = true

    var unknown: Array = []
    for suit in SUITS:
        for rank in RANKS:
            var candidate: Dictionary = {"suit": suit, "rank": rank}
            if not known.has(card_key(candidate)):
                unknown.append(candidate)
    return unknown


func _count_unknown_trumps_for_cpu() -> int:
    var count: int = 0
    for value in unknown_cards_for_cpu():
        var card: Dictionary = value
        if str(card["suit"]) == trump_suit:
            count += 1
    return count


func _lowest_cost_index(hand: Array) -> int:
    var selected: int = 0
    var selected_cost: int = cpu_card_cost(hand[0])
    for i in range(1, hand.size()):
        var cost: int = cpu_card_cost(hand[i])
        if cost < selected_cost:
            selected = i
            selected_cost = cost
    return selected


func _lowest_cost_from_indices(hand: Array, indices: Array) -> int:
    var selected: int = int(indices[0])
    var selected_cost: int = cpu_card_cost(hand[selected])
    for value in indices:
        var index: int = int(value)
        var cost: int = cpu_card_cost(hand[index])
        if cost < selected_cost:
            selected = index
            selected_cost = cost
    return selected


func cpu_card_cost(card: Dictionary) -> int:
    var cost: int = points_for(card) * 100 + strength_for(card)
    if str(card["suit"]) == trump_suit:
        cost += 24
    return cost


func cpu_lead_cost(card: Dictionary) -> int:
    var cost: int = cpu_card_cost(card)
    if deck.is_empty():
        cost += strength_for(card) * 4
    return cost


func second_card_wins(first: Dictionary, second: Dictionary, trump: String) -> bool:
    if str(second["suit"]) == str(first["suit"]):
        return strength_for(second) > strength_for(first)

    if str(second["suit"]) == trump and str(first["suit"]) != trump:
        return true

    return false


func points_for(card: Dictionary) -> int:
    return int(POINTS.get(card["rank"], 0))


func strength_for(card: Dictionary) -> int:
    return int(STRENGTH[card["rank"]])


func other_player(player: String) -> String:
    return "cpu" if player == "human" else "human"


func is_game_over() -> bool:
    return deck.is_empty() and hands["human"].is_empty() and hands["cpu"].is_empty() and table.is_empty()


func result_text() -> String:
    var human_score: int = scores["human"]
    var cpu_score: int = scores["cpu"]
    if human_score > cpu_score:
        return "Hai vinto %d a %d" % [human_score, cpu_score]
    if cpu_score > human_score:
        return "Tony vince %d a %d" % [cpu_score, human_score]
    return "Pareggio: 60 a 60"


func card_name(card: Dictionary) -> String:
    return "%s di %s" % [RANK_NAMES[card["rank"]], SUIT_NAMES[card["suit"]]]


func card_texture_path(card: Dictionary) -> String:
    return "res://assets/cards/napoletane/%s/%02d.svg" % [str(card["suit"]), int(card["rank"])]


func card_key(card: Dictionary) -> String:
    return "%s-%d" % [str(card["suit"]), int(card["rank"])]


func to_dict() -> Dictionary:
    return {
        "deck": deck.duplicate(true),
        "hands": hands.duplicate(true),
        "table": table.duplicate(true),
        "captured": captured.duplicate(true),
        "scores": scores.duplicate(true),
        "current_player": current_player,
        "trump_card": trump_card.duplicate(true),
        "trump_suit": trump_suit,
        "trick_number": trick_number,
        "played_history": played_history.duplicate(true),
    }


func load_from_dict(state: Dictionary) -> bool:
    var required := ["deck", "hands", "table", "captured", "scores", "current_player", "trump_card", "trump_suit", "trick_number"]
    for key in required:
        if not state.has(key):
            return false

    if typeof(state["deck"]) != TYPE_ARRAY or typeof(state["hands"]) != TYPE_DICTIONARY:
        return false
    if typeof(state["table"]) != TYPE_ARRAY or typeof(state["captured"]) != TYPE_DICTIONARY:
        return false
    if typeof(state["scores"]) != TYPE_DICTIONARY or typeof(state["trump_card"]) != TYPE_DICTIONARY:
        return false

    var loaded_deck: Array = state["deck"]
    var loaded_hands: Dictionary = state["hands"]
    var loaded_table: Array = state["table"]
    var loaded_captured: Dictionary = state["captured"]
    var loaded_scores: Dictionary = state["scores"]

    if not loaded_hands.has("human") or not loaded_hands.has("cpu"):
        return false
    if not loaded_captured.has("human") or not loaded_captured.has("cpu"):
        return false
    if not loaded_scores.has("human") or not loaded_scores.has("cpu"):
        return false

    deck = _normalize_card_array(loaded_deck)
    hands = {
        "human": _normalize_card_array(loaded_hands["human"]),
        "cpu": _normalize_card_array(loaded_hands["cpu"]),
    }
    table = _normalize_table(loaded_table)
    captured = {
        "human": _normalize_card_array(loaded_captured["human"]),
        "cpu": _normalize_card_array(loaded_captured["cpu"]),
    }
    scores = {
        "human": int(loaded_scores["human"]),
        "cpu": int(loaded_scores["cpu"]),
    }
    current_player = str(state["current_player"])
    trump_card = _normalize_card(state["trump_card"])
    trump_suit = str(state["trump_suit"])
    trick_number = int(state["trick_number"])

    if state.has("played_history") and typeof(state["played_history"]) == TYPE_ARRAY:
        played_history = _normalize_card_array(state["played_history"])
    else:
        played_history = []
        for player in ["human", "cpu"]:
            for value in captured[player]:
                var captured_card: Dictionary = value
                played_history.append(captured_card.duplicate(true))

    return _validate_loaded_state()


func _normalize_card(card_value: Variant) -> Dictionary:
    if typeof(card_value) != TYPE_DICTIONARY:
        return {}
    var card: Dictionary = card_value
    if not card.has("suit") or not card.has("rank"):
        return {}
    return {"suit": str(card["suit"]), "rank": int(card["rank"])}


func _normalize_card_array(values_value: Variant) -> Array:
    var result: Array = []
    if typeof(values_value) != TYPE_ARRAY:
        return result
    var values: Array = values_value
    for value in values:
        var card: Dictionary = _normalize_card(value)
        if card.is_empty():
            return []
        result.append(card)
    return result


func _normalize_table(values_value: Variant) -> Array:
    var result: Array = []
    if typeof(values_value) != TYPE_ARRAY:
        return result
    var values: Array = values_value
    for value in values:
        if typeof(value) != TYPE_DICTIONARY:
            return []
        var play: Dictionary = value
        if not play.has("player") or not play.has("card"):
            return []
        var card: Dictionary = _normalize_card(play["card"])
        if card.is_empty():
            return []
        result.append({"player": str(play["player"]), "card": card})
    return result


func _validate_loaded_state() -> bool:
    if not hands.has("human") or not hands.has("cpu"):
        return false
    if not captured.has("human") or not captured.has("cpu"):
        return false
    if not scores.has("human") or not scores.has("cpu"):
        return false
    if current_player != "human" and current_player != "cpu":
        return false
    if trump_suit not in SUITS:
        return false
    if trump_card.is_empty() or str(trump_card.get("suit", "")) != trump_suit:
        return false
    if trick_number < 1 or trick_number > 21:
        return false
    if table.size() > 2 or deck.size() > 34:
        return false
    if hands["human"].size() > 3 or hands["cpu"].size() > 3:
        return false
    if int(scores["human"]) < 0 or int(scores["cpu"]) < 0:
        return false
    if int(scores["human"]) + int(scores["cpu"]) > 120:
        return false
    if played_history.size() != captured["human"].size() + captured["cpu"].size():
        return false
    if trick_number != int(played_history.size() / 2) + 1:
        return false

    var human_captured_points: int = 0
    for value in captured["human"]:
        var human_captured_card: Dictionary = value
        human_captured_points += points_for(human_captured_card)
    var cpu_captured_points: int = 0
    for value in captured["cpu"]:
        var cpu_captured_card: Dictionary = value
        cpu_captured_points += points_for(cpu_captured_card)
    if human_captured_points != int(scores["human"]) or cpu_captured_points != int(scores["cpu"]):
        return false

    var seen: Dictionary = {}
    var total_cards: int = 0
    for value in deck:
        var deck_card: Dictionary = value
        if not _register_unique_card(seen, deck_card):
            return false
        total_cards += 1
    for player in ["human", "cpu"]:
        for value in hands[player]:
            var hand_card: Dictionary = value
            if not _register_unique_card(seen, hand_card):
                return false
            total_cards += 1
        for value in captured[player]:
            var captured_card: Dictionary = value
            if not _register_unique_card(seen, captured_card):
                return false
            total_cards += 1
    for value in table:
        var play: Dictionary = value
        if not play.has("card") or not play.has("player"):
            return false
        var table_card: Dictionary = play["card"]
        if not _register_unique_card(seen, table_card):
            return false
        total_cards += 1

    return total_cards == 40


func _register_unique_card(seen: Dictionary, card: Dictionary) -> bool:
    if not card.has("suit") or not card.has("rank"):
        return false
    if str(card["suit"]) not in SUITS or int(card["rank"]) not in RANKS:
        return false
    var key: String = card_key(card)
    if seen.has(key):
        return false
    seen[key] = true
    return true
