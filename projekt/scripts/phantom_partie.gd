class_name PhantomPartie
extends Node
## Phantom-Modus einer Partie (27.11., Knoten-Umbau Schritt 1 – vorher ein Block in main.gd):
## Verteidigung gegen ein Angriffs-Phantom, Angriff auf ein Verteidigungs-Phantom, Ersatz-Phantome,
## Zwischenwertung „Geknackt“ und das Schlussbild des Angriffs.
## Die Spielregeln sind unverändert; der Code greift über `spiel` auf main.gd zu (wie Laufband, Hud, Tutorial).
## Kindknoten von main.gd (`spiel.phantom_partie`). Der Bau eines Stands (`_setze_stand`) bleibt in main.gd,
## weil ihn auch Szenario-Editor, Order 24 und der Zwischenstand nutzen.

const BAU := 0      # wie main.gd Phase.BAU / KAMPF / ENDE
const ENDE := 2

var spiel: Node

var angriff_phantom: Dictionary = {}   # Verteidigung: die 20 Wellen eines anderen Spielers
var phantom: Dictionary = {}           # das geladene Verteidigungs-Phantom
var plaene: Dictionary = {}            # Angriff: Runde -> Trupps im Format von Werte.WELLEN
var angriff_log: Array = []            # Angriff: je Runde, was der Plan gekostet und gebracht hat
var phantom_pfad := ""                 # Angriff: Datei des Phantoms, gegen das es gerade geht
var ersatz: Array = []                 # Angriff: Dateien weiterer Phantome, die übernehmen, wenn die Verteidigung fällt
var geknackt := 0                      # Angriff: so viele Verteidigungen sind schon gefallen
var aktiv_pfad := ""                   # Angriff: Datei der Verteidigung, die gerade steht (auch ein Ersatz-Phantom)
var angriff_pfad := ""                 # Verteidigung: Datei des Angriffs-Phantoms, gegen das es geht
var angriff_fertig := false            # 19.11. (Paul): Angriff gewertet oder aufgegeben – nichts mehr buchen
var funk: Funkfenster                  # 23.11.: Sonde 7 führt beim ersten Angriff durch den Taktikplaner


## Normales Spiel, aber die Wellen kommen von einem Angriffs-Phantom (alle Runden aus einer Hand).
## Runden, für die das Phantom keinen Plan hat, laufen mit der entworfenen Welle.
func starte_verteidigung(pfad: String) -> bool:
	angriff_phantom = Phantom.lade(pfad)
	if angriff_phantom.is_empty():
		spiel.melde("Dieses Phantom lässt sich nicht laden.", 5.0)
		return false
	spiel.phantom_modus = "verteidigung"
	angriff_pfad = pfad
	spiel._gegner_name = str(angriff_phantom.get("spieler", ""))   # 25.11.: für „Revanche gegen …“
	Werte.setze_anfuehrer("brakk")   # 19.11.: gegen Angriffs-Phantome vorerst immer mit Brakk
	spiel._normales_spiel()
	spiel._protokoll["gegen_angriff"] = pfad.get_file()
	var wer := str(angriff_phantom.get("spieler", "einem Phantom"))
	var ab := Phantom.start_runde(angriff_phantom)   # 25.11.: neue Angriffe beginnen in Runde 8
	if ab > 1:
		spiel.melde(tr("Du verteidigst gegen den Angriff von %s. Runden 1–%d sind Standardwellen, ab Runde %d greift das Phantom an – seine Welle steht dann oben in der Ansage.") % [wer, ab - 1, ab], 9.0)
	else:
		spiel.melde("Du verteidigst gegen den Angriff von %s. Seine Welle steht jede Runde oben in der Ansage." % wer, 8.0)
	return true


## Verteidigung: Überschrift des Bands zu Beginn von Runde `nr` ("" = keins). 25.11. (Paul): nur noch in der ersten
## Phantom-Runde, danach zeigt das HUD das Portrait. (Ersatz-Phantome beim Angriff haben ihr eigenes Band.)
func banner(nr: int) -> String:
	var ab := Phantom.start_runde(angriff_phantom)
	if spiel.phantom_modus != "verteidigung" or nr != ab or trupps(nr).is_empty():
		return ""
	var wer := str(angriff_phantom.get("spieler", "EIN SPIELER")).to_upper()
	if ab > 1:
		return tr("AB JETZT: ANGRIFF VON %s") % wer   # nach den Standardwellen
	return "DIESE WELLE HAT %s GEPLANT" % wer


## 25.11.: Für das HUD – wer steht gegenüber? {"name", "portrait"}, {} = niemand (kein Phantom-Lauf, oder noch Standardwellen).
func gegner_portrait() -> Dictionary:
	var wer: Dictionary = {}
	if spiel.phantom_modus == "angriff":
		wer = phantom
	elif spiel.phantom_modus == "verteidigung" and spiel.welle >= Phantom.start_runde(angriff_phantom):
		wer = angriff_phantom
	if wer.is_empty():
		return {}
	return {"name": str(wer.get("spieler", "Phantom")), "portrait": Profil.portrait_gueltig(wer.get("portrait", 0))}


## Verteidigung: die Trupps, die das Angriffs-Phantom in Runde `nr` schickt (leer = es hat dafür keinen Plan).
func trupps(nr: int) -> Array:
	for r: Dictionary in angriff_phantom.get("runden", []):
		if int(r.get("runde", 0)) == nr:
			return r.get("trupps", [])
	return []


## Seitenwechsel: Der aufgezeichnete Bau eines Spielers verteidigt, du planst die Wellen auf dem Laufband.
func starte_angriff(pfad: String) -> bool:
	phantom = Phantom.lade(pfad)
	if phantom.is_empty():
		spiel.melde("Dieses Phantom lässt sich nicht laden.", 5.0)
		return false
	spiel.phantom_modus = "angriff"
	spiel.protokoll_an = false
	plaene = {}
	angriff_log = []
	phantom_pfad = pfad
	geknackt = 0
	spiel.nebel.vergiss()
	ersatz = []
	aktiv_pfad = pfad
	if not Online.ersatz_pfade.is_empty():
		ersatz = Online.ersatz_pfade.duplicate()   # 18.11.: online gezogen (das Startmenü hat sie schon geladen)
		Online.ersatz_pfade = []
	else:
		var pool := Phantom.liste("verteidigung")
		Zufall.mische(pool)   # Ersatz-Phantome zufällig aus dem Pool
		for f: Dictionary in pool:
			if str(f["pfad"]).get_file() != pfad.get_file() and ersatz.size() < 2:
				ersatz.append(f["pfad"])
	spiel._gegner_name = str(phantom.get("spieler", ""))   # 25.11.: für „Revanche gegen …“
	Werte.setze_anfuehrer(str(phantom.get("anfuehrer", "brakk")))   # 19.11.: das Phantom verteidigt mit den Regeln seines Anführers
	spiel.leben = Werte.start_leben()
	spiel.setze_checkpoints(phantom["karte"]["checkpoints"])
	spiel._setze_runde(mini(Phantom.ANGRIFF_AB_RUNDE, maxi(runden(), 1)))   # 25.11. (Paul): ab Runde 8, mit dem Bau von dann
	spiel.nebel.frei_runde = spiel.welle   # 25.11.: „die Verteidigung steht dann schon“ – die erste Runde ohne Nebel, wie beim Ersatz-Phantom
	lade_stand()
	zeige_laufband()
	_taktik_fuehrung.call_deferred()   # 23.11.: erster Angriff – Sonde 7 führt durch die erste Runde
	spiel.melde("Angriff auf %s ab Runde %d: Plane jede Runde eine Welle im Taktikplaner. Ziel: die %d Leben der Verteidigung." % [str(phantom.get("spieler", "ein Phantom")), spiel.welle, spiel.leben], 8.0)
	return true


## 23.11. (Phantom-Einführung D): Beim allerersten Angriff führt Sonde 7 durch die erste Runde im Taktikplaner:
## Vorlage/Einheiten aufs Band, Kärtchen anfassen, Budget, Welle starten. Kein Zwang – „Weiter“ geht immer, „Später“ schließt.
func _taktik_fuehrung() -> void:
	if spiel.phantom_modus != "angriff" or bool(Profil.einstellung("pe_taktik", false)) or spiel.tutorial != null:
		return
	Profil.setze_einstellung("pe_taktik", true)
	var lb: Laufband = spiel._laufband
	var hud = spiel._hud
	funk = Funkfenster.zeige(spiel, [
		{"text": "Du planst jetzt die Welle gegen diesen fremden Bau. „Vorlage“ füllt dir eine Runde vor – klick darauf.",
			"ziel": func() -> Rect2: return lb.knopf_bildschirm("Vorlage") if lb.visible else Rect2(),
			"fertig": func() -> bool: return not lb.plan.is_empty(),
			"hinweis": "Oder zieh selbst Einheiten aus der Leiste aufs Band."},
		{"text": "Jedes Kärtchen ist ein Trupp. Schieb es für Reihenfolge und Pausen, klick es an für Ausgang und Start.",
			"ziel": func() -> Rect2: return lb.bildschirm(Laufband.RAHMEN_R) if lb.visible else Rect2()},
		{"text": "Unten steht dein Budget für diese Runde – mehr Einheiten kosten mehr. Jede Runde planst du neu.",
			"ziel": func() -> Rect2: return lb.bildschirm(Laufband.KONSOLE_R) if lb.visible else Rect2()},
		{"text": "Bereit? Starte die Welle mit dem Emblem unten rechts oder [Leertaste]. Dein Ergebnis zählt für deine Elo.",
			"ziel": func() -> Rect2: return (hud.start.get_global_transform() * Rect2(Vector2.ZERO, hud.start.size)) if hud != null and hud.start != null else Rect2(),
			"fertig": func() -> bool: return spiel.phase != BAU},
	], "TAKTIKPLANER")


## Angriff: so viele Runden hat das Verteidigungs-Phantom aufgezeichnet.
func runden() -> int:
	return (phantom.get("runden", []) as Array).size()


## Stellt den Bau des Phantoms für die laufende Runde hin – jede Runde frisch, ohne Schäden aus der Runde davor.
func lade_stand() -> void:
	var liste: Array = phantom["runden"]
	if spiel.welle > liste.size():
		return
	var stand: Dictionary = liste[spiel.welle - 1]["stand"]
	spiel._setze_stand(stand)


## Züge, die der Verteidiger damals mitten in der Runde gemacht hat, gelten ab Rundenbeginn.
func zuege_in_runde() -> void:
	var liste: Array = phantom["runden"]
	if spiel.welle > liste.size():
		return
	var karte: Karte = spiel.karte
	var fabriken: Dictionary = spiel.fabriken
	for a: Dictionary in liste[spiel.welle - 1].get("in_runde", []):
		var z := Vector2i(int(a["x"]), int(a["y"]))
		if a["a"] == "bau" and a.get("typ", "") == "stellung":
			if karte.inhalt(z) == Karte.WALL and not karte.ausbau.has(z):
				karte.baue_aus(z, Karte.STELLUNG)
		elif a["a"] == "einheit" and fabriken.has(z) and int(fabriken[z].get("stufe", 0)) == 0 and not karte.paar.has(z):
			fabriken[z]["typ"] = str(a["typ"])
			karte.fabrik_typ[z] = str(a["typ"])


func zeige_laufband() -> void:
	if not plaene.has(spiel.welle):
		plaene[spiel.welle] = []
	spiel._laufband.visible = true
	spiel._laufband.zeige(plaene[spiel.welle])


## Angriff: Runde vorbei. Festhalten, was sie gebracht hat; die nächste Runde beginnt mit frischem Bau und leerem Band.
func runde_fertig(ist_geknackt: bool = false) -> void:
	var welle: int = spiel.welle
	var genommen: int = spiel._leben_vor_runde - spiel.leben
	angriff_log.append({
		"runde": welle,
		"gegen_pfad": aktiv_pfad,
		"staerke": snappedf(_staerke_jetzt(), 0.01),   # 19.11.: Gegnerstärke für die Wertung
		"geknackt": ist_geknackt,
		"trupps": (plaene.get(welle, []) as Array).duplicate(true),
		"punkte": Phantom.plan_preis(plaene.get(welle, [])),
		"budget": Phantom.budget(welle),
		"leben_genommen": genommen,
		"checkpoints_genommen": spiel._cp_verloren,
		"durchgaenge": spiel._durchgang,
		"sekunden": snappedf(spiel._kampf_sek, 0.1),
		"hq_sekunden": snappedf(hq_sekunden(), 0.1),
	})
	spiel.melde("Runde %d: %d Leben genommen, die Verteidigung hat noch %d." % [welle, genommen, spiel.leben], 5.0)


## 25.11.: So lange hält dein HQ in der letzten Runde schon dem Sturm stand (die Abwehrwelle davor zählt nicht).
func hq_sekunden() -> float:
	return spiel._kampf_sek - spiel._push_ab if spiel.endkampf and spiel._push_ab >= 0.0 else 0.0


## Angriff: Die Verteidigung hat ihr letztes Leben verloren. Steht ein Ersatz-Phantom bereit, übernimmt es ab der
## nächsten Runde mit vollen Leben und eigener Karte; sonst (oder in der letzten Runde) ist der Angriff gewonnen.
func gefallen() -> void:
	var neu := {}
	if not spiel.endkampf and spiel.welle < Werte.LETZTE_RUNDE:
		# 19.11. (Paul): Der Angriff läuft immer bis Runde 20 – fällt eine Verteidigung, übernimmt die nächste.
		# Erst die mitgebrachten (online gezogenen) Ersatz-Phantome, dann der eingebaute Pool; wer schon dran war,
		# kommt erst wieder, wenn alle einmal dran waren.
		for versuch in 2:
			if ersatz.is_empty():
				_ersatz_nachfuellen(versuch == 1)
			while not ersatz.is_empty() and neu.is_empty():
				var kpfad: String = ersatz.pop_front()
				var kandidat := Phantom.lade(kpfad)
				if (kandidat.get("runden", []) as Array).size() > spiel.welle:
					neu = kandidat
					neu["_pfad"] = kpfad
			if not neu.is_empty():
				break
	if neu.is_empty():
		runde_fertig(true)
		angriff_ende("durchbruch", true)
		return
	runde_fertig(true)
	_zeige_geknackt(neu)


## 19.11.: Ersatz aus dem eingebauten Pool – zuerst die, die in diesem Angriff noch nicht dran waren
## (`wiederholen` = auch die schon geknackten, nur nicht die aktuelle).
func _ersatz_nachfuellen(wiederholen: bool) -> void:
	var dran := {}
	for e: Dictionary in angriff_log:
		dran[str(e.get("gegen_pfad", "")).get_file()] = true
	dran[aktiv_pfad.get_file()] = true
	var pool := Phantom.liste("verteidigung")
	Zufall.mische(pool)
	for f: Dictionary in pool:
		var datei := str(f["pfad"]).get_file()
		if datei == aktiv_pfad.get_file():
			continue
		if wiederholen or not dran.has(datei):
			ersatz.append(f["pfad"])


## Stärke der gerade stehenden Verteidigung für die Wertung (aus ihrem Elo online; offline ×1).
func _staerke_jetzt() -> float:
	var id := Online.id_von(aktiv_pfad)
	if id == "":
		return 1.0
	for e: Dictionary in Online.listen["verteidigung"]:
		if str(e["id"]) == id:
			return Phantom.staerke(float(e.get("elo", 1000.0)))
	return 1.0


## 19.11. (Paul): Angriff mittendrin aufgegeben (Knopf nach dem Knacken, Neustart oder Hauptmenü): keine Wertung,
## nichts wird gespeichert oder hochgeladen – die Verteidigung, die gerade steht, bekommt den Sieg (Elo).
func aufgeben() -> void:
	if spiel.phantom_modus != "angriff" or angriff_fertig:
		return
	angriff_fertig = true
	var vid := Online.id_von(aktiv_pfad)
	if vid != "" and Online.aktiv():
		Online.angriff_abgebrochen(vid)   # 23.11.: zählt auch für die Spieler-Elo; 24.11. (72): als ein Lauf


## Angriff: Eine Verteidigung ist gefallen und ein Ersatz-Phantom steht bereit. Zwischenwertung zeigen (15.11.):
## Weiterspielen gegen das Ersatz-Phantom – oder hier aufhören und die Wertung sichern.
func _zeige_geknackt(neu: Dictionary) -> void:
	spiel.phase = ENDE
	spiel._laufband.visible = false
	var probe: Array = angriff_log.duplicate(true)
	var wertung := Phantom.wertung(probe)
	# 18.11.: Endtafel statt Textzeilen
	var genommen := 0
	for e: Dictionary in probe:
		genommen += int(e["leben_genommen"])
	var gegner_name := str(neu.get("spieler", "das Ersatz-Phantom"))
	spiel._zeige_tafel({
		"kicker": "PHANTOM-ANGRIFF  ·  RUNDE %d" % spiel.welle, "titel": "GEKNACKT!", "titel_farbe": spiel._F_KUPFER_HELL, "rahmen": spiel._F_KUPFER_HELL,
		"untertitel": "Die Verteidigung von %s ist gefallen." % str(phantom.get("spieler", "?")), "effekt": "kupfer", "wackeln": true,
		"kacheln": [
			{"name": "ZWISCHENSTAND", "zahl": int(wertung["gesamt"]), "farbe": spiel._F_GOLD},
			{"name": "LEBEN GENOMMEN", "zahl": genommen, "farbe": spiel._F_ROT, "symbol": "herz"},
			{"name": "GEKNACKT", "zahl": geknackt + 1, "farbe": spiel._F_KUPFER}],
		"kaesten": [{"titel": "NÄCHSTER GEGNER: %s" % gegner_name.to_upper(), "farbe": spiel._F_KUPFER_HELL,
			"text": "Neue Karte, volle %d Leben, eine Runde ohne Nebel. Der Angriff geht bis Runde %d – Punkte zählen nach der Stärke der Verteidigung. Aufgeben bringt keine Wertung." % [Werte.START_LEBEN, Werte.LETZTE_RUNDE]}],
		"zeilen": ["  ·  ".join(wertung["zeilen"])],
		"knoepfe": [
			["Weiter gegen %s" % gegner_name, func():
				spiel._tafel.visible = false
				_ersatz_uebernimmt(neu), spiel._F_KUPFER_HELL],
			["Aufgeben · keine Wertung", func():
				spiel._tafel.visible = false
				aktiv_pfad = str(neu.get("_pfad", ""))   # die nächste Verteidigung stand bereit – sie bekommt den Sieg
				aufgeben()
				spiel._zum_menue(), spiel._F_TEXT]],
	})


func _ersatz_uebernimmt(neu: Dictionary) -> void:
	geknackt += 1
	spiel.nebel.vergiss()
	spiel.nebel.frei_runde = spiel.welle + 1   # das neue Phantom zeigt sich eine Runde lang ohne Nebel
	for g in spiel.gegner:
		g.queue_free()
	spiel.gegner.clear()
	spiel._schlange = []
	spiel._pausen = []
	spiel._ausgaenge = []
	spiel._locker = []
	spiel._wurf_schlange = []
	spiel._wurf_aktiv = []
	spiel._im_flug = 0
	phantom = neu
	aktiv_pfad = str(neu.get("_pfad", ""))
	phantom.erase("_pfad")
	Werte.setze_anfuehrer(str(phantom.get("anfuehrer", "brakk")))   # 19.11.: Ersatz-Phantom mit seinem Anführer
	spiel.leben = Werte.start_leben()
	spiel.setze_checkpoints(phantom["karte"]["checkpoints"])
	var b: Array = phantom["karte"].get("basis", [Werte.BASIS_ZELLE.x, Werte.BASIS_ZELLE.y])
	spiel.setze_basis(Vector2i(int(b[0]), int(b[1])))
	for i in spiel.karte.cp_feind.size():
		spiel.karte.cp_feind[i] = false
	spiel._naechste_bauphase()
	lade_stand()
	zeige_laufband()
	spiel._einblendung.banner("NEUER GEGNER", "%s übernimmt – volle %d Leben." % [str(phantom.get("spieler", "?")), spiel.leben], spiel._F_KUPFER_HELL)   # 18.11.
	spiel.melde("Verteidigung geknackt! Ein Ersatz-Phantom (%s) übernimmt ab Runde %d – neue Karte, volle %d Leben." % [str(phantom.get("spieler", "?")), spiel.welle, spiel.leben], 10.0)


## Angriff: Schlussbild mit Wertung; der Angriff wird als Angriffs-Phantom gespeichert.
func angriff_ende(grund: String, runde_gebucht: bool = false) -> void:
	if not runde_gebucht:
		runde_fertig()
	var welle: int = spiel.welle
	var endkampf: bool = spiel.endkampf
	spiel.phase = ENDE
	spiel._laufband.visible = false
	var genommen := 0
	var punkte := 0
	for e: Dictionary in angriff_log:
		punkte += int(e["punkte"])
		genommen += int(e["leben_genommen"])
	var wertung := Phantom.wertung(angriff_log)
	angriff_fertig = true
	# 19.11. (Paul): Nur vollständige Angriffe (bis Runde 20) zählen für Rangliste, Profil und Online-Pool.
	var vollstaendig := welle >= Werte.LETZTE_RUNDE
	var daten := {
		"format": 1, "art": "angriff", "spieler": Profil.name(), "profil": Profil.id(), "begonnen": Time.get_datetime_string_from_system(),
		"gegen": str(phantom.get("quelle", "")),
		"portrait": Profil.portrait(),   # 25.11.
		"start_runde": int(angriff_log[0]["runde"]) if not angriff_log.is_empty() else welle,   # 25.11.: erste Runde dieses Angriffs
		"ergebnis": {"ausgang": grund, "runde": welle, "leben_genommen": genommen, "punkte": punkte, "geknackt": geknackt + (1 if grund == "durchbruch" else 0),
			"durchgaenge_runde_20": spiel._durchgang if endkampf else 0, "wertung": wertung["gesamt"]},
		"runden": angriff_log,
	}
	var pfad := Phantom.speichere("angriff", daten) if vollstaendig else ""
	if vollstaendig:
		spiel._merke_export(daten, "angriff")
		Profil.angriff_ende(int(wertung["gesamt"]), geknackt + (1 if grund == "durchbruch" else 0))
	if geknackt + (1 if grund == "durchbruch" else 0) > 0:
		spiel.erfolg("einbrecher")   # 18.11.
	if pfad != "":
		spiel._angriff_online.call_deferred(pfad, daten, int(wertung["gesamt"]))
	# 18.11.: Endtafel statt Textzeilen
	var geknackt_gesamt := geknackt + (1 if grund == "durchbruch" else 0)
	var titel := "DURCHBRUCH!"
	var farbe: Color = spiel._F_KUPFER_HELL
	var unter := "Die Verteidigung ist in Runde %d gefallen." % welle if geknackt_gesamt <= 1 else "%d Verteidigungen geknackt, die letzte in Runde %d." % [geknackt_gesamt, welle]
	if grund == "hq":
		titel = "HQ GEFALLEN"
		farbe = spiel._F_ROT
		unter = "Das Phantom hat den Gegenangriff gewonnen – aber jede Sekunde zählt."
	elif grund == "patt":
		titel = tr("RUNDE 20 GEHALTEN")
		farbe = spiel._F_GOLD
		unter = tr("%d Sekunden lang hat sich nichts mehr bewegt.") % int(Phantom.PATT_SEK)
	elif grund != "durchbruch":
		titel = "ANGRIFF BEENDET"
		farbe = spiel._F_GOLD
		unter = "Das Phantom hat keine weiteren Runden."
	var zeilen: Array = ["  ·  ".join(wertung["zeilen"])]
	if endkampf:
		zeilen.append("Runde 20: %d Durchgänge, %d Sekunden" % [spiel._durchgang, int(hq_sekunden())])
	if grund == "patt":
		zeilen.push_front(tr("Patt – Verteidigung hat gehalten"))
	if not vollstaendig:
		zeilen.append("Kein Ersatz-Phantom mehr da – der Angriff endet vor Runde %d und zählt nicht für die Rangliste." % Werte.LETZTE_RUNDE)
	elif pfad == "":
		zeilen.append("(Speichern hat nicht geklappt.)")
	var tafel_conf := {
		"kicker": "PHANTOM-ANGRIFF  ·  GEGEN %s" % str(phantom.get("spieler", "?")).to_upper(), "titel": titel, "titel_farbe": farbe, "rahmen": farbe,
		"untertitel": unter, "effekt": "kupfer" if grund != "hq" else "asche", "glitch": grund == "hq",
		"kacheln": [
			{"name": "PUNKTE", "zahl": int(wertung["gesamt"]), "farbe": spiel._F_GOLD},
			{"name": "LEBEN GENOMMEN", "zahl": genommen, "farbe": spiel._F_ROT, "symbol": "herz"},
			{"name": "GEKNACKT", "zahl": geknackt_gesamt, "farbe": spiel._F_KUPFER},
			{"name": "BUDGET", "zahl": punkte, "farbe": spiel._F_TEXT, "symbol": "muenze"}],
		"kaesten": [spiel._protokoll_kasten("DEIN ANGRIFF IST JETZT EIN PHANTOM", "Andere Spieler verteidigen ab jetzt gegen deine Wellen.")] if pfad != "" else [],
		"zeilen": zeilen,
		"knoepfe": spiel._revanche_knoepfe(spiel._F_KUPFER_HELL),
	}
	if pfad != "":
		var elo: Dictionary = spiel._elo_platz("angriff")   # 23.11. (Einführung F): Elo-Änderung zählt auf der Tafel
		if not elo.is_empty():
			tafel_conf["elo"] = elo
	spiel._zeige_tafel(tafel_conf)
