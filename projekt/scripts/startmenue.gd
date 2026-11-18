class_name Startmenue extends CanvasLayer
## Startmenü (16.11.2026, schlicht wie bei anderen Tower-Defense-Spielen): Titel, darunter eine senkrechte Liste.
##   Spielen        → Los, Karte normal/groß, Tutorial an/aus
##   Sandbox        → Sandbox spielen / Szenario bauen (18.11.)
##   Phantom-Modus  → Angreifen / Verteidigen
##   Einstellungen  → Grafik, Vollbild, Mauern, Übersicht
##   Beenden
## Oben rechts das Profil (18.11.): Spitzname und Statistiken. Im Phantom-Modus rechts die Rangliste (online, Elo).
## Maus oder Tasten (↑ ↓ wählen, Enter bestätigt, Esc zurück). Hintergrund: die Abendbühne (assets/neu/menue),
## rechts posieren die drei Technoclan-Truppen. Gezeichnet im UI-Raster 640×360 (zweifach skaliert).
## Frühere Fassungen (Knopfliste, Basislager, Basisstraße): _vor_startmenue/.

signal gewaehlt(sandbox: bool)
signal phantom_gewaehlt(art: String, pfad: String)
signal tutorial_gewaehlt
signal uebersicht_gewaehlt
signal brakk_gewaehlt   # 18.11.: Brakk-Mode

const Stil := preload("res://scripts/ui/ui_stil.gd")
const LICHT := Color("7fe0ff")
const KUPFER_HELL := Color("ffb070")
const LISTE_X := 56.0
const LISTE_Y := 128.0
const ZEILE_H := 24.0
const BREITE := 300.0
const LOGO_SKALA := 4.0 / 3.0     # 1 Logopixel = 4 Bildschirmpixel bei 1080p
## 18.11.: Adresse von Terrain Conquester für das Emblem unten rechts. Leer = Emblem ausgeblendet (TC noch nicht öffentlich).
const TC_ADRESSE := "https://paulriegraf-dev.github.io/Terrain-Conquester/"

var spiel: Node                    # setzt main.gd
var _welt: Flaeche
var _bilder := {}
var _seite := "haupt"              # haupt, spielen, phantom, einstellungen
var _wahl := 0
var _maus := Vector2(-100, -100)
var _zeit := 0.0
var _tutorial := false
var _wahl_karte := "felsenpass"    # 18.11.: Karte auf der Seite „Herausforderungen“
var _wahl_herausforderung := ""      # 18.11.: Herausforderung auf derselben Seite ("" = keine)
var _meldung := ""
var _eintraege: Array = []         # [Text, Aktion, Untertitel, Farbe]
# Titelbild (NES/Mega-Drive-Art): nur beim ersten Öffnen nach Programmstart, eine Taste/ein Klick führt zur Liste
static var _titel_gesehen := false
var _titel := false
var _titel_zeit := 0.0
var _sterne: Array = []
# Profil und Rangliste (18.11.)
const PROFIL_H := 18.0
const TAFEL := Rect2(372, 60, 252, 276)
var _eingabe: LineEdit              # unsichtbares Eingabefeld für den Spitznamen (gezeichnet wird selbst)
var _erststart := false             # erster Start: nach dem Namen fragen
var _laedt := false                 # ein Online-Phantom wird gerade geladen
var _online_stand := -1


class Flaeche extends Control:
	var malen: Callable
	var eingabe: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)
	func _gui_input(event: InputEvent) -> void:
		if eingabe.is_valid():
			eingabe.call(event)


func _init() -> void:
	layer = 100
	_welt = Flaeche.new()
	_welt.size = Vector2(640, 360)
	_welt.scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	_welt.mouse_filter = Control.MOUSE_FILTER_STOP
	_welt.malen = _male
	_welt.eingabe = _maus_eingabe
	add_child(_welt)
	_zeige("haupt")
	_titel = not _titel_gesehen
	_titel_gesehen = true
	var z := RandomNumberGenerator.new()
	z.seed = 7
	for i in 70:
		_sterne.append([Vector2(z.randf() * 640.0, z.randf() * 200.0), z.randf() * TAU, z.randf()])
	_eingabe = LineEdit.new()
	_eingabe.max_length = Profil.NAME_MAX
	_eingabe.modulate = Color(1, 1, 1, 0)
	_eingabe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eingabe.position = Vector2(-400, -400)
	_eingabe.size = Vector2(200, 30)
	_eingabe.context_menu_enabled = false
	add_child(_eingabe)
	Online.lade_listen()   # Phantom-Liste und Rangliste schon vorab holen
	if not _titel:
		_frage_namen_beim_ersten_mal()



func _bild(pfad: String) -> Texture2D:
	if not _bilder.has(pfad):
		_bilder[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _bilder[pfad]


# ------------------------------------------------------------------ Seiten

func _zeige(seite: String) -> void:
	if _tippt():
		_eingabe.release_focus()
	if seite == "phantom":
		Online.lade_listen()   # Rangliste auffrischen
	_seite = seite
	_kartenbild_daten.clear()   # 18.11.: Karten können sich geändert haben (Import, Editor)
	_wahl = 0
	_meldung = ""
	_baue()


func _baue() -> void:
	Werte.lade_einstellungen()
	_eintraege = []
	match _seite:
		"haupt":
			_eintraege = [
				# 18.11. (Paul): Reihenfolge nach Wichtigkeit
				["Spielen", _zeige.bind("spielen"), "", LICHT],
				["Phantom-Modus", _zeige.bind("phantom"), "", Stil.TEXT],
				["Brakk-Mode", _brakk_mode, "", Stil.TEXT],
				["Sandbox", _zeige.bind("sandbox"), "", Stil.TEXT],
				["Herausforderungen", _zeige.bind("herausforderung"), "", Stil.TEXT],
				["Einstellungen", _zeige.bind("einstellungen"), "", Stil.TEXT],
				["Beenden", _beenden, "", Stil.TEXT_BLASS],
			]
			# 18.11.: unterbrochene Partie (Seite neu geladen, Spiel geschlossen) ganz oben anbieten
			var runde: int = spiel.zwischenstand_runde() if spiel != null else 0
			if runde > 0:
				_eintraege.push_front(["Fortsetzen · Runde %d" % runde, _fortsetzen, "deine unterbrochene Partie", KUPFER_HELL])
				_eintraege[1][3] = Stil.TEXT
		"sandbox":
			# 18.11.: Sandbox als Unterseite – spielen wie bisher oder eigene Karte bauen
			_eintraege = [
				["Sandbox spielen", _starte.bind(true, "sandbox"), "unendlich Budget, alle Bauwerke ab Runde 1", LICHT],
				["Szenario bauen", _szenario_bauen, "eigene Karte mit Gelände, Regeln und Wellen", Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"herausforderung":
			# 18.11.: weitere Karten und Herausforderungen – zählt nicht für Rangliste und Phantome (außer PaulLand ohne Herausforderung)
			var haupt := _wahl_karte == "paulland" and _wahl_herausforderung == ""
			_eintraege = [
				["Los geht's", _starte.bind(true, "normal", _wahl_karte, _wahl_herausforderung), "wie „Spielen“ – zählt für Rangliste und Phantome" if haupt else "zählt nicht für Rangliste und Phantome", LICHT],
				["Karte: " + _karten_titel(_wahl_karte), _naechste_karte, _karten_text(_wahl_karte), Stil.TEXT],
				["Herausforderung: " + Werte.herausforderung_name(_wahl_herausforderung), _naechste_herausforderung, Werte.herausforderung_text(_wahl_herausforderung), Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"spielen":
			_eintraege = [
				["Los geht's", _los, "20 Runden gegen die Myriaden" + (" · mit Tutorial" if _tutorial else ""), LICHT],
				["Tutorial: " + ("an" if _tutorial else "aus"), _tutorial_umschalten, "Sonde 7 erklärt Schritt für Schritt", Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"phantom":
			var on := Online.bereit()
			var nv := (Online.listen["verteidigung"] as Array).size() if on else Phantom.liste("verteidigung", true).size()
			var na := (Online.listen["angriff"] as Array).size() if on else Phantom.liste("angriff").size()
			var wo := " online" if on else ""
			var staerkste := str(Profil.einstellung("phantom_wahl", "zufall")) == "staerkste"
			_eintraege = [
				["Angreifen", _phantom.bind("verteidigung"), "Greife den Bau eines anderen Spielers an · " + _anzahl(nv, "Phantom" + wo, "Phantome" + wo, "noch keine Phantome hinterlegt"), KUPFER_HELL],
				["Verteidigen", _phantom.bind("angriff"), "Tritt gegen den Angriff eines anderen Spielers an · " + _anzahl(na, "Angriff" + wo, "Angriffe" + wo, "noch keine Angriffe hinterlegt"), LICHT],
				["Gegner: " + ("Stärkste" if staerkste else "Zufall"), _wahl_umschalten, "die fünf Besten der Rangliste" if staerkste else "irgendein Phantom aus dem Pool", Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"profil":
			if _erststart:
				_eintraege = [
					["Name: " + _name_text(), _starte_eingabe, "Enter bestätigt · bis 16 Zeichen", LICHT],
					["Später", _spaeter, "geht auch jederzeit oben rechts", Stil.TEXT_BLASS],
				]
			else:
				_eintraege = [
					["Name: " + _name_text(), _starte_eingabe, "Enter bestätigt · bis 16 Zeichen" if _tippt() else "zum Ändern klicken", LICHT],
					["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
				]
		"grafik":
			_eintraege = [
				["Vogelperspektive (empfohlen)", _grafik_antwort.bind("neu"), "läuft am Handy flüssig und braucht wenig Speicher", LICHT],
				["HD-2D", _grafik_antwort.bind("hd"), "schöner, braucht aber viel Grafikspeicher – am Handy oft Abstürze", Stil.TEXT],
			]
		"einstellungen":
			var namen :={"klassisch": "Klassisch", "neu": "Vogelperspektive", "hd": "HD-2D (empfohlen)"}
			_eintraege = [
				["Grafik: " + str(namen.get(Werte.grafik, "?")), _naechste_grafik, "gilt ab der nächsten Partie", Stil.TEXT],
				["Vollbild: " + ("an" if Werte.vollbild else "aus"), _vollbild, "auch mit [F11]", Stil.TEXT],
			]
			if Werte.grafik_hd:
				var wnamen := {"tech": "Tech-Mauer (empfohlen)", "block": "Blöcke", "energie": "Energiewand"}
				_eintraege.append(["Mauern: " + str(wnamen.get(Werte.wand_stil, "Tech-Mauer")), _naechste_mauer, "auch im Spiel mit [M]", Stil.TEXT])
			_eintraege.append(["Musik: " + _prozent_text(Werte.musik), _naechste_musik.bind(10), "Klick lauter, Rechtsklick leiser · auch ← →", Stil.TEXT, _naechste_musik])
			_eintraege.append(["Geräusche: " + _prozent_text(Werte.toene), _naechste_toene.bind(10), "Schüsse nur nah herangezoomt · ← →", Stil.TEXT, _naechste_toene])
			_eintraege.append(["Übersicht", func(): uebersicht_gewaehlt.emit(), "Gegner, Truppen, Bauten, Regeln", Stil.TEXT])
			_eintraege.append(["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS])
	_wahl = clampi(_wahl, 0, _eintraege.size() - 1)


## 18.11.: Kartenwahl auf der Seite „Herausforderungen“ (Titel und Beschreibung stehen in karten/<name>.json).
static func _karten_titel(name: String) -> String:
	var titel := str(Werte.karten_daten(name).get("name", name))
	return titel + (" (eigene)" if Werte.ist_eigene_karte(name) else "")


static func _karten_text(name: String) -> String:
	return str(Werte.karten_daten(name).get("beschreibung", ""))


func _naechste_herausforderung() -> void:
	var schluessel: Array = Werte.HERAUSFORDERUNGEN.map(func(h: Array) -> String: return str(h[0]))
	var i := schluessel.find(_wahl_herausforderung)
	_wahl_herausforderung = str(schluessel[(i + 1) % schluessel.size()])
	_baue()


func _naechste_karte() -> void:
	var alle: Array[String] = Werte.KARTEN.duplicate()
	alle.append_array(Werte.eigene_karten())   # 18.11.: eigene Szenarien aus dem Editor
	var i := alle.find(_wahl_karte)
	_wahl_karte = alle[(i + 1) % alle.size()]
	# 18.11.: ein Szenario bringt seine Herausforderung mit (umstellen geht weiterhin)
	var regeln: Variant = Werte.karten_daten(_wahl_karte).get("regeln", {})
	_wahl_herausforderung = str((regeln as Dictionary).get("herausforderung", "")) if regeln is Dictionary else ""
	_baue()


## 18.11.: Szenario-Editor – baut die Szene neu auf (main.gd startet über naechster_start in den Editor).
func _szenario_bauen() -> void:
	Werte.herausforderung = ""
	spiel.herausforderung = ""
	spiel.naechster_start = "editor"
	Ladebild.lade(_welt.get_tree())


## 18.11.: Eine exportierte Karte ins Fenster ziehen = importieren (PC und Browser). Danach steht sie in der Kartenwahl.
func _dateien_fallen(pfade: PackedStringArray) -> void:
	for p: String in pfade:
		var grund: Array = []
		var kname := SzenarioEditor.importiere(p, grund)
		if kname == "":
			_meldung = str(grund[0])
			continue
		_wahl_karte = kname
		_zeige("herausforderung")
		_meldung = "Importiert: %s" % _karten_titel(kname)
		return


static func _anzahl(n: int, eins: String, mehr: String, keins: String) -> String:
	if n <= 0:
		return keins
	return "%d %s hinterlegt" % [n, eins if n == 1 else mehr]


func _los() -> void:
	_starte(true, "tutorial" if _tutorial else "normal")


## 18.11.: Brakk-Mode – braucht Maus und Tastatur (die Ego-Sicht fängt die Maus).
func _brakk_mode() -> void:
	if Touch.noetig():
		_meldung = "Der Brakk-Mode braucht Maus und Tastatur – am Handy geht er noch nicht."
		return
	_starte(true, "brakk")


## Startet einen Modus. Gespielt wird auf der großen Karte (Paul 16.11.); nur aufgezeichnete Bauten (Phantom
## angreifen) bringen ihre eigene Kartengröße mit. Passt die Größe nicht, wird umgestellt und die Szene neu geladen –
## main.gd startet dann über naechster_start gleich in den Modus.
## 18.11.: Ebenso die Karte – alles außer „Herausforderungen“ spielt auf der Hauptkarte PaulLand.
## Herausforderung: "" für alle anderen Modi – so bleibt keine aus einer früheren Partie hängen.
func _starte(gross: bool, art: String, karte: String = "paulland", herausforderung: String = "") -> void:
	Werte.herausforderung = herausforderung
	spiel.herausforderung = herausforderung
	if Werte.karte_gross != gross or (gross and Werte.karte_name != karte):
		Werte.karte_name = karte
		Werte.setze_karte(gross)
		Werte.speichere_einstellungen()
		spiel.naechster_start = art
		Ladebild.lade(_welt.get_tree())   # 17.11.: Ladebild statt eingefrorenem Bild
		return
	if art == "normal":
		gewaehlt.emit(false)
	elif art == "sandbox":
		gewaehlt.emit(true)
	elif art == "tutorial":
		tutorial_gewaehlt.emit()
	elif art == "brakk":
		brakk_gewaehlt.emit()
	elif art.begins_with("angriff:"):
		phantom_gewaehlt.emit("verteidigung", art.trim_prefix("angriff:"))
	elif art.begins_with("verteidigt:"):
		phantom_gewaehlt.emit("angriff", art.trim_prefix("verteidigt:"))


## 18.11.: `spiel` steht erst jetzt fest – Liste neu aufbauen (für „Fortsetzen“) und einmal pro Programmstart melden,
## dass eine Partie ohne Ende lief (Diagnose für die Abstürze am Handy).
static var _unterbrochen_gemeldet := false

func _ready() -> void:
	if not _welt.get_window().files_dropped.is_connected(_dateien_fallen):
		_welt.get_window().files_dropped.connect(_dateien_fallen)   # 18.11.: Import eigener Karten
	if _seite != "haupt":
		return
	_baue()
	var runde: int = spiel.zwischenstand_runde() if spiel != null else 0
	if runde > 0 and not _unterbrochen_gemeldet:
		_unterbrochen_gemeldet = true
		print("Zwischenstand gefunden: Partie in Runde %d lief ohne Ende." % runde)
		_meldung = "Die Seite wurde neu geladen – deine Partie kannst du fortsetzen." if OS.has_feature("web") else "Deine letzte Partie ist nicht beendet – du kannst sie fortsetzen."


## 18.11.: Zwischenstand laden – main.gd setzt ihn beim Neuaufbau der Szene hin.
func _fortsetzen() -> void:
	var karte: String = str(spiel.lies_zwischenstand().get("karte", "paulland"))   # 18.11.: auf der Karte der Partie
	if karte != Werte.karte_name:
		Werte.karte_name = karte
		Werte.speichere_einstellungen()
	Werte.herausforderung = str(spiel.lies_zwischenstand().get("herausforderung", ""))   # 18.11.
	spiel.naechster_start = "fortsetzen"
	Ladebild.lade(_welt.get_tree())


func _tutorial_umschalten() -> void:
	_tutorial = not _tutorial
	_baue()


func _beenden() -> void:
	_welt.get_tree().quit()


func _phantom(art: String) -> void:
	if _laedt:
		return
	var wie := str(Profil.einstellung("phantom_wahl", "zufall"))
	# 18.11.: zuerst online (der aktuelle Pool aller Spieler), sonst die eingebauten Phantome
	if Online.bereit() and not (Online.listen[art] as Array).is_empty():
		_laedt = true
		_meldung = "Phantom wird geladen …"
		var e := Online.waehle(art, wie)
		var pfad := "" if e.is_empty() else await Online.hole(e)
		if pfad != "" and art == "verteidigung":
			var ersatz: Array = []
			var ohne: Array = [str(e["id"])]
			for i in 2:
				var x := Online.waehle("verteidigung", "zufall", ohne)
				if x.is_empty():
					break
				ohne.append(str(x["id"]))
				var p := await Online.hole(x)
				if p != "":
					ersatz.append(p)
			Online.ersatz_pfade = ersatz
			_starte(int(e.get("spalten", 28)) == 28, "angriff:" + pfad)
			return
		if pfad != "":
			_starte(true, "verteidigt:" + pfad)
			return
		_laedt = false
		_meldung = ""
	var funde := Phantom.liste(art, true)
	if funde.is_empty():
		_meldung = "Noch kein Phantom da: Gewinne eine Partie, dann wird dein Bau zum ersten Phantom." if art == "verteidigung" else "Noch kein Angriff da: Greife zuerst selbst einmal als Angreifer an."
		return
	if wie == "staerkste":
		funde.sort_custom(func(a, b): return int(a["wert"]) > int(b["wert"]))
		funde = funde.slice(0, 5)
	var f: Dictionary = funde.pick_random()
	if art == "verteidigung":
		_starte(int(f.get("spalten", 20)) == 28, "angriff:" + str(f["pfad"]))   # der Bau bringt seine Kartengröße mit
	else:
		_starte(true, "verteidigt:" + str(f["pfad"]))


## Phantom direkt starten (main.gd: „Nochmal angreifen“).
func zeige_phantome(art: String) -> void:
	_zeige("phantom")
	_phantom(art)


func _wahl_umschalten() -> void:
	Profil.setze_einstellung("phantom_wahl", "zufall" if str(Profil.einstellung("phantom_wahl", "zufall")) == "staerkste" else "staerkste")
	_baue()


# ------------------------------------------------------------------ Profil (18.11.)

func _tippt() -> bool:
	return _eingabe != null and _eingabe.has_focus()


func _name_text() -> String:
	if _tippt():
		return _eingabe.text + ("_" if fmod(_zeit, 1.0) < 0.55 else " ")
	return Profil.name() if Profil.hat_namen() else "(noch keiner)"


func _starte_eingabe() -> void:
	if _tippt():
		return
	_eingabe.text = Profil.name() if Profil.hat_namen() else ""
	_eingabe.grab_focus()
	_eingabe.caret_column = _eingabe.text.length()
	_wahl = 0
	_meldung = ""
	_baue()


func _bestaetige_namen() -> void:
	if Profil.setze_name(_eingabe.text):
		_eingabe.release_focus()
		if _erststart:
			_erststart = false
			_zeige("grafik" if _grafik_frage_offen() else "haupt")
		else:
			_baue()
	else:
		_meldung = "Bitte einen Namen mit Buchstaben oder Ziffern."


func _spaeter() -> void:
	Profil.setze_gefragt()
	_erststart = false
	_zeige("grafik" if _grafik_frage_offen() else "haupt")


## 18.11.: Handy/Tablet beim allerersten Start: Vogelperspektive vorschlagen. HD-2D braucht viel WebGL-Speicher –
## der wahrscheinlichste Grund für die Abstürze am Handy. Gefragt wird einmal (Werte.grafik_gefragt).
func _grafik_frage_offen() -> bool:
	Werte.lade_einstellungen()
	return (Touch.noetig() or OS.get_environment("TD_TOUCH") != "") and not Werte.grafik_gefragt


func _grafik_antwort(modus: String) -> void:
	Werte.setze_grafik(modus)
	Werte.grafik_gefragt = true
	Werte.speichere_einstellungen()
	_zeige("haupt")


func _frage_namen_beim_ersten_mal() -> void:
	if Profil.gefragt():
		if _grafik_frage_offen():
			_zeige("grafik")
		return
	_erststart = true
	_zeige("profil")
	_starte_eingabe()


## Profil-Schild oben rechts: Brakk-Zeichen und Name.
func _profil_rect() -> Rect2:
	var w := Stil.breite(Profil.name(), Stil.NORMAL) + 30.0
	return Rect2(640.0 - 12.0 - w, 10.0, w, PROFIL_H)


func _male_profil_schild(ci: Control) -> void:
	if _seite == "profil":
		return
	var r := _profil_rect()
	var an := r.has_point(_maus)
	Stil.platte(ci, r, 3.0, Color(LICHT, 0.14) if an else Stil.METALL_DUNKEL, LICHT if an else Stil.RAHMEN)
	Stil.symbol(ci, "brakk", Vector2(r.position.x + 11.0, r.get_center().y), 1.0, LICHT)
	Stil.schreibe(ci, Vector2(r.position.x + 21.0, r.get_center().y), Profil.name(), Stil.NORMAL, Color.WHITE if an else Stil.TEXT)


## 18.11.: Emblem „Terrain Conquester“ unten rechts – Platzhalter aus Stil-Mitteln (Kupferschrift auf Metallplatte),
## bis das Logo kommt. Leuchtet beim Überfahren, ein Klick öffnet die Seite.
func _tc_rect() -> Rect2:
	var w := Stil.breite("Terrain Conquester", Stil.NORMAL) + 22.0
	return Rect2(640.0 - 12.0 - w, 341.0, w, 14.0)   # unter den Tafeln (enden bei 336)


func _male_tc_emblem(ci: Control) -> void:
	if TC_ADRESSE == "":
		return
	var r := _tc_rect()
	var an := r.has_point(_maus)
	Stil.platte(ci, r, 3.0, Color(KUPFER_HELL, 0.16) if an else Stil.METALL_DUNKEL, KUPFER_HELL if an else Stil.RAHMEN)
	Stil.schreibe(ci, Vector2(r.position.x + 7.0, r.get_center().y), "Terrain Conquester", Stil.NORMAL, KUPFER_HELL if an else Stil.KUPFER)
	# kleiner Pfeil nach rechts oben: führt aus dem Spiel hinaus
	var p := Vector2(r.end.x - 9.0, r.get_center().y)
	var farbe := KUPFER_HELL if an else Stil.KUPFER
	ci.draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), farbe, 1.0)
	ci.draw_line(p + Vector2(0, -3), p + Vector2(3, -3), farbe, 1.0)
	ci.draw_line(p + Vector2(3, -3), p + Vector2(3, 0), farbe, 1.0)


func _oeffne_tc() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open(%s, '_blank')" % JSON.stringify(TC_ADRESSE))
	else:
		OS.shell_open(TC_ADRESSE)


## 18.11.: Profil-Statistik neu gegliedert – Dienstgrad, drei Kacheln (Partien, Siege, beste Runde mit Balken),
## darunter die Abschnitte Verteidigung (Leuchtblau) und Phantom-Modus (Kupfer).
const DIENSTGRADE := [[0, "Rekrut"], [1, "Gefreiter"], [3, "Feldwebel"], [5, "Leutnant"], [10, "Hauptmann"], [20, "Oberst"], [40, "General"]]

func _male_profil_tafel(ci: Control) -> void:
	Stil.platte(ci, TAFEL, 4.0, Color(0.05, 0.06, 0.09, 0.88), Stil.RAHMEN)
	var x := TAFEL.position.x + 12.0
	var rechts := TAFEL.end.x - 12.0
	var y := TAFEL.position.y + 14.0
	var siege := Profil.stat("siege")
	var grad := "Rekrut"
	for d: Array in DIENSTGRADE:
		if siege >= int(d[0]):
			grad = str(d[1])
	Stil.schreibe(ci, Vector2(x, y), "STATISTIK", Stil.NORMAL, LICHT)
	var gw := Stil.breite(grad.to_upper(), Stil.KLEIN)
	Stil.platte(ci, Rect2(rechts - gw - 8.0, y - 6.0, gw + 8.0, 12.0), 2.0, Color(Stil.GOLD, 0.12), Stil.GOLD)
	Stil.schreibe(ci, Vector2(rechts - gw - 4.0, y), grad.to_upper(), Stil.KLEIN, Stil.GOLD)
	y += 14.0
	# Kacheln
	var partien := Profil.stat("partien")
	var beste := Profil.stat("beste_runde")
	var kacheln := [
		["PARTIEN", str(partien), Stil.TEXT],
		["SIEGE", "%d" % siege, Stil.GOLD],
		["BESTE RUNDE", ("%d" % beste) if beste > 0 else "–", LICHT]]
	var kb := (TAFEL.size.x - 24.0 - 8.0) / 3.0
	for i in kacheln.size():
		var kr := Rect2(roundf(x + i * (kb + 4.0)), y, roundf(kb), 34.0)
		Stil.platte(ci, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		ci.draw_rect(Rect2(kr.position.x + 3.0, kr.position.y + 2.0, kr.size.x - 6.0, 1.0), Color(kacheln[i][2], 0.6))
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 13.0), kacheln[i][1], Stil.GROSS, kacheln[i][2])
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 26.0), kacheln[i][0], Stil.KLEIN, Stil.TEXT_BLASS)
	y += 40.0
	# Siegquote und Fortschritt zur Runde 20 als schmale Balken
	var quote := float(siege) / float(partien) if partien > 0 else 0.0
	_balken(ci, Vector2(x, y), rechts - x, quote, Stil.GOLD, "Siegquote", "%d %%" % roundi(quote * 100.0))
	y += 13.0
	_balken(ci, Vector2(x, y), rechts - x, beste / float(Werte.STANDARD_RUNDEN), LICHT, "Weg bis Runde %d" % Werte.STANDARD_RUNDEN, "%d/%d" % [beste, Werte.STANDARD_RUNDEN])
	y += 18.0
	# Abschnitt Verteidigung
	var e := Profil.liebling("einheit:")
	var t := Profil.liebling("turm:")
	y = _abschnitt(ci, x, rechts, y, "VERTEIDIGUNG", LICHT, [
		["Gegner besiegt", str(Profil.stat("kills"))],
		["Lieblingseinheit", "%s · %d" % [str(Werte.EINHEITEN.get(e[0], {}).get("name", e[0])), e[1]] if not e.is_empty() else "–"],
		["Lieblingsturm", "%s · %d" % [str(Werte.TURMARTEN.get(t[0], {}).get("name", t[0])), t[1]] if not t.is_empty() else "–"],
		["Brakk", "%d Gegner" % Profil.kills("brakk")]])
	y += 4.0
	# Abschnitt Phantom-Modus
	var ba := Profil.stat("beste_angriffswertung")
	var bv := Profil.stat("beste_verteidigung")
	_abschnitt(ci, x, rechts, y, "PHANTOM-MODUS", KUPFER_HELL, [
		["Angriffe", "%d · %d geknackt" % [Profil.stat("angriffe"), Profil.stat("geknackt")]],
		["Beste Angriffswertung", str(ba) if ba > 0 else "–"],
		["Beste Verteidigung", str(bv) if bv > 0 else "–"],
		["Eigene Phantome", str(Profil.stat("phantome"))]])
	Stil.schreibe(ci, Vector2(x, TAFEL.end.y - 10.0), "gespeichert in diesem Browser", Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.6))
	_male_erfolge(ci)


func _balken(ci: Control, p: Vector2, breite: float, anteil: float, farbe: Color, name: String, wert: String) -> void:
	Stil.schreibe(ci, Vector2(p.x, p.y), name, Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.schreibe(ci, Vector2(p.x + breite - Stil.breite(wert, Stil.KLEIN), p.y), wert, Stil.KLEIN, farbe)
	var bx := p.x + 82.0
	var bw := breite - 82.0 - 34.0
	ci.draw_rect(Rect2(bx, p.y - 2.0, bw, 4.0), Stil.METALL_TIEF)
	ci.draw_rect(Rect2(bx, p.y - 2.0, roundf(bw * clampf(anteil, 0.0, 1.0)), 4.0), Color(farbe, 0.8))


## Abschnitt mit farbiger Überschrift und Zeilen [Bezeichnung, Wert]; gibt das y danach zurück.
func _abschnitt(ci: Control, x: float, rechts: float, y: float, titel: String, farbe: Color, zeilen: Array) -> float:
	Stil.schreibe(ci, Vector2(x, y), titel, Stil.KLEIN, farbe)
	ci.draw_rect(Rect2(x + Stil.breite(titel, Stil.KLEIN) + 5.0, y, rechts - x - Stil.breite(titel, Stil.KLEIN) - 5.0, 1.0), Color(farbe, 0.35))
	y += 12.0
	for z: Array in zeilen:
		Stil.schreibe(ci, Vector2(x + 4.0, y), str(z[0]), Stil.KLEIN, Stil.TEXT_BLASS)
		var w := str(z[1])
		Stil.schreibe(ci, Vector2(rechts - Stil.breite(w, Stil.NORMAL), y), w, Stil.NORMAL, Stil.TEXT)
		y += 13.0
	return y


## 18.11.: Zweite Tafel im Profil – Erfolge als Raster aus Symbolen. Nicht freigeschaltet grau, versteckte als „???“.
## Maus über einem Symbol: Name und Bedingung unten in der Tafel.
const ERFOLGE_TAFEL := Rect2(LISTE_X - 6.0, 200, 300, 136)
const ERFOLGE_SPALTEN := 7

func _erfolg_feld(i: int) -> Rect2:
	var p := ERFOLGE_TAFEL.position + Vector2(12.0 + (i % ERFOLGE_SPALTEN) * 40.0, 26.0 + (i / ERFOLGE_SPALTEN) * 28.0)
	return Rect2(p, Vector2(36, 24))


func _male_erfolge(ci: Control) -> void:
	var r := ERFOLGE_TAFEL
	Stil.platte(ci, r, 4.0, Color(0.05, 0.06, 0.09, 0.88), Stil.RAHMEN)
	Stil.schreibe(ci, Vector2(r.position.x + 12.0, r.position.y + 13.0), "ERFOLGE %d/%d" % [Erfolge.freigeschaltet(), Erfolge.anzahl()], Stil.NORMAL, LICHT)
	var info := "Zeig auf ein Symbol."
	for i in Erfolge.LISTE.size():
		var e: Dictionary = Erfolge.LISTE[i]
		var an := Profil.hat_erfolg(str(e["id"]))
		var f := _erfolg_feld(i)
		var drueber := f.has_point(_maus)
		Stil.platte(ci, f, 2.0, Color(Stil.GOLD, 0.12) if an else Stil.METALL_TIEF, Stil.GOLD if an else (LICHT if drueber else Stil.RAHMEN))
		if an or not bool(e["versteckt"]):
			Stil.symbol(ci, str(e["symbol"]), f.get_center(), 2.0, Stil.GOLD if an else Color(Stil.TEXT_BLASS, 0.45))
		else:
			Stil.schreibe_mittig(ci, f.get_center(), "???", Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.6))
		if drueber:
			if an or not bool(e["versteckt"]):
				info = "%s – %s" % [e["name"], e["text"]]
				if str(e.get("belohnung", "")) != "":
					info += " · Belohnung: %s" % e["belohnung"]
			else:
				info = "??? – ein versteckter Erfolg."
	Stil.absatz(ci, Vector2(r.position.x + 12.0, r.end.y - 22.0), info, r.size.x - 24.0, Stil.KLEIN, Stil.TEXT_BLASS)


## Rangliste im Phantom-Menü: beste Angriffe und stärkste Verteidigungen (Elo). Ohne Verbindung der eingebaute Pool.
func _male_rangliste(ci: Control) -> void:
	Stil.platte(ci, TAFEL, 4.0, Color(0.05, 0.06, 0.09, 0.88), Stil.RAHMEN)
	var x := TAFEL.position.x + 12.0
	var rechts := TAFEL.end.x - 12.0
	var y := TAFEL.position.y + 14.0
	Stil.schreibe(ci, Vector2(x, y), "RANGLISTE", Stil.NORMAL, LICHT)
	var stand: String = {"laedt": "lädt …", "online": "online", "offline": "offline · eingebaut", "unbekannt": "…"}.get(Online.zustand, "")
	if Online.zustand == "online" and not Online.bereit():
		stand = "online · noch leer"
	Stil.schreibe(ci, Vector2(rechts - Stil.breite(stand, Stil.KLEIN), y), stand, Stil.KLEIN, Stil.TEXT_BLASS if Online.zustand != "online" else Color("8fe39a"))
	y += 22.0
	var mein := Profil.id()
	for art: String in ["angriff", "verteidigung"]:
		Stil.schreibe(ci, Vector2(x, y), "Beste Angriffe" if art == "angriff" else "Stärkste Verteidigungen", Stil.NORMAL, KUPFER_HELL if art == "angriff" else LICHT)
		Stil.schreibe(ci, Vector2(rechts - Stil.breite("Elo", Stil.KLEIN), y), "Elo", Stil.KLEIN, Stil.TEXT_BLASS)
		y += 16.0
		var zeilen := _ranglisten_zeilen(art)
		if zeilen.is_empty():
			Stil.schreibe(ci, Vector2(x + 4.0, y), "noch niemand", Stil.KLEIN, Stil.TEXT_BLASS)
			y += 14.0
		for i in zeilen.size():
			var z: Array = zeilen[i]
			var farbe: Color = Color.WHITE if str(z[3]) == mein else Stil.TEXT
			Stil.schreibe(ci, Vector2(x, y), "%d" % (i + 1), Stil.NORMAL, Stil.GOLD if i == 0 else Stil.TEXT_BLASS)
			Stil.schreibe(ci, Vector2(x + 14.0, y), str(z[0]), Stil.NORMAL, farbe)
			Stil.schreibe(ci, Vector2(x + 14.0 + 78.0, y), str(z[1]), Stil.KLEIN, Stil.TEXT_BLASS)
			var elo := str(z[2])
			Stil.schreibe(ci, Vector2(rechts - Stil.breite(elo, Stil.NORMAL), y), elo, Stil.NORMAL, farbe)
			y += 14.0
		y += 12.0


## [Name, Zusatz, Elo-Text, Profil-ID] für die besten sechs einer Art.
func _ranglisten_zeilen(art: String) -> Array:
	var aus: Array = []
	if Online.bereit():
		for e: Dictionary in (Online.listen[art] as Array).slice(0, 6):
			var zusatz := ""
			if art == "angriff":
				zusatz = "%d Pkt" % int(e.get("wertung", 0))
			else:
				var sp := int(e.get("spiele", 0))
				zusatz = "%d/%d gehalten" % [int(e.get("siege", 0)), sp] if sp > 0 else "noch unberührt"
			aus.append([str(e.get("spieler", "?")).left(12), zusatz, "%d" % roundi(float(e.get("elo", 1000))), str(e.get("profil", ""))])
		return aus
	var funde := Phantom.liste(art, true)
	funde.sort_custom(func(a, b): return int(a["wert"]) > int(b["wert"]))
	for f: Dictionary in funde.slice(0, 6):
		aus.append([str(f.get("spieler", "?")).left(12), "%d Pkt" % int(f["wert"]) if art == "angriff" else "eingebaut", "–", ""])
	return aus


func _naechste_grafik() -> void:
	var folge := {"klassisch": "neu", "neu": "hd", "hd": "klassisch"}
	Werte.setze_grafik(str(folge.get(Werte.grafik, "hd")))
	Werte.speichere_einstellungen()
	_baue()


func _vollbild() -> void:
	Werte.setze_vollbild(not Werte.vollbild)
	Werte.speichere_einstellungen()
	_baue()


static func _prozent_text(p: int) -> String:
	return "aus" if p <= 0 else "%d %%" % p


## Lautstärke in 10er-Schritten; über 100 % geht es wieder bei 0 los (nur mit Klick, mit ← → bleibt es am Rand).
func _naechste_musik(d: int, umlauf: bool = true) -> void:
	Werte.musik = _schritt_prozent(Werte.musik, d, umlauf)
	Werte.speichere_einstellungen()
	Musik.lautstaerke(_welt.get_tree())
	_baue()


static func _schritt_prozent(p: int, d: int, umlauf: bool) -> int:
	var n := p + d
	if umlauf and n > 100:
		return 0
	if umlauf and n < 0:
		return 100
	return clampi(n, 0, 100)


func _naechste_toene(d: int, umlauf: bool = true) -> void:
	Werte.toene = _schritt_prozent(Werte.toene, d, umlauf)
	Werte.speichere_einstellungen()
	_baue()


func _naechste_mauer() -> void:
	var folge := {"tech": "energie", "energie": "block", "block": "tech"}
	Werte.wand_stil = str(folge.get(Werte.wand_stil, "tech"))
	Werte.speichere_einstellungen()
	_baue()


# ------------------------------------------------------------------ Eingabe

func _process(delta: float) -> void:
	_zeit += delta
	_titel_zeit += delta
	_maus = _welt.get_local_mouse_position()
	if Online.geaendert != _online_stand:
		_online_stand = Online.geaendert
		if not _laedt:
			_baue()
	if _tippt() and _seite == "profil":
		_eintraege[0][0] = "Name: " + _name_text()
	# Übersicht offen: das Menü wartet unsichtbar
	_welt.visible = not (spiel != null and spiel.get("_lexikon") != null and spiel._lexikon.visible)
	_welt.queue_redraw()


func _zeile(i: int) -> Rect2:
	return Rect2(LISTE_X, LISTE_Y + i * ZEILE_H, BREITE, ZEILE_H - 4.0)


func _input(event: InputEvent) -> void:
	if not _welt.visible or not (event is InputEventKey and event.pressed):
		return
	if _titel:
		if not event.echo:
			_klick()
			_titel_weiter()
			if not _titel:
				_frage_namen_beim_ersten_mal()
		get_viewport().set_input_as_handled()
		return
	var k: int = (event as InputEventKey).keycode
	if _tippt():
		if k in [KEY_ENTER, KEY_KP_ENTER]:
			_bestaetige_namen()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			_eingabe.release_focus()
			if _erststart:
				_spaeter()
			else:
				_baue()
			get_viewport().set_input_as_handled()
		return   # alles andere geht ins Eingabefeld
	if _laedt:
		get_viewport().set_input_as_handled()
		return
	match k:
		KEY_UP, KEY_W:
			_wahl = posmod(_wahl - 1, _eintraege.size())
		KEY_DOWN, KEY_S:
			_wahl = posmod(_wahl + 1, _eintraege.size())
		KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D:
			var e: Array = _eintraege[_wahl]
			if e.size() > 4 and (e[4] as Callable).is_valid():
				(e[4] as Callable).call(-10 if k in [KEY_LEFT, KEY_A] else 10, false)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not event.echo:
				_klick()
				(_eintraege[_wahl][1] as Callable).call()
		KEY_ESCAPE, KEY_BACKSPACE:
			if _seite != "haupt" and not event.echo:
				_zeige("haupt")
		_:
			return
	get_viewport().set_input_as_handled()


## Klickgeräusch im Startmenü (17.11., Paul: mehr Rückmeldung beim Klicken).
func _klick() -> void:
	Ton.spiele(self, "ui-klick", 0.0)


func _maus_eingabe(event: InputEvent) -> void:
	if _titel:
		if event is InputEventMouseButton and event.pressed:
			_klick()
			_titel_weiter()
			if not _titel:
				_frage_namen_beim_ersten_mal()
		return
	if _laedt:
		return
	if event is InputEventMouseMotion:
		for i in _eintraege.size():
			if _zeile(i).has_point(_maus):
				_wahl = i
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_klick()
		if event.button_index == MOUSE_BUTTON_LEFT and _seite != "profil" and _profil_rect().has_point((event as InputEventMouseButton).position):
			_zeige("profil")
			return
		if event.button_index == MOUSE_BUTTON_LEFT and TC_ADRESSE != "" and _tc_rect().has_point((event as InputEventMouseButton).position):
			_oeffne_tc()
			return
		if _tippt() and event.button_index == MOUSE_BUTTON_LEFT and not _zeile(0).has_point((event as InputEventMouseButton).position):
			_bestaetige_namen()   # Klick daneben übernimmt den Namen
		if event.button_index == MOUSE_BUTTON_RIGHT and _seite != "haupt":
			for i in _eintraege.size():
				var e: Array = _eintraege[i]
				if _zeile(i).has_point((event as InputEventMouseButton).position) and e.size() > 4:
					(e[4] as Callable).call(-10, true)   # Rechtsklick auf eine Lautstärke: leiser
					return
			_zeige("haupt")
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in _eintraege.size():
				if _zeile(i).has_point((event as InputEventMouseButton).position):
					_wahl = i
					(_eintraege[i][1] as Callable).call()
					return


# ------------------------------------------------------------------ Zeichnen

func _male(ci: Control) -> void:
	if _titel:
		_male_titel(ci)
		return
	var hg := _bild("res://assets/neu/menue/kaserne.png")
	if hg != null:
		ci.draw_texture_rect(hg, Rect2(0, 0, 640, 360), false)
	else:
		ci.draw_rect(Rect2(0, 0, 640, 360), Color("10141c"))
	# links abdunkeln, damit die Liste gut lesbar ist
	for k in 40:
		ci.draw_rect(Rect2(k * 8.0, 0, 8, 360), Color(0.03, 0.04, 0.06, 0.8 * (1.0 - k / 40.0)))
	# (Truppen im Menü entfernt, Paul 16.11.)
	# Logo (klein, 1 Logopixel = 2 Bildschirmpixel bei 1080p)
	var logo := _bild("res://assets/neu/menue/logo.png")
	if logo != null:
		ci.draw_texture_rect(logo, Rect2(Vector2(LISTE_X - 6.0, 26), Vector2(logo.get_size()) * (2.0 / 3.0)), false)
	else:
		Stil.schreibe(ci, Vector2(LISTE_X, 76), "PAULS TD BATTLER", 22, Stil.TEXT)
	var unter: String = {"haupt": "", "spielen": "Spielen", "phantom": "Phantom-Modus", "einstellungen": "Einstellungen", "profil": "Dein Profil", "grafik": "Grafik für dein Gerät", "herausforderung": "Herausforderungen", "sandbox": "Sandbox"}[_seite]
	if unter != "":
		Stil.schreibe(ci, Vector2(LISTE_X, 110), unter, Stil.NORMAL, Stil.TEXT_BLASS)
	# Liste
	for i in _eintraege.size():
		var e: Array = _eintraege[i]
		var r := _zeile(i)
		var an := i == _wahl
		var farbe: Color = e[3]
		if an:
			Stil.platte(ci, r, 3.0, Color(LICHT, 0.12), LICHT)
			var m := Vector2(r.position.x - 6.0 - 1.5 * absf(sin(_zeit * 4.0)), r.get_center().y)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-5, -4), m + Vector2(0, 0), m + Vector2(-5, 4)]), LICHT)
			if farbe == Stil.TEXT_BLASS or farbe == Stil.TEXT:
				farbe = Color.WHITE
		var mit_unter := str(e[2]) != ""
		Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + (6.0 if mit_unter else 10.0)), e[0], Stil.NORMAL, farbe)
		if mit_unter:
			Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + 15.0), e[2], Stil.KLEIN, Stil.TEXT_BLASS)
	if _meldung != "":
		Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y + _eintraege.size() * ZEILE_H + 4.0), _meldung, BREITE, Stil.KLEIN, LICHT if _laedt else Stil.WARN)
	if _seite == "phantom":
		_male_rangliste(ci)
	elif _seite == "herausforderung":
		_male_kartenbild(ci, _wahl_karte)
	elif _seite == "grafik":
		Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y - 2.0 + _eintraege.size() * ZEILE_H + 6.0), "Du spielst auf einem Touchgerät. Ändern kannst du das jederzeit unter Einstellungen → Grafik.", BREITE, Stil.KLEIN, Stil.TEXT_BLASS)
	elif _seite == "profil":
		if _erststart:
			Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y - 2.0 + _eintraege.size() * ZEILE_H + 6.0), "Wie sollen dich andere Spieler sehen? Der Name steht an deinen Phantomen und in der Rangliste.", BREITE, Stil.KLEIN, Stil.TEXT_BLASS)
		else:
			_male_profil_tafel(ci)
	_male_profil_schild(ci)
	_male_tc_emblem(ci)


## 18.11.: Vorschaubild der gewählten Karte rechts neben der Liste (Gelände, Mauern, Basis, Checkpoints) und ihre Eckdaten.
const KARTENBILD := Rect2(372, 128, 252, 170)
const BILD_FARBEN := {"fels": Color("7a7064"), "wasser": Color("2b5d8a"), "anhoehe": Color("b9ad6a"), "sumpf": Color("3d4a2c"),
	"bruecke": Color("8a6239"), "ruine": Color("8d8a96"), "wald": Color("244a26"), "erz": Color("c98a3d"), "eis": Color("cfe9f5"), "minen": Color("6b3b3b")}

var _kartenbild_daten := {}   # Kartenname -> Daten (nicht jedes Bild die Datei lesen)

func _male_kartenbild(ci: Control, kname: String) -> void:
	if not _kartenbild_daten.has(kname):
		_kartenbild_daten[kname] = Werte.karten_daten(kname)
	var k: Dictionary = _kartenbild_daten[kname]
	if k.is_empty():
		return
	var sp := int(k["spalten"])
	var ze := int(k["zeilen"])
	var c := floorf(minf((KARTENBILD.size.x - 8.0) / sp, (KARTENBILD.size.y - 26.0) / ze))
	var feld_r := Rect2(KARTENBILD.position + Vector2((KARTENBILD.size.x - c * sp) / 2.0, 4.0), Vector2(c * sp, c * ze))
	Stil.platte(ci, Rect2(KARTENBILD.position, Vector2(KARTENBILD.size.x, feld_r.size.y + 26.0)), 3.0, Stil.METALL_DUNKEL, Stil.RAHMEN)
	ci.draw_rect(feld_r, Color("4f7d45"))
	ci.draw_rect(Rect2(feld_r.position, Vector2(c * Werte.ZONE_SPALTEN, feld_r.size.y)), Color("6b4a2f"))
	var zelle := func(p: Variant) -> Rect2:
		return Rect2(feld_r.position + Vector2(float(p[0]), float(p[1])) * c, Vector2(c, c))
	for art: String in BILD_FARBEN:
		for p: Variant in k.get(art, []):
			ci.draw_rect(zelle.call(p), BILD_FARBEN[art])
	for p: Variant in k.get("mauern", []):
		ci.draw_rect((zelle.call(p) as Rect2).grow(-c * 0.12), Color("c49b63"))
	if _wahl_herausforderung == "mauern_fest":
		for p: Variant in k.get("mauern_fest", []):
			ci.draw_rect((zelle.call(p) as Rect2).grow(-c * 0.12), Color("b07cff"))
	# Checkpoints: Bereiche als Rahmen (gewürfelt) oder feste Felder
	var cp_farben := [Color("ffd34d"), Color("7fe0ff")]
	for i in 2:
		if bool(k.get("checkpoints_fest", false)):
			var r: Rect2 = zelle.call(k["checkpoints"][i])
			ci.draw_circle(r.get_center(), maxf(c * 0.45, 1.5), cp_farben[i])
		else:
			var b: Array = k["checkpoint_bereiche"][i]
			ci.draw_rect(Rect2(feld_r.position + Vector2(float(b[0]), float(b[1])) * c, Vector2(float(b[2]), float(b[3])) * c).grow(-float(i)), cp_farben[i], false, 1.0)
	# Basis (3×2) – zufällige Basis nur angedeutet
	var bz: Array = k["basis"]
	var basis_r := Rect2(feld_r.position + Vector2(float(bz[0]) - 1.0, float(bz[1]) - 1.0) * c, Vector2(3, 2) * c)
	if bool(k.get("basis_fest", false)):
		ci.draw_rect(basis_r, Color("6a5391"))
	else:
		ci.draw_rect(basis_r, Color("6a5391"), false, 1.0)
	# Eckdaten
	var r_: Variant = k.get("regeln", {})
	var regeln: Dictionary = r_ if r_ is Dictionary else {}
	var text := "%d×%d · %d Runden · Budget %d · %d Leben" % [sp, ze, int(regeln.get("runden", Werte.STANDARD_RUNDEN)),
		int(regeln.get("start_budget", Werte.STANDARD_BUDGET)), int(regeln.get("start_leben", Werte.STANDARD_LEBEN))]
	Stil.schreibe(ci, Vector2(KARTENBILD.position.x + 6.0, feld_r.end.y + 7.0), text, Stil.KLEIN, Stil.TEXT)
	var basis_text := "Basis fest" if bool(k.get("basis_fest", false)) else "Basis zufällig"
	var cp_text := "Checkpoints fest" if bool(k.get("checkpoints_fest", false)) else "Checkpoints gewürfelt"
	Stil.schreibe(ci, Vector2(KARTENBILD.position.x + 6.0, feld_r.end.y + 17.0), basis_text + " · " + cp_text, Stil.KLEIN, Stil.TEXT_BLASS)


## Die drei Technoclan-Truppen posieren rechts auf der Bühne (Standbilder, leicht atmend).
func _male_truppen(ci: Control) -> void:
	var truppen := [["res://assets/sprites/scharfschuetze.png", Vector2(430, 296)], ["res://assets/sprites/technogunner.png", Vector2(486, 304)], ["res://assets/sprites/plasmawerfer.png", Vector2(542, 296)]]
	for k in truppen.size():
		var tex := _bild(truppen[k][0])
		if tex == null:
			continue
		var fuss: Vector2 = truppen[k][1]
		var schatten := PackedVector2Array()
		for i in 16:
			var w := TAU * i / 16.0
			schatten.append(fuss + Vector2(cos(w) * 22.0, sin(w) * 5.0))
		ci.draw_colored_polygon(schatten, Color(0, 0, 0, 0.4))
		var g := Vector2(96, 96)   # 48er-Bild doppelt
		var bild := int(_zeit * 4.0 + k) % 4
		var ziel := Rect2((fuss - Vector2(g.x / 2.0, g.y * 0.92)).round(), g)
		if k == 2:
			ziel = Rect2(ziel.position, Vector2(-g.x, g.y))   # der rechte schaut zur Mitte
		ci.draw_texture_rect_region(tex, ziel, Rect2(bild * 48, 0, 48, 48))


# ------------------------------------------------------------------ Titelbild

const TITEL_EINLAUF := 2.2      # so lange läuft der Auftritt; ein Druck vorher spult ihn nur vor

func _titel_weiter() -> void:
	if _titel_zeit < TITEL_EINLAUF:
		_titel_zeit = TITEL_EINLAUF
		return
	_titel = false


## Weich ab 0, mit kleinem Überschwingen am Ende (für Logo und Truppen).
static func _feder(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


func _male_titel(ci: Control) -> void:
	var t := _titel_zeit
	_male_lageplan(ci, t)
	# Logo fällt von oben und setzt mit einem Ruck auf
	var lf := _feder((t - 0.2) / 0.6)
	var wackel := Vector2.ZERO
	if t > 0.8 and t < 1.05:
		wackel = Vector2(0, 2.0 * sin(t * 80.0))
	var schweben := Vector2(0, 2.0 * sin(t * 1.4)) if t > TITEL_EINLAUF else Vector2.ZERO
	var logo := _bild("res://assets/neu/menue/logo.png")
	var mitte := Vector2(320, 150) + Vector2(0, (1.0 - lf) * -260.0) + wackel + schweben
	if logo != null:
		var lg := Vector2(logo.get_size()) * LOGO_SKALA * 1.5
		ci.draw_texture_rect(logo, Rect2((mitte - lg / 2.0).round(), lg), false)
	else:
		Stil.schreibe_mittig(ci, mitte, "PAULS TD BATTLER", 30, Stil.TEXT)
	if t > TITEL_EINLAUF and fmod(t, 1.0) < 0.65:
		Stil.schreibe_mittig(ci, Vector2(320, 300), "DRÜCKE EINE TASTE", Stil.GROSS, Color.WHITE)


## Abstrakter Lageplan: Nachtblau, feines Gitter, treibende Höhenlinien, Mauerzüge und Checkpoints in Cyan,
## eine kupferne Gegnerroute. Ganz aus dem Code.
func _male_lageplan(ci: Control, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color("070b16"))
	var gitter := Color(LICHT, 0.05)
	var ver := fmod(t * 4.0, 20.0)
	for x in range(-20, 660, 20):
		ci.draw_rect(Rect2(x + ver, 0, 1, 360), gitter)
	for y in range(-20, 380, 20):
		ci.draw_rect(Rect2(0, y + ver * 0.5, 640, 1), gitter)
	# Höhenlinien um drei treibende Hügel
	var huegel := [Vector2(150, 110), Vector2(500, 250), Vector2(420, 70)]
	for h in huegel.size():
		var m: Vector2 = huegel[h] + Vector2(sin(t * 0.15 + h) * 20.0, cos(t * 0.12 + h * 2.0) * 12.0)
		for ring in range(1, 7):
			var pts := PackedVector2Array()
			for i in 49:
				var w := TAU * i / 48.0
				var r := ring * 17.0 * (1.0 + 0.18 * sin(w * 3.0 + h + ring * 0.4) + 0.08 * sin(w * 5.0 - t * 0.3))
				pts.append(m + Vector2(cos(w) * r * 1.5, sin(w) * r))
			ci.draw_polyline(pts, Color(LICHT, 0.10 - ring * 0.01), 1.0)
	# kupferne Route mit wanderndem Strich
	var route := PackedVector2Array([Vector2(-10, 200), Vector2(90, 200), Vector2(90, 280), Vector2(260, 280), Vector2(260, 190), Vector2(400, 190), Vector2(400, 300), Vector2(560, 300), Vector2(560, 160), Vector2(650, 160)])
	ci.draw_polyline(route, Color(KUPFER_HELL, 0.10), 3.0)
	var laenge := 0.0
	for i in route.size() - 1:
		laenge += route[i].distance_to(route[i + 1])
	var pos := 0.0
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var d := a.distance_to(b)
		var s := 0.0
		while s < d:
			var phase := fmod(pos + s - t * 30.0, 14.0)
			if phase < 0.0:
				phase += 14.0
			if phase < 6.0:
				ci.draw_rect(Rect2((a + (b - a) * (s / d)).round() - Vector2.ONE, Vector2(2, 2)), Color(KUPFER_HELL, 0.35))
			s += 2.0
		pos += d
	# Mauerzüge
	for m: Rect2 in [Rect2(40, 150, 120, 6), Rect2(180, 230, 6, 90), Rect2(320, 140, 6, 110), Rect2(460, 250, 70, 6), Rect2(480, 110, 6, 90)]:
		ci.draw_rect(m, Color(LICHT, 0.10))
		ci.draw_rect(m, Color(LICHT, 0.35), false, 1.0)
	# Checkpoints pulsieren
	for k in 3:
		var c: Vector2 = [Vector2(260, 280), Vector2(400, 190), Vector2(560, 300)][k]
		var puls := fmod(t * 0.6 + k * 0.33, 1.0)
		ci.draw_arc(c, 4.0 + puls * 14.0, 0, TAU, 24, Color(LICHT, 0.4 * (1.0 - puls)), 1.0)
		ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(LICHT, 0.7))
	# Vignette
	for k in 12:
		var a2 := 0.06
		ci.draw_rect(Rect2(0, k * 3.0, 640, 3), Color(0, 0, 0, a2 * (12 - k)))
		ci.draw_rect(Rect2(0, 357.0 - k * 3.0, 640, 3), Color(0, 0, 0, a2 * (12 - k)))
