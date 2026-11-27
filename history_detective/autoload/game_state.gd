extends Node
## GameState (autoload) — прогресс, ағымдағы эпизод, бейімделу профилі және
## user:// ішіне JSON түрінде сақтау/жүктеу.

const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")
const SAVE_PATH := "user://history_detective_save.json"
const REPORT_PATH := "user://history_detective_report.json"
const SAVE_VERSION := 1

signal progress_changed

var data: Dictionary = {}
var current_episode_id: String = "ep1"
var last_record: Dictionary = {}   # соңғы аяқталған эпизодтың жазбасы (нәтиже экраны үшін)


func _ready() -> void:
	load_game()


func _empty_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"unlocked": 1,
		"best": {},
		"passed": {},
		"history": [],
		"profile": AdaptiveEngine.default_profile(),
		"sessions": 0,
		"created": Time.get_datetime_string_from_system(),
	}


func load_game() -> void:
	data = _empty_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Сақтау файлы бүлінген — жаңа прогресс басталды.")
		return
	for k in parsed.keys():
		data[k] = parsed[k]
	data["sessions"] = int(data.get("sessions", 0)) + 1
	save_game()


func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Сақтау мүмкін болмады: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func reset_progress() -> void:
	data = _empty_data()
	last_record = {}
	save_game()
	progress_changed.emit()


# ---------------- Прогресс ----------------

func unlocked_count() -> int:
	return int(data.get("unlocked", 1))


func is_unlocked(index: int) -> bool:
	return index <= unlocked_count()


func is_passed(episode_id: String) -> bool:
	return bool((data["passed"] as Dictionary).get(episode_id, false))


func passed_count() -> int:
	var n: int = 0
	for k in (data["passed"] as Dictionary).keys():
		if bool(data["passed"][k]):
			n += 1
	return n


func all_passed() -> bool:
	return passed_count() >= DataRepo.episode_count() and DataRepo.episode_count() > 0


func best_for(episode_id: String) -> Dictionary:
	return (data["best"] as Dictionary).get(episode_id, {})


func history() -> Array:
	return data.get("history", [])


func get_profile() -> Dictionary:
	return data.get("profile", AdaptiveEngine.default_profile())


## Эпизод аяқталғанда шақырылады: тарихқа жазу, үздік нәтиже, құлыпты ашу,
## бейімделу профилін қайта есептеу және дискіге сақтау.
func commit_record(record: Dictionary) -> void:
	var hist: Array = history()
	hist.append(record)
	data["history"] = hist
	var ep_id: String = str(record["episode_id"])
	var best: Dictionary = best_for(ep_id)
	if best.is_empty() or int(record["score"]) > int(best.get("score", 0)):
		data["best"][ep_id] = {
			"score": record["score"], "max": record["max_score"],
			"stars": record["stars"], "percent": record["percent"],
			"time_sec": record["time_sec"],
		}
	if bool(record["passed"]):
		data["passed"][ep_id] = true
		var next_index: int = int(record["episode_index"]) + 1
		if next_index > unlocked_count() and next_index <= DataRepo.episode_count():
			data["unlocked"] = next_index
	data["profile"] = AdaptiveEngine.profile_from_history(hist)
	last_record = record
	save_game()
	progress_changed.emit()


## Аналитика есебін бөлек JSON-ға экспорттау (мұғалімге беру үшін).
func export_report() -> String:
	var report: Dictionary = {
		"game": DataRepo.meta.get("title", ""),
		"exported": Time.get_datetime_string_from_system(),
		"profile": get_profile(),
		"weighted_metrics": AdaptiveEngine.weighted_metrics(history()),
		"history": history(),
		"best": data.get("best", {}),
	}
	var f: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	return ProjectSettings.globalize_path(REPORT_PATH)
