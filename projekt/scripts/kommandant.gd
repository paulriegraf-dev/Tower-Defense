class_name Kommandant
extends Einheit
## Kommandant Brakk: einmal pro Partie, mit WASD gesteuert. Schießt von selbst auf den vordersten Gegner.
##   [Q] Sammeln: Bodentruppen im Umkreis folgen ihm. Nochmal [Q]: Losschlagen auf das Feld unter der Maus (Werteschub).
##   [E] Klettern: auf einen angrenzenden Erdwall und wieder herunter. Oben schießt er weiter und sieht über sein Wallstück.
##   [R] Klonmaschine: einmal pro Runde auf ein freies Feld setzen. Wer hindurchgeht, wird einmal geklont – auch Gegner.
## Auf einem verlorenen Checkpoint holt er ihn viel schneller zurück. Fällt er, steht er zur nächsten Runde wieder da.

var aufstellung := Karte.KEINE
var oben := false
var gefallen := false
var gesammelt: Array = []
var q_rest := 0.0
var e_rest := 0.0
var klon_genutzt := false
var _angriff_t := -1.0             # läuft die Angriffsanimation: Sekunden seit Beginn (-1 = keine)
var _angriff_ziel: Node2D = null
var _schuesse := 0


func einrichten_kommandant(p_spiel: Node, p_karte: Karte, zelle: Vector2i) -> void:
	spiel = p_spiel
	karte = p_karte
	daten = Werte.KOMMANDANT.duplicate()
	faehigkeit = ""
	max_leben = float(daten["leben"])
	leben = max_leben
	aufstellung = zelle
	position = karte.mitte(zelle)
	zustand = Zustand.BODEN
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)


func _process(delta: float) -> void:
	if gefallen:
		return
	_abkling -= delta
	_treffer -= delta
	q_rest -= delta
	e_rest -= delta
	gesammelt = gesammelt.filter(func(e): return is_instance_valid(e) and e.folge == self)
	if oben and karte.inhalt(posten_zelle) != Karte.WALL:
		_runter(true)   # der Wall unter ihm ist gefallen
	# Bewegung mit WASD
	var r := Vector2.ZERO
	if spiel.kommandant_steuerbar():
		if Input.is_physical_key_pressed(KEY_A):
			r.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			r.x += 1.0
		if Input.is_physical_key_pressed(KEY_W):
			r.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			r.y += 1.0
	_sprite.bewegt(r != Vector2.ZERO)
	if r != Vector2.ZERO:
		var schritt := r.normalized() * float(daten["tempo"]) * Werte.ZELLE * delta
		if absf(r.x) > 0.0:
			_sprite.flip_h = r.x < 0.0
		_versuche(Vector2(schritt.x, 0.0))
		_versuche(Vector2(0.0, schritt.y))
	# Schießen: im Kampf auf den vordersten Gegner in Reichweite
	if spiel.im_kampf():
		_angriff(delta)
	queue_redraw()


## Angriff im Takt der Animation: Sie läuft einmal durch, und in den Bildern mit dem Laserblitz fällt je ein Schuss.
func _angriff(delta: float) -> void:
	var weite := reichweite_jetzt() * Werte.ZELLE
	var dauer := float(daten["angriff_dauer"])
	if _angriff_t < 0.0:
		if _abkling > 0.0 or spiel.im_rauch(position):
			return
		_angriff_ziel = spiel.gegner_in_reichweite(position, weite, not oben, posten_zelle if oben else Karte.KEINE, "erste", false)
		if _angriff_ziel == null:
			return
		_angriff_t = 0.0
		_schuesse = 0
		_abkling = dauer
		_sprite.flip_h = _angriff_ziel.position.x < position.x
		_sprite.angriff(dauer)
		return
	_angriff_t += delta
	var bilder: Array = daten["schuss_bilder"]
	var bild := int(_angriff_t / dauer * float(daten["bilder"][2]))
	if _schuesse < bilder.size() and bild >= int(bilder[_schuesse]):
		_schuesse += 1
		if not is_instance_valid(_angriff_ziel) or _angriff_ziel._tot or position.distance_to(_angriff_ziel.position) > weite:
			_angriff_ziel = spiel.gegner_in_reichweite(position, weite, not oben, posten_zelle if oben else Karte.KEINE, "erste", false)
		if _angriff_ziel != null:
			var m: Vector2 = daten["muendung"]
			if _sprite.flip_h:
				m.x = -m.x
			spiel.schadensquelle = "fabrik:-1,-1"
			spiel.schuss_herkunft = position
			spiel.strahl(position + m, _angriff_ziel.position, Color(daten["schussfarbe"]), 3.0)
			_angriff_ziel.nimm_schaden(float(daten["schaden"]))
	if _angriff_t >= dauer:
		_angriff_t = -1.0


## Ein Stück gehen, wenn das Zielfeld passt: unten freie Felder, oben nur Erdwälle.
func _versuche(schritt: Vector2) -> void:
	if schritt == Vector2.ZERO:
		return
	var neu := position + schritt
	var fuss := neu - (Vector2(0, -12) if oben else Vector2.ZERO)
	var z := karte.zelle_bei(fuss)
	var ok := karte.inhalt(z) == Karte.WALL if oben else karte.ist_begehbar(z)
	if ok and karte.in_karte(z):
		position = neu
		if oben and z != posten_zelle:
			posten_zelle = z


func reichweite_jetzt() -> float:
	return float(daten["reichweite"]) + (float(daten["wall_bonus"]) if oben else 0.0)


func am_boden() -> bool:
	return not gefallen and not oben


func bodentruppe() -> bool:
	return am_boden()


func in_stellung() -> bool:
	return not gefallen and oben


# ------------------------------------------------------------ Fähigkeiten

## [Q]: sammeln – oder, wenn schon gesammelt, losschlagen auf `punkt`.
func taste_q(punkt: Vector2) -> String:
	if gefallen:
		return ""
	if not gesammelt.is_empty():
		var ziel := karte.zelle_bei(punkt)
		for e in gesammelt:
			e.folge = null
			e.sturm_bis = float(daten["sturm_sek"])
			e.sturm_ziel = ziel
		var n := gesammelt.size()
		gesammelt.clear()
		q_rest = float(daten["sturm_abklingzeit"])
		spiel.effekte.linie(position, punkt, Color("c9a6ff"))
		return "Losschlagen! %d Truppen stürmen %d Sekunden lang schneller und feuern rascher." % [n, int(daten["sturm_sek"])]
	if q_rest > 0.0:
		return "Sammeln wieder in %.0f s." % ceilf(q_rest)
	var radius := float(daten["sammel_radius"]) * Werte.ZELLE
	for e in spiel.einheiten:
		if e == self or e is Kommandant or not is_instance_valid(e) or e.ist_pilot or not e.am_boden():
			continue
		if position.distance_to(e.position) <= radius:
			e.folge_kommandant(self)
			gesammelt.append(e)
	q_rest = float(daten["sammel_abklingzeit"])
	spiel.effekte.flaeche(position, radius, Color("c9a6ff"))
	if gesammelt.is_empty():
		return "Keine Bodentruppen in der Nähe."
	return "Sammeln: %d Truppen folgen Brakk. [Q] nochmal = Losschlagen auf das Feld unter der Maus." % gesammelt.size()


## [E]: auf einen angrenzenden Erdwall klettern oder herunter.
func taste_e(punkt: Vector2) -> String:
	if gefallen:
		return ""
	if e_rest > 0.0:
		return "Klettern wieder in %.0f s." % ceilf(e_rest)
	if oben:
		return "" if _runter(false) else "Kein freies Feld neben dem Wall."
	var hier := karte.zelle_bei(position)
	var bester := Karte.KEINE
	var beste := INF
	for n in Karte.NACHBARN:
		var w: Vector2i = hier + n
		if karte.inhalt(w) == Karte.WALL and punkt.distance_to(karte.mitte(w)) < beste:
			beste = punkt.distance_to(karte.mitte(w))
			bester = w
	if bester == Karte.KEINE:
		return "Kein Erdwall direkt daneben."
	oben = true
	posten_zelle = bester
	zustand = Zustand.AUF_POSTEN
	position = karte.mitte(bester) + Vector2(0, -12)
	e_rest = float(daten["kletter_abklingzeit"])
	return "Brakk steht auf dem Wall: +%s Reichweite, Sicht über sein Wallstück." % str(daten["wall_bonus"])


func _runter(gestuerzt: bool) -> bool:
	var hier := posten_zelle
	for n in Karte.NACHBARN:
		var f: Vector2i = hier + n
		if karte.ist_begehbar(f):
			oben = false
			posten_zelle = Karte.KEINE
			zustand = Zustand.BODEN
			position = karte.mitte(f)
			if not gestuerzt:
				e_rest = float(daten["kletter_abklingzeit"])
			return true
	if gestuerzt:
		oben = false
		posten_zelle = Karte.KEINE
		zustand = Zustand.BODEN
		position = karte.mitte(hier)
	return false


func nimm_schaden(menge: float) -> void:
	if gefallen:
		return
	var f: float = spiel.schild_faktor(position)
	if f < 1.0:
		spiel.kuppel_abgefangen(position, menge * (1.0 - f))
	menge *= f
	leben -= menge
	_treffer = 0.08
	if leben <= 0.0:
		faellt()


func faellt() -> void:
	gefallen = true
	visible = false
	for e in gesammelt:
		if is_instance_valid(e):
			e.folge = null
	gesammelt.clear()
	spiel.melde("Brakk ist gefallen – zur nächsten Runde steht er wieder bereit.", 4.0)


## Zwischen den Runden: wieder aufstehen, voll geheilt, Klonmaschine wieder verfügbar.
func neue_runde() -> void:
	if gefallen:
		gefallen = false
		visible = true
		oben = false
		posten_zelle = Karte.KEINE
		position = karte.mitte(aufstellung)
	zustand = Zustand.AUF_POSTEN if oben else Zustand.BODEN
	leben = max_leben
	gesammelt.clear()
	klon_genutzt = false
	q_rest = 0.0
	e_rest = 0.0


func _draw() -> void:
	if gefallen:
		return
	# goldener Ring am Boden, damit man ihn im Gewühl findet
	draw_arc(Vector2(0, 14 if not oben else 26), 17.0, 0.0, TAU, 24, Color("ffd34d"), 2.0)
	if not gesammelt.is_empty():
		draw_arc(Vector2.ZERO, float(daten["sammel_radius"]) * Werte.ZELLE, 0.0, TAU, 64, Color(0.79, 0.65, 1.0, 0.35), 1.5)
	if leben < max_leben:
		draw_rect(Rect2(-18, -64, 36, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-16, -62, 32.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("ffd34d"))
