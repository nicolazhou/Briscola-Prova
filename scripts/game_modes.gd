extends RefCounted
class_name GameModes

const CLASSIC_2P := "classic_2p"
const TEAMS_4P := "teams_4p"

static func catalog() -> Array[Dictionary]:
    return [
        {
            "id": CLASSIC_2P,
            "name": "Briscola classica",
            "players": 2,
            "status": "production",
            "description": "Tu contro Tony · 3 carte · pesca dopo ogni presa",
        },
        {
            "id": TEAMS_4P,
            "name": "Briscola a squadre",
            "players": 4,
            "status": "beta",
            "description": "Tu + compagno contro due avversari",
        },
    ]

static func display_name(mode_id: String) -> String:
    for mode in catalog():
        if str(mode.get("id", "")) == mode_id:
            return str(mode.get("name", mode_id))
    return mode_id
