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
var bedroht: Array = []           # Stein-Schleuder, Bauphase: Felder mit Stellung/Fabrik/Batterie in Reichweite (16.11.)
var bedroht_vorschau := false     # ... und das Bauwerk unter der Maus läge in Reichweite
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
			max_leben = Werte.hq_leben()
			if Werte.grafik_neu:
				# Neue Grafik: Myr-Bau als Bild (Pixel ×2 wie die Truppen)
				var bild := Sprite2D.new()
				# 16.11.: kupferne Maschinen-Kuppel (128 px) im Stil der Schwarmbauten; in HD-2D größer
				bild.texture = load(Werte.NEU + "gebaeude/myr_hq_gross.png")
				bild.centered = false
				bild.offset = -Vector2(58, 108)
				bild.scale = Vector2(1.7, 1.7) if Werte.grafik_hd else Vector2(1.0, 1.0)
				bild.position = Vector2(0, 26)
				add_child(bild)
		"laser":
			max_leben = Werte.LASER["leben"]
			_figur(Werte.LASER)
		_:
			max_leben = Werte.SCHLEUDER["leben"]
			_abkling = Werte.SCHLEUDER["abklingzeit"] * 0.5
			_umzug_in = Werte.SCHLEUDER_UMZUG_SEK
			_figur(Werte.SCHLEUDER)
			if art == "wurf":
				_sprite.modulate = Werte.WURF_FARBE
	leben = max_leben


func _figur(daten: Dictionary) -> void:
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)


func _physics_process(_takt: float) -> void:
	var delta := Werte.sim_schritt()   # 9a: feste Schrittweite, unabhaengig von Tempo und Bildrate
	_zeit += delta
	_treffer -= delta
	modulate = (Color(1, 0.88, 0.86) if Werte.grafik_neu else Color(1, 0.6, 0.6)) if _treffer > 0.0 else Color.WHITE
	queue_redraw()
	if not spiel.im_kampf():
		if art == "schleuder":
			_pruefe_bedroht()
		return
	if art == "schleuder" and Werte.plan_runde(spiel.welle) >= Werte.SPRENGER_AB_WELLE:
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
			_abkling = Werte.SCHLEUDER["abklingzeit"] * (0.5 if spiel.brakk_modus else 1.0)   # 18.11. (Paul): Brakk-Mode – doppelt so viele Würfe
			_sprite.angriff(Werte.SCHLEUDER_ABWURF * 2.0)   # Arm holt aus und schlägt vor; der Stein löst sich zur Hälfte
			get_tree().create_timer(Werte.SCHLEUDER_ABWURF, true, true).timeout.connect(ruck)
			spiel.wurf(self, ziel)
		"laser":
			var opfer: Einheit = spiel.laserziel(position, Werte.LASER["reichweite"] * Werte.ZELLE)
			if opfer == null:
				_abkling = 0.2
				return
			_abkling = Werte.LASER["abklingzeit"]
			_sprite.angriff(Werte.LASER["abklingzeit"])
			spiel.schuss(position + Vector2(20, -24), opfer.position, Color("ff3ad0"))
			opfer.nimm_fernschaden(Werte.LASER["schaden"])   # 18.11.: Fernschuss (Ruine deckt)


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


## Kurzer Ruck beim Abwurf: die Schleuder staucht sich und federt zurück (16.11.).
func ruck() -> void:
	if not is_instance_valid(_sprite):
		return
	var grund: Vector2 = _sprite.get_meta("grund_massstab", _sprite.scale)
	_sprite.set_meta("grund_massstab", grund)
	var tw := create_tween()
	_sprite.scale = grund * Vector2(1.12, 0.86)
	tw.tween_property(_sprite, "scale", grund * Vector2(0.95, 1.06), 0.08)
	tw.tween_property(_sprite, "scale", grund, 0.12)


func nimm_schaden(menge: float) -> void:
	if not spiel.im_endkampf() or leben <= 0.0:
		return
	spiel.zaehle_schaden(minf(menge, leben), leben - menge <= 0.0)   # Schadensliste [Tab]: Treffer am HQ und an Zonenbauten
	leben -= menge
	_treffer = 0.08
	if leben <= 0.0:
		spiel.zonenbau_zerstoert(self)


func _draw() -> void:
	var pink := Karte.feind_farbe()   # neue Grafik: kupfern
	if art == "hq" and Werte.grafik_neu:
		if spiel.im_endkampf():
			var puls_n := 0.5 + 0.5 * sin(_zeit * 4.0)
			draw_rect(Rect2(-32, -34, 64, 66), Color(pink, 0.3 + 0.6 * puls_n), false, 4.0)
	elif art == "hq":
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
				_male_reichweite(pink)
			"wurf":
				draw_arc(Vector2.ZERO, Werte.WURF["reichweite"] * Werte.ZELLE, 0.0, TAU, 96, Color(1.0, 0.6, 0.1, 0.45), 2.0)
				draw_arc(Vector2.ZERO, Werte.WURF["weit" if spiel.phantom_modus != "" else "tasche_weit"] * Werte.ZELLE, 0.0, TAU, 128, Color(1.0, 0.6, 0.1, 0.18), 1.0)   # Taschenwürfe
			"laser":
				draw_arc(Vector2.ZERO, Werte.LASER["reichweite"] * Werte.ZELLE, 0.0, TAU, 96, Color(1.0, 0.25, 0.3, 0.45), 2.0)
	if leben < max_leben:
		draw_rect(Rect2(-24, -46, 48, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-22, -44, 44.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("ff5a4d"))


## Stein-Schleuder in der Bauphase (16.11., Paul: deutlicher): Was läge in Reichweite? Gebaute Stellungen, Fabriken und
## Batterien – und das Bauwerk, das gerade unter der Maus platziert wird. Die Oberfläche setzt dann ein „!“ über die Schleuder.
func _pruefe_bedroht() -> void:
	var weite: float = Werte.SCHLEUDER["reichweite"] * Werte.ZELLE
	bedroht = []
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		var ziel: bool = typ == Karte.FABRIK or typ == Karte.BATTERIE or (typ == Karte.WALL and karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG)
		if ziel and position.distance_to(karte.mitte(z)) <= weite and not karte.in_kuppel(karte.mitte(z)):
			bedroht.append(z)
	bedroht_vorschau = false
	var w: int = spiel.werkzeug
	if w == Karte.STELLUNG or w == Karte.FABRIK or w == Karte.BATTERIE:
		var m: Vector2i = karte.zelle_bei(spiel.maus_welt())
		var p := karte.mitte(m)
		bedroht_vorschau = position.distance_to(p) <= weite and not karte.in_kuppel(p) and karte.in_karte(m)


## Reichweite der Stein-Schleuder: getönte Fläche, kräftiger pulsierender Rand, wandernde Striche; was darin steht, ist
## kupfern umrandet. Liegt das Bauwerk unter der Maus in Reichweite, leuchtet alles auf.
func _male_reichweite(farbe: Color) -> void:
	var r: float = Werte.SCHLEUDER["reichweite"] * Werte.ZELLE
	var warn := bedroht_vorschau
	var puls := 0.5 + 0.5 * sin(_zeit * (7.0 if warn else 3.0))
	var f := Color(1.0, 0.45, 0.25) if warn else farbe
	draw_circle(Vector2.ZERO, r, Color(f, (0.20 if warn else 0.11) + 0.05 * puls))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, Color(0, 0, 0, 0.45), 16.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, Color(f, 0.75 + 0.25 * puls), 9.0)
	draw_arc(Vector2.ZERO, r - 7.0, 0.0, TAU, 128, Color(1, 1, 1, 0.25 + 0.2 * puls), 2.0)
	for i in 24:
		var w := TAU * i / 24.0 + _zeit * 0.25
		draw_arc(Vector2.ZERO, r + 16.0, w, w + 0.12, 4, Color(f, 0.8), 7.0)
	for z: Vector2i in bedroht:
		var m := karte.mitte(z) - position
		var rr := Rect2(m - Vector2(Werte.ZELLE, Werte.ZELLE) * 0.46, Vector2(Werte.ZELLE, Werte.ZELLE) * 0.92)
		draw_rect(rr, Color(f, 0.25 + 0.15 * puls))
		draw_rect(rr, Color(f, 1.0), false, 6.0)
