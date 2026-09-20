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

# Ordine di presa nella Briscola: Asso, Tre, Re, Cavallo, Fante, 7, 6, 5, 4, 2.
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
    trick_number = 1

    # Tre carte a testa.
    for _i in range(3):
        hands["human"].append(deck.pop_back())
    for _i in range(3):
        hands["cpu"].append(deck.pop_back())

    # La carta successiva determina la briscola e resta in fondo al mazzo:
    # verrà pescata per ultima.
    trump_card = deck.pop_back()
    trump_suit = trump_card["suit"]
    deck.push_front(trump_card)

    # In questo prototipo il giocatore umano apre la prima presa.
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
    var winner := first["player"]

    if second_card_wins(first["card"], second["card"], trump_suit):
        winner = second["player"]

    var trick_points := points_for(first["card"]) + points_for(second["card"])
    scores[winner] += trick_points
    captured[winner].append(first["card"])
    captured[winner].append(second["card"])

    # Il vincitore pesca per primo e apre la presa successiva.
    var loser := other_player(winner)
    for player in [winner, loser]:
        if not deck.is_empty():
            hands[player].append(deck.pop_back())

    current_player = winner
    table.clear()

    var result := {
        "winner": winner,
        "points": trick_points,
        "trick": trick_number,
    }
    trick_number += 1
    return result


func choose_cpu_card() -> int:
    var hand: Array = hands["cpu"]
    if hand.is_empty():
        return -1

    # Se la CPU risponde a una carta, prova a vincere usando la carta meno costosa.
    if table.size() == 1:
        var lead_card: Dictionary = table[0]["card"]
        var winning_indices: Array = []
        for i in range(hand.size()):
            if second_card_wins(lead_card, hand[i], trump_suit):
                winning_indices.append(i)

        if not winning_indices.is_empty():
            var best_index: int = winning_indices[0]
            var best_cost := cpu_card_cost(hand[best_index])
            for index in winning_indices:
                var cost := cpu_card_cost(hand[index])
                if cost < best_cost:
                    best_cost = cost
                    best_index = index
            return best_index

    # Altrimenti conserva assi, tre e briscole importanti quando possibile.
    var selected := 0
    var selected_cost := cpu_card_cost(hand[0])
    for i in range(1, hand.size()):
        var cost := cpu_card_cost(hand[i])
        if cost < selected_cost:
            selected = i
            selected_cost = cost
    return selected


func cpu_card_cost(card: Dictionary) -> int:
    var cost := points_for(card) * 100 + strength_for(card)
    if card["suit"] == trump_suit:
        cost += 20
    return cost


func second_card_wins(first: Dictionary, second: Dictionary, trump: String) -> bool:
    if second["suit"] == first["suit"]:
        return strength_for(second) > strength_for(first)

    if second["suit"] == trump and first["suit"] != trump:
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
    return "res://assets/cards/napoletane/%s/%02d.svg" % [card["suit"], card["rank"]]
