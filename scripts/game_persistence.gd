extends RefCounted
class_name GamePersistence

const SAVE_PATH := "user://briscola_save.json"
const SETTINGS_PATH := "user://briscola_settings.cfg"
const SAVE_VERSION := 2


func has_saved_game() -> bool:
    return FileAccess.file_exists(SAVE_PATH)


func save_game(engine_state: Dictionary, difficulty: String) -> bool:
    var payload: Dictionary = {
        "version": SAVE_VERSION,
        "difficulty": difficulty,
        "engine": engine_state,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
    }
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    file.close()
    return true


func load_game() -> Dictionary:
    if not has_saved_game():
        return {}
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    var raw: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    var payload: Dictionary = parsed
    if int(payload.get("version", -1)) != SAVE_VERSION:
        return {}
    if typeof(payload.get("engine", {})) != TYPE_DICTIONARY:
        return {}
    return payload


func clear_saved_game() -> void:
    var dir: DirAccess = DirAccess.open("user://")
    if dir != null and dir.file_exists("briscola_save.json"):
        dir.remove("briscola_save.json")


func load_settings() -> Dictionary:
    var defaults: Dictionary = {
        "difficulty": "normal",
        "sound_enabled": true,
        "reduced_motion": false,
        "games": 0,
        "wins": 0,
        "losses": 0,
        "draws": 0,
    }
    var config := ConfigFile.new()
    var error: Error = config.load(SETTINGS_PATH)
    if error != OK:
        return defaults

    var result: Dictionary = defaults.duplicate(true)
    result["difficulty"] = str(config.get_value("game", "difficulty", defaults["difficulty"]))
    result["sound_enabled"] = bool(config.get_value("audio", "sound_enabled", defaults["sound_enabled"]))
    result["reduced_motion"] = bool(config.get_value("accessibility", "reduced_motion", defaults["reduced_motion"]))
    result["games"] = int(config.get_value("stats", "games", defaults["games"]))
    result["wins"] = int(config.get_value("stats", "wins", defaults["wins"]))
    result["losses"] = int(config.get_value("stats", "losses", defaults["losses"]))
    result["draws"] = int(config.get_value("stats", "draws", defaults["draws"]))
    return result


func save_settings(settings: Dictionary) -> bool:
    var config := ConfigFile.new()
    config.set_value("game", "difficulty", str(settings.get("difficulty", "normal")))
    config.set_value("audio", "sound_enabled", bool(settings.get("sound_enabled", true)))
    config.set_value("accessibility", "reduced_motion", bool(settings.get("reduced_motion", false)))
    config.set_value("stats", "games", int(settings.get("games", 0)))
    config.set_value("stats", "wins", int(settings.get("wins", 0)))
    config.set_value("stats", "losses", int(settings.get("losses", 0)))
    config.set_value("stats", "draws", int(settings.get("draws", 0)))
    return config.save(SETTINGS_PATH) == OK


func record_result(settings: Dictionary, human_score: int, cpu_score: int) -> Dictionary:
    var updated: Dictionary = settings.duplicate(true)
    updated["games"] = int(updated.get("games", 0)) + 1
    if human_score > cpu_score:
        updated["wins"] = int(updated.get("wins", 0)) + 1
    elif cpu_score > human_score:
        updated["losses"] = int(updated.get("losses", 0)) + 1
    else:
        updated["draws"] = int(updated.get("draws", 0)) + 1
    save_settings(updated)
    return updated
