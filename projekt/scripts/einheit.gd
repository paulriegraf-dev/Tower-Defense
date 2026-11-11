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
var _marschziel := Karte.KEINE     # Feld, zu dem diese Bodentruppe marschiert: verlorener Checkpoint oder HQ
var _versatz := Vector2.ZERO       # damit Truppen nicht exakt aufeinander stehen
var _sprite: Figur
var _treffer := 0.0


func start(p_spiel: Node, p_karte: Karte, typ: String, p_fabrik: Vector2i) -> void:
	spiel = p_spiel
	karte = p_karte
	daten = Werte.EINHEITEN[typ]
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
		(karte.besatzung[posten_zelle] as Array).append(self)
	else:
		bisher = karte.posten.get(posten_zelle)
		karte.posten[posten_zelle] = self
	var weg: Array[Vector2i] = fund["weg"]
	for i in weg.size():
		# letzter Punkt = oben in der Stellung bzw. mitten in der Batterie, ohne Versatz
		var oben := Vector2.ZERO if zur_batterie else Vector2(0, -12)
		_punkte.append(karte.mitte(weg[i]) + (_versatz if i < weg.size() - 1 else oben))
	if bisher != null and bisher != self:
		bisher.verdraengt()


## Ist diese Einheit noch zu ihrer Stellung unterwegs und hat dabei mehr als `felder` Felder vor sich?
func unterwegs_weiter_als(felder: int) -> bool:
	return zustand == Zustand.ZUM_POSTEN and _punkte.size() > felder


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
			if _gehe(delta):
				if karte.inhalt(posten_zelle) == Karte.BATTERIE:
					zustand = Zustand.IN_BATTERIE
					_sprite.visible = false
				else:
					zustand = Zustand.AUF_POSTEN
		Zustand.IN_BATTERIE:
			pass   # die Batterie feuert (siehe main.gd)
		Zustand.AUF_POSTEN:
			# Von oben: mehr Reichweite, Wälle versperren die Sicht nicht.
			var weite: float = (daten["reichweite"] + Werte.POSTEN_REICHWEITE_BONUS) * Werte.ZELLE
			_sprite.bewegt(false)
			var oben_ziel: Node2D = spiel.gegner_in_reichweite(position, weite, false)
			if oben_ziel == null:
				oben_ziel = spiel.zonenbau_in_reichweite(position, weite, false)
			_feuere_auf(oben_ziel)
		Zustand.BODEN:
			if not karte.ist_frei(karte.zelle_bei(position)):
				_gehe(delta)   # noch in der Fabrik: erst heraustreten, dann kämpfen
				return
			# Nachrücken: Ist eine Stellung frei geworden (oder näher als für den, der dorthin unterwegs ist)?
			_posten_check -= delta
			if _posten_check <= 0.0:
				_posten_check = 1.0
				if not karte.finde_posten(karte.zelle_bei(position), self).is_empty():
					_marschziel = Karte.KEINE
					_suche_posten()
					return
			# Ziel wählen: ein verlorener Checkpoint geht vor, in der letzten Runde dann das HQ, sonst dem Gegner entgegen.
			_plan_in -= delta
			if _plan_in <= 0.0:
				_plan_in = 0.3
				var hier := karte.zelle_bei(position)
				_marschziel = karte.naechster_feind_checkpoint(hier)
				if _marschziel == Karte.KEINE and spiel.im_endkampf():
					# Letzte Runde: zum gegnerischen HQ – sofern es einen Fußweg gibt
					if hier == Werte.ANGRIFFS_ZELLE or not karte.einheiten_weg(hier, Werte.ANGRIFFS_ZELLE).is_empty():
						_marschziel = Werte.ANGRIFFS_ZELLE
				if _marschziel != Karte.KEINE:
					_plane_zur_zelle(_marschziel)
				else:
					var naechster: Gegner = spiel.naechster_gegner(position)
					if naechster != null:
						_plane_zur_zelle(karte.zelle_bei(naechster.position))
			var weite: float = daten["reichweite"] * Werte.ZELLE
			var ziel: Node2D = spiel.gegner_in_reichweite(position, weite, true)
			if ziel == null:
				ziel = spiel.zonenbau_in_reichweite(position, weite, true)
			if ziel != null and _marschziel == Karte.KEINE:
				# normaler Kampf: stehen bleiben und schießen
				_sprite.bewegt(false)
				_feuere_auf(ziel)
				return
			# Auf dem Marsch (Checkpoint, HQ) wird im Laufen geschossen, nicht angehalten.
			_gehe(delta)
			_feuere_auf(ziel)


## `ziel` ist ein Gegner oder (in der letzten Runde) ein Gebäude in der Zone.
func _feuere_auf(ziel: Node2D) -> void:
	if ziel == null or spiel.im_rauch(position):
		return   # im Rauch sieht die Einheit nichts
	_sprite.flip_h = ziel.position.x < position.x
	if _abkling > 0.0:
		return
	_abkling = daten["abklingzeit"]
	_sprite.angriff(daten["abklingzeit"])
	if daten.has("flaeche") and ziel is Gegner:
		# Flächenschaden: trifft alle Gegner rund um das Ziel
		spiel.schuss(position + Vector2(0, -10), ziel.position, Color(daten["schussfarbe"]))
		spiel.flaechenschaden(ziel.position, daten["flaeche"] * Werte.ZELLE, daten["schaden"], Color(daten["schussfarbe"]))
		return
	var muendung := position + Vector2(18 * (-1 if _sprite.flip_h else 1), -10)
	spiel.schuss(muendung, ziel.position + Vector2(0, 4), Color(daten["schussfarbe"]))
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


func _plane_zur_zelle(ziel: Vector2i) -> void:
	var hier := karte.zelle_bei(position)
	var weg := karte.einheiten_weg(hier, ziel)
	_punkte.clear()
	# Das erste Feld ist das eigene – außer die Einheit steckt noch in der Fabrik.
	for i in range(1 if karte.ist_frei(hier) else 0, weg.size()):
		_punkte.append(karte.mitte(weg[i]) + _versatz)


## Der Wall unter der Einheit wurde eingerissen: sie kämpft am Boden weiter.
func posten_verloren() -> void:
	posten_zelle = Karte.KEINE
	zustand = Zustand.BODEN
	_sprite.visible = true
	_punkte.clear()
	_plan_in = 0.0
	_marschziel = Karte.KEINE


func nimm_schaden(menge: float) -> void:
	leben -= menge
	_treffer = 0.08
	queue_redraw()
	if leben <= 0.0:
		spiel.einheit_gefallen(self)


## Reichweite in Feldern, so wie sie gerade gilt (in der Stellung mit Bonus).
func reichweite_jetzt() -> float:
	return daten["reichweite"] + (Werte.POSTEN_REICHWEITE_BONUS if zustand == Zustand.AUF_POSTEN else 0.0)


func _draw() -> void:
	if ausgewaehlt and zustand != Zustand.IN_BATTERIE:
		var r := reichweite_jetzt() * Werte.ZELLE
		draw_circle(Vector2.ZERO, r, Color(0.5, 0.88, 1.0, 0.08))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.5, 0.88, 1.0, 0.8), 2.0)
	if leben < max_leben:
		draw_rect(Rect2(-16, -46, 32, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, -44, 28.0 * clampf(leben / max_leben, 0.0, 1.0), 2), Color("7fe0ff"))
