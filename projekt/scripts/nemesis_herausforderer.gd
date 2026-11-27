class_name NemesisHerausforderer
extends Node
## 26.11. (Paul): Befehl 24 – der Herausforderer. Zu Minute 9 und 14 tritt ein Benannter allein gegen Brakk an.
##  - 10 s vorher meldet sich Sonde 7, die Phasenzeile heißt „Herausforderung“, die Musik wird leiser.
##  - Solange er steht, ruht der Fahrplan des Technoclan (Wellen, Vorstoß, Eskalation, Überläufer – nur die
##    Überlebens-Uhr läuft weiter). Jagdtrupps ziehen sich zu ihren Fabriken zurück, Bodentruppen schießen nicht;
##    Türme und Stellungen schießen weiter. F1 (26.11., Paul): Das gilt, solange die Lichtwand des Kampfplatzes steht;
##    nur ohne Lichtwand kommen die Trupps nach HERAUSFORDERER_PAUSE_MAX s zurück.
## Dieses Kind von Order24 führt den Ablauf; die Figur selbst steuert es mit angehaltener Truppenlogik (halt).

var o24: Order24
var nem: Nemesis
var spiel: Node

var zeiten: Array = []           # wann er antritt (Überlebens-Uhr, Sekunden); leer = gar nicht
var naechste := 0                # Index in zeiten
var zustand := "ruhe"            # "ruhe", "angesagt", "duell"
var einheit: Einheit = null
var person: Dictionary = {}
var vorher: Dictionary = {}      # der Herausforderer davor – C1: er und seine Truppenart kommen in diesem Lauf nicht wieder
var seit := 0.0                  # so lange läuft das Duell (Sekunden)
var protokoll: Array = []        # Prüfung: {"was", "bei", …}
var ergebnisse: Array = []       # für den Bericht: je [Name, "vertrieben" | "gesiegt"]
var kennwerte: Dictionary = {}   # wie Brakk spielt (nemesis_lernen.kennwerte)
## Bewegung (Punkt 4)
var _weg: Array[Vector2] = []    # Wegpunkte (Bildpunkte)
var _weg_neu := 0.0
var _aktion := {}                # laufender Sprung oder Tumble: {"art", "t", "sek", "von", "nach"}
var _aktion_in := 3.0
var _ausweich_rest := 0.0
var _wall_rest := 0.0            # > 0: er steht auf einer Wallkrone
var _wall_abkling := 4.0
var zaehler := {"sprung": 0, "tumble": 0, "ausweichen": 0, "wall": 0}
var angriffe_je_art := {}         # F5 (26.11., Paul): je Duell, wie oft welcher Angriff (Protokoll, Test)
var _krone_angriffe := 0         # F5: Angriffe von der aktuellen Krone …
var _krone_warte := 0.0          # … und wie lange er schon auf den ersten wartet
var kronen_ohne_angriff := 0     # F5: Prüfung – Kronen, die er ohne Angriff verließ (nach BOSS_SNIPER_KRONE_SEK Warten)
## Angriffe (Punkt 5)
var angriff := {}                # {"art", "teil": "anlauf"|"ansage"|"fenster", "t", "um", "ziel", "richtung"}
var wut := false                 # unter halbem Leben
var _letzte: Array = []          # die letzten Angriffe (nie derselbe dreimal)
var _bis_angriff := 2.0
var _salven := 0
## Vergeltung (Punkt 6)
const VERGELTUNG_UMRISS := Color("b46bff")
var vergeltung := {}             # {"art", "ring", "name", "rest"} – leer: gerade keine
var _vergeltung_in := 12.0
var marke_rest := 0.0            # Zielring: Brakk ist markiert
var gel_rest := 0.0              # Gelring: Brakk ist gebremst
var _marke: Node3D = null        # Vorschau der kopierten Lichtsäule
var stehende_saeule := {}         # H-7: die stehende Lichtsäule der Vergeltung: {"pos", "rest", "bild"}
var saeule_schaden := 0.0         # Prüfung (Anteile eines Treffers)
var _saeule_verzug := 0.0         # H-7: so lange wartet die fällige Säule schon auf freien Boden
var _saeule_ziel := Vector2.INF   # H-7: Ziel der nächsten Ansage (statt Brakks Position)
var _saeule_umriss_bis := -1.0    # H-7: so lange (uhr) trägt er den lila Umriss der Vergeltung
var klon: NemesisKlon = null      # H-8: die Klonmaschine dieses Duells
var klon_erzwingen := false        # H-8: Bossarena-Schalter bzw. Prüfung: der Klon kommt sicher
var gesagt := {}                   # I-1: Hinweise, die je Lauf nur einmal kommen (z. B. „jagdanker“)
## C1 (26.11., Paul): Kampfplatz und Auftritt als Sequenz
var kampfplatz: BrakkKampfplatz = null
var einzug := {}                 # er kommt von außen: {"teil": "lauf"|"sprung"|"ladung"|"durch", "t", "vor", "wall", "drinnen", "weg"}
var _aufbau_versucht := false
var _drohne: Drohne = null       # Erscheinungsmusik (Platzhalter)
## C2 (26.11., Paul): Bosstyp nach Truppenart (nemesis_boss*.gd)
var typ: NemesisBoss = null
var anvisiert := Vector2.INF     # er zielt auf Brakk (HUD „ANVISIERT“ mit Richtungspfeil): von hier
var gebunden_rest := 0.0         # Brakk ist vom Anker des Technogunners gebunden (kann nicht gehen)
var saeulen := 0                 # Brakks Lichtsäulen in diesem Lauf
var sonde_vertrieben := false    # C3: Sonde 7 trat selbst an und wurde vertrieben (Bericht, Hangar)
var sonde_erzwingen := false     # Prüfung: zu Minute 14 sicher Sonde 7
var sonde_aus := false           # Prüfung: nie Sonde 7 (26.11.: herausforderertest wackelte an der Ziehung)
## G2 (27.11., Paul): Bossarena und Zählung je Duell
var ansage_sek := Werte.HERAUSFORDERER_ANSAGE_SEK   # so lange vor dem Auftritt meldet sich Sonde 7 (Bossarena: kürzer)
var arena_person := {}           # Bossarena: diese Person tritt an (statt der Ziehung)
var zaehlung := {}               # je Duell: {"boss", "name", "angriffe", "treffer": {Art: {"n", "schaden"}}, "boss_schaden",
                                 #  "fenster_schaden", "vergeltungen", "druckphasen", "dauer", "ausgang"}
## G2-2: feste Abfolge (NemesisBoss.abfolge)
var _abf: Array = []             # Schritte der laufenden Phase …
var _abf_i := 0                  # … der nächste …
var _abf_wut := false            # … für welche Phase
var _abf_vorn: Array = []        # Eröffnung: läuft einmal vor der Abfolge
var schritt_jetzt := {}          # der Schritt des laufenden Angriffs ({} = Rückfall, Vergeltung oder Reaktion)
var _nach_krone := ""            # Schritt mit „krone“: dieser Angriff, sobald er oben steht
var abfolge_log: Array = []      # Prüfung: je {"i", "art", "bei", "druck"} (i = -1: Eröffnung)
## G2-3: Druckphasen
const DRUCK_UMRISS := Color("c46bff")
var druck := false               # läuft gerade eine Druckphase?
var _druck_seit := 0.0
var reihe: NemesisReihenwelle = null   # H-1: die laufende Reihenwelle (Anker-Zwang, lesbar; ersetzt das Bodenfeuer)
var zaehl_art := ""               # H-1: Treffer zählen unter dieser Art (Reihenwelle, Säule, Klon – laufen neben den Angriffen)
var _hoch_gesagt := false        # Sonde 7 kommentiert die erste Reihenwelle im Lauf
## H-6 (27.11., Paul): nie zwei Bodeneffekte zugleich (alle Bosse) – wer markiert den Boden bis wann (Duell-Sekunden)
var boden := {}                  # Besitzer ("boss", "reihe", "saeule", "klon") → bis (uhr)
var uhr := 0.0                    # H-6: Duell-Sekunden im Takt von schritt() (für boden)
var boden_log: Array = []        # Prüfung: je {"wer", "von", "bis"}
var _wartend := ""               # dieser Angriff der Abfolge wartet, bis der Boden frei (bzw. er bereit) ist
var _wartet_seit := 0.0
var anvisiert_balken := -1.0     # HUD unter „ANVISIERT“: Balken 0..1 (-1 = keiner) …
var anvisiert_text := ""         # … und sein Text ("" = „ANVISIERT“)
var brakk_v := Vector2.ZERO        # H-2: Brakks Geschwindigkeit (Bildpunkte je echter Sekunde, geglättet) …
var _brakk_vorher := Vector2.INF  # … aus seiner Lage im letzten Schritt


func einrichten(p_nem: Nemesis) -> void:
	nem = p_nem
	o24 = nem.o24
	spiel = nem.spiel
	zeiten = Werte.HERAUSFORDERER_ZEITEN.duplicate() if bool(o24.w("herausforderer")) else []
	kampfplatz = BrakkKampfplatz.new()
	add_child(kampfplatz)
	kampfplatz.einrichten(o24)


## Ruht deshalb der Fahrplan? F1 (26.11., Paul): solange die Lichtwand steht (auch bis zur Bergung); ohne Lichtwand
## nur die ersten HERAUSFORDERER_PAUSE_MAX s des Duells.
func sperrt() -> bool:
	return kampfplatz.zu() or (zustand == "duell" and seit <= Werte.HERAUSFORDERER_PAUSE_MAX)


## Läuft eine Herausforderung (angesagt oder im Gang)?
func laeuft() -> bool:
	return zustand != "ruhe"


## Ist das der Herausforderer, der gerade kämpft?
func ist_er(e: Variant) -> bool:
	return zustand == "duell" and e != null and is_instance_valid(e) and e == einheit


## Je Sekunde der Überlebens-Uhr (Order24._process, `dt` in echten Sekunden).
func weiter(dt: float) -> void:
	match zustand:
		"ruhe":
			if naechste < zeiten.size() and not o24.geheim and o24.zeit >= float(zeiten[naechste]) - ansage_sek:
				_ansagen()
		"angesagt":
			if not _aufbau_versucht and o24.zeit >= float(zeiten[naechste]) - ansage_sek + Werte.KAMPFPLATZ_RAEUM_VERZUG:
				_aufbau_versucht = true
				kampfplatz.aufbauen(o24.karte.zelle_bei(kampfplatz._fuss()))
			if o24.zeit >= float(zeiten[naechste]):
				_auftritt()
		"duell":
			var vor := sperrt()
			seit += dt
			if vor and not sperrt():
				_trupps_zurueck()
			if einheit == null or not is_instance_valid(einheit) or einheit.kampfunfaehig:
				ende("vertrieben")


func _ansagen() -> void:
	zustand = "angesagt"
	protokoll.append({"was": "ansage", "bei": o24.zeit})
	spiel.melde("Sonde 7: „Da kommt einer allein. Er will dich.“", 6.0)
	Ton.spiele(spiel, "alert", -2.0)
	Musik.duell(spiel.get_tree(), true)   # C1: Musik aus (HERAUSFORDERER_MUSIK_DB) …
	_aufbau_versucht = false
	_drohne_aus(0.1)
	_drohne = Drohne.new()                # … dafür die Erscheinungsmusik
	add_child(_drohne)


## C1: Tritt zu Minute 14 Sonde 7 selbst an? (SONDE_BOSS_CHANCE; nur beim zweiten Termin)
func sonde_zieht() -> bool:
	return naechste >= 1 and not sonde_aus and (sonde_erzwingen or randf() < Werte.SONDE_BOSS_CHANCE)


func _auftritt() -> void:
	var p: Dictionary = {}
	if not arena_person.is_empty():
		p = arena_person   # G2: Bossarena
	elif sonde_zieht():
		protokoll.append({"was": "sonde_gezogen", "bei": o24.zeit})
		p = Nemesis.sonde_person()   # C3: Sonde 7 selbst
	else:
		p = nem.herausforderer_waehlen(vorher)
	if p.is_empty():
		zustand = "ruhe"
		naechste += 1
		Musik.duell(spiel.get_tree(), false)
		kampfplatz.aufloesen(null, "bleibt")   # niemand kam: zurück zur Karte, Brakk bleibt, wo er ist
		_drohne_aus(1.0)
		return
	person = p
	# steht er schon im Feld (oder liegt er dort), verschwindet er dort und kommt allein per Beam
	var alt := nem.einheit_von(p)
	if alt != null:
		for k: Dictionary in nem.kampfunfaehig.duplicate():
			if k["einheit"] == alt:
				nem.kampfunfaehig.erase(k)
		nem._wegbeamen(alt, not alt.kampfunfaehig)
	var quelle := _fabrik_fuer(str(p["art"]))
	var e := o24._neue_truppe(str(p["art"]), quelle, 4)
	p["geborgen"] = false   # er tritt ausgeruht an
	if not ist_sonde():
		nem.einkleiden(e, p)
	einheit = e
	# 26.11. (Paul): feste Werte – Rangbonus, „zäh“ und Narben zählen hier nicht
	var k: Kommandant = spiel.kommandant
	typ = NemesisBoss.fuer("sonde" if ist_sonde() else str(p["art"]), self)   # C2, C3
	typ.einrichten_figur(e)
	e.max_leben = Werte.HERAUSFORDERER_LEBEN_MAL * k.max_leben * typ.leben_mal()
	e.leben = e.max_leben
	# C1: Steht der Kampfplatz, beamt er vor einem Randwall herein und kommt von außen; sonst wie bisher vor Brakk.
	einzug = _zugang() if kampfplatz.aktiv() else {}
	if not einzug.is_empty():
		e.position = o24.karte.mitte(einzug["start"] as Vector2i)
	elif kampfplatz.aktiv():
		e.position = o24.karte.mitte(kampfplatz._frei_innen(kampfplatz.mitte + Vector2i(0, -3)))
	else:
		e.position = o24.karte.mitte(ankunft())
	e.halt = true            # ab jetzt steuert ihn diese Datei
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._ausstehend.clear()
	if e.posten_zelle != Karte.KEINE and o24.karte.posten.get(e.posten_zelle) == e:
		o24.karte.posten.erase(e.posten_zelle)
	e.posten_zelle = Karte.KEINE
	e.set_meta("herausforderer", true)
	zustand = "duell"
	seit = 0.0
	_weg.clear()
	_aktion = {}
	_wall_rest = 0.0
	_wall_abkling = 4.0
	zaehler = {"sprung": 0, "tumble": 0, "ausweichen": 0, "wall": 0}
	angriffe_je_art = {}
	zaehlung = {"boss": "sonde" if ist_sonde() else str(p["art"]), "name": Nemesis.voller_name(p), "angriffe": angriffe_je_art, "treffer": {},
		"boss_schaden": 0.0, "fenster_schaden": 0.0, "vergeltungen": 0, "druckphasen": 0, "dauer": 0.0, "ausgang": "",
		"doppelstuerme": 0, "fenster_zeit": 0.0, "fenster_getroffen_zeit": 0.0, "abstand_summe": 0.0, "abstand_zeit": 0.0, "boden_anteil": 0}   # G2; H-11
	kennwerte = nem.lernen.kennwerte()
	_aktion_in = float(kennwerte["takt"])
	angriff = {}
	wut = false
	_letzte.clear()
	boden = {}   # H-6
	brakk_v = Vector2.ZERO   # H-2
	_brakk_vorher = Vector2.INF
	uhr = 0.0
	_saeule_umriss_bis = -1.0   # H-7
	klon = NemesisKlon.new(self)   # H-8
	klon.duell_beginnt(klon_erzwingen or (o24.arena != null and bool(BrakkBossarena.wahl.get("klon", false))))
	_saeule_verzug = 0.0
	stehende_saeule = {}
	boden_log = []
	_wartend = ""
	_abf = []   # G2-2
	_abf_vorn = []
	schritt_jetzt = {}
	_nach_krone = ""
	abfolge_log = []
	_bis_angriff = Werte.HERAUSFORDERER_ERSTER_ANGRIFF
	vergeltung = {}
	_vergeltung_in = Werte.HERAUSFORDERER_VERGELTUNG_ERSTE
	marke_rest = 0.0
	gel_rest = 0.0
	var schild := e.get_node_or_null("Frontschild") as CanvasItem
	if schild != null:
		schild.visible = false   # erst ab halbem Leben
	p["duell"] = {"abstand": kennwerte["abstand"], "je_min": kennwerte["je_min"], "seite": kennwerte["seite"], "wall": kennwerte["wall"]}   # für die Karte
	_gefecht_raeumen()
	_beam_an(e.position)
	if ist_sonde():   # C3: ihr eigenes Banner
		o24.tafeln.zeige({"art": "herausforderer", "titel": Nemesis.name_mit_titel(p), "zeilen": [tr("Befehl 24 – ich übernehme selbst.")],
			"rechts": "", "farbe": NemesisBossSonde.CYAN, "sek": Werte.HERAUSFORDERER_TAFEL_SEK, "pause": 0.3})
	else:
		var faehig := PackedStringArray(NemesisFaehigkeiten.von_person(p).map(func(f: Variant) -> String: return NemesisFaehigkeiten.name_von(str(f))))
		o24.tafeln.zeige({"art": "herausforderer", "titel": Nemesis.name_mit_titel(p), "zeilen": [
			"%s · %s" % [str(Nemesis.ART_TEXT.get(str(p["art"]), "")), " · ".join(faehig) if not faehig.is_empty() else "—"],
			tr("Er will dich. Allein.")], "rechts": Nemesis.bilanz_text(p).trim_prefix("Stand "), "farbe": Nemesis.umriss_farbe(p),
			"sek": Werte.HERAUSFORDERER_TAFEL_SEK, "pause": 0.3})
	protokoll.append({"was": "auftritt", "bei": o24.zeit, "name": Nemesis.voller_name(p),
		"abstand": e.position.distance_to(spiel.kommandant.position) / Werte.ZELLE, "einzug": not einzug.is_empty()})
	if not ist_sonde():
		nem._chronik(p, "fordert Brakk heraus")
	if einzug.is_empty() and kampfplatz.aktiv():
		_drin()   # kein Zugang von außen: er steht schon drin


## Duell vorbei: `wie` = "vertrieben" (er liegt) oder "gesiegt" (Brakk liegt).
func ende(wie: String) -> void:
	if zustand != "duell":
		return
	zustand = "ruhe"
	protokoll.append({"was": "angriffe", "bei": o24.zeit, "je_art": angriffe_je_art.duplicate(), "kronen_ohne_angriff": kronen_ohne_angriff})   # F5
	print("HERAUSFORDERER Angriffe je Art: %s" % str(angriffe_je_art))
	if not zaehlung.is_empty():   # G2: Zählung abschließen (Bossarena-Tafel, Protokoll)
		zaehlung["angriffe"] = angriffe_je_art.duplicate()
		zaehlung["dauer"] = snappedf(seit, 0.1)
		zaehlung["boden_anteil"] = boden_anteil()   # H-11
		if typ != null:
			zaehlung.merge(typ.zaehlung_extra(), true)   # I-8
		if str(zaehlung["ausgang"]) == "":
			zaehlung["ausgang"] = wie
		if o24.arena == null and spiel.has_method("befehl24_protokoll"):   # G2-6: im echten Lauf ins Partieprotokoll
			spiel.befehl24_protokoll("duell", duell_protokoll())
	naechste += 1
	while naechste < zeiten.size() and float(zeiten[naechste]) - ansage_sek <= o24.zeit:
		naechste += 1   # dauerte das Duell über den nächsten Termin hinaus, fällt der aus
	vorher = person
	ergebnisse.append([Nemesis.voller_name(person), wie])
	protokoll.append({"was": "ende", "bei": o24.zeit, "wie": wie, "dauer": seit})
	Musik.duell(spiel.get_tree(), false)
	angriff = {}
	_aktion = {}
	einzug = {}
	# C1: nach der Bergung zurück zur normalen Karte; F1 (26.11., Paul): Brakk bleibt, wo er steht. Fällt Brakk, ist der
	# Lauf vorbei (sofort).
	kampfplatz.aufloesen(einheit if wie == "vertrieben" and einheit != null and is_instance_valid(einheit) else null, "sofort" if wie == "gesiegt" else "bleibt")
	_drohne_aus(1.0)
	vergeltung_aus()
	_druck_aus()   # G2-3
	_reihe_aus()   # H-1
	_saeule_weg()   # H-7
	if klon != null:
		klon.ende()   # H-8
	if typ != null:
		typ.ende()   # C2: Stellungen, Bunker, Gel- und Brandflächen weg
	marke_rest = 0.0
	gel_rest = 0.0
	_marke_weg()
	if einheit != null and is_instance_valid(einheit):
		einheit.set_meta("hebt_ab", 0.0)
		einheit._sprite.modulate = Color(0.55, 0.55, 0.62) if einheit.kampfunfaehig else Color.WHITE
	if wie == "vertrieben":
		_besiegt()
	einheit = null
	if o24.arena != null:
		o24.arena.duell_ende(wie)   # G2: Bossarena – Bergung abwarten, dann die Tafel


## G2-6: Die Zählung des Duells fürs befehl24-Protokoll (Eintrag „duell“; werkzeuge/brakk_auswertung.py zeigt je Boss
## eine Tabelle). Schaden in Prozent von Brakks Leben.
func duell_protokoll() -> Dictionary:
	var k: Kommandant = spiel.kommandant
	var max_leben := k.max_leben if k != null else 1.0
	var treffer := {}
	for a: String in (zaehlung.get("treffer", {}) as Dictionary):
		var e: Dictionary = zaehlung["treffer"][a]
		treffer[a] = {"n": int(e["n"]), "prozent": roundi(100.0 * float(e["schaden"]) / maxf(1.0, max_leben))}
	return {"boss": str(zaehlung.get("boss", "")), "name": str(zaehlung.get("name", "")), "dauer": float(zaehlung.get("dauer", 0.0)),
		"angriffe": (zaehlung.get("angriffe", {}) as Dictionary).duplicate(), "treffer_je_art": treffer,
		"fenster_genutzt": BrakkBossarena.fenster_prozent(zaehlung), "druckphasen": int(zaehlung.get("druckphasen", 0)),
		"vergeltungen": int(zaehlung.get("vergeltungen", 0)), "ausgang": str(zaehlung.get("ausgang", "")),
		"doppelstuerme": int(zaehlung.get("doppelstuerme", 0)), "boden_anteil": int(zaehlung.get("boden_anteil", 0)),   # H-11
		"abstand_mittel": BrakkBossarena.abstand_mittel(zaehlung), "fenster_zeit_genutzt": BrakkBossarena.fenster_zeit_prozent(zaehlung),
		"typ": typ.zaehlung_extra() if typ != null else {}}   # I-8


## G2: Order24.BrakkZiel – einer seiner Treffer kam bei Brakk an (`menge` nach allen Faktoren). Gezählt je Angriffsart
## (der laufende, sonst der letzte – Brand und Gel wirken nach); als Treffer zählt, was mindestens 10 % eines vollen hat.
func zaehle_treffer(menge: float) -> void:
	if zustand != "duell" or zaehlung.is_empty():
		return
	var art := str(angriff.get("art", "")) if not angriff.is_empty() else (str(_letzte.back()) if not _letzte.is_empty() else "sonst")
	if zaehl_art != "":
		art = zaehl_art   # H-1: Reihenwelle, Säule, Klon
	var t: Dictionary = zaehlung["treffer"]
	var e: Dictionary = t.get(art, {"n": 0, "schaden": 0.0})
	e["schaden"] = float(e["schaden"]) + menge
	var nr := int(angriff.get("nr", -1))
	if menge >= schaden() * 0.1:
		e["n"] = int(e["n"]) + 1
	elif nr >= 0 and nr != int(zaehlung.get("dauer_nr", -2)):
		e["n"] = int(e["n"]) + 1   # Dauerschaden (Laser, Minigun): ein Treffer je Angriff
		zaehlung["dauer_nr"] = nr
	t[art] = e


## G2: Order24.treffer – Brakk trifft ihn (`menge` kommt bei ihm an); im verwundbaren Fenster getrennt gezählt.
func zaehle_boss_schaden(menge: float) -> void:
	if zustand != "duell" or zaehlung.is_empty():
		return
	zaehlung["boss_schaden"] = float(zaehlung["boss_schaden"]) + menge
	if str(angriff.get("teil", "")) == "fenster":
		zaehlung["fenster_schaden"] = float(zaehlung["fenster_schaden"]) + menge
		angriff["getroffen"] = true   # H-11: dieses Fenster hat Brakk genutzt


## Schaden eines seiner Treffer – fest, unabhängig von den Regeln für die Verteidigung (Brakks Wallring schützt weiter).
func schaden() -> float:
	var k: Kommandant = spiel.kommandant
	return Werte.HERAUSFORDERER_TREFFER_ANTEIL * (k.max_leben if k != null else 500.0)


## Die Quelle seiner Treffer (die Nummer dahinter sagt dem Nemesis-System, wer getroffen hat).
func quelle() -> String:
	return "herausforderer#%d" % einheit.get_instance_id()


## Felder je echter Sekunde: Brakks Lauftempo in der Ego-Sicht, etwas schneller.
func tempo() -> float:
	return EgoModus.TEMPO * float((Werte.ANFUEHRER_EGO["brakk"] as Dictionary)["tempo"]) * Werte.HERAUSFORDERER_TEMPO_MAL * (typ.tempo_mal() if typ != null else 1.0)


## Er liegt: kurze Zeitlupe, der Ring fällt sofort, Banner. Danach läuft alles wie sonst – [E] halten schaltet ihn
## endgültig aus (Kopfgeld ohne Ring), sonst wird er geborgen; der Fahrplan läuft weiter.
func _besiegt() -> void:
	if einheit == null or not is_instance_valid(einheit):
		return
	if spiel.ego != null:
		spiel.ego.kurze_lupe(Werte.HERAUSFORDERER_ENDE_LUPE_SEK)
	o24.beute_legen_herausforderer(einheit.position)
	if ist_sonde():
		sonde_vertrieben = true   # C3: Bericht und Hangar zeigen sie auf dem Podest
	o24.tafeln.zeige({"art": "herausforderer", "titel": tr("Sonde 7 vertrieben") if ist_sonde() else tr("Herausforderer vertrieben"),
		"zeilen": [Nemesis.name_mit_titel(person)], "farbe": Color("7fe0ff"), "sek": Werte.HERAUSFORDERER_TAFEL_SEK, "pause": 0.3})


## C3: Tritt gerade (oder trat zuletzt) Sonde 7 selbst an?
func ist_sonde() -> bool:
	return bool(person.get("sonde", false))


## Brakk ist gefallen, während er stand: Er hat das Duell gewonnen (auch wenn ein Turm den letzten Treffer gab).
func brakk_faellt() -> void:
	if zustand != "duell" or person.is_empty():
		return
	if ist_sonde():
		# C3: Sonde 7 steht in keiner Liste – kein Rang, keine Chronik. 26.11. (Paul): Der Deathscreen nennt sie
		# (auch wenn ein Turm den letzten Treffer gab); befördert wird für ihren Treffer niemand.
		nem.erledigt_info = {"lage": "", "art": str(person["art"]), "namenlos": false, "rang_vorher": int(person["rang"]),
			"begegnung": 1, "faehigkeit": "", "gewohnheit": "", "taktik": "", "duell": true}
		nem.erledigt_von = person
		ende("gesiegt")
		return
	if nem.erledigt_von != person:
		var pl: Dictionary = person["lauf"]
		nem.erledigt_info = {"lage": "", "art": str(person["art"]), "namenlos": false, "rang_vorher": int(person["rang"]),
			"begegnung": int(person.get("begegnungen", 0)) + 1, "faehigkeit": "", "gewohnheit": "", "taktik": ""}
		if not bool(pl["rang_plus"]) and int(person["rang"]) < Werte.NEMESIS_RANG_MAX:
			person["rang"] = int(person["rang"]) + 1
			pl["rang_plus"] = true
		Nemesis.titel_geben(person, Nemesis.TITEL_BEZWINGER)
		(person["bilanz"] as Dictionary)["er"] = int((person["bilanz"] as Dictionary)["er"]) + 1
		nem.erledigt_von = person
	elif not bool((person["lauf"] as Dictionary)["rang_plus"]) and int(person["rang"]) < Werte.NEMESIS_RANG_MAX:
		person["rang"] = int(person["rang"]) + 1
		(person["lauf"] as Dictionary)["rang_plus"] = true
	nem.erledigt_info["duell"] = true
	nem._chronik(person, "hat Brakk im Duell geschlagen")
	ende("gesiegt")


## Wo er ankommt: ein freies, zu Fuß erreichbares Feld HERAUSFORDERER_ABSTAND Felder vor Brakk, am liebsten mit Sicht
## und in Blickrichtung. Findet sich keins, wird der Ring weiter.
func ankunft() -> Vector2i:
	var k: Kommandant = spiel.kommandant
	var karte: Karte = o24.karte
	var blick := Vector2.RIGHT
	if spiel.ego != null:
		blick = Vector2(-sin(spiel.ego.gier), -cos(spiel.ego.gier))
	var von := karte.zelle_bei(k.position)
	for rand: Vector2 in [Vector2.ZERO, Vector2(-2, 2), Vector2(-4, 6)]:
		var beste := Karte.KEINE
		var wert := -INF
		for y in range(von.y - 18, von.y + 19):
			for x in range(von.x - 18, von.x + 19):
				var z := Vector2i(x, y)
				if not karte.in_karte(z) or not karte.ist_begehbar(z) or not karte.ist_frei(z):
					continue
				var p := karte.mitte(z)
				var d := p.distance_to(k.position) / Werte.ZELLE
				if d < Werte.HERAUSFORDERER_ABSTAND.x + rand.x or d > Werte.HERAUSFORDERER_ABSTAND.y + rand.y:
					continue
				var sicht := karte.sicht_frei(p, k.position)
				var w := (10.0 if sicht else 0.0) + blick.dot((p - k.position).normalized()) * 3.0 - absf(d - 11.0) * 0.2
				if w > wert and (sicht or not karte.einheiten_weg(z, o24._erreichbar_nahe(von, z)).is_empty()):
					wert = w
					beste = z
		if beste != Karte.KEINE:
			return beste
	return o24._freies_feld_bei(k.position + blick * 6.0 * Werte.ZELLE, von)


func _fabrik_fuer(art: String) -> Vector2i:
	var sonst := Karte.KEINE
	for z: Vector2i in spiel.fabriken:
		var typ := str(spiel.fabriken[z]["typ"])
		if typ == art and not o24.fabrik_hp.has(z):
			return z
		if typ != "pilot" and sonst == Karte.KEINE:
			sonst = z
	return sonst


## Zu Beginn des Duells: laufende Fähigkeiten der anderen brechen ab, die Jagdtrupps vergessen Brakk.
func _gefecht_raeumen() -> void:
	if nem.faehigkeiten != null:
		for id: int in nem.faehigkeiten._zust.keys():
			var x: Variant = instance_from_id(id)
			if Nemesis.lebt(x) and x != einheit:
				(x as Einheit).halt = false
		nem.faehigkeiten._zust.clear()
	o24.alarm.clear()
	for x: Variant in o24._truppen():
		if x != einheit:
			(x as Einheit)._plan_in = 0.0
			if (x as Einheit).zustand == Einheit.Zustand.BODEN:
				(x as Einheit)._punkte.clear()


func _trupps_zurueck() -> void:
	protokoll.append({"was": "trupps_zurueck", "bei": o24.zeit})
	spiel.melde("Sonde 7: „Das dauert zu lange. Jagdtrupps – wieder vor.“", 4.0)
	Musik.duell(spiel.get_tree(), false)


func _beam_an(pos: Vector2) -> void:
	var hd: HdAnsicht = spiel.hd
	if hd != null:
		var saeule := o24._kasten3d(hd, Vector3(0.6, 6.0, 0.6), Order24.TECHNO_FARBE, Vector3(pos.x / Werte.ZELLE, 3.0, (pos.y - Werte.KARTE_OBEN) / Werte.ZELLE))
		var stoff := saeule.material_override as StandardMaterial3D
		stoff.albedo_color.a = 0.55
		var tw := saeule.create_tween()
		tw.tween_property(stoff, "albedo_color:a", 0.0, 1.2)
		tw.tween_callback(saeule.queue_free)
	spiel.effekte.flaeche(pos, Werte.ZELLE * 0.9, Order24.TECHNO_FARBE)
	Ton.spiele(spiel, "tc-arc", 2.0)



# ------------------------------------------------------------------ Einzug in den Kampfplatz (C1)

## Woher er kommt: ein Randwall neben einer Lücke (vor ihm und dahinter frei), am liebsten in Brakks Blickrichtung.
## Er beamt KAMPFPLATZ_ANMARSCH Felder davor herein. {} = kein Zugang.
func _zugang() -> Dictionary:
	var karte: Karte = o24.karte
	var kp := kampfplatz
	var k: Kommandant = spiel.kommandant
	var blick := Vector2.RIGHT
	if spiel.ego != null:
		blick = Vector2(-sin(spiel.ego.gier), -cos(spiel.ego.gier))
	var beste := {}
	var wert := -INF
	for s: String in BrakkKampfplatz.SEITEN:
		var raus := BrakkKampfplatz.aussen(s)
		var quer := Vector2i(absi(raus.y), absi(raus.x))   # entlang der Seite
		var lu := BrakkKampfplatz.luecke(s)
		for wall_r: Vector2i in [lu[0] - quer, lu[lu.size() - 1] + quer]:
			var wall := kp.mitte + wall_r
			var vor := wall + raus
			var drinnen := wall - raus
			if karte.inhalt(wall) != Karte.WALL or not kp.gesetzt.has(wall) or not _frei(vor) or not _frei(drinnen):
				continue
			var start := o24._freies_feld_bei(karte.mitte(wall + raus * Werte.KAMPFPLATZ_ANMARSCH), vor)
			var weg := karte.einheiten_weg(start, vor)
			if start != vor and weg.is_empty():
				continue
			var w := blick.dot((karte.mitte(wall) - k.position).normalized()) + randf() * 0.6
			if w > wert:
				wert = w
				beste = {"teil": "lauf", "t": 0.0, "start": start, "vor": vor, "wall": wall, "drinnen": drinnen, "weg": weg}
	return beste


func _frei(z: Vector2i) -> bool:
	return o24.karte.in_karte(z) and o24.karte.ist_begehbar(z) and o24.karte.ist_frei(z)


## Er läuft zum Randwall, dann springt er darüber oder sprengt ihn (je zur Hälfte). Drinnen schließt sich die Lichtwand.
func _einzug_weiter(dt: float) -> void:
	var karte: Karte = o24.karte
	einzug["t"] = float(einzug["t"]) + dt
	var t := float(einzug["t"])
	match str(einzug["teil"]):
		"lauf":
			var ziel := karte.mitte(einzug["vor"] as Vector2i)
			var weg: Array = einzug["weg"]
			var rest := tempo() * Werte.ZELLE * dt
			while rest > 0.0 and not weg.is_empty():
				var p := karte.mitte(weg[0] as Vector2i)
				var d := einheit.position.distance_to(p)
				if d <= rest:
					einheit.position = p
					weg.pop_front()
					rest -= d
				else:
					einheit.position = einheit.position.move_toward(p, rest)
					rest = 0.0
			einheit._sprite.bewegt(true)
			if weg.is_empty() or t >= Werte.KAMPFPLATZ_ANMARSCH_MAX:
				einheit.position = ziel
				einzug["t"] = 0.0
				if randf() < 0.5:
					einzug["teil"] = "sprung"
					_aktion = {"art": "sprung", "t": 0.0, "sek": Werte.KAMPFPLATZ_SPRUNG_SEK, "von": ziel, "nach": karte.mitte(einzug["drinnen"] as Vector2i), "hoch": Werte.KAMPFPLATZ_SPRUNG_HOCH}
				else:
					einzug["teil"] = "ladung"
					einheit._sprite.bewegt(false)
					einheit._sprite.angriff(Werte.KAMPFPLATZ_SPRENG_ANSAGE)
					spiel.effekte.warnung(karte.mitte(einzug["wall"] as Vector2i), Werte.KAMPFPLATZ_SPRENG_ANSAGE * Werte.BRAKK_TEMPO)
					Ton.am_ort(spiel, "tc-arc", einheit.position)
				protokoll.append({"was": "einzug_" + str(einzug["teil"]), "bei": o24.zeit})
		"ladung":
			if int(t * 6.0) != int((t - dt) * 6.0):   # die Ladung blinkt
				(spiel.brakk_geschosse as BrakkGeschosse).aufblitzen(karte.mitte(einzug["wall"] as Vector2i), Color("ff3b3b"))
			if t >= Werte.KAMPFPLATZ_SPRENG_ANSAGE:
				kampfplatz.sprengen(einzug["wall"] as Vector2i)
				einzug["teil"] = "durch"
				_aktion = {"art": "lauf", "t": 0.0, "sek": 0.6, "von": einheit.position, "nach": karte.mitte(einzug["drinnen"] as Vector2i)}
		"sprung", "durch":
			_aktion_weiter(dt)
			if _aktion.is_empty():
				_drin()


## Er ist drin: Die Lichtwand schließt sich, der Kampf beginnt.
func _drin() -> void:
	einzug = {}
	_aktion = {}
	_weg.clear()
	einheit.set_meta("hebt_ab", 0.0)
	einheit._sprite.bewegt(false)
	_bis_angriff = Werte.HERAUSFORDERER_ERSTER_ANGRIFF
	kampfplatz.licht_an()
	_drohne_aus(3.0)
	protokoll.append({"was": "drin", "bei": o24.zeit, "innen": kampfplatz.innen_px(einheit.position)})


func _drohne_aus(sek: float) -> void:
	if _drohne != null and is_instance_valid(_drohne):
		_drohne.aus(sek)
	_drohne = null


## Erscheinungsmusik (Platzhalter, bis das Ton-Paket ein eigenes Stück bringt): ein tiefer Drone aus drei Sinustönen,
## der in 2 s anschwillt und langsam pulsiert. Lautstärke wie die Musik.
class Drohne extends AudioStreamPlayer:
	const RATE := 22050.0
	const TOENE := [55.0, 82.4, 110.6]
	const ANTEIL := [0.5, 0.3, 0.15]
	var _phase := [0.0, 0.0, 0.0]
	var _t := 0.0
	var _aus := -1.0
	var _aus_sek := 1.0

	func _ready() -> void:
		var g := AudioStreamGenerator.new()
		g.mix_rate = RATE
		g.buffer_length = 0.3
		stream = g
		volume_db = -4.0 + Musik.prozent_db(Werte.musik)
		process_mode = Node.PROCESS_MODE_ALWAYS
		play()

	func aus(sek: float) -> void:
		_aus = 0.0
		_aus_sek = maxf(0.05, sek)

	func _process(delta: float) -> void:
		if _aus >= 0.0:
			_aus += delta
			if _aus >= _aus_sek:
				queue_free()
				return
		var pb := get_stream_playback() as AudioStreamGeneratorPlayback
		if pb == null:
			return
		for i in mini(pb.get_frames_available(), 4096):
			_t += 1.0 / RATE
			var pegel := clampf(_t / 2.0, 0.0, 1.0) * (1.0 - clampf(_aus / _aus_sek, 0.0, 1.0) if _aus >= 0.0 else 1.0)
			var s := 0.0
			for j in 3:
				_phase[j] = fmod(float(_phase[j]) + TAU * float(TOENE[j]) / RATE, TAU)
				s += sin(float(_phase[j])) * float(ANTEIL[j])
			s *= pegel * (0.75 + 0.25 * sin(_t * TAU * 0.5)) * 0.4
			pb.push_frame(Vector2(s, s))



# ------------------------------------------------------------------ Er spielt wie Brakk (Punkt 4)

func _physics_process(_takt: float) -> void:
	if zustand != "duell" or o24 == null or not o24.laeuft or o24.vorbei or spiel.phase != 1:
		return
	# echte Sekunden (Spieltempo = SPIELTEMPO × BRAKK_TEMPO), in der Zeitlupe entsprechend langsamer
	schritt(Werte.sim_schritt() / (Werte.SPIELTEMPO * Werte.BRAKK_TEMPO))


## brakk_geschosse.gd zählt mit „Spielsekunden / BRAKK_TEMPO“ – eine seiner Sekunden dauert 1/SPIELTEMPO echte.
## Für Bilder, die so lange stehen sollen wie `echt` Sekunden:
static func _bg(echt: float) -> float:
	return echt * Werte.SPIELTEMPO


## Ein Schritt des Duells (`dt` in echten Sekunden).
func schritt(dt: float) -> void:
	var k: Kommandant = spiel.kommandant
	if k == null or k.gefallen or einheit == null or not is_instance_valid(einheit) or einheit.kampfunfaehig:
		return
	if not einzug.is_empty():
		einheit.halt = true
		_einzug_weiter(dt)
		_aussehen(k)
		return
	if kampfplatz.zu() and _aktion.is_empty() and not kampfplatz.innen_px(einheit.position):
		einheit.position = o24.karte.mitte(kampfplatz._frei_innen(o24.karte.zelle_bei(einheit.position)))   # C1: geschoben – zurück hinein
	uhr += dt   # H-6
	if _brakk_vorher != Vector2.INF and dt > 0.0:
		brakk_v = brakk_v.lerp(((k.position - _brakk_vorher) / dt).limit_length(6.0 * Werte.ZELLE), 0.35)   # H-2: für vorausberechnete Ziele (Sprünge des Ankers gedeckelt)
	_brakk_vorher = k.position
	_ausweich_rest -= dt
	_wall_abkling -= dt
	_aktion_in -= dt   # sein Takt läuft auch während der Angriffe; ausgeführt wird erst in der nächsten Bewegung
	einheit.halt = true   # nichts anderes steuert ihn
	_wut_pruefen()
	if not zaehlung.is_empty() and str(angriff.get("art", "")) != "sturm":   # H-11: mittlerer Abstand außerhalb der Stürme
		zaehlung["abstand_summe"] = float(zaehlung.get("abstand_summe", 0.0)) + einheit.position.distance_to(k.position) / Werte.ZELLE * dt
		zaehlung["abstand_zeit"] = float(zaehlung.get("abstand_zeit", 0.0)) + dt
	_vergeltung_weiter(dt)
	anvisiert = Vector2.INF
	anvisiert_balken = -1.0
	anvisiert_text = ""
	gebunden_rest = maxf(0.0, gebunden_rest - dt)
	if druck:   # G2-3: lila Puls-Umriss
		_druck_seit += dt
		einheit.set_meta("nemesis_umriss", DRUCK_UMRISS.lerp(Color("4a2470"), 0.5 + 0.5 * sin(_druck_seit * 9.0)))
	_reihe_weiter(dt)   # H-1
	_saeule_steht_weiter(dt)   # H-7
	if klon != null:
		klon.weiter(dt, k)   # H-8
	typ.immer(dt, k)
	if greift_an():
		_angriff_weiter(dt, k)
	elif not _aktion.is_empty():
		_aktion_weiter(dt)
	elif typ.steht():
		einheit._sprite.bewegt(false)   # C3: Sonde 7 am Boden – ihr Fenster
	else:
		_bis_angriff -= dt
		var d := einheit.position.distance_to(k.position) / Werte.ZELLE
		if _bis_angriff <= 0.0 and d <= Werte.HERAUSFORDERER_ANGRIFF_WEITE and sieht(einheit.position, k.position):
			var art := _wartend if _wartend != "" else naechster_angriff(d)
			if art != "" and not darf_beginnen(art, d):
				if _wartend == "":
					_wartet_seit = 0.0
				_wartend = art   # H-6: der Boden ist markiert (oder er ist noch nicht bereit) – er bewegt sich und wartet
				_wartet_seit += dt
				_bewegen(dt, k)
			elif art != "":
				_wartend = ""
				beginne_angriff(art)
			# "" = G2-2: erst auf die Krone (der Angriff folgt oben)
		else:
			_bewegen(dt, k)
	_aussehen(k)


## Er hält Brakks Lieblingsabstand, springt und tumbelt in dessen Takt, weicht dem Ladestrahl aus und nutzt Wallkronen.
func _bewegen(dt: float, k: Kommandant) -> void:
	if _ausweich_rest <= 0.0 and zielt_ladestrahl_auf_ihn():
		_ausweich_rest = Werte.HERAUSFORDERER_AUSWEICH_PAUSE
		zaehler["ausweichen"] += 1
		tumble(str(kennwerte.get("selten", "rechts")))
		return
	if _wall_rest > 0.0:
		_wall_rest -= dt
		if _wall_rest <= 0.0:
			if typ.krone_mit_angriff() and _krone_angriffe < 1 and _krone_warte < Werte.BOSS_SNIPER_KRONE_SEK:
				_wall_rest = 0.25   # F5 (26.11., Paul): erst ein Angriff von dieser Krone
				_krone_warte += 0.25
			else:
				if typ.krone_mit_angriff() and _krone_angriffe < 1:
					kronen_ohne_angriff += 1
				_vom_wall()
		return
	if _wall_abkling <= 0.0 and typ.wall_abkling() < INF and (k.oben or bool(kennwerte.get("wall", false)) or typ.wall_abkling() < 9.0):
		_wall_abkling = typ.wall_abkling()   # C2: der Scharfschütze wechselt oft die Krone, der Technogunner nie
		if _auf_den_wall(k):
			return
	if _aktion_in <= 0.0:
		_aktion_in = typ.takt(float(kennwerte.get("takt", 4.0))) * randf_range(0.75, 1.25)
		var seite := str(kennwerte.get("seite", ""))
		if seite == "" or randf() > 0.65:
			seite = "links" if randf() < 0.5 else "rechts"
		if randf() < typ.sprung_anteil(float(kennwerte.get("sprung_anteil", 0.4))):
			sprung(seite)
		else:
			tumble(seite)
		return
	_laufe(dt, k, typ.abstand(float(kennwerte.get("abstand", Werte.HERAUSFORDERER_ABSTAND_SONST))) * (typ.druck_abstand_mal() if druck else 1.0), tempo())   # G2-3: in der Druckphase näher (H-4: der Scharfschütze nicht)


## Auf Lieblingsabstand gehen: alle halbe Sekunde ein Feld mit Sicht in der Nähe wählen, dessen Abstand passt.
func _laufe(dt: float, k: Kommandant, abstand: float, v: float) -> void:
	var e := einheit
	var karte: Karte = o24.karte
	_weg_neu -= dt
	if _weg_neu <= 0.0 or _weg.is_empty():
		_weg_neu = 0.5
		var hier := karte.zelle_bei(e.position)
		var d := e.position.distance_to(k.position) / Werte.ZELLE
		_weg.clear()
		if d > abstand + 4.0 or not karte.sicht_frei(e.position, k.position):
			var ziel := o24._erreichbar_nahe(karte.zelle_bei(k.position), hier)
			var pfad := karte.einheiten_weg(hier, ziel)
			for i in mini(3, pfad.size()):
				if not _begehbar(pfad[i]) or not typ.feld_ok(pfad[i]):
					break   # C1: nicht durch die Lichtwand
				_weg.append(karte.mitte(pfad[i]))
		else:
			var beste := hier
			var wert := -INF
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var z := hier + Vector2i(dx, dy)
					if not _begehbar(z) or not typ.feld_ok(z):
						continue
					var p := karte.mitte(z)
					var w := -absf(p.distance_to(k.position) / Werte.ZELLE - abstand) * 2.0 + (4.0 if karte.sicht_frei(p, k.position) else 0.0) + randf() * 1.2 - 0.15 * Vector2(dx, dy).length()
					if w > wert:
						wert = w
						beste = z
			if beste != hier:
				_weg.append(karte.mitte(beste))
	var rest := v * Werte.ZELLE * dt
	e._sprite.bewegt(not _weg.is_empty())
	while rest > 0.0 and not _weg.is_empty():
		var ziel_p: Vector2 = _weg[0]
		var strecke := e.position.distance_to(ziel_p)
		if strecke <= rest:
			e.position = ziel_p
			_weg.pop_front()
			rest -= strecke
		else:
			e.position = e.position.move_toward(ziel_p, rest)
			rest = 0.0


## C1: Ist die Lichtwand zu, nur Felder im Platz.
func _begehbar(z: Vector2i) -> bool:
	return o24.karte.in_karte(z) and o24.karte.ist_begehbar(z) and o24.karte.ist_frei(z) and (not kampfplatz.zu() or kampfplatz.innen(z))


## Landepunkt `weit` Felder zur Seite (aus seiner Sicht, mit Blick zu Brakk); geht es dort nicht, die andere Seite.
## Vector2.INF = nirgends Platz.
func seitwaerts(seite: String, weit: float) -> Vector2:
	var k: Kommandant = spiel.kommandant
	var zu := (k.position - einheit.position).normalized()
	var rechts := Vector2(-zu.y, zu.x)
	var richtungen := {"links": -rechts, "rechts": rechts, "zurueck": -zu, "vor": zu}
	for s: String in [seite, "rechts" if seite == "links" else "links", "zurueck"]:
		var r: Vector2 = richtungen.get(s, rechts)
		for anteil: float in [1.0, 0.6]:
			var p := einheit.position + r * weit * anteil * Werte.ZELLE
			if _begehbar(o24.karte.zelle_bei(p)) and _begehbar(o24.karte.zelle_bei(einheit.position.lerp(p, 0.5))) and (typ == null or typ.feld_ok(o24.karte.zelle_bei(p))):
				return p
	return Vector2.INF


## Tumble: ein schneller Seitschritt mit Staub. C2: Wer nicht tumbelt (Plasmawerfer), macht einen langsamen Seitschritt.
func tumble(seite: String) -> void:
	var ziel := seitwaerts(seite, Werte.HERAUSFORDERER_TUMBLE_WEIT)
	if ziel == Vector2.INF:
		return
	if typ != null and not typ.tumble_ok():
		_aktion = {"art": "lauf", "t": 0.0, "sek": Werte.BOSS_SEITSCHRITT_SEK, "von": einheit.position, "nach": ziel}
		_weg.clear()
		return
	_aktion = {"art": "tumble", "t": 0.0, "sek": Werte.HERAUSFORDERER_TUMBLE_SEK, "von": einheit.position, "nach": ziel}
	_weg.clear()
	zaehler["tumble"] += 1
	spiel.effekte.flaeche(einheit.position, Werte.ZELLE * 0.45, Color(0.75, 0.68, 0.55))


## Sprung: er hebt im Bogen ab (wie die Hunde beim Sprung) und landet ein Stück zur Seite.
func sprung(seite: String) -> void:
	var ziel := seitwaerts(seite, 1.2)
	if ziel == Vector2.INF:
		ziel = einheit.position
	_aktion = {"art": "sprung", "t": 0.0, "sek": Werte.HERAUSFORDERER_SPRUNG_SEK, "von": einheit.position, "nach": ziel}
	_weg.clear()
	zaehler["sprung"] += 1


func _aktion_weiter(dt: float) -> void:
	_aktion["t"] = float(_aktion["t"]) + dt
	var a := clampf(float(_aktion["t"]) / float(_aktion["sek"]), 0.0, 1.0)
	var vorlauf := float(_aktion.get("vorlauf", 0.0))   # C2: Anker – erst steht das Seil, dann der Zug
	if vorlauf > 0.0:
		a = clampf((float(_aktion["t"]) - vorlauf) / (float(_aktion["sek"]) - vorlauf), 0.0, 1.0)
	einheit.position = (_aktion["von"] as Vector2).lerp(_aktion["nach"] as Vector2, a)
	var schweben := typ.schwebe() if typ != null else 0.0   # C3: Sonde 7 schwebt
	einheit.set_meta("hebt_ab", schweben + (4.0 * a * (1.0 - a) * Werte.BRAKK_SPRUNG_HOEHE_FELD * float(_aktion.get("hoch", 1.0)) if str(_aktion["art"]) == "sprung" else 0.0))
	einheit._sprite.bewegt(str(_aktion["art"]) == "lauf")
	if a >= 1.0:
		if str(_aktion["art"]) == "tumble":
			spiel.effekte.flaeche(einheit.position, Werte.ZELLE * 0.35, Color(0.75, 0.68, 0.55))
		_aktion = {}
		einheit.set_meta("hebt_ab", schweben)


## F5 (26.11., Paul): Sieht er Brakk von `von` aus? Auf einer Wallkrone wie eine Stellung: über das eigene Wallstück
## hinweg (vorher versperrte ihm das Nachbarfeld seiner Krone die Sicht – er griff von oben nie an).
func sieht(von: Vector2, nach: Vector2) -> bool:
	var karte: Karte = o24.karte
	var z := karte.zelle_bei(von)
	if einheit != null and is_instance_valid(einheit) and einheit.zustand == Einheit.Zustand.AUF_POSTEN and karte.inhalt(z) == Karte.WALL:
		return karte.sicht_von_wall(z, von, nach)
	return karte.sicht_frei(von, nach)


## Auf eine Wallkrone in der Nähe, von der er Brakk im Lieblingsabstand sieht. Oben zählt er wie in einer Stellung.
func _auf_den_wall(k: Kommandant) -> bool:
	var karte: Karte = o24.karte
	var hier := karte.zelle_bei(einheit.position)
	var abstand := float(kennwerte.get("abstand", 7.0))
	var beste := Karte.KEINE
	var wert := INF
	var platz := kampfplatz.zu()
	var r := 6 if platz else 4   # F2: im Platz liegen die Kronen am Rand – weiter suchen
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var z := hier + Vector2i(dx, dy)
			if not karte.in_karte(z) or karte.inhalt(z) != Karte.WALL or karte.zelle_bei(k.position) == z:
				continue
			if (platz and not kampfplatz.innen(z)) or karte.ausbau.has(z):
				continue   # F2 (26.11., Paul): im Kampfplatz auf den Randring (herunter springt er nach innen, _vom_wall); C2: nicht in Stellungen
			if not karte.sicht_von_wall(z, karte.mitte(z), k.position):
				continue   # F5 (26.11., Paul): nur Kronen, von denen er Brakk sieht – sonst hüpft er oben nur herum
			var w := absf(karte.mitte(z).distance_to(k.position) / Werte.ZELLE - abstand) - (2.0 if kampfplatz.ist_krone(z) else 0.0)   # F2: die Kronen des Randrings bevorzugt
			if w < wert:
				wert = w
				beste = z
	if beste == Karte.KEINE or wert > 5.0:
		return false
	_aktion = typ.weg_auf_krone(einheit.position, karte.mitte(beste))   # C2: Sprung, beim Scharfschützen der Anker
	_weg.clear()
	_wall_rest = randf_range(Werte.HERAUSFORDERER_WALL_SEK.x, Werte.HERAUSFORDERER_WALL_SEK.y)
	einheit.zustand = Einheit.Zustand.AUF_POSTEN   # Höhe: die HD-Ansicht und Brakks Waffen sehen ihn oben
	_krone_angriffe = 0
	_krone_warte = 0.0
	zaehler["wall"] += 1
	return true


func _vom_wall() -> void:
	var karte: Karte = o24.karte
	var unten := karte.mitte(o24._freies_feld_bei(einheit.position, karte.zelle_bei((spiel.kommandant as Kommandant).position)))
	if kampfplatz.zu() and not kampfplatz.im_innern(karte.zelle_bei(unten)):
		unten = karte.mitte(kampfplatz._frei_innen(karte.zelle_bei(einheit.position)))   # C1: herunter nur nach innen
	einheit.zustand = Einheit.Zustand.BODEN
	_wall_rest = 0.0
	_aktion = {"art": "sprung", "t": 0.0, "sek": Werte.HERAUSFORDERER_SPRUNG_SEK, "von": einheit.position, "nach": unten}


## Lädt Brakk den Ladestrahl und zielt auf ihn?
func zielt_ladestrahl_auf_ihn() -> bool:
	var ego: EgoModus = spiel.ego
	if ego == null or ego._lanze < 0.25 or einheit == null:
		return false
	var blick := Vector2(-sin(ego.gier), -cos(ego.gier))
	var zu := einheit.position - (spiel.kommandant as Kommandant).position
	return zu.length() <= EgoModus.LANZE_WEITE * Werte.ZELLE and absf(blick.angle_to(zu)) < deg_to_rad(9.0)


func _aussehen(k: Kommandant) -> void:
	einheit._sprite.flip_h = k.position.x < einheit.position.x
	einheit.queue_redraw()



# ------------------------------------------------------------------ Drei Angriffe (Punkt 5)
## Jeder Angriff kündigt sich mindestens 0,5 s an, seine Geschosse fliegen sichtbar, und danach steht er ein Fenster lang
## verwundbar da. Ab halbem Leben werden die Fenster kürzer, und die Angewohnheiten der Person kommen dazu.

const ANGRIFFE: Array[String] = ["salve", "kugel", "sturm"]


## Welcher Angriff als Nächstes? Nie derselbe dreimal in Folge; die Entfernung (Felder) gewichtet.
## C2: `eigene` – die Gewichte des Bosstyps (leer: Salve, Kugel, Sturm).
static func waehle_angriff(abstand: float, letzte: Array, eigene: Dictionary = {}) -> String:
	var gewichte := eigene.duplicate() if not eigene.is_empty() else {"salve": 1.0, "kugel": 1.0 if abstand >= 3.0 else 0.4, "sturm": 1.7 if abstand < 5.0 else (1.0 if abstand < 9.0 else 0.5)}
	if gewichte.size() == 1:
		return str(gewichte.keys()[0])   # ein erzwungener Angriff (z. B. die Zielmarkierung)
	if letzte.size() >= 2 and str(letzte[-1]) == str(letzte[-2]):
		gewichte.erase(str(letzte[-1]))
	var summe := 0.0
	for a: String in gewichte:
		summe += float(gewichte[a])
	var z := randf() * summe
	for a: String in gewichte:
		z -= float(gewichte[a])
		if z <= 0.0:
			return a
	return str(gewichte.keys().back())


func greift_an() -> bool:
	return not angriff.is_empty()


## Beginnt einen Angriff (auch für den Test).
func beginne_angriff(art: String) -> void:
	var k: Kommandant = spiel.kommandant
	if not schritt_jetzt.is_empty() and art != str(schritt_jetzt.get("art", "")) and art != str(schritt_jetzt.get("dann", "")):
		schritt_jetzt = {}   # G2-2: eine Reaktion (Schrotstoß) oder ein Test – nicht Teil der Abfolge
	_aktion = {}
	_weg.clear()
	einheit.set_meta("hebt_ab", 0.0)
	_letzte.append(art)
	angriffe_je_art[art] = int(angriffe_je_art.get(art, 0)) + 1   # F5
	if art == "sturm" and _letzte.size() >= 2 and str(_letzte[-2]) == "sturm" and not zaehlung.is_empty():
		zaehlung["doppelstuerme"] = int(zaehlung.get("doppelstuerme", 0)) + 1   # H-11
	if einheit.zustand == Einheit.Zustand.AUF_POSTEN:
		_krone_angriffe += 1
	angriff = {"art": art, "teil": "ansage", "t": 0.0, "um": 0.0, "angesagt": 0.0, "ziel": k.position, "richtung": (k.position - einheit.position).normalized(),
		"nr": _letzte.size()}   # G2: Nummer im Duell (Zählung)
	var boden_sek := typ.boden_sek(art) if typ != null else -1.0
	if boden_sek >= 0.0:
		boden_belegen("boss", boden_sek)   # H-6: seine Markierung am Boden (Linien, Kreis, Mörser …)
	if typ != null and typ.beginne(art):
		return   # C2: ein Angriff des Bosstyps
	match art:
		"salve":
			_salve_ansage()
		"kugel":
			_kugel_ansage()
		"sturm":
			angriff["teil"] = "anlauf"
		"doppel":
			_doppel_ansage()
		"strahl":
			_strahl_ansage()
		"saeule":
			_saeule_ansage()


func _angriff_weiter(dt: float, k: Kommandant) -> void:
	var a := angriff
	a["t"] = float(a["t"]) + dt
	var t := float(a["t"])
	var art := str(a["art"])
	match str(a["teil"]):
		"anlauf":   # Sturm: er läuft auf Brakk zu
			var d := einheit.position.distance_to(k.position) / Werte.ZELLE
			if d <= Werte.HERAUSFORDERER_STURM_NAH or t >= Werte.HERAUSFORDERER_STURM_ANLAUF:
				a["teil"] = "ansage"
				a["t"] = 0.0
				_sturm_ansage()
			else:
				_laufe(dt, k, 0.8, tempo() * Werte.HERAUSFORDERER_STURM_TEMPO)
		"ansage":
			einheit._sprite.bewegt(false)
			var rot := 0.55 + 0.45 * sin(t * 26.0)
			einheit._sprite.modulate = Color(1.0, 1.0 - 0.75 * rot, 1.0 - 0.75 * rot)   # rotes Aufleuchten
			if art == "saeule":
				_saeule_vorschau(clampf(t / float(a["um"]), 0.0, 1.0), dt)
			if t >= float(a["um"]):
				a["angesagt"] = t
				einheit._sprite.modulate = Color.WHITE
				if braucht_sicht(art) and not sieht(einheit.position, k.position):
					_ohne_sicht(art)   # H-5: keine Sicht aus seiner Höhe – Schritt überspringen, Schussfeld suchen
					return
				if typ != null and typ.feuer(art, k):
					pass   # C2: ein Angriff des Bosstyps
				else:
					match art:
						"salve":
							_salve_feuer()
						"kugel":
							_kugel_feuer()
						"sturm":
							_sturm_schlag(k)
						"doppel":
							_doppel_feuer()
						"strahl":
							_strahl_feuer()
						"saeule":
							_saeule_feuer(k)
				if str(a["teil"]) == "typ":
					pass   # C2: der Bosstyp führt weiter und ruft fenster()
				elif art == "saeule" and typ != null and typ.nach_saeule(k):
					pass   # H-7: der Scharfschütze legt das Laservisier nach (Kombo)
				elif art == "salve" and ring_kopie() == "minigun" and not bool(a.get("zweite", false)):
					_zweite_salve(k)
				else:
					fenster(typ.fenster_mal(art) if typ != null else 1.0)
		"typ":
			typ.weiter_angriff(dt, k)
		"fenster":   # er steht und ist verwundbar
			einheit._sprite.bewegt(false)
			if t >= float(a["um"]):
				protokoll.append({"was": "fenster_ende", "bei": o24.zeit, "dauer": t})
				if not zaehlung.is_empty():   # H-11: verwundbare Zeit und die davon mit Treffern
					zaehlung["fenster_zeit"] = float(zaehlung.get("fenster_zeit", 0.0)) + t
					if bool(a.get("getroffen", false)):
						zaehlung["fenster_getroffen_zeit"] = float(zaehlung.get("fenster_getroffen_zeit", 0.0)) + t
				angriff = {}
				_bis_angriff = float(schritt_jetzt["bewegung"]) if schritt_jetzt.has("bewegung") else randf_range(Werte.HERAUSFORDERER_BEWEGEN.x, Werte.HERAUSFORDERER_BEWEGEN.y)   # G2-2


## Nach dem Angriff steht er verwundbar da. C2: `mal` – der Bosstyp kann es kürzen (z. B. nach dem Sturm mit Gel).
func fenster(mal: float = 1.0) -> void:
	# G2-2: gekoppelter Angriff (Ankerwurf → Minigun, Markierung → Schubeinschlag) – gleich danach, ohne Fenster
	if schritt_jetzt.has("dann") and not bool(schritt_jetzt.get("dann_lief", false)) and str(angriff.get("art", "")) != str(schritt_jetzt["dann"]):
		schritt_jetzt["dann_lief"] = true
		protokoll.append({"was": "angriff", "bei": o24.zeit, "art": str(angriff["art"]), "angesagt": float(angriff["angesagt"]), "fenster": 0.0, "wut": wut, "dann": str(schritt_jetzt["dann"])})
		angriff = {}
		beginne_angriff(str(schritt_jetzt["dann"]))
		if schritt_jetzt.has("dann_sek"):
			angriff["sek"] = float(schritt_jetzt["dann_sek"])
		abfolge_log.append({"i": int(schritt_jetzt.get("i", -1)), "art": str(schritt_jetzt["dann"]), "bei": o24.zeit, "druck": bool(schritt_jetzt.get("druck", false)), "dann": true})
		return
	var dauer := randf_range(Werte.HERAUSFORDERER_FENSTER.x, Werte.HERAUSFORDERER_FENSTER.y) * (Werte.HERAUSFORDERER_WUT_FENSTER if wut else 1.0) * mal
	if schritt_jetzt.has("fenster"):
		dauer = float(schritt_jetzt["fenster"])   # G2-2: aus der Abfolge (Phase 2 steckt schon in der Tabelle)
	dauer *= Werte.HERAUSFORDERER_RING_TAKT_FENSTER if ring_kopie() == "feuerteam" else 1.0
	if bool(schritt_jetzt.get("druck_ende", false)):
		_druck_aus()   # G2-3: die Belohnung – der Boden kühlt, er steht lange
	protokoll.append({"was": "angriff", "bei": o24.zeit, "art": str(angriff["art"]), "angesagt": float(angriff["angesagt"]), "fenster": dauer, "wut": wut,
		"druck": bool(schritt_jetzt.get("druck", false)), "druck_ende": bool(schritt_jetzt.get("druck_ende", false))})
	angriff["teil"] = "fenster"
	angriff["t"] = 0.0
	angriff["um"] = dauer


## H-5: Kein Schuss in den Wall – der Angriff fällt aus (kein Fenster), er sucht ein Schussfeld: eine Rand-Krone mit
## Sicht oder seitwärts (der Lauf geht ohne Sicht ohnehin auf Brakk zu).
func _ohne_sicht(art: String) -> void:
	protokoll.append({"was": "ohne_sicht", "bei": o24.zeit, "art": art})
	angriff = {}
	_bis_angriff = 0.4
	if typ.wall_abkling() < INF and einheit.zustand != Einheit.Zustand.AUF_POSTEN and _auf_den_wall(spiel.kommandant):
		return
	tumble("links" if randf() < 0.5 else "rechts")


## Mündung (Bildpunkte) – etwas vor ihm in Schussrichtung.
func _muendung(richtung: Vector2) -> Vector2:
	return einheit.position + richtung * 0.35 * Werte.ZELLE


## H-5 (27.11., Paul): Mündungshöhe – in der aktuellen Höhe des Bosses (Krone aus der HD-Ansicht, Schweben, Sprung).
func _hoehe_er() -> float:
	return 0.5 + boden_h(einheit.position) + float(einheit.get_meta("hebt_ab", 0.0))


## H-5: Bodenhöhe an einem Punkt (Felder): auf einer Wallkrone die Wandhöhe der HD-Ansicht, sonst 0.
func boden_h(p: Vector2) -> float:
	var hd: HdAnsicht = spiel.hd
	return hd.H if hd != null and hd.ist_hoch(o24.karte.zelle_bei(p)) else 0.0


## H-5: Ziel = Mitte von Brakks Trefferzone in seiner aktuellen Höhe (Krone, Boden, Sprung).
func ziel_h() -> float:
	var ego: EgoModus = spiel.ego
	return (ego.hoehe if ego != null else 0.0) + 0.5


## H-5: Bodenmarkierungen liegen auf der Fläche, auf der Brakk steht (Krone oder Boden).
func markierung_h() -> float:
	var ego: EgoModus = spiel.ego
	return (ego._boden() if ego != null else 0.0) + 0.05


## H-2: Brakks vorausberechnete Position in `sek` Sekunden (aktuelle Position + Geschwindigkeit × Zeit), höchstens
## `max_felder` voraus.
func vorhersage(sek: float, max_felder: float) -> Vector2:
	var k: Kommandant = spiel.kommandant
	return k.position + (brakk_v * maxf(0.0, sek)).limit_length(max_felder * Werte.ZELLE)


## H-2 (27.11., Paul): Drei dünne Linien am Boden vom Schützen `e` aus = die Flugbahnen einer Welle, `vor` s vor dem Schuss:
## die mittlere durch Brakks vorausberechnete Position (Ansage + Flug, höchstens `vorhalt_max` Felder), die äußeren ±`winkel`°
## um seine aktuelle – Stehenbleiben und Weiterlaufen sind beide nicht sicher, der Tumble quer dazu schon. Gibt
## {"m": Mündung, "dirs": [3 Richtungen], "lang": [3 Längen]} zurück; salve_feuern() schießt genau darauf.
func salve_linien(e: Einheit, vor: float, winkel: float, vorhalt_max: float, tempo_felder: float, farbe: Color) -> Dictionary:
	var k: Kommandant = spiel.kommandant
	var zu := (k.position - e.position).normalized() if k.position.distance_to(e.position) > 1.0 else Vector2.RIGHT
	var m := e.position + zu * 0.35 * Werte.ZELLE
	var flug := m.distance_to(k.position) / maxf(1.0, tempo_felder * Werte.ZELLE)
	var ziel := vorhersage(vor + flug, vorhalt_max)
	var mitte := (ziel - m).normalized() if ziel.distance_to(m) > 1.0 else zu
	var jetzt := (k.position - m).normalized() if k.position.distance_to(m) > 1.0 else zu
	var dirs: Array = [jetzt.rotated(deg_to_rad(-winkel)), mitte, jetzt.rotated(deg_to_rad(winkel))]
	var laengen: Array = []
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var hoch := markierung_h()
	var weit := m.distance_to(k.position) + 2.0 * Werte.ZELLE
	for r: Vector2 in dirs:
		var lang := weit if k.oben else weite_bis_wand(m, r, weit)
		laengen.append(lang)
		bg._balken(bg._zu3d(m, hoch), bg._zu3d(m + r * lang, hoch), farbe, 0.035, _bg(vor + 0.12))
	return {"m": m, "dirs": dirs, "lang": laengen, "e": e}


## H-2: Die drei Schüsse einer Welle exakt entlang ihrer Linien (Mündung → Linienrichtung, Höhe nach H-5), Flug mit
## `tempo_felder` Feldern je echter Sekunde; die Welle trifft höchstens einmal.
func salve_feuern(l: Dictionary, menge: float, tempo_felder: float, zaehl: String = "", gruppe: int = -1, gruppe_max: int = 1, farbe: Color = Color(0, 0, 0, 0)) -> void:
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var e: Einheit = l.get("e", einheit)
	var m: Vector2 = l["m"]
	if gruppe < 0:
		_salven += 1
		gruppe = _salven
	var h0 := 0.5 + boden_h(e.position) + float(e.get_meta("hebt_ab", 0.0))
	for r: Vector2 in l["dirs"]:
		var vor := bg.geschosse.size()
		bg.schiesse("hf_salve", m, h0, menge, "herausforderer", quelle(), 1.0, m + r * 4.0 * Werte.ZELLE)
		if bg.geschosse.size() == vor:
			continue
		var g: Dictionary = bg.geschosse.back()
		g["r"] = r   # exakt die angesagte Linie
		g["d_ziel"] = maxf(1.0, m.distance_to((spiel.kommandant as Kommandant).position))
		g["lang"] = bg._bahn_ende(m, r, float(g["d_ziel"]))
		g["tempo"] = tempo_felder * Werte.ZELLE / Werte.SPIELTEMPO   # brakk_geschosse rechnet in seinen Sekunden (NemesisHerausforderer._bg)
		g["gruppe"] = gruppe
		g["gruppe_max"] = gruppe_max   # I-3: die 4er-Salve trifft höchstens zweimal
		if zaehl != "":
			g["zaehl"] = zaehl   # H-11: Treffer zählen unter dieser Art (z. B. „klon“)
		if farbe.a > 0.0:
			bg.faerben(g, farbe)   # Paul (27.11.): die Schüsse des Klons blau
		var wand := bg._lichtwand(m, m + r * float(g["lang"]))
		if wand != Vector2.INF:
			g["lang"] = maxf(1.0, m.distance_to(wand))
		_an_der_wand_enden(g)


## H-8: Sieht eine andere Figur (der Klon) Brakk?
func sieht_von(x: Einheit, nach: Vector2) -> bool:
	return o24.karte.sicht_frei(x.position, nach)


## H-5: Diese Angriffe schießen auf Brakk – vor dem Schuss braucht er Sicht aus seiner Höhe (sonst nie in den Wall).
func braucht_sicht(art: String) -> bool:
	if ring_kopie() == "durchschuss":
		return false   # mit dem Durchschlagring geht seine Salve durch Mauern
	return art in ["salve", "kugel", "doppel", "strahl", "salve5", "salve4"]


# ------------------------------------------------------------------ H-6: ein Bodeneffekt zugleich

## Ist der Boden frei von Markierungen anderer (`ausser` zählt nicht)?
func boden_frei(ausser: Array = []) -> bool:
	for wer: String in boden:
		if not ausser.has(wer) and float(boden[wer]) > uhr:
			return false
	return true


## `wer` markiert den Boden ab jetzt für `sek` Sekunden (überschreibt seinen bisherigen Eintrag).
func boden_belegen(wer: String, sek: float) -> void:
	var bis := uhr + maxf(0.0, sek)
	if float(boden.get(wer, -1.0)) > uhr:
		for i in range(boden_log.size() - 1, -1, -1):
			if str(boden_log[i]["wer"]) == wer:
				boden_log[i]["bis"] = bis
				break
	else:
		boden_log.append({"wer": wer, "von": uhr, "bis": bis})
	boden[wer] = bis


## `wer` gibt den Boden sofort frei.
func boden_freigeben(wer: String) -> void:
	if float(boden.get(wer, -1.0)) > uhr:
		boden_belegen(wer, 0.0)


## H-11 (27.11., Paul): Anteil der Duellzeit mit einer Bodenmarkierung (Prozent; Ziel < 25 %).
func boden_anteil() -> int:
	var teile: Array = []
	for e: Dictionary in boden_log:
		if float(e["bis"]) > float(e["von"]):
			teile.append([float(e["von"]), minf(float(e["bis"]), uhr)])
	teile.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var summe := 0.0
	var bis := -1.0
	for t: Array in teile:
		var von := maxf(float(t[0]), bis)
		if float(t[1]) > von:
			summe += float(t[1]) - von
		bis = maxf(bis, float(t[1]))
	return roundi(100.0 * summe / uhr) if uhr > 0.0 else 0


## Darf der Angriff jetzt beginnen? Mit Bodeneffekt nur auf freiem Boden; dazu fragt er seinen Typ (z. B. der
## Scharfschütze nach dem Sturm: erst wieder auf Abstand).
func darf_beginnen(art: String, abstand: float) -> bool:
	if typ != null and typ.boden_sek(art) >= 0.0 and not boden_frei(["boss"]):
		return false
	if _saeule_faellig_vorrang():
		return false   # H-7: die Vergeltung wartet schon zu lange – sie geht vor
	return typ == null or typ.bereit(art, abstand, _wartet_seit)


## H-6: Die Angriffe des nächsten Schritts der Abfolge (der wartende zuerst) – für Vorschauen wie den Reichweitenring.
func naechste_arten() -> Array:
	if _wartend != "":
		return [_wartend]
	if _abf.is_empty() or _abf_wut != wut:
		return []
	var st: Dictionary = _abf[_abf_i % _abf.size()]
	return (st["wahl"] as Array).duplicate() if st.has("wahl") else [str(st["a"])]


## a) Salve: drei Schüsse im Fächer. Er hebt die Waffe und leuchtet rot; die Bahnen liegen am Boden – durch die Lücke.
func _salve_ansage() -> void:
	angriff["um"] = Werte.HERAUSFORDERER_SALVE_ANSAGE
	einheit._sprite.angriff(Werte.HERAUSFORDERER_SALVE_ANSAGE + 0.2)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var r: Vector2 = angriff["richtung"]
	bg.aufblitzen(_muendung(r), Color("ff3b3b"))
	var weite := maxf(6.0 * Werte.ZELLE, einheit.position.distance_to(angriff["ziel"] as Vector2) + 2.0 * Werte.ZELLE)
	bg.kegel_bild(einheit.position, r, Werte.HERAUSFORDERER_SALVE_FAECHER, weite, Color("ff3b3b"), _bg(Werte.HERAUSFORDERER_SALVE_ANSAGE))
	Ton.am_ort(spiel, "tc-arc", einheit.position)


func _salve_feuer() -> void:
	var r: Vector2 = angriff["richtung"]
	var los := _feuere_salve.bind(r, einheit.position.distance_to(angriff["ziel"] as Vector2))
	if wut and NemesisGewohnheiten.von_person(person).has("tumble"):
		# Angewohnheit Doppelblitz: noch zweimal aufblitzen, der Schuss fällt erst nach dem Tumble-Fenster
		var bg: BrakkGeschosse = spiel.brakk_geschosse
		bg.aufblitzen(_muendung(r), Color("ffffff"))
		bg.spaeter(Werte.NEMESIS_DOPPELBLITZ * 0.5, bg.aufblitzen.bind(_muendung(r), Color("ffffff")))
		bg.spaeter(Werte.NEMESIS_DOPPELBLITZ, los)
		nem.gewohnheiten.gezeigt(einheit, "tumble")
	else:
		los.call()


func _feuere_salve(r: Vector2, weit: float) -> void:
	if einheit == null or not is_instance_valid(einheit) or einheit.kampfunfaehig:
		return
	_salven += 1
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	for grad: float in [-Werte.HERAUSFORDERER_SALVE_FAECHER, 0.0, Werte.HERAUSFORDERER_SALVE_FAECHER]:
		var punkt := einheit.position + r.rotated(deg_to_rad(grad)) * maxf(weit, 2.0 * Werte.ZELLE)
		bg.schiesse("hf_salve", _muendung(r), _hoehe_er(), schaden(), "herausforderer", quelle(), 1.0, punkt)
		(bg.geschosse.back() as Dictionary)["gruppe"] = _salven   # aus nächster Nähe trifft die Salve trotzdem nur einmal
		_an_der_wand_enden(bg.geschosse.back() as Dictionary)
	Ton.am_ort(spiel, "tc-blaster", einheit.position)


## b) Schwere Kugel: ein großes, langsames Geschoss mit Pfeil der Flugbahn am Boden; es platzt am Ziel.
func _kugel_ansage() -> void:
	angriff["um"] = Werte.HERAUSFORDERER_KUGEL_ANSAGE
	einheit._sprite.angriff(Werte.HERAUSFORDERER_KUGEL_ANSAGE + 0.2)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var ziel: Vector2 = angriff["ziel"]
	var g: Dictionary = Werte.BRAKK_GESCHOSS["hf_kugel"]
	var dauer := _bg(Werte.HERAUSFORDERER_KUGEL_ANSAGE) + einheit.position.distance_to(ziel) / (float(g["tempo"]) * Werte.ZELLE)
	var farbe := Color("ff6a2a")
	var r := (ziel - einheit.position).normalized()
	bg._balken(bg._zu3d(einheit.position, 0.07), bg._zu3d(ziel, 0.07), farbe, 0.09, dauer)
	for seite: float in [-1.0, 1.0]:   # Pfeilspitze
		bg._balken(bg._zu3d(ziel, 0.07), bg._zu3d(ziel - r.rotated(seite * 0.55) * 0.9 * Werte.ZELLE, 0.07), farbe, 0.09, dauer)
	bg._ring(bg._zu3d(ziel, 0.05), float(g["einschlag"]), farbe, dauer)
	spiel.effekte.warnung(ziel, dauer * Werte.BRAKK_TEMPO)   # Draufsicht und Minikarte (Spielsekunden)
	Ton.am_ort(spiel, "tc-grenade", einheit.position)


func _kugel_feuer() -> void:
	var r: Vector2 = angriff["richtung"]
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	bg.schiesse("hf_kugel", _muendung(r), _hoehe_er(), schaden(), "herausforderer", quelle(), 1.0, angriff["ziel"] as Vector2)
	var g: Dictionary = bg.geschosse.back()
	if ring_kopie() == "abpraller":
		g["danach"] = _kugel_springt
	if ring_kopie() == "brandfeld":
		g["brand_sek"] = Werte.HERAUSFORDERER_RING_BRAND_SEK
		g["brand_anteil"] = Werte.HERAUSFORDERER_RING_BRAND_ANTEIL


## c) Sturm: nach dem Anlauf liegt der Treffbereich als Kreis am Boden, dann schlägt er zu – rückwärts tumbeln.
func _sturm_ansage() -> void:
	angriff["um"] = Werte.HERAUSFORDERER_STURM_ANSAGE
	einheit._sprite.angriff(Werte.HERAUSFORDERER_STURM_ANSAGE + 0.2)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	bg._ring(bg._zu3d(einheit.position, markierung_h()), Werte.HERAUSFORDERER_STURM_RADIUS, Color("ff3b3b"), _bg(Werte.HERAUSFORDERER_STURM_ANSAGE))
	_treffbereich(einheit.position, Werte.HERAUSFORDERER_STURM_RADIUS, Werte.HERAUSFORDERER_STURM_ANSAGE)
	boden_belegen("boss", Werte.HERAUSFORDERER_STURM_ANSAGE)   # H-6: der Kreis liegt jetzt (der Anlauf war geschätzt)
	spiel.effekte.warnung(einheit.position, _bg(Werte.HERAUSFORDERER_STURM_ANSAGE) * Werte.BRAKK_TEMPO)
	Ton.am_ort(spiel, "tc-arc", einheit.position)


## Der Treffbereich als rote Fläche am Boden – sie wird bis zum Schlag immer kräftiger (der dünne Ring allein ging im
## Gras unter).
func _treffbereich(pos: Vector2, radius: float, sek: float, hoehe: float = -1.0) -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var scheibe := MeshInstance3D.new()
	var form := CylinderMesh.new()
	form.top_radius = radius
	form.bottom_radius = radius
	form.height = 0.02
	scheibe.mesh = form
	var stoff := o24._leucht(Color("ff2a2a"), 0.2)
	scheibe.material_override = stoff
	hd.add_child(scheibe)
	scheibe.position = Vector3(pos.x / Werte.ZELLE, (hoehe if hoehe >= 0.0 else markierung_h()) - 0.01, (pos.y - Werte.KARTE_OBEN) / Werte.ZELLE)   # H-5: auf Brakks Fläche (J-1: oder der angegebenen)
	var tw := scheibe.create_tween()
	tw.set_ignore_time_scale(true)   # echte Sekunden, wie die Ankündigung
	tw.tween_property(stoff, "albedo_color:a", 0.5, sek)
	tw.tween_callback(scheibe.queue_free)


func _sturm_schlag(k: Kommandant) -> void:
	var radius := Werte.HERAUSFORDERER_STURM_RADIUS * Werte.ZELLE
	spiel.effekte.flaeche(einheit.position, radius, Color("ff5a4a"))
	Ton.am_ort(spiel, "hit-boom", einheit.position)
	var ego: EgoModus = spiel.ego
	var sprunghoehe := (ego.hoehe - ego._boden()) if ego != null else 0.0
	if k.unverwundbar > 0.0 or sprunghoehe > Werte.HERAUSFORDERER_STURM_SPRUNG or k.position.distance_to(einheit.position) > radius + Werte.BRAKK_RUMPF * Werte.ZELLE:
		return
	(spiel.brakk_geschosse as BrakkGeschosse)._treffe_brakk(schaden(), "herausforderer", quelle(), einheit.position, true)


# ------------------------------------------------------------------ Ab halbem Leben

func _wut_pruefen() -> void:
	if wut or einheit.leben >= einheit.max_leben * Werte.HERAUSFORDERER_WUT_ANTEIL:
		return
	wut = true
	einheit.set_meta("wut", true)
	protokoll.append({"was": "wut", "bei": o24.zeit})
	var ag := NemesisGewohnheiten.von_person(person)
	var schild := einheit.get_node_or_null("Frontschild") as CanvasItem
	if schild != null:
		schild.visible = true
	if ag.has("klon"):
		nem.gewohnheiten.doppelgaenger(einheit, person, einheit.fabrik_zelle)
	var namen := PackedStringArray(ag.map(func(x: Variant) -> String: return NemesisGewohnheiten.name_von(str(x))))
	spiel.melde("%s wird gefährlicher%s." % [str(person["name"]), (" – " + ", ".join(namen)) if not namen.is_empty() else ""], 3.5)
	typ.wut()   # C2: Phase 2 des Bosstyps



# ------------------------------------------------------------------ Vergeltung (Punkt 6)
## Alle HERAUSFORDERER_VERGELTUNG_ABKLING s kopiert er für HERAUSFORDERER_VERGELTUNG_SEK s, was Brakk im Lauf am meisten
## genutzt hat (lila Umriss, Ansage). Eine Waffe ersetzt in der Zeit seine Angriffe, ein Ring verändert sie.

const WAFFEN := {"pistole": "Pistolen", "lanze": "Ladestrahl", "saeule": "Lichtsäule"}
const WAFFEN_ANGRIFF := {"pistole": "doppel", "lanze": "strahl", "saeule": "saeule"}
const VERGELTUNG_TEXT := {
	"pistole": "schnelle Doppelschüsse",
	"lanze": "ein Ladestrahl – raus aus der Ziellinie",
	"saeule": "eine Lichtsäule – raus aus dem Kreis",
	"durchschuss": "seine Salve geht durch Mauern",
	"laser": "jeder Treffer ist stärker",
	"markierung": "nach einem Treffer bist du markiert – der nächste sitzt härter",
	"feuerteam": "seine verwundbaren Fenster sind kürzer",
	"minigun": "zwei Salven nacheinander",
	"bollwerk": "er nimmt weniger Schaden",
	"abpraller": "seine Kugel springt weiter und platzt ein zweites Mal",
	"brandfeld": "seine Kugel hinterlässt Feuer",
	"plasmagel": "seine Treffer bremsen dich",
}
## Ringe, deren Wirkung an einem bestimmten Angriff hängt: den bevorzugt er solange
const RING_ANGRIFF := {"durchschuss": "salve", "minigun": "salve", "abpraller": "kugel", "brandfeld": "kugel"}


## Was er kopiert. Verglichen werden Ladestrahl, Lichtsäule und Ring nach ihrem Schaden (`quellen`); beim Ring zählt der,
## den Brakk am längsten aktiv hatte (`zaehler`: „aktiv_<ring>“ in Sekunden). Pistolen nur, wenn nichts davon genutzt
## wurde – sie machen fast immer den meisten Schaden.
static func waehle_vergeltung(quellen: Dictionary, zaehler_brakk: Dictionary) -> Dictionary:
	var ring := ""
	var laengste := 0.0
	for r: String in BrakkFortschritt.RINGE:
		var sek := float(zaehler_brakk.get("aktiv_" + r, 0.0))
		if sek > laengste:
			laengste = sek
			ring = r
	var werte := {"lanze": float(quellen.get("lanze", 0.0)), "saeule": float(quellen.get("saeule", 0.0)), "ring": float(quellen.get("ring", 0.0)) if ring != "" else 0.0}
	var beste := ""
	var hoechster := 0.0
	for art: String in werte:
		if float(werte[art]) > hoechster:
			hoechster = float(werte[art])
			beste = art
	if beste == "":
		beste = "ring" if ring != "" else "pistole"
	if beste == "ring":
		return {"art": "ring", "ring": ring, "name": str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring))}
	return {"art": beste, "ring": "", "name": str(WAFFEN[beste])}


## Der kopierte Ring ("" = gerade keiner).
func ring_kopie() -> String:
	return str(vergeltung.get("ring", ""))


## H-7 (27.11., Paul): Die Vergeltung ist immer die Lichtsäule (alle Bosse) – die Statistik der meistgenutzten Quelle
## entfällt für die Wahl (waehle_vergeltung, VERGELTUNG_TEXT, RING_ANGRIFF und WAFFEN_ANGRIFF bleiben im Code; nemesis_lernen
## behält die Zahlen für die Karte). Takt wie bisher (erstmals HERAUSFORDERER_VERGELTUNG_ERSTE, dann alle …_ABKLING s),
## aber sie wartet, bis der Boden frei ist – höchstens BOSS_SAEULE_VERZUG s, dann geht sie dem nächsten Schritt vor.
func _vergeltung_weiter(dt: float) -> void:
	marke_rest = maxf(0.0, marke_rest - dt)
	gel_rest = maxf(0.0, gel_rest - dt)
	_vergeltung_in -= dt
	if not vergeltung.is_empty():   # nur noch aus dem Test (vergeltung_an)
		vergeltung["rest"] = float(vergeltung["rest"]) - dt
		if float(vergeltung["rest"]) <= 0.0:
			vergeltung_aus()
		return
	if _saeule_umriss_bis >= 0.0 and uhr >= _saeule_umriss_bis and stehende_saeule.is_empty():
		_saeule_umriss_bis = -1.0
		einheit.set_meta("nemesis_umriss", DRUCK_UMRISS if druck else Nemesis.umriss_farbe(person))
	if _vergeltung_in > 0.0:
		_saeule_verzug = 0.0
		return
	_saeule_verzug += dt
	if not greift_an() and _aktion.is_empty() and boden_frei() and not typ.steht() and typ.vergeltung_ok():
		lichtsaeule_an()


## H-7: Wartet die fällige Säule schon länger als BOSS_SAEULE_VERZUG s? Dann beginnt kein neuer Schritt mehr vor ihr.
func _saeule_faellig_vorrang() -> bool:
	return _vergeltung_in <= 0.0 and vergeltung.is_empty() and _saeule_verzug >= Werte.BOSS_SAEULE_VERZUG


## H-7: Vergeltung: Lichtsäule – Ansage BOSS_SAEULE_ANSAGE s mit derselben Vorschau wie Brakks Lichtsäule (Standardkreis –
## die Bosse tragen keinen Ring) auf dem Ziel des Bosstyps (typ.saeule_ziel: Brakks vorausberechnete Position, beim
## Technogunner und Plasmawerfer als Wegsperre), dann steht sie BOSS_SAEULE_SEK s mit BOSS_SAEULE_JE_SEK je Sekunde.
func lichtsaeule_an() -> void:
	var k: Kommandant = spiel.kommandant
	_vergeltung_in = Werte.HERAUSFORDERER_VERGELTUNG_ABKLING
	_saeule_verzug = 0.0
	schritt_jetzt = {}   # kein Schritt der Abfolge
	var ziel := typ.saeule_ziel(k)
	_saeule_ziel = ziel
	beginne_angriff("saeule")   # Ansage mit Vorschau (_saeule_ansage) auf _saeule_ziel
	_saeule_ziel = Vector2.INF
	boden_belegen("saeule", Werte.BOSS_SAEULE_ANSAGE + Werte.BOSS_SAEULE_SEK)
	einheit.set_meta("nemesis_umriss", VERGELTUNG_UMRISS)   # lila, bis die Säule erlischt
	_saeule_umriss_bis = uhr + Werte.BOSS_SAEULE_ANSAGE + Werte.BOSS_SAEULE_SEK
	person["vergeltung"] = tr("Lichtsäule")   # steht in seiner Karte
	o24.tafeln.zeige({"art": "vergeltung", "titel": tr("Vergeltung: %s") % tr("Lichtsäule"), "zeilen": [tr("raus aus dem Kreis")],
		"farbe": VERGELTUNG_UMRISS, "sek": Werte.HERAUSFORDERER_VERGELTUNG_TAFEL_SEK, "pause": 0.2})
	Ton.spiele(spiel, "alert", -3.0)
	protokoll.append({"was": "vergeltung", "bei": o24.zeit, "name": tr("Lichtsäule"), "art": "saeule", "ring": "", "ziel": ziel,
		"abstand": einheit.position.distance_to(k.position) / Werte.ZELLE})
	if not zaehlung.is_empty():
		zaehlung["vergeltungen"] = int(zaehlung["vergeltungen"]) + 1   # G2


## H-7: Die stehende Säule – Schaden je Sekunde im Kreis (auch auf einer Krone und im Sprung: sie steht vom Boden bis
## in den Himmel).
func _saeule_steht_weiter(dt: float) -> void:
	if stehende_saeule.is_empty():
		return
	stehende_saeule["rest"] = float(stehende_saeule["rest"]) - dt
	var k: Kommandant = spiel.kommandant
	var z: Vector2 = stehende_saeule["pos"]
	if k.unverwundbar <= 0.0 and k.position.distance_to(z) <= (EgoModus.SAEULE_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE:
		saeule_schaden += Werte.BOSS_SAEULE_JE_SEK * dt
		treffe_als("saeule", schaden() * Werte.BOSS_SAEULE_JE_SEK * dt, z, false)
	var bild: Variant = stehende_saeule.get("bild")
	if is_instance_valid(bild) and bild is MeshInstance3D:
		var stoff := (bild as MeshInstance3D).material_override as StandardMaterial3D
		stoff.albedo_color.a = 0.35 + 0.15 * sin(float(stehende_saeule["rest"]) * 12.0)
	if float(stehende_saeule["rest"]) <= 0.0:
		_saeule_weg()


func _saeule_weg() -> void:
	if stehende_saeule.is_empty():
		return
	var bild: Variant = stehende_saeule.get("bild")
	if is_instance_valid(bild) and bild is MeshInstance3D:
		var stoff := (bild as MeshInstance3D).material_override as StandardMaterial3D
		var tw := (bild as Node).create_tween()
		tw.tween_property(stoff, "albedo_color:a", 0.0, 0.4)
		tw.tween_callback((bild as Node).queue_free)
	protokoll.append({"was": "saeule_ende", "bei": o24.zeit, "schaden": saeule_schaden})
	stehende_saeule = {}


## Beginnt die Vergeltung (auch für den Test).
func vergeltung_an(was: Dictionary) -> void:
	vergeltung = was.duplicate()
	vergeltung["rest"] = Werte.HERAUSFORDERER_VERGELTUNG_SEK
	_vergeltung_in = Werte.HERAUSFORDERER_VERGELTUNG_ABKLING
	_bis_angriff = minf(_bis_angriff, 0.8)
	einheit.set_meta("nemesis_umriss", VERGELTUNG_UMRISS)
	person["vergeltung"] = str(vergeltung["name"])   # ab jetzt steht sie in seiner Karte
	var schluessel := ring_kopie() if str(vergeltung["art"]) == "ring" else str(vergeltung["art"])
	o24.tafeln.zeige({"art": "vergeltung", "titel": tr("Vergeltung: %s") % str(vergeltung["name"]), "zeilen": [str(VERGELTUNG_TEXT.get(schluessel, ""))],
		"farbe": VERGELTUNG_UMRISS, "sek": Werte.HERAUSFORDERER_VERGELTUNG_TAFEL_SEK, "pause": 0.2})
	Ton.spiele(spiel, "alert", -3.0)
	protokoll.append({"was": "vergeltung", "bei": o24.zeit, "name": str(vergeltung["name"]), "art": str(vergeltung["art"]), "ring": ring_kopie()})
	if not zaehlung.is_empty():
		zaehlung["vergeltungen"] = int(zaehlung["vergeltungen"]) + 1   # G2


func vergeltung_aus() -> void:
	if vergeltung.is_empty():
		return
	vergeltung = {}
	if einheit != null and is_instance_valid(einheit):
		einheit.set_meta("nemesis_umriss", Nemesis.umriss_farbe(person))
	protokoll.append({"was": "vergeltung_ende", "bei": o24.zeit})


## Welcher Angriff als Nächstes – mit Vergeltung: die kopierte Waffe bzw. der Angriff, an dem der Ring hängt. Auch dann
## nie dreimal derselbe.
func naechster_angriff(abstand: float) -> String:
	var wunsch := ""
	if not vergeltung.is_empty():
		wunsch = (typ.ring_angriff(str(RING_ANGRIFF.get(ring_kopie(), ""))) if typ != null else str(RING_ANGRIFF.get(ring_kopie(), ""))) if str(vergeltung["art"]) == "ring" else str(WAFFEN_ANGRIFF[str(vergeltung["art"])])
	if wunsch != "" and not (_letzte.size() >= 2 and str(_letzte[-1]) == wunsch and str(_letzte[-2]) == wunsch):
		schritt_jetzt = {}
		_druck_aus()   # G2-3: ein Angriff außerhalb der Abfolge beendet die Druckphase
		return wunsch
	if _nach_krone != "":   # G2-2: er steht (oder stand) auf der Krone – jetzt der Angriff des Schritts
		var a := _nach_krone
		_nach_krone = ""
		return a
	var zwang := typ.erzwungen() if typ != null else ""
	if zwang != "":
		schritt_jetzt = {}
		_druck_aus()   # G2-3: ein Angriff außerhalb der Abfolge beendet die Druckphase
		return zwang
	var s := _abfolge_schritt(abstand)
	if not s.is_empty():
		if str(s["art"]) == "kronesprung":   # I-6: ein Schritt ohne Angriff – nur auf eine Rand-Krone
			if einheit.zustand != Einheit.Zustand.AUF_POSTEN and _aktion.is_empty():
				_auf_den_wall(spiel.kommandant)
			protokoll.append({"was": "kronesprung", "bei": o24.zeit, "oben": einheit.zustand == Einheit.Zustand.AUF_POSTEN})
			_bis_angriff = float(s.get("bewegung", 0.6))
			return ""
		if bool(s.get("krone", false)) and einheit.zustand != Einheit.Zustand.AUF_POSTEN and _aktion.is_empty() and _auf_den_wall(spiel.kommandant):
			_nach_krone = str(s["art"])   # Kronenwechsel: erst hinauf, der Angriff folgt oben
			_bis_angriff = 0.0
			return ""
		return str(s["art"])
	schritt_jetzt = {}
	_druck_aus()   # G2-3: ein Angriff außerhalb der Abfolge beendet die Druckphase
	var gewichte: Dictionary = typ.gewichte(abstand, _letzte) if typ != null else {}
	protokoll.append({"was": "wahl", "bei": o24.zeit, "gewichte": gewichte.duplicate(), "letzte": _letzte.slice(-2)})   # F5: für die Erwartung je Art
	return waehle_angriff(abstand, _letzte, gewichte)


## G2-2: Der nächste ausführbare Schritt der Abfolge ({} = keine Abfolge oder nichts ausführbar). Bei einem Phasenwechsel
## beginnt die neue Tabelle an zufälliger Stelle, vorher läuft einmal ihre Eröffnung.
func _abfolge_schritt(abstand: float) -> Dictionary:
	var tabelle: Array = typ.abfolge(wut) if typ != null else []
	if tabelle.is_empty():
		return {}
	if _abf.is_empty() or _abf_wut != wut:
		_abf = tabelle
		_abf_wut = wut
		_abf_i = randi() % tabelle.size()
		_abf_vorn = typ.eroeffnung(wut).duplicate()
	elif tabelle.size() == _abf.size():
		_abf = tabelle   # H-10: Werte der Tafel (Fenster, Bewegung) gelten sofort
	while not _abf_vorn.is_empty():
		var v: Dictionary = _abf_vorn.pop_front()
		if typ.kann(str(v["a"]), abstand):
			return _schritt_nehmen(v, -1, str(v["a"]), abstand)
	for versuch in _abf.size():
		var i := (_abf_i + versuch) % _abf.size()
		var st: Dictionary = _abf[i]
		var arten: Array = (st["wahl"] as Array).duplicate() if st.has("wahl") else [str(st["a"])]
		arten.shuffle()   # Wahl: eine von zwei, die andere als Ersatz
		for art: String in arten:
			if typ.kann(art, abstand):
				_abf_i = (i + 1) % _abf.size()
				return _schritt_nehmen(st, i, art, abstand)
	return {}


func _schritt_nehmen(st: Dictionary, i: int, art: String, abstand: float = -1.0) -> Dictionary:
	# I-1 (27.11., Paul): der Bosstyp kann den Schritt nach dem Abstand ersetzen (Technogunner: Jagdanker aus der Nähe wird
	# zum Sturmring, Sturmring aus der Ferne bekommt den Jagdanker davor)
	if abstand < 0.0:
		abstand = einheit.position.distance_to((spiel.kommandant as Kommandant).position) / Werte.ZELLE
	var ersatz: Array = typ.ersatz(art, abstand) if typ != null else [art, ""]
	art = str(ersatz[0])
	schritt_jetzt = st.duplicate()
	schritt_jetzt["art"] = art
	schritt_jetzt["i"] = i
	if schritt_jetzt.has("dann_fuer") and str(schritt_jetzt["dann_fuer"]) != art:
		schritt_jetzt.erase("dann")   # die Kopplung gilt nur für eine der beiden Wahlen
	if str(ersatz[1]) != "":
		schritt_jetzt["dann"] = str(ersatz[1])   # I-2: gekoppelt danach (mit vollem Ablauf)
		schritt_jetzt.erase("dann_sek")
	if (st.get("fenster_je", {}) as Dictionary).has(art):
		schritt_jetzt["fenster"] = float(st["fenster_je"][art])
	if bool(st.get("druck", false)):   # G2-3: kurze Fenster, keine Bewegung; nach dem letzten Druck-Schritt die Belohnung
		schritt_jetzt["fenster"] = Werte.BOSS_DRUCK_FENSTER
		schritt_jetzt["bewegung"] = Werte.BOSS_DRUCK_BEWEGUNG
		if i >= 0 and not bool((_abf[(i + 1) % _abf.size()] as Dictionary).get("druck", false)):
			schritt_jetzt["fenster"] = Werte.BOSS_DRUCK_BELOHNUNG
			schritt_jetzt["druck_ende"] = true
		if not druck:
			_druck_an()
	elif druck:
		_druck_aus()
	abfolge_log.append({"i": i, "art": art, "bei": o24.zeit, "druck": bool(st.get("druck", false))})
	return schritt_jetzt


## G2-3: Eine Druckphase beginnt – lila Puls-Umriss, HUD „DRUCK“; H-1: bei Sonde 7 beginnt eine Reihenwelle.
func _druck_an() -> void:
	druck = true
	_druck_seit = 0.0
	if not zaehlung.is_empty():
		zaehlung["druckphasen"] = int(zaehlung["druckphasen"]) + 1
	protokoll.append({"was": "druck", "bei": o24.zeit})
	Ton.spiele(spiel, "alert", -4.0)
	if typ != null and typ.anker_zwang():
		reihenwelle_an(einheit.position)   # H-1: Sonde 7 – die Reihenwelle von ihr aus (statt des Bodenfeuers)


func _druck_aus() -> void:
	if not druck:
		return
	druck = false
	if einheit != null and is_instance_valid(einheit):
		einheit.set_meta("nemesis_umriss", VERGELTUNG_UMRISS if not vergeltung.is_empty() else Nemesis.umriss_farbe(person))
	protokoll.append({"was": "druck_ende", "bei": o24.zeit})


## G2-3: HUD-Zeile des Duells: „DRUCK“ zu Beginn einer Druckphase; H-1: „Boden bricht“ bei der Reihenwelle (auch schon
## während der Ansage); sonst die des Typs.
func hud_zeile() -> String:
	if druck and _druck_seit < Werte.BOSS_DRUCK_HUD_SEK:
		return tr("DRUCK")
	if reihe != null or (str(angriff.get("art", "")) == "reihe" and str(angriff.get("teil", "")) == "ansage"):
		return tr("Boden bricht – hoch oder drüber!")
	return typ.hud_zeile() if typ != null else ""


## H-1 (27.11., Paul): Die Reihenwelle beginnt bei `von` (der Boss) und läuft von ihm weg in Richtung Brakk bis zur
## Lichtwand (nemesis_reihenwelle.gd). Höchstens eine zugleich; sie belegt den Boden (Besitzer „reihe“), solange sie läuft.
func reihenwelle_an(von: Vector2) -> void:
	if not kampfplatz.aktiv() or reihe != null:
		return
	if not boden_frei(["boss", "reihe"]):
		protokoll.append({"was": "reihenwelle_aus", "bei": o24.zeit})   # H-6: eine Säule (oder der Klon) markiert den Boden
		return
	reihe = NemesisReihenwelle.new(self)
	reihe.planen(von, (spiel.kommandant as Kommandant).position)
	if reihe.reihen.is_empty():
		reihe = null
		return
	boden_belegen("reihe", reihe.dauer())
	protokoll.append({"was": "reihenwelle", "bei": o24.zeit, "reihen": reihe.reihen.size(), "dauer": reihe.dauer(), "von": von,
		"schritt": reihe.schritt})
	if not _hoch_gesagt:
		_hoch_gesagt = true
		spiel.melde(tr("Sonde 7: „Hoch mit dir, Kommandant.“"), 3.0)


func _reihe_weiter(dt: float) -> void:
	if reihe == null:
		return
	reihe.weiter(dt)
	if reihe.fertig():
		protokoll.append({"was": "reihenwelle_ende", "bei": o24.zeit, "getroffen": reihe.getroffen, "explosionen": reihe.protokoll.duplicate()})
		reihe = null


func _reihe_aus() -> void:
	if reihe != null:
		reihe.abbrechen()
		boden_freigeben("reihe")
	reihe = null


## H-1: Ein Treffer an Brakk, gezählt unter `art` (auch wenn gerade ein anderer Angriff läuft – Reihenwelle, Säule, Klon).
func treffe_als(art: String, menge: float, von: Vector2, blitz: bool = true) -> void:
	var alt := zaehl_art
	zaehl_art = art
	(spiel.brakk_geschosse as BrakkGeschosse)._treffe_brakk(menge, "herausforderer", quelle(), von, blitz)
	zaehl_art = alt


## Order24 (Brakks Stellvertreter): einer seiner Treffer landet. Gibt den Faktor auf den Schaden zurück und setzt, was
## der kopierte Ring bewirkt. Die Ticks eines Brandfelds zählen nicht als Treffer.
func treffer_mal(menge: float) -> float:
	var mal := 1.0
	var ring := ring_kopie()
	if ring == "laser":
		mal *= Werte.HERAUSFORDERER_RING_GLUT
	if menge >= schaden() * 0.2:
		if marke_rest > 0.0:
			mal *= Werte.HERAUSFORDERER_RING_MARKE_MAL
			marke_rest = 0.0
		if ring == "markierung":
			marke_rest = Werte.HERAUSFORDERER_RING_MARKE_SEK
		if ring == "plasmagel":
			gel_rest = Werte.HERAUSFORDERER_RING_GEL_SEK
	return mal


## Order24.treffer: so viel von Brakks Schaden kommt bei ihm an (Wallring).
func schutz_faktor() -> float:
	return Werte.HERAUSFORDERER_RING_WALL_SCHUTZ if ring_kopie() == "bollwerk" else 1.0


## Brakks Lauftempo (Gelring).
func brakk_bremse() -> float:
	return minf(Werte.HERAUSFORDERER_RING_GEL_TEMPO if gel_rest > 0.0 else 1.0, typ.bremse() if typ != null and zustand == "duell" else 1.0)


## Wirbelring: nach der ersten Salve gleich die zweite – mit eigener, voller Ankündigung.
func _zweite_salve(k: Kommandant) -> void:
	protokoll.append({"was": "doppelsalve", "bei": o24.zeit, "angesagt": float(angriff["angesagt"])})
	angriff["zweite"] = true
	angriff["t"] = 0.0
	angriff["ziel"] = k.position
	angriff["richtung"] = (k.position - einheit.position).normalized()
	_salve_ansage()


## Wie weit reicht eine gerade Bahn von `von` bis zur ersten Mauer (steht er oben auf dem Wall, zählt erst die nächste)?
func weite_bis_wand(von: Vector2, r: Vector2, hoechstens: float) -> float:
	var karte: Karte = o24.karte
	var frei := karte.ist_frei(karte.zelle_bei(von))
	var s := 0.0
	var schritt_weite := Werte.ZELLE * 0.2
	while s < hoechstens:
		s += schritt_weite
		var c := karte.zelle_bei(von + r * s)
		if not karte.in_karte(c):
			return s
		if karte.ist_frei(c):
			frei = true
		elif frei:
			return s
	return hoechstens


## Mauern halten seine geraden Schüsse auf – außer mit dem Durchschlagring, oder wenn Brakk selbst oben auf dem Wall steht.
func _an_der_wand_enden(g: Dictionary) -> void:
	if ring_kopie() == "durchschuss" or (spiel.kommandant as Kommandant).oben:
		return
	g["lang"] = weite_bis_wand(g["von"] as Vector2, g["r"] as Vector2, float(g["lang"]))


# --- die kopierten Waffen

## Pistolen: schnelle Doppelschüsse – drei Paare kurz nacheinander, jedes Paar zählt höchstens einmal (ein Drittel eines
## Treffers).
func _doppel_ansage() -> void:
	angriff["um"] = Werte.HERAUSFORDERER_DOPPEL_ANSAGE
	einheit._sprite.angriff(Werte.HERAUSFORDERER_DOPPEL_ANSAGE + 0.6)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var r: Vector2 = angriff["richtung"]
	bg.aufblitzen(_muendung(r), VERGELTUNG_UMRISS)
	bg._balken(bg._zu3d(einheit.position, 0.07), bg._zu3d(angriff["ziel"] as Vector2, 0.07), VERGELTUNG_UMRISS, 0.05, _bg(Werte.HERAUSFORDERER_DOPPEL_ANSAGE))
	Ton.am_ort(spiel, "tc-arc", einheit.position)


func _doppel_feuer() -> void:
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	for i in Werte.HERAUSFORDERER_DOPPEL_PAARE:
		if i == 0:
			_doppel_paar()
		else:
			bg.spaeter(Werte.HERAUSFORDERER_DOPPEL_TAKT * i, _doppel_paar)


func _doppel_paar() -> void:
	var k: Kommandant = spiel.kommandant
	if einheit == null or not is_instance_valid(einheit) or einheit.kampfunfaehig or k == null:
		return
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	_salven += 1
	var r := (k.position - einheit.position).normalized()
	var quer := Vector2(-r.y, r.x) * Werte.HERAUSFORDERER_DOPPEL_VERSATZ * Werte.ZELLE
	for seite: float in [-1.0, 1.0]:
		var punkt := k.position + quer * seite
		bg.schiesse("hf_doppel", _muendung(r) + quer * seite, _hoehe_er(), schaden() / Werte.HERAUSFORDERER_DOPPEL_PAARE, "herausforderer", quelle(), 1.0, punkt)
		var g: Dictionary = bg.geschosse.back()
		g["gruppe"] = _salven
		_an_der_wand_enden(g)
	Ton.am_ort(spiel, "tc-blaster", einheit.position)


## Ladestrahl: erst die Ziellinie, dann ein dicker Strahl auf derselben Bahn.
func _strahl_ansage() -> void:
	angriff["um"] = Werte.HERAUSFORDERER_STRAHL_ANSAGE
	einheit._sprite.angriff(Werte.HERAUSFORDERER_STRAHL_ANSAGE + 0.2)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var r: Vector2 = angriff["richtung"]
	var weit := weite_bis_wand(einheit.position, r, EgoModus.LANZE_WEITE * Werte.ZELLE)
	angriff["ende"] = einheit.position + r * weit
	var dauer := _bg(Werte.HERAUSFORDERER_STRAHL_ANSAGE)
	bg._balken(bg._zu3d(einheit.position, 0.07), bg._zu3d(angriff["ende"] as Vector2, 0.07), VERGELTUNG_UMRISS, 0.09, dauer)
	bg._balken(bg._zu3d(_muendung(r), _hoehe_er()), bg._zu3d(angriff["ende"] as Vector2, 0.5), VERGELTUNG_UMRISS, 0.03, dauer)
	bg.aufblitzen(_muendung(r), VERGELTUNG_UMRISS)
	Ton.am_ort(spiel, "tc-rail", einheit.position)


func _strahl_feuer() -> void:
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var r: Vector2 = angriff["richtung"]
	var ende: Vector2 = angriff["ende"]
	bg._balken(bg._zu3d(_muendung(r), _hoehe_er()), bg._zu3d(ende, 0.5), VERGELTUNG_UMRISS.lightened(0.35), Werte.HERAUSFORDERER_STRAHL_BREITE, _bg(0.35))
	bg._hitscan(einheit.position, ende, Werte.HERAUSFORDERER_STRAHL_BREITE * Werte.ZELLE, schaden(), "herausforderer", quelle(), bg._ziel())
	Ton.am_ort(spiel, "hit-boom", ende)


## Lichtsäule: dieselbe Vorschau am Boden wie bei Brakk (ein Ring zieht sich zusammen und blinkt immer schneller), dann
## der Einschlag.
func _saeule_ansage() -> void:
	if _saeule_ziel != Vector2.INF:
		angriff["ziel"] = _saeule_ziel   # H-7: Ziel des Bosstyps (vorausberechnet bzw. Wegsperre)
	angriff["um"] = Werte.BOSS_SAEULE_ANSAGE
	einheit._sprite.angriff(Werte.BOSS_SAEULE_ANSAGE + 0.2)
	spiel.effekte.warnung(angriff["ziel"] as Vector2, _bg(Werte.BOSS_SAEULE_ANSAGE) * Werte.BRAKK_TEMPO)
	Ton.am_ort(spiel, "tc-arc", einheit.position)
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	_marke_weg()
	_marke = Node3D.new()
	for radius: float in [EgoModus.SAEULE_RADIUS, EgoModus.SAEULE_RADIUS]:
		var ring := MeshInstance3D.new()
		var form := TorusMesh.new()
		form.inner_radius = radius - 0.09
		form.outer_radius = radius
		ring.mesh = form
		ring.material_override = o24._leucht(VERGELTUNG_UMRISS, 0.9)
		_marke.add_child(ring)
	for i in 4:
		var strich := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.03, 0.12)
		strich.mesh = box
		strich.material_override = o24._leucht(VERGELTUNG_UMRISS, 0.8)
		strich.rotation.y = -TAU * i / 4.0
		strich.position = Vector3(cos(TAU * i / 4.0), 0.0, sin(TAU * i / 4.0)) * (EgoModus.SAEULE_RADIUS - 0.35)
		_marke.add_child(strich)
	# Brakk steht meist selbst im Kreis, und der liegt dann unter dem Bild: eine Lichtwand rundum sieht man auch von innen
	var wand := MeshInstance3D.new()
	var rohr := CylinderMesh.new()
	rohr.top_radius = EgoModus.SAEULE_RADIUS
	rohr.bottom_radius = EgoModus.SAEULE_RADIUS
	rohr.height = 1.6
	rohr.cap_top = false
	rohr.cap_bottom = false
	wand.mesh = rohr
	wand.material_override = o24._leucht(VERGELTUNG_UMRISS, 0.1)
	wand.position = Vector3(0, 0.8, 0)
	_marke.add_child(wand)
	hd.add_child(_marke)
	var z: Vector2 = angriff["ziel"]
	_marke.position = Vector3(z.x / Werte.ZELLE, (hd.H if hd.ist_hoch(o24.karte.zelle_bei(z)) else 0.0) + 0.06, (z.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func _saeule_vorschau(anteil: float, dt: float) -> void:
	if _marke == null or not is_instance_valid(_marke):
		return
	(_marke.get_child(1) as Node3D).scale = Vector3.ONE * lerpf(2.8, 1.0, anteil)
	((_marke.get_child(_marke.get_child_count() - 1) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = lerpf(0.1, 0.3, anteil)
	_marke.rotation.y += dt * (2.0 + 8.0 * anteil)
	_marke.visible = int(float(angriff["t"]) * (4.0 + 12.0 * anteil)) % 2 == 0 or anteil > 0.9


func _saeule_feuer(_k: Kommandant) -> void:
	_marke_weg()
	_saeule_weg()
	var z: Vector2 = angriff["ziel"]
	var radius := EgoModus.SAEULE_RADIUS * Werte.ZELLE
	var hd: HdAnsicht = spiel.hd
	if hd != null:
		var saeule := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.top_radius = EgoModus.SAEULE_RADIUS * 0.55
		form.bottom_radius = EgoModus.SAEULE_RADIUS * 0.75
		form.height = 8.0
		saeule.mesh = form
		var stoff := o24._leucht(VERGELTUNG_UMRISS, 0.6)
		saeule.material_override = stoff
		hd.add_child(saeule)
		saeule.position = Vector3(z.x / Werte.ZELLE, 4.0, (z.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		stehende_saeule["bild"] = saeule
	# H-7: sie steht BOSS_SAEULE_SEK s (Schaden je Sekunde in _saeule_steht_weiter) statt eines einzelnen Einschlags
	stehende_saeule["pos"] = z
	stehende_saeule["rest"] = Werte.BOSS_SAEULE_SEK
	spiel.effekte.flaeche(z, radius, VERGELTUNG_UMRISS)
	Ton.am_ort(spiel, "hit-boom", z)
	protokoll.append({"was": "saeule_steht", "bei": o24.zeit, "pos": z})


## Zielt die Vorschau gerade auf die Stelle, an der Brakk steht? (Warnzeile im HUD)
func saeule_ueber_brakk() -> bool:
	var k: Kommandant = spiel.kommandant if spiel != null else null
	if k != null and not stehende_saeule.is_empty() and k.position.distance_to(stehende_saeule["pos"] as Vector2) <= (EgoModus.SAEULE_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE:
		return true   # H-7: die Säule steht
	return k != null and str(angriff.get("art", "")) == "saeule" and str(angriff.get("teil", "")) == "ansage" and k.position.distance_to(angriff["ziel"] as Vector2) <= (EgoModus.SAEULE_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE


func _marke_weg() -> void:
	if _marke != null and is_instance_valid(_marke):
		_marke.queue_free()
	_marke = null


## Sprungring: nach dem ersten Platzen fliegt die Kugel ein Stück weiter auf Brakk zu und platzt noch einmal – mit
## eigenem Kreis. Im Flug trifft sie nicht, nur beim Platzen.
func _kugel_springt(wo: Vector2) -> void:
	var k: Kommandant = spiel.kommandant
	if einheit == null or not is_instance_valid(einheit) or einheit.kampfunfaehig or k == null:
		return
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var r := (k.position - wo).normalized() if k.position.distance_to(wo) > 0.5 * Werte.ZELLE else (wo - einheit.position).normalized()
	var ziel := wo + r * Werte.HERAUSFORDERER_RING_SPRUNG_WEIT * Werte.ZELLE
	var g: Dictionary = Werte.BRAKK_GESCHOSS["hf_kugel"]
	var flug := Werte.HERAUSFORDERER_RING_SPRUNG_WEIT / float(g["tempo"])   # Sekunden wie in brakk_geschosse
	bg._ring(bg._zu3d(ziel, 0.05), float(g["einschlag"]), Color("ff6a2a"), flug)
	spiel.effekte.warnung(ziel, flug * Werte.BRAKK_TEMPO)
	bg.schiesse("hf_kugel", wo, 0.3, schaden(), "herausforderer", quelle(), 1.0, ziel)
	(bg.geschosse.back() as Dictionary)["harmlos"] = true
	protokoll.append({"was": "kugel_springt", "bei": o24.zeit, "angesagt": flug / Werte.SPIELTEMPO})


func _exit_tree() -> void:
	if laeuft() and spiel != null and spiel.is_inside_tree():
		Musik.duell(spiel.get_tree(), false)
