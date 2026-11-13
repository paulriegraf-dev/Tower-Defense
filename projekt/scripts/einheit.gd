class_name Einheit
extends Node2D
## Eigene Truppe aus einer Fabrik.
## Geht zur nächsten freien Stellung; findet sie keine, geht sie dem Gegner am Boden entgegen.
## Geschossen wird nur fest in der Stellung oder am Boden bei freier Sicht – nie auf dem Weg zur Stellung.

enum Zustand { ZUM_POSTEN, AUF_POSTEN, BODEN, IN_BATTERIE }

var spiel: Node
var karte: Karte
var daten: Dictionary
var leben := 1.0
var max_leben := 1.0
var zustand := Zustand.BODEN
var posten_zelle := Karte.KEINE
var fabrik_zelle := Karte.KEINE

var _punkte: Array[Vector2] = []   # Wegpunkte in Weltkoordinaten
var _abkling := 0.0
var _plan_in := 0.0
var _posten_check := 1.0           # Sekunden bis zur nächsten Suche nach einer frei gewordenen Stellung
var ausgewaehlt := false           # angeklickt: Reichweite anzeigen
var _marsch_in := 0.0
var _wartet := false               # auf dem Weg zur Stellung: kein sicherer Weg, also abwarten
var _marschziel := Karte.KEINE     # Feld, zu dem diese Bodentruppe marschiert: verlorener Checkpoint oder HQ
var _versatz := Vector2.ZERO       # damit Truppen nicht exakt aufeinander stehen
var _sprite: Figur
var _treffer := 0.0
var faehigkeit := ""               # Stufe-3-Fähigkeit aus der Fabrik
var letztes_ziel: Node2D = null    # Feuerteam: worauf zuletzt geschossen wurde ...
var letzter_schuss := -100.0       # ... und wann (Spielzeit in Sekunden)
var _laser_ziel: Node2D = null
var _laser_zeit := 0.0
var _anlauf := 0.0                 # Minigun: 0..1


var ausbaustufe := 0                # Stufe der Fabrik, aus der die Truppe kommt (für das Abzeichen)

## Farbe des Abzeichens je Stufe-3-Fähigkeit
const ABZEICHEN := {
	"durchschuss": Color("ffd166"), "laser": Color("ff4d5e"), "markierung": Color("ff9f1c"),
	"bollwerk": Color("6fa8ff"), "feuerteam": Color("f4f4f4"), "minigun": Color("ffb347"),
	"abpraller": Color("c77dff"), "brandfeld": Color("ff6a00"), "plasmagel": Color("5dfc8a"),
}


func start(p_spiel: Node, p_karte: Karte, typ: String, p_fabrik: Vector2i, stufe: int = 0, p_faehigkeit: String = "") -> void:
	ausbaustufe = 0 if typ == "pilot" else stufe
	spiel = p_spiel
	karte = p_karte
	daten = Werte.einheit_daten(typ, stufe, p_faehigkeit)
	faehigkeit = daten["faehigkeit"]
	max_leben = daten["leben"]
	leben = max_leben
	fabrik_zelle = p_fabrik
	position = karte.mitte(p_fabrik)
	_versatz = Vector2(randf_range(-10, 10), randf_range(-8, 8))
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)

	_suche_posten()


## Nächste Stellung wählen und sich auf den Weg machen – oder am Boden kämpfen, wenn keine frei ist.
func _suche_posten() -> void:
	var hier := karte.zelle_bei(position)
	var fund := karte.finde_posten(hier, self)
	_punkte.clear()
	if fund.is_empty():
		zustand = Zustand.BODEN
		posten_zelle = Karte.KEINE
		if not karte.ist_frei(hier):
			# erst aus der Fabrik heraustreten
			var raus := karte.freier_nachbar(hier)
			if raus != Karte.KEINE:
				_punkte.append(karte.mitte(raus) + _versatz)
		return
	zustand = Zustand.ZUM_POSTEN
	posten_zelle = fund["wall"]
	var zur_batterie := karte.inhalt(posten_zelle) == Karte.BATTERIE
	var bisher: Einheit = null
	if zur_batterie:
		if not karte.besatzung.has(posten_zelle):
			karte.besatzung[posten_zelle] = []
		if fund.has("statt"):
			# Platz von einer Einheit übernehmen, die noch weiter weg ist
			bisher = fund["statt"]
			(karte.besatzung[posten_zelle] as Array).erase(bisher)
		(karte.besatzung[posten_zelle] as Array).append(self)
	else:
		bisher = karte.posten.get(posten_zelle)
		karte.posten[posten_zelle] = self
	var weg: Array[Vector2i] = fund["weg"]
	for i in weg.size():
		# letzter Punkt = oben in der Stellung bzw. mitten in der Batterie, ohne Versatz
		var oben := Vector2.ZERO if zur_batterie else Vector2(0, -12)
		_punkte.append(karte.mitte(weg[i]) + (_versatz if i < weg.size() - 1 else oben))
	if is_instance_valid(bisher) and bisher != self:
		bisher.verdraengt()


## Führt der restliche Weg zur Stellung an Gegnern vorbei? Dann einen sicheren Umweg nehmen – oder warten.
func _pruefe_weg_zur_stellung() -> void:
	var gefahr: Dictionary = spiel.gefahrenzellen()
	var bedroht := false
	for i in _punkte.size() - 1:   # der letzte Punkt ist die Stellung selbst
		if gefahr.has(karte.zelle_bei(_punkte[i])):
			bedroht = true
			break
	if not bedroht and not _wartet:
		return
	var hier := karte.zelle_bei(position)
	var weg := karte.sicherer_weg_auf_wall(hier, posten_zelle, gefahr)
	var vorher := _wartet
	_wartet = weg.is_empty()
	if _wartet:
		if not vorher:
			_punkte.clear()   # der alte Weg führt durch die Gefahr
		return
	var zur_batterie := karte.inhalt(posten_zelle) == Karte.BATTERIE
	_punkte.clear()
	for i in weg.size():
		if i == 0 and weg[i] == hier and weg.size() > 1:
			continue   # das eigene Feld
		var oben := Vector2.ZERO if zur_batterie else Vector2(0, -12)
		_punkte.append(karte.mitte(weg[i]) + (_versatz if i < weg.size() - 1 else oben))


## Ist diese Einheit noch zu ihrer Stellung unterwegs und hat dabei mehr als `felder` Felder vor sich?
func unterwegs_weiter_als(felder: int) -> bool:
	return zustand == Zustand.ZUM_POSTEN and _punkte.size() > felder


func rest_punkte() -> int:
	return _punkte.size()


## Eine nähere Einheit hat die Stellung übernommen: neue suchen.
func verdraengt() -> void:
	posten_zelle = Karte.KEINE
	_suche_posten()


func am_boden() -> bool:
	return zustand == Zustand.ZUM_POSTEN or zustand == Zustand.BODEN


func in_stellung() -> bool:
	return zustand == Zustand.AUF_POSTEN


## Sitzt die Einheit in einer Batterie? Dann ist sie unsichtbar, schießt nicht selbst und kann nicht getroffen werden.
func in_batterie() -> bool:
	return zustand == Zustand.IN_BATTERIE


func _process(delta: float) -> void:
	if not spiel.im_kampf():
		return
	_abkling -= delta
	_treffer -= delta
	_sprite.modulate = Color(1, 0.55, 0.55) if _treffer > 0.0 else Color.WHITE
	if ausgewaehlt:
		queue_redraw()

	match zustand:
		Zustand.ZUM_POSTEN:
			if spiel.ist_einnehmer(self):
				# Ein verlorener Checkpoint geht vor: die Stellung freigeben und ihn zurückholen
				if karte.posten.get(posten_zelle) == self:
					karte.posten.erase(posten_zelle)
				posten_zelle = Karte.KEINE
				_wartet = false
				_punkte.clear()
				zustand = Zustand.BODEN
				return
			if _im_tor():
				_gehe(delta)   # im Tor wird nicht angehalten: erst ganz hindurch
				return
			# Die Stellung ist ein Nebenauftrag: erst schießen, was in Reichweite und Sicht ist ...
			if karte.ist_begehbar(karte.zelle_bei(position)):
				var gegner_nah: Gegner = spiel.gegner_in_reichweite(position, daten["reichweite"] * Werte.ZELLE, true)
				if gegner_nah != null:
					_sprite.bewegt(false)
					_feuere_auf(gegner_nah)
					return
			# ... und nicht durch Gegner hindurchlaufen: sicheren Weg suchen oder warten.
			_plan_in -= delta
			if _plan_in <= 0.0:
				_plan_in = 0.4
				_pruefe_weg_zur_stellung()
			if _wartet:
				# Kein sicherer Weg zur Stellung: nicht herumstehen, sondern solange am Boden mitkämpfen.
				if daten.get("pilot", false):
					_sprite.bewegt(false)
					return
				_marsch_in -= delta
				if _marsch_in <= 0.0:
					_marsch_in = 0.3
					_waehle_marschziel()
				_gehe(delta)
				return
			if _gehe(delta):
				if karte.inhalt(posten_zelle) == Karte.BATTERIE:
					zustand = Zustand.IN_BATTERIE
					_sprite.visible = false
				else:
					zustand = Zustand.AUF_POSTEN
		Zustand.IN_BATTERIE:
			pass   # die Batterie feuert (siehe main.gd)
		Zustand.AUF_POSTEN:
			# Von oben: mehr Reichweite und Schuss über das eigene Wallstück hinweg. Fremde Erdwälle versperren die Sicht.
			var weite: float = (daten["reichweite"] + Werte.stellung_bonus(daten)) * Werte.ZELLE
			_sprite.bewegt(false)
			var oben_ziel: Node2D = spiel.gegner_in_reichweite(position, weite, false, posten_zelle)
			if faehigkeit == "markierung":
				# Zielmarkierung: das stärkste Ziel der ganzen Karte, ohne Reichweiten- und Sichtgrenze
				var staerkster: Gegner = spiel.staerkster_gegner()
				if staerkster != null:
					oben_ziel = staerkster
			if oben_ziel == null:
				oben_ziel = spiel.zonenbau_in_reichweite(position, weite, false, posten_zelle)
			_feuere_auf(oben_ziel)
		Zustand.BODEN:
			if not karte.ist_begehbar(karte.zelle_bei(position)):
				_gehe(delta)   # noch in der Fabrik: erst heraustreten, dann kämpfen
				return
			if _im_tor():
				_gehe(delta)   # im Tor wird nicht angehalten und nicht umgeplant: erst ganz hindurch, dann neu entscheiden
				return
			# Nachrücken: Ist eine Stellung frei geworden (oder näher als für den, der dorthin unterwegs ist)?
			_posten_check -= delta
			if _posten_check <= 0.0 and not spiel.ist_einnehmer(self):   # Checkpoint zurückholen geht vor
				_posten_check = 1.0
				if not karte.finde_posten(karte.zelle_bei(position), self).is_empty():
					_marschziel = Karte.KEINE
					_suche_posten()
					return
			if daten.get("pilot", false):
				_gehe(delta)   # Piloten kämpfen nicht: an der Fabrik warten, bis eine Batterie einen Platz hat
				return
			# 1) Wer schießen kann, bleibt stehen und schießt. Das geht immer vor – es wird nicht blind weitergelaufen.
			var weite: float = daten["reichweite"] * Werte.ZELLE
			var ziel: Node2D = spiel.gegner_in_reichweite(position, weite, true)
			if ziel == null:
				ziel = spiel.zonenbau_in_reichweite(position, weite, true)
			var drueckt: bool = spiel.im_endkampf() and karte.zelle_bei(position) != _marschziel and _marschziel != Karte.KEINE
			if ziel != null and drueckt and (ziel is Zonenbau or position.distance_to(ziel.position) > Werte.ENDKAMPF_ABSTAND * Werte.ZELLE):
				# Letzte Runde: im Gehen schießen und weiter auf das eigene Feld in der Zone vorrücken – stehen bleibt nur,
				# wem ein Gegner zu nah kommt. Sonst stapeln sich alle am ersten Feld mit Schussweite.
				_feuere_auf(ziel)
			elif ziel != null:
				_sprite.bewegt(false)
				_feuere_auf(ziel)
				return
			# 2) Sonst ein Ziel wählen und hingehen.
			_plan_in -= delta
			if _plan_in <= 0.0:
				_plan_in = 0.3
				_waehle_marschziel()
			_gehe(delta)


## Steckt die Truppe gerade in einem Tor und hat noch Weg vor sich? Dann läuft sie erst hindurch
## (auch durch mehrere Tore hintereinander), statt mittendrin stehen zu bleiben oder umzudrehen.
func _im_tor() -> bool:
	return not _punkte.is_empty() and karte.ist_tor(karte.zelle_bei(position))


## Wohin geht eine Bodentruppe, wenn sie gerade nichts beschießen kann?
##   a) zu einem verlorenen Checkpoint – aber nur, wenn dort gerade kein Gegner in der Nähe ist
##   b) in der letzten Runde zum HQ des Gegners
##   c) sonst der Spitze des Gegners auf der Hauptlinie entgegen, erst danach zu Gegnern abseits davon
func _waehle_marschziel() -> void:
	var hier := karte.zelle_bei(position)
	_marschziel = Karte.KEINE
	var cp := karte.naechster_feind_checkpoint(hier)
	# Nur die zugeteilte Truppe geht. Steht sie schon auf dem Checkpoint, bleibt sie dort, auch wenn Gegner näher kommen.
	if cp != Karte.KEINE and spiel.darf_checkpoint_holen(self, cp) and (hier == cp or spiel.ist_ruhig(karte.mitte(cp), Werte.CHECKPOINT_RUHE * Werte.ZELLE)):
		_marschziel = cp
	elif spiel.im_endkampf():
		# durchs Schild auf das eigene Feld in der Zone
		var feld: Vector2i = spiel.angriffsfeld(self)
		if hier == feld or not karte.einheiten_weg(hier, feld).is_empty():
			_marschziel = feld
		else:
			spiel.gib_angriffsfeld_frei(self)
	if _marschziel != Karte.KEINE:
		if hier != _marschziel:
			_plane_zur_zelle(_marschziel)
		return
	var spitze: Gegner = spiel.vorderster_gegner()
	if spitze != null and _plane_zur_zelle(karte.zelle_bei(spitze.position)):
		return
	var naechster: Gegner = spiel.naechster_gegner(position)
	if naechster != null:
		_plane_zur_zelle(karte.zelle_bei(naechster.position))


## `ziel` ist ein Gegner oder (in der letzten Runde) ein Gebäude in der Zone.
func _feuere_auf(ziel: Node2D) -> void:
	if ziel == null or spiel.im_rauch(position):
		# Minigun: Rauch stoppt den Anlauf sofort, ohne Ziel läuft sie langsam aus
		_anlauf = 0.0 if ziel != null else maxf(0.0, _anlauf - 0.4 * get_process_delta_time())
		_laser_ziel = null
		return   # im Rauch sieht die Einheit nichts
	_sprite.flip_h = ziel.position.x < position.x
	var farbe := Color(daten["schussfarbe"])
	var muendung := position + Vector2(18 * (-1 if _sprite.flip_h else 1), -10)
	var oben := zustand == Zustand.AUF_POSTEN

	# Laserstrahl: kein Einzelschuss, sondern Dauerschaden, der am selben Ziel anwächst
	if faehigkeit == "laser" and ziel is Gegner:
		var dt := get_process_delta_time()
		if ziel != _laser_ziel:
			_laser_ziel = ziel
			_laser_zeit = 0.0
		_laser_zeit += dt
		var faktor := minf(Werte.LASER_HOECHST, 1.0 + Werte.LASER_ANSTIEG * _laser_zeit)
		spiel.strahl(muendung, ziel.position + Vector2(0, 2), Color(1.0, 0.35, 0.3), 2.0 + faktor)
		_sprite.angriff(0.3)
		(ziel as Gegner).nimm_schaden(float(daten["schaden"]) / float(daten["abklingzeit"]) * faktor * dt)
		return

	if _abkling > 0.0:
		return
	var pause: float = daten["abklingzeit"]
	if faehigkeit == "feuerteam":
		# je mehr Feuerteam-Schützen gerade dasselbe Ziel beschießen, desto kürzer die Pause
		pause *= maxf(Werte.FEUERTEAM_HOECHST, 1.0 - Werte.FEUERTEAM_JE_MITSCHUETZE * spiel.mitschuetzen(self, ziel))
	elif faehigkeit == "minigun" and oben:
		pause *= lerpf(1.0, Werte.MINIGUN_SCHNELLSTE, _anlauf)
		_anlauf = minf(1.0, _anlauf + Werte.MINIGUN_JE_SCHUSS)
	elif faehigkeit == "markierung" and oben:
		pause *= Werte.MARKIERUNG_ABKLING
	_abkling = pause
	letztes_ziel = ziel
	letzter_schuss = spiel.spielzeit()
	_sprite.angriff(pause)

	if faehigkeit == "markierung" and oben and ziel is Gegner:
		spiel.strahl(muendung, ziel.position, Color(1.0, 0.25, 0.3), 2.0)
		(ziel as Gegner).markiert = Werte.MARKIERUNG_SEK
		(ziel as Gegner).nimm_schaden(float(daten["schaden"]) * Werte.MARKIERUNG_EIGENER_SCHADEN)
		return
	if faehigkeit == "durchschuss" and ziel is Gegner:
		# gerade Linie durch alle Gegner bis ans Ende der Reichweite
		var richtung := (ziel.position - position).normalized()
		var ende := position + richtung * reichweite_jetzt() * Werte.ZELLE
		spiel.strahl(muendung, ende, farbe, 3.0)
		spiel.linienschaden(self, position, ende, float(daten["schaden"]), posten_zelle if oben else Karte.KEINE)
		return
	if daten.has("flaeche") and ziel is Gegner:
		# Flächenschaden: trifft alle Gegner rund um das Ziel
		var radius: float = float(daten["flaeche"]) * Werte.ZELLE
		spiel.schuss(position + Vector2(0, -10), ziel.position, farbe)
		if faehigkeit == "plasmagel" and oben:
			spiel.gelschuss(ziel.position, radius, float(daten["schaden"]) * Werte.PLASMAGEL_SCHADEN)
			return
		spiel.flaechenschaden(ziel.position, radius, daten["schaden"], farbe)
		if faehigkeit == "abpraller":
			spiel.abpraller(ziel as Gegner, radius, float(daten["schaden"]), farbe)
		elif faehigkeit == "brandfeld":
			spiel.lege_brand(ziel.position, radius, float(daten["schaden"]) * Werte.BRANDFELD_SCHADEN)
		return
	spiel.schuss(muendung, ziel.position + Vector2(0, 4), farbe)
	ziel.call("nimm_schaden", daten["schaden"])


## Läuft die Wegpunkte ab. true, sobald keiner mehr übrig ist.
func _gehe(delta: float) -> bool:
	_sprite.bewegt(not _punkte.is_empty())
	if _punkte.is_empty():
		return true
	var schritt: float = daten["tempo"] * Werte.ZELLE * delta
	var ziel := _punkte[0]
	if absf(ziel.x - position.x) > 1.0:
		_sprite.flip_h = ziel.x < position.x
	if position.distance_to(ziel) <= schritt:
		position = ziel
		_punkte.remove_at(0)
	else:
		position = position.move_toward(ziel, schritt)
	return _punkte.is_empty()


## Plant den Fußweg zu `ziel`. false, wenn es keinen gibt.
func _plane_zur_zelle(ziel: Vector2i) -> bool:
	var hier := karte.zelle_bei(position)
	var weg := karte.einheiten_weg(hier, ziel)
	if weg.is_empty() and hier != ziel:
		return false
	_punkte.clear()
	# Das erste Feld ist das eigene – außer die Einheit steckt noch in der Fabrik.
	for i in range(1 if karte.ist_begehbar(hier) else 0, weg.size()):
		_punkte.append(karte.mitte(weg[i]) + _versatz)
	return true


## Der Wall unter der Einheit wurde eingerissen: sie kämpft am Boden weiter.
func posten_verloren() -> void:
	posten_zelle = Karte.KEINE
	zustand = Zustand.BODEN
	_sprite.visible = true
	_punkte.clear()
	_plan_in = 0.0
	_marschziel = Karte.KEINE


func nimm_schaden(menge: float) -> void:
	_anlauf = 0.0   # Minigun: ein Treffer unterbricht den Anlauf
	leben -= menge
	_treffer = 0.08
	queue_redraw()
	if leben <= 0.0:
		spiel.einheit_gefallen(self)


## Reichweite in Feldern, so wie sie gerade gilt (in der Stellung mit Bonus).
func reichweite_jetzt() -> float:
	return daten["reichweite"] + (Werte.stellung_bonus(daten) if zustand == Zustand.AUF_POSTEN else 0.0)


func _draw() -> void:
	if ausgewaehlt and zustand != Zustand.IN_BATTERIE and reichweite_jetzt() > 0.5:
		var r := reichweite_jetzt() * Werte.ZELLE
		draw_circle(Vector2.ZERO, r, Color(0.5, 0.88, 1.0, 0.08))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.5, 0.88, 1.0, 0.8), 2.0)
	if ausbaustufe > 0 and zustand != Zustand.IN_BATTERIE:
		# Abzeichen über dem Kopf: ein Punkt je Stufe; ab Stufe 3 in der Farbe der Fähigkeit, dazu ein Ring am Boden
		var farbe: Color = ABZEICHEN.get(faehigkeit, Color("ffe9a8"))
		var links := -5.0 * ausbaustufe + 1.0
		for i in ausbaustufe:
			draw_rect(Rect2(links + i * 10.0 - 1.0, -57, 8, 8), Color(0.08, 0.06, 0.12, 0.9))
			draw_rect(Rect2(links + i * 10.0, -56, 6, 6), farbe)
		if faehigkeit != "":
			draw_arc(Vector2(0, 14), 15.0, 0.0, TAU, 20, Color(farbe, 0.85), 2.0)
	if leben < max_leben:
		draw_rect(Rect2(-16, -46, 32, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, -44, 28.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("7fe0ff"))
