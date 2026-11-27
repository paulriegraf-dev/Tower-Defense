class_name BrakkBossarena
extends Node
## G2 (27.11., Paul): Befehl 24 – Bossarena, ein Testmodus nur für Paul (Entwicklercode „bossarena“ oder „allesfrei“).
## Im Brakk-Modus-Menü steht dann „Bossarena“: Boss, Brakks Stufe, Ringpaket, Sprengladungen und Phase-2-Start wählen,
## dann direkt ins Duell – ohne den 15-Minuten-Lauf.
##  - Start: große Karte (Befehl 24), Brakk im Niemandsland; keine Fabriken, Türme, Wellen und kein Fahrplan
##    (Order24 baut nur die Wälle, siehe REGELN und Order24._arena_karte).
##  - Der Kampfplatz läuft wie im Lauf (Ansage ANSAGE_SEK statt 10 s, Wälle fallen, der Boss kommt herein, Lichtwand,
##    Erscheinungsmusik), das Duell auch – mit Vergeltung, Bergung und Ring.
##  - Danach die Tafel „Nochmal / Anderer Boss / Zurück“ mit der Zählung des Herausforderers (NemesisHerausforderer.zaehlung).
##  - [R] gehalten (NEUSTART_HALTEN s) startet dasselbe Setup sofort neu – kurz gedrückt bleibt [R] Brakks Ulti.
##  - H-10: [F2] im Duell öffnet die Werte-Tafel (brakk_bosswerte.gd).
##  - nemesis.json wird weder gelesen noch geschrieben, das Partieprotokoll bleibt aus, Erfolge gibt es keine
##    (die Verrat-Sequenz entfällt). Der Boss ist ein frischer Benannter Rang 3 mit zufälligem Namen bzw. Sonde 7.

const BOSSE: Array[String] = ["scharfschuetze", "technogunner", "plasmawerfer", "sonde", "zufall"]
const BOSS_TEXT := {"scharfschuetze": "Scharfschütze", "technogunner": "Technogunner", "plasmawerfer": "Plasmawerfer", "sonde": "Sonde 7", "zufall": "zufällig"}
const STUFEN: Array[int] = [4, 6, 8, 10]
const PAKETE: Array[String] = ["keins", "standard", "frei"]
const PAKET_TEXT := {"keins": "keins", "standard": "Standard", "frei": "frei"}
const STANDARD_RINGE := {"durchschuss": 2, "minigun": 2, "bollwerk": 1}   # Durchschlag 2 + Wirbel 2 + Wall 1
const ANSAGE_SEK := 3.0                 # Ansage bis zum Auftritt (im Lauf HERAUSFORDERER_ANSAGE_SEK)
const PHASE2_ANTEIL := 0.49             # Phase-2-Start: so viel Leben hat der Boss zu Beginn
const NEUSTART_HALTEN := 0.8            # [R] so lange halten = Neustart
const BERGUNG_MAX := 25.0               # nach dem Duell höchstens so lange auf Bergung und Abbau des Platzes warten
## Regelpaket für Order24 (über das der Karte gelegt): nur die Wälle der großen Karte, nichts läuft von selbst.
const REGELN := {"gebiete": true, "fabriken_innen": 0, "geheim_ab": 0, "welle_takt": 9999, "elite_jede": 0, "flucht_sek": 0,
	"jagd_start": 99999, "vorstoss": false, "herausforderer": false, "lager_neu_ab": 99999, "tore_ab": 99999, "ueberleben_sek": 0}

static var laeuft := false              # true: der nächste Start von Befehl 24 ist die Bossarena
static var wahl := {"boss": "scharfschuetze", "stufe": 6, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
	"ladungen": 1, "phase2": false, "klon": false}
static var menue_seite := ""            # „Anderer Boss“: das Startmenü öffnet gleich diese Seite
static var letzte := {}                 # Zählung des letzten Duells (Prüfung)

var o24: Order24
var spiel: Node
var h: NemesisHerausforderer
var schritt := "warten"                 # "warten" → "angesagt" → "duell" → "bergung" → "tafel"
var boss := ""                          # die gezogene Art ("sonde" für Sonde 7)
var _t := 0.0
var _r_halten := 0.0
var _ebene: CanvasLayer = null
var _tafel: EndTafel = null
var werte_tafel: BrakkBosswerte = null   # H-10: [F2] Werte-Tafel


## Im Menü sichtbar? Nur mit Entwicklercode.
static func frei() -> bool:
	return Profil.hat_code("bossarena") or Profil.hat_code("allesfrei")


## H-10: Ist die Werte-Tafel offen? (Brakk nimmt dann keine Eingaben)
func werte_offen() -> bool:
	return werte_tafel != null and werte_tafel.offen


## Läuft gerade (bzw. startet gleich) die Bossarena?
static func aktiv() -> bool:
	return laeuft


## Die gewählten Ringe als [Ring, Stufe].
static func ringe_der_wahl() -> Array:
	var aus: Array = []
	match str(wahl["ringe"]):
		"standard":
			for r: String in STANDARD_RINGE:
				aus.append([r, int(STANDARD_RINGE[r])])
		"frei":
			for paar: Array in wahl["frei"]:
				if BrakkFortschritt.RINGE.has(str(paar[0])) and not aus.any(func(x: Array) -> bool: return x[0] == paar[0]):
					aus.append([str(paar[0]), clampi(int(paar[1]), 1, 3)])
	return aus


## Die Einträge der Startmenü-Seite „bossarena“ ([Text, Callable, Beschreibung, Farbe]). `neu_malen` baut die Seite neu
## (nach jedem Umschalten), `los` startet, `zurueck` geht eine Seite zurück.
static func menue(neu_malen: Callable, los: Callable, zurueck: Callable) -> Array:
	const TEXT := Color("e6e0d2")
	const BLASS := Color("8d8698")
	var schalte := func(feld: String, liste: Array) -> void:
		wahl[feld] = liste[(liste.find(wahl.get(feld, liste[0])) + 1) % liste.size()]
		neu_malen.call()
	var aus: Array = [
		[_tx("Duell starten"), los, _tx("Große Karte, Niemandsland, nur der Kampfplatz – kein Lauf, nichts wird gespeichert."), Color("7fe0ff")],
		[_tx("Boss") + ": " + str(BOSS_TEXT[wahl["boss"]]), schalte.bind("boss", BOSSE), _tx("Frischer Benannter Rang 3 mit zufälligem Namen – oder Sonde 7."), TEXT],
		[_tx("Brakks Stufe") + ": %d" % int(wahl["stufe"]), schalte.bind("stufe", STUFEN), "", TEXT],
		[_tx("Ringe") + ": " + str(PAKET_TEXT[wahl["ringe"]]), schalte.bind("ringe", PAKETE),
			", ".join(PackedStringArray(ringe_der_wahl().map(func(x: Array) -> String: return ring_text(str(x[0]), int(x[1]))))) if str(wahl["ringe"]) != "keins" else _tx("ohne Ringe"), TEXT],
	]
	if str(wahl["ringe"]) == "frei":
		var namen: Array = BrakkFortschritt.RINGE.keys()
		for i in 3:
			var paar: Array = wahl["frei"][i]
			var ring_weiter := func() -> void:
				paar[0] = namen[(namen.find(paar[0]) + 1) % namen.size()]
				neu_malen.call()
			var stufe_weiter := func() -> void:
				paar[1] = int(paar[1]) % 3 + 1
				neu_malen.call()
			aus.append(["  " + _tx("Ring %d") % (i + 1) + ": " + ring_text(str(paar[0]), int(paar[1])), ring_weiter, _tx("Klick: nächster Ring"), TEXT])
			aus.append(["  " + _tx("Stufe Ring %d") % (i + 1) + ": %d" % int(paar[1]), stufe_weiter, "", TEXT])
	aus.append([_tx("Sprengladungen") + ": %d" % int(wahl["ladungen"]), schalte.bind("ladungen", [0, 1, 2, 3]), "", TEXT])
	aus.append([_tx("Phase-2-Start") + ": " + (_tx("an") if bool(wahl["phase2"]) else _tx("aus")), schalte.bind("phase2", [false, true]), _tx("an: der Boss beginnt mit 49 % Leben"), TEXT])
	aus.append([_tx("Klon erzwingen") + ": " + (_tx("an") if bool(wahl.get("klon", false)) else _tx("aus")), schalte.bind("klon", [false, true]), _tx("an: die Klonmaschine kommt sicher (sonst 25 % je Duell, nicht bei Sonde 7)"), TEXT])   # H-8
	aus.append([_tx("Zurück"), zurueck, "", BLASS])
	return aus


## Kurzer Text eines Rings mit Stufe, z. B. „Wirbel 2“.
static func ring_text(ring: String, stufe: int) -> String:
	return "%s %d" % [str((BrakkFortschritt.RINGE.get(ring, {}) as Dictionary).get("name", ring)).trim_suffix("ring"), stufe]


func einrichten(p_o24: Order24) -> void:
	o24 = p_o24
	spiel = o24.spiel
	h = o24.herausforderer
	process_mode = Node.PROCESS_MODE_ALWAYS
	o24.nemesis.nur_arena = true   # 27.11. (Paul): „nicht den Hangar verdrängen“ – beim Verlassen ist `laeuft` schon aus, speichern() schrieb sonst nur den Arena-Boss
	BrakkBosswerte.laden()   # H-10: Order24.einrichten setzte alles auf Standard – jetzt die Änderungen der Arena
	werte_tafel = BrakkBosswerte.new(self)
	add_child(werte_tafel)


func _process(delta: float) -> void:
	if o24 == null or schritt == "tafel":
		return
	var echt := delta / maxf(Engine.time_scale, 0.01)
	if get_tree().paused:
		return
	_r_pruefen(echt)
	if not o24.laeuft:
		var tafel: Variant = spiel.ego.anzeige.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false   # keine Einsatz-Tafel – gleich los
		return
	match schritt:
		"warten":
			_aufstellen()
			schritt = "angesagt"
		"angesagt":
			if h.zustand == "duell" and h.einheit != null and is_instance_valid(h.einheit):
				if bool(wahl["phase2"]):
					h.einheit.leben = h.einheit.max_leben * PHASE2_ANTEIL   # ab dem nächsten Schritt Phase 2
				schritt = "duell"
		"bergung":
			_t += echt
			if h.kampfplatz.zustand == "aus" or _t >= BERGUNG_MAX:
				_tafel_zeigen()


## [R] halten: dasselbe Setup sofort neu.
func _r_pruefen(echt: float) -> void:
	if schritt in ["angesagt", "duell", "bergung"] and Input.is_physical_key_pressed(KEY_R):
		_r_halten += echt
		if _r_halten >= NEUSTART_HALTEN:
			if h.zustand == "duell":
				h.zaehlung["ausgang"] = "neustart"
			neu_starten()
	else:
		_r_halten = 0.0


## Brakk, Ringe und Ladungen wie gewählt, Brakk ins Niemandsland, der Boss in ANSAGE_SEK s.
func _aufstellen() -> void:
	var k: Kommandant = spiel.kommandant
	var f: BrakkFortschritt = k.fortschritt
	var ringe: Array = []
	var stufen := {}
	for paar: Array in ringe_der_wahl():
		ringe.append(paar[0])
		stufen[paar[0]] = paar[1]
	if f != null:
		f.lade({"stufe": int(wahl["stufe"]), "ringe": ringe, "ring_stufen": stufen}, k)
		f.stufen_fest = true
	o24.ladungen = int(wahl["ladungen"])
	o24._terminal_erklaert = true   # 27.11. (Paul): keine Fluchtsperre – Q, E und R gehen sofort (sonst erst nach dem Myriaden-HQ)
	var nl := BrakkGebiete.rechteck("niemandsland")
	var z := o24._freies_feld_bei(o24.karte.mitte(nl.get_center()), nl.get_center())
	if spiel.ego != null:
		spiel.ego.hoehe = 0.0
		spiel.ego._setze_fuss(o24.karte.mitte(z))
	else:
		k.position = o24.karte.mitte(z)
	k.anker = k.position
	k.leben = k.max_leben
	boss = str(wahl["boss"])
	if boss == "zufall":
		boss = BOSSE.slice(0, 4).pick_random()
	var nem := o24.nemesis
	nem.personen = []
	h.arena_person = Nemesis.sonde_person() if boss == "sonde" else nem.neue_person(boss, 3, nem._eigenname(), "")
	h.ansage_sek = ANSAGE_SEK
	h.zeiten = [o24.zeit + ANSAGE_SEK]
	h.naechste = 0
	spiel.protokoll_an = false
	print("BOSSARENA Start: %s · Stufe %d · Ringe %s · Ladungen %d · Phase 2 %s" % [boss, int(wahl["stufe"]), str(ringe_der_wahl()), o24.ladungen, str(wahl["phase2"])])


## NemesisHerausforderer.ende: das Duell ist vorbei. Nach dem Sieg Brakks warten Bergung und Abbau, sonst gleich die Tafel.
func duell_ende(wie: String) -> void:
	if schritt != "duell" and schritt != "angesagt":
		return
	letzte = h.zaehlung.duplicate(true)
	print("BOSSARENA Ende: %s %s" % [wie, str(letzte)])
	if wie == "vertrieben":
		schritt = "bergung"
		_t = 0.0
	else:
		_tafel_zeigen()


## Order24._ende: Brakk ist gefallen (stand der Boss noch, endete das Duell davor mit „gesiegt“).
func brakk_gefallen() -> void:
	if schritt != "tafel":
		_tafel_zeigen()


func _tafel_zeigen() -> void:
	if schritt == "tafel":
		return
	if werte_offen():
		werte_tafel.umschalten()
	schritt = "tafel"
	if letzte.is_empty():
		letzte = h.zaehlung.duplicate(true)
	_ebene = CanvasLayer.new()
	_ebene.layer = 90
	_ebene.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ebene)
	_tafel = EndTafel.new()
	_tafel.process_mode = Node.PROCESS_MODE_ALWAYS
	_ebene.add_child(_tafel)
	_tafel.zeige(tafel_inhalt(letzte, boss))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


## Inhalt der Ergebnistafel aus einer Zählung (auch für den Test).
func tafel_inhalt(z: Dictionary, art: String) -> Dictionary:
	var ausgang := str(z.get("ausgang", "gesiegt"))
	var vertrieben := ausgang == "vertrieben"
	var k: Kommandant = spiel.kommandant
	var max_leben := k.max_leben if k != null else 1.0
	var angriffe: Dictionary = z.get("angriffe", {})
	var summe := 0
	var teile := PackedStringArray()
	for a: String in angriffe:
		summe += int(angriffe[a])
		teile.append("%s %d" % [a, int(angriffe[a])])
	var treffer: Dictionary = z.get("treffer", {})
	var tt := PackedStringArray()
	for a: String in treffer:
		var e: Dictionary = treffer[a]
		tt.append("%s %d× (%d %%)" % [tr(str(ART_TEXT.get(a, a))), int(e.get("n", 0)), roundi(100.0 * float(e.get("schaden", 0.0)) / maxf(1.0, max_leben))])
	var zeilen := [tr("Druckphasen: %d") % int(z.get("druckphasen", 0)) + " · " + tr("Doppelstürme: %d") % int(z.get("doppelstuerme", 0)),
		tr("Bodenmarkierung: %d %% der Zeit (Ziel < 25 %%)") % int(z.get("boden_anteil", 0)) + " · " + tr("Abstand außerhalb der Stürme: Ø %.1f Felder (Ziel ≥ 8)") % abstand_mittel(z),
		tr("Schaden im Fenster: %d %%") % fenster_prozent(z)]   # H-11
	if z.has("gel_zeit"):   # J-7: Plasmawerfer
		zeilen.append(tr("Im Gel %.1f s · Brakk auf Kronen %.1f s · Wallsprenger %d · im Mittel %.1f Gele") % [float(z["gel_zeit"]), float(z.get("brakk_krone_zeit", 0.0)),
			int(z.get("wallsprenger", 0)), float(z.get("gele_mittel", 0.0))])
	if z.has("anker_treffer"):   # I-8: Technogunner
		zeilen.append(tr("Jagdanker: %d getroffen, %d gerissen · Minigun in Reichweite %.1f s · Kronen %d (%.1f s oben)") % [int(z["anker_treffer"]),
			int(z.get("anker_gerissen", 0)), float(z.get("minigun_drin", 0.0)), int(z.get("kronen", 0)), float(z.get("krone_zeit", 0.0))])
	return {
		"kicker": tr("BOSSARENA") + " · " + str(BOSS_TEXT.get(art, art)),
		"titel": tr("VERTRIEBEN") if vertrieben else (tr("NEUSTART") if ausgang == "neustart" else tr("BRAKK GEFALLEN")),
		"titel_farbe": Color("7fe0ff") if vertrieben else Color("ff6a5a"),
		"untertitel": str(z.get("name", "")),
		"kacheln": [
			{"name": tr("Dauer"), "zahl": roundi(float(z.get("dauer", 0.0))), "zeit": true},
			{"name": tr("Angriffe"), "zahl": summe},
			{"name": tr("Fenster genutzt"), "text": "%d %%" % fenster_zeit_prozent(z)},   # H-11: Anteil der verwundbaren Zeit mit Treffern
			{"name": tr("Vergeltungen"), "zahl": int(z.get("vergeltungen", 0))},
		],
		"kaesten": [
			{"titel": tr("Angriffe je Art"), "farbe": Color("ffd27a"), "text": " · ".join(teile) if not teile.is_empty() else "–"},
			{"titel": tr("Treffer auf Brakk"), "farbe": Color("ff6a5a"), "text": " · ".join(tt) if not tt.is_empty() else tr("keine")},
		],
		"zeilen": zeilen,
		"knoepfe": [[tr("Nochmal"), neu_starten, Color("ffd27a")], [tr("Anderer Boss"), _anderer_boss, Color("7fe0ff")], [tr("Zurück"), _zurueck, Color("a79fb3")]],
		"esc": _zurueck,
	}


## H-11 (27.11., Paul): Anteil der verwundbaren Zeit, in der Brakk den Boss traf (Prozent, je Fenster mit mindestens einem Treffer).
static func fenster_zeit_prozent(z: Dictionary) -> int:
	var zeit := float(z.get("fenster_zeit", 0.0))
	return roundi(100.0 * float(z.get("fenster_getroffen_zeit", 0.0)) / zeit) if zeit > 0.0 else 0


## H-11: mittlerer Abstand des Bosses außerhalb der Stürme (Felder; Ziel beim Scharfschützen ≥ 8).
static func abstand_mittel(z: Dictionary) -> float:
	var zeit := float(z.get("abstand_zeit", 0.0))
	return snappedf(float(z.get("abstand_summe", 0.0)) / zeit, 0.1) if zeit > 0.0 else 0.0


## H-11: lesbare Namen der Angriffsarten in der Zählung.
const ART_TEXT := {"salve": "Salve", "sturm": "Sturm", "laser": "Laser", "reihe": "Reihenwelle", "saeule": "Lichtsäule", "stellung": "Stellungen",
	"klon": "Klon", "zielmarkierung": "Zielmarkierung", "anker": "Jagdanker-Zug", "ring": "Ring", "salve4": "4er-Salve", "minigun": "Minigun",
	"sturmring": "Sturmring", "moerser": "Mörser", "glut": "Nachglühen", "wallsprenger": "Wallsprenger", "abpraller": "Abpraller", "brand": "Brand"}


## Anteil des Schadens am Boss, der in seinen verwundbaren Fenstern ankam (Prozent).
static func fenster_prozent(z: Dictionary) -> int:
	var gesamt := float(z.get("boss_schaden", 0.0))
	return roundi(100.0 * float(z.get("fenster_schaden", 0.0)) / gesamt) if gesamt > 0.0 else 0


## Dasselbe Setup noch einmal (Szene neu laden; main startet über die Karte wieder Befehl 24 und damit die Arena).
func neu_starten() -> void:
	get_tree().paused = false
	laeuft = true
	spiel.naechster_start = "normal"
	Ladebild.lade(get_tree())


func _anderer_boss() -> void:
	menue_seite = "bossarena"
	_zurueck()


func _zurueck() -> void:
	get_tree().paused = false
	laeuft = false
	spiel.naechster_start = ""
	Ladebild.lade(get_tree())


## tr() für statische Funktionen.
static func _tx(text: String) -> String:
	return TranslationServer.translate(text)
