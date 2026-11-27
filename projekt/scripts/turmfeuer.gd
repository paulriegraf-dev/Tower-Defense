class_name Turmfeuer
extends Node
## Feuer der Türme (27.11., Knoten-Umbau Schritt 3 – vorher in main.gd): Geschütz, Lanze, Frost, Funk (Optik), Heilturm,
## Truppenturm mit Werkschutz, Magnete und Batterien. Regeln unverändert. Kindknoten von main.gd (`spiel.turmfeuer`),
## main ruft je Takt `tick`, `magnete`, `batterien`. Karte, Effekte, Figuren, Gegner- und Einheitenlisten sind dieselben
## Objekte wie in main (werden dort nie neu zugewiesen); Schadensquelle/Schütze/Herkunft bleiben in main, weil
## Einheiten, Gegner und Schadensliste sie lesen.

const KAMPF := 1   # wie main.gd Phase.KAMPF

var spiel: Node
var karte: Karte
var effekte: Effekte
var figuren: Node2D
var turmbilder: Dictionary
var gegner: Array[Gegner]
var einheiten: Array[Einheit]
var fabriken: Dictionary

var abkling: Dictionary = {}     # Turm-Zelle -> Sekunden bis zum nächsten Schuss (auch PliPlop und Magnete)
var funk_welle: Dictionary = {}  # Funkturm -> Sekunden bis zur nächsten Funkwelle (nur Optik)
var schock_takt: Dictionary = {} # Frost mit Schockfrost: Turm-Zelle -> Sekunden bis zum nächsten Einfrieren
var nachschuss: Dictionary = {}  # Lanze mit Doppelstrahl: Turm-Zelle -> [Sekunden, Strahlende]


func richte_ein(s: Node) -> void:
	spiel = s
	karte = s.karte
	effekte = s.effekte
	figuren = s.figuren
	turmbilder = s.turmbilder
	gegner = s.gegner
	einheiten = s.einheiten
	fabriken = s.fabriken


var werkschutz: Dictionary = {}   # Turm-Zelle -> {"timer", "einheiten" (draußen), "drin", "ruhe", "schuss"}

func _truppenturm_ziel(z: Vector2i) -> Vector2i:
	var weit := float(karte.turm_wert(z, "ausfall_felder", 4.0))
	var bestes := Karte.KEINE
	var beste := INF
	for i in karte.checkpoints.size():
		var c: Vector2i = karte.checkpoints[i]
		var d := Vector2(c - z).length()
		if d > weit or d >= beste:
			continue
		var bedroht: bool = karte.cp_feind[i]
		if not bedroht:
			for g in gegner:
				if is_instance_valid(g) and karte.zelle_bei(g.position) == c:
					bedroht = true
					break
		if bedroht:
			beste = d
			bestes = c
	return bestes


func _truppenturm(z: Vector2i, delta: float) -> void:
	var neu_w := not werkschutz.has(z)
	var w: Dictionary = werkschutz.get(z, {"timer": 0.0, "einheiten": [], "drin": 0, "ruhe": 0.0, "schuss": 0.0})
	if not w.has("drin"):
		w["drin"] = 0
		w["ruhe"] = 0.0
		w["schuss"] = 0.0
	var liste: Array = (w["einheiten"] as Array).filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Node).is_queued_for_deletion() and (e as Einheit).leben > 0.0)
	w["einheiten"] = liste
	werkschutz[z] = w
	var hoechst := int(karte.turm_wert(z, "werkschutz", 2))
	if neu_w:
		w["drin"] = hoechst   # frisch gebaut: voll besetzt
	var drin := mini(int(w["drin"]), hoechst)
	# Nachschub: Gefallene kommen im Turm nach
	if drin + liste.size() >= hoechst:
		w["timer"] = 0.0
	else:
		w["timer"] = float(w["timer"]) + delta * float(karte.turm_wert(z, "nachschub", 1.0))
		if float(w["timer"]) >= Werte.PRODUKTION_SEK:
			w["timer"] = 0.0
			drin += 1
			effekte.flaeche(karte.mitte(z), Werte.ZELLE * 0.5, Color(Werte.TURMARTEN["truppen"]["farbe"]))
	var stufe := 2 if int(karte.turm_stufe.get(z, 1)) >= 2 else 0   # Truppenstufe 2 = Wertepaket
	# Ausfall oder Rückweg
	var cp := _truppenturm_ziel(z)
	if cp != Karte.KEINE:
		w["ruhe"] = 0.0
		var raus := karte.freier_nachbar(z)
		while drin > 0 and raus != Karte.KEINE:
			drin -= 1
			var e := Einheit.new()
			e.wach_turm = z
			e.wach_ziel = cp
			figuren.add_child(e)
			e.start(spiel, karte, "technogunner", z, stufe, "")
			e._schutz_rest = 0.0   # 25.11. (N3): rückt nur aus dem Turm aus, ist nicht frisch produziert
			e.daten["name"] = "Werkschutz"
			e.max_leben *= float(karte.turm_wert(z, "leben_mal", 1.0))
			e.leben = e.max_leben
			e.position = karte.mitte(raus)
			e._punkte.clear()
			effekte.flaeche(e.position, Werte.ZELLE * 0.5, Color(Werte.TURMARTEN["truppen"]["farbe"]))
			einheiten.append(e)
			liste.append(e)
		for e: Einheit in liste:
			e.wach_ziel = cp
			e.wach_heim = false
	elif not liste.is_empty():
		w["ruhe"] = float(w["ruhe"]) + delta
		if float(w["ruhe"]) >= float(karte.turm_wert(z, "ausfall_ruhe", 3.0)):
			var heim := karte.freier_nachbar(z)
			for e: Einheit in liste.duplicate():
				e.wach_heim = true
				e.wach_ziel = heim
				var da := karte.zelle_bei(e.position)
				if heim == Karte.KEINE or da == heim or Vector2(da - z).length() <= 1.5 or float(w["ruhe"]) > 20.0:
					liste.erase(e)
					einheiten.erase(e)
					e.queue_free()
					drin = mini(hoechst, drin + 1)
	w["drin"] = drin
	karte.werkschutz_zahl[z] = drin
	# Die Besatzung schießt aus dem Turm
	if drin <= 0:
		return
	var rest := float(w["schuss"]) - delta * float(spiel.turm_takt(z))
	if rest > 0.0:
		w["schuss"] = rest
		return
	var d: Dictionary = Werte.einheit_daten("technogunner", stufe, "")
	var von := karte.mitte(z) + Vector2(0, -14)
	var weite := float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
	spiel.schadensquelle = "turm:truppen"
	spiel.schuetze = null
	spiel.schadensobjekt = z
	spiel.schuss_herkunft = von
	var ziel: Gegner = spiel.gegner_in_reichweite(von, weite, false, z)
	if ziel == null:
		w["schuss"] = 0.0
		return
	if turmbilder.has(z):
		(turmbilder[z] as TurmBild).feuert(ziel.position)
	Ton.am_ort(spiel, "tc-heavy", von)
	spiel.schuss(von, ziel.position, Color(Werte.TURMARTEN["truppen"]["farbe"]))
	ziel.nimm_schaden(float(d["schaden"]))
	w["schuss"] = float(d["abklingzeit"]) / float(drin * maxi(1, (d.get("schuss_bilder", [0]) as Array).size()))   # jeder Mann schießt für sich: mehr Besatzung = dichteres Feuer


func tick(delta: float) -> void:
	for z: Vector2i in karte.ausbau:
		if not karte.turm_aktiv(z):
			continue   # kein Turm, lahmgelegt oder ohne Stützen
		var art_name: String = karte.turm_art.get(z, "geschuetz")
		if art_name == "funk":
			# schießt nicht selbst (siehe funk_faktor in main.gd) – sendet nur sichtbar Funkwellen
			var fw: float = funk_welle.get(z, 0.0) - delta
			if fw <= 0.0:
				fw = 0.9
				effekte.welle(karte.mitte(z), float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE, Color(Werte.TURMARTEN["funk"]["farbe"]), "funk", 1.5)
			funk_welle[z] = fw
			continue
		if art_name == "heil":
			_heilturm(z, delta)
			continue
		if art_name == "truppen":
			_truppenturm(z, delta)   # 20.11. (Nachtrag) / 21.11.: Besatzung schießt aus dem Turm, Ausfall nur zum Checkpoint
			continue
		if art_name == "pliplop":
			spiel._pliplop_turm(z, delta)   # 20.11. (Paul): PliPlop 3cK (Irrtürmer)
			continue
		var art: Dictionary = Werte.TURMARTEN[art_name]
		spiel.schadensquelle = "turm:" + art_name
		spiel.schuetze = null
		spiel.schadensobjekt = z
		var weite: float = float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
		if spiel.order24 != null:
			weite += spiel.order24.turm_bonus() * Werte.ZELLE   # 20.11. (Paul): Befehl 24 – Brakk auf den Erdwällen wird weiter beschossen
		var farbe := Color(art["farbe"])
		var von := karte.mitte(z) + Vector2(0, -14)
		spiel.schuss_herkunft = von
		var schaden := float(karte.turm_wert(z, "schaden"))
		# Lanze mit Doppelstrahl: der zweite Strahl folgt kurz nach dem ersten auf derselben Linie
		if nachschuss.has(z):
			var n: Array = nachschuss[z]
			n[0] = float(n[0]) - delta
			if float(n[0]) <= 0.0:
				nachschuss.erase(z)
				_lanzenstrahl(von, n[1], farbe, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, schaden)
		# Frost mit Schockfrost: eigener Takt, friert alle Gegner im Umkreis kurz ganz ein
		var schock := float(karte.turm_wert(z, "schock_alle", 0.0))
		if schock > 0.0:
			var t: float = float(schock_takt.get(z, schock)) - delta
			if t <= 0.0:
				var getroffen := false
				for g in gegner:
					if is_instance_valid(g) and not spiel._geschuetzt(g) and von.distance_to(g.position) <= weite and karte.sicht_von_wall(z, von, g.position):
						g.eingefroren = maxf(g.eingefroren, float(karte.turm_wert(z, "schock_sek")))
						getroffen = true
				if getroffen:
					effekte.welle(karte.mitte(z), weite, Color.WHITE, "frost", 0.5)
					t = schock
				else:
					t = 0.25
			schock_takt[z] = t
		var rest: float = abkling.get(z, 0.0) - delta * float(spiel.turm_takt(z))   # 20.11.: Überladen (Irrtürmer)
		if rest <= 0.0:
			var durch: bool = karte.turm_wert(z, "durch_waelle", false)
			var ziel: Gegner = spiel.gegner_in_reichweite(von, weite, false, Karte.KEINE if durch else z)   # Türme folgen derselben Sichtregel wie Stellungen
			if ziel != null:
				rest = float(karte.turm_wert(z, "abklingzeit"))
				match art_name:
					"frost":
						# Frostpuls: alle Gegner in Reichweite und Sicht werden verlangsamt
						effekte.welle(karte.mitte(z), weite, farbe, "frost", 0.8)
						var sproede := float(karte.turm_wert(z, "sproede", 0.0))
						for g in gegner.duplicate():
							if is_instance_valid(g) and not spiel._geschuetzt(g) and von.distance_to(g.position) <= weite and karte.sicht_von_wall(z, von, g.position):
								var sek := float(karte.turm_wert(z, "bremse_sek"))
								var bt := float(karte.turm_wert(z, "bremse_tempo"))   # 19.11.: Stufe 2 bremst stärker
								if g.gefroren <= 0.0:
									spiel.objekt_zaehle(z, "gebremst", 1.0)
									g.frost_tempo = bt
								else:
									g.frost_tempo = minf(g.frost_tempo, bt)
								g.gefroren = maxf(g.gefroren, sek)
								if sproede > 0.0:
									g.sproede = maxf(g.sproede, sek)
								if schaden > 0.0:
									g.nimm_schaden(schaden)
					"lanze" when spiel.brakk_geschosse != null and spiel.brakk_geschosse.ist_brakk(ziel):
						# 20.11.: Schritt 6c – erst Aufglühen, dann der Strahl auf Brakks Stelle von davor
						spiel.brakk_geschosse.turm(z, von, "lanze", schaden, weite, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, int(karte.turm_wert(z, "strahlen", 1)), spiel.schadensquelle)
					"lanze":
						Ton.am_ort(spiel, "tc-arc", von)
						# Strahl in gerader Linie bis zum Ende der Reichweite: trifft alles in der Linie (auch hinter Wällen)
						var ende := von + (ziel.position - von).normalized() * weite
						_lanzenstrahl(von, ende, farbe, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, schaden)
						if int(karte.turm_wert(z, "strahlen", 1)) >= 2:
							nachschuss[z] = [0.35, ende]
					_ when spiel.brakk_geschosse != null and spiel.brakk_geschosse.ist_brakk(ziel):
						spiel.brakk_geschosse.turm(z, von, art_name, schaden, weite, Werte.BRAKK_TURM_BREITE * Werte.ZELLE, 1, spiel.schadensquelle)   # 20.11.: Schritt 6c
					_:
						Ton.am_ort(spiel, "tc-heavy", von)
						_turm_schuss(z, von, ziel.position, farbe)
						ziel.nimm_schaden(schaden)
						if int(karte.turm_wert(z, "ziele", 1)) >= 2:
							# Doppelschuss: der nächste andere Gegner in Reichweite und Sicht
							var zweit: Gegner = null
							var nah := INF
							for g in gegner:
								if is_instance_valid(g) and g != ziel and not spiel._geschuetzt(g) and von.distance_to(g.position) <= weite and von.distance_to(g.position) < nah and karte.sicht_von_wall(z, von, g.position):
									zweit = g
									nah = von.distance_to(g.position)
							if zweit != null:
								_turm_schuss(z, von, zweit.position, farbe, false)
								zweit.nimm_schaden(schaden)
		abkling[z] = rest


## Gefechtsturm (16.11.): dreht sich zum Ziel, das Leuchtgeschoss startet an der Mündung (mit Höhe) und schlägt mit
## einem kleinen Treffer am Ziel ein. Ohne Turmbild (klassische Grafik) wie bisher als Linie.
func _turm_schuss(z: Vector2i, von: Vector2, nach: Vector2, farbe: Color, drehen: bool = true) -> void:
	if not turmbilder.has(z) or not Werte.grafik_neu:
		spiel.schuss(von, nach, farbe)
		return
	var tb := turmbilder[z] as TurmBild
	if drehen:
		tb.feuert(nach)
	var m: Array = tb.muendung()
	var stufe := int(karte.turm_stufe.get(z, 1))
	effekte.leuchtschuss(m[0], m[1], nach, 14.0, Color("7fe0ff"), 0.09 + (m[0] as Vector2).distance_to(nach) / 4200.0, 10.0 + 3.0 * stufe)
	effekte.fx("treffer_c", nach, 0.45 + 0.08 * stufe, nach.x < von.x)


func _lanzenstrahl(von: Vector2, ende: Vector2, farbe: Color, breite: float, schaden: float) -> void:
	spiel.strahl(von, ende, farbe, 6.0)
	var betroffen: Array = []
	for g in gegner:
		if is_instance_valid(g) and not spiel._geschuetzt(g):
			var p := Geometry2D.get_closest_point_to_segment(g.position, von, ende)
			if p.distance_to(g.position) <= breite:
				betroffen.append(g)
	var deckung: Dictionary = spiel.schild_deckung(von, betroffen)   # Schildabfangen: hinter einem Schildträger kommt der Strahl geschwächt an
	for g: Gegner in betroffen:
		if is_instance_valid(g):
			g.nimm_schaden(schaden * float(deckung.get(g, 1.0)))
	# 18.11.: Erfolg „Aufgespießt“ – vier Gegner mit einem Strahl
	var tote := 0
	for g: Gegner in betroffen:
		if is_instance_valid(g) and g._tot:
			tote += 1
	if tote >= 4:
		spiel.erfolg("aufgespiesst")


## Magnete: alle paar Sekunden die Gegner in ihrer Zuglinie heranziehen (höchstens bis vor den Magneten, nicht durch Wälle).



func magnete(delta: float) -> void:
	for z: Vector2i in karte.magnet_richtung:
		if karte.ausbau.get(z, Karte.FREI) != Karte.MAGNET:
			continue
		var rest: float = abkling.get(z, 0.0) - delta
		if rest <= 0.0:
			var r: Vector2i = karte.magnet_richtung[z]
			var linie := karte.magnet_linie(z, r)
			var gezogen := 0
			if not linie.is_empty():
				var vorne := karte.mitte(linie[0])
				var achse := Vector2(r)
				for g in gegner:
					if spiel._geschuetzt(g) or g.rolle == "belagerung" or not linie.has(karte.zelle_bei(g.position)):
						continue
					var ziel: Vector2 = g.position - achse * float(Werte.MAGNET["zug"]) * Werte.ZELLE
					if (ziel - vorne).dot(achse) < 0.0:
						ziel -= achse * (ziel - vorne).dot(achse)   # nicht weiter als bis vor den Magneten
					g.position = ziel
					g.plane_neu()
					gezogen += 1
				if gezogen > 0:
					var von := karte.mitte(z)
					effekte.linie(von, karte.mitte(linie[-1]), Color("ff7a6a"))
					effekte.linie(von + Vector2(-achse.y, achse.x) * 8.0, karte.mitte(linie[-1]) + Vector2(-achse.y, achse.x) * 8.0, Color("7aa8ff"))
			rest = float(Werte.MAGNET["abklingzeit"]) if gezogen > 0 else 0.25
		abkling[z] = rest


## Spiegel: Ziel für eine Bodentruppe, das sie selbst nicht sieht, aber über einen Spiegel trifft.
## Ergebnis: {"ziel": Gegner, "spiegel": Punkt} oder {} – beide Strecken zusammen höchstens `weite`.



func _heilturm(z: Vector2i, delta: float) -> void:
	var art: Dictionary = Werte.TURMARTEN["heil"]
	var instand := float(karte.turm_wert(z, "instand_sek", 0.0))
	if instand > 0.0:
		for t: Vector2i in karte.turm_schaden.keys():
			if karte.turm_lahm(t) and Vector2(t - z).length() <= float(karte.turm_wert(z, "reichweite")):
				spiel._instand_zeit[t] = float(spiel._instand_zeit.get(t, 0.0)) + delta
				if float(spiel._instand_zeit[t]) >= instand:
					spiel.objekt_zaehle(z, "instand", 1.0)
					karte.turm_schaden.erase(t)
					spiel._instand_zeit.erase(t)
					effekte.flaeche(karte.mitte(t), Werte.ZELLE * 0.8, Color(art["farbe"]))
					karte.queue_redraw()
	var rest: float = abkling.get(z, 0.0) - delta * float(spiel.turm_takt(z))   # 20.11.: Überladen (Irrtürmer)
	if rest <= 0.0:
		rest = float(art["abklingzeit"])
		var m := karte.mitte(z)
		var weite := float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
		var heilung := float(karte.turm_wert(z, "heilung"))
		var geheilt := false
		for e in einheiten:
			if is_instance_valid(e) and not e.in_batterie() and e.leben < e.max_leben and m.distance_to(e.position) <= weite:
				var vorher_leben: float = e.leben
				e.leben = minf(e.max_leben, e.leben + heilung)
				spiel.objekt_zaehle(z, "heilung", e.leben - vorher_leben)
				effekte.plus(e.position, Color(art["farbe"]))
				e.queue_redraw()
				geheilt = true
		if geheilt:
			effekte.welle(m, weite, Color(art["farbe"]), "heil", 0.9)
	abkling[z] = rest


## Schildkuppel: Faktor auf den Schaden, den eine eigene Truppe an `punkt` nimmt (1.0 = keine Kuppel).



func batterien(delta: float) -> void:
	spiel.schuss_herkunft = Vector2.INF
	var radius: float = Werte.BATTERIE["flaeche"] * Werte.ZELLE
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.BATTERIE or karte.ausgefallen.has(z):
			continue
		var stufe: int = spiel.batterie_stufe(z)
		var weite: float = spiel.batterie_reichweite(z)
		karte.batterie_stufe_neu[z] = stufe
		if stufe >= 2 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			# Schwere Ladung: nebenbei Rauch in Reichweite wegblasen
			spiel._rauch_abkling[z] = float(spiel._rauch_abkling.get(z, 0.0)) - delta
			if spiel._rauch_abkling[z] <= 0.0:
				var wolke: Variant = effekte.blase_rauch_weg(karte.mitte(z), weite)
				if wolke != null:
					spiel._rauch_abkling[z] = Werte.BATTERIE_RAUCH_SEK
					spiel.schuss(karte.mitte(z) + Vector2(0, -20), wolke, Color("d8f6ff"))
		var rest: float = abkling.get(z, Werte.BATTERIE["abklingzeit"] * 0.5) - delta * float(spiel.turm_takt(z))   # 20.11.: Überladen (Irrtürmer)
		if rest <= 0.0 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			var von := karte.mitte(z) + Vector2(0, -20)
			var bestes: Gegner = null
			var meiste := 0
			# Zielwahl im Batteriemenü (an der Pilotenfabrik): "dichteste" Gruppe (Standard) oder wie bei Truppen Erste/Letzte/Stärkste
			var modus := str(fabriken.get(karte.paar.get(z, z), {}).get("ziel", "dichteste"))
			if modus != "dichteste":
				bestes = spiel.gegner_in_reichweite(von, weite, false, Karte.KEINE, modus)
			for g in (gegner if modus == "dichteste" else []):
				if spiel._geschuetzt(g) or von.distance_to(g.position) > weite:
					continue
				var n := 0
				for h in gegner:
					if g.position.distance_to(h.position) <= radius:
						n += 1
				if g.rolle == "schild":
					n += 1000   # Provokation: ein Schildträger in Reichweite geht vor
				if n > meiste:
					meiste = n
					bestes = g
			if bestes != null:
				rest = Werte.BATTERIE["abklingzeit"]
				karte.batterie_schuss[z] = 0.0
				karte.batterie_blick[z] = bestes.position.x < von.x
				# 16.11.: sichtbarer Bolzen mit Zielkreuz; der Schaden kommt mit dem Einschlag (Effekte.BOLZEN_FLUG)
				effekte.batterie_schuss(von, bestes.position, radius)
				Ton.am_ort(spiel, "tc-arc", von)
				var ziel_punkt := bestes.position
				var schaden := float(Werte.BATTERIE["schaden"]) * (Werte.BATTERIE_ST2_SCHADEN if stufe >= 2 else 1.0)
				get_tree().create_timer(Effekte.BOLZEN_FLUG, false, true).timeout.connect(_batterie_einschlag.bind(z, von, ziel_punkt, radius, schaden))
		abkling[z] = maxf(rest, 0.0) if rest <= 0.0 else rest


func _batterie_einschlag(z: Vector2i, von: Vector2, punkt: Vector2, radius: float, schaden: float) -> void:
	if spiel.phase != KAMPF:
		return
	Ton.am_ort(spiel, "hit-pboom", punkt)
	spiel.schadensquelle = "batterie:%d,%d" % [z.x, z.y]
	spiel.schuetze = null
	spiel.schuss_herkunft = von   # der Frontschild fängt auch die Batterie ab, wenn sie von vorn kommt
	spiel.flaechenschaden(punkt, radius, schaden, Color("7fe0ff"), Werte.BATTERIE_RAND_FAKTOR, false)
	spiel.schuss_herkunft = Vector2.INF


## Schaden an allen Gegnern im Umkreis, mit einem kurzen Ring als Zeichen.
