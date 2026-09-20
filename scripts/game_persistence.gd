extends RefCounted
class_name GamePersistence

const SAVE_FILE := "briscola_save.json"
const TEMP_FILE := "briscola_save.tmp"
const BACKUP_FILE := "briscola_save.bak"
const SAVE_PATH := "user://" + SAVE_FILE
const TEMP_PATH := "user://" + TEMP_FILE
const BACKUP_PATH := "user://" + BACKUP_FILE
const SETTINGS_PATH := "user://briscola_settings.cfg"
const SAVE_VERSION := 2


func has_saved_game() -> bool:
    return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(TEMP_PATH) or FileAccess.file_exists(BACKUP_PATH)


func save_game(engine_state: Dictionary, difficulty: String) -> bool:
    var payload: Dictionary = {
        "version": SAVE_VERSION,
        "mode": GameModes.CLASSIC_2P,
        "app_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
        "difficulty": difficulty,
        "engine": engine_state,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
    }

    # Scrittura transazionale semplice: il file principale non viene toccato
    # finché il nuovo JSON non è stato scritto e flushato completamente.
    var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    file.flush()
    file.close()

    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        return false

    if dir.file_exists(BACKUP_FILE):
        dir.remove(BACKUP_FILE)

    if dir.file_exists(SAVE_FILE):
        var backup_error: Error = dir.rename(SAVE_FILE, BACKUP_FILE)
        if backup_error != OK:
            dir.remove(TEMP_FILE)
            return false

    var promote_error: Error = dir.rename(TEMP_FILE, SAVE_FILE)
    if promote_error != OK:
        # Best effort rollback: se la promozione fallisce, ripristina l'ultimo
        # save noto. TEMP resta recuperabile solo se il rename non l'ha mosso.
        if dir.file_exists(BACKUP_FILE) and not dir.file_exists(SAVE_FILE):
            dir.rename(BACKUP_FILE, SAVE_FILE)
        return false

    if dir.file_exists(BACKUP_FILE):
        dir.remove(BACKUP_FILE)
    return true


func load_game() -> Dictionary:
    # Ordine intenzionale: save ufficiale, eventuale temp completo lasciato da
    # una chiusura anomala, quindi backup dell'ultimo save valido.
    var candidate_paths: Array[String] = [SAVE_PATH, TEMP_PATH, BACKUP_PATH]
    for path in candidate_paths:
        var payload: Dictionary = _load_payload(path)
        if not payload.is_empty():
            return payload
    return {}


func _load_payload(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
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
    if dir == null:
        return
    var save_files: Array[String] = [SAVE_FILE, TEMP_FILE, BACKUP_FILE]
    for file_name in save_files:
        if dir.file_exists(file_name):
            dir.remove(file_name)


func load_settings() -> Dictionary:
    var defaults: Dictionary = {
        "difficulty": "normal",
        "sound_enabled": true,
        "reduced_motion": false,
        "tutorial_seen": false,
        "games": 0,
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "ai_feedback_easy_too_easy": 0,
        "ai_feedback_easy_fair": 0,
        "ai_feedback_easy_too_hard": 0,
        "ai_feedback_normal_too_easy": 0,
        "ai_feedback_normal_fair": 0,
        "ai_feedback_normal_too_hard": 0,
        "ai_feedback_hard_too_easy": 0,
        "ai_feedback_hard_fair": 0,
        "ai_feedback_hard_too_hard": 0,
        "team_feedback_easy_too_easy": 0,
        "team_feedback_easy_fair": 0,
        "team_feedback_easy_too_hard": 0,
        "team_feedback_normal_too_easy": 0,
        "team_feedback_normal_fair": 0,
        "team_feedback_normal_too_hard": 0,
        "team_feedback_hard_too_easy": 0,
        "team_feedback_hard_fair": 0,
        "team_feedback_hard_too_hard": 0,
    }
    var config := ConfigFile.new()
    var error: Error = config.load(SETTINGS_PATH)
    if error != OK:
        return defaults

    var result: Dictionary = defaults.duplicate(true)
    result["difficulty"] = str(config.get_value("game", "difficulty", defaults["difficulty"]))
    result["sound_enabled"] = bool(config.get_value("audio", "sound_enabled", defaults["sound_enabled"]))
    result["reduced_motion"] = bool(config.get_value("accessibility", "reduced_motion", defaults["reduced_motion"]))
    result["tutorial_seen"] = bool(config.get_value("onboarding", "tutorial_seen", defaults["tutorial_seen"]))
    result["games"] = int(config.get_value("stats", "games", defaults["games"]))
    result["wins"] = int(config.get_value("stats", "wins", defaults["wins"]))
    result["losses"] = int(config.get_value("stats", "losses", defaults["losses"]))
    result["draws"] = int(config.get_value("stats", "draws", defaults["draws"]))
    for difficulty in ["easy", "normal", "hard"]:
        for rating in ["too_easy", "fair", "too_hard"]:
            var key: String = "ai_feedback_%s_%s" % [difficulty, rating]
            result[key] = int(config.get_value("playtest", key, defaults[key]))
            var team_key: String = "team_feedback_%s_%s" % [difficulty, rating]
            result[team_key] = int(config.get_value("playtest", team_key, defaults[team_key]))
    return result


func save_settings(settings: Dictionary) -> bool:
    var config := ConfigFile.new()
    config.set_value("game", "difficulty", str(settings.get("difficulty", "normal")))
    config.set_value("audio", "sound_enabled", bool(settings.get("sound_enabled", true)))
    config.set_value("accessibility", "reduced_motion", bool(settings.get("reduced_motion", false)))
    config.set_value("onboarding", "tutorial_seen", bool(settings.get("tutorial_seen", false)))
    config.set_value("stats", "games", int(settings.get("games", 0)))
    config.set_value("stats", "wins", int(settings.get("wins", 0)))
    config.set_value("stats", "losses", int(settings.get("losses", 0)))
    config.set_value("stats", "draws", int(settings.get("draws", 0)))
    for difficulty in ["easy", "normal", "hard"]:
        for rating in ["too_easy", "fair", "too_hard"]:
            var key: String = "ai_feedback_%s_%s" % [difficulty, rating]
            config.set_value("playtest", key, int(settings.get(key, 0)))
            var team_key: String = "team_feedback_%s_%s" % [difficulty, rating]
            config.set_value("playtest", team_key, int(settings.get(team_key, 0)))
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


# Salvataggi separati per modalità aggiuntive. Il save 1v1 storico resta intatto,
# così gli utenti esistenti non perdono la partita durante la migrazione.
func has_mode_game(mode: String) -> bool:
    var paths: Dictionary = _mode_paths(mode)
    return FileAccess.file_exists(paths["save"]) or FileAccess.file_exists(paths["temp"]) or FileAccess.file_exists(paths["backup"])


func save_mode_game(mode: String, engine_state: Dictionary, difficulty: String) -> bool:
    var paths: Dictionary = _mode_paths(mode)
    var payload: Dictionary = {
        "version": 1,
        "mode": mode,
        "difficulty": difficulty,
        "engine": engine_state,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "app_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
    }
    return _write_transactional(paths, payload)


func load_mode_game(mode: String) -> Dictionary:
    var paths: Dictionary = _mode_paths(mode)
    for path in [paths["save"], paths["temp"], paths["backup"]]:
        var payload: Dictionary = _load_mode_payload(str(path), mode)
        if not payload.is_empty():
            return payload
    return {}


func clear_mode_game(mode: String) -> void:
    var paths: Dictionary = _mode_paths(mode)
    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        return
    for file_name in [paths["save_file"], paths["temp_file"], paths["backup_file"]]:
        if dir.file_exists(str(file_name)):
            dir.remove(str(file_name))


func _mode_paths(mode: String) -> Dictionary:
    var safe_mode: String = mode.replace("/", "_").replace("\\", "_").replace("..", "_")
    var base: String = "briscola_%s" % safe_mode
    return {
        "save_file": base + ".json",
        "temp_file": base + ".tmp",
        "backup_file": base + ".bak",
        "save": "user://" + base + ".json",
        "temp": "user://" + base + ".tmp",
        "backup": "user://" + base + ".bak",
    }


func _write_transactional(paths: Dictionary, payload: Dictionary) -> bool:
    var file: FileAccess = FileAccess.open(str(paths["temp"]), FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    file.flush()
    file.close()

    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        return false
    var save_file: String = str(paths["save_file"])
    var temp_file: String = str(paths["temp_file"])
    var backup_file: String = str(paths["backup_file"])

    if dir.file_exists(backup_file):
        dir.remove(backup_file)
    if dir.file_exists(save_file):
        if dir.rename(save_file, backup_file) != OK:
            dir.remove(temp_file)
            return false
    if dir.rename(temp_file, save_file) != OK:
        if dir.file_exists(backup_file) and not dir.file_exists(save_file):
            dir.rename(backup_file, save_file)
        return false
    if dir.file_exists(backup_file):
        dir.remove(backup_file)
    return true


func _load_mode_payload(path: String, expected_mode: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    var payload: Dictionary = parsed
    if int(payload.get("version", -1)) != 1 or str(payload.get("mode", "")) != expected_mode:
        return {}
    if typeof(payload.get("engine", {})) != TYPE_DICTIONARY:
        return {}
    return payload
