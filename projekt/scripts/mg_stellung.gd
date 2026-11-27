class_name MgStellung
extends Node
## MG-Stellung (20.11. Paul, Sonde 7; 27.11. Knoten-Umbau Paket B – vorher in main.gd): Das Nest schießt mit seinen
## eigenen Werten (Werte.MG_NEST, MG_AUSBAU, MG_SONDER); die Truppe darin ist nur Besatzung. Leuchtspur, Ladeschuss,
## Hülsenregen, Railgun, Sperrfeuer, Splittergurt, Ausbau. Regeln unverändert. Kindknoten von main.gd
## (`spiel.mg_stellung`); main leitet mg_werte, mg_reichweite, mg_feuer, mg_huelsen_punkte hierher weiter
## (die rufen Einheit, Fabrikmenü und Effekte auf).

var spiel: Node
var karte: Karte
var effekte: Effekte
var gegner: Array[Gegner]


func richte_ein(s: Node) -> void:
	spiel = s
	karte = s.karte
	effekte = s.effekte
	gegner = s.gegner


var schuesse: Dictionary = {}        # Nest -> Schusszähler (Leuchtspur)
var ladung: Dictionary = {}          # Nest -> Spielzeit des letzten Ladeschusses
var huelsen: Array = []   # [Position, Restzeit, Nest] – Hülsenregen


func werte(z: Vector2i) -> Dictionary:
	var wahl: Array = karte.mg_wahl.get(z, [])
	return Werte.mg_werte(int(karte.mg_stufe.get(z, 0)), wahl)


func reichweite(z: Vector2i) -> float:
	var w := werte(z)
	return maxf(0.5, float(w["reichweite"]) + (Werte.WACHPOSTEN_BONUS if karte.ist_wachposten(z) else 0.0) + karte.anhoehe_bonus(z) + Werte.mod("truppen_reichweite"))


## Kühlkreislauf: MG-Nester in der Nähe eines Nests mit Kühlkreislauf feuern schneller (Faktor ≥ 1).
func _takt(z: Vector2i) -> float:
	var f := 1.0
	var s: Dictionary = Werte.MG_SONDER["takt+lafette"]["kuehlkreislauf"]
	for n: Vector2i in karte.mg_stufe:
		if n == z or int(karte.mg_stufe[n]) < 3 or karte.ausbau.get(n, Karte.FREI) != Karte.STELLUNG:
			continue
		var w: Array = karte.mg_wahl.get(n, [])
		if w.size() < 3 or str(w[2]) != "kuehlkreislauf" or Vector2(n - z).length() > 1.5:
			continue
		var bonus := float(s["nachbar"]) * (float(s["funk"]) if spiel.funk_faktor(n) < 1.0 else 1.0)
		f = maxf(f, 1.0 + bonus)
	return f


## Ein Schuss des MG-Nests auf `z` mit der Truppe `e` als Besatzung. Rückgabe: Pause bis zum nächsten Schuss (0 = kein Schuss).
func feuer(e: Einheit, ziel: Node2D, z: Vector2i) -> float:
	if not is_instance_valid(ziel):
		return 0.0
	var w := werte(z)
	var sonder := str(w["sonder"])
	var s: Dictionary = w["s"]
	var g_ziel: Gegner = ziel as Gegner
	if spiel.im_rauch(e.position) and sonder != "ausguck" and not spiel.peilung(z) and not (g_ziel != null and g_ziel.markiert > 0.0):
		return 0.0   # im Rauch sieht das Nest nichts – außer mit Ausguck oder Peilsender
	var pause := float(w["abklingzeit"]) / _takt(z) * float(spiel.funk_faktor(z))
	if e.sturm_bis > 0.0:
		pause *= float(Werte.KOMMANDANT["sturm_feuer"])
	var farbe := Color(Werte.MG_NEST["farbe"])
	var von := e.position + Vector2(14 * (-1 if ziel.position.x < e.position.x else 1), -10)
	spiel.schadensquelle = "fabrik:%d,%d" % [e.fabrik_zelle.x, e.fabrik_zelle.y]
	spiel.schuetze = e
	spiel.schuss_herkunft = e.position
	var schaden := float(w["schaden"]) * Werte.mod_faktor("truppen_schaden")
	Ton.am_ort(spiel, Ton.fuer_truppe(e.daten), e.position)
	if spiel.brakk_geschosse != null and spiel.brakk_geschosse.ist_brakk(ziel):
		spiel.brakk_geschosse.schiesse("laser", von, 0.45, schaden, "technogunner", spiel.schadensquelle)
		return pause
	if g_ziel == null:
		spiel.schuss(von, ziel.position, farbe)
		ziel.call("nimm_schaden", schaden)
		return pause
	if sonder == "ausguck" and BrakkFortschritt.gross(g_ziel):
		schaden *= float(s["gross"])
	# Railgun-Lauf: durch alle in einer Linie, einmal an einem Erdwall abgeprallt
	if sonder == "railgun":
		_railgun(z, von, g_ziel.position, reichweite(z) * Werte.ZELLE, schaden, farbe, float(s["breite"]) * Werte.ZELLE)
		return pause
	spiel.schuss(von, g_ziel.position + Vector2(0, 4), farbe)
	var vorher := g_ziel.leben
	g_ziel.nimm_schaden(schaden)
	spiel.objekt_zaehle(z, "schaden", minf(schaden, maxf(0.0, vorher)))
	var ort := g_ziel.position
	var getoetet := g_ziel._tot or g_ziel.leben <= 0.0
	if getoetet:
		spiel.objekt_zaehle(z, "kills", 1.0)
	# Streuung: Splitter an alle rund ums Ziel
	var splitter := float(w["splitter"]) * Werte.ZELLE
	if splitter > 0.0:
		for g in gegner.duplicate():
			if not is_instance_valid(g) or g == g_ziel or spiel._geschuetzt(g) or g.position.distance_to(ort) > splitter:
				continue
			g.nimm_schaden(schaden * float(w["splitter_anteil"]))
			if sonder == "sperrfeuer":
				g.frost_tempo = minf(g.frost_tempo, float(s["bremse_tempo"])) if g.gefroren > 0.0 else float(s["bremse_tempo"])
				g.gefroren = maxf(g.gefroren, float(s["bremse_sek"]))
	if sonder == "sperrfeuer" and not getoetet and is_instance_valid(g_ziel):
		g_ziel.frost_tempo = minf(g_ziel.frost_tempo, float(s["bremse_tempo"])) if g_ziel.gefroren > 0.0 else float(s["bremse_tempo"])
		g_ziel.gefroren = maxf(g_ziel.gefroren, float(s["bremse_sek"]))
	match sonder:
		"huelsenregen":
			var eigene := huelsen.filter(func(h: Array) -> bool: return h[2] == z).size()
			if Zufall.f() < float(s["chance"]) and eigene < int(s["hoechst"]):
				var p := ort + Vector2(Zufall.von_bis(-0.25, 0.25), Zufall.von_bis(-0.2, 0.2)) * Werte.ZELLE
				huelsen.append([p, float(s["sek"]), z])
				effekte.flaeche(p, Werte.ZELLE * 0.18, Color("ffd34d"))
		"leuchtspur":
			var n := int(schuesse.get(z, 0)) + 1
			schuesse[z] = n
			if n % int(s["jeder"]) == 0 and not getoetet and is_instance_valid(g_ziel):
				spiel.strahl(von, ort, Color(1.0, 0.85, 0.3), 2.0)
				g_ziel.markiert = Werte.MARKIERUNG_SEK
				g_ziel.markier_faktor = Werte.MARKIERUNG_FAKTOR
				g_ziel.markiert_brakk = false
		"splittergurt":
			if getoetet:
				spiel.flaechenschaden(ort, float(s["radius"]) * Werte.ZELLE, schaden * float(s["anteil"]), farbe)
		"ladeschuss":
			if spiel.spielzeit() - float(ladung.get(z, -100.0)) >= float(s["sek"]):
				var dicht := _dichteste(e.position, reichweite(z) * Werte.ZELLE, float(s["radius"]) * Werte.ZELLE)
				if dicht != null:
					ladung[z] = spiel.spielzeit()
					var punkt := dicht.position
					effekte.batterie_schuss(von, punkt, float(s["radius"]) * Werte.ZELLE)
					get_tree().create_timer(Effekte.BOLZEN_FLUG, false, true).timeout.connect(
						func() -> void: spiel.flaechenschaden(punkt, float(s["radius"]) * Werte.ZELLE, schaden * float(s["mal"]), Color("9be37b")))
	return pause


## Mitte der dichtesten Gegnergruppe in Reichweite (ohne Sichtprüfung: der Mörser geht über die Mauer).
func _dichteste(von: Vector2, weite: float, radius: float) -> Gegner:
	var bestes: Gegner = null
	var meiste := 0
	for g in gegner:
		if spiel._geschuetzt(g) or von.distance_to(g.position) > weite:
			continue
		var n := 0
		for h in gegner:
			if g.position.distance_to(h.position) <= radius:
				n += 1
		if n > meiste:
			meiste = n
			bestes = g
	return bestes


## Railgun-Lauf: gerade Linie bis zur Reichweite; trifft sie vorher einen Erdwall (nicht den eigenen), prallt sie einmal ab.
func _railgun(z: Vector2i, von: Vector2, ziel: Vector2, weite: float, schaden: float, farbe: Color, breite: float) -> void:
	var richtung := (ziel - von).normalized()
	var start := von
	var rest := weite
	var getroffen: Array = []
	for abschnitt in 2:
		var ende := start + richtung * rest
		var schritt := 4.0
		var s := 0.0
		var prall := false
		var alt_zelle := karte.zelle_bei(start)
		while s < rest:
			s = minf(rest, s + schritt)
			var p := start + richtung * s
			var zelle := karte.zelle_bei(p)
			if zelle != alt_zelle and zelle != z and karte.inhalt(zelle) == Karte.WALL and s > Werte.ZELLE * 0.6:
				ende = p - richtung * schritt
				var d := zelle - alt_zelle
				if d.x != 0:
					richtung.x = -richtung.x
				if d.y != 0:
					richtung.y = -richtung.y
				prall = abschnitt == 0
				break
			alt_zelle = zelle
		spiel.strahl(start, ende, farbe, 3.0)
		for g in gegner.duplicate():
			if not is_instance_valid(g) or spiel._geschuetzt(g) or getroffen.has(g):
				continue
			var nah := Geometry2D.get_closest_point_to_segment(g.position, start, ende)
			if nah.distance_to(g.position) <= breite:
				getroffen.append(g)
				var vorher: float = g.leben
				g.nimm_schaden(schaden)
				spiel.objekt_zaehle(z, "schaden", minf(schaden, maxf(0.0, vorher)))
				if g._tot:
					spiel.objekt_zaehle(z, "kills", 1.0)
		rest -= start.distance_to(ende)
		start = ende
		if not prall or rest <= Werte.ZELLE * 0.3:
			break


## Hülsenregen: wer über liegende Hülsen läuft, rutscht aus (einmal je Hülse).
func huelsen_wirken(delta: float) -> void:
	if huelsen.is_empty():
		return
	var s: Dictionary = Werte.MG_SONDER["takt+streuung"]["huelsenregen"]
	var weg: Array = []
	for h: Array in huelsen:
		h[1] = float(h[1]) - delta
		if float(h[1]) <= 0.0:
			weg.append(h)
			continue
		for g in gegner:
			if is_instance_valid(g) and not g._tot and g.eingefroren <= 0.0 and g.position.distance_to(h[0]) <= Werte.ZELLE * 0.22 \
					and not bool(g.daten.get("flug", false)) and not BrakkFortschritt.gross(g):
				g.eingefroren = float(s["stolpern"])
				weg.append(h)
				effekte.fx("treffer_c", h[0], 0.35, false)
				break
	for h: Array in weg:
		huelsen.erase(h)


## Die Hülsen liegen als kleine goldene Punkte am Boden (in der Karte gezeichnet).
func huelsen_punkte() -> Array:
	var aus: Array = []
	for h: Array in huelsen:
		aus.append(h[0])
	return aus


## MG-Nest ausbauen: Stufe 1 und 2 je eine von zwei Richtungen, Stufe 3 eine Sonderform.
func werte_auf(z: Vector2i, wahl: String) -> bool:
	if not spiel.ausbau_moeglich() or not Werte.mg_stellung() or karte.ausbau.get(z, Karte.FREI) != Karte.STELLUNG:
		return false
	wahl = wahl.get_slice("|", wahl.get_slice_count("|") - 1)   # Protokoll/Replay: die ganze Kette, gültig ist die letzte Wahl
	var stufe := int(karte.mg_stufe.get(z, 0))
	if stufe >= 3:
		return false
	var alt: Array = karte.mg_wahl.get(z, [])
	var moeglich: Dictionary = Werte.MG_AUSBAU[stufe] if stufe < 2 else Werte.mg_sonder_wahl(alt)
	if not moeglich.has(wahl):
		return false
	var preis: int = Werte.KOSTEN_MG_STUFE[stufe]
	if spiel.budget < preis:
		spiel.melde("Nicht genug Budget.")
		return false
	spiel._merke_bezahlt(z, "stufen", preis)
	spiel.budget -= preis
	var neu: Array = alt.duplicate()
	neu.append(wahl)
	karte.mg_wahl[z] = neu
	karte.mg_stufe[z] = stufe + 1
	# Im Protokoll wie ein Turm-Upgrade: Stufe + 1 und die Wahlen als Kette (so liest es auch Phantom._stand)
	spiel._notiere({"a": "upgrade", "x": z.x, "y": z.y, "stufe": stufe + 2, "faehigkeit": "|".join(PackedStringArray(neu))})
	Auftraege.zaehle(spiel.auftrag, "upgrade")
	spiel.melde("MG-Stellung Stufe %d – %s: %s" % [stufe + 1, moeglich[wahl]["name"], moeglich[wahl]["text"]], 5.0)
	karte.queue_redraw()
	return true
