class_name Nemesis
extends Node
## 22.11. (Paul): Nemesis-System für „Befehl 24“ (Brakk-Modus Rogue) – Eliten, die überleben und sich einen Namen verdienen.
## Vorbild: das Nemesis-System aus Mittelerde: Mordors Schatten, in klein. Gilt nur in Befehl 24 (Kind von Order24).
##
## Teil 1+2 (22.11.):
##  - Personen: jede Elite (und jede beförderte Truppe) hat einen Datensatz – Truppenart, Rang 0–4, Eigenname und Beiname
##    (leer, bis verdient), Fähigkeit, Angewohnheit, Stärke, Schwäche, Bilanz gegen Brakk, Taktikwerte, Chronik.
##  - Eliten sterben nicht: bei 0 Leben „kampfunfähig“ (main.lazarett_rettet → rettet), nach NEMESIS_BERGUNG_SEK Beam in den
##    Schild. Die Sprengladung fällt trotzdem. In der nächsten Elitewelle sind sie wieder da – mit Narbe, −15 % Leben.
##  - Begegnung: Einheit und Brakk beschießen sich, bis einer fällt oder NEMESIS_BEGEGNUNG_RUHE s kein Schuss fällt.
##  - Feldbeförderung (sieben Bedingungen, Garantie zur zweiten Elitewelle, höchstens drei je Lauf), Name = Dienstgrad +
##    Eigenname + Beiname aus der Tat, Stärke und Schwäche passend zur Tat.
##  - Die Drei vom Appell (Verrat-Sequenz) sind von Anfang an benannt und bilden im ersten Lauf den ersten Elitetrupp.
## Speicherung über Läufe (user://nemesis.json), Fähigkeiten, Angewohnheiten und Lernen folgen in den Teilen 3–6.

## Dienstgrad je Rang (Rang 0 = namenlos)
const DIENSTGRADE: Array[String] = ["", "Gefreiter", "Hauptgefreiter", "Korporal", "Feldwebel"]

## 22.11. (Paul: selbst erstellen) – 40 Eigennamen im Technoclan-Klang, kurz und hart, ein paar Werkstattwörter dabei.
const EIGENNAMEN: Array[String] = [
	"Vex", "Kord", "Taln", "Brix", "Oxa", "Zed", "Rusk", "Ferro", "Kalix", "Nox",
	"Joss", "Volt", "Dekk", "Rho", "Pell", "Strax", "Ivo", "Tesk", "Morr", "Quill",
	"Sax", "Lumo", "Gant", "Brem", "Holt", "Vask", "Ondo", "Ziv", "Krell", "Pax",
	"Tyr", "Mags", "Dross", "Kip", "Fenn", "Hask", "Bolzen", "Spule", "Ohm", "Diode",
]

## 22.11. (Paul: selbst erstellen) – 20 Beinamen mit Auslöser. Zuerst die Tat (Bedingung der Beförderung) …
const BEINAME_TAT := {
	"zwei_begegnungen": "der Wiedergänger",   # zwei Begegnungen mit Brakk überlebt
	"anteil": "Volltreffer",                  # ihm in einer Begegnung mehr als 25 % Leben genommen
	"rest": "der Rest",                       # als Letzte ihres Jagdtrupps entkommen
	"medkit": "der Sanitäter",                # ihn am Med-Kit erwischt
	"sabotage": "der Hausmeister",            # ihn beim Sabotieren einer Fabrik erwischt
	"ladung": "der Entschärfer",              # ihn beim Setzen einer Sprengladung erwischt
	"sprengung": "Taubes Ohr",                # eine seiner Sprengladungen überlebt
	"sichtung": "Spürnase",                   # ihn für einen Trupp aufgedeckt, der dann traf
	"letzter_treffer": "Brakkbrecher",        # ihm den letzten Treffer gegeben
	"garantie": "der Fleißige",               # Garantie: meister Schaden an Brakk, ohne dass sonst wer befördert wurde
}
## … dann die Lage beim entscheidenden Treffer (gilt für Volltreffer, Wiedergänger und Garantie) …
const BEINAME_LAGE := {
	"hinterhalt": "der Geduldige",            # aus dem Hinterhalt (von hinten, Brakk sah weg)
	"wall": "Falkenauge",                     # von einem Wall herab (aus der Stellung)
	"brand": "Aschefuß",                      # Brakk stand im Brandfeld
	"dach": "Dachdecker",                     # Brakk oben auf einem Erdwall getroffen
	"luft": "Vogelschreck",                   # Brakk im Sprung getroffen
	"fern": "Weitblick",                      # aus mehr als NEMESIS_FERN Feldern
	"nah": "Tuchfühlung",                     # aus weniger als NEMESIS_NAH Feldern
}
## … und der Zustand der Person.
const BEINAME_ZUSTAND := {
	"knapp": "Haaresbreite",                  # bei der Beförderung fast tot (unter NEMESIS_KNAPP Leben)
	"frueh": "Frühaufsteher",                 # schon vor der Jagd befördert (Flucht- oder Sabotagephase)
	"unbelehrbar": "der Unbelehrbare",        # nach drei Bergungen (ersetzt den alten Beinamen)
}

## Die Drei vom Appell: Eigenname, Beiname, Truppenart nach dem Umrüsten (in der Sequenz alle drei Technogunner)
const APPELL := [
	["Vex", "der Pünktliche", "technogunner"],
	["Kord", "Stillgestanden", "scharfschuetze"],
	["Taln", "Befehl ist Befehl", "plasmawerfer"],
]

const STAERKEN := {
	"zaeh": "zäh (+30 % Leben)",
	"flink": "flink (+25 % Tempo)",
	"verstaerkung": "ruft Verstärkung (zwei Gunner)",
	"sprengfest": "sprengfest (Sprengladungen kaum)",
	"nerven": "eiserne Nerven (weicht nie zurück)",
}
const SCHWAECHEN := {
	"feuer": "fürchtet Feuer (weicht Brandfeldern weit aus)",
	"nachtragend": "nachtragend (läuft Brakk allein hinterher)",
	"nachladen": "langsam beim Nachladen",
	"nerven_letzter": "verliert die Nerven, wenn er als Letzter übrig ist",
}
## Stärke bzw. Schwäche, die zur Tat passt (sonst gezogen)
const TAT_STAERKE := {
	"zwei_begegnungen": "zaeh", "anteil": "nerven", "rest": "flink", "medkit": "flink", "sabotage": "zaeh",
	"ladung": "sprengfest", "sprengung": "sprengfest", "sichtung": "verstaerkung", "letzter_treffer": "nerven", "garantie": "verstaerkung",
}
const TAT_SCHWAECHE := {"rest": "nerven_letzter", "sichtung": "nachtragend", "anteil": "nachtragend", "medkit": "nachladen"}
const TAT_TEXT := {
	"zwei_begegnungen": "hat zwei Begegnungen mit Brakk überlebt",
	"anteil": "hat Brakk in einer Begegnung mehr als ein Viertel seines Lebens genommen",
	"rest": "ist als Letzte ihres Trupps entkommen",
	"medkit": "hat Brakk am Med-Kit erwischt",
	"sabotage": "hat Brakk beim Sabotieren erwischt",
	"ladung": "hat Brakk beim Setzen einer Sprengladung erwischt",
	"sprengung": "hat Brakks Sprengladung überlebt",
	"sichtung": "hat Brakk für ihren Trupp aufgedeckt",
	"letzter_treffer": "hat Brakk den letzten Treffer gegeben",
	"garantie": "hat Brakk den meisten Schaden gemacht",
}
const SONDE_BEFOERDERUNG: Array[String] = [
	"Feldbeförderung bestätigt: %s. Ich erwarte Ergebnisse.",
	"%s – Sie haben sich einen Namen verdient. Machen Sie ihn größer.",
	"Neuer Eintrag in der Kartei: %s. Kommandant Brakk, merken Sie sich das Gesicht.",
]

var o24: Order24
var spiel: Node
var personen: Array = []            # Datensätze (Dictionary), Benannte und die namenlosen Eliten dieses Laufs
var _naechste_id := 1
var _person_von := {}               # Einheit-ID -> Person
var _einheit_von := {}              # Person-ID -> Einheit
var _begegnung := {}                # Einheit-ID -> {"seit", "zuletzt", "an_brakk", "trupp", "trupp_n", "kontext", "rueckzug"}
var _lauf := {}                     # Einheit-ID -> {"schaden": float, "ueberlebt": int, "kontext": String}
var kampfunfaehig: Array = []       # je {"einheit": Einheit, "person": Dictionary, "bis": float}
var befoerderungen: Array = []      # dieses Laufs: je {"person": Dictionary, "grund": String, "zeit": float}
var feld_n := 0                     # Feldbeförderungen dieses Laufs (ohne letzten Treffer)
var elitewellen := 0
var erledigt_von: Dictionary = {}   # wer Brakk den letzten Treffer gab (Person; Deathscreen in Teil 7)
var erledigt_info: Dictionary = {}  # 22.11. (Teil 7): Lage, Waffe, Begegnung, vorher namenlos/Rang
var faehigkeiten: NemesisFaehigkeiten = null   # 22.11. (Teil 3): Fähigkeiten der Benannten
var gewohnheiten: NemesisGewohnheiten = null   # 22.11. (Teil 4): abgeschaute Angewohnheiten
var lernen: NemesisLernen = null               # 22.11. (Teil 5): Taktikwahl, Aufenthaltskarte, Spielstil
var _datei_zaehler := {}            # aus nemesis.json: wie oft Brakk was tat (über Läufe)
var _datei_gesehen := {}            # aus nemesis.json: schon erlebte Angewohnheiten (Lexikon)
static var gesehen_lauf := {}       # in diesem Lauf erlebte Angewohnheiten (das Lexikon liest sie mit)
var ausgeschaltet: Array = []       # endgültig ausgeschaltete Benannte dieses Laufs (Teil 6 füllt sie)
var _medkit_zeit := -99.0
var _ladung_zeit := -99.0
var _sichtungen := {}               # Trupp-Nr -> {"wer": Einheit, "bis": float}
var _rueckzug := {}                 # Einheit-ID -> bis (Zeit)
var _schilder := {}                 # Einheit-ID -> Label3D (Namensschild in der Ego-Sicht)
var _appell_gemeldet := false
# 22.11. (Teil 6): über Läufe hinweg
var erster_lauf := true             # noch keine nemesis.json mit den Drei vom Appell
var versetzt: Array = []            # dieses Laufs von Neuen verdrängte Benannte
var chronik_global: Array = []      # Ereignisse über alle Läufe (ausgeschaltet, versetzt)
var wiedersehen: Dictionary = {}    # laufende Einblendung {"name", "zeile", "bis", "farbe"}
var _halten: Dictionary = {}        # endgültig ausschalten: {"eintrag": kampfunfaehig-Eintrag, "t": float}
var _gespeichert := false


func einrichten(p_o24: Order24) -> void:
	o24 = p_o24
	spiel = o24.spiel
	laden()   # 22.11. (Teil 6): die Benannten aus user://nemesis.json
	for p: Dictionary in personen:
		p["lauf"] = _neuer_lauf(false)
	_lauf_trupp_ziehen()
	faehigkeiten = NemesisFaehigkeiten.new()   # 22.11. (Teil 3)
	faehigkeiten.nem = self
	add_child(faehigkeiten)
	gewohnheiten = NemesisGewohnheiten.new()   # 22.11. (Teil 4)
	gewohnheiten.nem = self
	gewohnheiten.zaehler = _datei_zaehler.duplicate()
	gewohnheiten.gesehen = _datei_gesehen.duplicate()
	add_child(gewohnheiten)
	lernen = NemesisLernen.new()   # 22.11. (Teil 5)
	lernen.nem = self
	add_child(lernen)


## `erlaubt`: darf in diesem Lauf in den Elitetrupp (aus der Liste gezogen, neu befördert oder vom Appell).
func _neuer_lauf(erlaubt: bool = true) -> Dictionary:
	return {"dabei": false, "schaden": 0.0, "geborgen": false, "rang_plus": false, "begegnungen": 0, "bergungen": 0, "erlaubt": erlaubt,
		"neu": false, "wiedersehen": false}


func zeit() -> float:
	return o24.zeit


# ------------------------------------------------------------------ Personen

func neue_person(art: String, rang: int = 0, eigenname: String = "", beiname: String = "") -> Dictionary:
	var p := {"id": _naechste_id, "art": art, "rang": rang, "name": eigenname, "beiname": beiname, "titel": "",
		"faehigkeit": "", "angewohnheit": "", "staerke": "", "schwaeche": "", "staerke_bekannt": false, "schwaeche_bekannt": false,
		"bilanz": {"er": 0, "brakk": 0}, "begegnungen": 0, "bergungen": 0, "narbe": 0, "geborgen": false,
		"taktik": {}, "chronik": [], "lauf": _neuer_lauf()}
	_naechste_id += 1
	personen.append(p)
	return p


static func dienstgrad(p: Dictionary) -> String:
	return DIENSTGRADE[clampi(int(p.get("rang", 0)), 0, DIENSTGRADE.size() - 1)]


## „Gefreiter Vex ‚der Pünktliche‘“ (namenlos: leer)
static func voller_name(p: Dictionary) -> String:
	if p.is_empty() or int(p.get("rang", 0)) <= 0 or str(p.get("name", "")) == "":
		return ""
	var s := "%s %s" % [dienstgrad(p), str(p["name"])]
	if str(p.get("beiname", "")) != "":
		s += " ‚%s‘" % str(p["beiname"])
	return s


static func benannt(p: Dictionary) -> bool:
	return not p.is_empty() and int(p.get("rang", 0)) >= 1


## Lebt die Einheit noch (nicht gefallen, nicht kampfunfähig)? Auch im Bild, in dem sie fällt.
static func lebt(x: Variant) -> bool:
	return is_instance_valid(x) and x is Einheit and not (x as Einheit).is_queued_for_deletion() and not (x as Einheit).kampfunfaehig and (x as Einheit).leben > 0.0


## Reihenfolge für den Elitetrupp: wer im Schild wartet vor denen im Feld, dann Rang, dann Siege über Brakk.
func _vorrang(p: Dictionary) -> int:
	return (0 if einheit_von(p) != null else 10000) + int(p["rang"]) * 100 + int((p["bilanz"] as Dictionary)["er"])


func person_von(e: Einheit) -> Dictionary:
	if e == null or not is_instance_valid(e):
		return {}
	var p: Variant = _person_von.get(e.get_instance_id(), null)
	return p as Dictionary if p is Dictionary else {}


func einheit_von(p: Dictionary) -> Einheit:
	var e: Variant = _einheit_von.get(int(p.get("id", -1)), null)
	if e is Einheit and is_instance_valid(e):
		return e as Einheit
	return null


func benannte() -> Array:
	return personen.filter(func(p: Dictionary) -> bool: return benannt(p))


func _zuordnen(e: Einheit, p: Dictionary) -> void:
	_person_von[e.get_instance_id()] = p
	_einheit_von[int(p["id"])] = e
	(p["lauf"] as Dictionary)["dabei"] = true


func _chronik(p: Dictionary, text: String) -> void:
	(p["chronik"] as Array).append({"zeit": zeit(), "text": text, "datum": Time.get_date_string_from_system()})
	print("NEMESIS %s: %s" % [voller_name(p) if benannt(p) else "Namenlose Elite #%d" % int(p["id"]), text])


## Truppenart einer Einheit (über den Namen in Werte.EINHEITEN)
static func art_von(e: Einheit) -> String:
	var n := str(e.daten.get("name", ""))
	for t: String in Werte.FABRIK_EINHEITEN:
		if str((Werte.EINHEITEN[t] as Dictionary).get("name", "")) == n:
			return t
	return "technogunner"


func _eigenname() -> String:
	var frei: Array = []
	var vergeben := {}
	for p: Dictionary in personen + versetzt + ausgeschaltet:   # Namen dieses Laufs nicht doppelt vergeben
		vergeben[str(p["name"])] = true
	for n: String in EIGENNAMEN:
		if not vergeben.has(n):
			frei.append(n)
	if frei.is_empty():
		return str(Zufall.waehle(EIGENNAMEN as Array))
	return str(Zufall.waehle(frei))


# ------------------------------------------------------------------ Die Drei vom Appell

## Verrat-Sequenz: die drei Technogunner werden Personen mit Namen (Rang 1) – nur im allerersten Lauf (22.11., Teil 6:
## danach stehen sie in der Liste oder sind ausgeschaltet bzw. versetzt). Stehen sie noch in der Liste, tragen die drei
## Technogunner der Sequenz ihre Namen.
func appell(einheiten: Array) -> void:
	var da := {}
	for p: Dictionary in personen:
		if bool(p.get("appell", false)):
			da[str(p["name"])] = p
	for i in APPELL.size():
		var a: Array = APPELL[i]
		var p: Dictionary = da.get(str(a[0]), {})
		if p.is_empty() and not erster_lauf:
			continue
		if p.is_empty():
			p = neue_person(str(a[2]), 1, str(a[0]), str(a[1]))
			p["appell"] = true
			p["staerke"] = ["nerven", "zaeh", "sprengfest"][i]
			p["schwaeche"] = ["nachtragend", "nachladen", "feuer"][i]
			p["faehigkeit"] = ["unterdrueckung", "markierung", "sperrbrand"][i]   # 22.11. (Teil 3)
			_chronik(p, "Beim Appell: hat auf Befehl 24 die Waffe auf Brakk gerichtet")
		if i >= einheiten.size():
			continue
		var e := einheiten[i] as Einheit
		if is_instance_valid(e) and benannt(p):
			_zuordnen(e, p)
			(p["lauf"] as Dictionary)["dabei"] = false   # die Sequenz zählt nicht als Einsatz
			_rang_bild(e, int(p["rang"]))
			e.set_meta("nemesis_umriss", umriss_farbe(p))


## Nach der Sequenz treten die Drei ab: Beam in den Schild – sie rüsten um und kommen mit dem ersten Elitetrupp wieder.
func appell_abtreten(einheiten: Array) -> void:
	for x: Variant in einheiten:
		if x is Einheit and is_instance_valid(x):
			_wegbeamen(x as Einheit)


# ------------------------------------------------------------------ Elitetrupp

## Elitewelle: Benannte zuerst (bis NEMESIS_ELITE_MAX), auf NEMESIS_ELITE_GRUNDZAHL mit Namenlosen aufgefüllt (erst die
## schon bekannten dieses Laufs, dann neue). Wer noch lebend im Feld steht (Feldbeförderte), stößt dazu. Gibt die
## Mitglieder zurück (neu erzeugte und beigetretene).
func elitetrupp(quellen: Array[Vector2i]) -> Array:
	elitewellen += 1
	if elitewellen == Werte.NEMESIS_GARANTIE_WELLE and feld_n == 0:
		_garantie()
	var dabei: Array = []
	var namen := benannte().filter(func(p: Dictionary) -> bool: return bool((p["lauf"] as Dictionary).get("erlaubt", true)))   # Teil 6: aus der Liste gezogen oder neu
	namen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _vorrang(a) > _vorrang(b))
	for p: Dictionary in namen:
		if dabei.size() < Werte.NEMESIS_ELITE_MAX and not _im_einsatz_elite(p):
			dabei.append(p)
	for p: Dictionary in personen:
		if dabei.size() < Werte.NEMESIS_ELITE_GRUNDZAHL and not benannt(p) and einheit_von(p) == null:
			dabei.append(p)
	while dabei.size() < Werte.NEMESIS_ELITE_GRUNDZAHL:
		var z: Vector2i = quellen[dabei.size() % quellen.size()]
		dabei.append(neue_person(str(spiel.fabriken[z]["typ"])))
	var aus: Array = []
	var appell_dabei: Array[String] = []
	for nr in dabei.size():
		var p: Dictionary = dabei[nr]
		var lebt := einheit_von(p)
		if lebt != null:
			_aus_trupp(lebt)   # Feldbeförderte stoßen zum Elitetrupp
			aus.append(lebt)
			continue
		var e := o24._neue_truppe(str(p["art"]), quellen[nr % quellen.size()], 4)
		einkleiden(e, p)
		aus.append(e)
		var doppel := gewohnheiten.doppelgaenger(e, p, quellen[nr % quellen.size()]) if gewohnheiten != null else null
		if doppel != null:
			aus.append(doppel)   # 22.11. (Teil 4): Doppelgänger – flackert, kein Name
		if str(p.get("staerke", "")) == "verstaerkung":
			for j in 2:
				aus.append(o24._neue_truppe("technogunner", quellen[nr % quellen.size()], 1))
		if bool(p.get("appell", false)) and str(p["art"]) != "technogunner":
			appell_dabei.append(str(p["name"]))
	if not _appell_gemeldet and appell_dabei.size() >= 2:
		_appell_gemeldet = true   # zwei der Drei vom Appell haben bis zum ersten Elitetrupp umgerüstet
		_sonde("%s und %s haben umgerüstet – Scharfschützengewehr und Plasmawerfer. Der Appell ist vollzählig, Kommandant." % [appell_dabei[0], appell_dabei[1]])
	var namen_txt: PackedStringArray = []
	for p: Dictionary in dabei:
		if benannt(p):
			namen_txt.append(voller_name(p))
	print("NEMESIS Elitewelle %d: %d Personen (%s)" % [elitewellen, dabei.size(), ", ".join(namen_txt)])
	return aus


## Steht diese Person schon in einem Elitetrupp im Feld?
func _im_einsatz_elite(p: Dictionary) -> bool:
	var e := einheit_von(p)
	if e == null:
		return false
	var nr := int(o24.jaeger.get(e.get_instance_id(), -1))
	if nr < 0 or nr >= o24.trupps.size():
		return false
	for m: Variant in (o24.trupps[nr] as Dictionary)["mitglieder"]:
		if is_instance_valid(m) and m != e and bool((m as Einheit).daten.get("elite", false)) and not person_von(m as Einheit).is_empty():
			return true
	return false


## Einheit aus ihrem bisherigen Jagdtrupp nehmen.
func _aus_trupp(e: Einheit) -> void:
	var id := e.get_instance_id()
	var nr := int(o24.jaeger.get(id, -1))
	if nr >= 0 and nr < o24.trupps.size():
		((o24.trupps[nr] as Dictionary)["mitglieder"] as Array).erase(e)
	o24.jaeger.erase(id)


## Person auf eine frische Einheit: Rangbonus, Stärke und Schwäche, Narbe, nach einer Bergung −15 % Leben.
func einkleiden(e: Einheit, p: Dictionary) -> void:
	_zuordnen(e, p)
	if benannt(p) and str(p.get("faehigkeit", "")) == "":
		p["faehigkeit"] = NemesisFaehigkeiten.ziehen(str(p["art"]), "", false)   # 22.11. (Teil 3): ältere Einträge ohne Fähigkeit
	var rang := int(p["rang"])
	var leben_mal := 1.0 + Werte.NEMESIS_RANG_BONUS * rang
	e.daten = e.daten.duplicate()
	e.daten["schaden"] = float(e.daten["schaden"]) * (1.0 + Werte.NEMESIS_RANG_BONUS * rang)
	match str(p.get("staerke", "")):
		"zaeh":
			leben_mal *= Werte.NEMESIS_ZAEH
		"flink":
			e.daten["tempo"] = float(e.daten["tempo"]) * Werte.NEMESIS_FLINK
	if str(p.get("schwaeche", "")) == "nachladen":
		e.daten["abklingzeit"] = float(e.daten["abklingzeit"]) * Werte.NEMESIS_NACHLADEN
	if bool(p.get("geborgen", false)):
		leben_mal *= Werte.NEMESIS_VERTRIEBEN_LEBEN   # vertrieben: −15 %, dafür mit Erinnerung (Taktik, Teil 5)
		p["geborgen"] = false
	e.max_leben *= leben_mal
	e.leben = e.max_leben
	if benannt(p):
		_rang_bild(e, rang)
		e.set_meta("nemesis_umriss", umriss_farbe(p))
	elif int(p.get("narbe", 0)) > 0:
		e.set_meta("nemesis_umriss", umriss_farbe(p))
	var ag := NemesisGewohnheiten.von_person(p)   # 22.11. (Teil 4)
	if ag.has("klettern"):
		e.set_meta("wall_reichweite", Werte.NEMESIS_WALL_REICHWEITE)
	if ag.has("fern"):
		var schild := Sprite2D.new()
		schild.name = "Frontschild"
		schild.texture = _frontschild_bild()
		schild.centered = false
		schild.offset = Vector2(6, -30)
		e.add_child(schild)


## Umriss: Benannte orange-golden, jede Narbe dunkler; Namenlose mit Narbe grau.
static func umriss_farbe(p: Dictionary) -> Color:
	var c: Color = Werte.NEMESIS_UMRISS if benannt(p) else Color("9a9aa8")
	return c.darkened(minf(0.6, 0.22 * float(p.get("narbe", 0))))


## Rangwinkel über dem Kopf (Sprite2D-Kind: die HD-Ansicht spiegelt es in die Ego-Sicht).
func _rang_bild(e: Einheit, rang: int) -> void:
	var alt := e.get_node_or_null("Rang")
	if alt != null:
		alt.free()
	if rang <= 0:
		return
	var s := Sprite2D.new()
	s.name = "Rang"
	s.texture = rangwinkel(rang)
	s.centered = false
	var hoehe := float(e._sprite.get("_zelle")) * e._sprite.scale.y * 0.8 + 14.0
	s.offset = Vector2(-7, -float(s.texture.get_height()) - hoehe)
	e.add_child(s)


static var _winkel_cache := {}

## Goldene Winkel übereinander (einer je Rang).
static func rangwinkel(rang: int) -> Texture2D:
	if _winkel_cache.has(rang):
		return _winkel_cache[rang]
	var h := 4 * rang + 3
	var img := Image.create(14, h, false, Image.FORMAT_RGBA8)
	for r in rang:
		var y0 := 4 * r + 1
		for x in 14:
			var y := y0 + floori(absf(float(x) - 6.5) / 3.0)
			for d in 2:
				if y + d < h:
					img.set_pixel(x, y + d, Color("ffd34d") if d == 0 else Color("b8862a"))
	_winkel_cache[rang] = ImageTexture.create_from_image(img)
	return _winkel_cache[rang]


# ------------------------------------------------------------------ Begegnungen und Taten

## Eine Einheit hat auf Brakk geschossen (Einheit._auf_brakk) – die Begegnung läuft (auch wenn er ausweicht).
func schuss(e: Einheit) -> void:
	_beg(e)["zuletzt"] = zeit()


## Begegnung der Einheit (wird angelegt, wenn keine läuft).
func _beg(e: Einheit) -> Dictionary:
	var id := e.get_instance_id()
	if not _begegnung.has(id):
		var nr := int(o24.jaeger.get(id, -1))
		var n := 0
		if nr >= 0 and nr < o24.trupps.size():
			n = ((o24.trupps[nr] as Dictionary)["mitglieder"] as Array).size()
		_begegnung[id] = {"seit": zeit(), "zuletzt": zeit(), "an_brakk": 0.0, "trupp": nr, "trupp_n": n, "kontext": "", "rueckzug": false, "erlitten": 0.0, "taktik": lernen.taktik_von(e) if lernen != null else ""}
	return _begegnung[id]


func _lauf_von(e: Einheit) -> Dictionary:
	var id := e.get_instance_id()
	if not _lauf.has(id):
		_lauf[id] = {"schaden": 0.0, "ueberlebt": 0, "kontext": "", "einheit": e}
	return _lauf[id]


## Treffer einer Einheit auf Brakk (BrakkZiel.nimm_schaden, `schaden` = was bei Brakk ankam).
func brakk_getroffen(id: int, schaden: float) -> void:
	var o: Object = instance_from_id(id)
	if not (o is Einheit) or not is_instance_valid(o):
		return
	var e := o as Einheit
	if e.kampfunfaehig:
		return
	var k: Kommandant = spiel.kommandant
	var b := _beg(e)
	b["zuletzt"] = zeit()
	b["an_brakk"] = float(b["an_brakk"]) + schaden
	var lage := _lage(e)
	b["kontext"] = lage
	var l := _lauf_von(e)
	l["schaden"] = float(l["schaden"]) + schaden
	l["kontext"] = lage
	var p := person_von(e)
	if not p.is_empty():
		var pl: Dictionary = p["lauf"]
		pl["schaden"] = float(pl["schaden"]) + schaden
	# Sichtung: ein anderer hat Brakk für diesen Trupp aufgedeckt
	var nr := int(o24.jaeger.get(id, -1))
	if _sichtungen.has(nr):
		var s: Dictionary = _sichtungen[nr]
		_sichtungen.erase(nr)
		if zeit() <= float(s["bis"]) and is_instance_valid(s["wer"]) and s["wer"] != e:
			befoerdern(s["wer"] as Einheit, "sichtung")
	# unterbrochen: beim Sabotieren, am Med-Kit oder beim Setzen einer Sprengladung
	if not o24.sabo.is_empty():
		befoerdern(e, "sabotage")
	elif zeit() - _medkit_zeit <= Werte.NEMESIS_UNTERBRECHUNG_SEK:
		befoerdern(e, "medkit")
	elif zeit() - _ladung_zeit <= Werte.NEMESIS_UNTERBRECHUNG_SEK:
		befoerdern(e, "ladung")
	elif k != null and float(b["an_brakk"]) > Werte.NEMESIS_BEGEGNUNG_ANTEIL * k.max_leben:
		befoerdern(e, "anteil", lage)


## Lage beim Treffer (für den Beinamen): hinterhalt, wall, brand, dach, luft, fern, nah oder "".
func _lage(e: Einheit) -> String:
	var k: Kommandant = spiel.kommandant
	if k == null:
		return ""
	var zu_e := e.position - k.position
	var ego: EgoModus = spiel.ego
	if ego != null and zu_e.length() > 1.0:
		var blick := Vector2(-sin(ego.gier), -cos(ego.gier))
		if blick.dot(zu_e.normalized()) < -0.5:
			return "hinterhalt"
	if e.in_stellung():
		return "wall"
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	if bg != null:
		for br: Dictionary in bg.braende:
			if k.position.distance_to(br["mitte"] as Vector2) <= float(br["r"]):
				return "brand"
	if k.oben:
		return "dach"
	if ego != null and ego.hoehe - ego._boden() > 0.3:
		return "luft"
	var d := zu_e.length() / Werte.ZELLE
	if d > Werte.NEMESIS_FERN:
		return "fern"
	if d < Werte.NEMESIS_NAH:
		return "nah"
	return ""


## Brakk hat eine Einheit getroffen (Order24.treffer) – auch das gehört zur Begegnung.
## 22.11. (Teil 5): Schaden, den die Einheit in der Begegnung genommen hat (für den Wert ihrer Taktik).
func erlitten(e: Einheit, menge: float) -> void:
	if menge > 0.0 and is_instance_valid(e) and not e.kampfunfaehig:
		var b := _beg(e)
		b["erlitten"] = float(b.get("erlitten", 0.0)) + menge


func von_brakk(e: Einheit) -> void:
	_beg(e)["zuletzt"] = zeit()
	var p := person_von(e)
	if benannt(p) and not bool((p["lauf"] as Dictionary).get("wiedersehen", false)):
		(p["lauf"] as Dictionary)["wiedersehen"] = true
		_wiedersehen(p)   # 22.11. (Teil 6): erster Treffer auf ihn in diesem Lauf


## Brakk ist gefallen – `id` gab den letzten Treffer: Beförderung (Rang 2) bzw. Rang +1 und „Brakks Bezwinger“.
func brakk_erledigt(id: int) -> void:
	var o: Object = instance_from_id(id)
	if not (o is Einheit) or not is_instance_valid(o) or not erledigt_von.is_empty():
		return
	var e := o as Einheit
	var p := person_von(e)
	# 22.11. (Teil 7): für den Deathscreen – wie, womit, die wievielte Begegnung, vorher namenlos?
	erledigt_info = {"lage": _lage(e), "art": art_von(e), "namenlos": not benannt(p), "rang_vorher": int(p.get("rang", 0)),
		"begegnung": int(p.get("begegnungen", 0)) + 1, "faehigkeit": faehigkeiten.letzte_von(e) if faehigkeiten != null else "", "gewohnheit": gewohnheiten.womit(e) if gewohnheiten != null else "", "taktik": lernen.taktik_von(e) if lernen != null else ""}
	if benannt(p):
		var pl: Dictionary = p["lauf"]
		if not bool(pl["rang_plus"]) and int(p["rang"]) < Werte.NEMESIS_RANG_MAX:
			p["rang"] = int(p["rang"]) + 1
			pl["rang_plus"] = true
			_rang_bild(e, int(p["rang"]))
	else:
		befoerdern(e, "letzter_treffer")
		p = person_von(e)
	if p.is_empty():
		return
	p["titel"] = "Brakks Bezwinger"
	var bil: Dictionary = p["bilanz"]
	bil["er"] = int(bil["er"]) + 1
	erledigt_von = p
	_chronik(p, "hat Brakk erledigt – „Brakks Bezwinger“")


## Med-Kit genommen / Sprengladung gesetzt: Treffer kurz danach gelten als „unterbrochen“.
func medkit() -> void:
	_medkit_zeit = zeit()
	if gewohnheiten != null:
		gewohnheiten.zaehle("medkit")   # 22.11. (Teil 4)


func ladung() -> void:
	_ladung_zeit = zeit()
	if gewohnheiten != null:
		gewohnheiten.zaehle("sprengen")   # 22.11. (Teil 4)


static var _schild_tex: Texture2D = null

## Frontschild (Teil 4): schmale cyanfarbene Platte vor der Figur.
static func _frontschild_bild() -> Texture2D:
	if _schild_tex == null:
		var img := Image.create(6, 18, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.45, 0.85, 1.0, 0.85))
		for y in 18:
			img.set_pixel(0, y, Color(0.9, 1.0, 1.0))
			img.set_pixel(5, y, Color(0.2, 0.5, 0.7))
		_schild_tex = ImageTexture.create_from_image(img)
	return _schild_tex


## Eine Einheit hat Brakk für den Trupp `nr` aufgedeckt (Stellung meldet bzw. Jäger sieht ihn zuerst).
func sichtung(wer: Einheit, nr: int) -> void:
	if wer == null or not is_instance_valid(wer) or nr < 0:
		return
	_sichtungen[nr] = {"wer": wer, "bis": zeit() + Werte.NEMESIS_SICHTUNG_SEK}


## Sprengladung explodiert: Faktor auf ihren Schaden (sprengfest) …
func spreng_faktor(e: Einheit) -> float:
	var p := person_von(e)
	if str(p.get("staerke", "")) == "sprengfest":
		p["staerke_bekannt"] = true
		return Werte.NEMESIS_SPRENGFEST
	return 1.0


## … und wer im Umkreis stand und noch lebt, hat sie überlebt.
func sprengung_ueberlebt(e: Einheit) -> void:
	if is_instance_valid(e) and not e.kampfunfaehig and e.leben > 0.0:
		befoerdern(e, "sprengung")


## Eliten schießen genauer (Anteil der Streuung).
func genau(e: Einheit) -> float:
	return Werte.NEMESIS_GENAU if not person_von(e).is_empty() or bool(e.daten.get("elite", false)) else 1.0


# ------------------------------------------------------------------ Feldbeförderung

## Befördert eine namenlose Einheit (Bedingung `grund`, Lage `lage` für den Beinamen). true = befördert.
func befoerdern(e: Einheit, grund: String, lage: String = "") -> bool:
	if e == null or not is_instance_valid(e) or e.kampfunfaehig or e.ist_pilot:
		return false
	var p := person_von(e)
	if benannt(p):
		return false
	var letzter := grund == "letzter_treffer"
	if not letzter and feld_n >= Werte.NEMESIS_FELD_MAX:
		return false
	if p.is_empty():
		p = neue_person(art_von(e))
		_zuordnen(e, p)
	p["rang"] = 2 if letzter else 1
	(p["lauf"] as Dictionary)["rang_plus"] = true
	(p["lauf"] as Dictionary)["neu"] = true   # Teil 6: Neue verdrängen am Laufende, werden nicht selbst versetzt
	(p["lauf"] as Dictionary)["wiedersehen"] = true   # wer gerade befördert wurde, braucht keine Wiedersehens-Zeile
	p["name"] = _eigenname()
	p["beiname"] = _beiname(grund, lage, e)
	_staerke_schwaeche(p, grund)
	p["faehigkeit"] = NemesisFaehigkeiten.ziehen(str(p["art"]), lage if lage != "" else str(_lauf_von(e)["kontext"]), o24.in_deckung)   # 22.11. (Teil 3): passend zur Tat
	if not letzter:
		feld_n += 1
	befoerderungen.append({"person": p, "grund": grund, "zeit": zeit()})
	_chronik(p, "Feldbeförderung: %s" % str(TAT_TEXT.get(grund, grund)))
	# sichtbar: Rangwinkel, Umriss, Leben aufgefüllt (mit Rangbonus und Stärke), Einblendung, Sonde 7
	var mal := 1.0 + Werte.NEMESIS_RANG_BONUS * int(p["rang"])
	if str(p["staerke"]) == "zaeh":
		mal *= Werte.NEMESIS_ZAEH
	e.max_leben *= mal
	e.leben = e.max_leben
	_rang_bild(e, int(p["rang"]))
	e.set_meta("nemesis_umriss", umriss_farbe(p))
	var nm := voller_name(p)
	if spiel.get("_einblendung") != null:
		spiel._einblendung.banner("FELDBEFÖRDERUNG", nm, Werte.NEMESIS_UMRISS)
	_sonde(SONDE_BEFOERDERUNG[randi() % SONDE_BEFOERDERUNG.size()] % nm)
	Ton.spiele(spiel, "alert", -6.0)
	return true


## Beiname: Tat – bei Volltreffer, Wiedergänger und Garantie gehen Zustand und Lage vor.
func _beiname(grund: String, lage: String, e: Einheit) -> String:
	if grund in ["anteil", "zwei_begegnungen", "garantie"]:
		if e.leben < e.max_leben * Werte.NEMESIS_KNAPP:
			return BEINAME_ZUSTAND["knapp"]
		if lage == "":
			lage = str(_lauf_von(e)["kontext"])
		if BEINAME_LAGE.has(lage) and not _beiname_vergeben(str(BEINAME_LAGE[lage])):
			return BEINAME_LAGE[lage]
		if o24.phase() in ["flucht", "sabotage"] and not _beiname_vergeben(str(BEINAME_ZUSTAND["frueh"])):
			return BEINAME_ZUSTAND["frueh"]
	return str(BEINAME_TAT.get(grund, "der Neue"))


## Trägt schon ein Benannter diesen Beinamen? (Lage-Beinamen sollen unterscheiden – sonst gilt der Beiname der Tat.)
func _beiname_vergeben(b: String) -> bool:
	for p: Dictionary in personen:
		if benannt(p) and str(p["beiname"]) == b:
			return true
	return false


## Stärke und Schwäche: meist passend zur Tat, sonst gezogen (ohne Widersprüche).
func _staerke_schwaeche(p: Dictionary, grund: String) -> void:
	var st := str(TAT_STAERKE.get(grund, ""))
	if st == "" or Zufall.f() < 0.25:
		st = str(Zufall.waehle(STAERKEN.keys()))
	p["staerke"] = st
	var sw := str(TAT_SCHWAECHE.get(grund, ""))
	if sw == "" or Zufall.f() < 0.25:
		var liste: Array = SCHWAECHEN.keys()
		if str(p["beiname"]) == BEINAME_LAGE["brand"]:
			liste.erase("feuer")   # Aschefuß fürchtet kein Feuer
		if st == "nerven":
			liste.erase("nerven_letzter")
		sw = str(Zufall.waehle(liste))
	if st == "nerven" and sw == "nerven_letzter":
		sw = "nachtragend"
	p["schwaeche"] = sw


## Garantie: bis zur zweiten Elitewelle keine Feldbeförderung → die lebende Einheit mit dem meisten Schaden an Brakk.
func _garantie() -> void:
	var beste: Einheit = null
	var wert := -1.0
	for id: int in _lauf:
		var l: Dictionary = _lauf[id]
		var e: Variant = l["einheit"]
		if is_instance_valid(e) and not (e as Einheit).kampfunfaehig and not benannt(person_von(e as Einheit)) and float(l["schaden"]) > wert:
			wert = float(l["schaden"])
			beste = e as Einheit
	if beste == null:
		# niemand hat getroffen: die Truppe am nächsten an Brakk
		var k: Kommandant = spiel.kommandant
		var d := INF
		for x: Variant in o24._truppen():
			var u := x as Einheit
			if not u.kampfunfaehig and not benannt(person_von(u)) and k != null and u.position.distance_to(k.position) < d:
				d = u.position.distance_to(k.position)
				beste = u
	if beste != null and befoerdern(beste, "garantie"):
		print("NEMESIS Garantie: %s (%.0f Schaden an Brakk)" % [voller_name(person_von(beste)), maxf(0.0, wert)])


# ------------------------------------------------------------------ Kampfunfähig und Bergung

## main.lazarett_rettet: Eine Person fällt nicht – sie wird kampfunfähig und nach NEMESIS_BERGUNG_SEK geborgen.
## Namenlose Truppen ohne Datensatz sterben wie bisher.
func rettet(e: Einheit) -> bool:
	var p := person_von(e)
	if p.is_empty() or not o24.laeuft:
		return false
	if e.kampfunfaehig:
		return true
	e.kampfunfaehig = true
	e.halt = false
	if faehigkeiten != null:
		faehigkeiten._zust.erase(e.get_instance_id())   # laufende Fähigkeit bricht ab
	e.leben = 0.0
	if e.posten_zelle != Karte.KEINE and o24.karte.posten.get(e.posten_zelle) == e:
		o24.karte.posten.erase(e.posten_zelle)
	e.posten_zelle = Karte.KEINE
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._ausstehend.clear()
	e._sprite.scale = Vector2(e._sprite.scale.x, e._sprite.scale.x * 0.45)   # sackt zusammen
	e._sprite.modulate = Color(0.55, 0.55, 0.62)
	_aus_trupp(e)
	o24.ladungen_boden.append({"pos": e.position, "knoten": null})   # Sprengladung fällt trotzdem (Elitetrupp: sicher)
	p["bergungen"] = int(p["bergungen"]) + 1
	p["narbe"] = int(p["narbe"]) + 1
	p["geborgen"] = true
	(p["lauf"] as Dictionary)["geborgen"] = true
	(p["lauf"] as Dictionary)["bergungen"] = int((p["lauf"] as Dictionary).get("bergungen", 0)) + 1
	var bil: Dictionary = p["bilanz"]
	bil["brakk"] = int(bil["brakk"]) + 1
	_beg(e)["erlitten"] = e.max_leben   # 22.11. (Teil 5): kampfunfähig = das ganze Leben verloren (für die Taktik)
	_begegnung_ende(e, false)
	if benannt(p) and int(p["bergungen"]) >= 3 and str(p["beiname"]) != BEINAME_ZUSTAND["unbelehrbar"]:
		p["beiname"] = BEINAME_ZUSTAND["unbelehrbar"]
		_chronik(p, "dritte Bergung – heißt jetzt „der Unbelehrbare“")
	_chronik(p, "von Brakk kampfunfähig geschossen (Bergung %d)" % int(p["bergungen"]))
	if gewohnheiten != null:
		gewohnheiten.abschauen(p, "kampfunfähig geschossen")   # 22.11. (Teil 4): kommt mit dem zurück, womit Brakk ihn besiegt hat
	if benannt(p):
		spiel.melde("%s ist kampfunfähig – Bergung in %d s." % [voller_name(p), roundi(Werte.NEMESIS_BERGUNG_SEK)], 2.5)
	kampfunfaehig.append({"einheit": e, "person": p, "bis": zeit() + Werte.NEMESIS_BERGUNG_SEK})
	return true


## Beam in den Schild: Lichtsäule, Ton, Einheit verschwindet (ohne Tod und ohne Drop).
func _wegbeamen(e: Einheit, beam: bool = true) -> void:
	var pos := e.position
	var hd: HdAnsicht = spiel.hd
	if hd != null and beam:
		var mitte := Vector3(pos.x / Werte.ZELLE, 2.5, (pos.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		var saeule := o24._kasten3d(hd, Vector3(0.35, 5.0, 0.35), Order24.TECHNO_FARBE, mitte)
		var tw := saeule.create_tween()
		tw.tween_property(saeule, "transparency", 1.0, 0.6)
		tw.tween_callback(saeule.queue_free)
	if beam:
		spiel.effekte.flaeche(pos, Werte.ZELLE * 0.6, Order24.TECHNO_FARBE)
		Ton.am_ort(spiel, "tc-arc", pos)
	_aus_trupp(e)
	var id := e.get_instance_id()
	var p := person_von(e)
	if not p.is_empty():
		_einheit_von.erase(int(p["id"]))
	_person_von.erase(id)
	_begegnung.erase(id)
	if _schilder.has(id):
		(_schilder[id] as Node).queue_free()
		_schilder.erase(id)
	spiel.einheiten.erase(e)
	if e.posten_zelle != Karte.KEINE and o24.karte.posten.get(e.posten_zelle) == e:
		o24.karte.posten.erase(e.posten_zelle)
	if spiel.fabriken.has(e.fabrik_zelle):
		(spiel.fabriken[e.fabrik_zelle]["einheiten"] as Array).erase(e)
	e.queue_free()


# ------------------------------------------------------------------ Stärken und Schwächen im Feld

## Order24.marschziel: Schwächen und Rückzug gehen vor (KEINE = wie sonst).
func marschziel(e: Einheit) -> Vector2i:
	var p := person_von(e)
	if p.is_empty() or e.kampfunfaehig:
		return Karte.KEINE
	var k: Kommandant = spiel.kommandant
	if k == null:
		return Karte.KEINE
	var id := e.get_instance_id()
	var hier := o24.karte.zelle_bei(e.position)
	var weg_von_brakk := (e.position - k.position).normalized() if e.position.distance_to(k.position) > 1.0 else Vector2.RIGHT
	var um: Dictionary = faehigkeiten.umstellen.get(id, {}) if faehigkeiten != null else {}
	if not um.is_empty():
		if zeit() < float(um["bis"]) and hier != (um["ziel"] as Vector2i):
			return o24._erreichbar_nahe(um["ziel"] as Vector2i, hier)   # 22.11. (Teil 3): Markierung – Stellungswechsel
		faehigkeiten.umstellen.erase(id)
	match str(p.get("schwaeche", "")):
		"feuer":
			for b: Variant in spiel.get("_braende"):
				var br := b as Array
				if br.size() > 5 and str(br[5]) != "" and e.position.distance_to(br[0] as Vector2) <= float(br[1]) + Werte.NEMESIS_FEUER_ABSTAND * Werte.ZELLE:
					_schwaeche_gesehen(p, e, "weicht dem Feuer aus")
					var weg := (e.position - (br[0] as Vector2)).normalized()
					return o24._erreichbar_nahe(o24._freies_feld_bei(e.position + weg * 3.0 * Werte.ZELLE, hier), hier)
		"nachtragend":
			if int((p["lauf"] as Dictionary)["begegnungen"]) > 0 or _begegnung.has(id):
				if o24.jaeger.has(id):
					_aus_trupp(e)   # verlässt den Trupp
				_schwaeche_gesehen(p, e, "läuft dir allein hinterher")
				return o24._erreichbar_nahe(o24.karte.zelle_bei(k.position), hier)
		"nerven_letzter":
			var nr := int(o24.jaeger.get(id, -1))
			var b: Dictionary = _begegnung.get(id, {})
			if nr >= 0 and nr < o24.trupps.size() and not b.is_empty() and int(b["trupp_n"]) >= Werte.NEMESIS_TRUPP_MIN:
				var lebend := ((o24.trupps[nr] as Dictionary)["mitglieder"] as Array).filter(func(x: Variant) -> bool: return Nemesis.lebt(x))
				if lebend.size() == 1:
					_schwaeche_gesehen(p, e, "verliert die Nerven und flieht")
					return o24._erreichbar_nahe(e.fabrik_zelle, hier)
	# Rückzug unter NEMESIS_RUECKZUG_ANTEIL Leben, einmal je Begegnung (eiserne Nerven: nie)
	if float(_rueckzug.get(id, -1.0)) > zeit():
		return o24._erreichbar_nahe(o24._freies_feld_bei(e.position + weg_von_brakk * 3.0 * Werte.ZELLE, hier), hier)
	if _begegnung.has(id) and e.leben < e.max_leben * Werte.NEMESIS_RUECKZUG_ANTEIL:
		var b: Dictionary = _begegnung[id]
		if not bool(b["rueckzug"]):
			b["rueckzug"] = true
			if str(p.get("staerke", "")) == "nerven":
				p["staerke_bekannt"] = true
			else:
				_rueckzug[id] = zeit() + Werte.NEMESIS_RUECKZUG_SEK
	var gz := gewohnheiten.marschziel(e) if gewohnheiten != null else Karte.KEINE   # 22.11. (Teil 4)
	if gz != Karte.KEINE:
		return gz
	return lernen.marschziel(e) if lernen != null else Karte.KEINE   # 22.11. (Teil 5): Taktik, Fabrikwache, Formation


## Eine Schwäche zeigt sich – sieht Brakk es (nah genug, freie Sicht), steht sie ab jetzt auf der Tafel.
func _schwaeche_gesehen(p: Dictionary, e: Einheit, text: String) -> void:
	if bool(p["schwaeche_bekannt"]):
		return
	var k: Kommandant = spiel.kommandant
	if k == null or e.position.distance_to(k.position) > 14.0 * Werte.ZELLE or not o24.karte.sicht_frei(e.position, k.position):
		return
	p["schwaeche_bekannt"] = true
	if benannt(p):
		spiel.melde("Schwäche erkannt: %s %s." % [voller_name(p), text], 4.0)
		_chronik(p, "Schwäche gezeigt: %s" % str(SCHWAECHEN.get(str(p["schwaeche"]), "")))


# ------------------------------------------------------------------ Ablauf

func _physics_process(_takt: float) -> void:
	if o24 == null or not o24.laeuft or o24.vorbei:
		return
	var t := zeit()
	_halten_weiter(Werte.SIM_SCHRITT / Werte.BRAKK_TEMPO)   # 22.11. (Teil 6): [E] am Kampfunfähigen – der Beam wartet
	if gewohnheiten != null:
		gewohnheiten.weiter(Werte.SIM_SCHRITT / Werte.BRAKK_TEMPO)   # 22.11. (Teil 4)
		gesehen_lauf = gewohnheiten.gesehen
	if lernen != null:
		lernen.weiter(Werte.SIM_SCHRITT / Werte.BRAKK_TEMPO)   # 22.11. (Teil 5): Aufenthaltskarte, Spielstil
	# Bergung nach NEMESIS_BERGUNG_SEK
	for k: Dictionary in kampfunfaehig.duplicate():
		var e: Variant = k["einheit"]
		if not is_instance_valid(e):
			kampfunfaehig.erase(k)
		elif t >= float(k["bis"]) and (_halten.is_empty() or _halten["eintrag"] != k):
			kampfunfaehig.erase(k)
			_chronik(k["person"] as Dictionary, "in den Schild geborgen")
			_wegbeamen(e as Einheit)
	# Begegnungen: NEMESIS_BEGEGNUNG_RUHE ohne Schuss = vorbei (überlebt)
	for id: int in _begegnung.keys():
		var b: Dictionary = _begegnung[id]
		if t - float(b["zuletzt"]) > Werte.NEMESIS_BEGEGNUNG_RUHE:
			var o: Object = instance_from_id(id)
			if o is Einheit and is_instance_valid(o) and not (o as Einheit).kampfunfaehig:
				_begegnung_ende(o as Einheit, true)
			else:
				_begegnung.erase(id)


## Begegnung vorbei – überlebt: Zähler, „Letzte ihres Trupps“ und „zwei Begegnungen“ prüfen.
func _begegnung_ende(e: Einheit, ueberlebt: bool) -> void:
	var id := e.get_instance_id()
	var b: Dictionary = _begegnung.get(id, {})
	_begegnung.erase(id)
	if b.is_empty():
		return
	var p := person_von(e)
	if not p.is_empty():
		p["begegnungen"] = int(p["begegnungen"]) + 1
		var pl: Dictionary = p["lauf"]
		pl["begegnungen"] = int(pl["begegnungen"]) + 1
		if lernen != null:
			lernen.begegnung_ende(e, p, b)   # 22.11. (Teil 5): Wert der Taktik nachführen, nächste wählen
	if not ueberlebt:
		return
	if benannt(p) and gewohnheiten != null and e.leben < e.max_leben * Werte.NEMESIS_KNAPP_VERTRIEBEN:
		gewohnheiten.abschauen(p, "knapp vertrieben")   # 22.11. (Teil 4)
	var l := _lauf_von(e)
	l["ueberlebt"] = int(l["ueberlebt"]) + 1
	var nr := int(b["trupp"])
	if nr >= 0 and nr < o24.trupps.size() and int(b["trupp_n"]) >= Werte.NEMESIS_TRUPP_MIN:
		var lebend := ((o24.trupps[nr] as Dictionary)["mitglieder"] as Array).filter(func(x: Variant) -> bool: return Nemesis.lebt(x))
		if lebend.size() == 1 and lebend[0] == e:
			if befoerdern(e, "rest"):
				return
	if int(l["ueberlebt"]) >= Werte.NEMESIS_BEGEGNUNGEN:
		befoerdern(e, "zwei_begegnungen")


## Lauf vorbei: Rang +1 für mehr als NEMESIS_LAUF_ANTEIL eines Lebensbalkens oder einen Lauf ohne Bergung (höchstens ein
## Rang je Lauf, Deckel NEMESIS_RANG_MAX). Namenlose dieses Laufs fallen aus der Liste.
## 22.11. (Teil 6): danach verdrängen Neue bei voller Liste den mit der schlechtesten Bilanz, und die Liste wird
## gespeichert. `abbruch` (Partie verlassen): kein Rangaufstieg, gespeichert wird trotzdem.
func lauf_ende(abbruch: bool = false) -> void:
	if _gespeichert:
		return
	_gespeichert = true
	var k: Kommandant = spiel.kommandant
	var balken := k.max_leben if k != null else 1.0
	for p: Dictionary in benannte():
		var pl: Dictionary = p["lauf"]
		if bool(pl["dabei"]):
			p["letzter_schaden"] = float(pl["schaden"])   # wer am härtesten getroffen hat, ist nächstes Mal dabei
		p["zuletzt_erledigt"] = not erledigt_von.is_empty() and erledigt_von == p
		if abbruch or not bool(pl["dabei"]) or bool(pl["rang_plus"]) or int(p["rang"]) >= Werte.NEMESIS_RANG_MAX:
			continue
		var grund := ""
		if float(pl["schaden"]) > Werte.NEMESIS_LAUF_ANTEIL * balken:
			grund = "hat Brakk mehr als %d %% eines Lebensbalkens genommen" % roundi(Werte.NEMESIS_LAUF_ANTEIL * 100.0)
		elif not bool(pl["geborgen"]):
			grund = "hat den Lauf ohne Bergung überstanden"
		if grund != "":
			p["rang"] = int(p["rang"]) + 1
			pl["rang_plus"] = true
			_chronik(p, "Rang %d: %s" % [int(p["rang"]), grund])
	personen = personen.filter(func(p: Dictionary) -> bool: return benannt(p))
	if gewohnheiten != null:
		gewohnheiten.lauf_ende()   # 22.11. (Teil 4): wer keine hat, übernimmt Brakks häufigste
	_verdraengen()
	speichern()


## Volle Liste: der Benannte mit der schlechtesten Bilanz (seine Siege minus Bergungen; dann niedrigerer Rang) wird
## „versetzt“ – Neue dieses Laufs sind davor geschützt, solange es Alte gibt.
func _verdraengen() -> void:
	while personen.size() > Werte.NEMESIS_LISTE_MAX:
		var alte := personen.filter(func(p: Dictionary) -> bool: return not bool((p.get("lauf", {}) as Dictionary).get("neu", false)))
		var wahl: Array = alte if not alte.is_empty() else personen
		var schlecht: Dictionary = wahl[0]
		for p: Dictionary in wahl:
			if _guete(p) < _guete(schlecht):
				schlecht = p
		personen.erase(schlecht)
		versetzt.append(schlecht)
		_chronik(schlecht, "versetzt – ein Neuer hat seinen Platz unter den Meistgesuchten")
		chronik_global.append({"datum": Time.get_date_string_from_system(), "text": "%s versetzt" % voller_name(schlecht)})


## Bilanz für die Liste: Siege über Brakk zählen, Bergungen kosten; bei Gleichstand der höhere Rang.
static func _guete(p: Dictionary) -> float:
	var b: Dictionary = p.get("bilanz", {})
	return float(int(b.get("er", 0)) - int(b.get("brakk", 0))) * 10.0 + float(p.get("rang", 1))


# ------------------------------------------------------------------ Speicherung (22.11., Teil 6)

const VERSION := 1
static var datei := "user://nemesis.json"   # Tests setzen eine eigene Datei
## gespeicherte Felder je Person und ihr Standard (fehlt ein Feld in einer alten Datei, gilt der Standard)
const FELDER := {
	"id": 0, "art": "technogunner", "rang": 1, "name": "?", "beiname": "", "titel": "", "faehigkeit": "", "angewohnheit": "",
	"staerke": "", "schwaeche": "", "staerke_bekannt": false, "schwaeche_bekannt": false, "bilanz": {"er": 0, "brakk": 0},
	"begegnungen": 0, "bergungen": 0, "narbe": 0, "geborgen": false, "taktik": {}, "chronik": [], "appell": false,
	"letzter_schaden": 0.0, "zuletzt_erledigt": false, "angewohnheit2": "",
}
const CHRONIK_MAX := 12


## Eine Person aus der Datei: fehlende oder falsch getippte Felder bekommen ihren Standard. {} = unbrauchbar.
static func person_aus(x: Variant) -> Dictionary:
	if not (x is Dictionary):
		return {}
	var d := x as Dictionary
	var p := {}
	for k: String in FELDER:
		var std: Variant = FELDER[k]
		var v: Variant = d.get(k, std)
		if typeof(std) == TYPE_INT and typeof(v) == TYPE_FLOAT:
			v = int(v)   # JSON kennt nur Kommazahlen
		if typeof(v) != typeof(std):
			v = std
		if v is Dictionary:
			v = (v as Dictionary).duplicate(true)   # nie die (schreibgeschützten) Standardwerte selbst weitergeben
		elif v is Array:
			v = (v as Array).duplicate(true)
		p[k] = v
	var b: Dictionary = p["bilanz"]
	p["bilanz"] = {"er": int(b.get("er", 0)), "brakk": int(b.get("brakk", 0))}
	p["rang"] = clampi(int(p["rang"]), 1, Werte.NEMESIS_RANG_MAX)
	if str(p["art"]) not in Werte.FABRIK_EINHEITEN:
		p["art"] = "technogunner"
	return p


static func _datei_lesen() -> Dictionary:
	if not FileAccess.file_exists(datei):
		return {}
	var f := FileAccess.open(datei, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d as Dictionary if d is Dictionary else {}


## Liste laden (beim Einrichten des Laufs).
func laden() -> void:
	var d := _datei_lesen()
	erster_lauf = not bool(d.get("appell_vergeben", false))
	personen = []
	for x: Variant in (d.get("personen", []) as Array if d.get("personen", []) is Array else []):
		var p := person_aus(x)
		if not p.is_empty() and str(p["name"]) not in ["?", ""]:
			personen.append(p)
	chronik_global = (d.get("chronik", []) as Array).duplicate() if d.get("chronik", []) is Array else []
	_datei_zaehler = {}
	var dz: Variant = d.get("zaehler", {})
	if dz is Dictionary:
		for a: String in NemesisGewohnheiten.ARTEN:
			_datei_zaehler[a] = int((dz as Dictionary).get(a, 0))
	_datei_gesehen = {}
	var dg: Variant = d.get("gesehen", [])
	if dg is Array:
		for a: Variant in (dg as Array):
			if str(a) in NemesisGewohnheiten.ARTEN:
				_datei_gesehen[str(a)] = true
	_naechste_id = 1
	for p: Dictionary in personen:
		_naechste_id = maxi(_naechste_id, int(p["id"]) + 1)


## Liste schreiben (Benannte, ohne die Laufdaten). Im Balance-Labor nie.
func speichern() -> void:
	if Labor.aktiv:
		return
	var liste: Array = []
	for p: Dictionary in benannte():
		var q := {}
		for k: String in FELDER:
			q[k] = p.get(k, FELDER[k])
		var ch: Array = q["chronik"]
		if ch.size() > CHRONIK_MAX:
			q["chronik"] = ch.slice(ch.size() - CHRONIK_MAX)
		liste.append(q)
	var gl := chronik_global.slice(maxi(0, chronik_global.size() - 30))
	var f := FileAccess.open(datei, FileAccess.WRITE)
	if f == null:
		return
	var zaehler: Dictionary = gewohnheiten.zaehler if gewohnheiten != null else _datei_zaehler
	var gesehen: Array = (gewohnheiten.gesehen if gewohnheiten != null else _datei_gesehen).keys()
	f.store_string(JSON.stringify({"version": VERSION, "appell_vergeben": true, "personen": liste, "chronik": gl, "zaehler": zaehler, "gesehen": gesehen}, "\t"))
	f.close()
	print("NEMESIS gespeichert: %d Benannte → %s" % [liste.size(), datei])


## Lexikon: erlebte Angewohnheiten aus der Datei und aus dem laufenden Lauf.
static func gesehen_gesamt() -> Dictionary:
	var aus := gesehen_lauf.duplicate()
	var dg: Variant = _datei_lesen().get("gesehen", [])
	if dg is Array:
		for a: Variant in (dg as Array):
			aus[str(a)] = true
	return aus


## Einstellungen: „Meistgesuchte zurücksetzen“ – die Liste ist weg, der nächste Lauf beginnt wieder mit dem Appell.
static func zuruecksetzen() -> void:
	if FileAccess.file_exists(datei):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(datei))


## Laufbeginn: NEMESIS_LAUF_TRUPP aus der Liste dürfen in den Elitetrupp – wer Brakk zuletzt erledigt oder am härtesten
## getroffen hat, immer; dann möglichst eine je Truppenart, sonst gezogen. Neu Beförderte kommen im Lauf dazu.
func _lauf_trupp_ziehen() -> void:
	var wahl: Array = []
	var haertester: Dictionary = {}
	for p: Dictionary in personen:
		if bool(p.get("zuletzt_erledigt", false)):
			wahl.append(p)
		if float(p.get("letzter_schaden", 0.0)) > float(haertester.get("letzter_schaden", 0.0)):
			haertester = p
	if not haertester.is_empty() and not wahl.has(haertester):
		wahl.append(haertester)
	var rest := personen.filter(func(p: Dictionary) -> bool: return not wahl.has(p))
	Zufall.mische(rest)
	for p: Dictionary in rest.duplicate():   # erst Truppenarten, die noch fehlen
		if wahl.size() >= Werte.NEMESIS_LAUF_TRUPP:
			break
		if not wahl.any(func(q: Dictionary) -> bool: return str(q["art"]) == str(p["art"])):
			wahl.append(p)
			rest.erase(p)
	for p: Dictionary in rest:
		if wahl.size() >= Werte.NEMESIS_LAUF_TRUPP:
			break
		wahl.append(p)
	for p: Dictionary in wahl:
		(p["lauf"] as Dictionary)["erlaubt"] = true
	if not wahl.is_empty():
		print("NEMESIS Laufbeginn: %s" % ", ".join(PackedStringArray(wahl.map(func(p: Dictionary) -> String: return voller_name(p)))))


# ------------------------------------------------------------------ Wiedersehen (22.11., Teil 6)

const WIEDERSEHEN := {
	"vorn": [
		"Diesmal ohne Klonmaschine, Kommandant?",
		"Sie schon wieder. Ich hatte gehofft, Sie bleiben länger liegen.",
		"{stand}. Wollen Sie aufholen?",
		"In meiner Kartei ist noch Platz – für Sie.",
	],
	"hinten": [
		"Das Knie spüre ich bis heute.",
		"Letztes Mal hatten Sie Glück. Heute nicht.",
		"Ich habe den Schild von innen gesehen. Sie werden ihn nie sehen.",
		"Narben vergessen nicht, Kommandant.",
	],
	"gleich": [
		"Gleichstand. Das ändern wir jetzt.",
		"Einer von uns geht heute in Führung.",
		"Ich kenne Ihre Tricks. Sie kennen meine.",
	],
	"neu": [
		"Befehl 24, Kommandant. Nichts Persönliches.",
		"Sonde 7 sagt, Sie sind gefährlich. Ich will es selbst sehen.",
		"Merken Sie sich meinen Namen.",
		"Ein Name ist schnell verdient. Ihrer ist schnell vergessen.",
	],
}


## Erster Treffer auf einen Benannten in diesem Lauf: Namensschild und eine Zeile zur Bilanz (Hologramm, das Spiel läuft weiter).
func _wiedersehen(p: Dictionary) -> void:
	var b: Dictionary = p["bilanz"]
	var er := int(b["er"])
	var br := int(b["brakk"])
	var lage := "neu" if er + br == 0 else ("vorn" if er > br else ("hinten" if br > er else "gleich"))
	var zeilen: Array = WIEDERSEHEN[lage]
	var zeile := str(zeilen[randi() % zeilen.size()]).replace("{stand}", bilanz_text(p))
	wiedersehen = {"name": voller_name(p), "zeile": zeile, "bis": zeit() + Werte.NEMESIS_WIEDERSEHEN_SEK, "farbe": umriss_farbe(p), "lage": lage, "stand": bilanz_text(p)}
	print("NEMESIS Wiedersehen: %s – „%s“" % [voller_name(p), zeile])


# ------------------------------------------------------------------ Endgültig ausschalten (22.11., Teil 6)

## [E] gedrückt/losgelassen (Order24.ego_taste). true = gehört hierher (neben einem kampfunfähigen Benannten).
func ausschalten_taste(gedrueckt: bool) -> bool:
	if not gedrueckt:
		if _halten.is_empty():
			return false
		_halten = {}
		spiel.melde("Losgelassen – er wird geborgen.", 1.5)
		return true
	var k := _ausschalten_ziel()
	if k.is_empty():
		return false
	_halten = {"eintrag": k, "t": 0.0}
	Ton.spiele(spiel, "tc-arc", -4.0)
	return true


## Der kampfunfähige Benannte, neben dem Brakk steht ({} = keiner).
func _ausschalten_ziel() -> Dictionary:
	var kd: Kommandant = spiel.kommandant
	if kd == null:
		return {}
	for k: Dictionary in kampfunfaehig:
		var e: Variant = k["einheit"]
		if is_instance_valid(e) and benannt(k["person"] as Dictionary) and (e as Einheit).position.distance_to(kd.position) <= Werte.NEMESIS_HALTEN_NAH * Werte.ZELLE:
			return k
	return {}


func halte_zeit(p: Dictionary) -> float:
	return Werte.NEMESIS_HALTEN_HOCH if int(p.get("rang", 1)) >= Werte.NEMESIS_HALTEN_RANG else Werte.NEMESIS_HALTEN


## Halten läuft: Brakk muss dranbleiben; der Beam wartet so lange. Voll → endgültig ausgeschaltet.
func _halten_weiter(dt: float) -> void:
	if _halten.is_empty():
		return
	var k: Dictionary = _halten["eintrag"]
	var kd: Kommandant = spiel.kommandant
	if not kampfunfaehig.has(k) or not is_instance_valid(k["einheit"]) or kd == null \
			or (k["einheit"] as Einheit).position.distance_to(kd.position) > (Werte.NEMESIS_HALTEN_NAH + 0.4) * Werte.ZELLE:
		_halten = {}
		return
	_halten["t"] = float(_halten["t"]) + dt
	k["bis"] = maxf(float(k["bis"]), zeit() + 0.3)   # die Bergung wartet, solange er festgehalten wird
	if float(_halten["t"]) >= halte_zeit(k["person"] as Dictionary):
		_halten = {}
		ausschalten(k)


## Anzeige für das HUD: {} oder {"text", "anteil"} (neben einem Kampfunfähigen bzw. beim Halten).
func ausschalten_hinweis() -> Dictionary:
	if not _halten.is_empty():
		var p: Dictionary = (_halten["eintrag"] as Dictionary)["person"]
		return {"text": "%s endgültig ausschalten …" % voller_name(p), "anteil": float(_halten["t"]) / halte_zeit(p)}
	var k := _ausschalten_ziel()
	if k.is_empty():
		return {}
	return {"text": "[E] halten: %s endgültig ausschalten" % voller_name(k["person"] as Dictionary), "anteil": -1.0}


## Endgültig weg: eigener Ton, Chronik, ein Ring als Beute; der Eintrag verschwindet aus der Liste.
func ausschalten(k: Dictionary) -> void:
	var p: Dictionary = k["person"]
	var e: Variant = k["einheit"]
	kampfunfaehig.erase(k)
	_chronik(p, "von Brakk endgültig ausgeschaltet")
	chronik_global.append({"datum": Time.get_date_string_from_system(), "text": "%s endgültig ausgeschaltet" % voller_name(p)})
	personen.erase(p)
	ausgeschaltet.append(p)
	if is_instance_valid(e):
		var pos := (e as Einheit).position
		if Werte.grafik_neu:
			spiel.effekte.fx("v_tod", pos + Vector2(0, -6), 0.6)
		spiel.effekte.flaeche(pos, Werte.ZELLE * 0.9, Color("ff5a6e"))
		_wegbeamen(e as Einheit, false)
	Ton.spiele(spiel, "death-tc", 2.0)   # eigener Ton: Fall und tiefer Schlag
	Ton.spiele(spiel, "hit-boom", -2.0)
	if spiel.get("_einblendung") != null:
		spiel._einblendung.banner("AUSGESCHALTET", voller_name(p), Color("ff5a6e"))
	var beute := _beute(str(p["art"]))
	spiel.melde("%s ist endgültig ausgeschaltet.%s" % [voller_name(p), (" Beute: " + beute) if beute != "" else ""], 4.0)


## Ring als Beute – passend zu seiner Truppenart: neuer Ring (Finger frei) oder eine Stufe mehr; sonst Gold.
func _beute(art: String) -> String:
	var kd: Kommandant = spiel.kommandant
	if kd == null or kd.fortschritt == null:
		return ""
	var f: BrakkFortschritt = kd.fortschritt
	var passend: Array = []
	var andere: Array = []
	for r: String in BrakkFortschritt.RINGE:
		var st := f.ring_stufe(r)
		var geht := st < BrakkFortschritt.RING_PREISE.size() and (st > 0 or f.ringe.size() < f.finger())
		if not geht:
			continue
		if str((BrakkFortschritt.RINGE[r] as Dictionary).get("truppe", "")) == art:
			passend.append(r)
		else:
			andere.append(r)
	var liste := passend if not passend.is_empty() else andere
	if liste.is_empty():
		spiel.budget += int(BrakkFortschritt.RING_PREISE[0])
		return "%d Gold" % int(BrakkFortschritt.RING_PREISE[0])
	var ring := str(Zufall.waehle(liste))
	var st0 := f.ring_stufe(ring)
	spiel.budget += int(BrakkFortschritt.RING_PREISE[st0])   # geschenkt: der Preis kommt dazu und wird gleich bezahlt
	if f.kaufe(ring, spiel) != "":
		return ""
	return "%s (Stufe %d)" % [str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring)), f.ring_stufe(ring)]


func _sonde(text: String) -> void:
	spiel.melde("Sonde 7: „%s“" % text, 5.0)


# ------------------------------------------------------------------ Bildschirme (Teil 7, 22.11.)

const ART_TEXT := {"technogunner": "Technogunner", "scharfschuetze": "Scharfschütze", "plasmawerfer": "Plasmawerfer"}
const WAFFE_TEXT := {"technogunner": "mit dem Lasergewehr", "scharfschuetze": "mit dem Scharfschützengewehr", "plasmawerfer": "mit dem Plasmawerfer"}
const LAGE_TEXT := {
	"hinterhalt": "aus dem Hinterhalt", "wall": "von einem Wall herab", "brand": "im Brandfeld", "dach": "oben auf dem Erdwall",
	"luft": "mitten im Sprung", "fern": "aus großer Entfernung", "nah": "aus nächster Nähe", "": "im offenen Feuergefecht",
}
## Was er zum Abschied sagt (3–4 Zeilen je Lage; Hologramm-Stil im Deathscreen)
const TOD_ZEILEN := {
	"erst": [
		"Befehl 24 ist Befehl 24, Kommandant. Nichts Persönliches.",
		"Ich habe nur gezielt. Den Rest haben Sie erledigt.",
		"Sonde 7 wird zufrieden sein. Ich bin es auch.",
		"Sie haben mich nicht kommen sehen. Das war der Plan.",
	],
	"rache": [
		"Das Knie spüre ich bis heute. Sie spüren jetzt gar nichts mehr.",
		"Sie haben mich in den Schild geschickt. Ich habe den Rückweg gefunden.",
		"Einmal Sie, einmal ich. Ich zähle mit, Kommandant.",
		"Narben verheilen. Ihre Bilanz nicht.",
	],
	"wieder": [
		"Schon wieder? Langsam wird es Routine.",
		"Ich kenne Ihre Wege inzwischen besser als Sie.",
		"Gleiche Stelle, gleiche Uhrzeit, gleiches Ergebnis.",
		"Soll ich es aufschreiben, Kommandant? Ach, ich habe ja eine Kartei.",
	],
	"befoerdert": [
		"Gestern ohne Namen. Heute mit Ihrem.",
		"Merken Sie sich mein Gesicht. Sie werden es wiedersehen.",
		"Die Beförderung widme ich Ihnen, Kommandant.",
		"Ein Name. Endlich. Danke für die Hilfe.",
	],
}


## „Stand 2 : 1 für ihn“ (er = seine Siege über Brakk, brakk = Bergungen durch Brakk)
static func bilanz_text(p: Dictionary) -> String:
	var b: Dictionary = p.get("bilanz", {})
	var er := int(b.get("er", 0))
	var br := int(b.get("brakk", 0))
	return "Stand %d : %d %s" % [er, br, "für ihn" if er > br else ("für dich" if br > er else "– ausgeglichen")]


## Deathscreen: wer Brakk erledigt hat ({} = keine Einheit – Turm, Batterie: der bisherige Schluss).
func tod_bericht() -> Dictionary:
	if erledigt_von.is_empty():
		return {}
	var p := erledigt_von
	var i := erledigt_info
	var art := str(i.get("art", p["art"]))
	var lage := str(i.get("lage", ""))
	var bil: Dictionary = p["bilanz"]
	var art_der_zeile := "befoerdert" if bool(i.get("namenlos", false)) else ("rache" if int(bil["brakk"]) > 0 else ("wieder" if int(bil["er"]) >= 2 else "erst"))
	var zeilen: Array = TOD_ZEILEN[art_der_zeile]
	var aus := {
		"name": voller_name(p), "art": str(ART_TEXT.get(art, art)), "rang": int(p["rang"]), "dienstgrad": dienstgrad(p),
		"begegnung": int(i.get("begegnung", 1)), "bilanz": bilanz_text(p),
		"womit": ("mit %s %s" % [NemesisFaehigkeiten.name_von(str(i["faehigkeit"])), str(LAGE_TEXT.get(lage, LAGE_TEXT[""]))]) if str(i.get("faehigkeit", "")) != "" \
			else ("mit seinem %s (gelernt von dir) %s" % [NemesisGewohnheiten.name_von(str(i["gewohnheit"])), str(LAGE_TEXT.get(lage, LAGE_TEXT[""]))]) if str(i.get("gewohnheit", "")) != "" \
			else ("%s %s" % [str(NemesisLernen.TEXT.get(str(i.get("taktik", "")), "")), str(WAFFE_TEXT.get(art, ""))]) if str(i.get("taktik", "")) not in ["", "direkt"] \
			else "%s %s" % [str(LAGE_TEXT.get(lage, LAGE_TEXT[""])), str(WAFFE_TEXT.get(art, ""))],
		"zeile": str(zeilen[randi() % zeilen.size()]), "namenlos": bool(i.get("namenlos", false)),
		"art_dativ": "Scharfschützen" if art == "scharfschuetze" else str(ART_TEXT.get(art, art)),
		"grund": "Begründung: %s" % str(TAT_TEXT["letzter_treffer"]),
		"aufstieg": "" if bool(i.get("namenlos", false)) or int(p["rang"]) <= int(i.get("rang_vorher", 0)) else "Aufstieg: %s → %s" % [DIENSTGRADE[int(i.get("rang_vorher", 0))], dienstgrad(p)],
	}
	return aus


## Siegbild/Bericht: was dieser Lauf mit den Eliten gemacht hat – je [Name, Art, Zusatz] (Art: befoerdert / vertrieben /
## ausgeschaltet).
func lauf_liste() -> Array:
	var aus: Array = []
	for b: Dictionary in befoerderungen:
		aus.append([voller_name(b["person"] as Dictionary), "befoerdert", str(TAT_TEXT.get(str(b["grund"]), ""))])
	for p: Dictionary in personen + versetzt:   # auch wer am Laufende versetzt wurde
		var n := int((p.get("lauf", {}) as Dictionary).get("bergungen", 0))
		if benannt(p) and n > 0:
			aus.append([voller_name(p), "vertrieben", "" if n == 1 else "%d×" % n])
	for p: Dictionary in ausgeschaltet:
		aus.append([voller_name(p), "ausgeschaltet", ""])
	for p: Dictionary in versetzt:
		aus.append([voller_name(p), "versetzt", ""])   # 22.11. (Teil 6): von einem Neuen verdrängt
	return aus


## Die Meistgesuchten aus user://nemesis.json (fehlt die Datei: leer). Verträgt fehlende und alte Felder.
static func meistgesuchte() -> Array:
	var d := _datei_lesen()
	var aus: Array = []
	for x: Variant in (d.get("personen", []) as Array if d.get("personen", []) is Array else []):
		var p := person_aus(x)
		if not p.is_empty() and str(p["name"]) not in ["?", ""]:
			aus.append(p)
	aus.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rang"]) > int(b["rang"]) or (int(a["rang"]) == int(b["rang"]) and _guete(a) > _guete(b)))
	return aus


## Partie verlassen, bevor der Lauf endete: trotzdem speichern (ohne Rangaufstieg).
func _exit_tree() -> void:
	if o24 != null and o24.laeuft and not _gespeichert:
		lauf_ende(true)


## Namensschilder in der Ego-Sicht (rein optisch, im Bildtakt).
func _process(_delta: float) -> void:
	var hd: HdAnsicht = spiel.hd if spiel != null else null
	var noch := {}
	if hd != null:
		for id: int in _person_von:
			var p: Dictionary = _person_von[id]
			var e: Variant = instance_from_id(id)
			if not benannt(p) or not is_instance_valid(e) or not (e as Einheit).is_visible_in_tree():
				continue
			var u := e as Einheit
			noch[id] = true
			var fs := u.get_node_or_null("Frontschild") as Sprite2D   # 22.11. (Teil 4): Frontschild immer zur Blickrichtung
			if fs != null:
				fs.offset.x = -12.0 if u._sprite.flip_h else 6.0
			var schild: Label3D = _schilder.get(id, null)
			if schild == null:
				schild = Label3D.new()
				schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				schild.font_size = 30
				schild.outline_size = 8
				schild.pixel_size = 0.0035
				schild.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
				hd.add_child(schild)
				_schilder[id] = schild
			var text := voller_name(p) + ("\n„%s“" % str(p["titel"]) if str(p["titel"]) != "" else "")
			var ansage := faehigkeiten.schild_zeile(u) if faehigkeiten != null else ""
			if ansage != "":
				text += "\n" + ansage   # 22.11. (Teil 3): Fähigkeit angekündigt bzw. läuft
			if schild.text != text:
				schild.text = text
			schild.modulate = umriss_farbe(p).lightened(0.25)
			var h := 1.35 + (hd.H if u.in_stellung() else 0.0)
			schild.position = Vector3(u.position.x / Werte.ZELLE, h, (u.position.y - Werte.KARTE_OBEN) / Werte.ZELLE)
	for id: int in _schilder.keys():
		if not noch.has(id):
			(_schilder[id] as Node).queue_free()
			_schilder.erase(id)
