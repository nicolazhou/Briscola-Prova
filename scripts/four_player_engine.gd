extends RefCounted
class_name FourPlayerEngine

const PLAYERS := ["human", "right", "partner", "left"]
const TEAM_US := "us"
const TEAM_THEM := "them"
const PLAYER_TEAM := {
    "human": TEAM_US,
    "partner": TEAM_US,
    "right": TEAM_THEM,
    "left": TEAM_THEM,
}

var deck: Array = []
var hands: Dictionary = {}
var table: Array = []
var captured := {TEAM_US: [], TEAM_THEM: []}
var scores := {TEAM_US: 0, TEAM_THEM: 0}
var trick_wins := {TEAM_US: 0, TEAM_THEM: 0}
var current_player := "human"
var trump_card: Dictionary = {}
var trump_suit := ""
var trick_number := 1
var played_history: Array = []


func new_game(start_player: String = "human") -> void:
    deck = []
    for suit in BriscolaEngine.SUITS:
        for rank in BriscolaEngine.RANKS:
            deck.append({"suit": suit, "rank": rank})
    deck.shuffle()

    hands = {}
    for player in PLAYERS:
        hands[player] = []
    table = []
    captured = {TEAM_US: [], TEAM_THEM: []}
    scores = {TEAM_US: 0, TEAM_THEM: 0}
    trick_wins = {TEAM_US: 0, TEAM_THEM: 0}
    played_history = []
    trick_number = 1

    var deal_order: Array = order_from(start_player)
    for _round in range(3):
        for player in deal_order:
            hands[player].append(deck.pop_back())

    trump_card = deck.pop_back()
    trump_suit = str(trump_card["suit"])
    deck.push_front(trump_card)
    current_player = start_player if start_player in PLAYERS else "human"


func play_card(player: String, hand_index: int) -> Dictionary:
    if player != current_player or table.size() >= 4:
        return {}
    if not hands.has(player):
        return {}
    var hand: Array = hands[player]
    if hand_index < 0 or hand_index >= hand.size():
        return {}

    var card: Dictionary = hand.pop_at(hand_index)
    table.append({"player": player, "card": card})
    if table.size() < 4:
        current_player = next_player(player)
    return card


func resolve_trick() -> Dictionary:
    if table.size() != 4:
        return {}

    var winner_play: Dictionary = table[0]
    var lead_card: Dictionary = winner_play["card"]
    var lead_suit: String = str(lead_card["suit"])
    var points: int = 0

    for value in table:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        points += points_for(card)
        var current_card: Dictionary = winner_play["card"]
        if _candidate_beats(current_card, card, lead_suit):
            winner_play = play

    var winner: String = str(winner_play["player"])
    var team: String = team_for(winner)
    scores[team] = int(scores[team]) + points
    trick_wins[team] = int(trick_wins[team]) + 1

    var played_cards: Array = []
    for value in table:
        var play: Dictionary = value
        var card: Dictionary = play["card"]
        captured[team].append(card)
        played_history.append(card.duplicate(true))
        played_cards.append(card.duplicate(true))

    var draws: Array = []
    for player in order_from(winner):
        if deck.is_empty():
            break
        var drawn: Dictionary = deck.pop_back()
        hands[player].append(drawn)
        draws.append({
            "player": player,
            "card": drawn.duplicate(true),
            "is_trump_card": card_key(drawn) == card_key(trump_card),
        })

    table.clear()
    current_player = winner
    var result: Dictionary = {
        "winner": winner,
        "team": team,
        "points": points,
        "trick": trick_number,
        "cards": played_cards,
        "draws": draws,
    }
    trick_number += 1
    return result


func choose_bot_card(player: String, difficulty: String = "normal") -> int:
    if player == "human" or not hands.has(player):
        return -1
    var hand: Array = hands[player]
    if hand.is_empty():
        return -1
    if difficulty == "easy":
        return randi_range(0, hand.size() - 1)
    if difficulty == "hard":
        return _choose_hard_team_card(player, hand)

    if table.is_empty():
        return _lowest_cost_index(hand, false)

    var current_winner: String = current_table_winner()
    var partner_winning: bool = team_for(current_winner) == team_for(player)
    var winning: Array = []
    var losing: Array = []
    for i in range(hand.size()):
        if candidate_would_win(hand[i]):
            winning.append(i)
        else:
            losing.append(i)

    # Se il compagno sta già vincendo, evita di sprecare una briscola o un carico.
    if partner_winning and not losing.is_empty():
        return _lowest_cost_from_indices(hand, losing, false)

    var trick_points: int = table_points()
    if not winning.is_empty() and trick_points >= 4:
        return _lowest_cost_from_indices(hand, winning, false)
    if not losing.is_empty():
        return _lowest_cost_from_indices(hand, losing, false)
    if not winning.is_empty():
        return _lowest_cost_from_indices(hand, winning, false)
    return 0


func _choose_hard_team_card(player: String, hand: Array) -> int:
    # Strategia di squadra senza leggere le mani nascoste o l'ordine del mazzo.
    # Usa solo tavolo, mano propria e carte già uscite.
    if table.is_empty():
        return _hard_lead_index(hand)

    var current_winner: String = current_table_winner()
    var partner_winning: bool = team_for(current_winner) == team_for(player)
    var winning: Array = []
    var losing: Array = []
    for i in range(hand.size()):
        if candidate_would_win(hand[i]):
            winning.append(i)
        else:
            losing.append(i)

    var trick_points_now: int = table_points()
    var late_game: bool = deck.is_empty()

    if partner_winning:
        # Se la presa appare al sicuro, passa punti al compagno evitando di
        # bruciare una briscola importante. È una scelta tipicamente "di coppia".
        if _current_team_win_looks_secure(player):
            var dump_index: int = _highest_safe_point_index(hand)
            if dump_index >= 0:
                return dump_index
        if not losing.is_empty():
            return _lowest_cost_from_indices(hand, losing, true)
        return _lowest_cost_from_indices(hand, winning, true) if not winning.is_empty() else 0

    # Se stanno vincendo gli avversari, recupera la presa quando contiene punti
    # o nel finale; altrimenti conserva le risorse migliori.
    if not winning.is_empty() and (trick_points_now >= 3 or late_game):
        return _lowest_cost_from_indices(hand, winning, true)
    if not losing.is_empty():
        return _lowest_cost_from_indices(hand, losing, true)
    if not winning.is_empty():
        return _lowest_cost_from_indices(hand, winning, true)
    return 0


func _hard_lead_index(hand: Array) -> int:
    # In apertura conserva assi/tre e briscole. Nel finale senza mazzo la forza
    # conta di più, ma resta preferibile scaricare una carta economica.
    var best: int = 0
    var best_cost: int = 1000000
    for i in range(hand.size()):
        var card: Dictionary = hand[i]
        var cost: int = card_cost(card, true)
        if deck.is_empty():
            cost -= strength_for(card) * 2
        if cost < best_cost:
            best = i
            best_cost = cost
    return best


func _highest_safe_point_index(hand: Array) -> int:
    var selected: int = -1
    var selected_points: int = -1
    var selected_cost: int = 1000000
    for i in range(hand.size()):
        var card: Dictionary = hand[i]
        # Non regaliamo una briscola alta solo per aggiungere pochi punti.
        if str(card["suit"]) == trump_suit and strength_for(card) >= BriscolaEngine.STRENGTH[8]:
            continue
        var points: int = points_for(card)
        var cost: int = card_cost(card, true)
        if points > selected_points or (points == selected_points and cost < selected_cost):
            selected = i
            selected_points = points
            selected_cost = cost
    return selected


func _current_team_win_looks_secure(player: String) -> bool:
    if table.is_empty():
        return false
    # Se dopo questo giocatore non giocherà più nessun avversario, la presa è
    # matematicamente al sicuro. Negli altri casi usiamo una stima conservativa
    # basata sulle carte ancora non viste, senza consultare deck/mano avversaria.
    var remaining_after_me: Array = []
    var cursor: String = next_player(player)
    var remaining_count: int = 4 - table.size() - 1
    for _i in range(maxi(remaining_count, 0)):
        remaining_after_me.append(cursor)
        cursor = next_player(cursor)
    var enemy_remains: bool = false
    for remaining_player in remaining_after_me:
        if team_for(str(remaining_player)) != team_for(player):
            enemy_remains = true
            break
    if not enemy_remains:
        return true

    var winner_name: String = current_table_winner()
    var winner_card: Dictionary = {}
    var lead_card: Dictionary = table[0]["card"]
    var lead_suit: String = str(lead_card["suit"])
    for value in table:
        var play: Dictionary = value
        if str(play["player"]) == winner_name:
            winner_card = play["card"]
            break
    if winner_card.is_empty():
        return false

    for value in _unseen_cards_for_ai(player):
        var unseen_card: Dictionary = value
        if _candidate_beats(winner_card, unseen_card, lead_suit):
            return false
    return true


func _unseen_cards_for_ai(player: String) -> Array:
    var seen: Dictionary = {}
    for value in played_history:
        var played_card: Dictionary = value
        seen[card_key(played_card)] = true
    for value in table:
        var play: Dictionary = value
        seen[card_key(play["card"])] = true
    var own_hand: Array = hands.get(player, [])
    for value in own_hand:
        var own_card: Dictionary = value
        seen[card_key(own_card)] = true

    var result: Array = []
    for suit in BriscolaEngine.SUITS:
        for rank in BriscolaEngine.RANKS:
            var card: Dictionary = {"suit": suit, "rank": rank}
            if not seen.has(card_key(card)):
                result.append(card)
    return result


func table_points() -> int:
    var total: int = 0
    for value in table:
        var play: Dictionary = value
        total += points_for(play["card"])
    return total


func partner_of(player: String) -> String:
    if player == "human":
        return "partner"
    if player == "partner":
        return "human"
    if player == "left":
        return "right"
    return "left"


func current_table_winner() -> String:
    if table.is_empty():
        return ""
    var winner_play: Dictionary = table[0]
    var first_card: Dictionary = winner_play["card"]
    var lead_suit: String = str(first_card["suit"])
    for i in range(1, table.size()):
        var play: Dictionary = table[i]
        var current_card: Dictionary = winner_play["card"]
        var candidate: Dictionary = play["card"]
        if _candidate_beats(current_card, candidate, lead_suit):
            winner_play = play
    return str(winner_play["player"])


func candidate_would_win(candidate: Dictionary) -> bool:
    if table.is_empty():
        return true
    var lead_play: Dictionary = table[0]
    var lead_card: Dictionary = lead_play["card"]
    var lead_suit: String = str(lead_card["suit"])
    var current_player_name: String = current_table_winner()
    var current_card: Dictionary = {}
    for value in table:
        var play: Dictionary = value
        if str(play["player"]) == current_player_name:
            current_card = play["card"]
            break
    return _candidate_beats(current_card, candidate, lead_suit)


func _candidate_beats(current: Dictionary, candidate: Dictionary, lead_suit: String) -> bool:
    var current_suit: String = str(current["suit"])
    var candidate_suit: String = str(candidate["suit"])

    if current_suit == trump_suit:
        return candidate_suit == trump_suit and strength_for(candidate) > strength_for(current)
    if candidate_suit == trump_suit:
        return true

    if current_suit == lead_suit:
        return candidate_suit == lead_suit and strength_for(candidate) > strength_for(current)
    return candidate_suit == lead_suit


func _lowest_cost_index(hand: Array, conserve_trump: bool) -> int:
    var indices: Array = []
    for i in range(hand.size()):
        indices.append(i)
    return _lowest_cost_from_indices(hand, indices, conserve_trump)


func _lowest_cost_from_indices(hand: Array, indices: Array, conserve_trump: bool) -> int:
    var selected: int = int(indices[0])
    var selected_cost: int = card_cost(hand[selected], conserve_trump)
    for value in indices:
        var index: int = int(value)
        var cost: int = card_cost(hand[index], conserve_trump)
        if cost < selected_cost:
            selected = index
            selected_cost = cost
    return selected


func card_cost(card: Dictionary, conserve_trump: bool = true) -> int:
    var cost: int = points_for(card) * 100 + strength_for(card)
    if conserve_trump and str(card["suit"]) == trump_suit:
        cost += 28
    return cost


func next_player(player: String) -> String:
    var index: int = PLAYERS.find(player)
    if index < 0:
        return PLAYERS[0]
    return str(PLAYERS[(index + 1) % PLAYERS.size()])


func order_from(player: String) -> Array:
    var result: Array = []
    var current: String = player if player in PLAYERS else str(PLAYERS[0])
    for _i in range(PLAYERS.size()):
        result.append(current)
        current = next_player(current)
    return result


func team_for(player: String) -> String:
    return str(PLAYER_TEAM.get(player, TEAM_THEM))


func points_for(card: Dictionary) -> int:
    return int(BriscolaEngine.POINTS.get(card["rank"], 0))


func strength_for(card: Dictionary) -> int:
    return int(BriscolaEngine.STRENGTH[card["rank"]])


func card_name(card: Dictionary) -> String:
    return "%s di %s" % [BriscolaEngine.RANK_NAMES[card["rank"]], BriscolaEngine.SUIT_NAMES[card["suit"]]]


func card_texture_path(card: Dictionary) -> String:
    return "res://assets/cards/napoletane/%s/%02d.svg" % [str(card["suit"]), int(card["rank"])]


func card_key(card: Dictionary) -> String:
    return "%s-%d" % [str(card["suit"]), int(card["rank"])]


func is_game_over() -> bool:
    if not deck.is_empty() or not table.is_empty():
        return false
    for player in PLAYERS:
        var hand: Array = hands[player]
        if not hand.is_empty():
            return false
    return true


func result_text() -> String:
    var ours: int = int(scores[TEAM_US])
    var theirs: int = int(scores[TEAM_THEM])
    if ours > theirs:
        return "Vinciamo %d a %d" % [ours, theirs]
    if theirs > ours:
        return "Perdiamo %d a %d" % [ours, theirs]
    return "Pareggio 60 a 60"


func to_dict() -> Dictionary:
    return {
        "deck": deck.duplicate(true),
        "hands": hands.duplicate(true),
        "table": table.duplicate(true),
        "captured": captured.duplicate(true),
        "scores": scores.duplicate(true),
        "trick_wins": trick_wins.duplicate(true),
        "current_player": current_player,
        "trump_card": trump_card.duplicate(true),
        "trump_suit": trump_suit,
        "trick_number": trick_number,
        "played_history": played_history.duplicate(true),
    }


func load_from_dict(state: Dictionary) -> bool:
    var required: Array = ["deck", "hands", "table", "captured", "scores", "current_player", "trump_card", "trump_suit", "trick_number"]
    for key in required:
        if not state.has(key):
            return false
    if typeof(state["hands"]) != TYPE_DICTIONARY or typeof(state["scores"]) != TYPE_DICTIONARY:
        return false

    deck = _normalize_card_array(state["deck"])
    hands = {}
    var loaded_hands: Dictionary = state["hands"]
    for player in PLAYERS:
        if not loaded_hands.has(player):
            return false
        hands[player] = _normalize_card_array(loaded_hands[player])

    table = _normalize_table(state["table"])
    var loaded_captured: Dictionary = state["captured"]
    captured = {
        TEAM_US: _normalize_card_array(loaded_captured.get(TEAM_US, [])),
        TEAM_THEM: _normalize_card_array(loaded_captured.get(TEAM_THEM, [])),
    }
    var loaded_scores: Dictionary = state["scores"]
    scores = {TEAM_US: int(loaded_scores.get(TEAM_US, 0)), TEAM_THEM: int(loaded_scores.get(TEAM_THEM, 0))}
    var loaded_wins: Dictionary = state.get("trick_wins", {})
    trick_wins = {TEAM_US: int(loaded_wins.get(TEAM_US, 0)), TEAM_THEM: int(loaded_wins.get(TEAM_THEM, 0))}
    current_player = str(state["current_player"])
    trump_card = _normalize_card(state["trump_card"])
    trump_suit = str(state["trump_suit"])
    trick_number = int(state["trick_number"])
    played_history = _normalize_card_array(state.get("played_history", []))
    return _validate_state()


func _normalize_card(value: Variant) -> Dictionary:
    if typeof(value) != TYPE_DICTIONARY:
        return {}
    var card: Dictionary = value
    if not card.has("suit") or not card.has("rank"):
        return {}
    return {"suit": str(card["suit"]), "rank": int(card["rank"])}


func _normalize_card_array(value: Variant) -> Array:
    var result: Array = []
    if typeof(value) != TYPE_ARRAY:
        return result
    for item in value:
        var card: Dictionary = _normalize_card(item)
        if card.is_empty():
            return []
        result.append(card)
    return result


func _normalize_table(value: Variant) -> Array:
    var result: Array = []
    if typeof(value) != TYPE_ARRAY:
        return result
    for item in value:
        if typeof(item) != TYPE_DICTIONARY:
            return []
        var play: Dictionary = item
        var card: Dictionary = _normalize_card(play.get("card", {}))
        var player: String = str(play.get("player", ""))
        if card.is_empty() or player not in PLAYERS:
            return []
        result.append({"player": player, "card": card})
    return result


func _validate_state() -> bool:
    if current_player not in PLAYERS or trump_suit not in BriscolaEngine.SUITS:
        return false
    if trump_card.is_empty() or str(trump_card.get("suit", "")) != trump_suit:
        return false
    if table.size() > 4 or trick_number < 1 or trick_number > 11:
        return false
    if int(scores[TEAM_US]) < 0 or int(scores[TEAM_THEM]) < 0:
        return false
    if int(scores[TEAM_US]) + int(scores[TEAM_THEM]) > 120:
        return false
    if played_history.size() != captured[TEAM_US].size() + captured[TEAM_THEM].size():
        return false
    if played_history.size() % 4 != 0:
        return false
    if trick_number != int(played_history.size() / 4) + 1:
        return false
    if int(trick_wins[TEAM_US]) + int(trick_wins[TEAM_THEM]) != int(played_history.size() / 4):
        return false

    var us_points: int = 0
    for value in captured[TEAM_US]:
        var card_us: Dictionary = value
        us_points += points_for(card_us)
    var them_points: int = 0
    for value in captured[TEAM_THEM]:
        var card_them: Dictionary = value
        them_points += points_for(card_them)
    if us_points != int(scores[TEAM_US]) or them_points != int(scores[TEAM_THEM]):
        return false

    var seen: Dictionary = {}
    var total: int = 0
    for value in deck:
        if not _register_card(seen, value):
            return false
        total += 1
    for player in PLAYERS:
        var hand: Array = hands[player]
        if hand.size() > 3:
            return false
        for value in hand:
            if not _register_card(seen, value):
                return false
            total += 1
    for team in [TEAM_US, TEAM_THEM]:
        for value in captured[team]:
            if not _register_card(seen, value):
                return false
            total += 1
    for value in table:
        var play: Dictionary = value
        if not _register_card(seen, play["card"]):
            return false
        total += 1
    return total == 40


func _register_card(seen: Dictionary, value: Variant) -> bool:
    var card: Dictionary = _normalize_card(value)
    if card.is_empty():
        return false
    if str(card["suit"]) not in BriscolaEngine.SUITS or int(card["rank"]) not in BriscolaEngine.RANKS:
        return false
    var key: String = card_key(card)
    if seen.has(key):
        return false
    seen[key] = true
    return true
