class_name Gegner
extends Node2D
## Angreifer einer Welle. Nimmt den billigsten Weg zur Basis und reißt ein, was den Weg versperrt.
## Nahkämpfer beißen Bodentruppen in Reichweite. Fernkämpfer beschießen im Laufen
## Truppen in Stellungen und sichtbare Bodentruppen.
##
## Sonderregeln je nach daten["rolle"]:
##   "fahne"      – führt den Trupp in seinem Tempo, kämpft nicht, nimmt Checkpoints schneller ein
##   "sprenger"   – läuft zum Erdwall mit der größten Abkürzung und sprengt ihn
##   "rauch"      – wirft Rauch auf Stellungen
##   "belagerung" – fährt zum Wallstück mit den meisten Stellungen, dockt an, setzt Turmtruppen ab
##   "enterer"    – Turmtruppe: läuft auf den Wällen und greift Stellungen im Nahkampf an

var spiel: Node
var karte: Karte
var typ := ""
var rolle := ""
var daten: Dictionary
var leben := 1.0
var max_leben := 1.0
var leben_faktor := 1.0

var trupp: Array = []               # alle Mitglieder des eigenen Trupps (gemeinsame Liste)

var _ziel := 0                      # nächstes Ziel auf der Route: Checkpoint Nummer _ziel, danach die Basis
var _weg: Array[Vector2i] = []
var _index := 0
var _abkling := 0.0
var _versatz := Vector2.ZERO
var _sprite: Figur
var _treffer := 0.0
var _tot := false

# Sonderregeln
var _sonderziel := Karte.KEINE      # Sprenger / Belagerungsturm: der angepeilte Erdwall
var _sonderweg: Array[Vector2i] = []
var _sonder_index := 0
var _sonder_plan_in := 0.0
var _angedockt := -1.0              # Belagerungsturm: Sekunden seit dem Andocken (-1 = noch unterwegs)
var _abgesetzt := 0
var _auf_wall := false              # Turmtruppe: läuft noch oben auf den Wällen
var _wall_zelle := Karte.KEINE


func start(p_spiel: Node, p_karte: Karte, p_typ: String, p_leben_faktor: float, start_zelle: Vector2i, erstes_ziel: int) -> void:
	spiel = p_spiel
	karte = p_karte
	typ = p_typ
	daten = Werte.GEGNER[typ]
	rolle = daten["rolle"]
	leben_faktor = p_leben_faktor
	max_leben = daten["leben"] * leben_faktor
	leben = max_leben
	_versatz = Vector2(randf_range(-6, 6), randf_range(-6, 6))
	_ziel = erstes_ziel
	position = karte.mitte(start_zelle) + _versatz
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)
	if rolle == "enterer":
		# Turmtruppen beginnen oben auf dem Wall
		_auf_wall = true
		_wall_zelle = start_zelle
		position = karte.mitte(start_zelle) + Vector2(0, -12)
	plane_neu()


## Ein Trupp bleibt zusammen: alle laufen so schnell wie das langsamste lebende Mitglied.
## Führt ein Fahnenträger den Trupp an, stürmen alle in seinem Tempo.
func tempo() -> float:
	var t: float = daten["tempo"]
	for g: Gegner in trupp:
		if g.rolle == "fahne":
			return g.daten["tempo"]
		t = minf(t, g.daten["tempo"])
	return t


## Wie weit ist dieser Gegner noch von der Basis entfernt? Kleiner = weiter vorn auf der Hauptlinie.
## (Erst zählt, wie viele Checkpoints noch vor ihm liegen, dann die Felder bis zum nächsten Ziel.)
func rest_weg() -> int:
	if _auf_wall:
		return 1 << 20
	return maxi(karte.checkpoints.size() - _ziel, 0) * 1000 + (_weg.size() - _index)


## Weg ab dem aktuellen Feld neu berechnen (z. B. nachdem ein Wall gefallen ist).
func plane_neu() -> void:
	_weg = karte.gegner_weg(typ, karte.zelle_bei(position), karte.ziel_zelle(_ziel))
	_index = 1
	_sonder_plan_in = 0.0   # Sprenger und Belagerungsturm wählen ihr Ziel neu


func _process(delta: float) -> void:
	if _tot or not spiel.im_kampf():
		return
	_abkling -= delta
	_treffer -= delta
	_sprite.modulate = Color(1, 0.55, 0.55) if _treffer > 0.0 else Color.WHITE
	var reichweite: float = daten["reichweite"] * Werte.ZELLE

	# 0) Sonderregeln. Geben sie true zurück, ist dieser Schritt damit erledigt.
	match rolle:
		"sprenger", "belagerung":
			if _zum_wall(delta):
				return
		"enterer":
			if _auf_wall:
				_auf_dem_wall(delta, reichweite)
				return
		"rauch":
			_wirf_rauch(reichweite)

	# 1) Ziel in Reichweite? Nahkämpfer bleiben stehen und kämpfen.
	if daten["fernkampf"]:
		# Fernkämpfer schießen im Laufen und halten dafür nicht an.
		var ziel: Einheit = spiel.fernziel(position, reichweite)
		if ziel != null and _abkling <= 0.0:
			_abkling = daten["abklingzeit"]
			_sprite.angriff(daten["abklingzeit"])
			spiel.schuss(position + Vector2(0, -6), ziel.position, Color("ff7ad9"))
			ziel.nimm_schaden(daten["schaden"])
	elif daten["schaden"] > 0.0:
		var opfer: Einheit = spiel.naechste_bodeneinheit(position, reichweite)
		if opfer != null:
			_sprite.bewegt(false)
			_sprite.flip_h = opfer.position.x < position.x
			if _abkling <= 0.0:
				_abkling = daten["abklingzeit"]
				_sprite.angriff(daten["abklingzeit"])
				spiel.schuss(position, opfer.position, Color("ff7ad9"))
				opfer.nimm_schaden(daten["schaden"])
			return

	# 2) Am Ziel?
	if _index >= _weg.size():
		if _ziel < karte.checkpoints.size():
			# Auf dem Checkpoint: stehen bleiben und halten, bis er eingenommen ist – dann weiter zum nächsten Ziel.
			if karte.cp_feind[_ziel]:
				_ziel += 1
				plane_neu()
			else:
				_sprite.bewegt(false)
				var faktor := Werte.FAHNE_EINNAHME_FAKTOR if rolle == "fahne" else 1.0
				karte.cp_tempo[_ziel] = maxf(karte.cp_tempo[_ziel], faktor)
			return
		_tot = true
		spiel.gegner_am_ziel(self)
		return

	# 3) Versperrt ein Wall oder eine Fabrik das nächste Feld? Einreißen.
	var naechstes := _weg[_index]
	if not karte.ist_frei(naechstes):
		var eigenes := karte.mitte(_weg[_index - 1]) + _versatz
		_sprite.flip_h = naechstes.x < _weg[_index - 1].x
		if position.distance_to(eigenes) > 2.0:
			_sprite.bewegt(true)
			position = position.move_toward(eigenes, tempo() * Werte.ZELLE * delta)
		else:
			_sprite.bewegt(false)
			if _abkling <= 0.0:
				_abkling = daten["abklingzeit"]
				_sprite.angriff(daten["abklingzeit"])
				spiel.schuss(position, karte.mitte(naechstes), Color("ff7ad9"))
				karte.schade(naechstes, maxf(daten["schaden"], 6.0))
		return

	# 4) Sonst weiterlaufen.
	_laufe_zu(karte.mitte(naechstes) + _versatz, delta)
	if position == karte.mitte(naechstes) + _versatz:
		_index += 1


## Geht einen Schritt auf `punkt` zu und richtet die Figur aus.
func _laufe_zu(punkt: Vector2, delta: float) -> void:
	_sprite.bewegt(true)
	if absf(punkt.x - position.x) > 1.0:
		_sprite.flip_h = punkt.x < position.x
	position = position.move_toward(punkt, tempo() * Werte.ZELLE * delta)


# ------------------------------------------------- Sprenger und Belagerungsturm

## Beide laufen über freie Felder neben ihren Zielwall. true = diese Regel hat den Schritt übernommen.
func _zum_wall(delta: float) -> bool:
	if _angedockt >= 0.0:
		_setze_truppen_ab(delta)
		return true
	# Ziel wählen (neu, sobald sich die Karte ändert oder das Ziel verschwunden ist)
	_sonder_plan_in -= delta
	if _sonder_plan_in <= 0.0 or (_sonderziel != Karte.KEINE and karte.inhalt(_sonderziel) != Karte.WALL):
		_sonder_plan_in = 2.0
		var hier := karte.zelle_bei(position)
		var fund: Dictionary = karte.sprengziel(hier) if rolle == "sprenger" else karte.andockziel(hier)
		if fund.is_empty():
			_sonderziel = Karte.KEINE
		else:
			_sonderziel = fund["wall"]
			_sonderweg = fund["weg"]
			_sonder_index = 1 if _sonderweg.size() > 0 and _sonderweg[0] == hier else 0
	if _sonderziel == Karte.KEINE:
		return false   # nichts Lohnendes: wie ein normaler Gegner zur Basis
	if _sonder_index < _sonderweg.size():
		var punkt := karte.mitte(_sonderweg[_sonder_index]) + _versatz
		_laufe_zu(punkt, delta)
		if position == punkt:
			_sonder_index += 1
		return true
	# angekommen
	_sprite.bewegt(false)
	_sprite.flip_h = karte.mitte(_sonderziel).x < position.x
	if rolle == "sprenger":
		_tot = true
		spiel.sprengung(self, _sonderziel)
	else:
		_angedockt = 0.0
	return true


## Angedockter Belagerungsturm: nach einer Wartezeit springt alle paar Sekunden eine Turmtruppe auf den Wall.
func _setze_truppen_ab(delta: float) -> void:
	if karte.inhalt(_sonderziel) != Karte.WALL:
		# Der Wall ist weg: neues Ziel suchen
		_angedockt = -1.0
		_sonderziel = Karte.KEINE
		_sonder_plan_in = 0.0
		return
	_angedockt += delta
	var faellig := int((_angedockt - Werte.ANDOCK_SEK) / Werte.ENTERER_ABSTAND) + 1
	if _angedockt < Werte.ANDOCK_SEK or _abgesetzt >= faellig:
		return
	_abgesetzt += 1
	_sprite.angriff(1.0)
	spiel.setze_enterer_ab(_sonderziel, leben_faktor, _ziel)
	if _abgesetzt >= Werte.ENTERER_JE_TURM:
		# leer: der Turm zerfällt
		_tot = true
		spiel.gegner_entfernt(self)


# ------------------------------------------------------------- Turmtruppe

func _auf_dem_wall(delta: float, reichweite: float) -> void:
	if karte.inhalt(_wall_zelle) != Karte.WALL:
		_springe_ab(_wall_zelle)   # der Wall unter ihr wurde eingerissen
		return
	var weg: Array[Vector2i] = [_wall_zelle]   # steht die Stellung genau hier, ist das schon das Ziel
	if not karte.posten.has(_wall_zelle):
		weg = karte.wall_weg_zur_stellung(_wall_zelle)
	if weg.is_empty():
		_springe_ab(karte.absprung(_wall_zelle))
		return
	var opfer: Einheit = karte.posten.get(weg[weg.size() - 1])
	if opfer != null and position.distance_to(opfer.position) <= reichweite:
		_sprite.bewegt(false)
		_sprite.flip_h = opfer.position.x < position.x
		if _abkling <= 0.0:
			_abkling = daten["abklingzeit"]
			_sprite.angriff(daten["abklingzeit"])
			spiel.schuss(position, opfer.position, Color("ff7ad9"))
			opfer.nimm_schaden(daten["schaden"])
		return
	if weg.size() < 2:
		return
	# zum nächsten Wallfeld auf dem Weg zur Stellung
	var punkt := karte.mitte(weg[1]) + Vector2(0, -12)
	_laufe_zu(punkt, delta)
	if position == punkt:
		_wall_zelle = weg[1]


func _springe_ab(feld: Vector2i) -> void:
	_auf_wall = false
	if feld != Karte.KEINE:
		position = karte.mitte(feld) + _versatz
	plane_neu()


# ------------------------------------------------------------ Rauchwerfer

func _wirf_rauch(reichweite: float) -> void:
	if _abkling > 0.0:
		return
	var punkt: Variant = spiel.rauchziel(position, reichweite)
	if punkt == null:
		return
	_abkling = daten["abklingzeit"]
	_sprite.angriff(daten["angriff_dauer"])
	spiel.lege_rauch(position, punkt)


func nimm_schaden(menge: float) -> void:
	if _tot:
		return
	leben -= menge
	_treffer = 0.08
	queue_redraw()
	if leben <= 0.0:
		_tot = true
		spiel.gegner_besiegt(self)


func _draw() -> void:
	if rolle == "fahne":
		draw_rect(Rect2(-2, -84, 4, 40), Color("3a2a1c"))
		draw_rect(Rect2(2, -84, 22, 14), Color("ff5ad0"))
	if leben < max_leben:
		var y := -92.0 if rolle == "fahne" else (-66.0 if rolle == "belagerung" else -46.0)
		draw_rect(Rect2(-16, y, 32, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, y + 2, 28.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("ff5a4d"))
