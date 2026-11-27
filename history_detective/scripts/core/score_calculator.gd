extends RefCounted
## ScoreCalculator — ұпай мен тексеру формулалары.
## Барлық функциялар static: оларды сахнасыз (тесттерде) да шақыруға болады.
## Формулалар docs/02_balance_economy.md құжатымен толық сәйкес.

const CLUE_MAX := 100.0            # 1-кезең: маңызды фрагменттерді табу
const CHRONO_ORDER_MAX := 260.0    # 2-кезең: реттілік
const CHRONO_ANOMALY_MAX := 40.0   # 2-кезең: уақыттық сәйкессіздікті табу
const REL_SCALE_MAX := 60.0        # 3-кезең: бір карточкаға шкала ұпайы
const REL_TAG_MAX := 40.0          # 3-кезең: бір карточкаға белгі ұпайы
const CONCLUSION_FACTOR := 3.0     # 4-кезең: дәлелділік (0..100) × 3 = 0..300
const TIME_BONUS_MAX := 100.0
const BASE_MAX := 1000.0           # бонуссыз база максимумы (100+300+300+300)
const HINT_BASE_PENALTY := 25
const PASS_PERCENT := 0.45


## 1-кезең. found — табылған маңызды фрагменттер (total-дан), false_marks —
## белгіленген бейтарап сөйлемдер (neutral_total-дан).
## ratio = found/total − false_marks/neutral_total  → «бәрін белгілеу» = 0 ұпай,
## тек маңыздыларын белгілеу = толық ұпай, кездейсоқ белгілеу ≈ 0.
static func clue_score(found: int, false_marks: int, total: int, neutral_total: int) -> Dictionary:
	var ratio: float = 0.0
	if total > 0:
		ratio = float(found) / float(total)
	if neutral_total > 0:
		ratio -= float(false_marks) / float(neutral_total)
	ratio = clampf(ratio, 0.0, 1.0)
	return {
		"points": roundi(ratio * CLUE_MAX),
		"ratio": ratio,
		"found": found,
		"false": false_marks,
		"total": total,
		"neutral_total": neutral_total,
	}


## 2-кезең. player_order / correct_order — элементтер id-лерінің массивтері.
## Ауытқу = Σ|ойыншы орны − дұрыс орын| (Spearman footrule).
## Нөлдік нүкте — кездейсоқ ретсіздіктің күтілетін мәні (n² − 1) / 3:
## кездейсоқ реттеу ұпай бермейді.
static func chronology_score(player_order: Array, correct_order: Array, flagged: Array, anomalies: Array) -> Dictionary:
	var n: int = correct_order.size()
	var deviation: int = 0
	var misplaced: Array = []
	for i in range(n):
		var item_id = player_order[i]
		var correct_index: int = correct_order.find(item_id)
		var d: int = absi(correct_index - i)
		deviation += d
		if d != 0:
			misplaced.append(item_id)
	var random_dev: float = maxf(1.0, (float(n * n) - 1.0) / 3.0)
	var order_ratio: float = clampf(1.0 - float(deviation) / random_dev, 0.0, 1.0)

	var hits: Array = []
	var false_flags: Array = []
	var missed: Array = []
	for f in flagged:
		if anomalies.has(f):
			hits.append(f)
		else:
			false_flags.append(f)
	for a in anomalies:
		if not flagged.has(a):
			missed.append(a)
	var anomaly_ratio: float = 1.0
	if anomalies.size() > 0:
		anomaly_ratio = clampf(float(hits.size() - false_flags.size()) / float(anomalies.size()), 0.0, 1.0)
	elif false_flags.size() > 0:
		anomaly_ratio = 0.0

	var points: int = roundi(order_ratio * CHRONO_ORDER_MAX + anomaly_ratio * CHRONO_ANOMALY_MAX)
	return {
		"points": points,
		"deviation": deviation,
		"misplaced": misplaced,
		"errors": misplaced.size(),
		"items": n,
		"order_ratio": order_ratio,
		"anomaly_hits": hits,
		"anomaly_false": false_flags,
		"anomaly_missed": missed,
		"anomaly_ratio": anomaly_ratio,
		"perfect": misplaced.is_empty() and missed.is_empty() and false_flags.is_empty(),
	}


## 3-кезең. ratings: {card_id: 1..5}, tags: {card_id: tag_id}, cards: эпизод карточкалары.
static func reliability_score(ratings: Dictionary, tags: Dictionary, cards: Array) -> Dictionary:
	var per_card: Dictionary = {}
	var scale_sum: float = 0.0
	var tag_hits: int = 0
	var errors: int = 0
	var points: float = 0.0
	for card in cards:
		var cid: String = str(card["id"])
		var correct: int = int(card["reliability"])
		var given: int = int(ratings.get(cid, 0))
		var diff: int = absi(given - correct)
		var scale_acc: float = clampf(1.0 - float(diff) / 4.0, 0.0, 1.0)
		var tag_ok: bool = (card["tags_ok"] as Array).has(str(tags.get(cid, "")))
		scale_sum += scale_acc
		if tag_ok:
			tag_hits += 1
		if diff >= 2 or not tag_ok:
			errors += 1
		var card_points: float = REL_SCALE_MAX * scale_acc + (REL_TAG_MAX if tag_ok else 0.0)
		points += card_points
		per_card[cid] = {
			"given": given, "correct": correct, "diff": diff,
			"tag_given": str(tags.get(cid, "")), "tag_ok": tag_ok,
			"points": roundi(card_points),
		}
	var count: int = maxi(1, cards.size())
	var scale_accuracy: float = scale_sum / float(count)
	var tag_accuracy: float = float(tag_hits) / float(count)
	return {
		"points": roundi(points),
		"per_card": per_card,
		"scale_accuracy": scale_accuracy,
		"tag_accuracy": tag_accuracy,
		# Біріктірілген «сенімділік бағалау дәлдігі» — бейімдеудің 2-параметрі
		"accuracy": 0.6 * scale_accuracy + 0.4 * tag_accuracy,
		"errors": errors,
	}


## 4-кезең. Дәлелділік баллы 0..100.
## +50 дұрыс қорытынды; +40 × (міндетті дәлелдер үлесі); +10 × (қосымша дәлелдер үлесі);
## −30 әр тыйым салынған (жалған) дереккөз; −10 ойыншы өзі ≤2 деп бағалаған
## дереккөзге сүйенсе (өзіндік қайшылық).
static func conclusion_score(option_correct: bool, evidence: Array, conclusion: Dictionary, ratings: Dictionary) -> Dictionary:
	var required: Array = conclusion.get("required", [])
	var supporting: Array = conclusion.get("supporting", [])
	var forbidden: Array = conclusion.get("forbidden", [])
	var req_hits: int = 0
	var sup_hits: int = 0
	var forbidden_used: Array = []
	var inconsistent: Array = []
	for e in evidence:
		if required.has(e):
			req_hits += 1
		if supporting.has(e):
			sup_hits += 1
		if forbidden.has(e):
			forbidden_used.append(e)
		elif ratings.has(e) and int(ratings[e]) <= 2:
			inconsistent.append(e)
	var quality: float = 0.0
	if option_correct:
		quality += 50.0
	if required.size() > 0:
		quality += 40.0 * float(req_hits) / float(required.size())
	if supporting.size() > 0:
		quality += 10.0 * minf(1.0, float(sup_hits) / float(supporting.size()))
	else:
		quality += 10.0 if req_hits == required.size() else 0.0
	quality -= 30.0 * forbidden_used.size()
	quality -= 10.0 * inconsistent.size()
	quality = clampf(quality, 0.0, 100.0)
	var missing: Array = []
	for r in required:
		if not evidence.has(r):
			missing.append(r)
	return {
		"correct": option_correct,
		"quality": roundi(quality),
		"points": roundi(quality * CONCLUSION_FACTOR),
		"required_hits": req_hits,
		"required_total": required.size(),
		"supporting_hits": sup_hits,
		"forbidden_used": forbidden_used,
		"inconsistent": inconsistent,
		"missing": missing,
	}


## Уақыт бонусы тек дұрыс әрі дәлелді (quality ≥ 70) қорытындыға беріледі —
## асығыс «болжау» марапатталмайды.
## ratio = уақыт / мақсатты уақыт: ≤0.5 → 100, 1.0 → 50, ≥1.5 → 0.
static func time_bonus(time_sec: float, target_sec: float, quality: int, correct: bool) -> int:
	if not correct or quality < 70 or target_sec <= 0.0:
		return 0
	var ratio: float = time_sec / target_sec
	return roundi(TIME_BONUS_MAX * clampf(1.5 - ratio, 0.0, 1.0))


static func hint_penalty(hint_level: int) -> int:
	return maxi(10, HINT_BASE_PENALTY - 5 * hint_level)


## Қорытынды есеп. parts: clue/chrono/rel/concl/time_bonus/hint_penalty ұпайлары.
static func total_score(parts: Dictionary, multiplier: float, score_bonus: float) -> Dictionary:
	var raw: float = float(parts.get("clue", 0)) + float(parts.get("chrono", 0)) \
		+ float(parts.get("rel", 0)) + float(parts.get("concl", 0)) \
		+ float(parts.get("time_bonus", 0)) - float(parts.get("hint_penalty", 0))
	raw = maxf(raw, 0.0)
	var total: int = roundi(raw * multiplier * (1.0 + score_bonus))
	var max_score: int = roundi(BASE_MAX * multiplier)
	var percent: float = clampf(float(total) / float(max_score), 0.0, 1.0)
	return {"total": total, "max": max_score, "percent": percent, "stars": stars_for(percent)}


static func stars_for(percent: float) -> int:
	if percent >= 0.85:
		return 3
	if percent >= 0.65:
		return 2
	if percent >= PASS_PERCENT:
		return 1
	return 0


## Эпизодты өту шарты: қорытынды дұрыс ӘРІ жалпы нәтиже ≥ 45 %.
static func is_passed(conclusion_correct: bool, percent: float) -> bool:
	return conclusion_correct and percent >= PASS_PERCENT
