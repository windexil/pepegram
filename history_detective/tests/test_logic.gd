extends SceneTree
## Логика және деректер тұтастығы тесттері (сахнасыз, headless).
## Іске қосу:  godot --headless --path . -s res://tests/test_logic.gd
## Шығу коды 0 — барлық тест өтті, 1 — қате бар.

const Score = preload("res://scripts/core/score_calculator.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")

var _fails: int = 0
var _passes: int = 0


func _init() -> void:
	print("History Detective — логикалық тесттер")
	_test_data_integrity()
	_test_clues()
	_test_chronology()
	_test_reliability()
	_test_conclusion()
	_test_total_and_time()
	_test_adaptation()
	print("\n=== Нәтиже: %d өтті, %d құлады ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, title: String) -> void:
	if cond:
		_passes += 1
		print("  ✔ ", title)
	else:
		_fails += 1
		printerr("  ✖ ", title)


func _load_data() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/episodes.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _test_data_integrity() -> void:
	print("\n[Деректер]")
	var d: Dictionary = _load_data()
	check(not d.is_empty(), "episodes.json жарамды JSON")
	var eps: Array = d.get("episodes", [])
	check(eps.size() == 3, "3 эпизод бар")
	var tag_ids: Array = []
	for t in d["reliability_tags"]:
		tag_ids.append(str(t["id"]))
	var total_cards: int = 0
	for ep in eps:
		var cards: Array = ep["cards"]
		total_cards += cards.size()
		check(cards.size() == 3, "%s: 3 карточка" % ep["id"])
		var formats: Dictionary = {}
		var card_ids: Array = []
		for c in cards:
			formats[str(c["format"])] = true
			card_ids.append(str(c["id"]))
			for k in ["title", "date_label", "author", "origin", "genre", "details", "fragments", "reliability", "tags_ok", "reliability_explain"]:
				check(c.has(k), "%s: '%s' өрісі бар" % [c["id"], k])
			check(int(c["reliability"]) >= 1 and int(c["reliability"]) <= 5, "%s: сенімділік 1..5" % c["id"])
			for tg in c["tags_ok"]:
				check(tag_ids.has(str(tg)), "%s: белгі '%s' белгілі" % [c["id"], tg])
		check(formats.size() == 3, "%s: 3 түрлі формат" % ep["id"])
		var chrono_ids: Dictionary = {}
		var anomalies: int = 0
		var cards_in_chrono: Dictionary = {}
		for it in ep["chronology"]:
			chrono_ids[str(it["id"])] = true
			if bool(it.get("anomaly", false)):
				anomalies += 1
			if it.has("card_id"):
				check(card_ids.has(str(it["card_id"])), "%s: card_id сілтемесі дұрыс" % it["id"])
				cards_in_chrono[str(it["card_id"])] = true
		check(chrono_ids.size() == (ep["chronology"] as Array).size(), "%s: хронология id-лері бірегей" % ep["id"])
		check(cards_in_chrono.size() == 3, "%s: әр карточка хронологияда бар" % ep["id"])
		check(anomalies >= 1, "%s: кемінде 1 уақыттық сәйкессіздік" % ep["id"])
		var correct_opts: int = 0
		for o in ep["conclusion"]["options"]:
			if bool(o["correct"]):
				correct_opts += 1
		check(correct_opts == 1, "%s: дәл бір дұрыс қорытынды" % ep["id"])
		for key in ["required", "supporting", "forbidden"]:
			for e in ep["conclusion"][key]:
				check(card_ids.has(str(e)) or chrono_ids.has(str(e)), "%s: %s дәлелі '%s' бар" % [ep["id"], key, e])
		for stage in ["investigate", "chronology", "reliability", "conclusion"]:
			check((ep["hints"][stage] as Array).size() == 3, "%s: '%s' үшін 3 кеңес" % [ep["id"], stage])
	check(total_cards == 9, "барлығы 9 дереккөз карточкасы")
	var m1: float = float(eps[0]["multiplier"])
	var m3: float = float(eps[2]["multiplier"])
	check(m1 < float(eps[1]["multiplier"]) and float(eps[1]["multiplier"]) < m3, "қиындық коэффициенті өседі")


func _test_clues() -> void:
	print("\n[1-кезең: белгілер]")
	check(int(Score.clue_score(5, 0, 5, 4)["points"]) == 100, "тек маңыздылары белгіленсе 100")
	check(int(Score.clue_score(4, 2, 5, 4)["points"]) == 30, "4/5 табылды, 2/4 артық → 80% − 50% = 30")
	check(int(Score.clue_score(5, 4, 5, 4)["points"]) == 0, "«бәрін белгілеу» стратегиясы → 0")
	check(int(Score.clue_score(0, 1, 5, 4)["points"]) == 0, "ұпай теріс болмайды")


func _test_chronology() -> void:
	print("\n[2-кезең: хронология]")
	var correct: Array = ["a", "b", "c", "d", "e"]
	var r1: Dictionary = Score.chronology_score(correct, correct, ["c"], ["c"])
	check(int(r1["points"]) == 300 and bool(r1["perfect"]), "мінсіз рет + сәйкессіздік → 300")
	var r2: Dictionary = Score.chronology_score(["b", "a", "c", "d", "e"], correct, ["c"], ["c"])
	check(int(r2["errors"]) == 2 and int(r2["deviation"]) == 2, "көрші екеуі ауысқан: 2 қате, ауытқу 2")
	check(int(r2["points"]) < 300 and int(r2["points"]) > 200, "кішкене қате — жоғары, бірақ толық емес ұпай")
	var r3: Dictionary = Score.chronology_score(["e", "d", "c", "b", "a"], correct, [], ["c"])
	check(int(r3["points"]) == 0, "толық кері рет + сәйкессіздік табылмады → 0")
	var r4: Dictionary = Score.chronology_score(correct, correct, ["a", "c"], ["c"])
	check(int(r4["points"]) == 260, "қате белгі сәйкессіздік ұпайын жояды")


func _test_reliability() -> void:
	print("\n[3-кезең: сенімділік]")
	var cards: Array = [
		{"id": "x", "reliability": 4, "tags_ok": ["indirect"]},
		{"id": "y", "reliability": 1, "tags_ok": ["anachronism"]},
	]
	var r: Dictionary = Score.reliability_score({"x": 4, "y": 1}, {"x": "indirect", "y": "anachronism"}, cards)
	check(int(r["points"]) == 200 and is_equal_approx(float(r["accuracy"]), 1.0), "толық дұрыс → 200, дәлдік 100%")
	var r2: Dictionary = Score.reliability_score({"x": 5, "y": 4}, {"x": "indirect", "y": "confirmed"}, cards)
	check(int(r2["errors"]) == 1, "|Δ|≥2 немесе қате белгі — 1 қате (y)")
	check(int(r2["points"]) == 45 + 40 + 15, "ұпай: x=45+40, y=15+0")


func _test_conclusion() -> void:
	print("\n[4-кезең: дәлелділік]")
	var concl: Dictionary = {"required": ["c1", "c3"], "supporting": ["t4"], "forbidden": ["c2"]}
	var ok: Dictionary = Score.conclusion_score(true, ["c1", "c3", "t4"], concl, {"c1": 4, "c3": 4})
	check(int(ok["quality"]) == 100 and int(ok["points"]) == 300, "дұрыс + толық дәлел → 100 / 300")
	var fake: Dictionary = Score.conclusion_score(true, ["c1", "c2"], concl, {"c1": 4, "c2": 1})
	check(int(fake["quality"]) == 40, "жалған дереккөз қосылса: 50+20−30 = 40")
	var wrong: Dictionary = Score.conclusion_score(false, ["c2"], concl, {"c2": 1})
	check(int(wrong["quality"]) == 0, "қате қорытынды + жалған дәлел → 0")
	var incons: Dictionary = Score.conclusion_score(true, ["c1", "c3", "t4", "x"], concl, {"c1": 4, "c3": 4, "x": 2})
	check(int(incons["quality"]) == 90, "өзі ≤2 деп бағалаған дереккөз → −10")


func _test_total_and_time() -> void:
	print("\n[Жалпы ұпай және уақыт]")
	check(Score.time_bonus(200.0, 400.0, 100, true) == 100, "уақыттың жартысы → бонус 100")
	check(Score.time_bonus(400.0, 400.0, 100, true) == 50, "дәл мақсатта → 50")
	check(Score.time_bonus(100.0, 400.0, 60, true) == 0, "сапа < 70 → бонус жоқ (асығыстық марапатталмайды)")
	check(Score.time_bonus(100.0, 400.0, 100, false) == 0, "қате қорытынды → бонус жоқ")
	var t: Dictionary = Score.total_score({"clue": 100, "chrono": 300, "rel": 300, "concl": 300, "time_bonus": 0, "hint_penalty": 0}, 1.5, 0.0)
	check(int(t["total"]) == 1500 and int(t["max"]) == 1500 and int(t["stars"]) == 3, "максимум ×1.5 = 1500, 3 жұлдыз")
	check(Score.is_passed(true, 0.5) and not Score.is_passed(false, 0.9) and not Score.is_passed(true, 0.3), "өту шарты")
	check(Score.hint_penalty(0) == 25 and Score.hint_penalty(3) == 10, "кеңес айыппұлы деңгейге тәуелді")


func _rec(chrono_errors: int, items: int, rel_acc: float, time_sec: float, target: float, evidence: int) -> Dictionary:
	return {"chrono_errors": chrono_errors, "chrono_items": items, "reliability_accuracy": rel_acc,
		"time_sec": time_sec, "target_time_sec": target, "evidence_score": evidence}


func _test_adaptation() -> void:
	print("\n[Бейімделу: екі параметрді салыстыру]")
	var p1: Dictionary = AdaptiveEngine.profile_from_history([_rec(5, 9, 0.9, 400, 420, 80)])
	check(str(p1["diagnosis_a"]) == "chrono_gap" and bool(p1["chrono_support"]), "хронология қатесі көп + сенімділік жоғары → уақыт маркерлері")
	var p2: Dictionary = AdaptiveEngine.profile_from_history([_rec(1, 9, 0.4, 400, 420, 80)])
	check(str(p2["diagnosis_a"]) == "source_gap" and bool(p2["source_support"]), "хронология жақсы + сенімділік төмен → салыстыру кестесі")
	var p3: Dictionary = AdaptiveEngine.profile_from_history([_rec(6, 9, 0.3, 800, 420, 30)])
	check(str(p3["diagnosis_a"]) == "both_gap" and str(p3["diagnosis_b"]) == "struggling" and int(p3["hint_level"]) == 3, "екеуі де әлсіз + баяу әрі сапасыз → кеңес деңгейі 3")
	var p4: Dictionary = AdaptiveEngine.profile_from_history([_rec(0, 9, 0.95, 200, 420, 100)])
	check(str(p4["diagnosis_a"]) == "strong" and str(p4["diagnosis_b"]) == "fluent" and int(p4["hint_level"]) == 0, "сарапшы → кеңес деңгейі 0, бонус")
	check(is_equal_approx(float(p4["score_bonus"]), 0.15), "сарапшы бонусы +10% + жылдамдық бонусы +5%")
	var p5: Dictionary = AdaptiveEngine.profile_from_history([_rec(2, 9, 0.7, 150, 420, 30)])
	check(str(p5["diagnosis_b"]) == "impulsive" and bool(p5["require_compare"]), "тез, бірақ дәлелсіз → салыстыру міндетті")
	var p6: Dictionary = AdaptiveEngine.profile_from_history([_rec(2, 9, 0.7, 700, 420, 90)])
	check(str(p6["diagnosis_b"]) == "careful" and float(p6["target_time_factor"]) > 1.0, "баяу, бірақ сапалы → уақыт ұзартылады")
	var wm: Dictionary = AdaptiveEngine.weighted_metrics([_rec(9, 9, 0.0, 420, 420, 0), _rec(0, 9, 1.0, 420, 420, 100)])
	check(is_equal_approx(float(wm["chrono_error_rate"]), 0.4) and is_equal_approx(float(wm["quality"]), 0.6), "салмақтау: соңғы ×0.6 + алдыңғы ×0.4")
	check((p1["rationale"] as Array).size() == 3, "негіздеме 3 жолдан тұрады (A, B, нәтиже)")
