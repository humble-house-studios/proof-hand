extends Control
## Proof Hand's screens (PRD §8): title → the Prover's Conjecture → each
## blind (intro, play, cash out, the Library) → run summary. Rules live in
## scripts/core/ (ProofRun, Blind, Scorer, AxiomEffects, Prover); this script
## draws state, animates the scoring and forwards taps. Layout is Containers.
## The office reads `_blind` (is_won()) to count proofs: keep the name.

const BOARD := Color(0.11, 0.14, 0.13)
const CHALK := Color(0.93, 0.93, 0.88)
const DIM := Color(0.93, 0.93, 0.88, 0.55)
const CHIPS_BLUE := Color(0.42, 0.67, 1.0)
const MULT_RED := Color(1.0, 0.42, 0.38)
const GOLD := Color(1.0, 0.84, 0.35)
const GREEN := Color(0.45, 0.9, 0.55)
const FIELD_COLORS: Array[Color] = [
	Color(0.91, 0.78, 0.42),  # Number Theory: chalk gold
	Color(0.42, 0.77, 0.72),  # Geometry: chalk teal
	Color(0.72, 0.61, 0.9),   # Analysis: chalk violet
	Color(0.93, 0.55, 0.48),  # Logic: chalk coral
]
const CARD_SIZE := Vector2(232, 340)
const LIFT := 36
const BUTTON_HEIGHT := 150
const MARGIN := 40
## How each hand is made, for the HANDS reference and the live preview.
const HAND_RULES := {
	"infinite_series": "5 in a row, all one Field",
	"tautology": "4 of the same rank",
	"symmetry": "5 cards that read the same both ways, in tap order (3-7-1-7-3)",
	"same_field": "5 cards of one Field",
	"sequence": "5 ranks in a row, any Fields (∞ is above 9)",
	"trinity": "3 of the same rank",
	"double_identity": "2 pairs",
	"identity": "a pair",
	"lone_term": "anything else: your highest card",
}
const SFX := ["select", "deselect", "chip", "mult", "xmult", "slam", "stamp", "coin", "buy", "discard", "proven", "refuted", "qed"]

var run: ProofRun
var _blind: Blind
var _bold: FontFile
var _busy := false
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _sfx_i := 0

var _play_root: Control
var _blind_label: Label
var _blind_title: Label
var _score_label: Label
var _plays_label: Label
var _discards_label: Label
var _money_label: Label
var _progress: ProgressBar
var _conj_label: Label
var _axiom_row: HBoxContainer
var _hand_label: Label
var _formula: RichTextLabel
var _last_label: Label
var _hint_button: Button
var _lemma_row: HBoxContainer
var _grid: GridContainer
var _play_button: Button
var _discard_button: Button
var _sort_button: Button
var _seed_label: Label
var _stamp: Label
var _overlay: Control
var _overlay_panel: PanelContainer
var _overlay_box: VBoxContainer
var _safe: MarginContainer
var _hint: Dictionary = {}


func _ready() -> void:
	var body: FontFile = load("res://fonts/DejaVuSans.ttf")
	_bold = load("res://fonts/DejaVuSans-Bold.ttf")
	theme = Theme.new()
	theme.default_font = body
	theme.default_font_size = 40
	for n in SFX:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()
	# Controller / arrow keys: a frame that moves between buttons, A presses.
	var pad: Node = preload("res://scripts/ui/pad_cursor.gd").new()
	pad.guide = [["DPAD", "Move over the cards"], ["A", "Pick / unpick a card"], ["X", "Play"], ["Y", "Discard"], ["RB", "Sort"]]
	add_child(pad)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_show_title()


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
	_play_root = _safe
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_safe.add_child(col)

	# Top bar: the blind and its target, score, Plays, Discards, money.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var bl := _stat(top, "LEMMA", "300", 1.3, GOLD)
	_blind_title = bl[0]
	_blind_label = bl[1]
	_score_label = _stat(top, "SCORE", "0", 1.2)[1]
	_plays_label = _stat(top, "PLAYS", "4", 0.75, CHIPS_BLUE)[1]
	_discards_label = _stat(top, "DISCARDS", "3", 0.95, MULT_RED)[1]
	_money_label = _stat(top, "GRANT", "$4", 0.8, GREEN)[1]

	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 26
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 13))
	_progress.add_theme_stylebox_override("fill", _box(GOLD, Color.TRANSPARENT, 0, 13))
	col.add_child(_progress)

	_conj_label = _label("", 30, GREEN)
	_conj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_conj_label)

	# Axioms, left to right (the order they apply in).
	_axiom_row = HBoxContainer.new()
	_axiom_row.add_theme_constant_override("separation", 10)
	_axiom_row.custom_minimum_size.y = 110
	col.add_child(_axiom_row)

	# The Prover panel: the live preview, the count-up, the verdict.
	var prover := PanelContainer.new()
	prover.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), DIM, 4, 24, 28))
	prover.custom_minimum_size.y = 330
	col.add_child(prover)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 8)
	prover.add_child(pcol)
	var head_row := HBoxContainer.new()
	pcol.add_child(head_row)
	var head := _label("◉  THE PROVER", 30, DIM)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	var hands := _button("HANDS", Color(0.25, 0.3, 0.28), 0.0, 30)
	hands.custom_minimum_size = Vector2(190, 84)
	hands.size_flags_horizontal = Control.SIZE_SHRINK_END
	hands.pressed.connect(_show_hands)
	head_row.add_child(hands)
	_hand_label = _label("Select up to 5 cards.", 60, CHALK, true)
	_hand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(_hand_label)
	_formula = RichTextLabel.new()
	_formula.bbcode_enabled = true
	_formula.fit_content = true
	_formula.scroll_active = false
	_formula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formula.add_theme_font_override("normal_font", _bold)
	_formula.add_theme_font_size_override("normal_font_size", 68)
	pcol.add_child(_formula)
	_last_label = _label("", 32, DIM)
	_last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(_last_label)
	_hint_button = _button("SHOW ME", Color(0.2, 0.36, 0.3), 0.0, 30)
	_hint_button.custom_minimum_size = Vector2(240, 84)
	_hint_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hint_button.pressed.connect(_use_hint)
	pcol.add_child(_hint_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_lemma_row = HBoxContainer.new()
	_lemma_row.add_theme_constant_override("separation", 12)
	col.add_child(_lemma_row)

	# The hand: two rows of four (see docs/DECISIONS.md).
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 6)
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
	_sort_button = _button("SORT\nRANK", Color(0.25, 0.3, 0.28), 0.8, 34)
	_sort_button.pressed.connect(_on_sort)
	_sort_button.set_meta("pad_button", JOY_BUTTON_RIGHT_SHOULDER)
	buttons.add_child(_sort_button)

	_seed_label = _label("", 24, Color(1, 1, 1, 0.3))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_seed_label)

	# The NOVEL / PROVEN stamp, over everything on the play screen.
	_stamp = _label("", 150, MULT_RED, true)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamp.add_theme_color_override("font_outline_color", BOARD)
	_stamp.add_theme_constant_override("outline_size", 24)
	_stamp.visible = false
	add_child(_stamp)

	_build_overlay()


## A labelled number in the top bar. Returns [title, value] labels.
func _stat(parent: Container, title: String, value: String, stretch: float, tint := CHALK) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 20, 14))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var t := _label(title, 24, DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	v.add_child(t)
	var l := _label(value, 50, tint, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return [t, l]


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.03, 0.05, 0.04, 0.88)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_overlay_panel = PanelContainer.new()
	_overlay_panel.add_theme_stylebox_override("panel", _box(BOARD, CHALK, 6, 32, 44))
	center.add_child(_overlay_panel)
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 22)
	_overlay_box.custom_minimum_size.x = 900
	_overlay_panel.add_child(_overlay_box)


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, stretch: float, font := 52) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = maxf(stretch, 0.01)
	b.add_theme_font_override("font", _bold)
	b.add_theme_font_size_override("font_size", font)
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


func _sfx(name: String, pitch := 1.0, db := 0.0) -> void:
	if not _sounds.has(name):
		return
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


# ---------------------------------------------------------------- overlay screens

## A screen over the board: a title, a body, then buttons [[text, Callable,
## color], ...]. extra: Controls placed between the body and the buttons.
func _screen(title: String, body: String, buttons: Array, extra: Array = [], title_color := CHALK) -> void:
	for c in _overlay_box.get_children():
		c.queue_free()
	if title != "":
		var t := _label(title, 96, title_color, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_overlay_box.add_child(t)
	if body != "":
		var b := _label(body, 40, CHALK)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_constant_override("line_spacing", 6)
		_overlay_box.add_child(b)
	for c in extra:
		_overlay_box.add_child(c)
	var first := true
	for spec in buttons:
		var btn := _button(spec[0], spec[2] if spec.size() > 2 else Color(0.2, 0.42, 0.75), 1.0)
		btn.pressed.connect(spec[1])
		if first:
			btn.set_meta("pad_button", JOY_BUTTON_START)
			first = false
		_overlay_box.add_child(btn)
	_overlay.visible = true


func _close_screen() -> void:
	_overlay.visible = false


func _show_title() -> void:
	var nb: Dictionary = Save.notebook
	var how := "Play the hand. Submit the proof.\n\n" + \
		"1  Tap up to 5 cards to make a hand:\n    pairs, runs, one Field...\n" + \
		"2  PLAY scores Chips × Mult.\n    Beat the target in 4 Plays.\n" + \
		"3  Between blinds, buy Axioms\n    that break the math.\n\n" + \
		"Prove 3 bosses to win the run."
	var extra: Array = []
	if int(nb.get("total_runs", 0)) > 0:
		var s := _label("Runs %d   ·   Wins %d   ·   Discoveries %d   ·   Best hand %d" % [
			int(nb.total_runs), int(nb.get("runs_won", 0)), nb.signatures.size(), int(nb.get("best_score", 0))], 30, GOLD)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extra.append(s)
	_screen("PROOF HAND", how, [["START A RUN", _new_run], ["HANDS", _show_hands, Color(0.25, 0.3, 0.28)]], extra, GOLD)


## Every hand, how to make it, and what it's worth right now.
func _show_hands() -> void:
	var was_playing := not _overlay.visible
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for t: HandType in Game.hand_types:
		var lv := int(run.levels.get(t.id, 1)) if run else 1
		var row := HBoxContainer.new()
		var name := _label("%s%s" % [t.name, "  Lv%d" % lv if lv > 1 else ""], 36, CHALK, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var nums := _label("%d × %d" % [t.chips_at(lv), t.mult_at(lv)], 36, GOLD, true)
		row.add_child(nums)
		list.add_child(row)
		var how := _label(HAND_RULES.get(t.id, ""), 28, DIM)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(how)
	_screen("HANDS", "Chips × Mult. Cards add their rank as Chips (∞ = 11).", [["BACK", _close_screen if was_playing else _show_title]], [list])


func _new_run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nb: Dictionary = Save.notebook
	run = ProofRun.new(Game.data, Game.hand_types, rng.randi() % 100000, nb.signatures)
	nb.total_runs = int(nb.get("total_runs", 0)) + 1
	Save.save_notebook()
	if run.conjecture == "":
		_blind_intro()
		return
	var p := _conj_parts(run.conjecture)
	var line := Prover.line(Game.data.prover_lines, "conjecture_propose", run.rng, {"hand": p[0], "fields": p[1]})
	_screen("THE PROVER", "\"%s\"\n\nPlay that hand this run:\nit scores ×2 Mult, and unlocks\na new Axiom for good." % line,
			[["BEGIN", _blind_intro]], [], GREEN)


## [hand name, "Analysis and Geometry"] for a signature.
func _conj_parts(sig: String) -> Array:
	var readable := Prover.readable(sig, Game.hand_types)
	var at := readable.find(" over ")
	if at < 0:
		at = readable.find(" in ")
		return [readable.substr(0, at), readable.substr(at + 4)]
	return [readable.substr(0, at), readable.substr(at + 6)]


## Before each blind: where you are on the ante, the target, the boss rule.
func _blind_intro() -> void:
	var sp := run.spec()
	var ladder: Array[String] = []
	for s in 3:
		var x := run.spec(run.ante, s)
		var mark := "▶ " if s == run.stage else ("✓ " if s < run.stage else "    ")
		ladder.append("%s%s  %d" % [mark, x.name if s < 2 else "Boss", x.target])
	var body := "Ante %d of %d\n\n%s\n\n" % [run.ante + 1, run.antes(), "\n".join(ladder)]
	var plays := 3 if sp.rule == "plays_3" else int(Game.data.blinds.plays_per_blind)
	body += "Score %d in %d Plays." % [sp.target, plays]
	if sp.kind == "boss":
		body += "\n\nBOSS RULE: %s" % sp.text
		if sp.taunt != "":
			body += "\n\"%s\"" % sp.taunt
	_screen(sp.name.to_upper(), body, [["PROVE IT", _start_blind]], [], MULT_RED if sp.kind == "boss" else GOLD)


func _start_blind() -> void:
	_close_screen()
	_blind = run.start_blind()
	_last_label.text = "Tap order is play order."
	_refresh()


# ---------------------------------------------------------------- play

func _on_card(card: Card) -> void:
	if _busy:
		return
	var was := _blind.is_selected(card)
	if _blind.toggle(card):
		_sfx("deselect" if was else "select", 1.0 + 0.05 * _blind.selected.size())
		_refresh()


func _on_play() -> void:
	if _busy or _blind == null or not _blind.can_play():
		return
	_busy = true
	var before := _blind.score
	var played: Array[Card] = _blind.selected.duplicate()
	var b := _blind.play()
	if b == null:
		_busy = false
		return
	var got := run.record(_blind.last_result, b)
	var nb: Dictionary = Save.notebook
	if got.novel:
		nb.signatures[got.signature] = int(nb.get("total_runs", 1))
	if b.total > int(nb.get("best_score", 0)):
		nb.best_score = b.total
	var unlocked := ""
	if got.proved:
		unlocked = _prove_conjecture()
	Save.save_notebook()
	_refresh_board(played)
	_play_button.disabled = true
	_discard_button.disabled = true
	_hint_button.visible = false
	await _count_up(b)
	# The score climbs into the bar.
	var t := create_tween()
	t.tween_method(func(v: float):
		_score_label.text = str(int(v))
		_progress.value = minf(v, _blind.target), float(before), float(_blind.score), 0.5)
	await t.finished
	if b.total >= int(_blind.target * 0.6):
		_shake(18.0)
	var verdict := Prover.line(Game.data.prover_lines, "novel" if got.novel else "verified", run.rng)
	_busy = false
	_refresh()
	_last_label.text = "%s  %s: %d." % [verdict, _blind.last_result.hand_type.name, b.total]
	if unlocked != "":
		_last_label.text += "\nConjecture proven! " + unlocked
	if _blind.is_over():
		await get_tree().create_timer(0.6).timeout
		_blind_over()


## Proving the Conjecture: a locked Axiom joins the shop for good (or $10).
func _prove_conjecture() -> String:
	var nb: Dictionary = Save.notebook
	nb.proven_conjectures.append(run.conjecture)
	for a: Dictionary in Game.data.axioms:
		if a.get("locked", false) and not a.id in nb.unlocked_axioms:
			nb.unlocked_axioms.append(a.id)
			return "%s unlocked in the Library." % a.name
	run.money += 10
	return "+$10."


## The scoring, Balatro-style: the hand, each card, each Axiom, the Prover,
## each a tick with a rising pitch; then Chips × Mult slam together.
func _count_up(b: Scorer.Breakdown) -> void:
	var chips := 0
	var mult := 0.0
	var pitch := 1.0
	_hand_label.text = _blind.last_result.hand_type.name
	for step in b.steps:
		chips += int(step.get("chips", 0))
		mult += float(step.get("mult", 0.0))
		var x := float(step.get("xmult", 0.0))
		if x > 0.0:
			mult *= x
		_formula.text = _formula_text(chips, mult)
		var what := ""
		if step.kind == "hand":
			what = "%s: %d × %s" % [step.source, step.chips, _mult_text(float(step.mult))]
			_sfx("chip", 0.8)
		elif step.kind == "card":
			what = "%s  +%d Chips" % [step.source, step.chips]
			_sfx("chip", pitch)
		elif x > 0.0:
			what = "%s  ×%s Mult" % [step.source, _mult_text(x)]
			_sfx("xmult", pitch)
		elif float(step.get("mult", 0.0)) > 0.0:
			what = "%s  +%s Mult" % [step.source, _mult_text(float(step.mult))]
			_sfx("mult", pitch)
		else:
			what = "%s  +%d Chips" % [step.source, step.chips]
			_sfx("chip", pitch)
		_last_label.text = what
		pitch += 0.06
		if step.kind == "prover" and step.source == "NOVEL":
			_do_stamp("NOVEL", MULT_RED)
		elif step.kind == "prover":
			_do_stamp("PROVEN", GREEN)
		await get_tree().create_timer(0.34 if step.kind in ["axiom", "prover"] else 0.16).timeout
	_formula.text = _formula_text(chips, mult) + "  [color=#%s]= %d[/color]" % [GOLD.to_html(false), b.total]
	_sfx("slam")
	_pop(_formula)
	await get_tree().create_timer(0.45).timeout


func _do_stamp(text: String, color: Color) -> void:
	_stamp.text = text
	_stamp.add_theme_color_override("font_color", color)
	_stamp.visible = true
	_stamp.pivot_offset = size * 0.5
	_stamp.rotation = -0.18
	_stamp.scale = Vector2(1.6, 1.6)
	_stamp.modulate.a = 1.0
	_sfx("stamp")
	var t := create_tween()
	t.tween_property(_stamp, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	t.tween_interval(0.6)
	t.tween_property(_stamp, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): _stamp.visible = false)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.15, 1.15)
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _shake(amount: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(_play_root, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * (1.0 - i / 6.0), 0.04)
	t.tween_property(_play_root, "position", Vector2.ZERO, 0.04)


func _on_discard() -> void:
	if _busy or _blind == null:
		return
	if _blind.discard():
		_sfx("discard")
		_refresh()
		_last_label.text = "Discarded. %d left." % _blind.discards_left


func _on_sort() -> void:
	if _busy or _blind == null:
		return
	_blind.toggle_sort()
	_refresh()


## SHOW ME: select the best hand the Prover can see.
func _use_hint() -> void:
	if _busy or _hint.is_empty():
		return
	for c in _blind.selected.duplicate():
		_blind.toggle(c)
	for c: Card in _hint.cards:
		_blind.toggle(c)
	_sfx("select", 1.2)
	_refresh()


func _use_lemma(i: int) -> void:
	if _busy:
		return
	var why := run.cant_use(i)
	if why != "":
		_last_label.text = why
		return
	var what := run.use_lemma(i)
	_sfx("stamp" if what == "sorry" else "buy")
	if what == "sorry":
		_refresh()
		_last_label.text = Prover.line(Game.data.prover_lines, "sorry_used", run.rng)
		await get_tree().create_timer(0.8).timeout
		_blind_over()
		return
	_refresh()
	_last_label.text = "%s applied." % what


# ---------------------------------------------------------------- after a blind

func _blind_over() -> void:
	run.finish_blind()
	if run.lost:
		_sfx("refuted")
		_run_over(false)
		return
	_sfx("proven")
	var sp := run.spec()
	var lines := run.cash_out()
	var total := 0
	var text: Array[String] = []
	for l in lines:
		text.append("%s   +$%d" % [l[0], l[1]])
		total += int(l[1])
	_sfx("coin")
	if run.advance():
		_run_over(true)
		return
	_screen("PROVEN.", "%s: %d of %d.\n\n%s\n\nGrant: +$%d  (you have $%d)" % [sp.name, _blind.score, _blind.target, "\n".join(text), total, run.money],
			[["TO THE LIBRARY", _open_library]], [], GOLD)


func _open_library() -> void:
	run.restock(Save.notebook.unlocked_axioms)
	_show_library("")


func _show_library(note: String) -> void:
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 14)
	for i in run.stock.size():
		var s: Dictionary = run.stock[i]
		var tag: String = {"axiom": "AXIOM", "lemma": "LEMMA", "study": "STUDY"}[s.kind]
		var ok := run.cant_buy(i) == ""
		var b := _button("%s  %s  ·  $%d\n%s" % [tag, s.item.name, s.price, s.item.text], Color(0.18, 0.3, 0.26) if ok else Color(0.2, 0.2, 0.2), 1.0, 30)
		b.custom_minimum_size.y = 130
		b.pressed.connect(_buy.bind(i))
		items.add_child(b)
	if run.stock.is_empty():
		items.add_child(_label("Sold out.", 34, DIM))
	items.add_child(_label("YOUR AXIOMS (they apply left to right):", 30, DIM))
	if run.axioms.is_empty():
		items.add_child(_label("None yet. They multiply everything.", 30, DIM))
	for i in run.axioms.size():
		var a: Dictionary = run.axioms[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := _label("%d. %s: %s" % [i + 1, a.name, a.text], 28, CHALK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if i > 0:
			var left := _button("◀", Color(0.25, 0.3, 0.28), 0.0, 30)
			left.custom_minimum_size = Vector2(96, 96)
			left.size_flags_horizontal = Control.SIZE_SHRINK_END
			left.pressed.connect(func():
				run.move_left(i)
				_show_library(""))
			row.add_child(left)
		var sell := _button("SELL $%d" % (int(a.price) / 2), Color(0.45, 0.22, 0.2), 0.0, 26)
		sell.custom_minimum_size = Vector2(190, 96)
		sell.size_flags_horizontal = Control.SIZE_SHRINK_END
		sell.pressed.connect(func():
			run.sell(i)
			_sfx("coin")
			_show_library(""))
		row.add_child(sell)
		items.add_child(row)
	if not run.lemmas.is_empty():
		items.add_child(_label("LEMMAS: " + ", ".join(run.lemmas.map(func(x): return x.name)), 28, DIM))
	var next := run.spec()
	var body := "Grant: $%d" % run.money
	if note != "":
		body += "\n" + note
	_screen("THE LIBRARY", body, [
		["NEXT: %s (%d)" % [next.name.to_upper(), next.target], _blind_intro],
		["REROLL  $%d" % run.reroll_price, _reroll, Color(0.3, 0.3, 0.2)],
	], [items], GOLD)


func _buy(i: int) -> void:
	var why := run.cant_buy(i)
	if why != "":
		_show_library(why)
		return
	var s: Dictionary = run.stock[i]
	run.buy(i)
	_sfx("buy")
	_show_library("Bought %s." % s.item.name)


func _reroll() -> void:
	if run.reroll(Save.notebook.unlocked_axioms):
		_sfx("discard")
		_show_library("")
	else:
		_show_library("Not enough money to reroll.")


func _run_over(won: bool) -> void:
	var nb: Dictionary = Save.notebook
	if won:
		nb.runs_won = int(nb.get("runs_won", 0)) + 1
		_sfx("qed")
	Save.save_notebook()
	var found: Array[String] = []
	for sig in run.discoveries:
		found.append("· " + Prover.readable(sig, Game.hand_types))
	var body := ""
	if won:
		body = "All three bosses proven.\n\"%s\"" % Prover.line(Game.data.prover_lines, "run_won", run.rng)
	else:
		body = "%s: %d of %d.\n\"%s\"" % [run.spec().name, _blind.score, _blind.target, Prover.line(Game.data.prover_lines, "run_lost", run.rng)]
	body += "\n\nReached Ante %d.  Best hand: %d%s." % [run.ante + 1, run.best_hand, " (%s)" % run.best_hand_name if run.best_hand_name != "" else ""]
	if run.conjecture != "":
		body += "\nConjecture: %s." % ("PROVEN" if run.proven else "unproven")
	if not found.is_empty():
		body += "\n\nNew in the Notebook (%d):\n%s" % [found.size(), "\n".join(found.slice(0, 6))]
	body += "\n\nSeed %d" % run.seed_value
	_screen("Q.E.D." if won else "REFUTED.", body, [["NEW RUN", _new_run], ["TITLE", _show_title, Color(0.25, 0.3, 0.28)]], [], GOLD if won else MULT_RED)


# ---------------------------------------------------------------- draw

func _refresh() -> void:
	if _blind == null or run == null:
		return
	var sp := run.spec()
	_blind_title.text = sp.name.to_upper() if sp.kind != "boss" else "BOSS"
	_blind_label.text = str(_blind.target)
	_score_label.text = str(_blind.score)
	_plays_label.text = str(_blind.plays_left)
	_discards_label.text = str(_blind.discards_left)
	_money_label.text = "$%d" % run.money
	_progress.max_value = _blind.target
	_progress.value = mini(_blind.score, _blind.target)
	_seed_label.text = "Ante %d · Seed %d%s" % [run.ante + 1, run.seed_value, ("  ·  BOSS: " + sp.text) if sp.kind == "boss" else ""]
	if run.conjecture != "":
		var p := _conj_parts(run.conjecture)
		_conj_label.text = ("✓ PROVEN: %s over %s (×2 Mult)" if run.proven else "CONJECTURE: %s over %s → ×2 Mult") % [p[0], p[1]]
		_conj_label.add_theme_color_override("font_color", GREEN if run.proven else GOLD)
	else:
		_conj_label.text = ""
	_refresh_axioms()
	_refresh_lemmas()

	var preview := _blind.preview()
	_hint = {}
	_hint_button.visible = false
	if preview == null:
		_hand_label.text = "Select up to 5 cards."
		_formula.text = ""
		# The Prover coaches the first ante only; after that it's on you.
		if not _busy and not _blind.is_over() and run.ante == 0:
			_hint = run.best_in_hand()
			if not _hint.is_empty():
				_last_label.text = "Best you hold: %s, about %d." % [_hint.result.hand_type.name, _hint.total]
				_hint_button.visible = true
	elif not _busy:
		var b := run.score(preview)
		var tags := ""
		var sig := Prover.signature(preview)
		if sig == run.conjecture:
			tags = "  · ×2!"
		elif not run.seen.has(sig):
			tags = "  · NEW"
		_hand_label.text = preview.hand_type.name + tags
		_formula.text = _formula_text(b.chips, b.mult) + "  [color=#%s]= %d[/color]" % [DIM.to_html(true), b.total]
		_last_label.text = "%s.  Need %d more." % [str(HAND_RULES.get(preview.hand_type.id, "")).capitalize(), maxi(0, _blind.target - _blind.score)]

	_play_button.disabled = not _blind.can_play() or _busy
	_discard_button.disabled = not _blind.can_discard() or _busy
	_sort_button.text = "SORT\n" + ("RANK" if _blind.sort_mode == Blind.SortMode.RANK else "FIELD")
	_refresh_board([])


func _refresh_board(gone: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var scoring: Array = []
	var p := _blind.preview()
	if p != null:
		scoring = p.scoring
	for card in _blind.hand:
		if card in gone:
			continue
		_grid.add_child(_card_view(card, card in scoring))


func _refresh_axioms() -> void:
	for c in _axiom_row.get_children():
		c.queue_free()
	for i in ProofRun.MAX_AXIOMS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has := i < run.axioms.size()
		panel.add_theme_stylebox_override("panel", _box(Color(0.2, 0.17, 0.25) if has else Color(1, 1, 1, 0.04), Color(0.75, 0.6, 1.0) if has else Color(1, 1, 1, 0.12), 3, 16, 8))
		var l := _label(run.axioms[i].name if has else "axiom", 24 if has else 22, CHALK if has else Color(1, 1, 1, 0.2), has)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(l)
		if has:
			var info := Button.new()
			info.flat = true
			info.focus_mode = Control.FOCUS_NONE
			info.pressed.connect(func(): _last_label.text = "%s: %s" % [run.axioms[i].name, run.axioms[i].text])
			panel.add_child(info)
		_axiom_row.add_child(panel)


func _refresh_lemmas() -> void:
	for c in _lemma_row.get_children():
		c.queue_free()
	for i in run.lemmas.size():
		var l: Dictionary = run.lemmas[i]
		var b := _button("USE %s" % str(l.name).to_upper(), Color(0.35, 0.25, 0.45), 1.0, 28)
		b.custom_minimum_size.y = 96
		b.pressed.connect(_use_lemma.bind(i))
		_lemma_row.add_child(b)


func _formula_text(chips: int, mult: float) -> String:
	return "[color=#%s]%d[/color] × [color=#%s]%s[/color]" % [CHIPS_BLUE.to_html(false), chips, MULT_RED.to_html(false), _mult_text(mult)]


func _mult_text(mult: float) -> String:
	return str(int(mult)) if is_equal_approx(mult, roundf(mult)) else "%.1f" % mult


## One card: a tall chalk-outlined button. Selected cards lift and show their
## play-order badge; the ones that would score glow gold.
func _card_view(card: Card, scores: bool) -> Control:
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
	var border := GOLD if scores else (CHALK if order > 0 else color)
	var width := 10 if scores else 6
	b.add_theme_stylebox_override("normal", _box(bg, border, width, 22))
	b.add_theme_stylebox_override("hover", _box(bg, border, width, 22))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.08), border, width, 22))
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
