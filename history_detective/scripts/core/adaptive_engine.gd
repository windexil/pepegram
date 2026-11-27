extends RefCounted
## AdaptiveEngine — екі параметрді салыстыру және бейімделу шешімі.
##
## Салыстыру A: «Хронология қателігінің үлесі» ↔ «Сенімділік бағалау дәлдігі»
## Салыстыру B: «Эпизодқа кеткен уақыт (мақсатқа қатынасы)» ↔ «Қорытынды сапасы (дәлелділік)»
##
## Метрикалар соңғы эпизодқа 0.6, алдыңғылардың орташасына 0.4 салмақпен
## есептеледі: бір кездейсоқ нәтиже профильді күрт өзгертпейді.

const CHRONO_ERR_HIGH := 0.30   # хронология элементтерінің >30 %-ы орнында емес
const REL_ACC_HIGH := 0.75      # сенімділік дәлдігі жоғары
const REL_ACC_LOW := 0.60       # сенімділік дәлдігі төмен
const TIME_FAST := 0.60         # мақсатты уақыттың 60 %-ынан тез
const TIME_SLOW := 1.30         # мақсатты уақыттан 30 %-ға баяу
const QUALITY_HIGH := 0.70      # дәлелділік ≥ 70/100
const QUALITY_LOW := 0.50       # дәлелділік < 50/100
const LAST_WEIGHT := 0.6


static func default_profile() -> Dictionary:
	return {
		"hint_level": 1,
		"chrono_support": false,
		"source_support": false,
		"anchor_items": false,
		"require_compare": false,
		"target_time_factor": 1.0,
		"score_bonus": 0.0,
		"diagnosis_a": "none",
		"diagnosis_b": "none",
		"rationale": ["Әзірге статистика жоқ: стандартты профиль (кеңес деңгейі 1) қолданылады."],
		"metrics": {},
		"based_on": 0,
	}


## Бір әрекет жазбасынан 4 нормаланған метрика.
static func metrics_of(record: Dictionary) -> Dictionary:
	var items: float = maxf(1.0, float(record.get("chrono_items", 1)))
	var target: float = maxf(1.0, float(record.get("target_time_sec", 1)))
	return {
		"chrono_error_rate": float(record.get("chrono_errors", 0)) / items,
		"reliability_accuracy": float(record.get("reliability_accuracy", 0.0)),
		"time_ratio": float(record.get("time_sec", 0.0)) / target,
		"quality": float(record.get("evidence_score", 0)) / 100.0,
	}


## Тарих бойынша салмақталған метрикалар (соңғысы 0.6, қалғандарының орташасы 0.4).
static func weighted_metrics(history: Array) -> Dictionary:
	if history.is_empty():
		return {}
	var last: Dictionary = metrics_of(history[history.size() - 1])
	if history.size() == 1:
		return last
	var prev_sum: Dictionary = {"chrono_error_rate": 0.0, "reliability_accuracy": 0.0, "time_ratio": 0.0, "quality": 0.0}
	for i in range(history.size() - 1):
		var m: Dictionary = metrics_of(history[i])
		for k in prev_sum.keys():
			prev_sum[k] = float(prev_sum[k]) + float(m[k])
	var n: float = float(history.size() - 1)
	var result: Dictionary = {}
	for k in prev_sum.keys():
		result[k] = LAST_WEIGHT * float(last[k]) + (1.0 - LAST_WEIGHT) * float(prev_sum[k]) / n
	return result


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## Негізгі шешім: метрикалар → бейімделу профилі + логикалық негіздеме (қазақша).
static func decide(m: Dictionary, based_on: int = 1) -> Dictionary:
	var p: Dictionary = default_profile()
	if m.is_empty():
		return p
	p["metrics"] = m
	p["based_on"] = based_on
	var rationale: Array = []
	var ce: float = float(m["chrono_error_rate"])
	var ra: float = float(m["reliability_accuracy"])
	var tr: float = float(m["time_ratio"])
	var q: float = float(m["quality"])
	var hint_level: int = 1

	# ---------- Салыстыру A: хронология қатесі ↔ сенімділік дәлдігі ----------
	var a_text: String = "A) Хронология қатесі %s (шек %s), сенімділік дәлдігі %s (шектер %s / %s). " % [
		_pct(ce), _pct(CHRONO_ERR_HIGH), _pct(ra), _pct(REL_ACC_LOW), _pct(REL_ACC_HIGH)]
	if ce > CHRONO_ERR_HIGH and ra >= REL_ACC_HIGH:
		p["diagnosis_a"] = "chrono_gap"
		p["chrono_support"] = true
		a_text += "Дереккөзді жақсы бағалайсың, бірақ уақыт осінде адасасың → уақыт маркерлері мәтінде ерекшеленеді, жасырын даталарға «бағдар» белгісі қосылады."
	elif ce <= CHRONO_ERR_HIGH and ra < REL_ACC_LOW:
		p["diagnosis_a"] = "source_gap"
		p["source_support"] = true
		a_text += "Хронологияны дұрыс құрасың, бірақ сенімділікті бағалауда қате көп → «автор мүддесі / жанр / уақыт арақашықтығы» салыстыру кестесі қосылады."
	elif ce > CHRONO_ERR_HIGH and ra < REL_ACC_LOW:
		p["diagnosis_a"] = "both_gap"
		p["chrono_support"] = true
		p["source_support"] = true
		p["anchor_items"] = true
		hint_level += 1
		a_text += "Екі дағды да әлсіз → екі көмекші де қосылады, хронологияның бірінші және соңғы элементі бекітіледі, кеңес деңгейі артады."
	elif ce <= CHRONO_ERR_HIGH and ra >= REL_ACC_HIGH:
		p["diagnosis_a"] = "strong"
		hint_level -= 1
		p["score_bonus"] = float(p["score_bonus"]) + 0.10
		a_text += "Екі дағды да жоғары → «сарапшы режимі»: кеңестер азаяды, ұпай коэффициенті +10 %."
	else:
		p["diagnosis_a"] = "balanced"
		a_text += "Көрсеткіштер аралық аймақта → қиындық өзгеріссіз қалады."
	rationale.append(a_text)

	# ---------- Салыстыру B: уақыт ↔ қорытынды сапасы ----------
	var b_text: String = "B) Уақыт мақсаттың %s-ы (шектер %s / %s), қорытынды сапасы %s (шектер %s / %s). " % [
		_pct(tr), _pct(TIME_FAST), _pct(TIME_SLOW), _pct(q), _pct(QUALITY_LOW), _pct(QUALITY_HIGH)]
	if tr < TIME_FAST and q < QUALITY_LOW:
		p["diagnosis_b"] = "impulsive"
		p["require_compare"] = true
		b_text += "Тез, бірақ дәлелсіз → асығыстық белгісі: келесі істе салыстыру режимін қолдану міндетті болады."
	elif tr > TIME_SLOW and q >= QUALITY_HIGH:
		p["diagnosis_b"] = "careful"
		p["target_time_factor"] = 1.2
		b_text += "Баяу, бірақ сапалы → мұқияттық марапатталады: мақсатты уақыт 20 %-ға ұзартылады."
	elif tr > TIME_SLOW and q < QUALITY_LOW:
		p["diagnosis_b"] = "struggling"
		p["anchor_items"] = true
		hint_level += 1
		b_text += "Баяу әрі сапа төмен → қиналу белгісі: кеңес деңгейі артады, кезең бағдары автоматты көрсетіледі."
	elif tr <= 1.0 and q >= QUALITY_HIGH:
		p["diagnosis_b"] = "fluent"
		p["target_time_factor"] = 0.9
		p["score_bonus"] = float(p["score_bonus"]) + 0.05
		b_text += "Жылдам әрі сапалы → сынақ күшейеді: мақсатты уақыт 10 %-ға қысқарады, ұпай коэффициенті +5 %."
	else:
		p["diagnosis_b"] = "normal"
		b_text += "Уақыт пен сапа теңгерімді → өзгеріс жоқ."
	rationale.append(b_text)

	p["hint_level"] = clampi(hint_level, 0, 3)
	rationale.append("Нәтиже: кеңес деңгейі %d/3; кеңес айыппұлы −%d ұпай." % [
		int(p["hint_level"]), maxi(10, 25 - 5 * int(p["hint_level"]))])
	p["rationale"] = rationale
	return p


static func profile_from_history(history: Array) -> Dictionary:
	return decide(weighted_metrics(history), history.size())


## Профильдің қысқа, ойыншыға түсінікті тізімі.
static func describe(p: Dictionary) -> Array:
	var out: Array = []
	if bool(p.get("chrono_support", false)):
		out.append("Уақыт маркерлері ерекшеленеді, жасырын даталарға бағдар беріледі")
	if bool(p.get("source_support", false)):
		out.append("Дереккөздерді салыстыру кестесі (автор мүддесі, жанр, уақыт)")
	if bool(p.get("anchor_items", false)):
		out.append("Хронологияның бірінші және соңғы элементі бекітілген")
	if bool(p.get("require_compare", false)):
		out.append("Салыстыру режимін қолдану міндетті")
	var f: float = float(p.get("target_time_factor", 1.0))
	if f > 1.0:
		out.append("Мақсатты уақыт ұзартылған (×%.1f)" % f)
	elif f < 1.0:
		out.append("Мақсатты уақыт қысқартылған (×%.1f)" % f)
	var b: float = float(p.get("score_bonus", 0.0))
	if b > 0.0:
		out.append("Ұпай коэффициенті +%d %%" % roundi(b * 100.0))
	out.append("Кеңес деңгейі: %d/3" % int(p.get("hint_level", 1)))
	return out
