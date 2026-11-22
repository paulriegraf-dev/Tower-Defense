class_name Erfolge
extends CanvasLayer
## Erfolge (18.11.2026): ein heimliches Tutorial – sie lenken auf Mechaniken, die man sonst übersieht.
## Die Liste steht hier, was freigeschaltet ist, im Profil (user://profil.json, Schlüssel „erfolge“).
## Freischalten: Erfolge.melde("id"). Im Spiel geht das über main.gd erfolg(), das die Sandbox ausnimmt.
## Beim Freischalten: Einblendung oben mit Symbol und ein Ton (Ebene am Wurzelknoten, übersteht den Szenenwechsel).
## Belohnungen (18.11., Paul): kommen später. Jeder Eintrag hat dafür das Feld „belohnung“ (leer = keine),
## ausgegeben wird sie in _gib_belohnung().

const Stil := preload("res://scripts/ui/ui_stil.gd")
const ANZEIGE_SEK := 4.5
const TON := "ui-klick"   # Platzhalter, bis es einen eigenen Erfolgston gibt

const LISTE: Array[Dictionary] = [
	{"id": "formenlehre", "name": "Formenlehre", "text": "Alle fünf Formtürme mindestens einmal gebaut.", "symbol": "turm", "versteckt": false, "belohnung": ""},
	{"id": "einsamer_posten", "name": "Einsamer Posten", "text": "Eine Truppe auf einem Wachposten erledigt einen Gegner.", "symbol": "stellung", "versteckt": false, "belohnung": ""},
	{"id": "zurueckgeholt", "name": "Zurückgeholt", "text": "Einen eingenommenen Checkpoint zurückerobert.", "symbol": "wall", "versteckt": false, "belohnung": ""},
	{"id": "letzter_moment", "name": "Im letzten Moment", "text": "Einen Sprenger erledigt, während er schon zündet.", "symbol": "panzer", "versteckt": false, "belohnung": ""},
	{"id": "doppelt_haelt", "name": "Doppelt hält besser", "text": "Eine Panzerung hat einen Sprenger abgefangen.", "symbol": "panzer", "versteckt": false, "belohnung": ""},
	{"id": "aufgespiesst", "name": "Aufgespießt", "text": "Ein Lanzenstrahl erledigt vier Gegner auf einmal.", "symbol": "turm", "versteckt": false, "belohnung": ""},
	{"id": "feldlazarett", "name": "Feldlazarett", "text": "Ein Heilturm holt eine gefallene Truppe zurück.", "symbol": "herz", "versteckt": false, "belohnung": ""},
	{"id": "kuppelschlag", "name": "Kuppelschlag", "text": "Eine Schildkuppel wehrt einen Stein ab.", "symbol": "batterie", "versteckt": false, "belohnung": ""},
	{"id": "fester_platz", "name": "Fester Platz", "text": "Eine Stellung per Pfeil einer Fabrik zugewiesen.", "symbol": "fabrik", "versteckt": false, "belohnung": ""},
	{"id": "sparfuchs", "name": "Sparfuchs", "text": "Am Rundenende die vollen Zinsen kassiert.", "symbol": "muenze", "versteckt": false, "belohnung": ""},
	{"id": "doppelgaenger", "name": "Doppelgänger", "text": "Einen Gegner durch die Klonmaschine geschickt.", "symbol": "brakk", "versteckt": false, "belohnung": ""},
	## 21.11. (Paul): schaltet den Brakk-Mode im Startmenü frei (Profil.brakk_modus_frei); der Phantom-Modus hängt an „gegenangriff“
	{"id": "aufgestellt", "name": "Zur Stelle", "text": "Brakk einmal in einer Partie aufgestellt – der Brakk-Mode ist frei.", "symbol": "brakk", "versteckt": false, "belohnung": ""},
	{"id": "kommandant", "name": "Kommandant", "text": "Brakk hat insgesamt 50 Gegner erledigt.", "symbol": "brakk", "versteckt": false, "belohnung": ""},
	{"id": "gegenangriff", "name": "Gegenangriff", "text": "Das HQ des Gegners in Runde 20 zerstört.", "symbol": "play", "versteckt": false, "belohnung": ""},
	{"id": "spiegelbild", "name": "Spiegelbild", "text": "Dein Bau ist zum ersten Phantom geworden.", "symbol": "buch", "versteckt": false, "belohnung": ""},
	{"id": "einbrecher", "name": "Einbrecher", "text": "Im Phantom-Angriff eine Verteidigung geknackt.", "symbol": "raster", "versteckt": false, "belohnung": ""},
	{"id": "spitze", "name": "Spitze", "text": "Platz 1 in einer Rangliste.", "symbol": "balken", "versteckt": false, "belohnung": ""},
	{"id": "von_hinten", "name": "Von hinten", "text": "Einen Schildträger mit einem Treffer von hinten erledigt.", "symbol": "tor", "versteckt": true, "belohnung": ""},
	{"id": "unberuehrt", "name": "Unberührt", "text": "In Runde 20 kein Leben verloren und gewonnen.", "symbol": "herz", "versteckt": true, "belohnung": ""},
	{"id": "ohne_fabrik", "name": "Ohne Nachschub", "text": "Gewonnen, ohne eine Fabrik zu bauen (Batterien zählen nicht).", "symbol": "fabrik", "versteckt": true, "belohnung": ""},
	## 19.11.: drei Erfolge, die später Anführer freischalten (Schritt 2b)
	{"id": "baumeister", "name": "Baumeister", "text": "In einer Partie alle fünf Formtürme gebaut, einen davon auf Stufe 3.", "symbol": "turm", "versteckt": false, "belohnung": ""},
	{"id": "ausbilder", "name": "Ausbilder", "text": "Tutorial abgeschlossen und mit mindestens 6 Fabriken gewonnen, eine davon auf Stufe 3.", "symbol": "fabrik", "versteckt": false, "belohnung": ""},
	{"id": "deutscher_sparer", "name": "Deutscher Sparer", "text": "Eine Runde mit mindestens 1000 Budget begonnen und die Partie gewonnen.", "symbol": "muenze", "versteckt": true, "belohnung": ""},
	## 20.11. (Paul): Befehl 24 (Brakk-Mode Rogue) – versteckt, gesperrt steht statt der Bedingung eine Anspielung („tipp“)
	{"id": "befehl24", "name": "Befehl 24", "text": "Vom eigenen Rat zum Verräter erklärt – und die Flucht angetreten (Brakk-Mode Rogue).", "symbol": "brakk", "versteckt": true, "belohnung": "",
		"tipp": "Wer zu oft gewinnt, wird dem Rat unheimlich …"},
	{"id": "ueberlaeufer", "name": "Der Feind meines Feindes", "text": "Mit den Myriaden das Technoclan-HQ zerstört – das geheime Ende von Befehl 24.", "symbol": "raster", "versteckt": true, "belohnung": "",
		"tipp": "1110000 100 010010 1000 1011101010110 01 001"},
]
## 19.11.: Schwellen der neuen Erfolge
const AUSBILDER_FABRIKEN := 6        # so viele Fabriken beim Sieg (Pilotenfabriken zählen nicht)
const SPARER_BUDGET := 1000          # mit so viel Budget eine Runde beginnen (normales Spiel)

static var _ebene: Erfolge = null
var _schlange: Array[Dictionary] = []
var _seit := -1.0
var _flaeche: Control


static func eintrag(id: String) -> Dictionary:
	for e: Dictionary in LISTE:
		if str(e["id"]) == id:
			return e
	return {}


static func anzahl() -> int:
	return LISTE.size()


static func freigeschaltet() -> int:
	var n := 0
	for e: Dictionary in LISTE:
		if Profil.hat_erfolg(str(e["id"])):
			n += 1
	return n


## Schaltet einen Erfolg frei (einmalig). Zeigt die Einblendung und gibt die Belohnung, falls es eine gibt.
static func melde(id: String) -> void:
	var e := eintrag(id)
	if e.is_empty() or not Profil.setze_erfolg(id):
		return
	_gib_belohnung(e)
	_zeige(e)


## 20.11.: Dieselbe Einblendung für andere Rückmeldungen (Entwicklercodes): eigener Titel statt „Erfolg: …“.
static func einblendung(titel: String, text: String, symbol: String) -> void:
	_zeige({"titel": titel, "text": text, "symbol": symbol})


static func _zeige(e: Dictionary) -> void:
	var baum := Engine.get_main_loop() as SceneTree
	if baum == null or baum.root == null or DisplayServer.get_name() == "headless":
		return
	if _ebene == null or not is_instance_valid(_ebene):
		_ebene = Erfolge.new()
		baum.root.add_child.call_deferred(_ebene)
	_ebene._schlange.append(e)


## Platzhalter (18.11.): Hier kommen später Belohnungen hin (z. B. Farben, Abzeichen, Budget zum Start).
static func _gib_belohnung(e: Dictionary) -> void:
	if str(e.get("belohnung", "")) == "":
		return
	print("Erfolg %s: Belohnung „%s“ ist noch nicht eingebaut." % [e["id"], e["belohnung"]])


func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flaeche = Control.new()
	_flaeche.size = Vector2(640, 360)
	_flaeche.scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	_flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flaeche.draw.connect(_male)
	add_child(_flaeche)


func _process(delta: float) -> void:
	if _seit < 0.0:
		if _schlange.is_empty():
			return
		_seit = 0.0
		Ton.spiele(self, TON)
	_seit += delta / maxf(Engine.time_scale, 0.01)
	if _seit >= ANZEIGE_SEK:
		_schlange.pop_front()
		_seit = -1.0
	_flaeche.queue_redraw()


func _male() -> void:
	if _seit < 0.0 or _schlange.is_empty():
		return
	var e: Dictionary = _schlange[0]
	# hinein- und hinausgleiten
	var rein := clampf(_seit / 0.3, 0.0, 1.0)
	var raus := clampf((ANZEIGE_SEK - _seit) / 0.3, 0.0, 1.0)
	var anteil := minf(rein, raus)
	var titel := str(e["titel"]) if e.has("titel") else "Erfolg: " + str(e["name"])   # 20.11.: auch Codes
	var text := str(e["text"])
	var w := ceilf(maxf(Stil.breite(titel, Stil.NORMAL), Stil.breite(text, Stil.KLEIN)) + 44.0)
	var r := Rect2(Vector2(roundf((640.0 - w) / 2.0), roundf(-40.0 + anteil * 86.0)), Vector2(w, 32.0))
	Stil.platte(_flaeche, r, 4.0, Color(0.06, 0.07, 0.1, 0.95), Stil.GOLD)
	Stil.symbol(_flaeche, str(e["symbol"]), Vector2(r.position.x + 17.0, r.get_center().y), 2.0, Stil.GOLD)
	Stil.schreibe(_flaeche, Vector2(r.position.x + 34.0, r.position.y + (10.0 if text != "" else 16.0)), titel, Stil.NORMAL, Stil.GOLD)   # 20.11.: ohne zweite Zeile mittig
	Stil.schreibe(_flaeche, Vector2(r.position.x + 34.0, r.position.y + 22.0), text, Stil.KLEIN, Stil.TEXT)
