extends Node
## DataRepo (autoload) — res://data/episodes.json мазмұнын жүктейді және
## эпизодтарға, карточкаларға, сенімділік белгілеріне қол жеткізу береді.

const DATA_PATH := "res://data/episodes.json"

var meta: Dictionary = {}
var episodes: Array = []
var tags: Array = []
var scale: Array = []
var load_error: String = ""


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		load_error = "Деректер файлы табылмады: " + DATA_PATH
		push_error(load_error)
		return
	var text: String = FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "episodes.json файлын талдау мүмкін болмады (JSON қатесі)."
		push_error(load_error)
		return
	meta = parsed.get("meta", {})
	episodes = parsed.get("episodes", [])
	tags = parsed.get("reliability_tags", [])
	scale = parsed.get("reliability_scale", [])


func episode_count() -> int:
	return episodes.size()


func get_episode(episode_id: String) -> Dictionary:
	for ep in episodes:
		if str(ep["id"]) == episode_id:
			return ep
	return {}


func get_episode_by_index(index: int) -> Dictionary:
	for ep in episodes:
		if int(ep["index"]) == index:
			return ep
	return {}


func get_card(ep: Dictionary, card_id: String) -> Dictionary:
	for c in ep.get("cards", []):
		if str(c["id"]) == card_id:
			return c
	return {}


func get_chrono_item(ep: Dictionary, item_id: String) -> Dictionary:
	for it in ep.get("chronology", []):
		if str(it["id"]) == item_id:
			return it
	return {}


## Дәлел ретінде таңдауға болатын кез келген элементтің атауы (карточка немесе оқиға).
func evidence_label(ep: Dictionary, evidence_id: String) -> String:
	var c: Dictionary = get_card(ep, evidence_id)
	if not c.is_empty():
		return str(c["title"])
	var it: Dictionary = get_chrono_item(ep, evidence_id)
	if not it.is_empty():
		return str(it.get("evidence_label", it["text"]))
	return evidence_id


func tag_name(tag_id: String) -> String:
	for t in tags:
		if str(t["id"]) == tag_id:
			return str(t["name"])
	return "—"


func scale_name(value: int) -> String:
	for s in scale:
		if int(s["value"]) == value:
			return str(s["name"])
	return "—"


func correct_chronology_order(ep: Dictionary) -> Array:
	var ids: Array = []
	for it in ep.get("chronology", []):
		ids.append(str(it["id"]))
	return ids


func anomaly_ids(ep: Dictionary) -> Array:
	var ids: Array = []
	for it in ep.get("chronology", []):
		if bool(it.get("anomaly", false)):
			ids.append(str(it["id"]))
	return ids


func clue_total(ep: Dictionary) -> int:
	var n: int = 0
	for c in ep.get("cards", []):
		for f in c.get("fragments", []):
			if bool(f.get("clue", false)):
				n += 1
	return n


func neutral_total(ep: Dictionary) -> int:
	var n: int = 0
	for c in ep.get("cards", []):
		for f in c.get("fragments", []):
			if not bool(f.get("clue", false)):
				n += 1
	return n
