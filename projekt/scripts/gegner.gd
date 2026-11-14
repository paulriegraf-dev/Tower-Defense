class_name Gegner
extends Node2D
## Angreifer einer Welle. Nimmt den billigsten Weg zur Basis und reißt ein, was den Weg versperrt.
## Nahkämpfer beißen Bodentruppen in Reichweite. Fernkämpfer beschießen im Laufen
## Truppen in Stellungen und sichtbare Bodentruppen.
##
## Sonderregeln je nach daten["rolle"]:
##   "fahne"      – geht dem Trupp voran und macht ihn 30 % schneller, kämpft nicht, nimmt Checkpoints schneller ein
##   "sprenger"   – läuft zum Erdwall mit der größten Abkürzung und sprengt ihn
##   "rauch"      – wirft Rauch auf Stellungen
##   "belagerung" – fährt zum Wallstück mit den meisten Stellungen, dockt an, setzt Turmtruppen ab
##   "enterer"    – Turmtruppe: läuft auf den Wällen und greift Stellungen im Nahkampf an

var _ziel_ist_fabrik := false       # Sprenger ohne lohnenden Erdwall: sein Ziel ist eine Fabrik
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
var _zuendung := -1.0               # Sprenger: Sekunden, die er schon an seinem Ziel zündet (-1 = noch nicht angekommen)
var _sonderziel := Karte.KEINE      # Sprenger / Belagerungsturm: der angepeilte Erdwall
var _sonderweg: Array[Vector2i] = []
var _sonder_index := 0
var _sonder_plan_in := 0.0
var _angedockt := -1.0              # Belagerungsturm: Sekunden seit dem Andocken (-1 = noch unterwegs)
var _abgesetzt := 0
var _auf_wall := false              # Turmtruppe: läuft noch oben auf den Wällen
var _wall_zelle := Karte.KEINE
var _leerlauf := 0.0                # Turmtruppe: Sekunden ohne Ziel auf dem Wall
var _brut: Array = []               # Belagerungsturm: seine abgesetzten Turmtruppen
var geworfen := false               # von der Wurf-Schleuder hinter die vordere Front geworfen
var markiert := 0.0                 # Sekunden: von einem Scharfschützen markiert, nimmt mehr Schaden
var gebremst := 0.0                 # Sekunden: von Plasmagel verlangsamt
var gefroren := 0.0                 # Sekunden: vom Frostturm verlangsamt (schwächer als Plasmagel)
var eingefroren := 0.0              # Sekunden: Schockfrost – steht ganz still
var sproede := 0.0                  # Sekunden: Sprödes Eis – nimmt mehr Schaden


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
	var t := _tempo_ungebremst()
	if eingefroren > 0.0:
		return 0.0
	if gebremst > 0.0:
		return t * Werte.PLASMAGEL_TEMPO
	if gefroren > 0.0:
		return t * float(Werte.TURMARTEN["frost"]["bremse_tempo"])
	return t


func _tempo_ungebremst() -> float:
	# Tempo des Trupps = langsamstes Mitglied, den Fahnenträger nicht mitgezählt (er wartet auf seinen Trupp).
	var t: float = INF if rolle == "fahne" else float(daten["tempo"])
	var fahne_dabei := false
	for g: Gegner in trupp:
		if g.rolle == "fahne":
			fahne_dabei = true
		else:
			t = minf(t, g.daten["tempo"])
	if t == INF:
		return daten["tempo"]   # Fahnenträger ohne Trupp: eigenes Tempo
	if rolle == "fahne":
		return minf(float(daten["tempo"]), t)   # der Bonus gilt nur für die anderen: er selbst läuft ohne
	# Ein Fahnenträger im Trupp oder seine Spur am Boden treibt an (den Belagerungsturm nicht).
	if fahne_dabei or (rolle != "belagerung" and spiel.auf_fahnenspur(position)):
		return t * Werte.FAHNE_BONUS
	return t


var _stand := 0.0
var _stand_pos := Vector2.INF

func steht() -> bool:
	return _stand >= 0.7


## Die nächsten Felder, über die dieser Gegner laufen wird (ab seinem jetzigen Feld), auch über das nächste Ziel hinaus.
func kommender_weg(hoechstens: int) -> Array[Vector2i]:
	var felder: Array[Vector2i] = []
	if _auf_wall:
		return felder
	for i in range(maxi(_index - 1, 0), _weg.size()):
		felder.append(_weg[i])
		if felder.size() >= hoechstens:
			return felder
	var von: Vector2i = felder[-1] if not felder.is_empty() else karte.zelle_bei(position)
	for k in range(_ziel + 1, karte.checkpoints.size() + 1):
		var stueck: Array[Vector2i] = karte.gegner_weg("hund", von, karte.ziel_zelle(k))
		for i in range(1, stueck.size()):
			felder.append(stueck[i])
			if felder.size() >= hoechstens:
				return felder
		von = karte.ziel_zelle(k)
	return felder


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
	# Steht er (nimmt einen Checkpoint ein, kämpft)? Dann warten Abfänger nicht am Treffpunkt, sondern kommen zu ihm.
	if position.distance_to(_stand_pos) < 2.0:
		_stand += delta
	else:
		_stand = 0.0
		_stand_pos = position
	if rolle == "sprenger":
		queue_redraw()   # Warnzeichen blinkt
	if markiert > 0.0 or gebremst > 0.0 or gefroren > 0.0 or eingefroren > 0.0 or sproede > 0.0:
		markiert -= delta
		gebremst -= delta
		gefroren -= delta
		eingefroren -= delta
		sproede -= delta
		queue_redraw()
	_sprite.modulate = Color(1, 0.55, 0.55) if _treffer > 0.0 else (Color(0.6, 1.0, 0.75) if gebremst > 0.0 else (Color(0.75, 0.92, 1.0) if gefroren > 0.0 or eingefroren > 0.0 else Color.WHITE))
	var reichweite: float = daten["reichweite"] * Werte.ZELLE

	# Energieschild einer Batterie im Weg: stehen bleiben und draufschlagen, bis er bricht.
	if not _auf_wall:
		var schild: Vector2i = spiel.schild_bei(position)
		if schild != Karte.KEINE:
			_sprite.bewegt(false)
			if _abkling <= 0.0:
				_abkling = daten["abklingzeit"] if daten["schaden"] > 0.0 else Werte.SCHILD_SCHLAG_SEK
				if daten["schaden"] > 0.0:
					_sprite.angriff(_abkling)
				spiel.schade_schild(schild, maxf(float(daten["schaden"]), Werte.SCHILD_MIN_SCHADEN))
			return

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
		# Ziele der Reihe nach: Truppen in Stellungen, dann Fabriken und Batterien, dann Bodentruppen
		var ziel: Einheit = spiel.fernziel(position, reichweite, 1)
		var bau := Karte.KEINE
		if ziel == null:
			bau = karte.gebaeude_in_reichweite(position, reichweite)
			if bau == Karte.KEINE:
				ziel = spiel.fernziel(position, reichweite, 2)
		if _abkling <= 0.0 and (ziel != null or bau != Karte.KEINE):
			_abkling = daten["abklingzeit"]
			_sprite.angriff(daten["abklingzeit"])
			if ziel != null:
				spiel.schuss(position + Vector2(0, -6), ziel.position, Color("ff7ad9"))
				ziel.nimm_schaden(daten["schaden"])
			else:
				spiel.schuss(position + Vector2(0, -6), karte.mitte(bau), Color("ff7ad9"))
				karte.beschiesse(bau, daten["schaden"])
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
			# Vor der Runde, ab der Checkpoints zählen, läuft er nur hindurch (Sandbox: Checkpoint-Route ab Runde 1).
			if karte.cp_feind[_ziel] or not karte.cp_aktiv:
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
	var ziel_weg := _sonderziel != Karte.KEINE and karte.inhalt(_sonderziel) != (Karte.FABRIK if _ziel_ist_fabrik else Karte.WALL)
	if _ziel_ist_fabrik and karte.ausgefallen.has(_sonderziel):
		ziel_weg = true
	# Ein Sprenger bleibt bei seinem Ziel, solange der Wall steht; der Belagerungsturm plant laufend neu.
	if ziel_weg or (_sonder_plan_in <= 0.0 and (rolle != "sprenger" or _sonderziel == Karte.KEINE)):
		_sonder_plan_in = 2.0
		_zuendung = -1.0   # neues Ziel: die Zündung beginnt von vorn
		var hier := karte.zelle_bei(position)
		# Ein geworfener Sprenger steht schon hinter der Front: für ihn gilt kein Mindestanmarsch.
		var fund: Dictionary = karte.sprengziel(hier, spiel.sprenger_stuecke(self), 0 if geworfen else Werte.SPRENGER_MIN_WEG) if rolle == "sprenger" else karte.andockziel(hier)
		_ziel_ist_fabrik = false
		if fund.is_empty() and rolle == "sprenger":
			fund = karte.fabrikziel(hier)   # kein lohnender Erdwall: dann eine Fabrik
			_ziel_ist_fabrik = not fund.is_empty()
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
		# Zündzeit: Er steht still am Ziel und ist leicht zu treffen. Fällt er vorher, gibt es keine Sprengung.
		_zuendung = maxf(_zuendung, 0.0) + delta
		if _zuendung < Werte.SPRENGER_ZUENDZEIT:
			queue_redraw()
			return true
		_tot = true
		if _ziel_ist_fabrik:
			spiel.sprengung_fabrik(self, _sonderziel)
		else:
			spiel.sprengung(self, _sonderziel)
	else:
		_angedockt = 0.0
		spiel.belagerung_dockt(self)
		if OS.get_environment("TD_WURF_LOG") != "":
			print("DOCK R%d an %s %s" % [spiel.welle, karte.zelle_bei(position), _dock_wall_text()])
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
	if _angedockt >= Werte.BELAGERUNG_SEK:
		# ausgebrannt: der Turm zerfällt
		_tot = true
		spiel.gegner_entfernt(self)
		return
	# Solange der Turm steht, kommen Turmtruppen nach – aber nie mehr als ENTERER_GLEICHZEITIG auf einmal.
	_brut = _brut.filter(func(g): return is_instance_valid(g) and not g._tot)
	var faellig := int((_angedockt - Werte.ANDOCK_SEK) / Werte.ENTERER_ABSTAND) + 1
	if _angedockt < Werte.ANDOCK_SEK or _abgesetzt >= faellig or _brut.size() >= Werte.ENTERER_GLEICHZEITIG:
		return
	_abgesetzt = faellig
	_sprite.angriff(1.0)
	_brut.append(spiel.setze_enterer_ab(_sonderziel, leben_faktor, _ziel))
	spiel.turmtruppe_abgesetzt(self)


# ------------------------------------------------------------- Turmtruppe

func _auf_dem_wall(delta: float, reichweite: float) -> void:
	if karte.inhalt(_wall_zelle) != Karte.WALL:
		_springe_ab(_wall_zelle)   # der Wall unter ihr wurde eingerissen
		return
	# Ziel: die nächste Stellung, in der jemand steht, oder der nächste laufende Turm auf diesem Wallstück
	var weg: Array[Vector2i] = [_wall_zelle]   # liegt das Ziel genau hier, ist der Weg schon zu Ende
	if not karte.enterziel(_wall_zelle):
		weg = karte.wall_weg_zur_stellung(_wall_zelle)
	if weg.is_empty():
		# nichts mehr zu holen: kurz warten, dann abspringen und wie die anderen zur Basis laufen
		_leerlauf += delta
		_sprite.bewegt(false)
		if _leerlauf >= Werte.ENTERER_LEERLAUF_SEK:
			var feld := karte.absprung(_wall_zelle)
			if feld == Karte.KEINE:
				_tot = true
				spiel.gegner_entfernt(self)   # eingeschlossen: gibt auf
			else:
				_springe_ab(feld)
		return
	_leerlauf = 0.0
	var ziel_zelle := weg[weg.size() - 1]
	var ziel_punkt := karte.mitte(ziel_zelle) + Vector2(0, -12)
	if position.distance_to(ziel_punkt) <= reichweite:
		_sprite.bewegt(false)
		_sprite.flip_h = ziel_punkt.x < position.x
		if _abkling <= 0.0:
			_abkling = daten["abklingzeit"]
			_sprite.angriff(daten["abklingzeit"])
			spiel.schuss(position, ziel_punkt, Color("ff7ad9"))
			var opfer: Variant = karte.posten.get(ziel_zelle)
			if is_instance_valid(opfer) and (opfer as Einheit).in_stellung():
				(opfer as Einheit).nimm_schaden(daten["schaden"])
			else:
				karte.schade_turm(ziel_zelle, daten["schaden"])
				if karte.turm_lahm(ziel_zelle):
					spiel.melde("Turmtruppen haben einen Turm lahmgelegt – er schweigt bis zum Ende der Runde.", 4.0)
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
	if markiert > 0.0:
		menge *= Werte.MARKIERUNG_FAKTOR
	if sproede > 0.0:
		menge *= float(Werte.TURM_STUFE_3["frost"]["sproede"]["sproede"])
	var wirksam := minf(menge, maxf(leben, 0.0))
	leben -= menge
	_treffer = 0.08
	queue_redraw()
	spiel.zaehle_schaden(wirksam, leben <= 0.0)   # für die Schadensliste [Tab]
	if leben <= 0.0:
		_tot = true
		spiel.gegner_besiegt(self)


## Der Erdwall, den dieser Sprenger gerade anpeilt (KEINE, wenn er keinen hat).
func sprengt() -> Vector2i:
	return _sonderziel if rolle == "sprenger" else Karte.KEINE


func _draw() -> void:
	if markiert > 0.0:
		# Zielmarkierung: Fadenkreuz
		var rot := Color(1.0, 0.25, 0.3, 0.9)
		draw_arc(Vector2(0, -8), 20.0, 0.0, TAU, 24, rot, 2.0)
		draw_line(Vector2(-26, -8), Vector2(-12, -8), rot, 2.0)
		draw_line(Vector2(12, -8), Vector2(26, -8), rot, 2.0)
		draw_line(Vector2(0, -34), Vector2(0, -20), rot, 2.0)
		draw_line(Vector2(0, 4), Vector2(0, 18), rot, 2.0)
	if rolle == "sprenger":
		# Warnzeichen über dem Kopf, blinkend
		var an := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4
		var farbe := Color("ffb347") if an else Color("ff5a1f")
		draw_colored_polygon(PackedVector2Array([Vector2(0, -78), Vector2(-13, -56), Vector2(13, -56)]), farbe)
		draw_rect(Rect2(-2, -72, 4, 9), Color("2a1608"))
		draw_rect(Rect2(-2, -61, 4, 3), Color("2a1608"))
		if _zuendung >= 0.0:
			# Zündung läuft: Ring um das Warnzeichen füllt sich, bis es knallt
			var anteil := clampf(_zuendung / Werte.SPRENGER_ZUENDZEIT, 0.0, 1.0)
			draw_arc(Vector2(0, -64), 19.0, 0.0, TAU, 32, Color(0, 0, 0, 0.55), 5.0)
			draw_arc(Vector2(0, -64), 19.0, -PI / 2.0, -PI / 2.0 + TAU * anteil, 32, Color("ff5a1f"), 4.0)
	if rolle == "fahne":
		draw_rect(Rect2(-2, -84, 4, 40), Color("3a2a1c"))
		draw_rect(Rect2(2, -84, 22, 14), Color("ff5ad0"))
	if leben < max_leben:
		var y := -92.0 if rolle == "fahne" else (-66.0 if rolle == "belagerung" else -46.0)
		draw_rect(Rect2(-16, y, 32, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, y + 2, 28.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("ff5a4d"))


## Nur für das Testprotokoll: wie viele Stellungen liegen auf dem Wallstück neben dem Andockpunkt, und wie viele nah dran?
func _dock_wall_text() -> String:
	var hier := karte.zelle_bei(position)
	var nah := 0
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.STELLUNG and Vector2(z - hier).length() <= 2.5:
			nah += 1
	return "(Stellungen in 2,5 Feldern: %d)" % nah
