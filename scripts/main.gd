extends Control
## Main UI controller for Creator Empire.
## Dynamically builds business cards and handles player interaction.

const AUTOSAVE_INTERVAL := 15.0
const FLOAT_LABEL_DURATION := 1.0

@onready var follower_label: Label = %FollowerLabel
@onready var rate_label: Label = %RateLabel
@onready var clout_label: Label = %CloutLabel
@onready var combo_bar: ProgressBar = %ComboBar
@onready var combo_label: Label = %ComboLabel
@onready var tap_button: Button = %TapButton
@onready var biz_container: VBoxContainer = %BizContainer

var biz_cards: Array[PanelContainer] = []
var autosave_timer: float = 0.0

## -----------------------------------------------------------------------

func _ready() -> void:
	_build_business_cards()
	_connect_signals()
	_update_header()
	_update_all_cards()
	# Show offline earnings
	var fps := GameState.get_followers_per_second()
	if fps > 0.0:
		_show_float_text("Welcome back!", tap_button)

func _process(delta: float) -> void:
	_update_header()
	_update_timers()
	# Autosave
	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_INTERVAL:
		autosave_timer = 0.0
		GameState.save_game()

## Signals ---------------------------------------------------------------

func _connect_signals() -> void:
	GameState.followers_changed.connect(_on_followers_changed)
	GameState.business_updated.connect(_on_business_updated)
	GameState.milestone_reached.connect(_on_milestone_reached)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.prestige_done.connect(_on_prestige_done)
	tap_button.pressed.connect(_on_tap_pressed)

func _on_followers_changed(_amount: float) -> void:
	_update_header()

func _on_business_updated(index: int) -> void:
	_update_card(index)

func _on_milestone_reached(biz_name: String, milestone: int) -> void:
	AudioManager.milestone()
	_show_notification("%s reached %d!" % [biz_name, milestone])

func _on_combo_changed(multiplier: int) -> void:
	combo_label.text = "COMBO x%d" % multiplier
	combo_bar.value = float(multiplier) / float(GameState.COMBO_MAX) * 100.0

func _on_prestige_done(clout: float) -> void:
	_build_business_cards()
	_update_all_cards()
	_show_notification("Gone Viral! Clout: %s" % Format.number(clout))

## Tap -------------------------------------------------------------------

func _on_tap_pressed() -> void:
	var earned := GameState.tap()
	_show_float_text("+" + Format.number(earned), tap_button)
	# Also start first business if idle
	GameState.start_business(0)

## Header ----------------------------------------------------------------

func _update_header() -> void:
	follower_label.text = Format.followers(GameState.followers)
	var fps := GameState.get_followers_per_second()
	if fps > 0.0:
		rate_label.text = "%s/sec" % Format.number(fps)
	else:
		rate_label.text = ""
	if GameState.clout > 0.0:
		clout_label.text = "Clout: %s (+%d%%)" % [Format.number(GameState.clout), int(GameState.clout * 2)]
		clout_label.visible = true
	else:
		clout_label.visible = false

## Business cards --------------------------------------------------------

func _build_business_cards() -> void:
	# Clear existing
	for child in biz_container.get_children():
		child.queue_free()
	biz_cards.clear()

	for i in GameState.biz_defs.size():
		var card := _create_biz_card(i)
		biz_container.add_child(card)
		biz_cards.append(card)

func _create_biz_card(index: int) -> PanelContainer:
	var def: Dictionary = GameState.biz_defs[index]
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.25, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 120)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Row 1: Name + Count
	var row1 := HBoxContainer.new()
	vbox.add_child(row1)
	var name_lbl := Label.new()
	name_lbl.text = def["name"]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.name = "NameLabel"
	row1.add_child(name_lbl)
	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.add_theme_font_size_override("font_size", 18)
	count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	row1.add_child(count_lbl)

	# Row 2: Payout + Milestone
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	var payout_lbl := Label.new()
	payout_lbl.name = "PayoutLabel"
	payout_lbl.add_theme_font_size_override("font_size", 14)
	payout_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	payout_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(payout_lbl)
	var milestone_lbl := Label.new()
	milestone_lbl.name = "MilestoneLabel"
	milestone_lbl.add_theme_font_size_override("font_size", 13)
	milestone_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row2.add_child(milestone_lbl)

	# Row 3: Timer bar
	var timer_bar := ProgressBar.new()
	timer_bar.name = "TimerBar"
	timer_bar.custom_minimum_size = Vector2(0, 16)
	timer_bar.value = 0.0
	timer_bar.show_percentage = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.8, 0.3, 0.9)
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	timer_bar.add_theme_stylebox_override("fill", bar_style)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.25)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	timer_bar.add_theme_stylebox_override("background", bar_bg)
	vbox.add_child(timer_bar)

	# Row 4: Buttons
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 8)
	vbox.add_child(row4)

	var collect_btn := Button.new()
	collect_btn.name = "CollectBtn"
	collect_btn.text = "COLLECT"
	collect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(collect_btn, Color(0.2, 0.7, 0.3))
	collect_btn.pressed.connect(_on_collect_pressed.bind(index))
	row4.add_child(collect_btn)

	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(buy_btn, Color(0.3, 0.4, 0.9))
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	row4.add_child(buy_btn)

	var hire_btn := Button.new()
	hire_btn.name = "HireBtn"
	hire_btn.text = "Hire Editor"
	hire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(hire_btn, Color(0.7, 0.3, 0.7))
	hire_btn.pressed.connect(_on_hire_pressed.bind(index))
	row4.add_child(hire_btn)

	return panel

func _style_button(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 14)

func _update_all_cards() -> void:
	for i in biz_cards.size():
		_update_card(i)

func _update_card(index: int) -> void:
	if index >= biz_cards.size():
		return
	var card := biz_cards[index]
	var count := GameState.biz_count[index]
	var unlocked := GameState.biz_unlocked[index]

	card.visible = unlocked

	if not unlocked:
		return

	var count_lbl: Label = card.find_child("CountLabel", true, false)
	var payout_lbl: Label = card.find_child("PayoutLabel", true, false)
	var milestone_lbl: Label = card.find_child("MilestoneLabel", true, false)
	var buy_btn: Button = card.find_child("BuyBtn", true, false)
	var hire_btn: Button = card.find_child("HireBtn", true, false)
	var collect_btn: Button = card.find_child("CollectBtn", true, false)

	count_lbl.text = "x%d" % count

	if count > 0:
		payout_lbl.text = "+%s" % Format.number(GameState.get_biz_payout(index))
	else:
		payout_lbl.text = ""

	var next_ms := GameState.next_milestone(count)
	if next_ms > 0:
		milestone_lbl.text = "Next: %d" % next_ms
	else:
		milestone_lbl.text = "MAX"

	var cost := GameState.get_biz_cost(index)
	buy_btn.text = "BUY %s" % Format.number(cost)
	buy_btn.disabled = GameState.followers < cost

	if GameState.biz_has_mgr[index]:
		hire_btn.text = "Hired!"
		hire_btn.disabled = true
	else:
		var mgr_cost: float = GameState.biz_defs[index]["mgr_cost"]
		hire_btn.text = "Hire %s" % Format.number(mgr_cost)
		hire_btn.disabled = GameState.followers < mgr_cost or count <= 0

	# Collect button: enabled only when timer idle and no manager and count > 0
	var timer_idle := GameState.biz_timer[index] < 0.0
	collect_btn.visible = not GameState.biz_has_mgr[index] and count > 0
	if timer_idle and count > 0 and not GameState.biz_has_mgr[index]:
		collect_btn.text = "COLLECT"
		collect_btn.disabled = false
	else:
		collect_btn.text = "COLLECT"
		collect_btn.disabled = true

func _update_timers() -> void:
	for i in biz_cards.size():
		if not GameState.biz_unlocked[i]:
			continue
		var card := biz_cards[i]
		var timer_bar: ProgressBar = card.find_child("TimerBar", true, false)
		timer_bar.value = GameState.get_biz_progress(i) * 100.0
		# Also refresh buy/hire button enabled state
		var buy_btn: Button = card.find_child("BuyBtn", true, false)
		buy_btn.disabled = GameState.followers < GameState.get_biz_cost(i)
		if not GameState.biz_has_mgr[i]:
			var hire_btn: Button = card.find_child("HireBtn", true, false)
			var mgr_cost: float = GameState.biz_defs[i]["mgr_cost"]
			hire_btn.disabled = GameState.followers < mgr_cost or GameState.biz_count[i] <= 0

## Button handlers -------------------------------------------------------

func _on_collect_pressed(index: int) -> void:
	# Start the business cycle (manual operation)
	if GameState.biz_timer[index] < 0.0 and GameState.biz_count[index] > 0:
		GameState.start_business(index)
		AudioManager.collect()

func _on_buy_pressed(index: int) -> void:
	if GameState.buy_business(index):
		var card := biz_cards[index]
		_show_float_text("+1 " + GameState.biz_defs[index]["name"], card)

func _on_hire_pressed(index: int) -> void:
	GameState.hire_manager(index)

## Floating text ---------------------------------------------------------

func _show_float_text(text: String, anchor: Control) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	lbl.z_index = 100
	lbl.position = anchor.global_position + Vector2(anchor.size.x * 0.3, -10)
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 60.0, FLOAT_LABEL_DURATION)
	tween.tween_property(lbl, "modulate:a", 0.0, FLOAT_LABEL_DURATION)
	tween.chain().tween_callback(lbl.queue_free)

## Notification ----------------------------------------------------------

func _show_notification(text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.3, 0.6, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	panel.z_index = 200
	add_child(panel)
	panel.position = Vector2(size.x * 0.1, size.y * 0.4)
	panel.size = Vector2(size.x * 0.8, 0)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)

## Prestige button (called from UI if added) -----------------------------

func _on_prestige_pressed() -> void:
	var pending := GameState.get_pending_clout()
	if pending > 0:
		GameState.prestige()
