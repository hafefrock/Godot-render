extends RefCounted
# Warna dan gaya tampilan bersama.

const BG := Color("#0F1115")
const PANEL := Color("#171A21")
const PANEL2 := Color("#20242D")
const ACCENT := Color("#FFD400")
const TEXT := Color("#E8EAED")
const MUTED := Color("#8B93A1")


static func box(color: Color, radius: int = 14, margin: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func style_button(b: Button, primary: bool = false) -> void:
	var normal: Color = ACCENT if primary else PANEL2
	var hover: Color = normal.lightened(0.12)
	var pressed: Color = normal.darkened(0.15)
	b.add_theme_stylebox_override("normal", box(normal, 14, 14))
	b.add_theme_stylebox_override("hover", box(hover, 14, 14))
	b.add_theme_stylebox_override("pressed", box(pressed, 14, 14))
	b.add_theme_stylebox_override("focus", box(hover, 14, 14))
	var fc: Color = Color.BLACK if primary else TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 56)


static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, primary)
	return b


static func label(text: String, font_size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 16, 12))
	return p
