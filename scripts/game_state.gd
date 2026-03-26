extends Node
## Core game state autoload singleton.
## Manages businesses, followers, prestige, saving/loading, and offline progress.

signal followers_changed(amount: float)
signal business_updated(index: int)
signal milestone_reached(biz_name: String, milestone: int)
signal combo_changed(multiplier: int)
signal prestige_done(clout: float)

const SAVE_PATH := "user://save.json"
const COST_SCALE := 1.15
const MILESTONE_LEVELS := [25, 50, 100, 200, 300, 400]
const MILESTONE_MULTIPLIERS := [2.0, 3.0, 4.0, 5.0, 6.0, 8.0]
const COMBO_MAX := 12
const COMBO_DECAY_TIME := 3.0
const PRESTIGE_BASE := 150.0

## Business definitions --------------------------------------------------
var biz_defs: Array[Dictionary] = [
	{
		"name": "Blog Post",
		"base_cost": 4.0,
		"base_payout": 1.0,
		"base_time": 0.6,
		"unlock_at": 0.0,
		"mgr_cost": 50.0,
	},
	{
		"name": "Short Clips",
		"base_cost": 60.0,
		"base_payout": 8.0,
		"base_time": 3.0,
		"unlock_at": 50.0,
		"mgr_cost": 500.0,
	},
	{
		"name": "Video Channel",
		"base_cost": 720.0,
		"base_payout": 54.0,
		"base_time": 6.0,
		"unlock_at": 500.0,
		"mgr_cost": 5_000.0,
	},
	{
		"name": "Podcast",
		"base_cost": 8_640.0,
		"base_payout": 432.0,
		"base_time": 12.0,
		"unlock_at": 5_000.0,
		"mgr_cost": 50_000.0,
	},
	{
		"name": "Merch Store",
		"base_cost": 103_680.0,
		"base_payout": 4_320.0,
		"base_time": 24.0,
		"unlock_at": 50_000.0,
		"mgr_cost": 500_000.0,
	},
	{
		"name": "Online Course",
		"base_cost": 1_244_160.0,
		"base_payout": 51_840.0,
		"base_time": 48.0,
		"unlock_at": 500_000.0,
		"mgr_cost": 5_000_000.0,
	},
	{
		"name": "Media Agency",
		"base_cost": 14_929_920.0,
		"base_payout": 777_600.0,
		"base_time": 96.0,
		"unlock_at": 5_000_000.0,
		"mgr_cost": 50_000_000.0,
	},
]

## Runtime state ----------------------------------------------------------
var followers: float = 0.0
var total_followers: float = 0.0  # lifetime, for prestige calc
var clout: float = 0.0            # prestige currency
var clout_bonus: float = 1.0      # multiplier from clout (1 + clout * 0.02)

var combo: int = 1
var combo_timer: float = 0.0

## Per-business runtime arrays (parallel to biz_defs)
var biz_count: Array[int] = []
var biz_has_mgr: Array[bool] = []
var biz_timer: Array[float] = []       # seconds remaining (-1 = idle)
var biz_unlocked: Array[bool] = []

var last_save_time: int = 0  # unix timestamp of last save

## -----------------------------------------------------------------------

func _ready() -> void:
	_init_arrays()
	load_game()

func _init_arrays() -> void:
	biz_count.clear()
	biz_has_mgr.clear()
	biz_timer.clear()
	biz_unlocked.clear()
	for i in biz_defs.size():
		biz_count.append(0)
		biz_has_mgr.append(false)
		biz_timer.append(-1.0)
		biz_unlocked.append(false)
	# First business always unlocked and owned x1
	biz_unlocked[0] = true
	biz_count[0] = 1

func _process(delta: float) -> void:
	_tick_combo(delta)
	_tick_businesses(delta)

## Combo -----------------------------------------------------------------

func _tick_combo(delta: float) -> void:
	if combo > 1:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 1
			combo_timer = 0.0
			combo_changed.emit(combo)

func add_combo() -> void:
	combo = mini(combo + 1, COMBO_MAX)
	combo_timer = COMBO_DECAY_TIME
	combo_changed.emit(combo)

## Businesses ------------------------------------------------------------

func _tick_businesses(delta: float) -> void:
	for i in biz_defs.size():
		if biz_count[i] <= 0:
			continue
		if biz_timer[i] < 0.0:
			# idle — auto-start if manager hired
			if biz_has_mgr[i]:
				biz_timer[i] = get_biz_time(i)
			continue
		biz_timer[i] -= delta
		if biz_timer[i] <= 0.0:
			# finished
			var payout := get_biz_payout(i)
			add_followers(payout)
			biz_timer[i] = -1.0
			if biz_has_mgr[i]:
				biz_timer[i] = get_biz_time(i)
			business_updated.emit(i)

func get_biz_cost(index: int) -> float:
	return biz_defs[index]["base_cost"] * pow(COST_SCALE, biz_count[index])

func get_biz_payout(index: int) -> float:
	var base: float = biz_defs[index]["base_payout"]
	var count: int = biz_count[index]
	var milestone_mult := _milestone_multiplier(count)
	return base * count * milestone_mult * clout_bonus

func get_biz_time(index: int) -> float:
	return biz_defs[index]["base_time"]

func get_biz_progress(index: int) -> float:
	var total_time: float = get_biz_time(index)
	if biz_timer[index] < 0.0:
		return 0.0
	return 1.0 - (biz_timer[index] / total_time)

func next_milestone(count: int) -> int:
	for m in MILESTONE_LEVELS:
		if count < m:
			return m
	return -1  # all milestones reached

func _milestone_multiplier(count: int) -> float:
	var mult := 1.0
	for i in MILESTONE_LEVELS.size():
		if count >= MILESTONE_LEVELS[i]:
			mult = MILESTONE_MULTIPLIERS[i]
	return mult

func buy_business(index: int) -> bool:
	var cost := get_biz_cost(index)
	if followers < cost:
		return false
	var old_count := biz_count[index]
	followers -= cost
	biz_count[index] += 1
	if not biz_unlocked[index]:
		biz_unlocked[index] = true
	followers_changed.emit(followers)
	business_updated.emit(index)
	# Check milestone
	var new_count := biz_count[index]
	for m in MILESTONE_LEVELS:
		if old_count < m and new_count >= m:
			milestone_reached.emit(biz_defs[index]["name"], m)
	AudioManager.buy()
	_check_unlocks()
	return true

func start_business(index: int) -> bool:
	if biz_count[index] <= 0:
		return false
	if biz_timer[index] >= 0.0:
		return false  # already running
	biz_timer[index] = get_biz_time(index)
	business_updated.emit(index)
	return true

func collect_business(index: int) -> float:
	# Manual collect — only when timer finished (<=0 and not idle)
	if biz_timer[index] >= 0.0:
		return 0.0
	# Timer shows -1 meaning idle after completion handled in _tick
	# This is called from UI; payout already given in _tick.
	return 0.0

func hire_manager(index: int) -> bool:
	if biz_has_mgr[index]:
		return false
	var cost: float = biz_defs[index]["mgr_cost"]
	if followers < cost:
		return false
	followers -= cost
	biz_has_mgr[index] = true
	followers_changed.emit(followers)
	business_updated.emit(index)
	AudioManager.hire()
	return true

func _check_unlocks() -> void:
	for i in biz_defs.size():
		if not biz_unlocked[i]:
			if total_followers >= biz_defs[i]["unlock_at"]:
				biz_unlocked[i] = true
				business_updated.emit(i)

## Followers -------------------------------------------------------------

func add_followers(amount: float) -> void:
	var actual := amount * combo
	followers += actual
	total_followers += actual
	followers_changed.emit(followers)
	_check_unlocks()

func get_followers_per_second() -> float:
	var fps := 0.0
	for i in biz_defs.size():
		if biz_count[i] <= 0:
			continue
		if not biz_has_mgr[i]:
			continue
		var payout := get_biz_payout(i)
		var time := get_biz_time(i)
		fps += payout / time
	return fps

## Tap -------------------------------------------------------------------

func tap() -> float:
	var base := biz_defs[0]["base_payout"]
	var amount := base * clout_bonus * combo
	followers += amount
	total_followers += amount
	add_combo()
	followers_changed.emit(followers)
	AudioManager.tap()
	_check_unlocks()
	return amount

## Prestige (Go Viral) ---------------------------------------------------

func get_pending_clout() -> float:
	if total_followers < PRESTIGE_BASE:
		return 0.0
	return floor(sqrt(total_followers / PRESTIGE_BASE))

func prestige() -> void:
	var pending := get_pending_clout()
	if pending <= 0.0:
		return
	clout += pending
	clout_bonus = 1.0 + clout * 0.02
	# Reset progress
	followers = 0.0
	total_followers = 0.0
	combo = 1
	combo_timer = 0.0
	_init_arrays()
	prestige_done.emit(clout)
	AudioManager.prestige()
	save_game()

## Save / Load -----------------------------------------------------------

func save_game() -> void:
	var data := {
		"followers": followers,
		"total_followers": total_followers,
		"clout": clout,
		"combo": combo,
		"biz_count": biz_count,
		"biz_has_mgr": biz_has_mgr,
		"biz_unlocked": biz_unlocked,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		last_save_time = int(data["timestamp"])

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Dictionary = json.data
	followers = data.get("followers", 0.0)
	total_followers = data.get("total_followers", 0.0)
	clout = data.get("clout", 0.0)
	clout_bonus = 1.0 + clout * 0.02
	combo = int(data.get("combo", 1))
	var saved_count: Array = data.get("biz_count", [])
	var saved_mgr: Array = data.get("biz_has_mgr", [])
	var saved_unlock: Array = data.get("biz_unlocked", [])
	for i in biz_defs.size():
		if i < saved_count.size():
			biz_count[i] = int(saved_count[i])
		if i < saved_mgr.size():
			biz_has_mgr[i] = bool(saved_mgr[i])
		if i < saved_unlock.size():
			biz_unlocked[i] = bool(saved_unlock[i])
	# Offline progress
	var saved_time: float = data.get("timestamp", 0.0)
	if saved_time > 0.0:
		var now := Time.get_unix_time_from_system()
		var elapsed := now - saved_time
		if elapsed > 0.0:
			_apply_offline_progress(elapsed)
	followers_changed.emit(followers)

func _apply_offline_progress(elapsed: float) -> void:
	# Only managed businesses earn offline
	for i in biz_defs.size():
		if biz_count[i] <= 0 or not biz_has_mgr[i]:
			continue
		var payout := get_biz_payout(i)
		var cycle_time := get_biz_time(i)
		var cycles := floor(elapsed / cycle_time)
		var earned := payout * cycles
		followers += earned
		total_followers += earned
	_check_unlocks()
