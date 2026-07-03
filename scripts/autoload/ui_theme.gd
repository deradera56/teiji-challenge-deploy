extends Node
## 共通UIテーマ。日本語フォント設定とUI部品の生成ヘルパー。
## Material Design風のフラットな配色（色覚バリアフリー考慮：色＋アイコン/文字で区別）

const BG := Color(0.10, 0.13, 0.16)
const PANEL := Color(0.16, 0.20, 0.24)
const CARD := Color(0.19, 0.24, 0.29)
const CARD_URGENT := Color(0.30, 0.17, 0.16)
const ACCENT := Color(0.25, 0.56, 0.88)
const GOOD := Color(0.27, 0.65, 0.42)
const WARN := Color(0.92, 0.62, 0.18)
const BAD := Color(0.85, 0.31, 0.29)
const AI_COL := Color(0.55, 0.40, 0.85)
const TEXT_MAIN := Color(0.94, 0.96, 0.98)
const TEXT_DIM := Color(0.63, 0.69, 0.75)


func _ready() -> void:
	# Godot標準フォントはCJK非対応。同梱フォント（日本語＋絵文字サブセット）を使う。
	# Webビルドでも表示できるようフォントは res://ui/fonts/ に同梱している。
	# 同梱フォントに無い文字はデスクトップではOSフォントにフォールバックする。
	var jp := FontFile.new()
	var jp_err := jp.load_dynamic_font("res://ui/fonts/noto_jp_subset.otf")
	var emoji := FontFile.new()
	var emoji_err := emoji.load_dynamic_font("res://ui/fonts/noto_emoji_subset.ttf")
	if jp_err == OK:
		var fallbacks: Array[Font] = []
		if emoji_err == OK:
			fallbacks.append(emoji)
		if not OS.has_feature("web"):
			fallbacks.append(_system_font())
		jp.fallbacks = fallbacks
		ThemeDB.fallback_font = jp
	else:
		# フォントが読めない場合の保険（OSフォント頼み）
		push_warning("同梱フォントの読み込みに失敗しました")
		ThemeDB.fallback_font = _system_font()
	ThemeDB.fallback_font_size = 28


func _system_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Yu Gothic UI", "Meiryo", "MS Gothic",
		"Hiragino Sans", "Noto Sans CJK JP", "sans-serif",
	])
	return f


func flat_style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(18)
	return sb


## 画面全体の背景を敷く
func fill_bg(parent: Control, color: Color = BG) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	parent.move_child(rect, 0)


func make_label(text: String, size: int = 28, color: Color = TEXT_MAIN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func make_button(text: String, bg: Color = ACCENT, font_size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_color_override("font_hover_color", TEXT_MAIN)
	b.add_theme_color_override("font_pressed_color", TEXT_DIM)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var normal := flat_style(bg, 12)
	var hover := flat_style(bg.lightened(0.1), 12)
	var pressed := flat_style(bg.darkened(0.2), 12)
	var disabled := flat_style(Color(bg.r, bg.g, bg.b, 0.35), 12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, 72)
	return b


func make_panel(color: Color = PANEL, radius: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat_style(color, radius))
	return p


func make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0, 0, 0, 0.35)
	bg_sb.set_corner_radius_all(8)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", fill_sb)
	return bar


func vspace(height: float = 20.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## 画面中央寄せの縦レイアウト（マージン付き）を作って返す
func make_margin_vbox(parent: Control, margin: int = 32, separation: int = 16) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", margin)
	mc.add_theme_constant_override("margin_right", margin)
	mc.add_theme_constant_override("margin_top", margin)
	mc.add_theme_constant_override("margin_bottom", margin)
	parent.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", separation)
	mc.add_child(vb)
	return vb
