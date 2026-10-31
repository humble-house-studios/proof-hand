extends Control
## M2 play screen: one blind. Deal 8, tap cards to select (the badge shows
## play order), Play / Discard / Sort, live hand preview from the Prover panel,
## score against the target. Rules live in scripts/core/ (Blind); this script
## only draws state and forwards taps. Layout is Containers only.

const BOARD := Color(0.11, 0.14, 0.13)
const CHALK := Color(0.93, 0.93, 0.88)
const DIM := Color(0.93, 0.93, 0.88, 0.55)
const CHIPS_BLUE := Color(0.42, 0.67, 1.0)
const MULT_RED := Color(1.0, 0.42, 0.38)
const FIELD_COLORS: Array[Color] = [
	Color(0.91, 0.78, 0.42),  # Number Theory: chalk gold
	Color(0.42, 0.77, 0.72),  # Geometry: chalk teal
	Color(0.72, 0.61, 0.9),   # Analysis: chalk violet
	Color(0.93, 0.55, 0.48),  # Logic: chalk coral
]
const CARD_SIZE := Vector2(232, 360)
const LIFT := 40
const BUTTON_HEIGHT := 150
const MARGIN := 40

var _blind: Blind
var _seed: int
var _bold: FontFile

var _blind_label: Label
var _score_label: Label
var _plays_label: Label
var _discards_label: Label
var _progress: ProgressBar
var _hand_label: Label
var _formula: RichTextLabel
var _last_label: Label
var _grid: GridContainer
var _play_button: Button
var _discard_button: Button
var _sort_button: Button
var _seed_label: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_text: Label
var _safe: MarginContainer


func _ready() -> void:
	var body: FontFile = load("res://fonts/DejaVuSans.ttf")
	_bold = load("res://fonts/DejaVuSans-Bold.ttf")
	theme = Theme.new()
	theme.default_font = body
	theme.default_font_size = 40
	_build()
	# Controller / arrow keys: a frame that moves between buttons, A presses.
	add_child(preload("res://scripts/ui/pad_cursor.gd").new())
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_new_blind()


# ---------------------------------------------------------------- build

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BOARD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	_safe.add_child(col)

	# Top bar: blind + target, score, Plays, Discards.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	_blind_label = _stat(top, "LEMMA", "Target 300", 1.4)
	_score_label = _stat(top, "SCORE", "0", 1.2)
	_plays_label = _stat(top, "PLAYS", "4", 0.8, CHIPS_BLUE)
	_discards_label = _stat(top, "DISCARDS", "3", 0.8, MULT_RED)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 28
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 14))
	_progress.add_theme_stylebox_override("fill", _box(FIELD_COLORS[0], Color.TRANSPARENT, 0, 14))
	col.add_child(_progress)

	# The Prover panel: live preview of the selection, and the last Play.
	var prover := PanelContainer.new()
	prover.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), DIM, 4, 24, 32))
	prover.custom_minimum_size.y = 360
	col.add_child(prover)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 10)
	prover.add_child(pcol)
	var head := _label("◉  THE PROVER", 32, DIM)
	pcol.add_child(head)
	_hand_label = _label("Select up to 5 cards.", 64, CHALK, true)
	_hand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(_hand_label)
	_formula = RichTextLabel.new()
	_formula.bbcode_enabled = true
	_formula.fit_content = true
	_formula.scroll_active = false
	_formula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formula.add_theme_font_override("normal_font", _bold)
	_formula.add_theme_font_size_override("normal_font_size", 72)
	pcol.add_child(_formula)
	_last_label = _label("Tap order is play order.", 34, DIM)
	_last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(_last_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# The hand: two rows of four (see docs/DECISIONS.md).
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_grid)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	_play_button = _button("PLAY", Color(0.2, 0.42, 0.75), 1.6)
	_play_button.pressed.connect(_on_play)
	_play_button.set_meta("pad_button", JOY_BUTTON_X)
	buttons.add_child(_play_button)
	_discard_button = _button("DISCARD", Color(0.62, 0.25, 0.24), 1.2)
	_discard_button.pressed.connect(_on_discard)
	_discard_button.set_meta("pad_button", JOY_BUTTON_Y)
	buttons.add_child(_discard_button)
	_sort_button = _button("SORT\nRANK", Color(0.25, 0.3, 0.28), 0.8)
	_sort_button.add_theme_font_size_override("font_size", 34)
	_sort_button.pressed.connect(_on_sort)
	_sort_button.set_meta("pad_button", JOY_BUTTON_RIGHT_SHOULDER)
	buttons.add_child(_sort_button)

	_seed_label = _label("", 26, Color(1, 1, 1, 0.3))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_seed_label)

	_build_overlay()


## A labelled number in the top bar. Returns the value label.
func _stat(parent: Container, title: String, value: String, stretch: float, tint := CHALK) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 20, 18))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var t := _label(title, 26, DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := _label(value, 52, tint, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return l


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(BOARD, CHALK, 6, 32, 56))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 32)
	v.custom_minimum_size.x = 760
	panel.add_child(v)
	_overlay_title = _label("", 110, CHALK, true)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_overlay_title)
	_overlay_text = _label("", 44, DIM)
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_overlay_text)
	var again := _button("NEW BLIND", Color(0.2, 0.42, 0.75), 1.0)
	again.pressed.connect(_new_blind)
	again.set_meta("pad_button", JOY_BUTTON_START)
	v.add_child(again)


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, stretch: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = stretch
	b.add_theme_font_override("font", _bold)
	b.add_theme_font_size_override("font_size", 52)
	b.add_theme_color_override("font_color", CHALK)
	b.add_theme_color_override("font_pressed_color", CHALK)
	b.add_theme_color_override("font_hover_color", CHALK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.add_theme_stylebox_override("normal", _box(color, CHALK, 4, 24))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.1), CHALK, 4, 24))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), CHALK, 4, 24))
	b.add_theme_stylebox_override("disabled", _box(color.darkened(0.55), Color(1, 1, 1, 0.2), 4, 24))
	return b


func _box(bg: Color, border: Color, border_w: int, radius: int, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _apply_safe_area() -> void:
	var left := float(MARGIN)
	var top := float(MARGIN)
	var right := float(MARGIN)
	var bottom := float(MARGIN)
	if OS.has_feature("mobile") and get_viewport() == get_window():
		var window := Vector2(DisplayServer.window_get_size())
		if window.x > 0 and window.y > 0:
			var to_view := get_viewport_rect().size / window
			var safe := Rect2(DisplayServer.get_display_safe_area())
			left += safe.position.x * to_view.x
			top += safe.position.y * to_view.y
			right += (window.x - safe.end.x) * to_view.x
			bottom += (window.y - safe.end.y) * to_view.y
	_safe.add_theme_constant_override("margin_left", int(left))
	_safe.add_theme_constant_override("margin_top", int(top))
	_safe.add_theme_constant_override("margin_right", int(right))
	_safe.add_theme_constant_override("margin_bottom", int(bottom))


# ---------------------------------------------------------------- flow

## M2 has one hard-coded blind: Ante 1's Lemma (target from data/blinds.json).
func _new_blind() -> void:
	var cfg: Dictionary = Game.data["blinds"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_seed = rng.randi() % 100000
	rng.seed = _seed
	_blind = Blind.new("Lemma", int(cfg["antes"][0]["lemma"]), Deck.new(rng),
			HandEvaluator.new(Game.hand_types), int(cfg["hand_size"]),
			int(cfg["plays_per_blind"]), int(cfg["discards_per_blind"]))
	_blind.start()
	_overlay.visible = false
	_last_label.text = "Tap order is play order."
	_refresh()


func _on_card(card: Card) -> void:
	if _blind.toggle(card):
		_refresh()


func _on_play() -> void:
	var b := _blind.play()
	if b == null:
		return
	_last_label.text = "Verified: %s, %d × %s = %d" % [
		_blind.last_result.hand_type.name, b.chips, _mult_text(b.mult), b.total]
	_refresh()
	if _blind.is_over():
		_show_result()


func _on_discard() -> void:
	if _blind.discard():
		_refresh()


func _on_sort() -> void:
	_blind.toggle_sort()
	_refresh()


func _show_result() -> void:
	_overlay.visible = true
	if _blind.is_won():
		_overlay_title.text = "PROVEN."
		_overlay_text.text = "%d against a target of %d,\nwith %d Plays to spare." % [_blind.score, _blind.target, _blind.plays_left]
	else:
		_overlay_title.text = "REFUTED."
		_overlay_text.text = "%d of %d. The Prover is unconvinced." % [_blind.score, _blind.target]


# ---------------------------------------------------------------- draw

func _refresh() -> void:
	_blind_label.text = "Target %d" % _blind.target
	_score_label.text = str(_blind.score)
	_plays_label.text = str(_blind.plays_left)
	_discards_label.text = str(_blind.discards_left)
	_progress.max_value = _blind.target
	_progress.value = mini(_blind.score, _blind.target)
	_seed_label.text = "Seed %d" % _seed

	var preview := _blind.preview()
	if preview == null:
		_hand_label.text = "Select up to 5 cards."
		_formula.text = ""
	else:
		var b := Scorer.score(preview)
		_hand_label.text = preview.hand_type.name
		_formula.text = "[color=#%s]%d[/color] × [color=#%s]%s[/color]" % [
			CHIPS_BLUE.to_html(false), b.chips, MULT_RED.to_html(false), _mult_text(b.mult)]

	_play_button.disabled = not _blind.can_play()
	_discard_button.disabled = not _blind.can_discard()
	_sort_button.text = "SORT\n" + ("RANK" if _blind.sort_mode == Blind.SortMode.RANK else "FIELD")

	for c in _grid.get_children():
		c.queue_free()
	for card in _blind.hand:
		_grid.add_child(_card_view(card))


func _mult_text(mult: float) -> String:
	return str(int(mult)) if is_equal_approx(mult, roundf(mult)) else "%.1f" % mult


## One card: a tall chalk-outlined button. Selected cards lift and show their
## play-order badge.
func _card_view(card: Card) -> Control:
	var order := _blind.order_of(card)
	var slot := MarginContainer.new()
	slot.add_theme_constant_override("margin_top", 0 if order > 0 else LIFT)
	slot.add_theme_constant_override("margin_bottom", LIFT if order > 0 else 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var color := FIELD_COLORS[card.field]
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE
	var bg := Color(0.2, 0.24, 0.22) if order > 0 else Color(0.15, 0.19, 0.17)
	var border := CHALK if order > 0 else color
	b.add_theme_stylebox_override("normal", _box(bg, border, 6, 22))
	b.add_theme_stylebox_override("hover", _box(bg, border, 6, 22))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.08), border, 6, 22))
	b.pressed.connect(_on_card.bind(card))
	slot.add_child(b)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var rank := _label("∞" if card.rank == Card.INFINITY else str(card.rank), 120, color, true)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rank)
	var glyph := _label(Card.FIELD_GLYPHS[card.field], 64, color)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(glyph)

	if order > 0:
		var badge := Label.new()
		badge.text = str(order)
		badge.add_theme_font_override("font", _bold)
		badge.add_theme_font_size_override("font_size", 40)
		badge.add_theme_color_override("font_color", BOARD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", _box(CHALK, Color.TRANSPARENT, 0, 32))
		badge.custom_minimum_size = Vector2(64, 64)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -76
		badge.offset_right = -12
		badge.offset_top = 12
		badge.offset_bottom = 76
		b.add_child(badge)
	return slot
