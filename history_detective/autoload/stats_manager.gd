extends Node
## Stats (autoload) — ағымдағы эпизодтағы ойыншы әрекеттерінің статистикасы.
## Жиналатын көрсеткіштер: қателер саны, хронология ауытқуы, сенімділік дәлдігі,
## қорытындының дәлелділік баллы, уақыт, кеңестер, әр кезеңнің ұпайы.

const Score = preload("res://scripts/core/score_calculator.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")

signal points_changed(points: int)

var episode: Dictionary = {}
var profile: Dictionary = {}
var active: bool = false
var start_ms: int = 0
var record: Dictionary = {}
var parts: Dictionary = {}
var stage_times: Dictionary = {}
var _stage_start_ms: int = 0
var _current_stage: String = ""


func begin_episode(ep: Dictionary, p_profile: Dictionary) -> void:
	episode = ep
	profile = p_profile
	active = true
	start_ms = Time.get_ticks_msec()
	parts = {"clue": 0, "chrono": 0, "rel": 0, "concl": 0, "time_bonus": 0, "hint_penalty": 0}
	stage_times = {}
	_current_stage = ""
	var target: float = float(ep["target_time_sec"]) * float(p_profile.get("target_time_factor", 1.0))
	record = {
		"episode_id": ep["id"],
		"episode_index": ep["index"],
		"episode_title": ep["title"],
		"started": Time.get_datetime_string_from_system(),
		"target_time_sec": roundi(target),
		"hint_level": int(p_profile.get("hint_level", 1)),
		"profile_used": AdaptiveEngine.describe(p_profile),
		"hints_used": 0,
		"hints_by_stage": {},
		"cards_opened": 0,
		"compare_used": 0,
		"clue_found": 0, "clue_false": 0, "clue_total": 0,
		"chrono_errors": 0, "chrono_deviation": 0, "chrono_items": 0, "chrono_attempts": 0,
		"anomaly_hits": 0, "anomaly_missed": 0, "anomaly_false": 0,
		"reliability_accuracy": 0.0, "reliability_scale_accuracy": 0.0,
		"reliability_tag_accuracy": 0.0, "reliability_errors": 0,
		"conclusion_correct": false, "evidence_score": 0, "forbidden_used": 0,
	}
	points_changed.emit(0)


func elapsed_sec() -> float:
	if not active:
		return float(record.get("time_sec", 0.0))
	return float(Time.get_ticks_msec() - start_ms) / 1000.0


func enter_stage(stage_name: String) -> void:
	_close_stage()
	_current_stage = stage_name
	_stage_start_ms = Time.get_ticks_msec()


func _close_stage() -> void:
	if _current_stage == "":
		return
	var dt: float = float(Time.get_ticks_msec() - _stage_start_ms) / 1000.0
	stage_times[_current_stage] = float(stage_times.get(_current_stage, 0.0)) + dt


func current_points() -> int:
	var raw: int = int(parts["clue"]) + int(parts["chrono"]) + int(parts["rel"]) + int(parts["concl"]) - int(parts["hint_penalty"])
	return maxi(0, roundi(float(raw) * float(episode.get("multiplier", 1.0))))


# ---------------- Әрекеттерді тіркеу ----------------

func note_card_opened() -> void:
	record["cards_opened"] = int(record["cards_opened"]) + 1


func note_compare_used() -> void:
	record["compare_used"] = int(record["compare_used"]) + 1


func use_hint(stage_name: String) -> int:
	var penalty: int = Score.hint_penalty(int(profile.get("hint_level", 1)))
	record["hints_used"] = int(record["hints_used"]) + 1
	var by_stage: Dictionary = record["hints_by_stage"]
	by_stage[stage_name] = int(by_stage.get(stage_name, 0)) + 1
	parts["hint_penalty"] = int(parts["hint_penalty"]) + penalty
	points_changed.emit(current_points())
	return penalty


func record_clues(result: Dictionary) -> void:
	parts["clue"] = int(result["points"])
	record["clue_found"] = result["found"]
	record["clue_false"] = result["false"]
	record["clue_total"] = result["total"]
	points_changed.emit(current_points())


## Тек БІРІНШІ тексеріс бағаланады; кейінгілері — оқу үшін (attempts санына жазылады).
func record_chronology(result: Dictionary) -> void:
	var attempts: int = int(record["chrono_attempts"]) + 1
	record["chrono_attempts"] = attempts
	if attempts > 1:
		return
	parts["chrono"] = int(result["points"])
	record["chrono_errors"] = result["errors"]
	record["chrono_deviation"] = result["deviation"]
	record["chrono_items"] = result["items"]
	record["anomaly_hits"] = (result["anomaly_hits"] as Array).size()
	record["anomaly_missed"] = (result["anomaly_missed"] as Array).size()
	record["anomaly_false"] = (result["anomaly_false"] as Array).size()
	points_changed.emit(current_points())


func record_reliability(result: Dictionary) -> void:
	parts["rel"] = int(result["points"])
	record["reliability_accuracy"] = snappedf(float(result["accuracy"]), 0.001)
	record["reliability_scale_accuracy"] = snappedf(float(result["scale_accuracy"]), 0.001)
	record["reliability_tag_accuracy"] = snappedf(float(result["tag_accuracy"]), 0.001)
	record["reliability_errors"] = result["errors"]
	points_changed.emit(current_points())


func record_conclusion(result: Dictionary) -> void:
	parts["concl"] = int(result["points"])
	record["conclusion_correct"] = result["correct"]
	record["evidence_score"] = result["quality"]
	record["forbidden_used"] = (result["forbidden_used"] as Array).size()
	points_changed.emit(current_points())


## Эпизодты аяқтау: уақыт бонусы, жалпы ұпай, өту шарты, жазбаны сақтау.
func finish_episode() -> Dictionary:
	_close_stage()
	var time_sec: float = elapsed_sec()
	active = false
	record["time_sec"] = snappedf(time_sec, 0.1)
	record["stage_times"] = stage_times.duplicate()
	parts["time_bonus"] = Score.time_bonus(time_sec, float(record["target_time_sec"]),
		int(record["evidence_score"]), bool(record["conclusion_correct"]))
	var total: Dictionary = Score.total_score(parts, float(episode["multiplier"]), float(profile.get("score_bonus", 0.0)))
	record["parts"] = parts.duplicate()
	record["score"] = total["total"]
	record["max_score"] = total["max"]
	record["percent"] = snappedf(float(total["percent"]), 0.001)
	record["stars"] = total["stars"]
	record["total_errors"] = int(record["clue_false"]) + int(record["chrono_errors"]) \
		+ int(record["anomaly_missed"]) + int(record["anomaly_false"]) \
		+ int(record["reliability_errors"]) + int(record["forbidden_used"]) \
		+ (0 if bool(record["conclusion_correct"]) else 1)
	record["passed"] = Score.is_passed(bool(record["conclusion_correct"]), float(total["percent"]))
	record["finished"] = Time.get_datetime_string_from_system()
	GameState.commit_record(record)
	return record
