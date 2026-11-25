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
var _meldung_gold := false          # 23.11.: Hinweis statt Warnung (Phantom-Bericht)
var _karte_profil := ""                # 24.11.: offene Spielerkarte (Profil-ID), "" = zu
var _rang_treffer: Array = []        # [Rechteck, Profil-ID] der Ranglistenzeilen (Klick öffnet die Spielerkarte)
var _bilanz_rect := Rect2()          # eigene Bilanz im Phantom-Menü (klickbar)
var _funk: Funkfenster              # 23.11.: Sonde 7 im Phantom-Menü (Einführung)
var _eintraege: Array = []         # [Text, Aktion, Untertitel, Farbe]
# Titelbild (NES/Mega-Drive-Art): nur beim ersten Öffnen nach Programmstart, eine Taste/ein Klick führt zur Liste
static var _titel_gesehen := false
var _grund: ColorRect
var _titel := false
var _titel_zeit := 0.0
var _sterne: Array = []
# Profil und Rangliste (18.11.)
const PROFIL_H := 18.0
const TAFEL := Rect2(372, 60, 252, 276)
var _eingabe: LineEdit              # unsichtbares Eingabefeld für den Spitznamen (gezeichnet wird selbst)
var _code_modus := false            # 20.11.: das Eingabefeld nimmt gerade einen Entwicklercode auf (Einstellungen)
var _code := ""                     # 20.11.: getippter Code, solange das Feld nicht aktiv ist
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
	process_mode = Node.PROCESS_MODE_ALWAYS   # 20.11.: die Übersicht pausiert das Spiel – das Menü muss sich trotzdem ausblenden (sonst „friert“ es ein)
	# 19.11.: Hintergrund hinter der Menüfläche – mit sicheren Rändern (iPhone) ist sie etwas kleiner als das Bild
	_grund = ColorRect.new()
	_grund.color = Color("0b0e14")
	_grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_grund)
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
	Online.erneut()   # 25.11.: nicht angekommene Läufe noch einmal melden
	if Profil.phantom_frei():
		Online.lade_bericht(str(Profil.einstellung("phantom_bericht_seit", "")))   # 23.11.: Phantom-Bericht (was seit dem letzten Besuch geschah)
	if not _titel:
		_frage_namen_beim_ersten_mal()



func _bild(pfad: String) -> Texture2D:
	if not _bilder.has(pfad):
		_bilder[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _bilder[pfad]


# ------------------------------------------------------------------ Seiten

func _zeige(seite: String) -> void:
	_code_merken()   # 20.11.
	if _tippt():
		_eingabe.release_focus()
	if seite == "phantom":
		Online.lade_listen()   # Rangliste auffrischen
	_seite = seite
	_kartenbild_daten.clear()   # 18.11.: Karten können sich geändert haben (Import, Editor)
	_wahl = 0
	_meldung = ""
	_meldung_gold = false
	if seite != "phantom" and is_instance_valid(_funk):
		_funk.schliessen()
	_baue()
	if seite == "phantom":
		_phantom_einfuehrung()


func _baue() -> void:
	Werte.lade_einstellungen()
	_eintraege = []
	match _seite:
		"haupt":
			_eintraege = [
				# 18.11. (Paul): Reihenfolge nach Wichtigkeit
				["Spielen", _zeige.bind("spielen"), "", LICHT],
				["Phantom-Modus", _zeige.bind("phantom"), "Neuer Bericht: dein Phantom war im Einsatz" if Online.bericht_text() != "" else "", Stil.TEXT] if Profil.phantom_frei() else ["Phantom-Modus", _tafel_auf.bind("phantom"), SPERR_TAFEL["phantom"]["bedingung"], GESPERRT],   # 21.11. (Paul): erst nach einem Sieg
				["Brakk-Mode", _zeige.bind("brakk"), "", Stil.TEXT] if Profil.brakk_modus_frei() else ["Brakk-Mode", _tafel_auf.bind("brakk"), SPERR_TAFEL["brakk"]["bedingung"], GESPERRT],   # 20.11. (Schritt 5b): Unterseite Classic / Rogue; 21.11.: erst nach dem ersten Brakk
				["Sandbox", _zeige.bind("sandbox"), "", Stil.TEXT],
				["Herausforderungen", _zeige.bind("herausforderung"), "", Stil.TEXT],
				["Einstellungen", _zeige.bind("einstellungen"), "", Stil.TEXT],
				["Beenden", _beenden, "", Stil.TEXT_BLASS],
			]
			# 18.11.: unterbrochene Partie (Seite neu geladen, Spiel geschlossen) ganz oben anbieten
			var runde: int = spiel.zwischenstand_runde() if spiel != null else 0
			if runde > 0:
				_eintraege.push_front(["Fortsetzen · Runde %d" % runde, _fortsetzen, "deine unterbrochene Partie" + (" im Brakk-Mode" if bool(spiel.lies_zwischenstand().get("brakk_modus", false)) else ""), KUPFER_HELL])   # 19.11.: auch Brakk-Mode
				_eintraege[1][3] = Stil.TEXT
		"brakk":
			# 20.11. (Schritt 5b): Classic = der bisherige Brakk-Mode, Rogue = Order 24
			_eintraege = [
				["Classic", _brakk_mode, "20 Runden gegen die Myriaden in der Ego-Sicht – wie bisher", LICHT],
				["Rogue · Befehl 24", _zeige.bind("rogue"), "der Technoclan hat sich gegen Brakk gewandt: allein überleben", KUPFER_HELL] if Profil.rogue_frei() else ["Rogue · gesperrt", _rogue_gesperrt, "erst Classic gewinnen (Runde 20) – dann geht es weiter …", Stil.TEXT_BLASS],   # 20.11. (Paul)
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
			if Profil.rogue_frei():
				_eintraege.insert(2, ["Hangar", _hangar_oeffnen, "die Benannten des Technoclans, die dich jagen", Stil.TEXT])   # 25.11. (Paul): statt der Liste „Meistgesuchte“
		"rogue":
			# 20.11. (Schritt 5b): Order 24 mit Standardwerten oder eine eigene Rogue-Karte aus dem Editor
			_eintraege = [["Befehl 24 · Standardwerte", _rogue_los.bind("szenario_order24"), _karten_text("szenario_order24"), LICHT]]
			for kname: String in Werte.eigene_karten():
				var rg: Variant = Werte.karten_daten(kname).get("regeln", {})
				if rg is Dictionary and str((rg as Dictionary).get("modus", "")) == "rogue":
					_eintraege.append(["Eigene: " + _karten_titel(kname), _rogue_los.bind(kname), _karten_text(kname), Stil.TEXT])
			if _eintraege.size() == 1:
				_eintraege.append(["Eigene Karte laden", _zeige.bind("rogue"), "noch keine – im Editor (Sandbox → Szenario bauen → Szenarien) aus der Vorlage Order 24 speichern", Stil.TEXT_BLASS])
			_eintraege.append(["Zurück", _zeige.bind("brakk"), "", Stil.TEXT_BLASS])
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
			var vorgabe := _karten_anfuehrer(_wahl_karte)   # 19.11.: Szenario gibt den Anführer vor
			_eintraege = [
				["Los geht's", _herausforderung_los, ("wie „Spielen“ – zählt für Rangliste und Phantome" if haupt else "zählt nicht für Rangliste und Phantome") + (" · Anführer: " + Anfuehrer.name(vorgabe) if vorgabe != "" else ""), LICHT],
				["Karte: " + _karten_titel(_wahl_karte), _naechste_karte, _karten_text(_wahl_karte), Stil.TEXT],
				["Herausforderung: " + Werte.herausforderung_name(_wahl_herausforderung), _naechste_herausforderung, Werte.herausforderung_text(_wahl_herausforderung), Stil.TEXT],
				["Szenarien", _zeige.bind("szenarien"), "fünf besondere Lagen (Belagert, Zange, Alarmstart …)", Stil.TEXT],   # 20.11. (Paul): unter Herausforderungen, nicht unter Spielen
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"anfuehrer":
			# 19.11.: je Anführer ein Eintrag (gezeichnet als Kachel, siehe _male_anfuehrer), dazu „Zurück“
			for a: Dictionary in _af_liste():
				_eintraege.append([str(a["name"]), _anfuehrer_gewaehlt.bind(str(a["id"])), "", Stil.TEXT, _af_schieben])
			_eintraege.append(["Zurück", func() -> void: _zeige(_af_zurueck), "", Stil.TEXT_BLASS])
		"spielen":
			_eintraege = [
				["Los geht's", _los, "20 Runden gegen die Myriaden" + (" · mit Tutorial" if _tutorial else ""), LICHT],
				["Tutorial: " + ("an" if _tutorial else "aus"), _tutorial_umschalten, "Sonde 7 erklärt Schritt für Schritt", Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"szenarien":
			# 20.11. (Schritt 5): mitgelieferte Szenarien; rechts der Steckbrief der gewählten Karte
			for kname: String in Werte.SZENARIEN:
				_eintraege.append([_karten_titel(kname), _szenario_los.bind(kname), "", Stil.TEXT])   # Beschreibung steht rechts im Steckbrief
			_eintraege.append(["Zurück", _zeige.bind("herausforderung"), "", Stil.TEXT_BLASS])
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
				["So funktioniert's", _phantom_erklaeren, "Phantome, Elo und Rangliste in 20 Sekunden", Stil.TEXT_BLASS],   # 23.11.: „?“ der Einführung
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"profil":
			if _erststart:
				# 21.11. (Paul): beim ersten Start Pflicht – kein „Später“; bestätigen per Knopf, Klick oder Enter
				_eintraege = [
					["Name: " + _name_text(), _starte_eingabe, "bis 16 Zeichen · Buchstaben oder Ziffern", LICHT],
					["Bestätigen", _bestaetige_namen, "oder Enter drücken", KUPFER_HELL],
				]
			else:
				_eintraege = [
					["Name: " + _name_text(), _starte_eingabe, "Enter bestätigt · bis 16 Zeichen" if _tippt() else "zum Ändern klicken", LICHT],
				]
				if _tippt():
					_eintraege.append(["Übernehmen", _bestaetige_namen, "oder Enter drücken", KUPFER_HELL])   # 21.11.
				_eintraege += [
					["Brakk-Mode · " + Anfuehrer.name(_profil_af) if _profil_brakk else "Brakk-Mode", _profil_brakk_umschalten, _profil_brakk_text(), Stil.TEXT],   # 19.11.; 20.11.: je Anführer getrennt, ein Klick blättert weiter
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
			_eintraege.append(["Code: " + _code_text(), _starte_code, "Enter löst ein" if _tippt() else "zum Eingeben klicken", Stil.TEXT])   # 20.11.: Entwicklercodes
			_eintraege.append(["Einlösen", _loese_code, "", Stil.TEXT])
			if not Nemesis.meistgesuchte().is_empty():   # 22.11. (Paul, Nemesis Teil 6/8)
				_eintraege.append(["Meistgesuchte zurücksetzen", _meistgesuchte_weg, "Klick noch einmal: alle Benannten aus Befehl 24 löschen" if _weg_frage else "die Benannten aus Befehl 24 vergessen – nächster Lauf beginnt mit dem Appell", Stil.WARN if _weg_frage else Stil.TEXT])
			_eintraege.append(["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS])
	_wahl = clampi(_wahl, 0, _eintraege.size() - 1)
	if _seite == "brakk":   # 22.11. (Paul): Brakk-Tutorial jederzeit wiederholen (brakk_tutorial.gd)
		_eintraege.insert(1, ["Tutorial", func() -> void: BrakkTutorial.aus_menue(self), "Sonde 7 zeigt Parkour, Schießstand, Bauen und Ringe – ohne Risiko", Stil.TEXT])


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
	if _tutorial:
		Werte.setze_anfuehrer("brakk")   # 19.11.: das Tutorial läuft immer mit Brakk
		_starte(true, "tutorial")
		return
	_zeige_anfuehrer("spielen", _starte.bind(true, "normal"))   # 19.11.: erst den Anführer wählen


## 19.11.: Herausforderungen → Los: gibt das Szenario den Anführer vor, gleich los, sonst erst wählen.
func _herausforderung_los() -> void:
	var start := _starte.bind(true, "normal", _wahl_karte, _wahl_herausforderung)
	var vorgabe := _karten_anfuehrer(_wahl_karte)
	if vorgabe != "":
		Werte.setze_anfuehrer(vorgabe)
		start.call()
		return
	_zeige_anfuehrer("herausforderung", start)


## 20.11.: Szenario starten – mit seiner Herausforderung; Anführer wie bei den Herausforderungen (vorgegeben oder Wahl).
func _szenario_los(kname: String) -> void:
	var regeln: Variant = Werte.karten_daten(kname).get("regeln", {})
	var hf := str((regeln as Dictionary).get("herausforderung", "")) if regeln is Dictionary else ""
	var start := _starte.bind(true, "normal", kname, hf)
	var vorgabe := _karten_anfuehrer(kname)
	if vorgabe != "":
		Werte.setze_anfuehrer(vorgabe)
		start.call()
		return
	_zeige_anfuehrer("szenarien", start)


## Anführer, den eine Karte im Regelpaket vorgibt ("" = frei wählbar).
static func _karten_anfuehrer(kname: String) -> String:
	var regeln: Variant = Werte.karten_daten(kname).get("regeln", {})
	if regeln is Dictionary and str((regeln as Dictionary).get("modus", "normal")) == "brakk":
		return "brakk"   # 20.11.: Szenario im Brakk-Mode – Brakk ist der Anführer
	var id := str((regeln as Dictionary).get("anfuehrer", "")) if regeln is Dictionary else ""
	return Anfuehrer.gueltig(id) if id != "" else ""


# ------------------------------------------------------------------ Anführerwahl (19.11.)

## Spielen → Los (und Herausforderungen → Los): vier Kacheln mit Porträt, Perks und Nachteilen. Gesperrte zeigen ein
## Fragezeichen und den Erfolg, der sie freischaltet (beim versteckten nur den Tipp). Die Wahl merkt sich das Profil.
const AF_Y := 66.0
const AF_H := 238.0
const AF_ZURUECK := Rect2(20, 314, 110, 20)
var _af_zurueck := "spielen"     # Seite, auf die „Zurück“ führt
var _af_start: Callable          # startet die Partie, sobald ein Anführer gewählt ist
var _af_ego := false             # 20.11.: Auswahl vor dem Brakk-Mode (nur Anführer mit Ego-Kit)


## 20.11.: Anführer dieser Auswahl – vor dem Brakk-Mode nur die mit Ego-Kit (Werte.ANFUEHRER_EGO).
func _af_liste() -> Array:
	if not _af_ego:
		return Anfuehrer.LISTE
	var liste: Array = []
	for a: Dictionary in Anfuehrer.LISTE:
		if Werte.ego_hat(str(a["id"])):
			liste.append(a)
	return liste


## Wählbar? Freigeschaltet über den Erfolg; vor dem Brakk-Mode am Handy vorerst nur Brakk (20.11.).
func _af_frei(id: String) -> bool:
	return Anfuehrer.frei(id) and not _af_handy_gesperrt(id)


func _af_handy_gesperrt(id: String) -> bool:
	return _af_ego and id != "brakk" and Touch.ohne_maus()


func _zeige_anfuehrer(zurueck: String, start: Callable, ego: bool = false) -> void:
	_af_zurueck = zurueck
	_af_start = start
	_af_ego = ego
	_zeige("anfuehrer")
	var letzter := Anfuehrer.gueltig(str(Profil.einstellung("anfuehrer_ego" if ego else "anfuehrer", "brakk")))
	for i in _af_liste().size():
		if str(_af_liste()[i]["id"]) == letzter and _af_frei(letzter):
			_wahl = i


func _af_kachel(i: int) -> Rect2:
	var n := maxi(1, _af_liste().size())   # 20.11.: vor dem Brakk-Mode drei breitere Kacheln
	var w := (600.0 - float(n - 1) * 8.0) / float(n)
	return Rect2(roundf(20.0 + i * (w + 8.0)), AF_Y, roundf(w), AF_H)


func _anfuehrer_gewaehlt(id: String) -> void:
	if _af_handy_gesperrt(id):
		_meldung = "%s: Am Handy noch nicht spielbar." % Anfuehrer.name(id)   # 20.11.
		return
	if not _af_frei(id):
		_meldung = "%s ist noch gesperrt – %s." % [Anfuehrer.name(id), Anfuehrer.freischalt_text(id)]
		return
	Werte.setze_anfuehrer(id)
	Profil.setze_einstellung("anfuehrer_ego" if _af_ego else "anfuehrer", id)
	if _af_start.is_valid():
		_af_start.call()


## ← → wechseln die Kachel (die Liste kennt sonst nur ↑ ↓).
func _af_schieben(d: int, _umlauf: bool) -> void:
	var n := _af_liste().size()
	if _wahl < n:
		_wahl = posmod(_wahl + (1 if d > 0 else -1), n)


func _male_anfuehrer(ci: Control) -> void:
	if _af_ego:   # 20.11.: vor dem Brakk-Mode
		Stil.schreibe(ci, Vector2(20, 30), "ANFÜHRER FÜR DEN BRAKK-MODE", Stil.GROSS, LICHT)
		Stil.schreibe(ci, Vector2(20, 48), "Du spielst ihn selbst in der Ego-Sicht. Ringe sind für alle das Build-System.", Stil.KLEIN, Stil.TEXT_BLASS)
	else:
		Stil.schreibe(ci, Vector2(20, 30), "ANFÜHRER WÄHLEN", Stil.GROSS, LICHT)
		Stil.schreibe(ci, Vector2(20, 48), "Seine Perks gelten ab Runde 1. Seine Figur kaufst du wie Brakk mit [8].", Stil.KLEIN, Stil.TEXT_BLASS)
	for i in _af_liste().size():
		_male_af_kachel(ci, i, _af_liste()[i])
	var zr := AF_ZURUECK
	var an := _wahl == _af_liste().size()
	Stil.platte(ci, zr, 3.0, Color(LICHT, 0.12) if an else Color(0.05, 0.06, 0.09, 0.85), LICHT if an else Stil.RAHMEN)
	Stil.schreibe_mittig(ci, zr.get_center(), "Zurück", Stil.NORMAL, Color.WHITE if an else Stil.TEXT_BLASS)
	if _meldung != "":
		Stil.absatz(ci, Vector2(144, 318), _meldung, 476.0, Stil.KLEIN, Stil.WARN)


func _male_af_kachel(ci: Control, i: int, a: Dictionary) -> void:
	var r := _af_kachel(i)
	var id := str(a["id"])
	var frei := _af_frei(id)
	var an := i == _wahl
	var farbe: Color = a["farbe"]
	Stil.platte(ci, r, 4.0, Color(0.05, 0.06, 0.09, 0.92), (LICHT if frei else Stil.RAHMEN_HELL) if an else Stil.RAHMEN)
	if an:
		ci.draw_rect(Rect2(r.position.x + 10.0, r.position.y + 2.0, r.size.x - 20.0, 1.0), LICHT)   # Lichtkante oben
	var x := r.position.x + 8.0
	var weite := r.size.x - 16.0
	# Porträt (Platzhalter): Initiale auf einer Metallplatte mit Nieten
	var p := Rect2(roundf(r.get_center().x - 28.0), r.position.y + 10.0, 56.0, 56.0)
	Stil.platte(ci, p, 4.0, Stil.METALL, Stil.RAHMEN_HELL)
	ci.draw_rect(Rect2(p.position + Vector2(4, 4), p.size - Vector2(8, 8)), Color(farbe, 0.08 if frei else 0.03))
	for ecke: Vector2 in [Vector2(5, 5), Vector2(p.size.x - 7, 5), Vector2(5, p.size.y - 7), Vector2(p.size.x - 7, p.size.y - 7)]:
		ci.draw_rect(Rect2(p.position + ecke, Vector2(2, 2)), Stil.RAHMEN_HELL)
	# 20.11. (Paul): echtes Porträt, wo es eins gibt (Brakk) – 32er-Bild dreifach auf dem Schirm, die Initiale sonst
	var portraet: Texture2D = Anfuehrer.portraet(id)
	if portraet != null:
		var ps := Vector2(48, 48)
		ci.draw_rect(Rect2(p.position + Vector2(4, 4), p.size - Vector2(8, 8)), Color(farbe, 0.16))
		ci.draw_texture_rect(portraet, Rect2((p.get_center() - ps / 2.0).round(), ps), false, Color.WHITE if frei else Color(0.25, 0.27, 0.32))
		if an and frei:
			ci.draw_rect(Rect2(p.position + Vector2(2, 2), p.size - Vector2(4, 4)), farbe, false, 1.0)
		if not frei:
			Stil.schreibe_mittig(ci, p.get_center() + Vector2(0, 1), "?", 28, Stil.TEXT)   # 21.11.: gesperrt – Fragezeichen über dem abgedunkelten Porträt
	elif frei:
		Stil.schreibe_mittig(ci, p.get_center() + Vector2(0, 1), str(a["initiale"]), 28, farbe)
	else:
		Stil.schreibe_mittig(ci, p.get_center() + Vector2(0, 1), str(a["initiale"]), 28, Color(Stil.TEXT_BLASS, 0.25))
		ci.draw_rect(Rect2(p.position + Vector2(3, 3), p.size - Vector2(6, 6)), Color(0.02, 0.03, 0.05, 0.55))
		Stil.schreibe_mittig(ci, p.get_center() + Vector2(0, 1), "?", 28, Stil.TEXT)
	var y := p.end.y + 10.0
	Stil.schreibe_mittig(ci, Vector2(r.get_center().x, y), str(a["name"]).to_upper(), Stil.NORMAL, farbe if frei else Stil.TEXT_BLASS)
	y += 10.0
	if _af_handy_gesperrt(id):
		Stil.schreibe_mittig(ci, Vector2(r.get_center().x, y), "Am Handy noch nicht spielbar", Stil.KLEIN, Stil.WARN)   # 20.11.
		y += 10.0
	elif not frei:
		Stil.schreibe_mittig(ci, Vector2(r.get_center().x, y), Anfuehrer.freischalt_text(id), Stil.KLEIN, Stil.GOLD)
		y += 10.0
	if _af_ego:
		# 20.11.: vor dem Brakk-Mode – drei Zeilen Kit aus Werte.ANFUEHRER_EGO statt Perks und Nachteilen
		Stil.schreibe(ci, Vector2(x, y + 3.0), "KIT", Stil.KLEIN, LICHT)
		y += 9.0
		for t: String in Werte.ANFUEHRER_EGO[id]["kit"]:
			y = _af_absatz(ci, x, y, "+ " + t, weite, Stil.TEXT)
		return
	y = _af_absatz(ci, x, y, str(a["kurz"]), weite, Stil.TEXT_BLASS) + 4.0
	Stil.schreibe(ci, Vector2(x, y + 3.0), "PERKS", Stil.KLEIN, LICHT)
	y += 9.0
	for t: String in a["perks"]:
		y = _af_absatz(ci, x, y, "+ " + t, weite, Stil.TEXT)
	y += 4.0
	Stil.schreibe(ci, Vector2(x, y + 3.0), "NACHTEILE", Stil.KLEIN, Stil.WARN)
	y += 9.0
	for t: String in a["nachteile"]:
		y = _af_absatz(ci, x, y, "– " + t, weite, Stil.TEXT_BLASS)
	if not bool(a["rangliste"]):
		Stil.schreibe_mittig(ci, Vector2(r.get_center().x, r.end.y - 9.0), "nicht ranglistenfähig", Stil.KLEIN, KUPFER_HELL)


## Absatz in einer Kachel; gibt das y darunter zurück.
func _af_absatz(ci: Control, x: float, y: float, text: String, weite: float, farbe: Color) -> float:
	Stil.absatz(ci, Vector2(x, y), text, weite, Stil.KLEIN, farbe)
	return y + Stil.absatz_groesse(text, weite, Stil.KLEIN).y + 1.0


## 18.11.: Brakk-Mode – am PC mit Maus und Tastatur, am Handy mit Touch-Steuerung (ego_touch.gd).
func _brakk_mode() -> void:
	_zeige_anfuehrer("brakk", _starte.bind(true, "brakk"), true)   # 20.11.: erst den Anführer wählen (Brakk, Irrtürmer, Sonde 7)


## 20.11. (Paul): Rogue ist gesperrt, bis Classic einmal gewonnen wurde.
## 21.11. (Paul): gesperrte Modi im Hauptmenü – grau mit Schloss; ein Klick öffnet eine kleine Tafel mit Teaser
## (Bild, zwei Sätze, Bedingung) und „Verstanden“. Sie rüttelt beim Öffnen kurz wie an einem Schloss.
const GESPERRT := Color(0.42, 0.44, 0.5)
const SPERR_TAFEL := {
	"brakk": {"titel": "BRAKK-MODE", "bedingung": "Stelle Brakk einmal in einer Partie auf",
		"text": "Nimm selbst das Gewehr in die Hand – der Krieg aus Brakks Augen. In Classic hältst du 20 Runden in der Ego-Sicht, in Rogue kämpfst du allein ums Überleben."},
	"phantom": {"titel": "PHANTOM-MODUS", "bedingung": "Überstehe Runde 20",
		"text": "Deine Verteidigung bleibt als Phantom zurück. Greife die der anderen an."},
}
const TAFEL_RECHT := Rect2(150, 105, 340, 150)
const TAFEL_KNOPF := Rect2(260, 225, 120, 20)
## Silhouette einer Verteidigung für die Phantom-Tafel ('#' Erdwall, 'T' Turm, 'F' Fabrik).
const PHANTOM_BAU := [
	"..##....##",
	"..#T.##.#.",
	"..##..#.#.",
	"F.....#T#.",
	"..##..###.",
	"..#T......",
	"..##.F..##",
]
var _tafel := ""
var _tafel_ab := 0.0


func _tafel_auf(art: String) -> void:
	_tafel = art
	_tafel_ab = _zeit
	Ton.spiele(self, "hit-thud", -6.0)


func _tafel_zu() -> void:
	_tafel = ""
	_klick()


func _male_tafel(ci: Control) -> void:
	var d: Dictionary = SPERR_TAFEL[_tafel]
	var t := _zeit - _tafel_ab
	var wackeln := Vector2(roundf(sin(t * 70.0) * 4.0 * maxf(0.0, 1.0 - t / 0.35)), 0.0)   # Rütteln am Schloss
	ci.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.05, 0.7))
	var r := Rect2(TAFEL_RECHT.position + wackeln, TAFEL_RECHT.size)
	Stil.platte(ci, r, 6.0, Color(0.05, 0.06, 0.09, 0.96), Stil.RAHMEN)
	ci.draw_rect(Rect2(r.position.x + 12.0, r.position.y + 3.0, 60.0, 1.0), LICHT)
	# Bild links
	var bild := Rect2(r.position + Vector2(12, 14), Vector2(96, 96))
	ci.draw_rect(bild, Color(0.08, 0.1, 0.14))
	if _tafel == "brakk":
		var p: Texture2D = Anfuehrer.portraet("brakk")
		if p != null:
			ci.draw_texture_rect(p, bild, false)
	else:
		var px := 8.0
		var o := bild.position + (bild.size - Vector2(PHANTOM_BAU[0].length(), PHANTOM_BAU.size()) * px) / 2.0
		var geist := Color(0.62, 0.86, 1.0)
		for y in PHANTOM_BAU.size():
			for x in (PHANTOM_BAU[y] as String).length():
				var c: String = PHANTOM_BAU[y][x]
				if c == ".":
					continue
				var zr := Rect2(o + Vector2(x, y) * px, Vector2(px - 1.0, px - 1.0))
				ci.draw_rect(zr, Color(geist, 0.22 if c == "#" else 0.45))
				ci.draw_rect(zr, Color(geist, 0.6), false, 1.0)
	ci.draw_rect(bild, Stil.RAHMEN, false, 1.0)
	# Text rechts
	var x := bild.end.x + 12.0
	var weite := r.end.x - 12.0 - x
	Stil.schreibe(ci, Vector2(x, r.position.y + 20.0), str(d["titel"]), Stil.GROSS, LICHT)
	Stil.absatz(ci, Vector2(x, r.position.y + 34.0), str(d["text"]), weite, Stil.KLEIN, Stil.TEXT)
	Stil.symbol(ci, "schloss", Vector2(x + 4.0, r.position.y + 100.0), 1.0, KUPFER_HELL)
	var bedingung := str(d["bedingung"])
	if _tafel == "phantom" and int(Profil.stat("beste_runde")) > 0:
		bedingung += "\nBisher: Runde %d von %d" % [mini(int(Profil.stat("beste_runde")), Werte.LETZTE_RUNDE), Werte.LETZTE_RUNDE]   # 23.11. (Einführung A)
	Stil.absatz(ci, Vector2(x + 13.0, r.position.y + 96.0), bedingung, weite - 13.0, Stil.KLEIN, KUPFER_HELL)
	# Knopf
	var k := Rect2(TAFEL_KNOPF.position + wackeln, TAFEL_KNOPF.size)
	var an := k.has_point(_maus)
	Stil.platte(ci, k, 3.0, Color(LICHT, 0.2 if an else 0.1), LICHT)
	Stil.schreibe_mittig(ci, k.get_center() + Vector2(0, 1), "Verstanden", Stil.NORMAL, Color.WHITE if an else LICHT)


func _rogue_gesperrt() -> void:
	_meldung = "Rogue schaltest du frei, wenn du Classic bis Runde 20 gewinnst."


## 20.11. (Schritt 5b): Order 24 auf einer Rogue-Karte (Regelpaket modus "rogue" – main.gd startet dann Order24).
func _rogue_los(kname: String) -> void:
	Werte.setze_anfuehrer("brakk")   # 20.11. (Paul): Befehl 24 gilt nur Brakk – keine Anführerwahl
	_starte(true, "normal", kname, "")


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
	for af: Dictionary in Anfuehrer.LISTE:
		Anfuehrer.portraet(str(af["id"]))   # 21.11.: Porträts vorladen (sonst erscheint das Bild beim ersten Zeichnen weiß)
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
	# 19.11.: Diagnose – brach die letzte Sitzung ohne reguläres Ende ab? Einmal melden, mit Modus und Runde.
	var ab: Dictionary = spiel.abgebrochene_sitzung() if spiel != null else {}
	if not ab.is_empty():
		var wo := "%s, Runde %d (%s)" % [str(ab.get("modus", "?")), int(ab.get("runde", 0)), str(ab.get("abschnitt", "?"))]
		print("Abgebrochene Sitzung: ", wo, " seit ", ab.get("zeit", "?"))
		_meldung = ("Die letzte Partie brach ohne Ende ab: %s – die Seite wurde neu geladen." if OS.has_feature("web") else "Die letzte Partie brach ohne Ende ab: %s.") % wo
		if runde > 0:
			_meldung += " Fortsetzen ganz oben."
		# 19.11.: Abbruch und passender Zwischenstand – gleich fortsetzen (ein Tipp, am Handy ohnehin für den Ton nötig).
		# Schutz vor einer Absturzschleife: brach es schon zweimal kurz nach dem Fortsetzen ab, normal ins Startmenü.
		if runde > 0:
			if _auto_folge() >= 2:
				_auto_folge_loeschen()
				_meldung = "Die Partie brach zweimal kurz nach dem Fortsetzen ab – bitte selbst wählen (Fortsetzen ganz oben)."
			else:
				_auto = runde
				_auto_modus = str(ab.get("modus", ""))
				_titel = false


# ------------------------------------------------------------------ Automatisch fortsetzen (19.11.)

## Brach die letzte Sitzung ab (am Handy lädt der Browser die Seite neu) und gibt es einen Zwischenstand, zeigt das Menü
## statt Titelbild und Liste ein Bild „Partie wird fortgesetzt“ – ein Tipp setzt fort, „Zum Hauptmenü“ nicht.
## In user://auto_fortsetzen.json zählt „folge“ die Fortsetzungen, die innerhalb von AUTO_HALTEN Sekunden wieder
## abbrachen; ab 2 geht es normal ins Startmenü. Läuft die Partie länger, löscht ein Zeitgeber den Zähler.
const AUTO_DATEI := "user://auto_fortsetzen.json"
const AUTO_HALTEN := 60.0
const AUTO_KNOPF := Rect2(255, 300, 130, 22)
var _auto := 0                    # Runde, die gleich fortgesetzt wird (0 = nein)
var _auto_modus := ""


static func _auto_folge() -> int:
	if not FileAccess.file_exists(AUTO_DATEI):
		return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTO_DATEI))
	return int((d as Dictionary).get("folge", 0)) if d is Dictionary else 0


static func _auto_folge_loeschen() -> void:
	if FileAccess.file_exists(AUTO_DATEI):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTO_DATEI))


func _auto_los() -> void:
	var folge := _auto_folge() + 1   # vor dem Öffnen lesen – WRITE leert die Datei
	var datei := FileAccess.open(AUTO_DATEI, FileAccess.WRITE)
	if datei != null:
		datei.store_string(JSON.stringify({"folge": folge}))
		datei.close()
	# Läuft die Partie länger als AUTO_HALTEN (dazu die Ladezeit), war es keine Absturzschleife. Der Zeitgeber gehört dem
	# SceneTree und überlebt den Szenenwechsel; Echtzeit, auch in der Pause.
	_welt.get_tree().create_timer(AUTO_HALTEN + 15.0, true, false, true).timeout.connect(Startmenue._auto_folge_loeschen)
	_auto = 0
	_fortsetzen()


func _auto_abbrechen() -> void:
	_auto = 0
	_auto_folge_loeschen()
	_frage_namen_beim_ersten_mal()


func _male_auto(ci: Control) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color("0b0e14"))
	var hg := _bild("res://assets/neu/menue/kaserne.png")
	if hg != null:
		ci.draw_texture_rect(hg, Rect2(0, 0, 640, 360), false, Color(1, 1, 1, 0.35))
	Stil.schreibe_mittig(ci, Vector2(320, 140), "Partie wird fortgesetzt", 24, Stil.TEXT)
	Stil.schreibe_mittig(ci, Vector2(320, 172), ("Runde %d" % _auto) + (" · " + _auto_modus if _auto_modus != "" else ""), Stil.GROSS, Color("e8b77a"))
	var puls := 0.55 + 0.45 * sin(_zeit * 3.0)
	Stil.schreibe_mittig(ci, Vector2(320, 230), "Tippen zum Weiterspielen", Stil.GROSS, Color(1, 1, 1, puls))
	Stil.platte(ci, AUTO_KNOPF, 2.0)
	Stil.schreibe_mittig(ci, AUTO_KNOPF.get_center(), "Zum Hauptmenü", Stil.KLEIN, Stil.TEXT)


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
	# 25.11.: Lädt die Liste noch, kurz warten – sonst käme ein eingebautes Phantom, obwohl der Pool gleich da ist
	if Online.zustand == "laedt":
		_laedt = true
		_meldung = "Phantom wird geladen …"
		while Online.zustand == "laedt":
			await _welt.get_tree().process_frame
		_laedt = false
		_meldung = ""
	# 18.11.: zuerst online (der aktuelle Pool aller Spieler), sonst die eingebauten Phantome
	if Online.bereit() and not (Online.listen[art] as Array).is_empty():
		_laedt = true
		_meldung = "Phantom wird geladen …"
		var e := Online.waehle(art, wie)
		var pfad := "" if e.is_empty() else await Online.hole(e)
		if pfad != "" and art == "verteidigung":
			var ersatz: Array = []
			var ohne: Array = [str(e["id"])]
			for i in 6:   # 19.11.: der Angriff läuft immer bis Runde 20 – genug Ersatz holen (sonst springt der eingebaute Pool ein)
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


## 23.11. (Einführung C): erster Besuch im Phantom-Menü – Sonde 7 erklärt in drei Sätzen; „So funktioniert's“ ruft sie wieder auf.
## Danach, falls vorhanden, der Phantom-Bericht (G): was seit dem letzten Besuch mit deinen Phantomen geschah.
func _phantom_einfuehrung() -> void:
	var bt := Online.bericht_text()
	if bt != "":
		_meldung = bt
		_meldung_gold = true
		Profil.setze_einstellung("phantom_bericht_seit", Time.get_datetime_string_from_system(true) + "Z")
		Online.bericht = {}
	if not bool(Profil.einstellung("pe_menue", false)):
		Profil.setze_einstellung("pe_menue", true)
		_phantom_erklaeren()


func _phantom_erklaeren() -> void:
	if is_instance_valid(_funk):
		_funk.schliessen()
	_funk = Funkfenster.zeige(self, [
		{"text": "Ein Phantom ist die Aufzeichnung eines echten Spielers: Dein Bau bleibt zurück, andere greifen ihn an – und du greifst ihre an."},
		{"text": "Angreifen: Du planst Wellen gegen einen fremden Bau. Verteidigen: Du hältst gegen einen fremden Angriff."},
		{"text": tr("Dein Angriff beginnt in Runde %d – die Verteidigung steht dann schon.") % Phantom.ANGRIFF_AB_RUNDE},
		{"text": tr("Jeder Lauf zählt für deine Elo: gegen Stärkere zu gewinnen bringt mehr. Die ersten 5 Läufe sind deine Einstufung – so lange ist dein Rang vorläufig.")},
	])
	_funk.unten = 716.0
	_funk.layer = 101   # das Startmenü selbst liegt auf Ebene 100


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


## 20.11.: Entwicklercode – dasselbe unsichtbare Eingabefeld wie beim Namen, Enter oder „Einlösen“ löst ein.
func _code_text() -> String:
	if _tippt() and _code_modus:
		return _eingabe.text + ("_" if fmod(_zeit, 1.0) < 0.55 else " ")
	return _code if _code != "" else "–"


func _starte_code() -> void:
	if _tippt():
		return
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var antwort: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify("Code:"), JSON.stringify(_code)], true)
		if antwort is String:
			_code = (antwort as String).strip_edges()
			_baue()
		return
	_code_modus = true
	_eingabe.max_length = 32
	_eingabe.text = _code
	_eingabe.grab_focus()
	_eingabe.caret_column = _eingabe.text.length()
	_meldung = ""
	_baue()


## Feld verlassen, Getipptes behalten.
func _code_merken() -> void:
	if _tippt() and _code_modus:
		_code = _eingabe.text.strip_edges()
		_eingabe.release_focus()


func _loese_code() -> void:
	_code_merken()
	if Profil.code_einloesen(_code):
		_code = ""
	_baue()


func _starte_eingabe() -> void:
	if _tippt():
		return
	_code_modus = false   # 20.11.
	_eingabe.max_length = Profil.NAME_MAX
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		# 18.11. (Paul): am Handy öffnet das unsichtbare Feld keine Bildschirmtastatur – dort das Eingabefenster des Browsers
		var alt := Profil.name() if Profil.hat_namen() else ""
		var antwort: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify("Dein Spitzname (bis %d Zeichen):" % Profil.NAME_MAX), JSON.stringify(alt)], true)
		if antwort is String:
			_eingabe.text = (antwort as String).strip_edges().substr(0, Profil.NAME_MAX)
			_bestaetige_namen()
			_baue()
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
	if Profil.hat_namen():   # 21.11.: Pflicht – auch wer früher „Später“ gewählt hat, wird jetzt gefragt
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
	var za := _zahlen(Profil.id(), "angriff")   # 24.11. (Paul): langfristige Bilanz neben der Elo
	var zv := _zahlen(Profil.id(), "verteidigung")
	_abschnitt(ci, x, rechts, y, "PHANTOM-MODUS", KUPFER_HELL, [
		["Angriffe", ("%d · %d geknackt" % [za["spiele"], za["siege"]]) if za["da"] else "%d · %d geknackt" % [Profil.stat("angriffe"), Profil.stat("geknackt")]],
		["Verteidigungen", ("%d · %d gehalten" % [zv["spiele"], zv["siege"]]) if zv["da"] else "–"],
		["Angriffs-Elo", _elo_zeile(za)],
		["Verteidigungs-Elo", _elo_zeile(zv)],
		["Beste Angriffswertung", str(ba) if ba > 0 else "–"],
		["Eigene Phantome", str(Profil.stat("phantome"))]])
	Stil.schreibe(ci, Vector2(x, TAFEL.end.y - 10.0), "gespeichert in diesem Browser", Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.6))
	_male_erfolge(ci)


## 25.11.: Portrait-Auswahl rechts neben den Einträgen der Profilseite – ein Klick blättert weiter.
const PORTRAIT_FELD := Rect2(306, 126, 48, 54)


func _male_portrait_wahl(ci: Control) -> void:
	var r := PORTRAIT_FELD
	var drueber := r.has_point(_maus)
	Stil.platte(ci, r, 3.0, Color(0.05, 0.06, 0.09, 0.96), LICHT if drueber else Stil.RAHMEN)
	ci.draw_texture_rect(Profil.portrait_bild(Profil.portrait()), Rect2(r.position + Vector2(8.0, 5.0), Vector2(32.0, 32.0)), false)
	Stil.schreibe_mittig(ci, Vector2(r.get_center().x, r.position.y + 45.0), tr("Bild %d/%d") % [Profil.portrait() + 1, Werte.PORTRAITS.size()], Stil.KLEIN, Color.WHITE if drueber else Stil.TEXT_BLASS)


## 25.11.: Elo auf der Profilseite – vorläufige mit „?“ und Zähler statt der besten.
func _elo_zeile(z: Dictionary) -> String:
	if not z["da"]:
		return "–"
	if Online.vorlaeufig(int(z["spiele"])):
		return "%d? · %s" % [z["elo"], Online.vorlaeufig_text(int(z["spiele"]))]
	return "%d (beste %d)" % [z["elo"], z["elo_max"]]


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
const ERFOLGE_SPALTEN := 8   # 19.11.: 8 statt 7 Spalten – 22 Erfolge passen so in drei Reihen

func _erfolg_feld(i: int) -> Rect2:
	var p := ERFOLGE_TAFEL.position + Vector2(12.0 + (i % ERFOLGE_SPALTEN) * 35.0, 26.0 + (i / ERFOLGE_SPALTEN) * 28.0)
	return Rect2(p, Vector2(32, 24))


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
				info = "??? – " + str(e.get("tipp", "ein versteckter Erfolg."))   # 20.11. (Paul): manche verraten eine Anspielung
	Stil.absatz(ci, Vector2(r.position.x + 12.0, r.end.y - 22.0), info, r.size.x - 24.0, Stil.KLEIN, Stil.TEXT_BLASS)


## Rangliste im Phantom-Menü: beste Angriffe und stärkste Verteidigungen (Elo). Ohne Verbindung der eingebaute Pool.
## 22.11. (Paul, Grafik-Chat): neue Darstellung nach dem Prinzip der Star-Fox-Tafel – Konzept unverändert (eine Liste,
## Elo-Reihenfolge, Punkte bzw. gehaltene Duelle + Elo). Reiter Angriff / Verteidigung statt zwei Abschnitten, feste
## Spalten mit dunklen Ziffernfeldern, die Spaltenfarbe trägt die Bedeutung (Name Cyan, Punkte Gold, Elo Kupfer),
## Anführer als Text hinter dem Namen, Top 10 und darunter der eigene Platz fest („DU“), auch außerhalb der Top 10.
const SILBER := Color("c9d4e0")
const RANG_ZEILE := 16.0
const RANG_ZAHL := 10
var _rang_reiter := "angriff"       # 22.11.: angriff | verteidigung
var _rang_ansicht := "spieler"      # 23.11. (Paul): spieler (Spieler-Elo) | phantome (Phantom-Elo)


## Reiterflächen (für Zeichnen und Klick): [art, Rechteck].
func _rang_reiter_rects() -> Array:
	var x := TAFEL.position.x + 12.0
	var b := (TAFEL.size.x - 24.0 - 4.0) / 2.0
	var y := TAFEL.position.y + 26.0
	return [["angriff", Rect2(x, y, b, 14.0)], ["verteidigung", Rect2(x + b + 4.0, y, b, 14.0)]]


## 23.11.: Umschalter Spieler / Phantome oben neben dem Titel: [ansicht, Rechteck].
func _rang_ansicht_rects() -> Array:
	var b := 46.0
	var x := TAFEL.position.x + 84.0
	var y := TAFEL.position.y + 8.0
	return [["spieler", Rect2(x, y, b, 12.0)], ["phantome", Rect2(x + b + 2.0, y, b, 12.0)]]


## Klick auf einen Reiter: true, wenn der Klick verbraucht ist.
func _rang_klick(p: Vector2) -> bool:
	if _seite != "phantom":
		return false
	for r: Array in _rang_ansicht_rects():
		if (r[1] as Rect2).has_point(p):
			if _rang_ansicht != str(r[0]):
				_rang_ansicht = str(r[0])
				Ton.spiele(_welt, "ui-klick", -6.0)
			return true
	for r: Array in _rang_reiter_rects():
		if (r[1] as Rect2).has_point(p):
			if _rang_reiter != str(r[0]):
				_rang_reiter = str(r[0])
				Ton.spiele(_welt, "ui-klick", -6.0)
			return true
	# 24.11. (Paul): Klick auf eine Zeile öffnet die Spielerkarte; Klick auf die eigene Bilanz die eigene
	for t: Array in _rang_treffer:
		if (t[0] as Rect2).has_point(p):
			_karte_profil = str(t[1])
			Ton.spiele(_welt, "ui-klick", -6.0)
			return true
	if _bilanz_rect.has_point(p) and Profil.id() != "":
		_karte_profil = Profil.id()
		Ton.spiele(_welt, "ui-klick", -6.0)
		return true
	return false


func _male_rangliste(ci: Control) -> void:
	_rang_treffer = []
	Stil.platte(ci, TAFEL, 6.0, Color(0.05, 0.06, 0.09, 0.9), Stil.RAHMEN)
	var x := TAFEL.position.x + 12.0
	var rechts := TAFEL.end.x - 12.0
	var y := TAFEL.position.y + 14.0
	ci.draw_rect(Rect2(TAFEL.position.x + 12.0, TAFEL.position.y + 3.0, 60.0, 1.0), LICHT)   # Lichtkante oben
	Stil.schreibe(ci, Vector2(x, y), "RANGLISTE", Stil.GROSS, LICHT)
	# Stand als Pille: grüner Punkt pulsiert, solange online
	var stand: String = {"laedt": "lädt …", "online": "online", "offline": "offline", "unbekannt": "…"}.get(Online.zustand, "")
	if Online.zustand == "online" and not Online.bereit():
		stand = "noch leer"
	var gruen := Online.zustand == "online"
	var sf: Color = Color("8fe39a") if gruen else Stil.TEXT_BLASS
	var pw := Stil.breite(stand, Stil.KLEIN) + 18.0
	var pille := Rect2(rechts - pw, y - 6.0, pw, 12.0)
	Stil.platte(ci, pille, 3.0, Color(sf, 0.1), Color(sf, 0.6))
	ci.draw_circle(pille.position + Vector2(7.0, 6.0), 2.0, Color(sf, 0.55 + 0.45 * absf(sin(_zeit * 3.0))) if gruen else Color(sf, 0.6))
	Stil.schreibe(ci, pille.position + Vector2(12.0, 6.0), stand, Stil.KLEIN, sf)
	# 23.11.: Umschalter Spieler / Phantome
	for r: Array in _rang_ansicht_rects():
		var rr: Rect2 = r[1]
		var an := str(r[0]) == _rang_ansicht
		var drueber := rr.has_point(_maus)
		Stil.platte(ci, rr, 3.0, Color(LICHT, 0.16) if an else (Color(LICHT, 0.06) if drueber else Stil.METALL_TIEF), LICHT if an else Color(LICHT, 0.4 if drueber else 0.22))
		Stil.schreibe_mittig(ci, rr.get_center(), "SPIELER" if str(r[0]) == "spieler" else "PHANTOME", Stil.KLEIN, LICHT if an else Stil.TEXT_BLASS)
	# Reiter
	for r: Array in _rang_reiter_rects():
		var art := str(r[0])
		var rr: Rect2 = r[1]
		var farbe: Color = KUPFER_HELL if art == "angriff" else LICHT
		var an := art == _rang_reiter
		var drueber := rr.has_point(_maus)
		Stil.platte(ci, rr, 3.0, Color(farbe, 0.16) if an else (Color(farbe, 0.06) if drueber else Stil.METALL_TIEF), farbe if an else Color(farbe, 0.45 if drueber else 0.25))
		if an:
			ci.draw_rect(Rect2(rr.position.x + 3.0, rr.end.y - 3.0, rr.size.x - 6.0, 1.0), farbe)
		var titel := "BESTE ANGRIFFE" if art == "angriff" else "VERTEIDIGUNG"
		Stil.symbol(ci, "panzer" if art == "angriff" else "wall", Vector2(rr.position.x + 9.0, rr.get_center().y), 1.0, farbe if an else Color(farbe, 0.6))
		Stil.schreibe(ci, Vector2(rr.position.x + 17.0, rr.get_center().y), titel, Stil.KLEIN, farbe if an else Stil.TEXT_BLASS)
	y = TAFEL.position.y + 50.0
	var farbe_art: Color = KUPFER_HELL if _rang_reiter == "angriff" else LICHT
	# Spaltenköpfe als kleine Pillen (wie die Star-Fox-Tafel)
	var sp := _rang_spalten(x, rechts)
	var wert_kopf := "LÄUFE" if _rang_ansicht == "spieler" else ("BESTER" if _rang_reiter == "angriff" else "GEHALTEN")
	var koepfe := [["#", sp["rang"]], ["NAME", sp["name"]], [wert_kopf, sp["wert"]], ["ELO", sp["elo"]]]
	if sp.has("duelle"):
		koepfe.insert(3, ["DUELLE", sp["duelle"]])
	for k: Array in koepfe:
		var kr := Rect2((k[1] as Vector2).x, y - 5.0, (k[1] as Vector2).y, 10.0)
		Stil.platte(ci, kr, 2.0, Color(0.11, 0.12, 0.15), Stil.RAHMEN)
		Stil.schreibe_mittig(ci, kr.get_center(), str(k[0]), Stil.KLEIN, Stil.TEXT_BLASS)
	var kopf_hinweis := ""
	var kopf_rect := Rect2()
	for k: Array in koepfe:
		var kr2 := Rect2((k[1] as Vector2).x, y - 5.0, (k[1] as Vector2).y, 10.0)
		if kr2.has_point(_maus):
			kopf_hinweis = str(_KOPF_HINWEISE.get(str(k[0]), ""))
			kopf_rect = kr2
	y += 9.0
	var alle := _ranglisten_zeilen(_rang_reiter)
	var mein := Profil.id()
	var mein_platz := -1
	for i in alle.size():
		if mein != "" and str(alle[i][3]) == mein:
			mein_platz = i
			break
	if alle.is_empty():
		Stil.platte(ci, Rect2(x, y, rechts - x, RANG_ZEILE - 2.0), 3.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe(ci, Vector2(x + 8.0, y + 7.0), "noch niemand – sei der Erste", Stil.KLEIN, Stil.TEXT_BLASS)
	for i in mini(alle.size(), RANG_ZAHL):
		_rang_zeile(ci, y + i * RANG_ZEILE, sp, i, alle[i], i == mein_platz, farbe_art)
		var zr := Rect2(x, y + i * RANG_ZEILE, rechts - x, RANG_ZEILE - 2.0)
		_rang_klickbar(ci, zr, str(alle[i][3]))
		if _vorlaeufig_n(alle[i]) >= 0 and zr.has_point(_maus) and _karte_profil == "":
			kopf_hinweis = tr("vorläufig – %d von %d Läufen") % [_vorlaeufig_n(alle[i]), Online.LISTE_AB]   # 25.11.
			kopf_rect = zr
	# eigener Platz, fest unten
	var unten := TAFEL.end.y - 12.0 - (RANG_ZEILE - 2.0)
	ci.draw_rect(Rect2(x, unten - 4.0, rechts - x, 1.0), Color(farbe_art, 0.3))
	if mein_platz >= 0:
		_rang_zeile(ci, unten, sp, mein_platz, alle[mein_platz], true, farbe_art)
		_rang_klickbar(ci, Rect2(x, unten, rechts - x, RANG_ZEILE - 2.0), mein)
	else:
		var r := Rect2(x, unten, rechts - x, RANG_ZEILE - 2.0)
		_rang_klickbar(ci, r, mein)
		Stil.platte(ci, r, 3.0, Stil.METALL_TIEF, Color(LICHT, 0.35))
		Stil.schreibe(ci, Vector2(x + 7.0, r.get_center().y), "DU", Stil.NORMAL, LICHT)
		Stil.schreibe(ci, Vector2(x + 26.0, r.get_center().y), _rang_du_text(), Stil.KLEIN, Stil.TEXT_BLASS)
	if kopf_hinweis != "":
		# 23.11. (Einführung C): kleine Erklärung beim Darüberfahren
		var tb := minf(Stil.breite(kopf_hinweis, Stil.KLEIN) + 12.0, TAFEL.size.x - 24.0)
		var tr := Rect2(clampf(kopf_rect.get_center().x - tb / 2.0, TAFEL.position.x + 8.0, TAFEL.end.x - tb - 8.0), kopf_rect.end.y + 3.0, tb, 14.0)
		Stil.platte(ci, tr, 2.0, Color(0.02, 0.03, 0.05, 0.97), LICHT)
		Stil.schreibe_mittig(ci, tr.get_center(), kopf_hinweis, Stil.KLEIN, Stil.TEXT)


## 24.11.: Zeile der Rangliste klickbar machen (Spielerkarte); Hover hebt sie hervor. Eingebaute Pool-Phantome haben keine Karte.
func _rang_klickbar(ci: Control, r: Rect2, profil: String) -> void:
	if profil == "" or profil == "pool":
		return
	_rang_treffer.append([r, profil])
	if r.has_point(_maus) and _karte_profil == "":
		ci.draw_rect(r, Color(LICHT, 0.7), false, 1.0)


const _KOPF_HINWEISE := {
	"#": "Platz nach Elo",
	"NAME": "Wer dahintersteckt (bei Phantomen mit Anführer)",
	"LÄUFE": "Gespielte Phantom-Läufe – bis 5 ist der Platz vorläufig",
	"BESTER": "Beste Wertung dieses Angriffs",
	"GEHALTEN": "So oft hat die Verteidigung gehalten",
	"DUELLE": "Duelle gegen echte Spieler – ab 5 in der Liste",
	"ELO": "Stärke: gegen Stärkere gewinnen bringt mehr",
}


## Spalten: Name -> Vector2(x, breite).
func _rang_spalten(x: float, rechts: float) -> Dictionary:
	var elo_b := 34.0 if _rang_ansicht == "spieler" else 30.0   # 25.11.: Platz für das „?“ vorläufiger Elo
	var wert_b := 42.0
	var rang_b := 16.0
	var elo_x := rechts - elo_b
	var aus := {"rang": Vector2(x, rang_b), "elo": Vector2(elo_x, elo_b)}
	var vor_elo := elo_x
	if _rang_ansicht == "phantome" and Online.bereit():
		var duell_b := 28.0   # 23.11.: Zahl der Duelle
		vor_elo = elo_x - 3.0 - duell_b
		aus["duelle"] = Vector2(vor_elo, duell_b)
	var wert_x := vor_elo - 3.0 - wert_b
	var name_x := x + rang_b + 3.0
	aus["name"] = Vector2(name_x, wert_x - 3.0 - name_x)
	aus["wert"] = Vector2(wert_x, wert_b)
	return aus


## Eine Zeile: Platzziffer, dann dunkle Felder für Name (+ Anführer), Wert (Gold) und Elo (Kupfer).
func _rang_zeile(ci: Control, y: float, sp: Dictionary, i: int, z: Array, eigen: bool, farbe: Color) -> void:
	var h := RANG_ZEILE - 2.0
	var m := y + h * 0.5
	var vorl := _vorlaeufig_n(z)   # 25.11.: vorläufige Zeilen gedämpft, ohne Medaille
	var medaille: Color = [Stil.GOLD, SILBER, Stil.KUPFER][i] if i < 3 and vorl < 0 else Stil.TEXT_BLASS
	# Platz: große Ziffer ohne Kasten, die ersten drei in Medaillenfarbe
	var rs: Vector2 = sp["rang"]
	Stil.schreibe_mittig(ci, Vector2(rs.x + rs.y * 0.5, m), "%d" % (i + 1), Stil.GROSS if i < 9 else Stil.NORMAL, medaille)
	# Namensfeld
	var ns: Vector2 = sp["name"]
	var nr := Rect2(ns.x, y, ns.y, h)
	Stil.platte(ci, nr, 2.0, Color(LICHT, 0.12) if eigen else Color(0.03, 0.035, 0.05), LICHT if eigen else (Color(Stil.GOLD, 0.55) if i == 0 and vorl < 0 else Stil.RAHMEN))
	var name := str(z[0])
	var name_farbe: Color = Color.WHITE if eigen else (Stil.TEXT_BLASS if vorl >= 0 else LICHT)
	var nw := Stil.schreibe(ci, Vector2(nr.position.x + 5.0, m), name, Stil.NORMAL, name_farbe)
	var zusatz := ""
	if eigen:
		zusatz = "du"
	if str(z[4]) != "":
		zusatz = (zusatz + " · " if zusatz != "" else "") + str(z[4])
	var versuche: Array = [zusatz]
	if eigen and vorl >= 0:   # 25.11.: die eigene Zeile nennt den Stand – so ausführlich, wie Platz ist
		versuche = [zusatz + " · " + Online.vorlaeufig_text(vorl), Online.vorlaeufig_text(vorl), "%d/%d" % [vorl, Online.LISTE_AB]]
	var platz := nr.end.x - (nr.position.x + 5.0 + nw + 4.0) - 4.0
	for t: String in versuche:
		if t != "" and Stil.breite(t, Stil.KLEIN) <= platz:
			Stil.schreibe(ci, Vector2(nr.position.x + 5.0 + nw + 4.0, m), t, Stil.KLEIN, LICHT if eigen else Stil.TEXT_BLASS)
			break
	# Wertfeld (Gold) – führende Nullen gedimmt wie auf einer Anzeigetafel
	var ws: Vector2 = sp["wert"]
	var wr := Rect2(ws.x, y, ws.y, h)
	Stil.platte(ci, wr, 2.0, Color(0.03, 0.035, 0.05), Stil.RAHMEN)
	_rang_ziffern(ci, wr, str(z[1]), Color(Stil.GOLD, 0.5) if vorl >= 0 else Stil.GOLD, 5)
	# 23.11.: Duelle (Silber)
	if sp.has("duelle") and z.size() > 5:
		var ds: Vector2 = sp["duelle"]
		var dr := Rect2(ds.x, y, ds.y, h)
		Stil.platte(ci, dr, 2.0, Color(0.03, 0.035, 0.05), Stil.RAHMEN)
		_rang_ziffern(ci, dr, str(z[5]), SILBER, 3)
	# Elofeld (Kupfer)
	var es: Vector2 = sp["elo"]
	var er := Rect2(es.x, y, es.y, h)
	Stil.platte(ci, er, 2.0, Color(0.03, 0.035, 0.05), Stil.RAHMEN)
	_rang_ziffern(ci, er, str(z[2]), Color(KUPFER_HELL, 0.55) if vorl >= 0 else KUPFER_HELL, 4)


## 25.11.: Läufe einer vorläufigen Spielerzeile (z[5]), -1 = fester Rang oder Phantom-Zeile.
func _vorlaeufig_n(z: Array) -> int:
	return int(z[5]) if _rang_ansicht == "spieler" and z.size() > 5 else -1


## Ziffern rechtsbündig ins Feld; reine Zahlen bekommen gedimmte führende Nullen bis `stellen`.
func _rang_ziffern(ci: Control, r: Rect2, text: String, farbe: Color, stellen: int) -> void:
	var m := r.get_center().y
	var ende := r.end.x - 4.0
	if text.is_valid_int() and text.length() < stellen:
		var null_teil := "0".repeat(stellen - text.length())
		var tw := Stil.breite(text, Stil.NORMAL)
		var nw := Stil.breite(null_teil, Stil.NORMAL)
		Stil.schreibe(ci, Vector2(ende - tw - nw, m), null_teil, Stil.NORMAL, Color(farbe, 0.22))
		Stil.schreibe(ci, Vector2(ende - tw, m), text, Stil.NORMAL, farbe)
		return
	Stil.schreibe(ci, Vector2(ende - Stil.breite(text, Stil.NORMAL), m), text, Stil.NORMAL, farbe)


## [Name, Wert, Elo-Text, Profil-ID, Anführer] für die ganze Liste einer Art (Elo-Reihenfolge wie bisher).
func _ranglisten_zeilen(art: String) -> Array:
	var aus: Array = []
	if Online.bereit() and _rang_ansicht == "spieler":
		# 25.11. (Paul): Spieler-Elo ab dem ersten Lauf; bis Online.LISTE_AB Läufe vorläufig („?“, z[5] = Läufe)
		for e: Dictionary in (Online.spieler_listen[art] as Array):
			var n := int(e.get("spiele", 0))
			if n < 1:
				continue
			var vorl := Online.vorlaeufig(n)
			aus.append([str(e.get("spieler", "?")).left(12), "%d" % n, "%d%s" % [roundi(float(e.get("elo", 1000))), "?" if vorl else ""], str(e.get("profil", "")), "", n if vorl else -1])
		return aus
	if Online.bereit():
		for e: Dictionary in (Online.listen[art] as Array):
			if int(e.get("spiele", 0)) < Online.LISTE_AB:
				continue   # 23.11.: Phantome erst ab LISTE_AB Duellen
			var wert := ""
			if art == "angriff":
				wert = "%d" % int(e.get("wertung", 0))
			else:
				var sp := int(e.get("spiele", 0))
				wert = "%d/%d" % [int(e.get("siege", 0)), sp] if sp > 0 else "neu"
			var af := ""
			if art == "verteidigung":
				af = Anfuehrer.name(Anfuehrer.gueltig(str(e.get("anfuehrer", "brakk")) if e.get("anfuehrer") != null else "brakk"))
			aus.append([str(e.get("spieler", "?")).left(12), wert, "%d" % roundi(float(e.get("elo", 1000))), str(e.get("profil", "")), af, "%d" % int(e.get("spiele", 0))])
		return aus
	var funde := Phantom.liste(art, true)
	funde.sort_custom(func(a, b): return int(a["wert"]) > int(b["wert"]))
	for f: Dictionary in funde:
		aus.append([str(f.get("spieler", "?")).left(12), "%d" % int(f["wert"]) if art == "angriff" else "–", "–", "", ""])
	return aus


## 23.11.: Text in der „DU“-Zeile, wenn man (noch) nicht in der Liste steht – mit dem Weg dorthin.
func _rang_du_text() -> String:
	var mein := Profil.id()
	var spieler := _rang_ansicht == "spieler"
	if Online.bereit() and mein != "":
		var beste := -1
		for e: Dictionary in ((Online.spieler_listen if spieler else Online.listen)[_rang_reiter] as Array):
			if str(e.get("profil", "")) == mein:
				beste = maxi(beste, int(e.get("spiele", 0)))
		if not spieler and beste >= 0 and beste < Online.LISTE_AB:   # 25.11.: Spieler stehen sofort in der Liste
			var rest := Online.LISTE_AB - beste
			return "dein Phantom ist neu – noch %d %s bis zur Liste" % [rest, "Duell" if rest == 1 else "Duelle"]
	if spieler:
		return "noch kein Lauf als Angreifer" if _rang_reiter == "angriff" else "noch kein Lauf als Verteidiger"
	return "noch kein Angriff in der Liste" if _rang_reiter == "angriff" else "noch keine Verteidigung in der Liste"


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
	if _tippt() and _seite == "profil" and not _code_modus:
		_eintraege[0][0] = "Name: " + _name_text()
	if _tippt() and _code_modus and _seite == "einstellungen":   # 20.11.: blinkender Strich im Codefeld
		for e: Array in _eintraege:
			if str(e[0]).begins_with("Code: "):
				e[0] = "Code: " + _code_text()
	# Übersicht oder Hangar offen: das Menü wartet unsichtbar
	_welt.visible = not is_instance_valid(_hangar) and not (spiel != null and spiel.get("_lexikon") != null and spiel._lexikon.visible)
	SichererRand.einpassen(_welt, Stil.UI_SKALA)   # 19.11.: iPhone – sichere Ränder (am PC unverändert)
	_grund.visible = _welt.visible and SichererRand.faktor() < 1.0
	_welt.queue_redraw()


func _zeile(i: int) -> Rect2:
	if _seite == "anfuehrer":   # 19.11.: Kacheln statt Zeilen
		return _af_kachel(i) if i < _af_liste().size() else AF_ZURUECK
	return Rect2(LISTE_X, LISTE_Y + i * ZEILE_H, BREITE, ZEILE_H - 4.0)


## 19.11.: Esc / Rechtsklick – von der Anführerwahl zurück auf die Seite davor, sonst ins Hauptmenü.
func _zurueck() -> void:
	_zeige(_af_zurueck if _seite == "anfuehrer" else "haupt")


func _input(event: InputEvent) -> void:
	if not _welt.visible or not (event is InputEventKey and event.pressed):
		return
	if _karte_profil != "":
		if not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_BACKSPACE]:
			_karte_profil = ""   # 24.11.: Spielerkarte schließen
			_klick()
		get_viewport().set_input_as_handled()
		return
	if _tafel != "":
		if not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_BACKSPACE]:
			_tafel_zu()   # 21.11.: Teaser-Tafel eines gesperrten Modus
		get_viewport().set_input_as_handled()
		return
	if _auto > 0:
		if not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				_auto_abbrechen()
			else:
				_auto_los()
		get_viewport().set_input_as_handled()
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
			if _code_modus:
				_loese_code()   # 20.11.
			else:
				_bestaetige_namen()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			if _code_modus:
				_code_merken()   # 20.11.
				_baue()
				get_viewport().set_input_as_handled()
				return
			if _erststart:
				_meldung = "Bitte gib zuerst einen Namen ein."   # 21.11.: Pflicht beim ersten Start
				get_viewport().set_input_as_handled()
				return
			_eingabe.release_focus()
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
			if _seite != "haupt" and not event.echo and not _erststart:   # 21.11.: beim ersten Start kein Weg am Namen vorbei
				_zurueck()   # 19.11.
		_:
			return
	get_viewport().set_input_as_handled()


## Klickgeräusch im Startmenü (17.11., Paul: mehr Rückmeldung beim Klicken).
func _klick() -> void:
	Ton.spiele(self, "ui-klick", 0.0)


func _maus_eingabe(event: InputEvent) -> void:
	if _karte_profil != "":
		# 24.11.: „Schließen“ oder ein Klick neben die Karte schließt sie
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var pk := (event as InputEventMouseButton).position
			if KARTE_KNOPF.has_point(pk) or not KARTE_R.has_point(pk) or event.button_index == MOUSE_BUTTON_RIGHT:
				_karte_profil = ""
				_klick()
		return
	if _tafel != "":
		# 21.11.: „Verstanden“ oder ein Klick neben die Tafel schließt sie
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var p := (event as InputEventMouseButton).position
			if TAFEL_KNOPF.has_point(p) or not TAFEL_RECHT.has_point(p) or event.button_index == MOUSE_BUTTON_RIGHT:
				_tafel_zu()
		return
	if _auto > 0:
		if event is InputEventMouseButton and event.pressed:
			_klick()
			if AUTO_KNOPF.has_point((event as InputEventMouseButton).position):
				_auto_abbrechen()
			else:
				_auto_los()
		return
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
		if event.button_index == MOUSE_BUTTON_LEFT and _rang_klick((event as InputEventMouseButton).position):
			return   # 22.11.: Reiter der Rangliste
		if event.button_index == MOUSE_BUTTON_LEFT and _seite == "profil" and not _erststart and PORTRAIT_FELD.has_point((event as InputEventMouseButton).position):
			Profil.setze_portrait(Profil.portrait() + 1)   # 25.11.
			Ton.spiele(_welt, "ui-klick", -6.0)
			return
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_klick()
		if event.button_index == MOUSE_BUTTON_LEFT and _seite != "profil" and _seite != "anfuehrer" and _profil_rect().has_point((event as InputEventMouseButton).position):
			_zeige("profil")
			return
		if event.button_index == MOUSE_BUTTON_LEFT and TC_ADRESSE != "" and _seite != "anfuehrer" and _tc_rect().has_point((event as InputEventMouseButton).position):
			_oeffne_tc()
			return
		if _tippt() and _code_modus and event.button_index == MOUSE_BUTTON_LEFT:
			_code_merken()   # 20.11.: Klick daneben behält den Code („Einlösen“ löst ihn dann ein)
		elif _tippt() and event.button_index == MOUSE_BUTTON_LEFT and not _zeile(0).has_point((event as InputEventMouseButton).position):
			_bestaetige_namen()   # Klick daneben übernimmt den Namen
			if not _tippt():
				return   # übernommen: der Klick ist damit verbraucht (sonst löst er auf der neuen Seite gleich etwas aus)
		if event.button_index == MOUSE_BUTTON_RIGHT and _erststart:
			return   # 21.11.: beim ersten Start führt kein Weg am Namen vorbei
		if event.button_index == MOUSE_BUTTON_RIGHT and _seite != "haupt":
			for i in _eintraege.size():
				var e: Array = _eintraege[i]
				if _zeile(i).has_point((event as InputEventMouseButton).position) and e.size() > 4 and _seite != "anfuehrer":
					(e[4] as Callable).call(-10, true)   # Rechtsklick auf eine Lautstärke: leiser
					return
			_zurueck()   # 19.11.
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in _eintraege.size():
				if _zeile(i).has_point((event as InputEventMouseButton).position):
					_wahl = i
					(_eintraege[i][1] as Callable).call()
					return


# ------------------------------------------------------------------ Zeichnen

func _male(ci: Control) -> void:
	if _auto > 0:
		_male_auto(ci)   # 19.11.
		return
	if _titel:
		_male_titel(ci)
		return
	var hg := _bild("res://assets/neu/menue/kaserne.png")
	if hg != null:
		ci.draw_texture_rect(hg, Rect2(0, 0, 640, 360), false)
	else:
		ci.draw_rect(Rect2(0, 0, 640, 360), Color("10141c"))
	if _seite == "anfuehrer":   # 19.11.: eigene Seite – Kacheln über die ganze Breite
		ci.draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.04, 0.06, 0.72))
		_male_anfuehrer(ci)
		Stil.schreibe_mittig(ci, Vector2(320, 353), "Version %d" % Werte.VERSION, Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.7))
		return
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
	var unter: String = {"haupt": "", "spielen": "Spielen", "phantom": "Phantom-Modus", "einstellungen": "Einstellungen", "profil": "Dein Profil", "grafik": "Grafik für dein Gerät", "herausforderung": "Herausforderungen", "sandbox": "Sandbox", "anfuehrer": "Anführer", "szenarien": "Szenarien", "brakk": "Brakk-Mode", "rogue": "Rogue"}[_seite]
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
		if e[3] == GESPERRT:
			Stil.symbol(ci, "schloss", Vector2(r.end.x - 14.0, r.get_center().y), 1.0, GESPERRT.lightened(0.25 if an else 0.0))   # 21.11.
		var mit_unter := str(e[2]) != ""
		Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + (6.0 if mit_unter else 10.0)), e[0], Stil.NORMAL, farbe)
		if mit_unter:
			Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + 15.0), e[2], Stil.KLEIN, Stil.TEXT_BLASS)
	if _meldung != "":
		Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y + _eintraege.size() * ZEILE_H + 4.0), _meldung, BREITE, Stil.KLEIN, LICHT if _laedt else (Stil.GOLD if _meldung_gold else Stil.WARN))
	if _seite == "phantom":
		_male_rangliste(ci)
		_male_bilanz(ci)
	elif _seite == "herausforderung":
		_male_kartenbild(ci, _wahl_karte)
	elif _seite == "szenarien" and _wahl < Werte.SZENARIEN.size():
		_male_kartenbild(ci, Werte.SZENARIEN[_wahl])   # 20.11.
	elif _seite == "grafik":
		Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y - 2.0 + _eintraege.size() * ZEILE_H + 6.0), "Du spielst auf einem Touchgerät. Ändern kannst du das jederzeit unter Einstellungen → Grafik.", BREITE, Stil.KLEIN, Stil.TEXT_BLASS)
	elif _seite == "profil":
		if _erststart:
			Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y - 2.0 + _eintraege.size() * ZEILE_H + 6.0), "Wie sollen dich andere Spieler sehen? Der Name steht an deinen Phantomen und in der Rangliste.", BREITE, Stil.KLEIN, Stil.TEXT_BLASS)
		else:
			if _profil_brakk:
				_male_profil_brakk(ci)   # 19.11.
			else:
				_male_profil_tafel(ci)
			_male_portrait_wahl(ci)   # 25.11.
	_male_profil_schild(ci)
	_male_tc_emblem(ci)
	Stil.schreibe_mittig(ci, Vector2(320, 353), "Version %d" % Werte.VERSION, Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.7))   # 19.11.: welcher Stand läuft (Handy)
	if _tafel != "":
		_male_tafel(ci)   # 21.11.
	if _karte_profil != "":
		_male_spielerkarte(ci)   # 24.11.


## 24.11. (Paul): Zahlen eines Spielers für eine Seite aus den geladenen Online-Listen.
## da = false: noch keine Läufe (oder offline) – dann „–“ anzeigen.
func _zahlen(profil: String, art: String) -> Dictionary:
	var e: Dictionary = Online.spieler_daten(profil).get(art, {})
	if e.is_empty():
		return {"da": false, "elo": 1000, "elo_max": 1000, "spiele": 0, "siege": 0, "duelle": 0}
	var elo := roundi(float(e.get("elo", 1000)))
	return {"da": true, "elo": elo, "elo_max": maxi(elo, roundi(float(e.get("elo_max", elo)))), "spiele": int(e.get("spiele", 0)), "siege": int(e.get("siege", 0)),
		"duelle": int(e.get("duelle", e.get("spiele", 0)))}   # 24.11. (72): spiele = Läufe, duelle = einzelne Verteidigungen/Angriffe


## Kleine Bilanz im Phantom-Menü unter der Liste: beide Elo-Werte mit bester Elo und Zählern; Klick öffnet die eigene Karte.
func _male_bilanz(ci: Control) -> void:
	var r := Rect2(LISTE_X, 290.0, BREITE, 52.0)
	_bilanz_rect = r
	var an := r.has_point(_maus) and _karte_profil == ""
	Stil.platte(ci, r, 3.0, Color(0.05, 0.06, 0.09, 0.88), LICHT if an else Stil.RAHMEN)
	Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + 8.0), "DEINE BILANZ", Stil.KLEIN, LICHT)
	var hint := "Karte öffnen ▸"
	Stil.schreibe(ci, Vector2(r.end.x - 8.0 - Stil.breite(hint, Stil.KLEIN), r.position.y + 8.0), hint, Stil.KLEIN, Color(Stil.TEXT_BLASS, 1.0 if an else 0.6))
	var mein := Profil.id()
	for i in 2:
		var art: String = ["angriff", "verteidigung"][i]
		var farbe: Color = KUPFER_HELL if i == 0 else LICHT
		var z := _zahlen(mein, art)
		var x := r.position.x + 8.0 + i * (BREITE / 2.0)
		Stil.schreibe(ci, Vector2(x, r.position.y + 19.0), "ANGRIFFS-ELO" if i == 0 else "VERTEIDIGUNGS-ELO", Stil.KLEIN, Stil.TEXT_BLASS)
		if z["da"]:
			var vorl := Online.vorlaeufig(int(z["spiele"]))   # 25.11.
			var elo_text := str(z["elo"]) + ("?" if vorl else "")
			Stil.schreibe(ci, Vector2(x, r.position.y + 31.0), elo_text, Stil.GROSS, farbe)
			Stil.schreibe(ci, Vector2(x + Stil.breite(elo_text, Stil.GROSS) + 6.0, r.position.y + 31.0), Online.vorlaeufig_text(int(z["spiele"])) if vorl else "beste %d" % z["elo_max"], Stil.KLEIN, Stil.TEXT_BLASS)
			Stil.schreibe(ci, Vector2(x, r.position.y + 43.0), "%d %s · %d %s" % [z["spiele"], "Angriffe" if i == 0 else "Verteidigungen", z["siege"], "geknackt" if i == 0 else "gehalten"], Stil.KLEIN, Stil.TEXT)
		else:
			Stil.schreibe(ci, Vector2(x, r.position.y + 31.0), "–", Stil.GROSS, Color(farbe, 0.6))
			Stil.schreibe(ci, Vector2(x, r.position.y + 43.0), "noch kein Lauf", Stil.KLEIN, Stil.TEXT_BLASS)


const KARTE_R := Rect2(106, 52, 428, 252)
const KARTE_KNOPF := Rect2(272, 276, 96, 20)


## 24.11. (Paul): Spielerkarte – langfristige Bilanz eines Spielers (aus der Rangliste anklickbar, auch die eigene).
## Elo bleibt reine Leistung; die Zähler sind eine Aktivitätsstatistik.
func _male_spielerkarte(ci: Control) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.05, 0.72))
	var r := KARTE_R
	Stil.platte(ci, r, 6.0, Color(0.05, 0.06, 0.09, 0.98), Stil.RAHMEN)
	ci.draw_rect(Rect2(r.position.x + 12.0, r.position.y + 3.0, 60.0, 1.0), LICHT)
	var d := Online.spieler_daten(_karte_profil)
	var eigen := _karte_profil == Profil.id()
	var name := str(d["name"])
	if name == "":
		name = Profil.name() if eigen else "Spieler"
	Stil.schreibe(ci, Vector2(r.position.x + 14.0, r.position.y + 14.0), "SPIELERKARTE", Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.schreibe(ci, Vector2(r.position.x + 14.0, r.position.y + 29.0), name, Stil.GROSS, Color.WHITE)
	if eigen:
		var tw := Stil.breite("DU", Stil.KLEIN) + 8.0
		var tx := r.position.x + 14.0 + Stil.breite(name, Stil.GROSS) + 8.0
		Stil.platte(ci, Rect2(tx, r.position.y + 23.0, tw, 12.0), 2.0, Color(LICHT, 0.14), LICHT)
		Stil.schreibe(ci, Vector2(tx + 4.0, r.position.y + 29.0), "DU", Stil.KLEIN, LICHT)
	var sp := (r.size.x - 28.0 - 8.0) / 2.0
	for i in 2:
		var art: String = ["angriff", "verteidigung"][i]
		var farbe: Color = KUPFER_HELL if i == 0 else LICHT
		var z := _zahlen(_karte_profil, art)
		var sr := Rect2(r.position.x + 14.0 + i * (sp + 8.0), r.position.y + 46.0, sp, 160.0)
		Stil.platte(ci, sr, 3.0, Stil.METALL_TIEF, Color(farbe, 0.45))
		ci.draw_rect(Rect2(sr.position.x + 3.0, sr.position.y + 2.0, sr.size.x - 6.0, 1.0), Color(farbe, 0.6))
		Stil.symbol(ci, "panzer" if i == 0 else "wall", Vector2(sr.position.x + 12.0, sr.position.y + 13.0), 1.0, farbe)
		Stil.schreibe(ci, Vector2(sr.position.x + 22.0, sr.position.y + 13.0), "ALS ANGREIFER" if i == 0 else "ALS VERTEIDIGER", Stil.KLEIN, farbe)
		var y := sr.position.y + 36.0
		if not z["da"]:
			Stil.schreibe(ci, Vector2(sr.position.x + 10.0, y + 8.0), "noch kein Lauf", Stil.NORMAL, Stil.TEXT_BLASS)
			continue
		var vorl := Online.vorlaeufig(int(z["spiele"]))   # 25.11.
		var elo_text := str(z["elo"]) + ("?" if vorl else "")
		Stil.schreibe(ci, Vector2(sr.position.x + 10.0, y), elo_text, 28, Color.WHITE)
		Stil.schreibe(ci, Vector2(sr.position.x + 10.0 + Stil.breite(elo_text, 28) + 6.0, y + 3.0), "SPIELER-ELO", Stil.KLEIN, Stil.TEXT_BLASS)
		var platz := Online.spieler_platz(art, _karte_profil)
		var liste_text := "Platz %d in der Rangliste" % platz if platz > 0 else "noch kein Platz in der Liste"
		if vorl:
			liste_text = ("Platz %d · " % platz if platz > 0 else "") + Online.vorlaeufig_text(int(z["spiele"]))
		Stil.schreibe(ci, Vector2(sr.position.x + 10.0, y + 22.0), liste_text, Stil.KLEIN, Stil.GOLD if platz > 0 and not vorl else Stil.TEXT_BLASS)
		y += 42.0
		var quote := roundi(100.0 * float(z["siege"]) / float(maxi(int(z["duelle"]), 1)))   # 24.11. (72): geknackte Verteidigungen je angetroffene
		var zeilen: Array = [
			["Beste Elo", str(z["elo_max"])],
			["Angriffe" if i == 0 else "Verteidigungen", str(z["spiele"])],
			["Geknackt" if i == 0 else "Gehalten", "%d" % z["siege"]],
			["Quote", "%d %%" % quote]]
		for zl: Array in zeilen:
			Stil.schreibe(ci, Vector2(sr.position.x + 10.0, y), str(zl[0]), Stil.KLEIN, Stil.TEXT_BLASS)
			var w := str(zl[1])
			Stil.schreibe(ci, Vector2(sr.end.x - 10.0 - Stil.breite(w, Stil.NORMAL), y), w, Stil.NORMAL, Stil.TEXT)
			y += 14.0
	var ph: Dictionary = d["phantome"]
	Stil.schreibe(ci, Vector2(r.position.x + 14.0, r.position.y + 218.0), "Im Pool: %d %s · %d %s" % [ph["verteidigung"], "Verteidigung" if int(ph["verteidigung"]) == 1 else "Verteidigungen", ph["angriff"], "Angriff" if int(ph["angriff"]) == 1 else "Angriffe"], Stil.KLEIN, Stil.TEXT_BLASS)
	var k := KARTE_KNOPF
	var an := k.has_point(_maus)
	Stil.platte(ci, k, 3.0, Color(LICHT, 0.2 if an else 0.1), LICHT)
	Stil.schreibe_mittig(ci, k.get_center() + Vector2(0, 1), "Schließen", Stil.NORMAL, Color.WHITE if an else LICHT)


## 18.11.: Steckbrief der gewählten Karte rechts neben der Liste. (Paul 18.11.: statt des Minikarten-Bilds –
## das sah grob aus.) Titel und Beschreibung, Eckdaten als Kacheln, Gelände als Farbmarken, Regeln, Herausforderung.
const KARTENBILD := Rect2(372, 128, 252, 170)
const BILD_FARBEN := {"fels": Color("7a7064"), "wasser": Color("2b5d8a"), "anhoehe": Color("b9ad6a"), "sumpf": Color("3d4a2c"),
	"bruecke": Color("8a6239"), "ruine": Color("8d8a96"), "wald": Color("244a26"), "erz": Color("c98a3d"), "eis": Color("cfe9f5"), "minen": Color("6b3b3b"),
	"mauern": Color("c49b63")}
const GELAENDE_NAMEN := {"fels": "Fels", "wasser": "Wasser", "anhoehe": "Anhöhe", "sumpf": "Sumpf", "bruecke": "Brücke", "ruine": "Ruine",
	"wald": "Wald", "erz": "Erzader", "eis": "Eis", "minen": "Minen", "mauern": "Mauern"}

var _kartenbild_daten := {}   # Kartenname -> Daten (nicht jedes Bild die Datei lesen)


var _hangar: Hangar = null


## 25.11. (Paul): Hangar des Technoclan über dem Menü (hangar.gd). Solange er offen ist, ruht das Menü darunter – es liest
## Tasten nur, solange es sichtbar ist.
func _hangar_oeffnen() -> void:
	_hangar = Hangar.new()
	_hangar.geschlossen.connect(func() -> void: _klick())
	_welt.visible = false
	add_child(_hangar)


var _weg_frage := false   # 22.11.: „Meistgesuchte zurücksetzen“ – erster Klick fragt, der zweite löscht

func _meistgesuchte_weg() -> void:
	if not _weg_frage:
		_weg_frage = true
	else:
		_weg_frage = false
		Nemesis.zuruecksetzen()
		_meldung = "Die Meistgesuchten sind vergessen."
	var w := _wahl
	_baue()
	_wahl = clampi(w, 0, _eintraege.size() - 1)


func _male_kartenbild(ci: Control, kname: String) -> void:
	if not _kartenbild_daten.has(kname):
		_kartenbild_daten[kname] = Werte.karten_daten(kname)
	var k: Dictionary = _kartenbild_daten[kname]
	if k.is_empty():
		return
	var r_: Variant = k.get("regeln", {})
	var regeln: Dictionary = r_ if r_ is Dictionary else {}
	var x := KARTENBILD.position.x + 12.0
	var rechts := KARTENBILD.end.x - 12.0
	var weite := rechts - x
	var beschreibung := str(k.get("beschreibung", ""))
	var h_text := Stil.absatz_groesse(beschreibung, weite, Stil.KLEIN).y if beschreibung != "" else 0.0
	var hf := Werte.herausforderung_text(_wahl_herausforderung) if _wahl_herausforderung != "" else ""
	var h_hf := Stil.absatz_groesse(hf, weite - 12.0, Stil.KLEIN).y + 22.0 if hf != "" else 0.0
	# Gelände vorab in Zeilen legen (für die Höhe der Tafel)
	var g0 := x + Stil.breite("GELÄNDE", Stil.KLEIN) + 8.0
	var marken: Array = []   # [Art, Name, x, Zeile]
	var mx := g0
	var zeile := 0
	for art: String in GELAENDE_NAMEN:
		if (k.get(art, []) as Array).is_empty():
			continue
		var n: String = GELAENDE_NAMEN[art]
		var bw := 9.0 + Stil.breite(n, Stil.KLEIN) + 8.0
		if mx + bw > rechts + 8.0:
			mx = g0
			zeile += 1
		marken.append([art, n, mx, zeile])
		mx += bw
	var hoehe := 30.0 + h_text + 6.0 + 40.0 + 18.0 + zeile * 12.0 + 16.0 + h_hf + 8.0
	var rahmen := Rect2(KARTENBILD.position, Vector2(KARTENBILD.size.x, hoehe))
	Stil.platte(ci, rahmen, 6.0, Color(0.05, 0.06, 0.09, 0.9), Stil.RAHMEN)
	ci.draw_rect(Rect2(x, rahmen.position.y + 3.0, 60.0, 1.0), LICHT)
	var y := rahmen.position.y + 13.0
	Stil.schreibe(ci, Vector2(x, y), str(k.get("name", kname)).to_upper(), Stil.GROSS, LICHT)
	if Werte.ist_eigene_karte(kname):
		var ew := Stil.breite("EIGENE", Stil.KLEIN) + 8.0
		Stil.platte(ci, Rect2(rechts - ew, y - 6.0, ew, 12.0), 2.0, Color(KUPFER_HELL, 0.12), KUPFER_HELL)
		Stil.schreibe(ci, Vector2(rechts - ew + 4.0, y), "EIGENE", Stil.KLEIN, KUPFER_HELL)
	y += 12.0
	if beschreibung != "":
		Stil.absatz(ci, Vector2(x, y), beschreibung, weite, Stil.KLEIN, Stil.TEXT_BLASS)
		y += h_text
	y += 6.0
	# Eckdaten als Kacheln
	var kacheln := [
		["GRÖSSE", "%d×%d" % [int(k["spalten"]), int(k["zeilen"])], Stil.TEXT],
		["RUNDEN", str(int(regeln.get("runden", Werte.STANDARD_RUNDEN))), LICHT],
		["BUDGET", str(int(regeln.get("start_budget", Werte.STANDARD_BUDGET))), Stil.GOLD],
		["LEBEN", str(int(regeln.get("start_leben", Werte.STANDARD_LEBEN))), Stil.ROT]]
	var kb := (weite - 9.0) / 4.0
	for i in kacheln.size():
		var kr := Rect2(roundf(x + i * (kb + 3.0)), y, roundf(kb), 34.0)
		Stil.platte(ci, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		ci.draw_rect(Rect2(kr.position.x + 3.0, kr.position.y + 2.0, kr.size.x - 6.0, 1.0), Color(kacheln[i][2], 0.6))
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 13.0), kacheln[i][1], Stil.GROSS, kacheln[i][2])
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 26.0), kacheln[i][0], Stil.KLEIN, Stil.TEXT_BLASS)
	y += 40.0
	# Gelände: Farbmarken für alles, was auf der Karte liegt (bis zwei Zeilen)
	Stil.schreibe(ci, Vector2(x, y + 4.0), "GELÄNDE", Stil.KLEIN, Stil.TEXT_BLASS)
	for m: Array in marken:
		var my := y + 4.0 + int(m[3]) * 12.0
		ci.draw_rect(Rect2(float(m[2]), my - 3.0, 6.0, 6.0), BILD_FARBEN[m[0]])
		ci.draw_rect(Rect2(float(m[2]), my - 3.0, 6.0, 6.0), Color(0, 0, 0, 0.5), false, 1.0)
		Stil.schreibe(ci, Vector2(float(m[2]) + 9.0, my), str(m[1]), Stil.KLEIN, Stil.TEXT)
	if marken.is_empty():
		Stil.schreibe(ci, Vector2(g0, y + 4.0), "freies Feld", Stil.KLEIN, Stil.TEXT)
	y += 18.0 + zeile * 12.0
	# Regeln als Zeile
	var ziel := str(regeln.get("ziel", "gegenangriff"))
	var teile: Array[String] = []
	if ziel != "gegenangriff":
		teile.append("Ziel: " + Werte.ziel_name(ziel))
	teile.append("Basis fest" if bool(k.get("basis_fest", false)) else "Basis zufällig")
	teile.append("Checkpoints fest" if bool(k.get("checkpoints_fest", false)) else "Checkpoints gewürfelt")
	Stil.schreibe(ci, Vector2(x, y), " · ".join(teile), Stil.KLEIN, Stil.TEXT_BLASS)
	y += 12.0
	# Gewählte Herausforderung als kupferner Kasten
	if hf != "":
		var hr := Rect2(x, y, weite, h_hf - 4.0)
		Stil.platte(ci, hr, 3.0, Color(KUPFER_HELL, 0.08), Color(KUPFER_HELL, 0.7))
		Stil.schreibe(ci, Vector2(x + 6.0, y + 8.0), Werte.herausforderung_name(_wahl_herausforderung).to_upper(), Stil.KLEIN, KUPFER_HELL)
		Stil.absatz(ci, Vector2(x + 6.0, y + 14.0), hf, weite - 12.0, Stil.KLEIN, Stil.TEXT)


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


# ------------------------------------------------------------------ Profil: Brakk-Mode (19.11.)

## 19.11. (Paul): Abschnitt „Brakk-Mode“ im Profil – Siege, höchste Stufe, Lieblingsring, häufigster Titel und die
## Übersicht des letzten Siegs zum Nachschauen (BrakkSieg.male_bericht).
var _profil_brakk := false
var _profil_af := "brakk"        # 20.11.: welcher Anführer im Abschnitt Brakk-Mode gezeigt wird


## 19.11.: Statistik ↔ Brakk-Mode; 20.11.: im Brakk-Mode blättert derselbe Eintrag durch die Anführer (Brakk → Irrtürmer →
## Sonde 7) und danach zurück zur Statistik – so bleibt die Liste bei drei Einträgen.
func _profil_brakk_umschalten() -> void:
	var ids: Array = Werte.ANFUEHRER_EGO.keys()
	if not _profil_brakk:
		_profil_brakk = true
		_profil_af = str(ids[0])
	else:
		var i := ids.find(_profil_af) + 1
		if i >= ids.size():
			_profil_brakk = false
		else:
			_profil_af = str(ids[i])
	_zeige("profil")


func _profil_brakk_text() -> String:
	if not _profil_brakk:
		return "Siege, Ringe, Titel und der letzte Sieg"
	var ids: Array = Werte.ANFUEHRER_EGO.keys()
	var i := ids.find(_profil_af) + 1
	return "weiter: " + Anfuehrer.name(str(ids[i])) if i < ids.size() else "zurück zur Statistik"


func _male_profil_brakk(ci: Control) -> void:
	var r := Rect2(LISTE_X - 6.0, 204, 624.0 - (LISTE_X - 6.0), 138)
	Stil.platte(ci, Rect2(TAFEL.position, Vector2(TAFEL.size.x, 128)), 4.0, Color(0.05, 0.06, 0.09, 0.88), Stil.RAHMEN)
	var s := Profil.ego_s(_profil_af)   # 20.11.: je Anführer getrennt (Brakk: die alten Schlüssel)
	var x := TAFEL.position.x + 12.0
	var y := TAFEL.position.y + 14.0
	Stil.schreibe(ci, Vector2(x, y), "BRAKK-MODE · " + Anfuehrer.name(_profil_af).to_upper(), Stil.NORMAL, Stil.GOLD)
	var ring := Profil.brakk_meist("brakk_ringe" + s)
	var titel := Profil.brakk_meist("brakk_titel" + s)
	var werte := [
		["SIEGE", str(Profil.stat("brakk_siege" + s)), Stil.GOLD],
		["HÖCHSTE STUFE", str(Profil.stat("brakk_stufe" + s)) if Profil.stat("brakk_stufe" + s) > 0 else "–", LICHT],
		["LIEBLINGSRING", str(BrakkFortschritt.RINGE.get(ring[0], {}).get("name", "–")).trim_suffix("ring") if not ring.is_empty() else "–", Stil.TEXT],
		["HÄUFIGSTER TITEL", str(titel[0]) if not titel.is_empty() else "–", Stil.TEXT]]
	var kb := (TAFEL.size.x - 24.0 - 4.0) / 2.0
	for i in werte.size():
		var kr := Rect2(roundf(x + (i % 2) * (kb + 4.0)), y + 10.0 + (i / 2) * 38.0, roundf(kb), 34.0)
		Stil.platte(ci, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 13.0), werte[i][1], Stil.GROSS if str(werte[i][1]).length() < 7 else Stil.NORMAL, werte[i][2])
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 26.0), werte[i][0], Stil.KLEIN, Stil.TEXT_BLASS)
	# letzter Sieg
	Stil.platte(ci, r, 4.0, Color(0.05, 0.06, 0.09, 0.88), Stil.RAHMEN)
	var b: Dictionary = Profil.einstellung("brakk_letzter_sieg" + s, {})
	Stil.schreibe(ci, r.position + Vector2(12, 12), "LETZTER SIEG" + (" · " + str(b.get("datum", "")) if not b.is_empty() else ""), Stil.KLEIN, Stil.LEUCHT)
	BrakkSieg.male_bericht(ci, Rect2(r.position + Vector2(12, 18), r.size - Vector2(24, 22)), b, true)
