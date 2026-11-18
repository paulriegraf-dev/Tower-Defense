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
var _ft_anlauf := 0.0   # Feuerteam: Anlauf 0..1
var letzte_zielzelle := Vector2i(-99, -99)   # 17.11.: ... und auf welcher Kachel das Ziel stand (Feuerteam zählt je Kachel)
var _ausstehend: Array = []        # 15.11.: Treffer, die erst im Bild mit dem Mündungsblitz fallen ({"t", "ziel", "pos", "muendung", "erster", "minigun"})
var _laser_ziel: Node2D = null
var _laser_zeit := 0.0
var _spiegel_punkt := Vector2.INF   # Schuss über einen Spiegel: dort knickt er ab (INF = direkt)
var _ohne_ziel := 0.0              # Aufräumen: so lange (Sekunden) hat die Truppe in der Stellung kein Ziel mehr
var _anlauf := 0.0                 # Minigun: 0..1
var _bruestung: Sprite2D = null    # neue Grafik: Vorderkante der Stellung vor der Figur


var ist_pilot := false
var ausbaustufe := 0                # Stufe der Fabrik, aus der die Truppe kommt (für das Abzeichen)
var folge: Node2D = null            # Kommandant hat gesammelt: ihm folgen
var sturm_bis := 0.0                # Losschlagen: so lange schneller und rascher feuern
var sturm_ziel := Karte.KEINE       # ... und dorthin stürmen
var klon := false                   # aus der Klonmaschine (wird nicht noch einmal geklont)
var _gefolgt := false

## Farbe des Abzeichens je Stufe-3-Fähigkeit
const ABZEICHEN := {
	"durchschuss": Color("ffd166"), "laser": Color("ff4d5e"), "markierung": Color("ff9f1c"),
	"bollwerk": Color("6fa8ff"), "feuerteam": Color("f4f4f4"), "minigun": Color("ffb347"),
	"abpraller": Color("c77dff"), "brandfeld": Color("ff6a00"), "plasmagel": Color("5dfc8a"),
}


func start(p_spiel: Node, p_karte: Karte, typ: String, p_fabrik: Vector2i, stufe: int = 0, p_faehigkeit: String = "") -> void:
	ausbaustufe = 0 if typ == "pilot" else stufe
	ist_pilot = typ == "pilot"
	spiel = p_spiel
	karte = p_karte
	daten = Werte.grafik_einheit(Werte.einheit_daten(typ, stufe, p_faehigkeit), typ, stufe)
	faehigkeit = daten["faehigkeit"]
	max_leben = daten["leben"]
	leben = max_leben
	fabrik_zelle = p_fabrik
	position = karte.mitte(p_fabrik)
	_versatz = Vector2(randf_range(-10, 10), randf_range(-8, 8))
	_sprite = Figur.new()
	add_child(_sprite)
	_sprite.einrichten(daten)
	if Werte.grafik_neu and Werte.NEU_HALTUNG.has(typ):
		# Neue Grafik: in der Stellung kniend bzw. liegend, die Brüstung verdeckt die Beine
		_sprite.setze_haltung(Werte.NEU_HALTUNG[typ])
		_bruestung = Sprite2D.new()   # (in HD-2D unsichtbar: dort ist die Brüstung ein 3D-Block)
		_bruestung.texture = load(Werte.NEU + "wand/bruestung.png")
		_bruestung.position = Vector2(0, 14)
		_bruestung.visible = false
		add_child(_bruestung)

	_suche_posten()


## Nächste Stellung wählen und sich auf den Weg machen – oder am Boden kämpfen, wenn keine frei ist.
func _suche_posten() -> void:
	var hier := karte.zelle_bei(position)
	var fund := karte.finde_posten(hier, self)
	if spiel.im_endkampf() and not ist_pilot and not spiel.endkampf_stellung_frei(self):
		fund = {}   # letzte Runde: nur die zusätzlichen Truppen greifen an, die normale Besatzung bleibt in den Stellungen (17.11.)
	_punkte.clear()
	if fund.is_empty():
		zustand = Zustand.BODEN
		posten_zelle = Karte.KEINE
		if not karte.ist_frei(hier):
			# erst aus der Fabrik heraustreten
			for raus: Vector2i in karte.ausgang(hier):
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


## Drang in die Stellung dieser Truppe (Werte.STELLUNG_DRANG).
func _drang() -> Dictionary:
	var b := str(daten.get("blatt", ""))
	for id: String in Werte.STELLUNG_DRANG:
		if id in b:
			return Werte.STELLUNG_DRANG[id]
	return {}


## Führt der restliche Weg zur Stellung an Gegnern vorbei? Dann einen sicheren Umweg nehmen – oder warten.
## 16.11.: je nach Truppe kleinerer Gefahrenkreis (Scharfschütze gar keiner); kurz vor der Stellung wird immer gegangen.
func _pruefe_weg_zur_stellung() -> void:
	var radius := float(_drang().get("gefahr", Werte.GEFAHR_RADIUS))
	if radius <= 0.0 or (_punkte.size() <= Werte.STELLUNG_TROTZDEM_FELDER and not _wartet):
		_wartet = false
		return
	var gefahr: Dictionary = spiel.gefahrenzellen(radius)
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


## Kampftruppe am Boden (kein Pilot)? Ziel für Flächentreffer auf Haufen.
func bodentruppe() -> bool:
	return am_boden() and not ist_pilot


func in_stellung() -> bool:
	return zustand == Zustand.AUF_POSTEN


## Sitzt die Einheit in einer Batterie? Dann ist sie unsichtbar, schießt nicht selbst und kann nicht getroffen werden.
func in_batterie() -> bool:
	return zustand == Zustand.IN_BATTERIE


func _process(delta: float) -> void:
	if _bruestung != null:
		var oben := zustand == Zustand.AUF_POSTEN
		_sprite.haltung(oben)
		_bruestung.visible = oben and not Werte.grafik_hd
	if not spiel.im_kampf():
		return
	_abkling -= delta
	_treffer -= delta
	if not _ausstehend.is_empty():
		_ausstehende_treffer(delta)
	_sprite.modulate = (Color(1, 0.86, 0.84) if Werte.grafik_neu else Color(1, 0.55, 0.55)) if _treffer > 0.0 else (Color(0.85, 0.75, 1.0) if sturm_bis > 0.0 else Color.WHITE)
	if ausgewaehlt:
		queue_redraw()
	if sturm_bis > 0.0:
		sturm_bis -= delta
	if is_instance_valid(folge) or (sturm_bis > 0.0 and sturm_ziel != Karte.KEINE):
		_folgen(delta)
		return
	if _gefolgt:
		# Sammeln/Losschlagen vorbei: wieder selbst entscheiden
		_gefolgt = false
		folge = null
		sturm_ziel = Karte.KEINE
		zustand = Zustand.BODEN
		_punkte.clear()
		_suche_posten()

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
			if not ist_pilot and spiel.aufraeumen():
				# Rundenende, nichts kommt mehr nach: nicht mehr in die Stellung, sondern den Übrigen hinterher
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
			# Unterwegs zur Stellung nur stehen bleiben und schießen, wenn ein Gegner wirklich nah ist (16.11., Paul: die
			# Scharfschützen blieben mit ihrer großen Reichweite sonst unten stehen und kamen nie in die Stellung). Die
			# letzten Felder bis zur Stellung werden immer gegangen.
			if karte.ist_begehbar(karte.zelle_bei(position)) and _punkte.size() > Werte.STELLUNG_DURCHGEHEN_FELDER:
				var nah_weite: float = minf(float(daten["reichweite"]), float(_drang().get("nahwehr", Werte.STELLUNG_NAHWEHR_FELDER))) * Werte.ZELLE
				var gegner_nah: Gegner = spiel.gegner_in_reichweite(position, nah_weite, true, Karte.KEINE, spiel.zielmodus(fabrik_zelle))
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
			var weite: float = (daten["reichweite"] + karte.posten_bonus(posten_zelle, daten)) * Werte.ZELLE
			_sprite.bewegt(false)
			# Alle Gegner weg, aber ein Checkpoint ist noch verloren: Die nächste Truppe verlässt dafür ihre Stellung.
			_posten_check -= delta
			if _posten_check <= 0.0:
				_posten_check = 0.5
				if spiel.raeumen():
					for i in karte.checkpoints.size():
						if karte.cp_feind[i] and spiel.darf_checkpoint_holen(self, karte.checkpoints[i]):
							if karte.posten.get(posten_zelle) == self:
								karte.posten.erase(posten_zelle)
							posten_zelle = Karte.KEINE
							zustand = Zustand.BODEN
							_waehle_marschziel()
							return
			var oben_ziel: Node2D = spiel.gegner_in_reichweite(position, weite, false, posten_zelle, spiel.zielmodus(fabrik_zelle))
			if faehigkeit == "markierung":
				# Zielmarkierung: das stärkste Ziel der ganzen Karte, ohne Reichweiten- und Sichtgrenze
				var staerkster: Gegner = spiel.staerkster_gegner()
				if staerkster != null:
					oben_ziel = staerkster
			if oben_ziel == null:
				oben_ziel = spiel.zonenbau_in_reichweite(position, weite, false, posten_zelle)
			# Aufräumen: Nichts kommt mehr nach und von hier oben ist kein Ziel zu treffen – absteigen und hinterher.
			if oben_ziel == null and spiel.aufraeumen():
				_ohne_ziel += delta
				if _ohne_ziel >= 1.5 and spiel.darf_absteigen(self):
					_ohne_ziel = 0.0
					if karte.posten.get(posten_zelle) == self:
						karte.posten.erase(posten_zelle)
					posten_zelle = Karte.KEINE
					zustand = Zustand.BODEN
					_waehle_marschziel()
					return
			else:
				_ohne_ziel = 0.0
			_feuere_auf(oben_ziel)
		Zustand.BODEN:
			if not karte.ist_begehbar(karte.zelle_bei(position)):
				if _punkte.is_empty():
					# steht noch in der Fabrik (oder auf einem Wall) und hat keinen Weg mehr: auf das nächste freie Feld treten,
					# sonst bleibt sie für immer stehen
					for raus: Vector2i in karte.ausgang(karte.zelle_bei(position)):
						_punkte.append(karte.mitte(raus) + _versatz)
				_gehe(delta)   # noch in der Fabrik: erst heraustreten, dann kämpfen
				return
			if _im_tor():
				_gehe(delta)   # im Tor wird nicht angehalten und nicht umgeplant: erst ganz hindurch, dann neu entscheiden
				return
			# Nachrücken: Ist eine Stellung frei geworden (oder näher als für den, der dorthin unterwegs ist)?
			_posten_check -= delta
			if _posten_check <= 0.0 and not spiel.ist_einnehmer(self) and (ist_pilot or not spiel.aufraeumen()):   # Checkpoint zurückholen und Aufräumen gehen vor
				_posten_check = 1.0
				if (ist_pilot or not spiel.im_endkampf() or spiel.endkampf_stellung_frei(self)) and not karte.finde_posten(karte.zelle_bei(position), self).is_empty():
					_marschziel = Karte.KEINE
					_suche_posten()
					return
			if daten.get("pilot", false):
				_repariere(delta)   # Piloten kämpfen nicht: Reserve wartet an der Fabrik – oder repariert, was ausgefallen ist
				return
			# 1) Wer schießen kann, bleibt stehen und schießt. Das geht immer vor – es wird nicht blind weitergelaufen.
			var weite: float = (daten["reichweite"] + _hoehe()) * Werte.ZELLE   # 18.11.: Anhöhe
			var ziel: Node2D = spiel.gegner_in_reichweite(position, weite, true, Karte.KEINE, spiel.zielmodus(fabrik_zelle))
			if ziel == null:
				ziel = spiel.zonenbau_in_reichweite(position, weite, true)
			_spiegel_punkt = Vector2.INF
			if ziel == null:
				# Spiegel: um die Ecke schießen (nur Bodentruppen)
				var ueber: Dictionary = spiel.ziel_ueber_spiegel(position, weite)
				if not ueber.is_empty():
					ziel = ueber["ziel"]
					_spiegel_punkt = ueber["spiegel"]
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
	# Jeder verlorene Checkpoint bekommt seine eigene Truppe: alle durchgehen, nicht nur den nächsten.
	# Nur die zugeteilte Truppe geht. Steht sie schon auf dem Checkpoint, bleibt sie dort, auch wenn Gegner näher kommen.
	var cp := Karte.KEINE
	for i in karte.checkpoints.size():
		var c: Vector2i = karte.checkpoints[i]
		if karte.cp_feind[i] and spiel.darf_checkpoint_holen(self, c) and (hier == c or spiel.ist_ruhig(karte.mitte(c), Werte.CHECKPOINT_RUHE * Werte.ZELLE)):
			cp = c
			break
	if cp != Karte.KEINE:
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
	# Entgegenlaufen, nie hinterher: ein Feld auf dem Weg eines Gegners, an dem diese Truppe vor ihm ankommt.
	# Wer schon durch ist und nicht mehr abzufangen, gehört den Stellungen, Türmen und Batterien weiter hinten.
	var grenze := Werte.ZONE_SPALTEN + Werte.ZONE_ABSTAND
	for c: Vector2i in karte.checkpoints:
		grenze = mini(grenze, c.x)
	var abfang: Vector2i = spiel.abfangfeld(self)
	if abfang != Karte.KEINE:
		_marschziel = abfang
		if hier != abfang:
			_plane_zur_zelle(abfang)
		return
	if spiel.aufraeumen():
		# Rundenende: Wer nicht mehr abzufangen ist, wird jetzt doch verfolgt – es kommt ja nichts mehr nach.
		var jagd: Vector2i = spiel.jagdziel(self)
		if jagd != Karte.KEINE:
			_marschziel = jagd
			if hier != jagd:
				_plane_zur_zelle(jagd)
			return
	if hier.x < grenze and not spiel.im_endkampf():
		# zu weit vorn: zurück hinter die Linie, auf das nächste freie Feld
		var bestes := Karte.KEINE
		for y in Werte.ZEILEN:
			var z := Vector2i(grenze, y)
			if karte.ist_frei(z) and (bestes == Karte.KEINE or absi(y - hier.y) < absi(bestes.y - hier.y)):
				bestes = z
		if bestes != Karte.KEINE:
			_plane_zur_zelle(bestes)


func marschziel() -> Vector2i:
	return _marschziel if zustand == Zustand.BODEN or _wartet else Karte.KEINE


var _rep_ziel := Karte.KEINE
var _rep_neben := Karte.KEINE
var _rep_zeit := 0.0
var _rep_suche := 0.0

## Reservepilot: zum nächsten ausgefallenen Gebäude oder lahmen Turm laufen und es in Werte.REPARATUR_SEK reparieren.
func _repariere(delta: float) -> void:
	if _rep_ziel != Karte.KEINE and not spiel.ist_kaputt(_rep_ziel):
		_rep_ziel = Karte.KEINE
		_rep_zeit = 0.0
		queue_redraw()
	if _rep_ziel == Karte.KEINE:
		_rep_suche -= delta
		if _rep_suche <= 0.0:
			_rep_suche = 1.0
			var fund: Dictionary = spiel.reparaturziel(self)
			if not fund.is_empty():
				_rep_ziel = fund["z"]
				_rep_neben = fund["neben"]
				_plane_zur_zelle(_rep_neben)
		if _rep_ziel == Karte.KEINE:
			_gehe(delta)
			return
	if not _gehe(delta) and karte.zelle_bei(position) != _rep_neben:
		return
	if karte.zelle_bei(position) != _rep_neben:
		_rep_ziel = Karte.KEINE   # Weg versperrt: neu suchen
		return
	_sprite.bewegt(false)
	_rep_zeit += delta
	queue_redraw()
	if _rep_zeit >= Werte.REPARATUR_SEK:
		spiel.repariere(_rep_ziel)
		_rep_ziel = Karte.KEINE
		_rep_zeit = 0.0


## `ziel` ist ein Gegner oder (in der letzten Runde) ein Gebäude in der Zone.
func _feuere_auf(ziel: Node2D) -> void:
	spiel.schadensquelle = "fabrik:%d,%d" % [fabrik_zelle.x, fabrik_zelle.y]   # Schadensliste: alles von hier zählt für die Fabrik
	spiel.schuetze = self   # 18.11.: für den Erfolg „Einsamer Posten“
	spiel.schuss_herkunft = position
	# Im Rauch sieht die Einheit nichts – außer mit Klarsicht (Scharfschütze ab Stufe 2) oder auf ein markiertes Ziel.
	var blind: bool = spiel.im_rauch(position) and not daten.get("klarsicht", false) and not (in_stellung() and spiel.peilung(posten_zelle)) and not (ziel is Gegner and (ziel as Gegner).markiert > 0.0)
	if ziel == null or blind:
		# Minigun: Rauch stoppt den Anlauf sofort, ohne Ziel läuft sie langsam aus
		_anlauf = 0.0 if ziel != null else maxf(0.0, _anlauf - 0.4 * get_process_delta_time())
		_laser_ziel = null
		return   # im Rauch sieht die Einheit nichts
	_sprite.flip_h = ziel.position.x < position.x
	var farbe := Color(daten["schussfarbe"])
	var muendung := position + Vector2(18 * (-1 if _sprite.flip_h else 1), -10)
	var oben := zustand == Zustand.AUF_POSTEN
	if _spiegel_punkt != Vector2.INF and not oben:
		# über den Spiegel: erst zum Spiegel, von dort weiter zum Ziel
		if faehigkeit == "laser":
			spiel.strahl(muendung, _spiegel_punkt, Color(1.0, 0.35, 0.3), 2.0)
		elif _abkling <= 0.0:
			spiel.schuss(muendung, _spiegel_punkt, farbe)
		muendung = _spiegel_punkt

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
		(ziel as Gegner).nimm_schaden(float(daten["schaden"]) / float(daten["abklingzeit"]) * faktor * dt, true)
		return

	if _abkling > 0.0:
		return
	var pause: float = daten["abklingzeit"]
	if faehigkeit == "feuerteam":
		# je mehr Feuerteam-Schützen gerade Gegner auf derselben Kachel beschießen, desto kürzer die Pause –
		# 17.11.: der Bonus baut sich über einige Schüsse auf (Anlauf) und verfällt bei einer Feuerpause
		var mit: int = spiel.mitschuetzen(self, ziel)
		if spiel.spielzeit() - letzter_schuss > Werte.FEUERTEAM_PAUSE_VERFALL:
			_ft_anlauf = 0.0
		if mit > 0:
			_ft_anlauf = minf(1.0, _ft_anlauf + Werte.FEUERTEAM_ANLAUF_JE_SCHUSS)
		else:
			_ft_anlauf = maxf(0.0, _ft_anlauf - Werte.FEUERTEAM_ANLAUF_JE_SCHUSS)
		var voll := maxf(Werte.FEUERTEAM_HOECHST, 1.0 - Werte.FEUERTEAM_JE_MITSCHUETZE * mit)
		pause *= lerpf(1.0, voll, _ft_anlauf)
	elif faehigkeit == "minigun" and oben:
		pause = Werte.MINIGUN_ABKLING * lerpf(1.0, Werte.MINIGUN_SCHNELLSTE, _anlauf)
		_anlauf = minf(1.0, _anlauf + Werte.MINIGUN_JE_SCHUSS)
	elif faehigkeit == "markierung" and oben:
		pause *= Werte.MARKIERUNG_ABKLING
	if oben:
		pause *= spiel.funk_faktor(posten_zelle)   # Funkturm in der Nähe: schneller feuern
	if sturm_bis > 0.0:
		pause *= float(Werte.KOMMANDANT["sturm_feuer"])   # Losschlagen: rascher feuern
	_abkling = pause
	letztes_ziel = ziel
	letzter_schuss = spiel.spielzeit()
	letzte_zielzelle = spiel.karte.zelle_bei(ziel.position)
	Ton.am_ort(spiel, Ton.fuer_truppe(daten), position)
	_sprite.angriff(pause)

	if faehigkeit == "markierung" and oben and ziel is Gegner:
		spiel.strahl(muendung, ziel.position, Color(1.0, 0.25, 0.3), 2.0)
		(ziel as Gegner).markiert = Werte.MARKIERUNG_SEK
		(ziel as Gegner).nimm_schaden(float(daten["schaden"]) * Werte.MARKIERUNG_EIGENER_SCHADEN)
		return
	if faehigkeit == "durchschuss" and ziel is Gegner:
		# gerade Linie durch alle Gegner bis ans Ende der Reichweite
		var start := muendung if _spiegel_punkt != Vector2.INF and not oben else position
		var richtung := (ziel.position - start).normalized()
		var ende := start + richtung * reichweite_jetzt() * Werte.ZELLE
		spiel.strahl(muendung, ende, farbe, 3.0)
		spiel.linienschaden(self, start, ende, float(daten["schaden"]), posten_zelle if oben else Karte.KEINE)
		return
	# 15.11.: Treffer im Takt der Animation – je Mündungsblitz (Werte: schuss_bilder) einer.
	# Die Minigun zeigt vorerst nur den ersten Blitz und trifft einmal.
	var minigun := faehigkeit == "minigun" and oben
	var bilder: Array = daten.get("schuss_bilder", [0])
	if minigun or (faehigkeit == "plasmagel" and oben):
		bilder = [bilder[0]]   # Plasmagel aus der Stellung: ein Gelschuss statt zwei Flächentreffer
	var dauer := minf(float(daten["angriff_dauer"]), pause)
	var n_bilder := float(daten["bilder"][2])
	var start := muendung if _spiegel_punkt != Vector2.INF and not oben else position + Vector2(0, -10)
	for i in bilder.size():
		var e := {"t": float(bilder[i]) / n_bilder * dauer, "ziel": ziel, "pos": ziel.position,
			"muendung": muendung, "start": start, "erster": i == 0, "minigun": minigun,
			"flaeche": daten.has("flaeche") and ziel is Gegner}
		if e["t"] <= 0.0:
			_treffe(e)
		else:
			_ausstehend.append(e)


## 15.11.: wartende Treffer herunterzählen und im Bild des Mündungsblitzes auslösen.
func _ausstehende_treffer(delta: float) -> void:
	var faellig: Array = []
	for e: Dictionary in _ausstehend:
		e["t"] = float(e["t"]) - delta
		if e["t"] <= 0.0:
			faellig.append(e)
	for e: Dictionary in faellig:
		_ausstehend.erase(e)
		_treffe(e)


## Ein Treffer: Fläche (Plasmawerfer) oder Einzelziel. Fähigkeiten der Fläche nur beim ersten Schuss eines Angriffs.
func _treffe(e: Dictionary) -> void:
	var ziel = e["ziel"]
	var lebt: bool = is_instance_valid(ziel) and not ziel.is_queued_for_deletion() and not (ziel is Gegner and (ziel as Gegner)._tot)
	spiel.schadensquelle = "fabrik:%d,%d" % [fabrik_zelle.x, fabrik_zelle.y]
	spiel.schuetze = self   # 18.11.: für den Erfolg „Einsamer Posten“
	spiel.schuss_herkunft = position
	var farbe := Color(daten["schussfarbe"])
	var schaden := float(daten["schaden"]) * (Werte.MINIGUN_SCHADEN_FAKTOR if e["minigun"] else 1.0)
	if e["flaeche"]:
		# Flächenschaden: trifft alle Gegner rund um das Ziel (ist es schon weg, dort, wo es zuletzt war)
		var ort: Vector2 = (ziel as Node2D).position if lebt else e["pos"]
		var radius: float = float(daten["flaeche"]) * Werte.ZELLE
		spiel.schuss(e["start"], ort, farbe)
		if e["erster"] and faehigkeit == "plasmagel" and zustand == Zustand.AUF_POSTEN:
			spiel.gelschuss(ort, radius, schaden * Werte.PLASMAGEL_SCHADEN)
			return
		spiel.flaechenschaden(ort, radius, schaden, farbe)
		if e["erster"] and lebt and faehigkeit == "abpraller":
			spiel.abpraller(ziel as Gegner, radius, schaden, farbe)
		elif e["erster"] and faehigkeit == "brandfeld":
			spiel.lege_brand(ort, radius, schaden * Werte.BRANDFELD_SCHADEN)
		return
	if not lebt:
		# Ziel ist schon gefallen: wie bei Brakk aufs nächste Ziel in Reichweite umschwenken (sonst ginge der Schuss ins Leere)
		var oben := zustand == Zustand.AUF_POSTEN
		ziel = spiel.gegner_in_reichweite(position, reichweite_jetzt() * Werte.ZELLE, not oben, posten_zelle if oben else Karte.KEINE, spiel.zielmodus(fabrik_zelle))
		if ziel == null:
			return
		var m: Vector2 = e["muendung"]
		_sprite.flip_h = ziel.position.x < position.x
		e["muendung"] = position + Vector2(absf(m.x - position.x) * (-1 if _sprite.flip_h else 1), m.y - position.y)
	spiel.schuss(e["muendung"], (ziel as Node2D).position + Vector2(0, 4), farbe)
	ziel.call("nimm_schaden", schaden)


## Vom Kommandanten gesammelt: Stellung freigeben und ihm folgen.
func folge_kommandant(k: Node2D) -> void:
	if posten_zelle != Karte.KEINE and karte.posten.get(posten_zelle) == self:
		karte.posten.erase(posten_zelle)
	posten_zelle = Karte.KEINE
	zustand = Zustand.BODEN
	_punkte.clear()
	_plan_in = 0.0
	folge = k
	sturm_bis = 0.0
	_gefolgt = true


## Folgen bzw. Stürmen: was in Reichweite ist, wird beschossen; sonst zum Kommandanten bzw. zum Sturmziel.
func _folgen(delta: float) -> void:
	_gefolgt = true
	var weite: float = (daten["reichweite"] + _hoehe()) * Werte.ZELLE   # 18.11.: Anhöhe
	var ziel: Node2D = spiel.gegner_in_reichweite(position, weite, true, Karte.KEINE, spiel.zielmodus(fabrik_zelle))
	if ziel != null:
		_sprite.bewegt(false)
		_feuere_auf(ziel)
		return
	var ziel_zelle := sturm_ziel if not is_instance_valid(folge) else karte.zelle_bei(folge.position)
	if is_instance_valid(folge) and position.distance_to(folge.position) < Werte.ZELLE * 1.3:
		_sprite.bewegt(false)
		return
	if not is_instance_valid(folge) and karte.zelle_bei(position) == sturm_ziel:
		sturm_ziel = Karte.KEINE   # angekommen und nichts zu tun: Sturm ist vorbei
		return
	_plan_in -= delta
	if _plan_in <= 0.0 or _punkte.is_empty():
		_plan_in = 0.5
		if not karte.ist_begehbar(ziel_zelle):
			# Kommandant auf dem Wall: zum freien Feld daneben
			for n in Karte.NACHBARN:
				if karte.ist_begehbar(ziel_zelle + n):
					ziel_zelle = ziel_zelle + n
					break
		_plane_zur_zelle(ziel_zelle)
	_gehe(delta)


## Läuft die Wegpunkte ab. true, sobald keiner mehr übrig ist.
func _gehe(delta: float) -> bool:
	_sprite.bewegt(not _punkte.is_empty())
	if _punkte.is_empty():
		return true
	var schritt: float = daten["tempo"] * Werte.ZELLE * delta * (float(Werte.KOMMANDANT["sturm_tempo"]) if sturm_bis > 0.0 else 1.0)
	schritt *= karte.boden_tempo(position)   # 18.11.: Sumpf bremst, Eis beschleunigt (auch Brakk)
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


## 18.11. (Etappe 2): Schuss oder Wurf aus der Ferne (Battlesphäre, Schleuder, Laser) – auf einer Ruine gibt es Deckung.
## (Gilt auch für Brakk: nimm_schaden ruft dann seine eigene Fassung.)
func nimm_fernschaden(menge: float) -> void:
	if karte.boden_bei(position) == "ruine":
		menge *= 1.0 - Werte.RUINE_DECKUNG
	nimm_schaden(menge)


func nimm_schaden(menge: float) -> void:
	_anlauf *= 1.0 - Werte.MINIGUN_TREFFER_VERLUST   # Minigun: ein Treffer kostet einen Teil des Anlaufs
	var f: float = spiel.schild_faktor(position)   # Schildgenerator-Kuppel
	if f < 1.0:
		spiel.kuppel_abgefangen(position, menge * (1.0 - f))
	menge *= f
	if zustand == Zustand.AUF_POSTEN:
		menge *= 1.0 - Werte.STELLUNG_DECKUNG   # Patch 16.11.: Deckung in der Stellung
	leben -= menge
	_treffer = 0.08
	queue_redraw()
	if leben <= 0.0 and not spiel.lazarett_rettet(self):
		spiel.einheit_gefallen(self)


## Reichweite in Feldern, so wie sie gerade gilt (in der Stellung mit Bonus).
func reichweite_jetzt() -> float:
	return daten["reichweite"] + (karte.posten_bonus(posten_zelle, daten) if zustand == Zustand.AUF_POSTEN else _hoehe())


## 18.11.: Anhöhe – mehr Reichweite am Boden (in der Stellung rechnet posten_bonus sie ein). Auch für Brakk.
func _hoehe() -> float:
	return karte.anhoehe_bonus(karte.zelle_bei(position))


func _draw() -> void:
	if ausgewaehlt and zustand != Zustand.IN_BATTERIE and reichweite_jetzt() > 0.5:
		var r := reichweite_jetzt() * Werte.ZELLE
		draw_circle(Vector2.ZERO, r, Color(0.5, 0.88, 1.0, 0.08))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.5, 0.88, 1.0, 0.8), 2.0)
	if ausbaustufe > 0 and zustand != Zustand.IN_BATTERIE:
		# Abzeichen: ab Stufe 3 ein Ring am Boden in der Farbe der Fähigkeit. Die Punkte über dem Kopf sind weg
		# (17.11., Paul): die Ausbaustufe zeigt jetzt das Aussehen der Truppe.
		var farbe: Color = ABZEICHEN.get(faehigkeit, Color("ffe9a8"))
		if faehigkeit != "":
			draw_arc(Vector2(0, 14), 13.0 if Werte.grafik_neu else 15.0, 0.0, TAU, 20, Color(farbe, 0.5 if Werte.grafik_neu else 0.85), 2.0)
	if _rep_zeit > 0.0:
		# Reparatur läuft: Fortschrittsring
		draw_arc(Vector2(0, -30), 12.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(_rep_zeit / Werte.REPARATUR_SEK, 0.0, 1.0), 20, Color("7fe0ff"), 4.0)
	if leben < max_leben and not Werte.grafik_hd:   # HD-2D: Balken als 3D-Bild über der Figur (hd_ansicht.gd)
		draw_rect(Rect2(-16, -46, 32, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, -44, 28.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("7fe0ff"))
