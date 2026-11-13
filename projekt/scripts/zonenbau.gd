class_name Zonenbau
extends Node2D
## Gebäude in der Zone des Gegners. Alle sind erst in der letzten Runde angreifbar.
##   "hq"        – das Hauptquartier
##   "schleuder" – wirft im Bogen Steine auf Truppen in Stellungen und auf Fabriken
##   "wurf"      – Wurf-Schleuder: wirft Hunde über die ersten Wälle (gesteuert von main.gd)
##   "laser"     – schießt flach auf Bodentruppen; Wälle geben Deckung

var spiel: Node
var karte: Karte
var art := "hq"
var zelle := Karte.KEINE
var leben := 1.0
var max_leben := 1.0

var _abkling := 0.0
var _sprite: Figur
var _treffer := 0.0
var _zeit := 0.0
var _umzug_in := 0.0               # Stein-Schleuder: Sekunden bis zum nächsten Platzwechsel in der Runde
var _faehrt := false
var _fahrziel := Vector2.ZERO


func start(p_spiel: Node, p_karte: Karte, p_art: String, p_zelle: Vector2i) -> void:
	spiel = p_spiel
	karte = p_karte
	art = p_art
	zelle = p_zelle
	position = karte.mitte(zelle)
	match art:
		"hq":
			max_leben = Werte.HQ_LEBEN
		"laser":
			max_leben = Werte.LASER["leben"]
			_figur(Werte.LASER)
		_:
			max_leben = Werte.SCHLEUDER["leben"]
			_abkling = Werte.SCHLEUDER["abklingzeit"] * 0.5
			_umzug_in = Werte.SCHLEUDER_UMZUG_SEK
			_figur(Werte.SCHLEUDER)
	leben = max_leben


func _figur(daten: Dictionary) -> void:
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)


func _process(delta: float) -> void:
	_zeit += delta
	_treffer -= delta
	modulate = Color(1, 0.6, 0.6) if _treffer > 0.0 else Color.WHITE
	queue_redraw()
	if not spiel.im_kampf():
		return
	if art == "schleuder" and spiel.welle >= Werte.SPRENGER_AB_WELLE:
		# Platzwechsel während der Runde: hinfahren, dabei wird nicht geworfen
		if _faehrt:
			_sprite.bewegt(true)
			_sprite.flip_h = false
			position = position.move_toward(_fahrziel, Werte.SCHLEUDER_TEMPO * Werte.ZELLE * delta)
			if position == _fahrziel:
				_faehrt = false
				_sprite.bewegt(false)
			return
		_umzug_in -= delta
		if _umzug_in <= 0.0:
			spiel.schleuder_umzug(self, false)
			return
	_abkling -= delta
	if _abkling > 0.0:
		return
	match art:
		"schleuder":
			var ziel: Variant = spiel.schleuderziel(position, Werte.SCHLEUDER["reichweite"] * Werte.ZELLE)
			if ziel == null:
				_abkling = 0.5
				return
			_abkling = Werte.SCHLEUDER["abklingzeit"]
			_sprite.angriff(Werte.SCHLEUDER["angriff_dauer"])
			spiel.wurf(self, ziel)
		"laser":
			var opfer: Einheit = spiel.laserziel(position, Werte.LASER["reichweite"] * Werte.ZELLE)
			if opfer == null:
				_abkling = 0.2
				return
			_abkling = Werte.LASER["abklingzeit"]
			_sprite.angriff(Werte.LASER["abklingzeit"])
			spiel.schuss(position + Vector2(20, -24), opfer.position, Color("ff3ad0"))
			opfer.nimm_schaden(Werte.LASER["schaden"])


## Auf ein anderes Feld der Zone wechseln: sofort (zwischen den Runden) oder hinfahren (in der Runde).
func versetze(neue_zelle: Vector2i, sofort: bool) -> void:
	zelle = neue_zelle
	_umzug_in = Werte.SCHLEUDER_UMZUG_SEK
	_fahrziel = karte.mitte(zelle)
	_faehrt = not sofort
	if sofort:
		position = _fahrziel


## Wurf-Schleuder: bereit für das nächste Rudel?
func wurfbereit() -> bool:
	return art == "wurf" and _abkling <= 0.0


func hat_geworfen() -> void:
	_abkling = Werte.WURF["abklingzeit"]
	_sprite.angriff(Werte.SCHLEUDER["angriff_dauer"])


func nimm_schaden(menge: float) -> void:
	if not spiel.im_endkampf() or leben <= 0.0:
		return
	leben -= menge
	_treffer = 0.08
	if leben <= 0.0:
		spiel.zonenbau_zerstoert(self)


func _draw() -> void:
	var pink := Color("ff5ad0")
	if art == "hq":
		# Messingkuppel der Myriaden
		draw_rect(Rect2(-30, -22, 60, 52), Color("3a2a1c"))
		draw_rect(Rect2(-26, -18, 52, 44), Color("8a6a35"))
		draw_rect(Rect2(-20, -26, 40, 16), Color("c9963f"))
		draw_rect(Rect2(-12, -32, 24, 8), Color("e6c06a"))
		draw_rect(Rect2(-8, -4, 16, 16), pink)
		draw_rect(Rect2(-26, 18, 52, 8), Color("3a2a1c"))
		if spiel.im_endkampf():
			var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
			draw_rect(Rect2(-32, -34, 64, 66), Color(pink, 0.3 + 0.6 * puls), false, 4.0)
	elif not spiel.im_kampf():
		# Bauphase: Reichweite zeigen (Schleuder pink, Wurf-Schleuder orange, Laser hellrot)
		match art:
			"schleuder":
				draw_arc(Vector2.ZERO, Werte.SCHLEUDER["reichweite"] * Werte.ZELLE, 0.0, TAU, 96, Color(pink, 0.45), 2.0)
			"wurf":
				draw_arc(Vector2.ZERO, Werte.WURF["reichweite"] * Werte.ZELLE, 0.0, TAU, 96, Color(1.0, 0.6, 0.1, 0.45), 2.0)
				draw_arc(Vector2.ZERO, Werte.WURF["weit"] * Werte.ZELLE, 0.0, TAU, 128, Color(1.0, 0.6, 0.1, 0.18), 1.0)   # Taschenwürfe
			"laser":
				draw_arc(Vector2.ZERO, Werte.LASER["reichweite"] * Werte.ZELLE, 0.0, TAU, 96, Color(1.0, 0.25, 0.3, 0.45), 2.0)
	if leben < max_leben:
		draw_rect(Rect2(-24, -46, 48, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-22, -44, 44.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("ff5a4d"))
