class_name WurfSchleuder
extends Node
## Wurf-Schleuder der Myriaden (27.11., Knoten-Umbau Paket C – vorher in main.gd): Trupps zu vier fliegen über die
## Mauer, landen gemeinsam und stürmen den nächsten freien Checkpoint; im Phantom-Angriff wählt der Spieler das
## Landefeld. Regeln unverändert. Kindknoten von main.gd (`spiel.wurf_schleuder`). Die Wurf-Warteschlange der Welle
## (`_wurf_schlange`, `_wurf_aktiv`, `_im_flug`) bleibt in main, weil Wellenstart, Phantom-Partie und Tests sie nutzen;
## main leitet wurf_standorte und waehle_wurfziel (Laufband) hierher weiter.

var spiel: Node
var karte: Karte
var effekte: Effekte
var gegner: Array[Gegner]


func richte_ein(s: Node) -> void:
	spiel = s
	karte = s.karte
	effekte = s.effekte
	gegner = s.gegner


var takt := 0.0     # Sekunden bis zum nächsten Geworfenen
var bau: Zonenbau   # die Schleuder, die gerade wirft
var landung := Karte.KEINE
var sturm_ziel := 0 # Checkpoint, den die Geworfenen stürmen
var flug_rudel: Array = []   # der Trupp, der gerade geworfen wird


## Phantom-Modus: Der Plan enthält einen Wurf, aber die Wurf-Schleuder steht noch nicht (vor Runde 10) – dann kommt sie jetzt.
func sorge_fuer_schleuder() -> void:
	for b in spiel.zonenbauten:
		if b.art == "wurf":
			return
	for nr in Werte.ZONENBAUTEN.size():
		var s: Dictionary = Werte.ZONENBAUTEN[nr]
		if s["art"] == "wurf" and not spiel._zone_gebaut.has(nr):
			spiel._zone_gebaut[nr] = true
			spiel._neuer_zonenbau("wurf", s["zelle"])
			return


## Felder, von denen aus geworfen wird: die Wurf-Schleudern, die stehen – sonst der Platz, an dem die erste entsteht.
func standorte() -> Array:
	var felder: Array = []
	for b in spiel.zonenbauten:
		if b.art == "wurf":
			felder.append(b.zelle)
	if felder.is_empty():
		for s: Dictionary in Werte.ZONENBAUTEN:
			if s["art"] == "wurf":
				felder.append(s["zelle"])
				break
	return felder


## Angriff: Der nächste Linksklick auf die Karte setzt das Landefeld dieses Wurf-Trupps.
func waehle_ziel(trupp: Dictionary) -> void:
	if spiel.szenario_editor != null:
		spiel.melde("Im Szenario sucht die Wurf-Schleuder ihr Ziel selbst.", 4.0)   # 18.11.
		return
	spiel._wurfziel_fuer = trupp
	spiel._laufband.visible = false
	spiel.melde("Wurfziel: Klick auf ein freies Feld im orangen Kreis. Rechtsklick oder [Esc] bricht ab.", 8.0)


func setze_ziel(z: Vector2i) -> void:
	var nah := false
	for s: Vector2i in standorte():
		if Vector2(z - s).length() <= float(Werte.WURF["weit"]):
			nah = true
	# Im Nebel verrät das Ziel nichts: Steht dort etwas, landen die Geworfenen daneben.
	if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or karte.ist_basis(z) or (spiel.nebel.offen(z) and not karte.ist_frei(z)):
		spiel.melde("Dort kann nichts landen: Das Feld muss frei sein und außerhalb deiner Zone liegen.", 4.0)
		return
	if not nah:
		spiel.melde("Zu weit: Die Wurf-Schleuder reicht nur bis zum orangen Kreis.", 4.0)
		return
	spiel._wurfziel_fuer["ziel"] = [z.x, z.y]
	spiel._wurfziel_fuer.erase("wenn")
	beende_ziel()


func beende_ziel() -> void:
	spiel._wurfziel_fuer = {}
	spiel._laufband.visible = true
	spiel._laufband._neu()


## Wurf-Schleuder: Trupps zu vier fliegen über die Mauer. Die nächste bereite Schleuder wirft den nächsten Trupp;
## alle vier landen an derselben Stelle und bleiben als Trupp zusammen.
func tick(delta: float) -> void:
	var schleudern: Array = []
	for b in spiel.zonenbauten:
		if b.art == "wurf":
			schleudern.append(b)
	if schleudern.is_empty():
		# keine Wurf-Schleuder (mehr): die restlichen Wurf-Trupps laufen zu Fuß
		for eintrag: Dictionary in spiel._wurf_schlange:
			spiel._schlange.append(eintrag["typen"])
			spiel._pausen.append(0.0)
		spiel._wurf_schlange = []
		if not spiel._wurf_aktiv.is_empty():
			spiel._schlange.append(spiel._wurf_aktiv)
			spiel._pausen.append(0.0)
			spiel._wurf_aktiv = []
		return
	if spiel._wurf_aktiv.is_empty():
		if spiel._wurf_schlange.is_empty():
			return
		# Würfe, die auf einen Belagerungsturm warten, obwohl keiner mehr kommt: normal werfen
		var turm_kommt := false
		for typen: Array in spiel._schlange:
			if typen.has("belagerung"):
				turm_kommt = true
		for g in gegner:
			if g.rolle == "belagerung" and not g.vorstoss:   # 25.11. (N6): wer vorrückt, dockt nicht mehr an
				turm_kommt = true
		# der nächste Wurf, der dran ist: sein Auslöser ist erfüllt und genug Lauf-Trupps sind unterwegs
		var dran := -1
		for i in spiel._wurf_schlange.size():
			var e: Dictionary = spiel._wurf_schlange[i]
			if e["wenn"] != "" and not turm_kommt:
				e["wenn"] = ""
			if e["wenn"] == "" and (int(e["nach"]) <= spiel._trupp_nr or spiel._schlange.is_empty()) and spiel._kampf_sek - spiel._durchgang_sek >= float(e.get("zeit", 0.0)):
				dran = i
				break
		if dran < 0:
			return
		var eilt: bool = spiel._wurf_schlange[dran].get("eilt", false)
		if not eilt and not spiel._welle.get("wurf_frei", false) and spiel._kampf_sek < float(Werte.WURF["wartet"]) and not spiel.endkampf:
			return   # sie hält sich zurück, bis die eigenen Truppen vorgerückt sind
		bau = null
		for b: Zonenbau in schleudern:
			if b.wurfbereit() or (eilt and bau == null):
				bau = b
				if b.wurfbereit():
					break
		if bau == null:
			return
		var eintrag: Dictionary = spiel._wurf_schlange[dran]
		var ziel := {}
		if eintrag.has("ziel"):
			# Der Angreifer hat das Feld gewählt; steht dort inzwischen etwas, landen sie daneben.
			var gewollt := Vector2i(int(eintrag["ziel"][0]), int(eintrag["ziel"][1]))
			var feld := gewollt if karte.ist_frei(gewollt) else karte.freier_nachbar(gewollt)
			if feld != Karte.KEINE:
				ziel = {"z": feld, "mauer": 0.0}
		elif eintrag.has("nahe"):
			var feld := karte.freies_feld_nahe(eintrag["nahe"])
			if feld != Karte.KEINE:
				ziel = {"z": feld, "mauer": 0.0}
		elif eintrag.has("meiden"):
			ziel = karte.wurf_landefeld(bau.zelle, eintrag["meiden"], Werte.WURF_BELAGERUNG_ABSTAND)
		if ziel.is_empty():
			ziel = karte.wurf_landefeld(bau.zelle)
		if ziel.is_empty():
			return
		landung = ziel["z"]
		# Geworfene stürmen den nächsten Checkpoint, den der Gegner noch nicht hält – nicht die Basis.
		sturm_ziel = karte.sturmziel_ab(landung)
		bau.hat_geworfen()
		spiel._wurf_schlange.remove_at(dran)
		spiel._wurf_aktiv = eintrag["typen"]
		if OS.get_environment("TD_WURF_LOG") != "":
			print("WURF R%d t=%.1f  %s -> %s  %s  %s" % [spiel.welle, spiel._kampf_sek, bau.zelle, landung, spiel._wurf_aktiv, "nahe Turm" if eintrag.has("nahe") else ("Zange" if eintrag.has("meiden") else "")])
		flug_rudel = []
		takt = 0.0
		var dauer: float = Werte.WURF["flugzeit"] + Werte.WURF["abstand"] * spiel._wurf_aktiv.size() + 0.5
		effekte.warnung(karte.mitte(landung), dauer)
	if not is_instance_valid(bau):
		spiel._schlange.append(spiel._wurf_aktiv)   # Schleuder mitten im Wurf zerstört: der Rest läuft
		spiel._pausen.append(0.0)
		spiel._wurf_aktiv = []
		return
	takt -= delta
	if takt > 0.0:
		return
	takt = Werte.WURF["abstand"]
	var typ: String = spiel._wurf_aktiv.pop_front()
	spiel._im_flug += 1
	bau.ruck()
	Ton.am_ort(spiel, "myr-launch", bau.position)
	effekte.wurf(bau.position + Vector2(0, -30), karte.mitte(landung), Werte.WURF["flugzeit"], _landet.bind(landung, sturm_ziel, flug_rudel, typ), "einheit", typ)


func loese_aus(wenn: String, zusatz: Dictionary) -> void:
	for i in spiel._wurf_schlange.size():
		var e: Dictionary = spiel._wurf_schlange[i]
		if e["wenn"] == wenn:
			e["wenn"] = ""
			e["nach"] = 0
			e["eilt"] = true
			e.merge(zusatz)
			spiel._wurf_schlange.remove_at(i)
			spiel._wurf_schlange.push_front(e)
			return


func _landet(zelle: Vector2i, erstes_ziel: int, rudel: Array, typ: String = "hund") -> void:
	Ton.am_ort(spiel, "hit-thud", karte.mitte(zelle))
	spiel._im_flug -= 1
	# Wurde inzwischen dort gebaut? Dann daneben landen.
	var feld := zelle if karte.ist_frei(zelle) else karte.freier_nachbar(zelle)
	if feld != Karte.KEINE:
		var g: Gegner = spiel._neuer_gegner(typ, feld, erstes_ziel)
		g.geworfen = true
		g.aufrappeln()   # 16.11.: landet geduckt und richtet sich auf
		if OS.get_environment("TD_WURF_LOG") != "":
			print("LANDUNG R%d t=%.1f  %s auf %s, Ziel: %s" % [spiel.welle, spiel._kampf_sek, typ, feld, "Basis" if erstes_ziel >= karte.checkpoints.size() else "Checkpoint %d" % (erstes_ziel + 1)])
		g.trupp = rudel
		rudel.append(g)
