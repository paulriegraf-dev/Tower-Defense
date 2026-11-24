extends Node2D
## Spielablauf: Bauphase -> Welle -> Bauphase ... sowie Eingabe und Anzeige.

enum Phase { BAU, KAMPF, ENDE }

var phase := Phase.BAU
var werkzeug: int = Karte.FREI      # Karte.FREI = nichts gewählt, sonst WALL / FABRIK / STELLUNG / TURM
var budget: int = Werte.START_BUDGET
var leben: int = Werte.START_LEBEN
var welle: int = 1
var sandbox := false                # Übergangsmenü: 5000 Budget, alle Bauwerke ab Runde 1
var _menue: Startmenue
var tutorial: Tutorial = null       # läuft gerade das Tutorial (Sonde 7)? Fragt beim Start des normalen Spiels
var phantom_modus := ""             # "" = normales Spiel, "angriff" = du greifst den Bau eines Phantoms an, "verteidigung" = du spielst gegen die Wellen eines Phantoms
var _angriff_phantom: Dictionary = {}   # Verteidigung: die 20 Wellen eines anderen Spielers
var _phantom: Dictionary = {}       # das geladene Verteidigungs-Phantom
var _plaene: Dictionary = {}        # Angriff: Runde -> Trupps im Format von Werte.WELLEN
var _angriff_log: Array = []        # Angriff: je Runde, was der Plan gekostet und gebracht hat
var _laufband: Laufband
var nebel: Laufband.Nebel           # Kriegsnebel des Angreifers (nur im Phantom-Modus „Angreifer“)
var _durchgang_sek := 0.0           # Kampfzeit, zu der der laufende Durchgang der Welle begann (für Würfe auf feste Sekunden)
var _phantom_pfad := ""             # Angriff: Datei des Phantoms, gegen das es gerade geht
var _ersatz: Array = []             # Angriff: Dateien weiterer Phantome, die übernehmen, wenn die Verteidigung fällt
var _geknackt := 0                  # Angriff: so viele Verteidigungen sind schon gefallen
var _aktiv_pfad := ""               # Angriff: Datei der Verteidigung, die gerade steht (auch ein Ersatz-Phantom)
var _profil_kills: Dictionary = {}  # Profil (18.11.): wer in dieser Partie wie viele Gegner besiegt hat
var _angriff_pfad := ""             # Verteidigung: Datei des Angriffs-Phantoms, gegen das es geht
var _wurfziel_fuer: Dictionary = {} # Angriff: dieser Wurf-Trupp wartet auf den Klick für sein Landefeld
var _ende_knoepfe: HBoxContainer
var _btn_menue: Button              # oben rechts: Partie abbrechen und zurück ins Hauptmenü (zweiter Klick bestätigt)
var _abbruch_ms := -100000
var _bezahlt: Dictionary = {}       # Feld -> was in dieser Bauphase dort bezahlt wurde: {"bau", "ausbau", "stufen", "stufen_n"} (wird beim Abreißen voll erstattet)
var _abriss_merk := Karte.KEINE     # teures Bauwerk, das auf den zweiten Rechtsklick wartet
var _abriss_ms := 0
const ABRISS_FRIST_MS: int = 4000   # so lange gilt der erste Rechtsklick auf Fabrik, Batterie oder Turm
const BAU_STAPEL_MAX := 5           # 22.11.: Brakk-Mode – so viele Bauschritte der Bauphase lassen sich mit [Z] zurücknehmen
var _bau_stapel: Array = []         # 22.11.: [{"z": Feld, "typ": Bautyp}], jüngster zuletzt; wird am Wellenstart geleert
var _export_knoepfe: HBoxContainer
var _export_hinweis: Label
var _export_text := ""              # Schlussbild: die Datei, die sich herunterladen / kopieren lässt (Partie oder Phantom)
var _export_name := ""
var _bestaetigung: Control
static var naechster_start := ""    # überlebt den Neustart der Szene: "normal", "liste" oder "angriff:<Datei>"
var sandbox_gegner: Dictionary = {} # Sandbox: Typ -> Anzahl in der nächsten Welle (leer = Welle wie im Spiel)
var sandbox_truppen := 0            # Sandbox: so viele Truppen je Fabrik mehr (oder weniger)
var schilde: Dictionary = {}        # Batterie-Zelle -> {"a": Erdwall, "e": Erdwall, "felder": [Felder dazwischen], "leben": Rest, "max": volle Stärke}
var _schild_fuer := Karte.KEINE     # diese Batterie wartet darauf, dass ihr Schild gezogen wird
var _schild_start := Karte.KEINE    # erster Erdwall beim Ziehen des Schilds
var _rauch_abkling: Dictionary = {}

var karte: Karte
var effekte: Effekte
var figuren: Node2D
var turmbilder := {}               # neue Grafik: Turm-Zelle -> TurmBild (y-sortiert zwischen den Figuren)
var hd: HdAnsicht = null           # HD-2D-Ansicht (Grafik „HD-2D“)
var ego: EgoModus = null           # 18.11.: Ego-Sicht mit Brakk [G] (Prototyp)
var brakk_modus := false            # 18.11.: Brakk-Mode – Extra-Modus aus dem Startmenü: Ego-Sicht mit Brakk ab Runde 1
const BRAKK_GEGNER_MAL := 1.98         # 18.11. (Paul): Brakk-Mode – so viele Gegner wie sonst mal … (19.11.: 10 % weniger, vorher 2,2)
const BRAKK_LEBEN_JE_RUNDE := 0.06      # … und je Runde zusätzlich so viel mehr Leben
const BRAKK_ABSTAND_MAL := 0.5             # 18.11. (Paul): Gegner eines Trupps starten dichter …
const BRAKK_PAUSE_MAL := 0.6               # … und zwischen zwei Trupps vergeht weniger Zeit
const BRAKK_FABRIK_PROZENT := 10.0         # 18.11. (Paul): Brakk-Mode – jede weitere Fabrik nur 10 % teurer (sonst 25 %), für mehrere Ring-Standorte
const BRAKK_STUFE1_LEBEN := 1.2           # 19.11. (Paul): Brakk-Mode – Truppen ab Fabrik-Stufe 1 mit +20 % Leben (statt dritter Truppe)
const BRAKK_GEL_FELD_SCHADEN := 0.75      # 19.11. (Paul): Truppen im Gel-Feld machen 25 % weniger Schaden
var _brakk_praemie := 0.0                # Bruchteile der gedrittelten Prämie
var szenario_editor: SzenarioEditor = null   # 18.11.: Szenario-Editor (Startmenü → Sandbox → Szenario bauen)
var order24: Order24 = null   # 20.11. (Schritt 5b): Brakk-Mode „Rogue“ – Order 24 (scripts/order24.gd)
var brakk_geschosse: BrakkGeschosse = null   # 20.11. (Schritt 6c): Brakk-Mode – Schüsse auf Brakk als echte Geschosse (setzt die Ego-Sicht)
var gegner: Array[Gegner] = []
var einheiten: Array[Einheit] = []
var ausgang := ""                 # 9b: "sieg" oder "niederlage", sobald die Partie zu Ende ist (Labor, Replay, Tests)
var endkampf := false               # letzte Runde: Gegner ohne Ende, Sieg durch Zerstören des HQ
var zonenbauten: Array[Zonenbau] = []   # HQ und Schleudern in der Zone des Gegners
var hq: Zonenbau
var fabriken: Dictionary = {}       # Zelle -> {"timer": float, "einheiten": Array, "typ": String}

var _welle: Dictionary = {}
var _schlange: Array = []           # Trupps, die in dieser Welle noch kommen (je eine Liste von Gegnertypen)
var _trupp: Array = []              # Mitglieder des Trupps, der gerade herauskommt
var _start_zelle := Werte.START_ZELLE   # Startfeld der laufenden Welle
var _erstes_ziel := 0               # erstes Routenziel der laufenden Welle
var _gefahr_je: Dictionary = {}     # Radius -> Felder nahe an Gegnern (Zwischenspeicher für einen Frame)
var _gefahr_stand := -1
var _zins_felder: Array[ColorRect] = []
var _lbl_zins: Label
var _lbl_zins_titel: Label
var _wurf_schlange: Array = []      # Würfe dieser Welle: {"typen", "nach", "wenn"}
var _pausen: Array = []             # zu _schlange: Sekunden mehr/weniger Pause vor dem Trupp
var _ausgaenge: Array = []          # zu _schlange: Ausgang je Trupp (nur Phantom-Modus)
var _locker: Array = []             # zu _schlange: lockere Formation je Trupp (17.11.)
var _trupp_nr := 0                  # so viele Lauf-Trupps dieses Durchgangs sind schon unterwegs
var _durchgang := 0                 # letzte Runde: der wievielte Durchgang der Welle
var _wurf_nahe := Vector2.INF       # der nächste Wurf landet hier in der Nähe (Zange am Belagerungsturm)
var _abgesetzt: Dictionary = {}     # Belagerungsturm -> so viele Myr-Drohnen hat er schon abgesetzt
var _wurf_aktiv: Array = []         # der Trupp, der gerade fliegt (Rest)
var _wurf_takt := 0.0
var _wurf_bau: Zonenbau
var _wurf_landung := Karte.KEINE
var _wurf_ziel := 0
var _wurf_trupp: Array = []
var _wurf_sofort := false           # ein Belagerungsturm hat angedockt: der nächste Wurf fliegt sofort ...
var _wurf_meiden := Vector2.INF     # ... und weit weg von ihm
var variante := 0                   # ab Werte.WELLEN_VARIANTEN_AB: welche der zwei Wellen-Varianten kommt
# Bauprotokoll: was in welcher Runde gebaut wurde und wie die Runde ausging (für das Nachspielen und Auswerten)
var protokoll_an := true
var _protokoll: Dictionary = {}
var _protokoll_datei := ""
var _kampf_tick := 0                # 9a: Bilder (feste Schrittweite) seit Wellenstart; Eingaben mitten in der Welle tragen ihn im Protokoll
var _runde_start_ms := 0
var _leben_vor_runde := 0
var _cp_verloren := 0
var _spielzeit := 0.0                # läuft nur im Kampf (für Feuerteam und Brandfelder)
var _lexikon: Lexikon                # Übersicht über Gegner, Truppen und Bauten [I]
var _nachschlag: Nachschlag          # Nachschlagekarte mit Formationen [H]
var _fabrikmenue: Fabrikmenue        # Tafel an der angeklickten Fabrik: Truppe wählen, Upgrades kaufen
var _nachspiel := 0.0               # Sekunden, die nach dem letzten Gegner noch für die Rückeroberung liefen
var _kampf_sek := 0.0               # Spielzeit seit Rundenbeginn
var weg_info: Array = [0, 0, 0]      # 23.11.: zuletzt angezeigter Gegnerweg [Felder, Umweg, unter Beschuss]
var _im_flug := 0                   # geworfene Hunde, die noch in der Luft sind
var _tempo_faktor := 1.0            # 1, 2 oder 3 (Taste F schaltet weiter), wird mit Werte.SPIELTEMPO multipliziert
var _spawn_in := 0.0
var _turm_abkling: Dictionary = {}  # Turm-Zelle -> Sekunden bis zum nächsten Schuss
var turm_ueberladen: Dictionary = {}  # 20.11.: Brakk-Mode, Irrtürmer – Turm-Zelle -> [Ende (ms), Faktor]: feuert so lange schneller
var _funk_welle: Dictionary = {}    # Funkturm -> Sekunden bis zur nächsten Funkwelle (nur Optik)
var _turm_schock: Dictionary = {}    # Frost mit Schockfrost: Turm-Zelle -> Sekunden bis zum nächsten Einfrieren
var _turm_nachschuss: Dictionary = {}   # Lanze mit Doppelstrahl: Turm-Zelle -> [Sekunden, Strahlende]
var _lazarett_genutzt: Dictionary = {}  # Heilturm mit Feldlazarett: schon in dieser Runde jemanden gerettet
var _instand_zeit: Dictionary = {}      # lahmgelegter Turm -> Sekunden unter einem Heilturm mit Instandsetzung
var _meldung := ""
var _meldung_zeit := 0.0

var _lbl_status: Label
var _lbl_vorschau: Label
var _lbl_hinweis: Label
var _hinweis_grund: ColorRect
var _knoepfe: Dictionary = {}       # Werkzeug -> Button
var _btn_start: Button
var _btn_tempo: Button
var _neu_grund: ColorRect           # Ansage "Neu in dieser Runde"
var _lbl_neu: Label
var _hud: CanvasLayer                # neue Oberfläche (scripts/ui/hud.gd, 16.11.): Inseln und Konsole
var _auswahl: Einheit               # angeklickte Einheit (zeigt ihre Reichweite)
var _ende: Control
var _ende_text: Label
var _tafel: EndTafel   # 18.11.: Sieg, Niederlage, Phantom-Ende (scripts/ui/end_tafel.gd)
var _einblendung: Einblendung   # 18.11.: Rundenabrechnung und Banner (scripts/ui/einblendung.gd)
var _meldung_art := ""   # 18.11.: "geld", "ereignis" oder "" – färbt die Meldung im HUD
var _durch_typen: Dictionary = {}   # 18.11.: welche Gegnertypen in dieser Partie die Basis erreicht haben (Niederlage-Tafel)


func _ready() -> void:
	Zufall.neue_partie()   # 9a: Samen der Partie, bevor Karte und Checkpoints gewuerfelt werden
	Gegner._einschuss.clear()   # 9a: statisch – sonst zählen Treffer der vorigen Partie in dieser mit
	herausforderung = Werte.herausforderung   # 18.11.: vom Startmenü (überlebt den Neustart der Szene)
	if Touch.noetig():
		add_child(Touch.new())   # 17.11.: Handy/Tablet – lange drücken = Rechtsklick, zwei Finger = Zoom, Hinweis bei Hochkant
	Ladebild.fertig.call_deferred()   # 17.11.: läuft gerade ein Ladebild, darf es jetzt voll laufen und ausblenden
	Werte.lade_einstellungen()
	if naechster_start == "editor":
		SzenarioEditor.uebernimm()   # 18.11.: der Entwurf ist die Karte – vor dem Aufbau der Karte
	budget = Werte.START_BUDGET   # 18.11.: erst jetzt steht die Karte fest (Regelpaket eines Szenarios)
	leben = Werte.START_LEBEN
	# Vollbild wie eingestellt (Standard an; das Projekt startet schon im Vollbild)
	var ist_voll := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if Werte.vollbild != ist_voll and not OS.has_feature("web"):   # 21.11.: Web – nie beim Laden (werte.gd)
		Werte.setze_vollbild(Werte.vollbild)
	_start_zelle = Werte.START_ZELLE   # Kartengröße steht erst jetzt fest
	karte = Karte.new()
	add_child(karte)
	var schatten := Schatten.new()
	schatten.spiel = self
	karte.add_child(schatten)
	karte.zerstoert.connect(_bei_zerstoert)
	karte.ausgefallen_ist.connect(_bei_ausfall)
	figuren = Node2D.new()
	figuren.y_sort_enabled = true
	add_child(figuren)
	effekte = Effekte.new()
	add_child(effekte)
	var marken := Laufband.Marken.new()
	marken.spiel = self
	add_child(marken)
	nebel = Laufband.Nebel.new()
	nebel.spiel = self
	add_child(nebel)   # über Karte, Figuren und Effekten
	Engine.time_scale = Werte.SPIELTEMPO
	_aktualisiere_zone()
	karte.cp_aktiv = Werte.plan_runde(welle) >= Werte.CHECKPOINTS_AB_WELLE
	karte.zeige_schwachstelle = Werte.plan_runde(welle) >= Werte.SPRENGER_AB_WELLE
	setze_kartenmauern()   # 18.11.: vorgebaute Erdwälle der Karte (aktualisiert auch den Weg)
	_beginne_protokoll()
	_baue_hud()
	var start := naechster_start
	naechster_start = ""
	if start == "normal":
		_spiel_nach_regeln()   # Neustart vom Schlussbild: gleich ins normale Spiel, ohne Menü (20.11.: oder Brakk-Mode laut Karte)
	elif start == "sandbox":
		_menue_gewaehlt(true)   # aus dem Startmenü, nach dem Wechsel der Kartengröße
	elif start == "tutorial":
		_tutorial_gewaehlt()
	elif start == "brakk":
		_brakk_modus_gewaehlt()   # 18.11.
	elif start == "fortsetzen":
		_lade_zwischenstand()   # 18.11.
	elif start == "editor":
		szenario_editor = SzenarioEditor.new()   # 18.11.
		add_child(szenario_editor)
		szenario_editor.einrichten(self)
	elif start.begins_with("verteidigt:"):
		starte_phantom_verteidigung(start.trim_prefix("verteidigt:"))
	elif start.begins_with("angriff:"):
		starte_phantom_angriff(start.trim_prefix("angriff:"))
	elif DisplayServer.get_name() != "headless" and OS.get_environment("TD_OHNE_MENUE") == "":
		_menue = Startmenue.new()
		_menue.spiel = self
		add_child(_menue)
		_menue.gewaehlt.connect(_menue_gewaehlt)
		_menue.phantom_gewaehlt.connect(_phantom_gewaehlt)
		_menue.tutorial_gewaehlt.connect(_tutorial_gewaehlt)
		_menue.brakk_gewaehlt.connect(_brakk_modus_gewaehlt)
		_menue.uebersicht_gewaehlt.connect(func(): _lexikon.visible = true)
		Musik.spiele(get_tree(), "menue")
		if start == "liste":
			_menue.zeige_phantome("verteidigung")
	if _menue == null:
		Musik.spiele(get_tree(), "ingame")
	if start == "" and _menue == null and OS.get_environment("TD_PHANTOM") != "":
		starte_phantom_angriff(OS.get_environment("TD_PHANTOM"))   # für Testläufe ohne Menü
	elif start == "" and _menue == null and OS.get_environment("TD_PHANTOM_V") != "":
		starte_phantom_verteidigung(OS.get_environment("TD_PHANTOM_V"))


func _menue_weg() -> void:
	Musik.spiele(get_tree(), "ingame")
	if _menue != null:
		_menue.queue_free()
		_menue = null


func _menue_gewaehlt(mit_sandbox: bool) -> void:
	sandbox = mit_sandbox
	if sandbox:
		_setze_anfuehrer("brakk")   # 19.11.: Sandbox mit Brakk
		budget = 999999
		_protokoll["sandbox"] = true
		sandbox_cp_route(true)
		melde("Sandbox: unendlich Budget, alle Bauwerke freigeschaltet.", 5.0)
	else:
		_spiel_nach_regeln()   # 16.11.: das Tutorial hat im Basislager ein eigenes Gebäude (Übungsplatz); 20.11.: Modus laut Karte
	_menue_weg()


## Übungsplatz im Basislager: normales Spiel, Sonde 7 erklärt gleich Schritt für Schritt.
func _tutorial_gewaehlt() -> void:
	Werte.setze_anfuehrer("brakk")   # 19.11.: das Tutorial läuft immer mit Brakk
	_normales_spiel()
	tutorial = Tutorial.new()
	tutorial.spiel = self
	add_child(tutorial)
	tutorial._starte()
	_menue_weg()


## Normales Spiel (auch gegen ein Angriffs-Phantom): Die Basis steht jede Partie woanders.
func _normales_spiel() -> void:
	_setze_anfuehrer(Werte.anfuehrer)   # 19.11.: vom Startmenü gewählt (oder vom Szenario vorgegeben)
	_kartenbauten_einrichten()      # 18.11.: vorgebaute Türme/Fabriken eines Szenarios
	_herausforderung_einrichten()   # 18.11.: vor der Basis – die fertige Mauer steht zuerst
	if herausforderung == "mauern_fest":
		setze_basis(Werte.BASIS_ZELLE)   # 18.11.: am Ende des Labyrinths, damit die Gegner die ganze Mauer ablaufen
	elif Werte.BASIS_ZUFALL and not Werte.KARTE_BASIS_FEST:
		stelle_basis("ueberall")
	_alarmstart_einrichten()   # 20.11. (Schritt 5b): Formation aus [H] mit Fabriken und Stellungen, angesprengt
	_startlage_einrichten()   # 20.11.
	_zeige_einfuehrung()
	_starte_bauzeit()   # 18.11.: auch schon in Runde 1
	if bool(Werte.KARTE_REGELN.get("sofort", false)) and phantom_modus == "":
		starte_welle.call_deferred(true)   # 20.11.: Alarmstart – die erste Welle läuft gleich
		_trupp_unterwegs.call_deferred()   # 20.11. (Schritt 5b): ein Trupp ist schon mitten auf dem Weg


## 20.11. (Schritt 5): Normales Spiel oder – wenn das Regelpaket der Karte es sagt – der Brakk-Mode (Ego-Sicht).
func _spiel_nach_regeln() -> void:
	if Werte.modus() == "rogue":
		_order24_gewaehlt()   # 20.11. (Schritt 5b)
	elif Werte.modus() == "brakk":
		_brakk_modus_gewaehlt()
	else:
		_normales_spiel()


## 20.11. (Schritt 5): Startlage aus dem Regelpaket – beschädigte Mauer der Karte, Checkpoints schon beim Gegner.
func _startlage_einrichten() -> void:
	var anteil := clampf(float(Werte.KARTE_REGELN.get("mauer_leben", 100)) / 100.0, 0.05, 1.0)
	if anteil < 1.0:
		for z: Vector2i in Werte.MAUERN:
			if karte.inhalt(z) == Karte.WALL:
				karte.leben[z] = karte.max_leben(Karte.WALL) * anteil
	if bool(Werte.KARTE_REGELN.get("cp_feind", false)) and not karte.checkpoints.is_empty():
		karte.cp_aktiv = true
		for i in karte.cp_feind.size():
			karte.cp_feind[i] = true
		karte.aktualisiere_pfad()
		karte.queue_redraw()


## 20.11. (Schritt 5b, Alarmstart): Regelpaket "formation" ("" = Zufall unter Werte.ALARM_FORMATIONEN, sonst der Name aus [H]).
## Die Formation wird auf die Karte gelegt (Checkpoints und Basis wie im Plan), dazu "alarm_fabriken" Fabriken (Stufe 1,
## reihum spezialisiert) und "alarm_stellungen" Stellungen auf den Wallfeldern mit der größten Wegabdeckung. Danach sind
## "gesprengt" Erdwälle weg. Alles gehört zur Karte (nicht abreißbar). Nur auf Karten mit 28×14 (Größe der Pläne).
var alarm_formation := ""   # welche Formation liegt (für Anzeige und Prüfung)

func _alarmstart_einrichten() -> void:
	var r: Dictionary = Werte.KARTE_REGELN
	if not r.has("formation") or Werte.SPALTEN != Nachschlag.SP or Werte.ZEILEN != Nachschlag.ZE or phantom_modus != "":
		return
	var name := str(r["formation"])
	if not Nachschlag.PLAENE_GROSS.has(name):
		name = Zufall.waehle(Werte.ALARM_FORMATIONEN)
	alarm_formation = name
	formation_aufbauen(name, clampi(int(r.get("alarm_fabriken", 6)), 0, 12), clampi(int(r.get("alarm_stellungen", 4)), 0, 12), clampi(int(r.get("gesprengt", 6)), 0, 40))


## 20.11. (Schritt 5b): Formation `name` aus [H] (28×14) mit ihren Checkpoints hinstellen, dazu `anzahl` Fabriken (Stufe 1,
## reihum spezialisiert), `soll` Stellungen mit der größten Wegabdeckung und `weg_damit` gesprengte Erdwälle. Alles gehört
## zur Karte. Alarmstart und Order 24. Gibt die Stellungen zurück.
func formation_aufbauen(name: String, anzahl: int, soll: int, weg_damit: int) -> Array[Vector2i]:
	var plan: Array = (Nachschlag.PLAENE_GROSS[name] as Array).duplicate()
	if Zufall.ganz(2) == 1:
		plan.reverse()   # mal oben, mal unten gespiegelt
	var waelle: Array = []
	var fabrik_felder: Array[Vector2i] = []
	var cps: Array = [Karte.KEINE, Karte.KEINE]
	for y in plan.size():
		var zeile := str(plan[y])
		for x in zeile.length():
			var c := zeile[x]
			var z := Vector2i(x, y)
			if c in ["#", "S", "T", "O"] and karte.ist_bebaubar(z):
				waelle.append([x, y, "tor" if c == "O" else ""])
			elif c == "F" and karte.ist_bebaubar(z):
				fabrik_felder.append(z)
			elif c == "1" or c == "2":
				cps[int(c) - 1] = z
	if cps[0] != Karte.KEINE and cps[1] != Karte.KEINE:
		setze_checkpoints(cps)
	# Fabriken: erst die Felder des Plans, dann freie Felder nah an der Basis
	var belegt := {}
	for w: Array in waelle:
		belegt[Vector2i(int(w[0]), int(w[1]))] = true
	if fabrik_felder.size() < anzahl:
		var frei: Array[Vector2i] = []
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN + 4, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if karte.ist_bebaubar(z) and not belegt.has(z) and not fabrik_felder.has(z) and not karte.ist_basis(z) and absi(y - karte.basis.y) > 1:
					frei.append(z)
		frei.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(karte.basis) < b.distance_squared_to(karte.basis))
		for z: Vector2i in frei:
			if fabrik_felder.size() >= anzahl:
				break
			var nah := false
			for f: Vector2i in fabrik_felder:
				if absi(f.x - z.x) <= 1 and absi(f.y - z.y) <= 1:
					nah = true
			if not nah:
				fabrik_felder.append(z)
	var fabriken_liste: Array = []
	for i in mini(anzahl, fabrik_felder.size()):
		fabriken_liste.append({"x": fabrik_felder[i].x, "y": fabrik_felder[i].y, "einheit": Werte.ALARM_TRUPPEN[i % Werte.ALARM_TRUPPEN.size()], "stufe": 1})
	_setze_stand({"waelle": waelle, "fabriken": fabriken_liste, "batterien": []})
	# Stellungen: Wallfelder, von denen aus die meisten Wegfelder in Reichweite liegen (mindestens 3 Felder auseinander)
	var weg := {}
	for z: Vector2i in karte.pfad:
		weg[z] = true
	for neben: Array in karte.neben_pfade:
		for z: Vector2i in neben:
			weg[z] = true
	var kandidaten: Array = []
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.WALL or karte.ausbau.has(z):
			continue
		var n := 0
		for w: Vector2i in weg:
			if Vector2(w - z).length() <= Werte.STELLUNG_ABDECKUNG:
				n += 1
		kandidaten.append([n, z])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var stellungen: Array[Vector2i] = []
	for k: Array in kandidaten:
		if stellungen.size() >= soll:
			break
		var z: Vector2i = k[1]
		var zu_nah := false
		for s: Vector2i in stellungen:
			if Vector2(s - z).length() < 3.0:
				zu_nah = true
		if not zu_nah:
			stellungen.append(z)
			karte.baue_aus(z, Karte.STELLUNG)
	# Gesprengt: blanke Erdwälle (keine Stellung, kein Tor, keine Turmstütze), bevorzugt am Gegnerweg
	var blank: Array = []
	for z: Vector2i in karte.feld:
		if karte.feld[z] == Karte.WALL and not karte.ausbau.has(z) and not karte.stuetze_von.has(z):
			var am_weg := 0
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if weg.has(z + d):
					am_weg = 1
			blank.append([am_weg * 10 + Zufall.ganz(10), z])
	blank.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in mini(weg_damit, blank.size()):
		karte.entferne(blank[i][1] as Vector2i)
	for z: Vector2i in karte.feld:
		karte.fest[z] = true   # gehört zur Karte: ausbaubar, nicht abreißbar
	karte.aktualisiere_pfad()
	karte.queue_redraw()
	print("FORMATION %s · %d Erdwälle · %d Fabriken · Stellungen %s · %d gesprengt" % [name, waelle.size(), fabriken_liste.size(), str(stellungen), mini(weg_damit, blank.size())])
	return stellungen


## 20.11. (Schritt 5b, Alarmstart): Regelpaket "trupp_unterwegs" (Typen) – dieser Trupp steht beim Start schon auf einem
## Drittel des Gegnerwegs und läuft los, sobald die erste Welle beginnt.
func _trupp_unterwegs() -> void:
	var typen: Variant = Werte.KARTE_REGELN.get("trupp_unterwegs", [])
	if not (typen is Array) or (typen as Array).is_empty() or phase != Phase.KAMPF or karte.pfad.size() < 6:
		return
	var i := int(karte.pfad.size() * 0.3)
	var zelle: Vector2i = karte.pfad[i]
	var ziel := karte.erstes_ziel()
	for k in range(ziel, karte.checkpoints.size()):
		var j := karte.pfad.find(karte.checkpoints[k])
		if j >= 0 and j < i:
			ziel = k + 1   # Checkpoints, die schon hinter ihm liegen, läuft er nicht mehr an
	var trupp: Array = []
	for typ: Variant in (typen as Array):
		if not Werte.GEGNER.has(str(typ)):
			continue
		var g := _neuer_gegner(str(typ), zelle, ziel)
		g.trupp = trupp
		trupp.append(g)
	if Werte.ZONE2.size != Vector2i.ZERO:
		for g: Gegner in trupp:
			_zange_route(g)
	melde("Ein Trupp ist schon durch die Linien – er steht mitten auf dem Weg!", 6.0)


## 18.11.: Szenario mit vorgebauten Türmen/Fabriken (Werte.KARTE_STAND): hinstellen, nicht abreißbar (sonst gäbe der
## Abriss Geld für etwas, das nie bezahlt wurde). Liegt ein zufälliger Checkpoint darauf, wird er neu gewürfelt.
func _kartenbauten_einrichten() -> void:
	if Werte.KARTE_STAND.is_empty():
		return
	_setze_stand(Werte.KARTE_STAND)
	setze_kartenmauern()
	_markiere_kartenbauten()
	for cp: Vector2i in karte.checkpoints:
		if karte.feld.has(cp):
			setze_checkpoints(karte._zufalls_checkpoints())
			break


## Alle Felder, die das Szenario vorgebaut hat, als „gehört zur Karte“ markieren (auch nach „Fortsetzen“).
func _markiere_kartenbauten() -> void:
	var st: Dictionary = Werte.KARTE_STAND
	var felder: Array[Vector2i] = []
	for w: Array in st.get("waelle", []):
		felder.append(Vector2i(int(w[0]), int(w[1])))
	for f: Dictionary in st.get("fabriken", []):
		felder.append(Vector2i(int(f["x"]), int(f["y"])))
	for b: Dictionary in st.get("batterien", []):
		felder.append(Vector2i(int(b["x"]), int(b["y"])))
		felder.append(Vector2i(int(b["px"]), int(b["py"])))
	for z: Vector2i in felder:
		if karte.inhalt(z) != Karte.FREI:
			karte.fest[z] = true


## 18.11.: Einführungstext eines Szenarios zu Spielbeginn (Fenster mit „Los“).
func _zeige_einfuehrung() -> void:
	var text := str(Werte.KARTE_REGELN.get("einfuehrung", "")).strip_edges()
	if text == "" or DisplayServer.get_name() == "headless":
		return
	if brakk_modus:
		melde("%s: %s" % [Werte.KARTE_TITEL, text], 10.0)   # 20.11.: im Brakk-Mode kein zweites Fenster über der Einsatz-Tafel
		return
	add_child(ModLeiste.Tafel.new(Werte.KARTE_TITEL, text, [["Los geht's", Callable()]]))


## 18.11.: Vorgebaute Erdwälle der Karte hinstellen (ausbaubar, nicht abreißbar). `felder` leer = die der Karte.
func setze_kartenmauern(felder: Array[Vector2i] = Werte.MAUERN, nicht_unter_brakk: bool = false) -> void:
	var brakk_feld: Vector2i = karte.zelle_bei(kommandant.position) if nicht_unter_brakk and kommandant != null else Karte.KEINE
	for z: Vector2i in felder:
		if karte.ist_frei(z) and not karte.ist_basis(z) and not karte.checkpoints.has(z) and z != brakk_feld:
			karte.setze(z, Karte.WALL)
		if karte.inhalt(z) == Karte.WALL:
			karte.fest[z] = true
	karte.aktualisiere_pfad()


# ------------------------------------------------------------ Phantom-Modus

func _phantom_gewaehlt(art: String, pfad: String) -> void:
	_menue_weg()
	if art == "verteidigung":
		starte_phantom_angriff(pfad)
	else:
		starte_phantom_verteidigung(pfad)


## Normales Spiel, aber die Wellen kommen von einem Angriffs-Phantom (alle Runden aus einer Hand).
## Runden, für die das Phantom keinen Plan hat, laufen mit der entworfenen Welle.
func starte_phantom_verteidigung(pfad: String) -> bool:
	_angriff_phantom = Phantom.lade(pfad)
	if _angriff_phantom.is_empty():
		melde("Dieses Phantom lässt sich nicht laden.", 5.0)
		return false
	phantom_modus = "verteidigung"
	_angriff_pfad = pfad
	Werte.setze_anfuehrer("brakk")   # 19.11.: gegen Angriffs-Phantome vorerst immer mit Brakk
	_normales_spiel()
	_protokoll["gegen_angriff"] = pfad.get_file()
	melde("Du verteidigst gegen den Angriff von %s. Seine Welle steht jede Runde oben in der Ansage." % str(_angriff_phantom.get("spieler", "einem Phantom")), 8.0)
	return true


## Verteidigung: die Trupps, die das Angriffs-Phantom in Runde `nr` schickt (leer = es hat dafür keinen Plan).
func _phantom_trupps(nr: int) -> Array:
	for r: Dictionary in _angriff_phantom.get("runden", []):
		if int(r.get("runde", 0)) == nr:
			return r.get("trupps", [])
	return []


## Seitenwechsel: Der aufgezeichnete Bau eines Spielers verteidigt, du planst die Wellen auf dem Laufband.
func starte_phantom_angriff(pfad: String) -> bool:
	_phantom = Phantom.lade(pfad)
	if _phantom.is_empty():
		melde("Dieses Phantom lässt sich nicht laden.", 5.0)
		return false
	phantom_modus = "angriff"
	protokoll_an = false
	_plaene = {}
	_angriff_log = []
	_phantom_pfad = pfad
	_geknackt = 0
	nebel.vergiss()
	_ersatz = []
	_aktiv_pfad = pfad
	if not Online.ersatz_pfade.is_empty():
		_ersatz = Online.ersatz_pfade.duplicate()   # 18.11.: online gezogen (das Startmenü hat sie schon geladen)
		Online.ersatz_pfade = []
	else:
		var pool := Phantom.liste("verteidigung")
		Zufall.mische(pool)   # Ersatz-Phantome zufällig aus dem Pool
		for f: Dictionary in pool:
			if str(f["pfad"]).get_file() != pfad.get_file() and _ersatz.size() < 2:
				_ersatz.append(f["pfad"])
	Werte.setze_anfuehrer(str(_phantom.get("anfuehrer", "brakk")))   # 19.11.: das Phantom verteidigt mit den Regeln seines Anführers
	leben = Werte.start_leben()
	setze_checkpoints(_phantom["karte"]["checkpoints"])
	_lade_phantom_stand()
	_zeige_laufband()
	_taktik_fuehrung.call_deferred()   # 23.11.: erster Angriff – Sonde 7 führt durch die erste Runde
	melde("Angriff auf %s: Plane jede Runde eine Welle im Taktikplaner. Ziel: die %d Leben der Verteidigung." % [str(_phantom.get("spieler", "ein Phantom")), leben], 8.0)
	return true


## 23.11. (Phantom-Einführung D): Beim allerersten Angriff führt Sonde 7 durch die erste Runde im Taktikplaner:
## Vorlage/Einheiten aufs Band, Kärtchen anfassen, Budget, Welle starten. Kein Zwang – „Weiter“ geht immer, „Später“ schließt.
var _funk: Funkfenster

func _taktik_fuehrung() -> void:
	if phantom_modus != "angriff" or bool(Profil.einstellung("pe_taktik", false)) or tutorial != null:
		return
	Profil.setze_einstellung("pe_taktik", true)
	var lb := _laufband
	_funk = Funkfenster.zeige(self, [
		{"text": "Du planst jetzt die Welle gegen diesen fremden Bau. „Vorlage“ füllt dir eine Runde vor – klick darauf.",
			"ziel": func() -> Rect2: return lb.knopf_bildschirm("Vorlage") if lb.visible else Rect2(),
			"fertig": func() -> bool: return not lb.plan.is_empty(),
			"hinweis": "Oder zieh selbst Einheiten aus der Leiste aufs Band."},
		{"text": "Jedes Kärtchen ist ein Trupp. Schieb es für Reihenfolge und Pausen, klick es an für Ausgang und Start.",
			"ziel": func() -> Rect2: return lb.bildschirm(Laufband.RAHMEN_R) if lb.visible else Rect2()},
		{"text": "Unten steht dein Budget für diese Runde – mehr Einheiten kosten mehr. Jede Runde planst du neu.",
			"ziel": func() -> Rect2: return lb.bildschirm(Laufband.KONSOLE_R) if lb.visible else Rect2()},
		{"text": "Bereit? Starte die Welle mit dem Emblem unten rechts oder [Leertaste]. Dein Ergebnis zählt für deine Elo.",
			"ziel": func() -> Rect2: return (_hud.start.get_global_transform() * Rect2(Vector2.ZERO, _hud.start.size)) if _hud != null and _hud.start != null else Rect2(),
			"fertig": func() -> bool: return phase != Phase.BAU},
	], "TAKTIKPLANER")


func phantom_runden() -> int:
	return (_phantom.get("runden", []) as Array).size()


## Stellt den Bau des Phantoms für die laufende Runde hin – jede Runde frisch, ohne Schäden aus der Runde davor.
func _lade_phantom_stand() -> void:
	var runden: Array = _phantom["runden"]
	if welle > runden.size():
		return
	var stand: Dictionary = runden[welle - 1]["stand"]
	_setze_stand(stand)


## 18.11.: Stellt einen Bau im Format von Phantom._stand hin (Runde eines Phantoms oder Zwischenstand).
func _setze_stand(stand: Dictionary) -> void:
	_schliesse_fabrikmenue()
	for z: Vector2i in karte.feld.keys():
		karte.entferne(z)
	fabriken.clear()
	schilde.clear()
	_turm_abkling.clear()
	var ausbauten := {"stellung": Karte.STELLUNG, "turm": Karte.TURM, "tor": Karte.TOR, "spiegel": Karte.SPIEGEL, "magnet": Karte.MAGNET}
	for w: Array in stand["waelle"]:
		karte.setze(Vector2i(int(w[0]), int(w[1])), Karte.WALL)
		if w.size() > 3 and bool(w[3]):
			karte.panzer[Vector2i(int(w[0]), int(w[1]))] = true
	# Tore und Stellungen zuerst, Türme zuletzt: ein Turm sucht sich seine Stützen unter den fertigen Erdwällen
	for durchgang in 2:
		for w: Array in stand["waelle"]:
			var art := str(w[2])
			if art != "" and (art == "turm") == (durchgang == 1):
				karte.baue_aus(Vector2i(int(w[0]), int(w[1])), ausbauten[art])
				if art == "turm" and w.size() > 5 and int(w[5]) > 1:
					karte.turm_stufe[Vector2i(int(w[0]), int(w[1]))] = int(w[5])
					if w.size() > 6 and str(w[6]) != "":
						karte.turm_faehigkeit[Vector2i(int(w[0]), int(w[1]))] = str(w[6])
				if art == "stellung" and w.size() > 6 and int(w[5]) > 1:   # 20.11. (Paul): MG-Stellung – Stufe und Wahlen
					var mz := Vector2i(int(w[0]), int(w[1]))
					karte.mg_stufe[mz] = int(w[5]) - 1
					karte.mg_wahl[mz] = Array(str(w[6]).split("|", false))
				if art == "magnet" and w.size() > 4 and (w[4] as Array).size() == 2:
					karte.magnet_richtung[Vector2i(int(w[0]), int(w[1]))] = Vector2i(int(w[4][0]), int(w[4][1]))
	for f: Dictionary in stand["fabriken"]:
		var z := Vector2i(int(f["x"]), int(f["y"]))
		var stufe := int(f.get("stufe", 0))
		karte.setze(z, Karte.FABRIK)
		fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": str(f["einheit"]), "stufe": stufe}
		karte.fabrik_typ[z] = str(f["einheit"])
		if stufe > 0:
			karte.fabrik_stufe[z] = stufe
		if f.has("faehigkeit"):
			fabriken[z]["faehigkeit"] = str(f["faehigkeit"])
		if f.has("ziel"):
			fabriken[z]["ziel"] = str(f["ziel"])
		if f.has("stellungen"):
			var liste: Array = []
			for s in f["stellungen"]:
				liste.append(Vector2i(int(s[0]), int(s[1])))
			fabriken[z]["stellungen"] = liste
	for g: Array in stand.get("generatoren", []):
		var gz := Vector2i(int(g[0]), int(g[1]))
		var gp := Vector2i(int(g[2]), int(g[3]))
		karte.generator_paar[gz] = gp
		karte.generator_paar[gp] = gz
		karte.setze(gz, Karte.GENERATOR)
		karte.setze(gp, Karte.GENERATOR)
	for b: Dictionary in stand["batterien"]:
		var z := Vector2i(int(b["x"]), int(b["y"]))
		var pz := Vector2i(int(b["px"]), int(b["py"]))
		karte.setze(z, Karte.BATTERIE)
		karte.paar[z] = pz
		karte.paar[pz] = z
		if int(b.get("stufe", 0)) > 0:
			karte.fabrik_stufe[z] = int(b["stufe"])
		if b.has("schild") and (b["schild"] as Array).size() >= 4:   # alte Aufnahmen (ein Schildfeld) fallen weg
			_lege_schild(z, Vector2i(int(b["schild"][0]), int(b["schild"][1])), Vector2i(int(b["schild"][2]), int(b["schild"][3])))
	karte.repariere_alles()
	karte.aktualisiere_pfad()


## Züge, die der Verteidiger damals mitten in der Runde gemacht hat, gelten ab Rundenbeginn.
func _phantom_zuege_in_runde() -> void:
	var runden: Array = _phantom["runden"]
	if welle > runden.size():
		return
	for a: Dictionary in runden[welle - 1].get("in_runde", []):
		var z := Vector2i(int(a["x"]), int(a["y"]))
		if a["a"] == "bau" and a.get("typ", "") == "stellung":
			if karte.inhalt(z) == Karte.WALL and not karte.ausbau.has(z):
				karte.baue_aus(z, Karte.STELLUNG)
		elif a["a"] == "einheit" and fabriken.has(z) and int(fabriken[z].get("stufe", 0)) == 0 and not karte.paar.has(z):
			fabriken[z]["typ"] = str(a["typ"])
			karte.fabrik_typ[z] = str(a["typ"])


func _zeige_laufband() -> void:
	if not _plaene.has(welle):
		_plaene[welle] = []
	_laufband.visible = true
	_laufband.zeige(_plaene[welle])


## Angriff: Runde vorbei. Festhalten, was sie gebracht hat; die nächste Runde beginnt mit frischem Bau und leerem Band.
func _angriff_runde_fertig(geknackt: bool = false) -> void:
	var genommen := _leben_vor_runde - leben
	_angriff_log.append({
		"runde": welle,
		"gegen_pfad": _aktiv_pfad,
		"staerke": snappedf(_staerke_jetzt(), 0.01),   # 19.11.: Gegnerstärke für die Wertung
		"geknackt": geknackt,
		"trupps": (_plaene.get(welle, []) as Array).duplicate(true),
		"punkte": Phantom.plan_preis(_plaene.get(welle, [])),
		"budget": Phantom.budget(welle),
		"leben_genommen": genommen,
		"checkpoints_genommen": _cp_verloren,
		"durchgaenge": _durchgang,
		"sekunden": snappedf(_kampf_sek, 0.1),
	})
	melde("Runde %d: %d Leben genommen, die Verteidigung hat noch %d." % [welle, genommen, leben], 5.0)


## Angriff: Die Verteidigung hat ihr letztes Leben verloren. Steht ein Ersatz-Phantom bereit, übernimmt es ab der
## nächsten Runde mit vollen Leben und eigener Karte; sonst (oder in der letzten Runde) ist der Angriff gewonnen.
func _phantom_gefallen() -> void:
	var neu := {}
	if not endkampf and welle < Werte.LETZTE_RUNDE:
		# 19.11. (Paul): Der Angriff läuft immer bis Runde 20 – fällt eine Verteidigung, übernimmt die nächste.
		# Erst die mitgebrachten (online gezogenen) Ersatz-Phantome, dann der eingebaute Pool; wer schon dran war,
		# kommt erst wieder, wenn alle einmal dran waren.
		for versuch in 2:
			if _ersatz.is_empty():
				_ersatz_nachfuellen(versuch == 1)
			while not _ersatz.is_empty() and neu.is_empty():
				var kpfad: String = _ersatz.pop_front()
				var kandidat := Phantom.lade(kpfad)
				if (kandidat.get("runden", []) as Array).size() > welle:
					neu = kandidat
					neu["_pfad"] = kpfad
			if not neu.is_empty():
				break
	if neu.is_empty():
		_angriff_runde_fertig(true)
		_angriff_ende("durchbruch", true)
		return
	_angriff_runde_fertig(true)
	_zeige_geknackt(neu)


## 19.11.: Ersatz aus dem eingebauten Pool – zuerst die, die in diesem Angriff noch nicht dran waren
## (`wiederholen` = auch die schon geknackten, nur nicht die aktuelle).
func _ersatz_nachfuellen(wiederholen: bool) -> void:
	var dran := {}
	for e: Dictionary in _angriff_log:
		dran[str(e.get("gegen_pfad", "")).get_file()] = true
	dran[_aktiv_pfad.get_file()] = true
	var pool := Phantom.liste("verteidigung")
	Zufall.mische(pool)
	for f: Dictionary in pool:
		var datei := str(f["pfad"]).get_file()
		if datei == _aktiv_pfad.get_file():
			continue
		if wiederholen or not dran.has(datei):
			_ersatz.append(f["pfad"])


## Stärke der gerade stehenden Verteidigung für die Wertung (aus ihrem Elo online; offline ×1).
func _staerke_jetzt() -> float:
	var id := Online.id_von(_aktiv_pfad)
	if id == "":
		return 1.0
	for e: Dictionary in Online.listen["verteidigung"]:
		if str(e["id"]) == id:
			return Phantom.staerke(float(e.get("elo", 1000.0)))
	return 1.0


## 19.11. (Paul): Angriff mittendrin aufgegeben (Knopf nach dem Knacken, Neustart oder Hauptmenü): keine Wertung,
## nichts wird gespeichert oder hochgeladen – die Verteidigung, die gerade steht, bekommt den Sieg (Elo).
var _angriff_fertig := false

func _angriff_aufgeben() -> void:
	if phantom_modus != "angriff" or _angriff_fertig:
		return
	_angriff_fertig = true
	var vid := Online.id_von(_aktiv_pfad)
	if vid != "" and Online.aktiv():
		Online.angriff_abgebrochen(vid)   # 23.11.: zählt auch für die Spieler-Elo; 24.11. (72): als ein Lauf


## Angriff: Eine Verteidigung ist gefallen und ein Ersatz-Phantom steht bereit. Zwischenwertung zeigen (15.11.):
## Weiterspielen gegen das Ersatz-Phantom – oder hier aufhören und die Wertung sichern.
func _zeige_geknackt(neu: Dictionary) -> void:
	phase = Phase.ENDE
	_laufband.visible = false
	var probe: Array = _angriff_log.duplicate(true)
	var wertung := Phantom.wertung(probe)
	# 18.11.: Endtafel statt Textzeilen
	var genommen := 0
	for e: Dictionary in probe:
		genommen += int(e["leben_genommen"])
	var gegner_name := str(neu.get("spieler", "das Ersatz-Phantom"))
	_zeige_tafel({
		"kicker": "PHANTOM-ANGRIFF  ·  RUNDE %d" % welle, "titel": "GEKNACKT!", "titel_farbe": _F_KUPFER_HELL, "rahmen": _F_KUPFER_HELL,
		"untertitel": "Die Verteidigung von %s ist gefallen." % str(_phantom.get("spieler", "?")), "effekt": "kupfer", "wackeln": true,
		"kacheln": [
			{"name": "ZWISCHENSTAND", "zahl": int(wertung["gesamt"]), "farbe": _F_GOLD},
			{"name": "LEBEN GENOMMEN", "zahl": genommen, "farbe": _F_ROT, "symbol": "herz"},
			{"name": "GEKNACKT", "zahl": _geknackt + 1, "farbe": _F_KUPFER}],
		"kaesten": [{"titel": "NÄCHSTER GEGNER: %s" % gegner_name.to_upper(), "farbe": _F_KUPFER_HELL,
			"text": "Neue Karte, volle %d Leben, eine Runde ohne Nebel. Der Angriff geht bis Runde %d – Punkte zählen nach der Stärke der Verteidigung. Aufgeben bringt keine Wertung." % [Werte.START_LEBEN, Werte.LETZTE_RUNDE]}],
		"zeilen": ["  ·  ".join(wertung["zeilen"])],
		"knoepfe": [
			["Weiter gegen %s" % gegner_name, func():
				_tafel.visible = false
				_ersatz_uebernimmt(neu), _F_KUPFER_HELL],
			["Aufgeben · keine Wertung", func():
				_tafel.visible = false
				_aktiv_pfad = str(neu.get("_pfad", ""))   # die nächste Verteidigung stand bereit – sie bekommt den Sieg
				_angriff_aufgeben()
				_zum_menue(), _F_TEXT]],
	})


func _ersatz_uebernimmt(neu: Dictionary) -> void:
	_geknackt += 1
	nebel.vergiss()
	nebel.frei_runde = welle + 1   # das neue Phantom zeigt sich eine Runde lang ohne Nebel
	for g in gegner:
		g.queue_free()
	gegner.clear()
	_schlange = []
	_pausen = []
	_ausgaenge = []
	_locker = []
	_wurf_schlange = []
	_wurf_aktiv = []
	_im_flug = 0
	_phantom = neu
	_aktiv_pfad = str(neu.get("_pfad", ""))
	_phantom.erase("_pfad")
	Werte.setze_anfuehrer(str(_phantom.get("anfuehrer", "brakk")))   # 19.11.: Ersatz-Phantom mit seinem Anführer
	leben = Werte.start_leben()
	setze_checkpoints(_phantom["karte"]["checkpoints"])
	var b: Array = _phantom["karte"].get("basis", [Werte.BASIS_ZELLE.x, Werte.BASIS_ZELLE.y])
	setze_basis(Vector2i(int(b[0]), int(b[1])))
	for i in karte.cp_feind.size():
		karte.cp_feind[i] = false
	_naechste_bauphase()
	_lade_phantom_stand()
	_zeige_laufband()
	_einblendung.banner("NEUER GEGNER", "%s übernimmt – volle %d Leben." % [str(_phantom.get("spieler", "?")), leben], _F_KUPFER_HELL)   # 18.11.
	melde("Verteidigung geknackt! Ein Ersatz-Phantom (%s) übernimmt ab Runde %d – neue Karte, volle %d Leben." % [str(_phantom.get("spieler", "?")), welle, leben], 10.0)


## Angriff: Schlussbild mit Wertung; der Angriff wird als Angriffs-Phantom gespeichert.
func _angriff_ende(grund: String, runde_gebucht: bool = false) -> void:
	if not runde_gebucht:
		_angriff_runde_fertig()
	phase = Phase.ENDE
	_laufband.visible = false
	var genommen := 0
	var punkte := 0
	for e: Dictionary in _angriff_log:
		punkte += int(e["punkte"])
		genommen += int(e["leben_genommen"])
	var wertung := Phantom.wertung(_angriff_log)
	_angriff_fertig = true
	# 19.11. (Paul): Nur vollständige Angriffe (bis Runde 20) zählen für Rangliste, Profil und Online-Pool.
	var vollstaendig := welle >= Werte.LETZTE_RUNDE
	var daten := {
		"format": 1, "art": "angriff", "spieler": Profil.name(), "profil": Profil.id(), "begonnen": Time.get_datetime_string_from_system(),
		"gegen": str(_phantom.get("quelle", "")),
		"ergebnis": {"ausgang": grund, "runde": welle, "leben_genommen": genommen, "punkte": punkte, "geknackt": _geknackt + (1 if grund == "durchbruch" else 0),
			"durchgaenge_runde_20": _durchgang if endkampf else 0, "wertung": wertung["gesamt"]},
		"runden": _angriff_log,
	}
	var pfad := Phantom.speichere("angriff", daten) if vollstaendig else ""
	if vollstaendig:
		_merke_export(daten, "angriff")
		Profil.angriff_ende(int(wertung["gesamt"]), _geknackt + (1 if grund == "durchbruch" else 0))
	if _geknackt + (1 if grund == "durchbruch" else 0) > 0:
		erfolg("einbrecher")   # 18.11.
	if pfad != "":
		_angriff_online.call_deferred(pfad, daten, int(wertung["gesamt"]))
	# 18.11.: Endtafel statt Textzeilen
	var geknackt := _geknackt + (1 if grund == "durchbruch" else 0)
	var titel := "DURCHBRUCH!"
	var farbe := _F_KUPFER_HELL
	var unter := "Die Verteidigung ist in Runde %d gefallen." % welle if geknackt <= 1 else "%d Verteidigungen geknackt, die letzte in Runde %d." % [geknackt, welle]
	if grund == "hq":
		titel = "HQ GEFALLEN"
		farbe = _F_ROT
		unter = "Das Phantom hat den Gegenangriff gewonnen – aber jede Sekunde zählt."
	elif grund != "durchbruch":
		titel = "ANGRIFF BEENDET"
		farbe = _F_GOLD
		unter = "Das Phantom hat keine weiteren Runden."
	var zeilen: Array = ["  ·  ".join(wertung["zeilen"])]
	if endkampf:
		zeilen.append("Runde 20: %d Durchgänge, %d Sekunden" % [_durchgang, int(_kampf_sek)])
	if not vollstaendig:
		zeilen.append("Kein Ersatz-Phantom mehr da – der Angriff endet vor Runde %d und zählt nicht für die Rangliste." % Werte.LETZTE_RUNDE)
	elif pfad == "":
		zeilen.append("(Speichern hat nicht geklappt.)")
	var tafel_conf := {
		"kicker": "PHANTOM-ANGRIFF  ·  GEGEN %s" % str(_phantom.get("spieler", "?")).to_upper(), "titel": titel, "titel_farbe": farbe, "rahmen": farbe,
		"untertitel": unter, "effekt": "kupfer" if grund != "hq" else "asche", "glitch": grund == "hq",
		"kacheln": [
			{"name": "PUNKTE", "zahl": int(wertung["gesamt"]), "farbe": _F_GOLD},
			{"name": "LEBEN GENOMMEN", "zahl": genommen, "farbe": _F_ROT, "symbol": "herz"},
			{"name": "GEKNACKT", "zahl": geknackt, "farbe": _F_KUPFER},
			{"name": "BUDGET", "zahl": punkte, "farbe": _F_TEXT, "symbol": "muenze"}],
		"kaesten": [_protokoll_kasten("DEIN ANGRIFF IST JETZT EIN PHANTOM", "Andere Spieler verteidigen ab jetzt gegen deine Wellen.")] if pfad != "" else [],
		"zeilen": zeilen,
		"knoepfe": [["Nochmal angreifen", _neustart, _F_KUPFER_HELL], ["Startmenü", _zum_menue, _F_TEXT]],
	}
	if pfad != "":
		var elo := _elo_platz("angriff")   # 23.11. (Einführung F): Elo-Änderung zählt auf der Tafel
		if not elo.is_empty():
			tafel_conf["elo"] = elo
	_zeige_tafel(tafel_conf)


# ------------------------------------------------------------ Profil und Online-Pool (18.11.)

# ------------------------------------------------------------ Herausforderungen (18.11.)
## Startmenü → Herausforderungen: "" (keine), "keine_fabriken", "doppelt", "mauern_fest" (Liste in Werte.HERAUSFORDERUNGEN).
## Zählt nicht für Rangliste und Phantome; Erfolge zählen. Setzt das Startmenü (auch bei jedem anderen Modus, dann "").
var herausforderung := ""


## Alle Bauwerke frei (sonst gibt es in Runde 1 nur Fabriken)?
func alles_frei() -> bool:
	return sandbox or brakk_modus or Werte.plan_runde(welle) >= Werte.WAELLE_AB_WELLE or herausforderung in ["keine_fabriken", "mauern_fest"]   # 18.11.: Brakk-Mode – alles ab Runde 1 (5 Gratis-Erdwälle je Runde)


## 18.11.: Bauwerke, die eine Karte (Regelpaket „bauten“, Szenario-Editor) einzeln sperren kann: Werkzeug -> [Schlüssel, Name].
const BAUTEN := {
	Karte.FABRIK: ["fabrik", "Fabrik"], Karte.WALL: ["wall", "Erdwall"], Karte.STELLUNG: ["stellung", "Stellung"],
	Karte.TURM: ["turm", "Turm"], Karte.GENERATOR: ["generator", "Schildgenerator"], Karte.BATTERIE: ["batterie", "Batterie"],
	Karte.TOR: ["tor", "Tor"], Karte.PANZER: ["panzer", "Panzerung"], Karte.KOMMANDANT: ["kommandant", "Brakk"],
}


## Grund, warum die Herausforderung (oder die Karte) dieses Bauwerk verbietet ("" = erlaubt).
func herausforderung_sperrt(typ: int) -> String:
	if BAUTEN.has(typ) and not Werte.baut_erlaubt(str(BAUTEN[typ][0])):
		return "Auf dieser Karte gesperrt: %s." % str(BAUTEN[typ][1])
	if herausforderung == "keine_fabriken" and typ == Karte.FABRIK:
		return "Herausforderung „Keine Fabriken“: Fabriken sind gesperrt – Türme, Batterien und Brakk gehen."
	if herausforderung == "mauern_fest" and typ == Karte.WALL:
		return "Herausforderung „Mauern fest“: Die Mauer steht schon – bau Türme, Stellungen und Tore darauf."
	return anfuehrer_sperrt(typ)


## 19.11.: Was der Anführer nicht erlaubt ("" = erlaubt): gesperrte Bauwerke, Höchstzahl Fabriken, Figur auf Slot [8].
## Für Brakk greift nichts davon.
func anfuehrer_sperrt(typ: int) -> String:
	var wer := Anfuehrer.name(Werte.anfuehrer)
	if typ == Karte.KOMMANDANT and Werte.figur() != "brakk":   # Schritt 2c: hier die Figuren der anderen Anführer anschließen
		return "Figur folgt: Die Figur von %s kommt noch." % wer
	if BAUTEN.has(typ) and Werte.af_gesperrt(str(BAUTEN[typ][0])):
		return "%s: %s gesperrt." % [wer, str(BAUTEN[typ][1])]
	if typ == Karte.FABRIK and Werte.max_fabriken() > 0 and _normale_fabriken() >= Werte.max_fabriken():
		return "%s: höchstens %d Fabriken." % [wer, Werte.max_fabriken()]
	return ""


## 19.11.: Anführer der Partie festlegen (Werte.anfuehrer) – ein Szenario kann ihn vorgeben (Regelpaket „anfuehrer“,
## leer = frei wählbar). Steht auch im Protokoll (Phantome) und setzt das Startleben des Anführers.
func _setze_anfuehrer(id: String) -> void:
	var vorgabe := str(Werte.KARTE_REGELN.get("anfuehrer", ""))
	Werte.setze_anfuehrer(vorgabe if vorgabe != "" else id)
	_protokoll["anfuehrer"] = Werte.anfuehrer
	_merke_code()   # 20.11.
	leben = Werte.start_leben()


## 20.11.: Anführer nur per Entwicklercode frei → Flag im Partieprotokoll: keine Rangliste, keine Phantome.
func _merke_code() -> void:
	if Anfuehrer.per_code(Werte.anfuehrer):
		_protokoll["code"] = true
	else:
		_protokoll.erase("code")


## 18.11.: Einkommen (Rundenbonus, Prämien, Erzadern) mit „Doppeltes Geld“ und dem Werte-Mod „Einkommen“ der Karte.
func einkommen(betrag: int) -> int:
	if not Werte.einkommen_an():
		return 0   # 20.11.: Szenario ohne Einkommen (Rundenbonus, Prämien, Erzadern)
	return roundi(betrag * geld_faktor() * Werte.mod_faktor("einkommen"))


func geld_faktor() -> int:
	return 2 if herausforderung == "doppelt" else 1


## Zu Beginn einer Partie mit Herausforderung: fertige Mauer hinstellen bzw. das Startpaket sofort geben.
func _herausforderung_einrichten() -> void:
	if herausforderung == "":
		return
	if herausforderung == "mauern_fest":
		setze_kartenmauern(Werte.MAUERN_FEST)
		# Lag ein Checkpoint auf der Mauer (dort bleibt sie offen), würfeln wir ihn neu und schließen die Lücke
		var im_weg := false
		for cp: Vector2i in karte.checkpoints:
			if Werte.MAUERN_FEST.has(cp):
				im_weg = true
		if im_weg:
			setze_checkpoints(karte._zufalls_checkpoints())
			setze_kartenmauern(Werte.MAUERN_FEST)
	elif herausforderung == "keine_fabriken":
		freie_waelle = Werte.startpaket_waelle()   # 19.11.: je Anführer
	melde("Herausforderung: %s – %s" % [Werte.herausforderung_name(herausforderung), Werte.herausforderung_text(herausforderung)], 9.0)


## „Doppelte Gegner“: jeder Trupp kommt zweimal hintereinander (tiefe Kopie – die Wellen in Werte bleiben unberührt).
func _verdoppelt(w: Dictionary, mal: int = 2) -> Dictionary:   # 18.11.: `mal` – Brakk-Mode verdreifacht
	var d: Dictionary = w.duplicate(true)
	for g: Dictionary in d.get("gruppen", []):
		g["anzahl"] = int(g["anzahl"]) * mal
	for schluessel: String in ["trupps", "pausen", "locker", "ausgaenge", "jeder"]:
		if not d.has(schluessel):
			continue
		var alt: Array = d[schluessel]
		var neu: Array = []
		for e: Variant in alt:
			neu.append(e)
			for i in mal - 1:
				neu.append(e.duplicate(true) if e is Array else e)
		d[schluessel] = neu
	return d


## 18.11.: um so viel Prozent wird jede weitere Fabrik teurer (Brakk-Mode weniger).
func fabrik_prozent() -> float:
	return BRAKK_FABRIK_PROZENT if brakk_modus else Werte.KOSTEN_FABRIK_PROZENT


## 18.11. (Paul): Brakk-Mode – jeder Trupp kommt mit `mal`-facher Stärke auf einmal (statt mehrerer Trupps nacheinander),
## seine Gegner starten in halbem Abstand: weniger Einzelgänger, mehr Druck, kürzere Runden.
func _gebuendelt(w: Dictionary, mal: float) -> Dictionary:
	var d: Dictionary = w.duplicate(true)
	var neu: Array = []
	for t: Variant in d.get("trupps", []):
		# 18.11.: auch krumme Faktoren (2,2): die Gegner des Trupps reihum wiederholen, bis die neue Größe erreicht ist
		var alt := t as Array
		var groesser: Array = []
		for i in roundi(alt.size() * mal):
			groesser.append(alt[i % alt.size()])
		neu.append(groesser)
	# die Vorschau zählt dieselben Gegner, die wirklich kommen
	for g: Dictionary in d.get("gruppen", []):
		var anzahl := 0
		for t2: Variant in neu:
			anzahl += (t2 as Array).count(g["typ"])
		g["anzahl"] = anzahl
	d["trupps"] = neu
	d["abstand"] = float(d.get("abstand", 1.0)) * BRAKK_ABSTAND_MAL
	return d


## 18.11.: Erfolg freischalten (erfolge.gd) – nicht in der Sandbox.
func erfolg(id: String) -> void:
	if sandbox or _protokoll.has("sandbox_sprung"):
		return
	Erfolge.melde(id)


## 18.11.: Wurde in dieser Partie je eine Fabrik gebaut? (Pilotenfabriken der Batterien zählen nicht.)
func _fabrik_gebaut() -> bool:
	for r: Dictionary in _protokoll.get("runden", []):
		for a: Dictionary in r.get("aktionen", []):
			if str(a.get("a", "")) == "bau" and str(a.get("typ", "")) == "fabrik":
				return true
	return false


## 20.11. (Paul): Pauls Aufträge (scripts/auftraege.gd). `auftrag` = laufender Auftrag ({} = keiner).
var auftrag: Dictionary = {}
var auftrag_letzter := ""   # Kennungen der letzten Runde (mit Komma) – nie gleich noch einmal
var gratis_fabriken := 0    # 20.11. (Paul): Sachpreis aus Aufträgen – so viele Fabriken kosten nichts


func _auftrag_neu() -> void:
	auftrag = Auftraege.neuer(self)
	if not auftrag.is_empty():
		melde("%s für diese Runde – die Liste steht oben links." % Auftraege.titel(auftrag), 7.0)


func _auftrag_pruefen(wann: String) -> void:
	if not auftrag.is_empty() and Auftraege.pruefe(self, auftrag, wann):
		auftrag_letzter = Auftraege.kennungen(auftrag)
		auftrag = {}


## 19.11.: Erfolge „Ausbilder“ und „Deutscher Sparer“ beim Sieg.
func _erfolge_zum_sieg() -> void:
	if bool(Profil.einstellung("tutorial_fertig", false)) and _normale_fabriken() >= Erfolge.AUSBILDER_FABRIKEN:
		for z: Vector2i in fabriken:
			if not karte.paar.has(z) and int(fabriken[z].get("stufe", 0)) >= 3:
				erfolg("ausbilder")
				break
	if bool(_protokoll.get("sparer", false)):
		erfolg("deutscher_sparer")


## 19.11.: Erfolg „Baumeister“ – in dieser Partie alle Formtürme gebaut (gemerkt im Protokoll, übersteht so den
## Zwischenstand) und ein Turm steht auf Stufe 3. Geprüft beim Turmbau und beim Aufwerten.
func _pruefe_baumeister(neue_art: String = "") -> void:
	var formen: Array = _protokoll.get("formen", [])
	if neue_art != "" and not formen.has(neue_art):
		formen.append(neue_art)
		_protokoll["formen"] = formen
	if formen.filter(func(a: Variant) -> bool: return not str(a) in ["truppen", "pliplop"]).size() < Werte.FORMTUERME_ZAHL:   # 20.11. (Nachtrag): ohne Truppenturm
		return
	for z: Vector2i in karte.turm_stufe:
		if int(karte.turm_stufe[z]) >= 3:
			erfolg("baumeister")
			return


var schuetze: Node = null   # 18.11.: die Truppe, deren Schuss gerade trifft (Erfolg „Einsamer Posten“)


## Ein besiegter Gegner fürs Profil: welche Einheit, welcher Turm, Brakk oder eine Batterie.
func _profil_kill(quelle: String) -> void:
	if sandbox or phantom_modus == "angriff" or quelle == "":
		return
	var schluessel := ""
	if quelle == "fabrik:-1,-1":
		schluessel = "brakk"
	elif quelle.begins_with("fabrik:"):
		var xy := quelle.trim_prefix("fabrik:").split(",")
		var z := Vector2i(int(xy[0]), int(xy[1]))
		if fabriken.has(z):
			schluessel = "einheit:" + str(fabriken[z]["typ"])
	elif quelle.begins_with("turm:"):
		schluessel = quelle
	elif quelle.begins_with("batterie"):
		schluessel = "batterie"
	if schluessel != "":
		_profil_kills[schluessel] = int(_profil_kills.get(schluessel, 0)) + 1
	if schluessel == "brakk" and Profil.kills("brakk") + int(_profil_kills["brakk"]) >= 50:
		erfolg("kommandant")


## Partie als Verteidiger zu Ende: Profil fortschreiben. Gegen ein Angriffs-Phantom gibt es eine Wertung (Text zurück).
func _partie_ins_profil(sieg: bool) -> String:
	if sandbox or phantom_modus == "angriff":
		return ""
	var gehalten := welle if sieg else welle - 1
	var vw := -1
	var text := ""
	if phantom_modus == "verteidigung":
		var w := Phantom.verteidigungs_wertung(gehalten, leben, sieg)
		vw = int(w["gesamt"])
		text = "Verteidigungswertung: %d Punkte  ·  %s" % [vw, "  ·  ".join(w["zeilen"])]
	Profil.partie_ende(sieg, welle, _profil_kills, vw)
	_profil_kills = {}
	return text


func _online_hinweis(ok: bool, was: String) -> void:
	if not is_instance_valid(_export_hinweis) or _export_text == "":
		return
	_export_hinweis.text = ("Online hochgeladen: %s – andere Spieler treffen jetzt darauf." % was) if ok else "Keine Verbindung – dein Lauf liegt als Datei bereit (herunterladen und an Paul schicken)."


## Angriff hochladen und für jede Verteidigung, gegen die er lief, ein Duell melden (Elo).
func _angriff_online(pfad: String, daten: Dictionary, wertung: int) -> void:
	if not Online.aktiv():
		return
	var elo_vor: Dictionary = await Online.meine_elo("angriff")   # 23.11.: Spieler-Elo vor dem Lauf (für die Anzeige)
	var id := ""
	if await _platz_frei("angriff"):   # 23.11.: höchstens 3 eigene Angriffe im Pool – sonst wählt der Spieler, welcher weicht
		id = await Online.hochladen("angriff", pfad.get_file(), daten)
		_online_hinweis(id != "", "dein Angriff")
		if id != "":
			Online.pfad_id[pfad] = id
	else:
		_online_hinweis_text("Nicht hochgeladen – deine bisherigen Angriffe bleiben im Pool. Dein Lauf zählt trotzdem für deine Spieler-Elo.")
	# 24.11. (Paul, Version 72): Phantom-Elo je Verteidigung einzeln (Duell mit Runde und Anteil), die Spieler-Angriffs-Elo
	# aber nur EINMAL für den ganzen Lauf (Budget-gewichtet, Datenbank `angriff_lauf_melden`).
	var duelle: Array = Online.lauf_duelle(daten)
	for d: Dictionary in duelle:
		await Online.duell(id, str(d["id"]), float(d["phantom_s"]), wertung, "angriff")
	await Online.lauf(duelle)
	await _elo_anzeigen("angriff", elo_vor)


## Verteidigung gegen ein Angriffs-Phantom (oder ein Sieg im normalen Spiel) zu Ende: Bau hochladen, Duell melden.
func _verteidigung_online(pfad: String, daten: Dictionary) -> void:
	if not Online.aktiv() or not Anfuehrer.ranglistenfaehig(Werte.anfuehrer) or _protokoll.has("code"):   # 19.11.: Paul meldet nichts an die Rangliste; 20.11.: per Code freigeschaltet auch nicht
		return
	var vid := ""
	var elo_vor: Dictionary = {}
	if phantom_modus == "verteidigung":
		elo_vor = await Online.meine_elo("verteidigung")   # 23.11.: Spieler-Elo vor dem Duell (für die Anzeige)
	if pfad != "":
		if await _platz_frei("verteidigung"):   # 23.11.: höchstens 3 eigene Verteidigungen im Pool
			vid = await Online.hochladen("verteidigung", pfad.get_file(), daten)
			_online_hinweis(vid != "", "dein Bau")
			if vid != "":
				Online.pfad_id[pfad] = vid
		else:
			_online_hinweis_text("Nicht hochgeladen – deine bisherigen Verteidigungen bleiben im Pool.")
	if phantom_modus == "verteidigung" and _angriff_pfad != "" and not _duell_gemeldet:
		_duell_gemeldet = true
		var aid := Online.id_von(_angriff_pfad)
		var genommen := Werte.START_LEBEN - leben
		if aid != "":
			await Online.duell(aid, vid, Phantom.duell_ergebnis(genommen, leben <= 0, welle), 0, "verteidigung")   # 23.11.: Runde des Falls zählt mit; Spieler-Elo
	await _elo_anzeigen("verteidigung", elo_vor)


## 23.11. (Phantom-Einführung F): Platzhalter „Elo wird berechnet“ für die Endtafel – leer, wenn gar nichts gemeldet wird.
func _elo_platz(art: String) -> Dictionary:
	var id := Profil.id()
	if not Online.aktiv() or id == "" or id == "pool":
		return {}
	if art == "verteidigung":
		if phantom_modus != "verteidigung" or _angriff_pfad == "" or Online.id_von(_angriff_pfad) == "" or not Anfuehrer.ranglistenfaehig(Werte.anfuehrer) or _protokoll.has("code"):
			return {}
	return {"label": "DEINE ANGRIFFS-ELO" if art == "angriff" else "DEINE VERTEIDIGUNGS-ELO", "vorher": 1000, "nachher": -1, "hinweis": ""}


## Nach dem Duell: neue Spieler-Elo holen und auf der Tafel hochzählen lassen (Rückfall: Anzeige weg).
func _elo_anzeigen(art: String, vor: Dictionary) -> void:
	if _tafel == null or not _tafel.conf.has("elo"):
		return
	var nach: Dictionary = await Online.meine_elo(art)
	if _tafel == null or not _tafel.conf.has("elo"):
		return
	if vor.is_empty() or nach.is_empty():
		_tafel.conf.erase("elo")
		return
	var hinweis := ""
	var spiele := int(nach.get("spiele", 0))
	if spiele < Online.LISTE_AB:
		hinweis = "noch %d %s bis zur Rangliste" % [Online.LISTE_AB - spiele, "Lauf" if Online.LISTE_AB - spiele == 1 else "Läufe"]
	else:
		await Online.lade_listen()
		var platz := 0
		var n := 0
		for e: Dictionary in Online.spieler_listen[art]:
			if int(e.get("spiele", 0)) >= Online.LISTE_AB:
				n += 1
				if platz == 0 and str(e.get("profil", "")) == Profil.id():
					platz = n
		if platz > 0:
			hinweis = "Platz %d in der Rangliste" % platz
	if _tafel != null and _tafel.conf.has("elo"):
		_tafel.elo_setze(roundi(float(vor.get("elo", 1000))), roundi(float(nach.get("elo", 1000))), hinweis)


var _duell_gemeldet := false   # 23.11.: Phantom-Verteidigung – das Duell wird nur einmal gemeldet


## 23.11. (Paul): Phantom-Verteidigung mittendrin verlassen (Hauptmenü, Neustart) zählt als Niederlage in dieser Runde.
func _verteidigung_aufgeben() -> void:
	if phantom_modus != "verteidigung" or phase == Phase.ENDE or _duell_gemeldet or _angriff_pfad == "":
		return
	_duell_gemeldet = true
	if not Online.aktiv() or not Anfuehrer.ranglistenfaehig(Werte.anfuehrer) or _protokoll.has("code"):
		return
	var aid := Online.id_von(_angriff_pfad)
	if aid != "":
		Online.duell(aid, "", Phantom.duell_ergebnis(Werte.START_LEBEN - leben, true, welle), 0, "verteidigung")   # statisch: läuft weiter, auch wenn die Szene wechselt


# ------------------------------------------------------------ Plätze im Pool (23.11.)

## 23.11. (Paul): Jeder Spieler hat Online.PLAETZE Plätze je Art. Sind sie voll, wählt er auf einer Tafel, welches
## Phantom weicht (das schwächste ist vorausgewählt) – oder er lädt nicht hoch. Verdrängte Phantome kommen ins Archiv
## (bleiben in der Datenbank, aber nicht mehr im Pool und nicht in der Rangliste). Esc / Schließen = nicht hochladen.
## Hat jemand aus der Zeit vor der Regel mehr Phantome, bleiben die stärksten zur Wahl, die übrigen gehen ins Archiv.
## true = hochladen.
var _platz_wahl := "?"

func _platz_frei(art: String) -> bool:
	var eigene: Variant = await Online.eigene(art)
	if not (eigene is Array) or (eigene as Array).size() < Online.PLAETZE:
		return true   # Platz frei, offline oder Datenbank noch ohne Plätze
	var liste: Array = (eigene as Array).duplicate()   # schwächstes zuerst (Elo aufsteigend)
	var ueberzaehlig: Array = liste.slice(0, liste.size() - Online.PLAETZE)
	var wahl: Array = liste.slice(liste.size() - Online.PLAETZE)
	_platz_wahl = "?"
	var punkte: Array = []
	var knoepfe: Array = []
	for i in wahl.size():
		var e: Dictionary = wahl[i]
		var datum := str(e.get("erstellt", "")).left(10)
		var teile := datum.split("-")
		if teile.size() == 3:
			datum = "%s.%s." % [teile[2], teile[1]]
		punkte.append(["panzer" if art == "angriff" else "wall", "%d: Elo %d · %d Duelle · vom %s%s" % [i + 1, roundi(float(e.get("elo", 1000))), int(e.get("spiele", 0)), datum, "  (schwächstes)" if i == 0 else ""]])
		var id := str(e["id"])
		knoepfe.append(["Ersetze %d" % (i + 1), func(): _platz_wahl = id; _bestaetigung.visible = false, _F_KUPFER_HELL if i == 0 else _F_LEUCHT])
	var behalten := func(): _platz_wahl = ""; _bestaetigung.visible = false
	knoepfe.append(["Behalten", behalten, _F_TEXT])
	var zeilen: Array = ["Dein neues Phantom nimmt den Platz eines alten ein. Das alte kommt ins Archiv."]
	if not ueberzaehlig.is_empty():
		zeilen.append("Neu: %d Plätze je Art. Deine %d schwächeren älteren Phantome kommen ebenfalls ins Archiv." % [Online.PLAETZE, ueberzaehlig.size()])
	(_bestaetigung as EndTafel).zeige({
		"kicker": "PHANTOM-POOL", "titel": "PLÄTZE VOLL", "titel_farbe": _F_KUPFER_HELL, "rahmen": _F_KUPFER_HELL,
		"untertitel": "Du hast schon %d %s im Pool. Welches soll weichen?" % [Online.PLAETZE, "Angriffe" if art == "angriff" else "Verteidigungen"],
		"punkte": punkte, "zeilen": zeilen, "knoepfe": knoepfe, "esc": behalten,
	})
	while _platz_wahl == "?":
		if not is_inside_tree():
			return false
		if not _bestaetigung.visible:
			_platz_wahl = ""   # anders geschlossen: nichts verdrängen
			break
		await get_tree().process_frame
	if _platz_wahl == "":
		return false
	if not await Online.archivieren(_platz_wahl):
		_online_hinweis_text("Der alte Platz ließ sich nicht freimachen – nicht hochgeladen.")
		return false
	if not ueberzaehlig.is_empty():
		for e: Dictionary in ueberzaehlig:
			await Online.archivieren(str(e["id"]))
	return true


func _online_hinweis_text(text: String) -> void:
	if is_instance_valid(_export_hinweis):
		_export_hinweis.text = text


# ------------------------------------------------------------ Schlussbild

## Schlussbild mit Knöpfen: Neustart, Startmenü und – nach einem Sieg im normalen Spiel – der Wechsel in den Angriffsmodus.
func _zeige_ende(text: String, schrift: int = 36, mit_angriff: bool = false) -> void:
	phase = Phase.ENDE
	_ende_text.add_theme_font_size_override("font_size", schrift)
	_ende_text.text = text
	for k in _ende_knoepfe.get_children():
		k.queue_free()
	_ende_knopf("Nochmal angreifen" if phantom_modus == "angriff" else "Neustart", _neustart)
	_ende_knopf("Startmenü", _zum_menue)
	if mit_angriff:
		var b := _ende_knopf("⚔  In die Offensive", _frage_angriff)
		b.custom_minimum_size = Vector2(330, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color("ffe9a8"))
		var kasten := StyleBoxFlat.new()
		kasten.bg_color = Color("5a1f1f")
		kasten.border_color = Color("ffb347")
		kasten.set_border_width_all(3)
		kasten.set_corner_radius_all(6)
		var hell: StyleBoxFlat = kasten.duplicate()
		hell.bg_color = Color("7d2a2a")
		b.add_theme_stylebox_override("normal", kasten)
		b.add_theme_stylebox_override("hover", hell)
		b.add_theme_stylebox_override("pressed", hell)
		# langsames Pulsieren, damit die Option ins Auge fällt
		var puls := create_tween().set_loops()
		puls.tween_property(b, "modulate", Color(1.25, 1.15, 1.0), 0.8)
		puls.tween_property(b, "modulate", Color(1, 1, 1), 0.8)
	# Zweite Reihe: das Phantom-Protokoll dieses Laufs zum Weitergeben
	for k in _export_knoepfe.get_children():
		k.queue_free()
	if _export_text != "":
		var b1 := _ende_knopf("⬆  Phantom-Protokoll hochladen", _export_datei, _export_knoepfe)
		b1.custom_minimum_size = Vector2(340, 44)
		b1.add_theme_font_size_override("font_size", 17)
		b1.add_theme_color_override("font_color", Color("ffe9a8"))
	_export_hinweis.text = ("Wird online hochgeladen …" if Online.aktiv() else "Dein Lauf als Datei: herunterladen und an Paul schicken – dann wird er zum Phantom für andere Spieler.") if _export_text != "" else ""
	_ende.visible = true


const _F_LEUCHT := Color("7fe0ff")
const _F_TEXT := Color("e6edf3")
const _F_GOLD := Color("ffd34d")
const _F_ROT := Color("ff5a6e")
const _F_KUPFER := Color("e08a4f")
const _F_KUPFER_HELL := Color("ffb070")


## Endtafel zeigen (18.11.): Spiel steht, das alte Schlussbild bleibt verborgen.
func _zeige_tafel(conf: Dictionary) -> void:
	phase = Phase.ENDE
	_ende.visible = false
	_tafel.gesperrt = func() -> bool: return _bestaetigung.visible
	_tafel.zeige(conf)


## Kasten „Phantom-Protokoll“ für die Endtafel: Hinweis zum Hochladen (ändert sich, sobald online fertig) und Knopf.
func _protokoll_kasten(titel: String, sonst: String) -> Dictionary:
	_export_hinweis.text = ("Wird online hochgeladen …" if Online.aktiv() else "Dein Lauf als Datei: herunterladen und an Paul schicken – dann wird er zum Phantom für andere Spieler.") if _export_text != "" else sonst
	var k := {"titel": titel, "farbe": _F_LEUCHT, "text_fn": func() -> String: return _export_hinweis.text}
	if _export_text != "":
		k["knopf"] = ["Hochladen", _export_datei]
	return k


var _phantom_neu := false   # 21.11.: dieser Sieg hat den Phantom-Modus freigeschaltet


## 18.11.: Siegbildschirm statt Text auf schwarzem Grund.
func _zeige_sieg(info: Dictionary, mit_angriff: bool) -> void:
	var k: Array = []
	if mit_angriff:
		k.append(["In die Offensive", _frage_angriff, _F_KUPFER_HELL])
	k.append(["Neustart", _neustart, _F_LEUCHT])
	k.append(["Startmenü", _zum_menue, _F_TEXT])
	var conf := {
		"kicker": ("RUNDE %d  ·  GEGENANGRIFF" % int(info["welle"])) if Werte.ziel() == "gegenangriff" else ("RUNDE %d  ·  %s" % [int(info["welle"]), Werte.ziel_name(Werte.ziel()).to_upper()]), "titel": "SIEG", "titel_farbe": _F_GOLD, "rahmen": _F_GOLD,
		"untertitel": "Das HQ der Myriaden ist zerstört." if Werte.ziel() == "gegenangriff" else "Alle Runden überstanden – die Basis steht.", "effekt": "funken",   # 18.11.: Spielziel
		"kacheln": [
			{"name": "RUNDEN", "zahl": info["welle"], "max": info["welle"], "farbe": _F_LEUCHT},
			{"name": "LEBEN", "zahl": info["leben"], "max": info["max_leben"], "farbe": _F_ROT, "symbol": "herz"},
			{"name": "BESIEGT", "zahl": info["besiegt"], "farbe": _F_KUPFER},
			{"name": "KAMPFZEIT", "zahl": info["sekunden"], "zeit": true, "farbe": _F_TEXT}],
		"kaesten": [_protokoll_kasten("DEIN BAU IST JETZT EIN PHANTOM", "")] if info["phantom"] else [],
		"zeilen": [str(info["wertung"])] if str(info["wertung"]) != "" else [],
		"knoepfe": k,
	}
	if _phantom_neu:
		(conf["zeilen"] as Array).append("Phantom-Modus freigeschaltet")   # 21.11. (Paul)
	if phantom_modus == "verteidigung":
		var elo := _elo_platz("verteidigung")
		if not elo.is_empty():
			conf["elo"] = elo
	elif info["phantom"] and not bool(Profil.einstellung("pe_comic", false)):
		# 23.11. (Einführung B): beim ersten Phantom-Bau ein Mini-Comic – was jetzt mit dem Bau geschieht
		Profil.setze_einstellung("pe_comic", true)
		conf["comic"] = [["wall", "Dein Bau", _F_LEUCHT], ["panzer", "Andere greifen an", _F_KUPFER_HELL], ["buch", "Bericht für dich", _F_GOLD]]
	_zeige_tafel(conf)


## Sprüche der Myriaden und Tipps von Sonde 7 zur Niederlage, je nach dem Gegnertyp, der am häufigsten durchkam.
const _SPRUECHE := {
	"hund": ["Wuff. Das heißt auf Myriadisch: Danke für die offene Tür.", "Die Hunde lassen ausrichten: Eure Basis riecht jetzt nach uns."],
	"fahne": ["Unsere Fahne weht jetzt über eurer Basis. Steht ihr ausgezeichnet.", "Wir waren einfach schneller. Die Fahne hat's gemacht."],
	"sphaere": ["Battlesphären melden: Ziel erreicht. Euer Kaffee war leider kalt.", "Wir haben aus sicherer Entfernung zugesehen. Sehr unterhaltsam."],
	"sprenger": ["Eure Mauern waren wirklich hübsch. Waren.", "Kleiner Knall, große Wirkung. Danke fürs Zusammenstehen."],
	"schild": ["Von vorn, wie immer. Ihr hättet es mal von der Seite versuchen sollen.", "Klopf, klopf. Wer ist da? Ein Schild. Ein sehr großer Schild."],
	"schwarm": ["Erst waren wir einer. Dann drei. Dann waren wir überall.", "Ihr habt den Schwarmgeist besiegt. Seine Drohnen fanden das lustig."],
	"enterer": ["Erst waren wir einer. Dann drei. Dann waren wir überall.", "Myr-Drohnen sind klein. Aber sie sind viele. Und sie haben Hunger."],
	"belagerung": ["Danke für die schönen Wälle. Wir haben angedockt und es uns gemütlich gemacht.", "Ein Turm, ein Plan, eine offene Basis."],
	"rauch": ["Habt ihr uns gesehen? Nein? Genau das war der Plan.", "Ein bisschen Nebel, und schon zielt keiner mehr."],
	"sani": ["Wir sind zäher, als ihr dachtet. Unser Sanitäter auch.", "Jeder Kratzer geheilt. Jeder Durchbruch geschafft."],
}
const _SPRUCH_SONST := "Die Myriaden danken für eure Gastfreundschaft. Bis zur nächsten Partie!"
const _TIPPS := {
	"hund": "Rudel kommen schnell und in Massen: Plasmawerfer treffen die ganze Gruppe, ein Lanzenturm im langen Gang trifft alle in der Linie.",
	"fahne": "Fahnenträger zuerst ausschalten: Fällt die Fahne, wird der Trupp wieder langsam. Ein Frostturm bremst den ganzen Sturm.",
	"sphaere": "Battlesphären schießen auf Stellungen: Scharfschützen oder eine Batterie holen sie aus der Distanz.",
	"sprenger": "Sprenger stehen 1,7 s still, bevor es knallt: Scharfschützen an die Abkürzungen. Panzerung fängt die erste Sprengung ab.",
	"schild": "Schildträger halten nur von vorn: Knickt der Weg an deinen Schützen vorbei ab, trifft alles von der Seite voll.",
	"schwarm": "Schwarmgeister zerfallen in drei Drohnen: Flächenschaden hinter der Stelle, wo sie fallen, etwa ein Brandfeld.",
	"enterer": "Myr-Drohnen laufen auf Wällen: ein Heilturm mit Instandsetzung und Bodentruppen in der Nähe der Türme helfen.",
	"belagerung": "Belagerungstürme docken am ersten Wall an: Dort lohnen Schwere Munition oder eine Lanze.",
	"rauch": "Gegen Rauch: Peilsender am Funkturm oder Scharfschützen ab Stufe 2 (Klarsicht). Türme schießen sowieso weiter.",
	"sani": "Sanitäter heilen alle um sich: Mit Zielmarkierung oder Durchschuss fällt er zuerst.",
}
const _TIPP_SONST := "Ein Blick in die Schadensliste [Tab] zeigt, welche Fabrik kaum getroffen hat. Dort lohnt sich ein Umbau."


## 18.11.: Niederlage – mit Augenzwinkern: abgefangener Funkspruch der Myriaden und ein Tipp von Sonde 7.
func _zeige_niederlage(vw: String, rekord_vorher: int, besiegt: int) -> void:
	var meiste := ""
	for typ: String in _durch_typen:
		if meiste == "" or int(_durch_typen[typ]) > int(_durch_typen[meiste]):
			meiste = typ
	var sprueche: Array = _SPRUECHE.get(meiste, [_SPRUCH_SONST])
	var spruch: String = sprueche[randi() % sprueche.size()]
	if endkampf:
		spruch = "So nah an unserem HQ. Wir haben gezittert. Kurz."
	var sek := 0.0
	for r: Dictionary in _protokoll.get("runden", []):
		sek += float((r.get("ergebnis", {}) as Dictionary).get("sekunden", 0.0))
	var durch := {"name": "MEISTE DURCH", "text": "–", "farbe": _F_KUPFER}
	if meiste != "":
		durch["text"] = "%s ×%d" % [str(Werte.GEGNER[meiste]["kurz"]), int(_durch_typen[meiste])]
	var zeilen: Array = []
	if welle > rekord_vorher and rekord_vorher > 0:
		zeilen.append("Neuer Rekord: Runde %d (vorher %d)" % [welle, rekord_vorher])
	if vw != "":
		zeilen.append(vw)
	var untertitel := ["Die Myriaden sind durch.", "Das war knapp. Also, für die Myriaden nicht.", "Die Basis macht jetzt eine kurze Pause.", "Zurück auf Anfang – diesmal mit Plan."]
	if not Profil.phantom_frei() and phantom_modus == "" and welle >= 10 and not brakk_modus and not sandbox and herausforderung == "" and Werte.ist_hauptkarte():
		zeilen.append("Hältst du Runde 20, wird dein Bau zum Phantom für andere.")   # 23.11. (Einführung A)
	var tafel_conf := {
		"kicker": ("RUNDE %d · ENDLOS" % welle) if Werte.ziel() == "endlos" else ("RUNDE %d VON %d" % [welle, Werte.LETZTE_RUNDE]), "titel": "BASIS GEFALLEN" if leben <= 0 else "CHECKPOINTS VERLOREN", "titel_farbe": _F_ROT, "rahmen": _F_ROT,
		"untertitel": untertitel[randi() % untertitel.size()], "effekt": "asche", "glitch": true, "wackeln": true,
		"kacheln": [
			{"name": "ERREICHT", "zahl": welle, "max": Werte.LETZTE_RUNDE, "farbe": _F_ROT} if Werte.ziel() != "endlos" else {"name": "ERREICHT", "zahl": welle, "farbe": _F_ROT},
			{"name": "BESIEGT", "zahl": besiegt, "farbe": _F_KUPFER},
			durch,
			{"name": "KAMPFZEIT", "zahl": sek, "zeit": true, "farbe": _F_TEXT}],
		"kaesten": [
			{"titel": "ABGEFANGENER FUNKSPRUCH DER MYRIADEN", "farbe": _F_KUPFER, "text": "„%s“" % spruch, "tippen": true},
			{"titel": "SONDE 7 RÄT", "farbe": _F_LEUCHT, "text": str(_TIPPS.get(meiste, _TIPP_SONST))}],
		"zeilen": zeilen,
		"knoepfe": [["Revanche!", _neustart, _F_LEUCHT], ["Startmenü", _zum_menue, _F_TEXT]],
	}
	if phantom_modus == "verteidigung":
		var elo := _elo_platz("verteidigung")
		if not elo.is_empty():
			tafel_conf["elo"] = elo
	_zeige_tafel(tafel_conf)


## Merkt sich die Datei dieser Partie fürs Schlussbild (Herunterladen im Browser).
func _merke_export(daten: Dictionary, art: String) -> void:
	_export_text = JSON.stringify(daten, "\t")
	_export_name = "%s-%s.json" % [art, Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")]


func _export_datei() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_export_text.to_utf8_buffer(), _export_name, "application/json")
		_export_hinweis.text = "Heruntergeladen: %s – diese Datei an Paul schicken." % _export_name
	else:
		# Am PC liegt die Datei schon im Ordner „Phantom Dateien“: den Ordner zeigen
		var art := "angriff" if _export_name.begins_with("angriff") else "verteidigung"
		for o: String in Phantom.ordner(art):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(o)):
				OS.shell_open(ProjectSettings.globalize_path(o))
				_export_hinweis.text = "Die Datei liegt im geöffneten Ordner."
				return


func _ende_knopf(text: String, aktion: Callable, eltern: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(aktion)
	(eltern if eltern != null else _ende_knoepfe).add_child(b)
	return b


## Neustart ohne Umweg über das Menü. Die Partie ist da schon gespeichert (partien/, nach einem Sieg auch als Phantom).
func _neustart() -> void:
	if phase != Phase.ENDE:
		_angriff_aufgeben()   # 19.11.: Angriff abgebrochen – zählt für die Verteidigung
		_verteidigung_aufgeben()   # 23.11.
	loesche_sitzung()   # 19.11.
	if not sandbox and phantom_modus != "angriff":
		loesche_zwischenstand()   # 18.11.
	naechster_start = "angriff:" + _phantom_pfad if phantom_modus == "angriff" else ("brakk" if brakk_modus and Werte.modus() != "rogue" else "normal")   # 18.11.: Neustart bleibt im Brakk-Mode; 20.11. (Paul): Rogue bleibt Rogue (über das Regelpaket der Karte)
	Ladebild.lade(get_tree())   # 17.11.: Ladebild statt eingefrorenem Bild


## Knopf oben rechts: Partie abbrechen. Der erste Klick fragt nach, der zweite (innerhalb weniger Sekunden) geht ins Hauptmenü.
## Abgeschlossene Runden sind da schon im Bauprotokoll gespeichert.
func _abbruch_klick() -> void:
	if phase == Phase.ENDE or Time.get_ticks_msec() - _abbruch_ms <= ABRISS_FRIST_MS:
		_zum_menue()
		return
	_abbruch_ms = Time.get_ticks_msec()
	_btn_menue.text = "Abbrechen?"
	melde(("Test beenden und zurück in den Editor?" if SzenarioEditor.testet else "Partie abbrechen und zurück ins Hauptmenü?") + " Dann nochmal auf den Knopf klicken.", ABRISS_FRIST_MS / 1000.0)   # 20.11.


func _zum_menue() -> void:
	if phase != Phase.ENDE or (_tafel != null and _tafel.visible and not _angriff_fertig):
		_angriff_aufgeben()   # 19.11.: Angriff abgebrochen – zählt für die Verteidigung
	_verteidigung_aufgeben()   # 23.11.: Verteidigung abgebrochen – zählt für den Angriff
	loesche_sitzung()   # 19.11.
	if _menue == null and not sandbox and phantom_modus != "angriff":
		loesche_zwischenstand()   # 18.11.: bewusst verlassen – kein „Fortsetzen“ mehr
	naechster_start = ""
	if SzenarioEditor.testet:
		SzenarioEditor.testet = false   # 18.11.: „Szenario testen“ – zurück in den Editor
		naechster_start = "editor"
	Ladebild.lade(get_tree())   # 17.11.: Ladebild statt eingefrorenem Bild


## Bestätigung vor dem Seitenwechsel: kurz sagen, was der Angriffsmodus ist und was jetzt passiert.
func _frage_angriff() -> void:
	var zurueck := func(): _bestaetigung.visible = false
	(_bestaetigung as EndTafel).zeige({
		"kicker": "PHANTOM-MODUS", "titel": "IN DIE OFFENSIVE?", "titel_farbe": _F_KUPFER_HELL, "rahmen": _F_KUPFER_HELL,
		"untertitel": "Du wechselst die Seite.",
		"punkte": [
			["wall", "Ein Phantom verteidigt: der Bau eines anderen Spielers, Runde für Runde so, wie er damals stand."],
			["muenze", "Jede Runde ein festes Budget. Im Taktikplaner wählst du Einheiten, Reihenfolge, Pausen und Würfe."],
			["herz", "Nimm dem Phantom alle %d Leben – oder halte Runde 20 so lange wie möglich. Am Ende gibt es Punkte." % Werte.START_LEBEN]],
		"zeilen": ["Deine Partie ist gespeichert und steht ab jetzt selbst als Phantom im Pool."],
		"knoepfe": [["Ja, angreifen", _angriff_bestaetigt, _F_KUPFER_HELL], ["Zurück", zurueck, _F_TEXT]],
		"esc": zurueck,
	})


func _angriff_bestaetigt() -> void:
	naechster_start = "liste"
	Ladebild.lade(get_tree())   # 17.11.: Ladebild statt eingefrorenem Bild


# -------------------------------------------------------------- Bauprotokoll
# -------------------------------------------------------------- Bauprotokoll

const BAU_NAMEN := {Karte.WALL: "wall", Karte.FABRIK: "fabrik", Karte.STELLUNG: "stellung", Karte.TURM: "turm", Karte.BATTERIE: "batterie", Karte.TOR: "tor", Karte.PANZER: "panzer", Karte.SPIEGEL: "spiegel", Karte.MAGNET: "magnet", Karte.GENERATOR: "generator", Karte.KOMMANDANT: "kommandant"}


func _beginne_protokoll() -> void:
	var cps: Array = []
	for z in karte.checkpoints:
		cps.append([z.x, z.y])
	_protokoll = {"version": 2, "samen": Zufall.samen, "karte": Werte.karte_name, "begonnen": Time.get_datetime_string_from_system(), "checkpoints": cps, "runden": [], "anfuehrer": Werte.anfuehrer}   # 19.11.: Anführer
	_merke_code()   # 20.11.
	_protokoll_datei = "partie-%s.json" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")


## Eintrag der laufenden Bauphase (wird bei Bedarf angelegt).
func _runden_eintrag() -> Dictionary:
	var runden: Array = _protokoll["runden"]
	if runden.is_empty() or (runden[runden.size() - 1] as Dictionary).has("ergebnis"):
		runden.append({"runde": welle, "budget_vorher": budget, "aktionen": []})
	return runden[runden.size() - 1]


func _notiere(aktion: Dictionary) -> void:
	if protokoll_an and not _protokoll.is_empty():
		if phase == Phase.KAMPF:
			aktion["t"] = _kampf_tick   # 9a: Eingabe mitten in der Welle – das Replay setzt sie zum selben Bild ein
		(_runden_eintrag()["aktionen"] as Array).append(aktion)


## Ergebnis der Runde festhalten und das Protokoll speichern.
func _schliesse_runde(ausgang: String) -> void:
	if not protokoll_an or _protokoll.is_empty():
		return
	var eintrag := _runden_eintrag()
	eintrag["ergebnis"] = {
		"ausgang": ausgang,
		"leben": leben,
		"leben_verloren": _leben_vor_runde - leben,
		"budget_nachher": budget,
		"checkpoints_verloren": _cp_verloren,
		"checkpoints_am_ende_beim_gegner": karte.cp_feind.count(true),
		"fabriken": fabriken.size(),
		"waelle": karte.feld.values().count(Karte.WALL),
		"sekunden": snappedf((Time.get_ticks_msec() - _runde_start_ms) / 1000.0, 0.1),
	}
	if brakk_modus and kommandant != null and kommandant.fortschritt != null:
		eintrag["brakk"] = kommandant.fortschritt.protokoll.abschluss(self, kommandant, kommandant.fortschritt)   # 23.11.
	_speichere_protokoll()


## 23.11.: Ereignis für das Brakk-Protokoll (nur im Brakk-Mode).
func brakk_ereignis(art: String, daten: Dictionary = {}) -> void:
	if brakk_modus and kommandant != null and kommandant.fortschritt != null:
		kommandant.fortschritt.protokoll.ereignis(self, art, daten)


## 23.11.: Befehl 24 hat keine Runden – Abschnitte je Jagdwelle und am Ende (mit Brakk-Block) unter "befehl24".
func befehl24_protokoll(art: String, daten: Dictionary = {}) -> void:
	if not protokoll_an or _protokoll.is_empty() or order24 == null:
		return
	var e := {"t": snappedf(float(order24.zeit), 0.1), "a": art}
	e.merge(daten)
	if art in ["welle", "ende"] and kommandant != null and kommandant.fortschritt != null:
		e["brakk"] = kommandant.fortschritt.protokoll.abschluss(self, kommandant, kommandant.fortschritt)
	if not _protokoll.has("befehl24"):
		_protokoll["befehl24"] = []
	(_protokoll["befehl24"] as Array).append(e)
	_speichere_protokoll()


## 23.11.: Sieg-Bericht des Brakk-Mode mit ins Protokoll.
func brakk_bericht_merken(bericht: Dictionary) -> void:
	if not protokoll_an or _protokoll.is_empty():
		return
	_protokoll["brakk_bericht"] = bericht
	_speichere_protokoll()


## Im Editor landet die Datei im Projektordner unter partien/, sonst im Benutzerordner des Spiels.
func _speichere_protokoll() -> void:
	if ohne_spuren:
		return   # 9a: Werkzeuge/Labor schreiben nichts nach partien/ (das Protokoll bleibt im Speicher)
	var text := JSON.stringify(_protokoll, "\t")
	for ordner: String in ["res://partien", "user://partien"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ordner))
		var datei := FileAccess.open(ordner + "/" + _protokoll_datei, FileAccess.WRITE)
		if datei != null:
			datei.store_string(text)
			datei.close()
			return


# -------------------------------------------------------------- Zwischenstand (18.11.)
## Am Handy verwirft der Browser manchmal die Seite (Tab im Hintergrund, Speicher voll). Zu Beginn jeder Bauphase
## (ab Runde 2) wird der Stand gesichert; das Startmenü bietet dann „Fortsetzen“ an. Normales Spiel, Phantom-Verteidigung
## und (19.11.) Brakk-Mode – nicht Sandbox, Tutorial oder Phantom-Angriff. Gelöscht bei Sieg, Niederlage, Hauptmenü, Neustart.
## Der Bau kommt live von der Karte (das Protokoll kennt keine Sprengungen). Nicht gesichert: Werte je Bauwerk
## (Schaden/Kills), Lage der Schleudern (ziehen ohnehin jede Runde um).
const ZWISCHENSTAND := "user://zwischenstand.json"
## 9a: Werkzeuge (Replay, Labor) setzen das vor dem Start: kein Zwischenstand, kein Sitzungs-Merker – weder lesen
## noch schreiben noch loeschen. Sonst setzt das Startmenue die naechste Partie mit dem Stand der vorigen fort,
## und die echten Dateien des Spielers werden ueberschrieben.
static var ohne_spuren := false


static func lies_zwischenstand() -> Dictionary:
	if ohne_spuren or not FileAccess.file_exists(ZWISCHENSTAND):
		return {}
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(ZWISCHENSTAND))
	if daten is Dictionary:
		return daten
	return {}


## Runde des Zwischenstands, 0 = keiner (oder er passt nicht zur Kartengröße).
static func zwischenstand_runde() -> int:
	var d := lies_zwischenstand()
	if int(d.get("spalten", 0)) != Werte.SPALTEN or int(d.get("zeilen", 0)) != Werte.ZEILEN:
		return 0
	return int(d.get("welle", 0))


static func loesche_zwischenstand() -> void:
	if not ohne_spuren and FileAccess.file_exists(ZWISCHENSTAND):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ZWISCHENSTAND))


func _speichere_zwischenstand() -> void:
	if ohne_spuren or sandbox or phantom_modus == "angriff" or _protokoll.has("sandbox_sprung") or welle < 2 or phase != Phase.BAU:
		return
	if tutorial != null and is_instance_valid(tutorial):
		return
	var cps: Array = []
	for z in karte.checkpoints:
		cps.append([z.x, z.y])
	var d := {
		"version": 1, "gespeichert": Time.get_datetime_string_from_system(),
		"spalten": Werte.SPALTEN, "zeilen": Werte.ZEILEN, "karte": Werte.karte_name,
		"welle": welle, "leben": leben, "budget": budget, "freie_waelle": freie_waelle, "variante": variante,
		"basis": [karte.basis.x, karte.basis.y], "checkpoints": cps, "cp_feind": Array(karte.cp_feind),
		"stand": Phantom._stand(_zellen_jetzt(), _schilde_jetzt()),
		"kommandant": [kommandant.aufstellung.x, kommandant.aufstellung.y] if kommandant != null else [],
		"phantom_modus": phantom_modus, "angriff_pfad": _angriff_pfad, "herausforderung": herausforderung, "anfuehrer": Werte.anfuehrer,   # 19.11.
		"auftrag": auftrag, "auftrag_letzter": auftrag_letzter, "gratis_fabriken": gratis_fabriken,   # 20.11.
		"protokoll": _protokoll, "protokoll_datei": _protokoll_datei, "kills": _profil_kills,
	}
	if brakk_modus and kommandant != null and kommandant.fortschritt != null:
		_brakk_zwischenstand(d)   # 19.11.
	# erst in eine Zwischendatei, dann umbenennen: ein Absturz beim Schreiben lässt den alten Stand heil
	var tmp := ZWISCHENSTAND + ".tmp"
	var datei := FileAccess.open(tmp, FileAccess.WRITE)
	if datei == null:
		return
	datei.store_string(JSON.stringify(d))
	datei.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(ZWISCHENSTAND))


## 19.11.: Brakk-Mode im Zwischenstand – Brakks Fortschritt, gratis Stellungen; Fabriken im Ringfeld mit ihrem eigenen
## Stand (ohne Ring), beim Laden baut das Feld sie wieder um.
func _brakk_zwischenstand(d: Dictionary) -> void:
	d["brakk_modus"] = true
	d["brakk"] = kommandant.fortschritt.speichern()
	d["freie_stellungen"] = freie_stellungen
	var zellen := _zellen_jetzt()
	for z: Vector2i in zellen:
		if fabriken.has(z) and (fabriken[z] as Dictionary).has("ring_vorher"):
			var v: Dictionary = fabriken[z]["ring_vorher"]
			zellen[z]["einheit"] = str(v["typ"])
			zellen[z]["stufe"] = int(v["stufe"])
			zellen[z].erase("faehigkeit")
			if str(v["faehigkeit"]) != "":
				zellen[z]["faehigkeit"] = str(v["faehigkeit"])
	d["stand"] = Phantom._stand(zellen, _schilde_jetzt())


func _brakk_fortsetzen(d: Dictionary) -> void:
	if kommandant == null:
		return
	kommandant.fortschritt = BrakkFortschritt.new(kommandant)
	kommandant.fortschritt.lade(d.get("brakk", {}), kommandant)
	freie_stellungen = int(d.get("freie_stellungen", 0))
	_menue_weg()
	for i in 3:
		await get_tree().process_frame   # die HD-Ansicht entsteht erst im nächsten Bild
	if ego == null and hd != null and kommandant != null:
		_ego_umschalten()


## 19.11.: Diagnose – brach die letzte Sitzung ohne reguläres Ende ab (am Handy: Browser lädt die Seite neu)? Merker in
## user://, gesetzt zu jeder Welle und Bauphase, gelöscht bei Sieg, Niederlage, Neustart und Hauptmenü. Das Startmenü meldet
## ihn einmal.
const SITZUNG := "user://sitzung.json"


func _merke_sitzung(abschnitt: String) -> void:
	if ohne_spuren:
		return
	var modus := "Brakk-Mode" if brakk_modus else ("Sandbox" if sandbox else ("Phantom-" + phantom_modus if phantom_modus != "" else ("Tutorial" if tutorial != null else "Normales Spiel")))
	var datei := FileAccess.open(SITZUNG, FileAccess.WRITE)
	if datei != null:
		datei.store_string(JSON.stringify({"modus": modus, "runde": welle, "abschnitt": abschnitt, "zeit": Time.get_datetime_string_from_system()}))
		datei.close()


static func loesche_sitzung() -> void:
	if not ohne_spuren and FileAccess.file_exists(SITZUNG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SITZUNG))


## Abgebrochene Sitzung (einmal): {"modus", "runde", "abschnitt", "zeit"} oder {}; der Merker ist danach gelöscht.
static func abgebrochene_sitzung() -> Dictionary:
	if ohne_spuren or not FileAccess.file_exists(SITZUNG):
		return {}
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(SITZUNG))
	loesche_sitzung()
	return daten if daten is Dictionary else {}


## Der Bau, wie er gerade steht, im Format von Phantom._wende_an (Feld -> {"typ", ...}).
func _zellen_jetzt() -> Dictionary:
	var namen := {Karte.STELLUNG: "stellung", Karte.TURM: "turm", Karte.TOR: "tor", Karte.SPIEGEL: "spiegel", Karte.MAGNET: "magnet"}
	var zellen := {}
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		if typ == Karte.WALL:
			var w := {"typ": "wall", "ausbau": str(namen.get(karte.ausbau.get(z, -1), "")), "panzer": karte.panzer.has(z),
				"stufe": int(karte.turm_stufe.get(z, 1)), "faehigkeit": str(karte.turm_faehigkeit.get(z, ""))}
			if karte.mg_stufe.has(z):   # 20.11. (Paul): MG-Stellung – Stufe + 1 und Wahlen im selben Feld wie beim Turm
				w["stufe"] = int(karte.mg_stufe[z]) + 1
				w["faehigkeit"] = "|".join(PackedStringArray(karte.mg_wahl.get(z, [])))
			if karte.magnet_richtung.has(z):
				var r: Vector2i = karte.magnet_richtung[z]
				w["richtung"] = [r.x, r.y]
			zellen[z] = w
		elif typ == Karte.FABRIK and fabriken.has(z):
			var f: Dictionary = fabriken[z]
			var c := {"typ": "fabrik", "einheit": str(f["typ"]), "stufe": int(f.get("stufe", 0))}
			if f.has("faehigkeit"):
				c["faehigkeit"] = str(f["faehigkeit"])
			if f.has("ziel"):
				c["ziel"] = str(f["ziel"])
			if f.has("stellungen"):
				var liste: Array = []
				for s: Vector2i in f["stellungen"]:
					liste.append([s.x, s.y])
				c["stellungen"] = liste
			if karte.paar.has(z):
				c["partner"] = karte.paar[z]
			zellen[z] = c
		elif typ == Karte.BATTERIE and karte.paar.has(z):
			zellen[z] = {"typ": "batterie", "partner": karte.paar[z]}
		elif typ == Karte.GENERATOR and karte.generator_paar.has(z):
			var gp: Vector2i = karte.generator_paar[z]
			var vorne: bool = z.x < gp.x or (z.x == gp.x and z.y <= gp.y)
			zellen[z] = {"typ": "generator" if vorne else "generator_teil", "partner": gp}
	return zellen


## Schilde der Batterien im Format von Phantom._wende_an (Batterie -> [Erdwall, Erdwall]).
func _schilde_jetzt() -> Dictionary:
	var aus := {}
	for b: Vector2i in schilde:
		var s: Dictionary = schilde[b]
		aus[b] = [s["a"], s["e"]]
	return aus


## Startmenü → „Fortsetzen“: den gesicherten Stand hinstellen. Passt er nicht, beginnt eine neue Partie.
func _lade_zwischenstand() -> void:
	var d := lies_zwischenstand()
	if bool(d.get("brakk_modus", false)):
		brakk_modus = true   # 19.11.: wie _brakk_modus_gewaehlt – festes Tempo, HD-2D
		_tempo_faktor = Werte.BRAKK_TEMPO
		Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor
		Werte.setze_grafik("hd")
	herausforderung = str(d.get("herausforderung", ""))   # 18.11.
	Werte.herausforderung = herausforderung
	Werte.setze_anfuehrer(str(d.get("anfuehrer", "brakk")))   # 19.11.: alte Zwischenstände ohne Feld = Brakk
	var passt: bool = not d.is_empty() and int(d.get("spalten", 0)) == Werte.SPALTEN and int(d.get("zeilen", 0)) == Werte.ZEILEN \
			and str(d.get("karte", "paulland")) == Werte.karte_name
	if passt and str(d.get("phantom_modus", "")) == "verteidigung":
		passt = starte_phantom_verteidigung(str(d.get("angriff_pfad", "")))
	if not passt:
		loesche_zwischenstand()
		_normales_spiel()
		melde("Der Zwischenstand ließ sich nicht laden – eine neue Partie beginnt.", 6.0)
		return
	setze_checkpoints(d["checkpoints"])
	var bz: Array = d["basis"]
	setze_basis(Vector2i(int(bz[0]), int(bz[1])))
	_protokoll = d["protokoll"]
	Zufall.samen = int(_protokoll.get("samen", Zufall.samen))   # 9a: Fortsetzen mit dem Samen der Partie
	_protokoll["anfuehrer"] = Werte.anfuehrer   # 19.11.
	_merke_code()   # 20.11.
	_protokoll_datei = str(d["protokoll_datei"])
	_profil_kills = d.get("kills", {})
	_setze_stand(d["stand"])
	for z: Vector2i in Werte.MAUERN + (Werte.MAUERN_FEST if herausforderung == "mauern_fest" else ([] as Array[Vector2i])):   # 18.11.: vorgebaute Mauern bleiben nicht abreißbar
		if karte.inhalt(z) == Karte.WALL:
			karte.fest[z] = true
	_markiere_kartenbauten()   # 18.11.: vorgebaute Türme/Fabriken eines Szenarios
	var kz: Array = d.get("kommandant", [])
	if kz.size() == 2:
		_setze_kommandant(Vector2i(int(kz[0]), int(kz[1])))
	# wie nach einer geschafften Runde: welle eins davor, dann die Bauphase regulär herrichten
	welle = int(d["welle"]) - 1
	_naechste_bauphase()
	leben = int(d["leben"])
	budget = int(d["budget"])
	var gesichert: Variant = d.get("auftrag", {})   # 20.11.: Pauls Auftrag der Bauphase (nicht neu ziehen)
	auftrag = (gesichert as Dictionary) if gesichert is Dictionary else {}
	auftrag_letzter = str(d.get("auftrag_letzter", ""))
	gratis_fabriken = int(d.get("gratis_fabriken", 0))
	if not auftrag.has("liste"):
		auftrag = {}   # Spielstand im alten Format (ein einzelner Auftrag)
	freie_waelle = int(d.get("freie_waelle", 0))
	variante = int(d.get("variante", 0))
	karte.cp_aktiv = Werte.plan_runde(welle) >= Werte.CHECKPOINTS_AB_WELLE   # _naechste_bauphase schaltet sie nur genau in dieser Runde an
	var feind: Array = d.get("cp_feind", [])
	for i in mini(feind.size(), karte.cp_feind.size()):
		karte.cp_feind[i] = bool(feind[i])
	karte.aktualisiere_pfad()
	karte.queue_redraw()
	if brakk_modus:
		_brakk_fortsetzen(d)   # 19.11.
	_speichere_zwischenstand()
	melde("Partie fortgesetzt: Runde %d." % welle, 5.0)


## Für das Nachspielen: Checkpoints auf die Felder der aufgezeichneten Partie setzen.
## Sandbox: Wo steht die eigene Basis? "fest" = alter Platz, "rechts" = zufällig im rechten Drittel,
## "ueberall" = zufällig mit Mindestabstand zum HQ des Gegners, "klick" = der nächste Linksklick auf die Karte setzt sie.
const BASIS_SPALTE_RECHTS: int = 15     # "rechts": ab dieser Spalte
const BASIS_ABSTAND_HQ: float = 8.0     # "ueberall": so weit (Felder) vom HQ des Gegners entfernt
const BASIS_ABSTAND_CP: float = 3.0     # zufällige Basis: so weit von jedem Checkpoint entfernt
var basis_art := "fest"
var _setze_basis := false

func sandbox_basis(art: String) -> void:
	if not sandbox or phase != Phase.BAU:
		return
	stelle_basis(art)


## Basis versetzen: "fest", "rechts", "ueberall" (zufällig) oder "klick" (nächster Linksklick).
func stelle_basis(art: String) -> void:
	_setze_basis = art == "klick"
	if art == "klick":
		melde("Basis setzen: Klick auf ein freies Feld. Rechtsklick bricht ab.", 6.0)
		return
	if art == "fest":
		if not setze_basis(Werte.BASIS_ZELLE):
			melde("Der alte Platz der Basis ist bebaut.", 4.0)
			return
	else:
		var felder: Array[Vector2i] = []
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if z == karte.basis or not _basis_moeglich(z):
					continue
				if art == "rechts" and x < roundi(BASIS_SPALTE_RECHTS * Werte.KARTE_FAKTOR):
					continue
				if art == "ueberall" and Vector2(z - Werte.START_ZELLE).length() < BASIS_ABSTAND_HQ * Werte.KARTE_FAKTOR:
					continue
				if art == "ueberall" and not sandbox and (x - 1) * 2 < Werte.SPALTEN:
					continue   # 19.11. (Paul): im Spiel steht die Basis ganz in der rechten Kartenhälfte (alle 3 Spalten); Sandbox bleibt frei
				if art == "ueberall" and not sandbox and brakk_modus and order24 == null and float(x - 1) < Werte.SPALTEN * Werte.BRAKK_BASIS_AB_ANTEIL:
					continue   # 22.11. (Paul): Brakk-Mode – ganz im letzten Drittel, damit die Gegner nicht zu schnell durchkommen
				var nah := false
				for cp in karte.checkpoints:
					if Vector2(z - cp).length() < BASIS_ABSTAND_CP:
						nah = true
				if not nah:
					felder.append(z)
		if felder.is_empty():
			melde("Kein freies Feld für die Basis gefunden.", 4.0)
			return
		setze_basis(felder[Zufall.ganz(felder.size())])
	basis_art = art


## Die Basis belegt 3×2 Felder (Karte.basis_felder): alle müssen frei, in der Karte und außerhalb der Zone sein.
func _basis_moeglich(z: Vector2i) -> bool:
	for c in Karte.basis_felder(z):
		if not karte.in_karte(c) or c.x < Werte.ZONE_SPALTEN or not karte.ist_frei(c) or karte.checkpoints.has(c):
			return false
	return true


## Rückt ein Basisfeld so weit nach innen, dass die 3×2 Felder in die Karte passen (alte Partien hatten die Basis am Rand).
func basis_einpassen(z: Vector2i) -> Vector2i:
	return Vector2i(clampi(z.x, Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 2), clampi(z.y, 1, Werte.ZEILEN - 1))


## Versetzt die eigene Basis auf ein freies Feld. false, wenn das Feld nicht geht.
func setze_basis(z: Vector2i) -> bool:
	z = basis_einpassen(z)
	if z != karte.basis and not _basis_moeglich(z):
		return false
	karte.basis = z
	_protokoll["basis"] = [z.x, z.y]
	karte.aktualisiere_pfad()
	karte.queue_redraw()
	return true


## Sandbox: Gegnerweg schon ab Runde 1 durch die Checkpoints (eingenommen werden sie weiter erst ab CHECKPOINTS_AB_WELLE).
func sandbox_cp_route(an: bool) -> void:
	karte.cp_route = an
	karte.aktualisiere_pfad()
	karte.queue_redraw()


func setze_checkpoints(felder: Array) -> void:
	for i in mini(felder.size(), karte.checkpoints.size()):
		karte.checkpoints[i] = Vector2i(int(felder[i][0]), int(felder[i][1]))
	karte.aktualisiere_pfad()


func im_kampf() -> bool:
	return phase == Phase.KAMPF


func im_endkampf() -> bool:
	return endkampf


## Stellt HQ und fällige Schleudern in die Zone. Gibt true zurück, wenn eine Schleuder dazukam.
var _zone_gebaut: Dictionary = {}   # Nummer in Werte.ZONENBAUTEN -> steht schon

func _aktualisiere_zone() -> bool:
	var neu := false
	if hq == null:
		hq = _neuer_zonenbau("hq", Werte.START_ZELLE)
	for nr in Werte.ZONENBAUTEN.size():
		var s: Dictionary = Werte.ZONENBAUTEN[nr]
		if (welle if s["art"] == "laser" else Werte.plan_runde(welle)) < int(s["ab_welle"]) or _zone_gebaut.has(nr):   # 20.11.: Laser nach der echten Runde, alles andere nach dem Plan
			continue
		# Merken, was schon steht: Schleudern ziehen um, ihr Feld sagt also nichts mehr aus.
		_zone_gebaut[nr] = true
		_neuer_zonenbau(s["art"], s["zelle"])
		neu = true
	return neu


func _neuer_zonenbau(art: String, zelle: Vector2i) -> Zonenbau:
	var b := Zonenbau.new()
	figuren.add_child(b)
	b.start(self, karte, art, zelle)
	zonenbauten.append(b)
	return b


## Startfeld für den nächsten Gegner: irgendwo in der Zone (verteilt, nicht gebündelt) –
## oder der eingenommene Checkpoint, an dem die Welle startet.
func _spawn_zelle() -> Vector2i:
	if not _ausgaenge.is_empty() and str(_ausgaenge[0]) == "zone2" and not Werte.ZONE2_AUSGAENGE.is_empty():
		return Zufall.waehle(Werte.ZONE2_AUSGAENGE)   # 20.11. (Zange): zweite Hälfte des Trupps aus der zweiten Zone
	if phantom_modus != "" or Werte.KARTE_WELLEN.has(welle):   # 18.11.: eigene Wellen eines Szenarios kommen wie geplant
		# Phantom-Modus: jeder Trupp kommt geschlossen an seinem Ausgang heraus, damit die geplante Reihenfolge hält.
		# 16.11.: Ein gewählter Ausgang (oben/unten) gilt immer – auch wenn ein eingenommener Checkpoint sonst der
		# Startpunkt wäre. Nur „Mitte“ startet dann am Checkpoint.
		var ausgang := str(_ausgaenge[0]) if not _ausgaenge.is_empty() else ""
		if ausgang == "" and _start_zelle == Werte.START_ZELLE and not Werte.EINGAENGE.is_empty():
			return _naechster_eingang()   # 20.11.: Karte mit Eingängen
		if ausgang != "" or _start_zelle == Werte.START_ZELLE:
			return Werte.AUSGAENGE.get(ausgang, Werte.START_ZELLE)
		return _start_zelle
	if _start_zelle != Werte.START_ZELLE:
		return _start_zelle
	if not Werte.EINGAENGE.is_empty():
		return _naechster_eingang()   # 20.11.: Karte mit Eingängen – nur dort, abwechselnd
	if Werte.plan_runde(welle) <= Werte.HAUPTLINIE_BIS:
		return Werte.START_ZELLE   # die ersten Runden: alle über die Hauptlinie, nichts verteilt sich
	return Vector2i(Zufall.ganz(Werte.ZONE_SPALTEN), Zufall.ganz(Werte.ZEILEN))


## 20.11. (Schritt 5b, Zange): Jeder Trupp mit mindestens zwei Mitgliedern wird nach Köpfen halbiert; die zweite Hälfte
## kommt gleichzeitig aus der zweiten Zone. Einzelne (Belagerungsturm) wechseln sich ab.
func _zange_teilen() -> void:
	var s: Array = []
	var p: Array = []
	var a: Array = []
	var l: Array = []
	var einzeln := 0
	for i in _schlange.size():
		var typen: Array = _schlange[i]
		if typen.size() < 2:
			s.append(typen)
			p.append(_pausen[i])
			a.append("zone2" if einzeln % 2 == 1 else str(_ausgaenge[i]))
			l.append(_locker[i])
			einzeln += 1
			continue
		var haelfte := ceili(typen.size() / 2.0)
		s.append(typen.slice(0, haelfte))
		p.append(_pausen[i])
		a.append(str(_ausgaenge[i]))
		l.append(_locker[i])
		s.append(typen.slice(haelfte))
		p.append(-Werte.TRUPP_PAUSE)   # gleich hinterher: beide Hälften sind zur selben Zeit unterwegs
		a.append("zone2")
		l.append(_locker[i])
	_schlange = s
	_pausen = p
	_ausgaenge = a
	_locker = l


## 20.11. (Zange): Aus der zweiten Zone geht es nur über Checkpoint 2, aus der linken nur über Checkpoint 1.
func _zange_route(g: Gegner) -> void:
	if Werte.in_zone2(karte.zelle_bei(g.position)):
		g._ziel = maxi(g._ziel, 1)
	else:
		g.ohne_cp = 1
	g.plane_neu()


## 20.11.: Eingänge reihum – die Gegner einer Welle teilen sich auf alle Eingänge auf.
var _eingang_nr := 0

func _naechster_eingang() -> Vector2i:
	_eingang_nr += 1
	return Werte.EINGAENGE[_eingang_nr % Werte.EINGAENGE.size()]


# ------------------------------------------------------------------ Ablauf

var _zieh_von := Karte.KEINE   # Fabrik, von der gerade ein Zuweisungspfeil gezogen wird
var _wall_letzte := Karte.KEINE   # letztes Feld beim Wall-Ziehen (Lücken dazwischen werden aufgefüllt)
var kommandant: Kommandant = null   # Brakk, einmal pro Partie
var klonmaschine: Klonmaschine = null
var schuss_herkunft := Vector2.INF   # woher der gerade ausgeteilte Schaden kommt (Schildträger); INF = Fläche/unbekannt
var _trupp_zelle := Vector2i.ZERO   # Startfeld des Trupps, der gerade entsteht


func _aktualisiere_zuweisung() -> void:
	var f := Karte.KEINE
	if _fabrikmenue != null and _fabrikmenue.visible and fabriken.has(_fabrikmenue.zelle):
		f = _fabrikmenue.zelle
	elif _zieh_von != Karte.KEINE and fabriken.has(_zieh_von):
		f = _zieh_von   # Tafel beim Pfeilziehen ausgeblendet: die Zuweisungen bleiben sichtbar
	var ziele: Array = zugewiesen(f) if f != Karte.KEINE else []
	if f != karte.zuweis_fabrik or ziele != karte.zuweis_ziele:
		karte.zuweis_fabrik = f
		karte.zuweis_ziele = ziele
		karte.queue_redraw()


var kamera_2d: Kamera2D = null
var _zoomregler: VSlider
var _zoom_grund: Control
var _ansicht_knopf: Button
var _sandbox_leiste: Control


## Zoom-Regler rechts am Rand (16.11.): oben = nah, unten = ganze Karte. Gilt für HD-2D und die 2D-Kamera; das Mausrad stellt ihn mit.
func _baue_zoomregler(ebene: CanvasLayer) -> void:
	var grund := PanelContainer.new()
	grund.position = Vector2(1236, 250)
	grund.size = Vector2(36, 210)
	_zoom_grund = grund
	grund.mouse_filter = Control.MOUSE_FILTER_STOP
	# 18.11.: im Stil des HUD (Metall, Leuchtblau) statt runder Standard-Box
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.11, 0.125, 0.15, 0.88)
	stil.border_color = Color("4a515e")
	stil.set_border_width_all(2)
	stil.set_content_margin_all(3)
	grund.add_theme_stylebox_override("panel", stil)
	ebene.add_child(grund)
	var spalte := VBoxContainer.new()
	spalte.alignment = BoxContainer.ALIGNMENT_CENTER
	grund.add_child(spalte)
	# Ansicht kippen (Draufsicht [V], nur HD-2D) – oben am Regler, damit man sie findet (16.11.)
	_ansicht_knopf = Button.new()
	_ansicht_knopf.text = "V"
	_ansicht_knopf.tooltip_text = "Draufsicht / schräge Ansicht [V]"
	_ansicht_knopf.focus_mode = Control.FOCUS_NONE
	_ansicht_knopf.add_theme_color_override("font_color", Color("7fe0ff"))
	_ansicht_knopf.pressed.connect(func():
		if hd != null:
			hd.draufsicht_umschalten())
	spalte.add_child(_ansicht_knopf)
	var plus := Button.new()
	plus.text = "+"
	plus.focus_mode = Control.FOCUS_NONE
	plus.flat = true
	spalte.add_child(plus)
	_zoomregler = VSlider.new()
	_zoomregler.min_value = 0.0
	_zoomregler.max_value = 1.0
	_zoomregler.step = 0.01
	_zoomregler.custom_minimum_size = Vector2(20, 130)
	_zoomregler.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zoomregler.focus_mode = Control.FOCUS_NONE
	_zoomregler.tooltip_text = "Zoom (auch Mausrad)"
	spalte.add_child(_zoomregler)
	var minus := Button.new()
	minus.text = "−"
	minus.focus_mode = Control.FOCUS_NONE
	minus.flat = true
	spalte.add_child(minus)
	for b: Button in [_ansicht_knopf, plus, minus]:
		_hud_knopf_stil(b)
	var spur := StyleBoxFlat.new()
	spur.bg_color = Color("15171c")
	spur.border_color = Color("4a515e")
	spur.set_border_width_all(1)
	spur.content_margin_left = 3
	spur.content_margin_right = 3
	var fuellung := StyleBoxFlat.new()
	fuellung.bg_color = Color(_F_LEUCHT, 0.35)
	_zoomregler.add_theme_stylebox_override("slider", spur)
	_zoomregler.add_theme_stylebox_override("grabber_area", fuellung)
	_zoomregler.add_theme_stylebox_override("grabber_area_highlight", fuellung)
	var griff := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	griff.fill(_F_LEUCHT)
	griff.fill_rect(Rect2i(1, 1, 10, 4), Color("2a2f38"))
	griff.fill_rect(Rect2i(3, 2, 6, 2), _F_LEUCHT)
	var griff_tex := ImageTexture.create_from_image(griff)
	for name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		_zoomregler.add_theme_icon_override(name, griff_tex)
	_zoomregler.value_changed.connect(_zoom_gestellt)
	plus.pressed.connect(func(): _zoomregler.value = minf(1.0, _zoomregler.value + 0.2))
	minus.pressed.connect(func(): _zoomregler.value = maxf(0.0, _zoomregler.value - 0.2))


## 18.11.: kleiner HUD-Knopf (Zoom-Leiste): Metallfläche, Leuchtrand beim Darüberfahren, Pixelschrift.
func _hud_knopf_stil(b: Button) -> void:
	b.flat = false
	b.custom_minimum_size = Vector2(26, 22)
	var flaechen := {"normal": [Color("2a2f38"), Color("4a515e")], "hover": [Color(_F_LEUCHT, 0.18), _F_LEUCHT], "pressed": [Color(_F_LEUCHT, 0.32), _F_LEUCHT]}
	for zustand: String in flaechen:
		var sb := StyleBoxFlat.new()
		sb.bg_color = flaechen[zustand][0]
		sb.border_color = flaechen[zustand][1]
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(zustand, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", preload("res://scripts/ui/ui_stil.gd").schrift_fuer(25))
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", _F_LEUCHT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


## 0 = ganz heraus, 1 = ganz nah (für die Kampfgeräusche).
func zoom_anteil() -> float:
	if hd != null:
		return hd.zoom_anteil()
	if kamera_2d != null:
		return kamera_2d.zoom_anteil()
	return 1.0


func _zoom_gestellt(anteil: float) -> void:
	if hd != null:
		hd.setze_zoom_anteil(anteil)
	elif kamera_2d != null:
		kamera_2d.setze_zoom_anteil(anteil)


var _laufband_vor_pause := false


func _zoomregler_nachziehen() -> void:
	if _zoomregler == null:
		return
	# solange ein Fenster offen ist (Ankerfenster, Übersicht, Formationen, Pause), stört der Regler nur (16.11.)
	_ansicht_knopf.visible = hd != null
	# 18.11. (Paul): Pause-Menü oder Startmenü offen – der Taktikplaner verschwindet und kommt danach wieder
	if _laufband != null:
		var verdeckt: bool = _hud.pausiert() or _menue != null
		if verdeckt and _laufband.visible:
			_laufband.visible = false
			_laufband_vor_pause = true
		elif not verdeckt and _laufband_vor_pause:
			_laufband_vor_pause = false
			_laufband.visible = true
	_zoom_grund.visible = not (_fabrikmenue.visible or _lexikon.visible or _nachschlag.visible or _hud.pausiert() \
		or (_ende != null and _ende.visible) or (_laufband != null and _laufband.visible))
	# rechts am Rand – neben der Sandbox-Leiste, wenn die offen ist
	var x := 1236.0
	if is_instance_valid(_sandbox_leiste) and _sandbox_leiste.is_visible_in_tree() and _sandbox_leiste._offen:
		x = minf(x, _sandbox_leiste.position.x - 42.0)   # 18.11.: eingeklappt liegt nur der Kopf oben – dann ganz an den Rand
	_zoom_grund.position.x = x if absf(_zoom_grund.position.x - x) < 1.0 else lerpf(_zoom_grund.position.x, x, 0.25)
	var a := -1.0
	if hd != null:
		a = hd.zoom_anteil()
	elif kamera_2d != null:
		a = kamera_2d.zoom_anteil()
	if a >= 0.0 and not _zoomregler.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_zoomregler.set_value_no_signal(a)


func _process(delta: float) -> void:
	schuss_herkunft = Vector2.INF
	if Werte.grafik_neu:
		_turmbilder_abgleichen()
	elif not turmbilder.is_empty():
		for t in turmbilder.values():
			(t as Node).queue_free()
		turmbilder.clear()
	if Werte.grafik_hd != (hd != null):
		# Grafik im Startmenü umgestellt: 3D-Ansicht an- bzw. abbauen
		if hd == null:
			hd = HdAnsicht.new()
			add_child(hd)
			hd.einrichten(self)
		else:
			hd.queue_free()
			hd = null
	if (hd == null) != (kamera_2d != null):
		# 2D-Kamera: schwenkt und zoomt auf der großen Karte (auf der normalen steht sie fest)
		if kamera_2d == null:
			kamera_2d = Kamera2D.new()
			kamera_2d.spiel = self
			add_child(kamera_2d)
		else:
			kamera_2d.queue_free()
			kamera_2d = null
	_zoomregler_nachziehen()
	_aktualisiere_zuweisung()
	schadensquelle = ""   # wer gerade Schaden macht, setzt sich selbst (Truppe, Turm, Batterie, Brandfeld)
	schuetze = null
	_aktualisiere_vorschau()
	_aktualisiere_sichtanzeige()
	_bauzeit_tick(delta)
	_aktualisiere_hud(delta)
	_pflege_schilde()
	# 22.11.: Brakk-Mode – doppelt so lange Schritte, und ein langsames Bild holt höchstens BRAKK_MAX_SCHRITTE nach
	Werte.sim_mal = Werte.BRAKK_SIM_MAL if brakk_modus else 1
	Engine.max_physics_steps_per_frame = Werte.BRAKK_MAX_SCHRITTE if brakk_modus else 8
	# 9a: Tempo (Taste F, Brakk-Mode, Zeitlupe) wirkt ueber die Zahl der Simulationsschritte je Sekunde, nicht ueber ihre Laenge
	Engine.physics_ticks_per_second = maxi(1, roundi(60.0 * Engine.time_scale / Werte.SPIELTEMPO / float(Werte.sim_mal)))


## 9a: Kampf-Simulation mit fester Schrittweite (Werte.SIM_SCHRITT). Tempo x3 = dreimal so viele Schritte je Sekunde,
## nicht dreimal so grosse – so verlaeuft eine Partie bei jedem Tempo und jeder Bildrate gleich.
func _physics_process(_takt: float) -> void:
	if phase != Phase.KAMPF:
		return
	var delta := Werte.sim_schritt()   # 22.11.: im Brakk-Mode doppelt so lang
	schuss_herkunft = Vector2.INF
	schadensquelle = ""
	schuetze = null
	_pflege_schilde()
	_kampf_tick += 1
	_abstand_halten(delta)

	if endkampf and _schlange.is_empty():
		# letzte Runde: nach kurzer Pause beginnt dieselbe Reihe Trupps von vorn
		_lade_durchgang()
		_spawn_in = Werte.ENDKAMPF_PAUSE
	if not _schlange.is_empty():
		_spawn_in -= delta
		if _spawn_in <= 0.0:
			var typen: Array = _schlange[0]
			var typ: String = typen.pop_front()
			if _trupp.is_empty():
				_trupp_zelle = _spawn_zelle()   # gebündelt: der ganze Trupp startet am selben Fleck
			var g := _neuer_gegner(typ, _trupp_zelle, _erstes_ziel)
			if Werte.ZONE2.size != Vector2i.ZERO and karte.checkpoints.size() >= 2:
				_zange_route(g)   # 20.11. (Zange)
			g.trupp = _trupp
			_trupp.append(g)
			# In der Zone wartet der Trupp, bis er vollständig ist, und läuft dann gemeinsam los
			g.wartet = not typen.is_empty() and _trupp_zelle.x < Werte.ZONE_SPALTEN
			if typen.is_empty():
				# Trupp vollständig: Schildträger gehen vor, der Rest folgt ein paar Sekunden später
				var mit_schild := false
				for m in _trupp:
					if is_instance_valid(m) and m.rolle == "schild":
						mit_schild = true
				# 16.11.: große Trupps gehen gestaffelt los (Kolonne statt Klumpen), Schildträger zuerst
				# 17.11.: lockere Formation mit deutlich mehr Abstand (gegen Flächenschaden)
				var ist_locker := not _locker.is_empty() and bool(_locker[0])
				var staffel := Werte.LOCKER_STAFFEL_SEK if ist_locker else Werte.TRUPP_STAFFEL_SEK
				if brakk_modus:
					staffel *= BRAKK_ABSTAND_MAL   # 18.11. (Paul): Brakk-Mode – enger beisammen
				for m in _trupp:
					if is_instance_valid(m):
						m.locker = ist_locker
				var k := 0
				for m in _trupp:
					if is_instance_valid(m):
						if mit_schild and m.rolle != "schild" and _trupp_zelle.x < Werte.ZONE_SPALTEN:
							m.warte_noch = Werte.SCHILD_VORLAUF_SEK
						if _trupp_zelle.x < Werte.ZONE_SPALTEN and m.rolle != "schild":
							m.warte_noch += k * staffel
							k += 1
						m.wartet = false
				# Trupp vollständig: nach einer Pause kommt der nächste (der Plan kann sie verlängern oder kürzen)
				_schlange.pop_front()
				_pausen.pop_front()
				if not _ausgaenge.is_empty():
					_ausgaenge.pop_front()
				if not _locker.is_empty():
					_locker.pop_front()
				_trupp = []
				_trupp_nr += 1
				_spawn_in += Werte.ENDKAMPF_TRUPP_PAUSE if endkampf else Werte.TRUPP_PAUSE
				if not _pausen.is_empty():
					_spawn_in = maxf(_spawn_in + float(_pausen[0]), 0.6)
				if brakk_modus:
					_spawn_in = maxf(_spawn_in * BRAKK_PAUSE_MAL, 0.4)   # 18.11. (Paul): Brakk-Mode – kürzere Pausen
			else:
				_spawn_in += _welle["abstand"]
	_wurf_tick(delta)
	if OS.get_environment("TD_CP_LOG") != "" and welle == int(OS.get_environment("TD_CP_LOG")) and Engine.get_process_frames() % 240 == 0:
		var zeilen := []
		for e in einheiten:
			zeilen.append("%s%s@%s->%s%s" % [e.daten["name"].substr(0, 4), ["Z", "P", "B", "I"][e.zustand], karte.zelle_bei(e.position), e._marschziel, "*" if ist_einnehmer(e) else ""])
		print("CP t=%.0f feind=%s ruhig=%s gegner=%d | %s" % [_kampf_sek, karte.cp_feind, karte.checkpoints.map(func(c): return ist_ruhig(karte.mitte(c), Werte.CHECKPOINT_RUHE * Werte.ZELLE)), gegner.size(), " ".join(zeilen)])
	for z: Vector2i in _ausfall_zeit.keys():
		_ausfall_zeit[z] = float(_ausfall_zeit[z]) - delta
		if _ausfall_zeit[z] <= 0.0 or not karte.ausgefallen.has(z):
			_ausfall_zeit.erase(z)
			if karte.ausgefallen.has(z):
				repariere(z, true)

	for z: Vector2i in fabriken:
		var f: Dictionary = fabriken[z]
		if karte.ausgefallen.has(z):
			f["timer"] = 0.0   # zerschossen: produziert bis zum Ende der Runde nichts
			continue
		if (f["einheiten"] as Array).size() >= truppen_limit(z):
			f["timer"] = 0.0
			karte.fortschritt[z] = 1.0
			continue
		f["timer"] += delta
		karte.fortschritt[z] = f["timer"] / produktion_sek()
		if f["timer"] >= produktion_sek():
			f["timer"] = 0.0
			var e := Einheit.new()
			figuren.add_child(e)
			e.start(self, karte, f["typ"], z, int(f.get("stufe", 0)), str(f.get("faehigkeit", "")))
			if brakk_modus and int(f.get("stufe", 0)) >= 1:
				e.max_leben *= BRAKK_STUFE1_LEBEN   # 19.11. (Paul): statt der dritten Truppe
				e.leben = e.max_leben
			if brakk_modus and str(f.get("ring", "")) == "plasmagel":
				e.daten["schaden"] = float(e.daten["schaden"]) * BRAKK_GEL_FELD_SCHADEN   # 19.11. (Paul, Bot-Partien): Gel-Feld war am stärksten
			if order24 != null:
				order24.neue_einheit(e)   # 20.11. (Paul): Befehl 24 – Truppen schwächer
			einheiten.append(e)
			(f["einheiten"] as Array).append(e)

	_kampf_sek += delta
	_braende_wirken(delta)
	_tuerme_feuern(delta)
	_mg_huelsen_wirken(delta)   # 20.11. (Paul): MG-Stellung, Hülsenregen
	_mg_besetzt_zeigen()
	_magnete_ziehen(delta)
	_batterien_feuern(delta)
	_checkpoints_halten(delta)
	_minen_pruefen()

	# Sprenger sichtbar machen: ihr Ziel blinkt während der Runde
	var ziele: Array[Vector2i] = []
	for g in gegner:
		if g.rolle == "sprenger" and g.sprengt() != Karte.KEINE:
			ziele.append(g.sprengt())
	karte.sprengziele_aktiv = ziele

	if not endkampf and _schlange.is_empty() and _wurf_schlange.is_empty() and _wurf_aktiv.is_empty() and gegner.is_empty() and _im_flug == 0 and phase == Phase.KAMPF:
		# Kein Gegner mehr da: Die zugeteilte Truppe bekommt noch etwas Zeit, einen verlorenen Checkpoint zurückzuholen.
		if _nachspiel < Werte.NACHSPIEL_MAX and _truppe_kann_checkpoint_holen():
			if _nachspiel == 0.0:
				melde("Eine Truppe holt den verlorenen Checkpoint zurück ...", 4.0)
			_nachspiel += delta
			return
		if OS.get_environment("TD_CP_LOG") != "" and karte.cp_feind.has(true):
			var zeilen := []
			for e in einheiten:
				zeilen.append("%s%s@%s->%s%s L%d" % [e.daten["name"].substr(0, 4), ["Z", "P", "B", "I"][e.zustand], karte.zelle_bei(e.position), e._marschziel, "*" if ist_einnehmer(e) else "", e.leben])
			print("ENDE R%d nachspiel=%.1f feind=%s kann=%s | %s" % [welle, _nachspiel, karte.cp_feind, _truppe_kann_checkpoint_holen(), " ".join(zeilen)])
		_welle_geschafft()


## Gibt es einen vom Gegner gehaltenen Checkpoint, zu dem eine freie Bodentruppe einen Weg hat?
func _truppe_kann_checkpoint_holen() -> bool:
	if not karte.cp_aktiv:
		return false
	for i in karte.checkpoints.size():
		if not karte.cp_feind[i]:
			continue
		for e in einheiten:
			# Sind alle Gegner weg, darf auch eine Truppe aus einer Stellung gehen (siehe raeumen()).
			if e.in_batterie() or e.daten.get("pilot", false):
				continue
			var hier := karte.zelle_bei(e.position)
			if hier == karte.checkpoints[i] or not karte.einheiten_weg(hier, karte.checkpoints[i]).is_empty():
				return true
	return false


## Kein Gegner mehr auf dem Feld und keiner mehr unterwegs: Jetzt holt die nächste Truppe einen verlorenen Checkpoint
## zurück – notfalls verlässt sie dafür ihre Stellung. Sonst startet die nächste Welle von dort.
## Aufräumen: Darf diese Truppe ihre Stellung verlassen? Nur für Gegner, die feststehen oder die niemand mehr trifft,
## und höchstens AUFRAEUM_JAEGER_JE_GEGNER Truppen je solchem Gegner (15.11.: vorher stieg jede Truppe ohne Ziel ab).
var _jaeger: Array = []

func darf_absteigen(e: Einheit) -> bool:
	var ziele := 0
	for g in gegner:
		if not _geschuetzt(g) and g.rest_weg() < (1 << 20) and g.draussen >= Werte.AUFRAEUM_DRAUSSEN_SEK and (g._stand >= Werte.AUFRAEUM_STEHT_SEK or g.ohne_treffer >= Werte.AUFRAEUM_OHNE_TREFFER_SEK):
			ziele += 1
	if ziele == 0:
		return false
	_jaeger = _jaeger.filter(func(u): return is_instance_valid(u) and einheiten.has(u) and u.am_boden())
	if _jaeger.size() >= ziele * Werte.AUFRAEUM_JAEGER_JE_GEGNER:
		return false
	_jaeger.append(e)
	return true


## Platz auf dem Feld (15.11.): Gegner untereinander und eigene Bodentruppen untereinander schieben sich sanft auseinander,
## bis sie sich nach ihrem Radius nicht mehr überlappen. Geschoben wird nur innerhalb des eigenen Felds oder auf freie Felder.
func _abstand_halten(delta: float) -> void:
	var haerte := clampf(Werte.ABSTAND_HAERTE * delta, 0.0, 0.5)
	var gs: Array = []
	for g in gegner:
		if is_instance_valid(g) and not g._tot and not g._auf_wall:
			gs.append([g, maxf(g.radius(), Werte.LOCKER_RADIUS * Werte.ZELLE) if g.locker else g.radius()])
	_schiebe(gs, haerte, false)
	var es: Array = []
	var r := Werte.TRUPPE_RADIUS * Werte.ZELLE
	for e in einheiten:
		if is_instance_valid(e) and not (e is Kommandant) and e.zustand == Einheit.Zustand.BODEN and karte.ist_frei(karte.zelle_bei(e.position)) and not e._im_tor():
			es.append([e, r])
	_schiebe(es, haerte, true)


func _schiebe(liste: Array, haerte: float, _truppen: bool) -> void:
	var n := liste.size()
	if n < 2:
		return
	var schub: Array[Vector2] = []
	schub.resize(n)
	schub.fill(Vector2.ZERO)
	for i in n:
		var a: Node2D = liste[i][0]
		var ra: float = liste[i][1]
		for j in range(i + 1, n):
			var b: Node2D = liste[j][0]
			var rb: float = liste[j][1]
			var abstand := a.position - b.position
			var d := abstand.length()
			var soll := ra + rb
			if d >= soll:
				continue
			var richtung := abstand / d if d > 0.01 else Vector2.RIGHT.rotated(Zufall.f() * TAU)
			# Schwere schieben Leichte: Anteile nach Fläche (Radius²)
			var ma := ra * ra
			var mb := rb * rb
			var tief := (soll - d) * haerte
			schub[i] += richtung * tief * mb / (ma + mb)
			schub[j] -= richtung * tief * ma / (ma + mb)
	for i in n:
		if schub[i] == Vector2.ZERO:
			continue
		var u: Node2D = liste[i][0]
		var neu := u.position + schub[i]
		var alt_z := karte.zelle_bei(u.position)
		var neu_z := karte.zelle_bei(neu)
		if neu_z == alt_z or karte.ist_frei(neu_z):
			u.position = neu


func raeumen() -> bool:
	return phase == Phase.KAMPF and not endkampf and gegner.is_empty() and _schlange.is_empty() and _wurf_schlange.is_empty() and _wurf_aktiv.is_empty() and _im_flug == 0


## Aufräumen am Rundenende: Es kommt nichts mehr nach (kein Trupp, kein Wurf, kein Belagerungsturm, der Myr-Drohnen absetzt),
## aber es leben noch Gegner. Dann dürfen Truppen ohne Ziel ihre Stellung verlassen und den Übrigen hinterhergehen.
func aufraeumen() -> bool:
	if order24 != null:
		return false   # 20.11.: Order 24 – Truppen verfolgen nur, wenn Order24 es sagt
	if phase != Phase.KAMPF or endkampf or gegner.is_empty() or not _schlange.is_empty() or not _wurf_schlange.is_empty() or not _wurf_aktiv.is_empty() or _im_flug > 0:
		return false
	if gegner.size() > Werte.AUFRAEUM_HOECHSTENS_GEGNER:
		return false   # noch ein ganzer Trupp unterwegs: die Stellungen bleiben besetzt
	for g in gegner:
		if g.rolle == "belagerung":
			return false
	return true


## Aufräumen: Feld des nächsten erreichbaren Gegners (Luftlinie), nicht in der Zone und nicht oben auf einem Wall. KEINE = keiner.
func jagdziel(e: Einheit) -> Vector2i:
	var hier := karte.zelle_bei(e.position)
	var grenze := Werte.ZONE_SPALTEN + Werte.ZONE_ABSTAND
	var bestes := Karte.KEINE
	var beste := INF
	for g in gegner:
		var z := karte.zelle_bei(g.position)
		if _geschuetzt(g) or z.x < grenze or not karte.ist_frei(z):
			continue
		var d := e.position.distance_squared_to(g.position)
		if d >= beste:
			continue
		if z != hier and karte.einheiten_weg(hier, z).is_empty():
			continue
		beste = d
		bestes = z
	return bestes


## Pro verlorenem Checkpoint geht nur eine Truppe zurückholen (die nächste Bodentruppe); die anderen kämpfen weiter.
var _cp_einnehmer: Dictionary = {}   # Checkpoint-Index -> Einheit

func darf_checkpoint_holen(e: Einheit, cp: Vector2i) -> bool:
	var i := karte.checkpoints.find(cp)
	if i < 0:
		return false
	var amt = _cp_einnehmer.get(i)
	var alle := raeumen()
	if amt != null and is_instance_valid(amt) and einheiten.has(amt) and (amt.am_boden() or (alle and amt.in_stellung())):
		return amt == e
	var bester: Einheit = null
	var beste_weite := 1 << 30
	for u in einheiten:
		# Auch wer gerade zu einer Stellung unterwegs ist, kommt in Frage: der Checkpoint geht vor.
		if not (u.am_boden() or (alle and u.in_stellung())) or u.daten.get("pilot", false):
			continue
		# Wer schon einen anderen Checkpoint zurückholt, bleibt dabei: jeder verlorene Checkpoint bekommt seine eigene Truppe.
		var vergeben := false
		for k in _cp_einnehmer:
			if k != i and _cp_einnehmer[k] == u and k < karte.checkpoints.size() and karte.cp_feind[k]:
				vergeben = true
		if vergeben:
			continue
		var hier := karte.zelle_bei(u.position)
		var w := 0 if hier == cp else karte.einheiten_weg(hier, cp).size()   # Fußweg, nicht Luftlinie
		if hier != cp and w == 0:
			continue
		if w < beste_weite:
			beste_weite = w
			bester = u
	_cp_einnehmer[i] = bester
	return bester == e


## Ist diese Truppe gerade dafür eingeteilt, einen verlorenen Checkpoint zurückzuholen?
## Das geht vor: Sie besetzt solange keine Stellung neu.
func ist_einnehmer(e: Einheit) -> bool:
	for i in _cp_einnehmer:
		if _cp_einnehmer[i] == e and i < karte.checkpoints.size() and karte.cp_feind[i]:
			return true
	return false


## Spur der Fahnenträger: Wer ihr folgt, stürmt in seinem Tempo mit.
var _fahnenspur: Array = []   # [Punkt, Restzeit]
var _spur_in := 0.0
var _zuteilung_in := 0.0

func auf_fahnenspur(punkt: Vector2) -> bool:
	var r := Werte.FAHNE_SPUR_RADIUS * Werte.ZELLE
	for s: Array in _fahnenspur:
		if punkt.distance_squared_to(s[0]) <= r * r:
			return true
	return false


func _pflege_fahnenspur(delta: float) -> void:
	for s: Array in _fahnenspur:
		s[1] -= delta
	_fahnenspur = _fahnenspur.filter(func(s): return s[1] > 0.0)
	_spur_in -= delta
	if _spur_in > 0.0:
		return
	_spur_in = 0.2
	for g in gegner:
		if g.rolle == "fahne":
			_fahnenspur.append([g.position, Werte.FAHNE_SPUR_SEK])
			effekte.spur(g.position, Werte.FAHNE_SPUR_SEK)


## Bodentruppen auf einem verlorenen Checkpoint holen ihn nach einigen Sekunden zurück.
func _checkpoints_halten(delta: float) -> void:
	_pflege_fahnenspur(delta)
	# Verlorene Checkpoints bekommen sofort eine Truppe zugeteilt – auch eine, die gerade zu einer Stellung läuft.
	_zuteilung_in -= delta
	if _zuteilung_in <= 0.0:
		_zuteilung_in = 0.5
		for nr in karte.checkpoints.size():
			if karte.cp_feind[nr]:
				darf_checkpoint_holen(null, karte.checkpoints[nr])
	for i in karte.checkpoints.size():
		if not karte.cp_feind[i]:
			# Gegner halten den Checkpoint: Einnahme läuft, solange einer darauf steht
			if karte.cp_tempo[i] > 0.0:
				karte.cp_einnahme[i] += delta * karte.cp_tempo[i]
				if karte.cp_einnahme[i] >= Werte.EINNAHME_SEK:
					checkpoint_erreicht(i)
			else:
				karte.cp_einnahme[i] = maxf(0.0, karte.cp_einnahme[i] - delta)
			karte.cp_tempo[i] = 0.0
			continue
		var besetzt := false
		var cp_faktor := 1.0
		for e in einheiten:
			if order24 != null and e is Kommandant:
				continue   # 20.11.: Befehl 24 – Brakk gehört nicht mehr zum Technoclan
			if e.zustand == Einheit.Zustand.BODEN and karte.zelle_bei(e.position) == karte.checkpoints[i]:
				besetzt = true
				if e is Kommandant:
					cp_faktor = float(Werte.KOMMANDANT["cp_faktor"])   # Brakk holt ihn viel schneller zurück
		if not besetzt:
			karte.cp_fortschritt[i] = maxf(0.0, karte.cp_fortschritt[i] - delta)
			continue
		karte.cp_fortschritt[i] += delta * cp_faktor
		if karte.cp_fortschritt[i] >= Werte.RUECKEROBERUNG_SEK:
			karte.cp_feind[i] = false
			erfolg("zurueckgeholt")   # 18.11.
			karte.cp_fortschritt[i] = 0.0
			if OS.get_environment("TD_WURF_LOG") != "":
				print("CP R%d t=%.1f  Checkpoint %d zurückerobert" % [welle, _kampf_sek, i + 1])
			karte.aktualisiere_pfad()
			brakk_ereignis("cp_zurueck", {"cp": i + 1})   # 23.11.
			melde("Checkpoint %d zurückerobert." % (i + 1), 4.0)


## Die Gegner haben Checkpoint `i` lange genug gehalten.
func checkpoint_erreicht(i: int) -> void:
	if karte.cp_feind[i]:
		return
	karte.cp_feind[i] = true
	_cp_verloren += 1
	if OS.get_environment("TD_WURF_LOG") != "":
		print("CP R%d t=%.1f  Checkpoint %d verloren" % [welle, _kampf_sek, i + 1])
	karte.cp_fortschritt[i] = 0.0
	karte.cp_einnahme[i] = 0.0
	karte.aktualisiere_pfad()
	for g in gegner:
		if is_instance_valid(g) and not g._auf_wall and g._ziel == i:
			g.plane_neu()   # dieser Checkpoint ist erledigt: direkt weiter zum nächsten
	brakk_ereignis("cp_verloren", {"cp": i + 1})   # 23.11.
	melde("Checkpoint %d verloren! Die nächste Welle startet dort." % (i + 1), 4.0)


## 20.11. (Paul, Nachtrag) / 21.11. (Paul): Truppenturm (Irrtürmer) – hält bis zu „werkschutz“ Technogunner als Besatzung.
## Die Besatzung schießt aus dem Turm (jeder Mann ein Schuss wie ein Technogunner, im Turm nicht angreifbar). Heraus kommt
## sie nur zur ersten Reaktion: Steht ein Gegner auf einem Checkpoint im Umkreis von „ausfall_felder“ (oder ist der
## verloren), rückt die ganze Besatzung dorthin aus – nicht in Stellungen, nicht dem Gegner hinterher. Ist der Checkpoint
## wieder ruhig, geht sie zurück in den Turm. Gefallene kommen nach PRODUKTION_SEK / „nachschub“ im Turm nach.
var _werkschutz := {}   # Turm-Zelle -> {"timer", "einheiten" (draußen), "drin", "ruhe", "schuss"}

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
	var neu_w := not _werkschutz.has(z)
	var w: Dictionary = _werkschutz.get(z, {"timer": 0.0, "einheiten": [], "drin": 0, "ruhe": 0.0, "schuss": 0.0})
	if not w.has("drin"):
		w["drin"] = 0
		w["ruhe"] = 0.0
		w["schuss"] = 0.0
	var liste: Array = (w["einheiten"] as Array).filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Node).is_queued_for_deletion() and (e as Einheit).leben > 0.0)
	w["einheiten"] = liste
	_werkschutz[z] = w
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
			e.start(self, karte, "technogunner", z, stufe, "")
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
	var rest := float(w["schuss"]) - delta * turm_takt(z)
	if rest > 0.0:
		w["schuss"] = rest
		return
	var d: Dictionary = Werte.einheit_daten("technogunner", stufe, "")
	var von := karte.mitte(z) + Vector2(0, -14)
	var weite := float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
	schadensquelle = "turm:truppen"
	schuetze = null
	schadensobjekt = z
	schuss_herkunft = von
	var ziel := gegner_in_reichweite(von, weite, false, z)
	if ziel == null:
		w["schuss"] = 0.0
		return
	if turmbilder.has(z):
		(turmbilder[z] as TurmBild).feuert(ziel.position)
	Ton.am_ort(self, "tc-heavy", von)
	schuss(von, ziel.position, Color(Werte.TURMARTEN["truppen"]["farbe"]))
	ziel.nimm_schaden(float(d["schaden"]))
	w["schuss"] = float(d["abklingzeit"]) / float(drin * maxi(1, (d.get("schuss_bilder", [0]) as Array).size()))   # jeder Mann schießt für sich: mehr Besatzung = dichteres Feuer


func _tuerme_feuern(delta: float) -> void:
	for z: Vector2i in karte.ausbau:
		if not karte.turm_aktiv(z):
			continue   # kein Turm, lahmgelegt oder ohne Stützen
		var art_name: String = karte.turm_art.get(z, "geschuetz")
		if art_name == "funk":
			# schießt nicht selbst (siehe funk_faktor) – sendet nur sichtbar Funkwellen
			var fw: float = _funk_welle.get(z, 0.0) - delta
			if fw <= 0.0:
				fw = 0.9
				effekte.welle(karte.mitte(z), float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE, Color(Werte.TURMARTEN["funk"]["farbe"]), "funk", 1.5)
			_funk_welle[z] = fw
			continue
		if art_name == "heil":
			_heilturm(z, delta)
			continue
		if art_name == "truppen":
			_truppenturm(z, delta)   # 20.11. (Nachtrag) / 21.11.: Besatzung schießt aus dem Turm, Ausfall nur zum Checkpoint
			continue
		if art_name == "pliplop":
			_pliplop_turm(z, delta)   # 20.11. (Paul): PliPlop 3cK (Irrtürmer)
			continue
		var art: Dictionary = Werte.TURMARTEN[art_name]
		schadensquelle = "turm:" + art_name
		schuetze = null
		schadensobjekt = z
		var weite: float = float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
		if order24 != null:
			weite += order24.turm_bonus() * Werte.ZELLE   # 20.11. (Paul): Befehl 24 – Brakk auf den Erdwällen wird weiter beschossen
		var farbe := Color(art["farbe"])
		var von := karte.mitte(z) + Vector2(0, -14)
		schuss_herkunft = von
		var schaden := float(karte.turm_wert(z, "schaden"))
		# Lanze mit Doppelstrahl: der zweite Strahl folgt kurz nach dem ersten auf derselben Linie
		if _turm_nachschuss.has(z):
			var n: Array = _turm_nachschuss[z]
			n[0] = float(n[0]) - delta
			if float(n[0]) <= 0.0:
				_turm_nachschuss.erase(z)
				_lanzenstrahl(von, n[1], farbe, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, schaden)
		# Frost mit Schockfrost: eigener Takt, friert alle Gegner im Umkreis kurz ganz ein
		var schock := float(karte.turm_wert(z, "schock_alle", 0.0))
		if schock > 0.0:
			var t: float = float(_turm_schock.get(z, schock)) - delta
			if t <= 0.0:
				var getroffen := false
				for g in gegner:
					if is_instance_valid(g) and not _geschuetzt(g) and von.distance_to(g.position) <= weite and karte.sicht_von_wall(z, von, g.position):
						g.eingefroren = maxf(g.eingefroren, float(karte.turm_wert(z, "schock_sek")))
						getroffen = true
				if getroffen:
					effekte.welle(karte.mitte(z), weite, Color.WHITE, "frost", 0.5)
					t = schock
				else:
					t = 0.25
			_turm_schock[z] = t
		var rest: float = _turm_abkling.get(z, 0.0) - delta * turm_takt(z)   # 20.11.: Überladen (Irrtürmer)
		if rest <= 0.0:
			var durch: bool = karte.turm_wert(z, "durch_waelle", false)
			var ziel := gegner_in_reichweite(von, weite, false, Karte.KEINE if durch else z)   # Türme folgen derselben Sichtregel wie Stellungen
			if ziel != null:
				rest = float(karte.turm_wert(z, "abklingzeit"))
				match art_name:
					"frost":
						# Frostpuls: alle Gegner in Reichweite und Sicht werden verlangsamt
						effekte.welle(karte.mitte(z), weite, farbe, "frost", 0.8)
						var sproede := float(karte.turm_wert(z, "sproede", 0.0))
						for g in gegner.duplicate():
							if is_instance_valid(g) and not _geschuetzt(g) and von.distance_to(g.position) <= weite and karte.sicht_von_wall(z, von, g.position):
								var sek := float(karte.turm_wert(z, "bremse_sek"))
								var bt := float(karte.turm_wert(z, "bremse_tempo"))   # 19.11.: Stufe 2 bremst stärker
								if g.gefroren <= 0.0:
									objekt_zaehle(z, "gebremst", 1.0)
									g.frost_tempo = bt
								else:
									g.frost_tempo = minf(g.frost_tempo, bt)
								g.gefroren = maxf(g.gefroren, sek)
								if sproede > 0.0:
									g.sproede = maxf(g.sproede, sek)
								if schaden > 0.0:
									g.nimm_schaden(schaden)
					"lanze" when brakk_geschosse != null and brakk_geschosse.ist_brakk(ziel):
						# 20.11.: Schritt 6c – erst Aufglühen, dann der Strahl auf Brakks Stelle von davor
						brakk_geschosse.turm(z, von, "lanze", schaden, weite, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, int(karte.turm_wert(z, "strahlen", 1)), schadensquelle)
					"lanze":
						Ton.am_ort(self, "tc-arc", von)
						# Strahl in gerader Linie bis zum Ende der Reichweite: trifft alles in der Linie (auch hinter Wällen)
						var ende := von + (ziel.position - von).normalized() * weite
						_lanzenstrahl(von, ende, farbe, float(karte.turm_wert(z, "breite")) * Werte.ZELLE, schaden)
						if int(karte.turm_wert(z, "strahlen", 1)) >= 2:
							_turm_nachschuss[z] = [0.35, ende]
					_ when brakk_geschosse != null and brakk_geschosse.ist_brakk(ziel):
						brakk_geschosse.turm(z, von, art_name, schaden, weite, Werte.BRAKK_TURM_BREITE * Werte.ZELLE, 1, schadensquelle)   # 20.11.: Schritt 6c
					_:
						Ton.am_ort(self, "tc-heavy", von)
						_turm_schuss(z, von, ziel.position, farbe)
						ziel.nimm_schaden(schaden)
						if int(karte.turm_wert(z, "ziele", 1)) >= 2:
							# Doppelschuss: der nächste andere Gegner in Reichweite und Sicht
							var zweit: Gegner = null
							var nah := INF
							for g in gegner:
								if is_instance_valid(g) and g != ziel and not _geschuetzt(g) and von.distance_to(g.position) <= weite and von.distance_to(g.position) < nah and karte.sicht_von_wall(z, von, g.position):
									zweit = g
									nah = von.distance_to(g.position)
							if zweit != null:
								_turm_schuss(z, von, zweit.position, farbe, false)
								zweit.nimm_schaden(schaden)
		_turm_abkling[z] = rest


## Gefechtsturm (16.11.): dreht sich zum Ziel, das Leuchtgeschoss startet an der Mündung (mit Höhe) und schlägt mit
## einem kleinen Treffer am Ziel ein. Ohne Turmbild (klassische Grafik) wie bisher als Linie.
func _turm_schuss(z: Vector2i, von: Vector2, nach: Vector2, farbe: Color, drehen: bool = true) -> void:
	if not turmbilder.has(z) or not Werte.grafik_neu:
		schuss(von, nach, farbe)
		return
	var tb := turmbilder[z] as TurmBild
	if drehen:
		tb.feuert(nach)
	var m: Array = tb.muendung()
	var stufe := int(karte.turm_stufe.get(z, 1))
	effekte.leuchtschuss(m[0], m[1], nach, 14.0, Color("7fe0ff"), 0.09 + (m[0] as Vector2).distance_to(nach) / 4200.0, 10.0 + 3.0 * stufe)
	effekte.fx("treffer_c", nach, 0.45 + 0.08 * stufe, nach.x < von.x)


func _lanzenstrahl(von: Vector2, ende: Vector2, farbe: Color, breite: float, schaden: float) -> void:
	strahl(von, ende, farbe, 6.0)
	var betroffen: Array = []
	for g in gegner:
		if is_instance_valid(g) and not _geschuetzt(g):
			var p := Geometry2D.get_closest_point_to_segment(g.position, von, ende)
			if p.distance_to(g.position) <= breite:
				betroffen.append(g)
	var deckung := schild_deckung(von, betroffen)   # Schildabfangen: hinter einem Schildträger kommt der Strahl geschwächt an
	for g: Gegner in betroffen:
		if is_instance_valid(g):
			g.nimm_schaden(schaden * float(deckung.get(g, 1.0)))
	# 18.11.: Erfolg „Aufgespießt“ – vier Gegner mit einem Strahl
	var tote := 0
	for g: Gegner in betroffen:
		if is_instance_valid(g) and g._tot:
			tote += 1
	if tote >= 4:
		erfolg("aufgespiesst")


## Magnete: alle paar Sekunden die Gegner in ihrer Zuglinie heranziehen (höchstens bis vor den Magneten, nicht durch Wälle).
func _magnete_ziehen(delta: float) -> void:
	for z: Vector2i in karte.magnet_richtung:
		if karte.ausbau.get(z, Karte.FREI) != Karte.MAGNET:
			continue
		var rest: float = _turm_abkling.get(z, 0.0) - delta
		if rest <= 0.0:
			var r: Vector2i = karte.magnet_richtung[z]
			var linie := karte.magnet_linie(z, r)
			var gezogen := 0
			if not linie.is_empty():
				var vorne := karte.mitte(linie[0])
				var achse := Vector2(r)
				for g in gegner:
					if _geschuetzt(g) or g.rolle == "belagerung" or not linie.has(karte.zelle_bei(g.position)):
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
		_turm_abkling[z] = rest


## Spiegel: Ziel für eine Bodentruppe, das sie selbst nicht sieht, aber über einen Spiegel trifft.
## Ergebnis: {"ziel": Gegner, "spiegel": Punkt} oder {} – beide Strecken zusammen höchstens `weite`.
func ziel_ueber_spiegel(von: Vector2, weite: float) -> Dictionary:
	var bestes := {}
	var beste := INF
	for s: Vector2i in karte.ausbau:
		if karte.ausbau[s] != Karte.SPIEGEL:
			continue
		var sp := karte.mitte(s)
		var d1 := von.distance_to(sp)
		if d1 >= weite or not karte.sicht_frei(sp, von):
			continue
		for g in gegner:
			if _geschuetzt(g):
				continue
			var d := d1 + sp.distance_to(g.position)
			if d <= weite and d < beste and karte.sicht_frei(sp, g.position):
				beste = d
				bestes = {"ziel": g, "spiegel": sp}
	return bestes


var _weg_grund: Control
var _lbl_weg: Label
var _weg_in := 0.0

## Weganzeige: Weglänge, Umweg durch eigene Bauten (gegenüber freiem Feld) und Wegfelder in Reichweite von Stellungen, Türmen, Batterien.
func _aktualisiere_weganzeige(delta: float) -> void:
	var zeigen := phase == Phase.BAU and phantom_modus != "angriff" and welle >= Werte.WAELLE_AB_WELLE - 1 and not endkampf
	_weg_grund.visible = zeigen
	if not zeigen:
		return
	_weg_in -= delta / maxf(Engine.time_scale, 0.01)
	if _weg_in > 0.0:
		return
	_weg_in = 0.4
	var weg := karte.pfad
	if weg.size() < 2:
		return
	var frei := 0
	var von := karte.start_zelle()
	for i in range(karte.erstes_ziel(), karte.checkpoints.size() + 1):
		var nach := karte.ziel_zelle(i)
		frei += karte.grund_abstand(von, nach)   # 18.11.: Umwege durch Fels und Wasser zählen nicht als „deine Bauten“
		von = nach
	var umweg := maxi(0, weg.size() - 1 - frei)
	# Wegfelder in Reichweite (grob: Luftlinie, ohne Sichtregel)
	var quellen: Array = []   # [Mitte, Reichweite in Pixeln]
	for z: Vector2i in karte.ausbau:
		match karte.ausbau[z]:
			Karte.STELLUNG:
				quellen.append([karte.mitte(z), 4.0 * Werte.ZELLE])
			Karte.TURM:
				var art: String = karte.turm_art.get(z, "geschuetz")
				if not art in ["funk", "heil"]:
					quellen.append([karte.mitte(z), float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE])
	for z: Vector2i in karte.feld:
		if karte.feld[z] == Karte.BATTERIE:
			quellen.append([karte.mitte(z), float(Werte.BATTERIE["reichweite"]) * Werte.ZELLE])
	var beschossen := 0
	for f in weg:
		var m := karte.mitte(f)
		for q: Array in quellen:
			if m.distance_to(q[0]) <= q[1]:
				beschossen += 1
				break
	_lbl_weg.text = "Gegnerweg %d Felder · +%d durch deine Bauten · %d unter Beschuss" % [weg.size() - 1, umweg, beschossen]
	weg_info = [weg.size() - 1, umweg, beschossen]   # 23.11.: Brakk-Protokoll


## Heilturm: alle paar Sekunden eigene Truppen im Umkreis heilen.
func _heilturm(z: Vector2i, delta: float) -> void:
	var art: Dictionary = Werte.TURMARTEN["heil"]
	var instand := float(karte.turm_wert(z, "instand_sek", 0.0))
	if instand > 0.0:
		for t: Vector2i in karte.turm_schaden.keys():
			if karte.turm_lahm(t) and Vector2(t - z).length() <= float(karte.turm_wert(z, "reichweite")):
				_instand_zeit[t] = float(_instand_zeit.get(t, 0.0)) + delta
				if float(_instand_zeit[t]) >= instand:
					objekt_zaehle(z, "instand", 1.0)
					karte.turm_schaden.erase(t)
					_instand_zeit.erase(t)
					effekte.flaeche(karte.mitte(t), Werte.ZELLE * 0.8, Color(art["farbe"]))
					karte.queue_redraw()
	var rest: float = _turm_abkling.get(z, 0.0) - delta * turm_takt(z)   # 20.11.: Überladen (Irrtürmer)
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
				objekt_zaehle(z, "heilung", e.leben - vorher_leben)
				effekte.plus(e.position, Color(art["farbe"]))
				e.queue_redraw()
				geheilt = true
		if geheilt:
			effekte.welle(m, weite, Color(art["farbe"]), "heil", 0.9)
	_turm_abkling[z] = rest


## Schildkuppel: Faktor auf den Schaden, den eine eigene Truppe an `punkt` nimmt (1.0 = keine Kuppel).
func schild_faktor(punkt: Vector2) -> float:
	return 1.0 - Werte.KUPPEL_SCHUTZ if karte.in_kuppel(punkt) else 1.0


## Funkturm: Truppen in Stellungen in seinem Umkreis feuern schneller. Faktor auf ihre Pause (1.0 = kein Funkturm in der Nähe).
func funk_faktor(stellung: Vector2i) -> float:
	if stellung == Karte.KEINE:
		return 1.0
	var bester := 1.0
	for z: Vector2i in karte.turm_art:
		if karte.turm_art[z] == "funk" and karte.turm_aktiv(z) and Vector2(stellung - z).length() <= float(karte.turm_wert(z, "reichweite")):
			bester = minf(bester, float(karte.turm_wert(z, "feuer_faktor")))
	return bester


## Funkturm mit Peilsender: Truppen in dieser Stellung sehen durch Rauch.
func peilung(stellung: Vector2i) -> bool:
	if stellung == Karte.KEINE:
		return false
	for z: Vector2i in karte.turm_art:
		if karte.turm_art[z] == "funk" and karte.turm_aktiv(z) and karte.turm_wert(z, "peilung", false) and Vector2(stellung - z).length() <= float(karte.turm_wert(z, "reichweite")):
			return true
	return false


## Heilturm mit Feldlazarett: Fällt die Truppe `e` in seinem Umkreis, steht sie mit halbem Leben wieder auf (einmal pro Runde je Turm).
func lazarett_rettet(e: Einheit) -> bool:
	if order24 != null and order24.nemesis != null and order24.nemesis.rettet(e):
		return true   # 22.11. (Paul): Befehl 24 – Eliten sterben nicht, sie werden kampfunfähig und geborgen (nemesis.gd)
	for z: Vector2i in karte.turm_art:
		if karte.turm_art[z] == "heil" and karte.turm_aktiv(z) and not _lazarett_genutzt.has(z) and karte.turm_wert(z, "lazarett", false) \
				and karte.mitte(z).distance_to(e.position) <= float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE:
			_lazarett_genutzt[z] = true
			erfolg("feldlazarett")   # 18.11.
			objekt_zaehle(z, "gerettet", 1.0)
			e.leben = e.max_leben * 0.5
			effekte.flaeche(e.position, Werte.ZELLE * 0.6, Color(Werte.TURMARTEN["heil"]["farbe"]))
			melde("Feldlazarett: %s steht wieder auf." % e.daten["name"], 3.0)
			return true
	return false


## Voll bemannte Batterien feuern auf die dichteste Gegnergruppe in Reichweite – über Wälle hinweg.
func _batterien_feuern(delta: float) -> void:
	schuss_herkunft = Vector2.INF
	var radius: float = Werte.BATTERIE["flaeche"] * Werte.ZELLE
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.BATTERIE or karte.ausgefallen.has(z):
			continue
		var stufe := batterie_stufe(z)
		var weite := batterie_reichweite(z)
		karte.batterie_stufe_neu[z] = stufe
		if stufe >= 2 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			# Schwere Ladung: nebenbei Rauch in Reichweite wegblasen
			_rauch_abkling[z] = float(_rauch_abkling.get(z, 0.0)) - delta
			if _rauch_abkling[z] <= 0.0:
				var wolke: Variant = effekte.blase_rauch_weg(karte.mitte(z), weite)
				if wolke != null:
					_rauch_abkling[z] = Werte.BATTERIE_RAUCH_SEK
					schuss(karte.mitte(z) + Vector2(0, -20), wolke, Color("d8f6ff"))
		var rest: float = _turm_abkling.get(z, Werte.BATTERIE["abklingzeit"] * 0.5) - delta * turm_takt(z)   # 20.11.: Überladen (Irrtürmer)
		if rest <= 0.0 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			var von := karte.mitte(z) + Vector2(0, -20)
			var bestes: Gegner = null
			var meiste := 0
			# Zielwahl im Batteriemenü (an der Pilotenfabrik): "dichteste" Gruppe (Standard) oder wie bei Truppen Erste/Letzte/Stärkste
			var modus := str(fabriken.get(karte.paar.get(z, z), {}).get("ziel", "dichteste"))
			if modus != "dichteste":
				bestes = gegner_in_reichweite(von, weite, false, Karte.KEINE, modus)
			for g in (gegner if modus == "dichteste" else []):
				if _geschuetzt(g) or von.distance_to(g.position) > weite:
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
				Ton.am_ort(self, "tc-arc", von)
				var ziel_punkt := bestes.position
				var schaden := float(Werte.BATTERIE["schaden"]) * (Werte.BATTERIE_ST2_SCHADEN if stufe >= 2 else 1.0)
				get_tree().create_timer(Effekte.BOLZEN_FLUG, false, true).timeout.connect(_batterie_einschlag.bind(z, von, ziel_punkt, radius, schaden))
		_turm_abkling[z] = maxf(rest, 0.0) if rest <= 0.0 else rest


func _batterie_einschlag(z: Vector2i, von: Vector2, punkt: Vector2, radius: float, schaden: float) -> void:
	if phase != Phase.KAMPF:
		return
	Ton.am_ort(self, "hit-pboom", punkt)
	schadensquelle = "batterie:%d,%d" % [z.x, z.y]
	schuetze = null
	schuss_herkunft = von   # der Frontschild fängt auch die Batterie ab, wenn sie von vorn kommt
	flaechenschaden(punkt, radius, schaden, Color("7fe0ff"), Werte.BATTERIE_RAND_FAKTOR, false)
	schuss_herkunft = Vector2.INF


## Schaden an allen Gegnern im Umkreis, mit einem kurzen Ring als Zeichen.
# ------------------------------------------------- Stufe-3-Fähigkeiten

func spielzeit() -> float:
	return _spielzeit


func strahl(von: Vector2, nach: Vector2, farbe: Color, breite: float) -> void:
	effekte.strahl(von, nach, farbe, breite)


## Zielmarkierung: der Gegner mit den meisten Lebenspunkten, der gerade angreifbar ist.
func staerkster_gegner() -> Gegner:
	var bester: Gegner = null
	for g in gegner:
		if _geschuetzt(g):
			continue
		if bester == null or g.leben > bester.leben:
			bester = g
	return bester


## Feuerteam (17.11.): Wie viele andere Feuerteam-Schützen haben in der letzten Sekunde auf ein Ziel
## auf derselben Kachel geschossen? So zählt Beschuss auf einen Pulk mit, nicht nur auf genau einen Gegner.
func mitschuetzen(wer: Einheit, ziel: Node2D) -> int:
	var n := 0
	var kachel := karte.zelle_bei(ziel.position)
	for e in einheiten:
		if e != wer and e.faehigkeit == "feuerteam" and e.letzte_zielzelle == kachel and _spielzeit - e.letzter_schuss <= 1.0:
			n += 1
	return n


## Durchschuss: trifft jeden Gegner nah an der Linie, den der Schütze auch einzeln treffen dürfte.
func linienschaden(_wer: Einheit, von: Vector2, nach: Vector2, schaden: float, von_wall: Vector2i) -> void:
	var breite := Werte.DURCHSCHUSS_BREITE * Werte.ZELLE
	for g in gegner.duplicate():
		if _geschuetzt(g):
			continue
		var naechster := Geometry2D.get_closest_point_to_segment(g.position, von, nach)
		if naechster.distance_to(g.position) > breite:
			continue
		if von_wall != Karte.KEINE:
			if not karte.sicht_von_wall(von_wall, von, g.position):
				continue
		elif not karte.sicht_frei(von, g.position):
			continue
		g.nimm_schaden(schaden)


## Abpraller: vom Einschlag aus bis zu zweimal zum nächsten noch nicht getroffenen Gegner weiter.
func abpraller(erstes: Gegner, radius: float, schaden: float, farbe: Color) -> void:
	var getroffen: Array = [erstes]
	var punkt := erstes.position
	for sprung in Werte.ABPRALLER_SPRUENGE:
		schaden *= Werte.ABPRALLER_SCHADEN
		var naechster: Gegner = null
		var beste := Werte.ABPRALLER_WEITE * Werte.ZELLE
		for g in gegner:
			if getroffen.has(g) or _geschuetzt(g):
				continue
			var d := punkt.distance_to(g.position)
			if d > radius * 0.6 and d <= beste and karte.sicht_frei(punkt, g.position):
				beste = d
				naechster = g
		if naechster == null:
			return
		effekte.strahl(punkt, naechster.position, farbe, 2.0)
		punkt = naechster.position
		getroffen.append(naechster)
		flaechenschaden(punkt, radius * 0.8, schaden, farbe)


## Brandfeld: brennt nach und schädigt, wer darin steht.
var _braende: Array = []   # [Mitte, Radius, Restzeit, Schaden je Sekunde]

func lege_brand(mitte: Vector2, radius: float, schaden_je_sek: float) -> void:
	_braende.append([mitte, radius, Werte.BRANDFELD_SEK, schaden_je_sek, schadensquelle, brakk_quelle])
	effekte.brand(mitte, radius, Werte.BRANDFELD_SEK)


func _braende_wirken(delta: float) -> void:
	_spielzeit += delta
	schuss_herkunft = Vector2.INF   # Brandfelder brennen von unten: kein Frontschild
	for b: Array in _braende:
		b[2] -= delta
		schadensquelle = str(b[4]) if b.size() > 4 else ""
		brakk_quelle = str(b[5]) if b.size() > 5 else ""
		schuetze = null   # 18.11.: Brandfeld – keine Truppe schießt gerade
		for g in gegner.duplicate():
			if not _geschuetzt(g) and (b[0] as Vector2).distance_to(g.position) <= float(b[1]):
				g.nimm_schaden(float(b[3]) * delta, true)
	brakk_quelle = ""
	_braende = _braende.filter(func(b): return b[2] > 0.0)


## Plasmagel: wenig Schaden, aber alle im Feld werden verlangsamt.
func gelschuss(mitte: Vector2, radius: float, schaden: float) -> void:
	effekte.gel(mitte, radius, Werte.PLASMAGEL_SEK)
	var betroffen: Array = []
	for g in gegner:
		if not _geschuetzt(g) and mitte.distance_to(g.position) <= radius:
			betroffen.append(g)
	var deckung := schild_deckung(schuss_herkunft, betroffen)
	for g: Gegner in betroffen:
		if is_instance_valid(g):
			g.gebremst = Werte.PLASMAGEL_SEK
			g.nimm_schaden(schaden * float(deckung.get(g, 1.0)))


## `rand`: Schadensanteil am Rand des Einschlags (1 = überall voll; Batterie: fällt zum Rand ab).
func flaechenschaden(mitte: Vector2, radius: float, schaden: float, farbe: Color, rand: float = 1.0, ring: bool = true) -> void:
	for i in (12 if ring else 0):
		var a := Vector2.RIGHT.rotated(TAU * i / 12.0) * radius
		var b := Vector2.RIGHT.rotated(TAU * (i + 1) / 12.0) * radius
		effekte.linie(mitte + a, mitte + b, farbe)
	var betroffen: Array = []
	for g in gegner:
		if not _geschuetzt(g) and mitte.distance_to(g.position) <= radius:
			betroffen.append(g)
	var deckung := schild_deckung(schuss_herkunft, betroffen)
	for g: Gegner in betroffen:
		if is_instance_valid(g):
			var abfall := lerpf(1.0, rand, clampf(mitte.distance_to(g.position) / maxf(radius, 1.0), 0.0, 1.0))
			g.nimm_schaden(schaden * abfall * float(deckung.get(g, 1.0)))
	if order24 != null and (brakk_quelle != "" or schadensquelle == "fabrik:-1,-1"):
		order24.flaeche(mitte, radius, schaden)   # 20.11.: Brakks Flächenschaden trifft in Order 24 den Technoclan


## Schildabfangen: Fläche und Strahlen von vorn trifft auch die, die direkt hinter einem Schildträger stehen,
## nur mit SCHILD_FRONT_FAKTOR. Ergebnis: Gegner -> Faktor (nur Gedeckte; den Schildträger selbst regelt nimm_schaden).
func schild_deckung(herkunft: Vector2, betroffen: Array) -> Dictionary:
	var deckung := {}
	if herkunft == Vector2.INF or betroffen.is_empty():
		return deckung
	for h: Gegner in gegner:
		if h.rolle != "schild" or h.leben <= 0.0 or _geschuetzt(h):
			continue
		var vor := h.position - herkunft
		if vor.length() <= 4.0 or absf(h.blick.angle_to(-vor)) > deg_to_rad(Werte.SCHILD_FRONT_WINKEL):
			continue   # der Schuss kommt nicht von vorn
		var richtung := vor.normalized()
		for g: Gegner in betroffen:
			if g == h:
				continue
			var rel := g.position - h.position
			var tiefe := rel.dot(richtung)
			if tiefe > 0.0 and tiefe <= Werte.SCHILD_DECKUNG_TIEFE * Werte.ZELLE and absf(rel.cross(richtung)) <= Werte.SCHILD_DECKUNG_BREITE * Werte.ZELLE:
				deckung[g] = Werte.SCHILD_FRONT_FAKTOR
	return deckung


## `erzwingen` (18.11.): die Bauzeit eines Szenarios ist um – die Welle kommt auch ohne Fabrik.
func starte_welle(erzwingen: bool = false) -> void:
	if phase != Phase.BAU:
		return
	if tutorial != null and tutorial.sperrt_welle():
		melde("Sonde 7: Erst noch den Schritt im Tutorial – oder „Tutorial beenden“.", 3.0)
		return
	if phantom_modus == "angriff":
		if Werte.welle_aus_plan({"name": "", "trupps": _plaene.get(welle, [])}, welle)["gruppen"].is_empty():
			_laufband.visible = true
			melde("Der Taktikplaner ist leer: erst Einheiten auf das Band setzen.", 4.0)
			return
		_laufband.visible = false
		_phantom_zuege_in_runde()
	elif fabriken.is_empty() and herausforderung != "keine_fabriken" and not brakk_modus and not erzwingen:   # 18.11.: in „Keine Fabriken“ und im Brakk-Mode geht es ohne
		melde("Erst eine Fabrik bauen [1].")
		return
	_schild_fuer = Karte.KEINE
	_schild_start = Karte.KEINE
	_bezahlt.clear()   # ab jetzt gilt für alles Gebaute die normale Erstattung
	_bau_stapel.clear()
	_abriss_merk = Karte.KEINE
	if budget >= Erfolge.SPARER_BUDGET and not brakk_modus and phantom_modus == "" and herausforderung == "":
		_protokoll["sparer"] = true   # 19.11.: Erfolg „Deutscher Sparer“ (zählt beim Sieg)
	_auftrag_pruefen("welle")   # 20.11.: Pauls Aufträge
	phase = Phase.KAMPF
	_kampf_tick = 0
	if phantom_modus == "verteidigung" and not _phantom_trupps(welle).is_empty():
		# 23.11. (Phantom-Einführung E): wessen Welle ist das?
		_einblendung.banner("DIESE WELLE HAT %s GEPLANT" % str(_angriff_phantom.get("spieler", "EIN SPIELER")).to_upper(), "Phantom-Angriff · Runde %d" % welle, _F_KUPFER_HELL)
		if not bool(Profil.einstellung("pe_verteidigung", false)):
			Profil.setze_einstellung("pe_verteidigung", true)
			melde("Das ist die echte Welle eines anderen Spielers – halte alle Runden, dann steigt deine Elo.", 8.0)
	_merke_sitzung("Welle")   # 19.11.: Diagnose – brach die Sitzung ab?
	karte.brut_aktualisieren()   # Brut-Boden: Stand zu Rundenbeginn
	runde_stats.clear()   # Schadensliste [Tab]: zählt je Runde neu
	_lazarett_genutzt.clear()
	_instand_zeit.clear()
	_turm_schock.clear()
	_turm_nachschuss.clear()
	runde_stats_welle = welle
	werkzeug = Karte.FREI
	_runde_start_ms = Time.get_ticks_msec()
	_leben_vor_runde = leben
	_cp_verloren = 0
	_nachspiel = 0.0
	_kampf_sek = 0.0
	_braende.clear()
	karte.zeige_pfad_kraeftig = false
	_welle = naechste_welle()
	if endkampf:
		_welle["leben_faktor"] = Werte.endkampf_leben()   # 18.11.: der Abwehrteil von Runde 20 hat normale Leben
	_trupp = []
	_im_flug = 0
	_wurf_schlange = []
	_minen_scharf = {}   # 18.11.: jede Mine liegt zu Rundenbeginn wieder
	for z: Vector2i in karte.boden:
		if karte.boden[z] == "minen":
			_minen_scharf[z] = true
	_durchgang = 0
	_abgesetzt.clear()
	_ausfall_zeit.clear()
	_reparaturen.clear()
	_wurf_nahe = Vector2.INF
	if (phantom_modus != "" or Werte.KARTE_WELLEN.has(welle)) and not (_welle["wurf"] as Array).is_empty():
		_sorge_fuer_wurf_schleuder()   # 18.11.: auch für eigene Wellen eines Szenarios
	_lade_durchgang()
	_wurf_aktiv = []
	_wurf_sofort = false
	_wurf_meiden = Vector2.INF
	if not _wurf_schlange.is_empty() and phantom_modus == "":
		# Wer sich hinter einer dicken Mauer verschanzt, bekommt ein Rudel Hunde zusätzlich über die Mauer geworfen.
		for b in zonenbauten:
			if b.art == "wurf" and karte.wurf_mauer(b.zelle) >= Werte.WURF_MAUER_EXTRA:
				_wurf_schlange.append({"typen": ["hund", "hund", "hund", "hund"], "nach": 0, "wenn": ""})
				melde("Die Wurf-Schleuder nimmt eure Mauer ins Visier.", 4.0)
				break
	if variante > 0 or welle >= Werte.WELLEN_VARIANTEN_AB:
		_runden_eintrag()["variante"] = variante
	_spawn_in = 1.0
	_start_zelle = karte.start_zelle() if karte.start_index() >= 0 else Werte.START_ZELLE   # 20.11.: Eingänge wählt _spawn_zelle reihum
	_erstes_ziel = karte.erstes_ziel()
	_turm_abkling.clear()
	for z: Vector2i in fabriken:
		fabriken[z]["timer"] = Werte.PRODUKTION_SEK - 0.5   # erste Einheit kommt sofort
	Ton.spiele(self, "alert")


## Phantom-Modus: Der Plan enthält einen Wurf, aber die Wurf-Schleuder steht noch nicht (vor Runde 10) – dann kommt sie jetzt.
func _sorge_fuer_wurf_schleuder() -> void:
	for b in zonenbauten:
		if b.art == "wurf":
			return
	for nr in Werte.ZONENBAUTEN.size():
		var s: Dictionary = Werte.ZONENBAUTEN[nr]
		if s["art"] == "wurf" and not _zone_gebaut.has(nr):
			_zone_gebaut[nr] = true
			_neuer_zonenbau("wurf", s["zelle"])
			return


## Felder, von denen aus geworfen wird: die Wurf-Schleudern, die stehen – sonst der Platz, an dem die erste entsteht.
func wurf_standorte() -> Array:
	var felder: Array = []
	for b in zonenbauten:
		if b.art == "wurf":
			felder.append(b.zelle)
	if felder.is_empty():
		for s: Dictionary in Werte.ZONENBAUTEN:
			if s["art"] == "wurf":
				felder.append(s["zelle"])
				break
	return felder


## Angriff: Der nächste Linksklick auf die Karte setzt das Landefeld dieses Wurf-Trupps.
func waehle_wurfziel(trupp: Dictionary) -> void:
	if szenario_editor != null:
		melde("Im Szenario sucht die Wurf-Schleuder ihr Ziel selbst.", 4.0)   # 18.11.
		return
	_wurfziel_fuer = trupp
	_laufband.visible = false
	melde("Wurfziel: Klick auf ein freies Feld im orangen Kreis. Rechtsklick oder [Esc] bricht ab.", 8.0)


func _setze_wurfziel(z: Vector2i) -> void:
	var nah := false
	for s: Vector2i in wurf_standorte():
		if Vector2(z - s).length() <= float(Werte.WURF["weit"]):
			nah = true
	# Im Nebel verrät das Ziel nichts: Steht dort etwas, landen die Geworfenen daneben.
	if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or karte.ist_basis(z) or (nebel.offen(z) and not karte.ist_frei(z)):
		melde("Dort kann nichts landen: Das Feld muss frei sein und außerhalb deiner Zone liegen.", 4.0)
		return
	if not nah:
		melde("Zu weit: Die Wurf-Schleuder reicht nur bis zum orangen Kreis.", 4.0)
		return
	_wurfziel_fuer["ziel"] = [z.x, z.y]
	_wurfziel_fuer.erase("wenn")
	_beende_wurfziel()


func _beende_wurfziel() -> void:
	_wurfziel_fuer = {}
	_laufband.visible = true
	_laufband._neu()


## Füllt die Schlangen mit dem nächsten Durchgang der Welle (in normalen Runden gibt es nur einen).
var _elite_nr := -1   # 19.11.: Brakk-Mode – dieser Trupp des Durchgangs kommt als Elite (-1 = keiner)

func _lade_durchgang() -> void:
	_durchgang += 1
	_durchgang_sek = _kampf_sek
	_schlange = []
	_pausen = []
	_trupp_nr = 0
	_ausgaenge = []
	_locker = []
	var locker: Array = _welle.get("locker", [])
	var ausgaenge: Array = _welle.get("ausgaenge", [])
	var trupps: Array = _welle["trupps"]
	var jeder: Array = _welle.get("jeder", [])
	var pausen: Array = _welle.get("pausen", [])
	for i in trupps.size():
		if i < jeder.size() and int(jeder[i]) > 1 and _durchgang % int(jeder[i]) != 0:
			continue
		_schlange.append((trupps[i] as Array).duplicate())
		_pausen.append(float(pausen[i]) if i < pausen.size() else 0.0)
		_ausgaenge.append(str(ausgaenge[i]) if i < ausgaenge.size() else "")
		_locker.append(bool(locker[i]) if i < locker.size() else false)
	if Werte.ZONE2.size != Vector2i.ZERO and phantom_modus == "":
		_zange_teilen()   # 20.11. (Zange): jeden Trupp halbieren
	_elite_nr = -1
	if brakk_modus and welle in Werte.BRAKK_ELITE_RUNDEN and _durchgang <= 1 and _schlange.size() >= 2:   # 20.11.: feste Liste
		_elite_nr = Zufall.ganz_von_bis(1, _schlange.size() - 1)   # nicht der erste Trupp
	var info: Array = _welle.get("wurf_info", [])
	var wuerfe: Array = _welle["wurf"]
	for i in wuerfe.size():
		var eintrag := {"typen": (wuerfe[i] as Array).duplicate(), "nach": 0, "wenn": ""}
		if i < info.size():
			eintrag["nach"] = int(info[i]["nach"])
			eintrag["wenn"] = String(info[i]["wenn"])
			if (info[i] as Dictionary).has("ziel"):
				eintrag["ziel"] = info[i]["ziel"]
			if (info[i] as Dictionary).has("zeit"):
				eintrag["zeit"] = float(info[i]["zeit"])
		_wurf_schlange.append(eintrag)


## Die Welle, die als Nächstes kommt – in der Sandbox mit den dort eingestellten Gegnerzahlen.
func naechste_welle() -> Dictionary:
	if order24 != null:
		return Werte.welle_aus_plan({"name": "Befehl 24", "trupps": []}, 1)   # 20.11.: keine Myriaden-Wellen
	if phantom_modus == "angriff":
		return Werte.welle_aus_plan({"name": "Dein Angriff", "trupps": _plaene.get(welle, []), "wurf_frei": true}, welle)
	if phantom_modus == "verteidigung" and not _phantom_trupps(welle).is_empty():
		return Werte.welle_aus_plan({"name": "Angriff von %s" % str(_angriff_phantom.get("spieler", "?")), "trupps": _phantom_trupps(welle), "wurf_frei": true}, welle)
	var w := Werte.welle(welle)
	if Werte.KARTE_WELLEN.has(welle):
		# 18.11.: Szenario mit eigener Welle für diese Runde (Taktikplaner im Szenario-Editor); sonst die entworfene
		w = Werte.welle_aus_plan({"name": "Welle des Szenarios", "trupps": Werte.KARTE_WELLEN[welle], "wurf_frei": true}, welle)
	if herausforderung == "doppelt":
		w = _verdoppelt(w)   # 18.11.: jeder Trupp kommt zweimal (Vorschau und Welle)
	if brakk_modus:
		# 18.11. (Paul): Brakk-Mode – erst einmal deutlich schwerer: dreimal so viele Gegner, je Runde zusätzlich zäher
		w = _gebuendelt(w, BRAKK_GEGNER_MAL)   # 18.11. (Paul): gebündelt – jeder Trupp in 2,2-facher Stärke auf einmal
		w["leben_faktor"] = float(w.get("leben_faktor", 1.0)) * (1.0 + BRAKK_LEBEN_JE_RUNDE * float(welle - 1))
	if not sandbox or sandbox_gegner.is_empty():
		return w
	var anzahl := {}
	for g: Dictionary in w["gruppen"]:
		anzahl[g["typ"]] = g["anzahl"]
	for typ: String in sandbox_gegner:
		anzahl[typ] = sandbox_gegner[typ]
	# Sprenger zuerst, dann je Typ Trupps zu fünft (Belagerungstürme einzeln), reihum gemischt
	var listen: Array = []
	var gruppen: Array = []
	for typ: String in ["sprenger", "hund", "fahne", "sphaere", "rauch", "belagerung", "schild", "sani", "schwarm"]:
		var n := int(anzahl.get(typ, 0))
		if n <= 0:
			continue
		gruppen.append({"typ": typ, "anzahl": n})
		var liste: Array = []
		var je := 1 if typ == "belagerung" else 5
		while n > 0:
			var trupp: Array = []
			for i in mini(je, n):
				trupp.append(typ)
			n -= trupp.size()
			liste.append(trupp)
		listen.append(liste)
	var trupps: Array = []
	var uebrig := true
	while uebrig:
		uebrig = false
		for liste: Array in listen:
			if not liste.is_empty():
				trupps.append(liste.pop_front())
				uebrig = true
	w["gruppen"] = gruppen
	w["trupps"] = trupps
	w["pausen"] = []
	w["jeder"] = []
	w["wurf"] = []
	w["wurf_info"] = []
	w["name"] = "Eigene Welle"
	return w


func sandbox_aendere_gegner(typ: String, um: int) -> void:
	var jetzt := 0
	for g: Dictionary in naechste_welle()["gruppen"]:
		if g["typ"] == typ:
			jetzt = g["anzahl"]
	sandbox_gegner[typ] = clampi(jetzt + um, 0, 200)


## Neue Bauphase: welche der zwei Varianten kommt? (vorher nur eine)
func waehle_variante() -> void:
	Zufall.runde(welle)   # 9a: Zufall der Runde haengt nur an Samen und Rundennummer
	variante = Zufall.ganz(2) if welle >= Werte.WELLEN_VARIANTEN_AB else 0


## Sandbox: direkt zu einer Runde springen (nur in der Bauphase). Gebautes bleibt stehen.
func sandbox_springe(nr: int) -> void:
	nr = clampi(nr, 1, Werte.LETZTE_RUNDE)
	if not sandbox or phase != Phase.BAU or nr == welle:
		return
	welle = nr
	waehle_variante()
	_protokoll["sandbox_sprung"] = true
	karte.cp_aktiv = Werte.plan_runde(welle) >= Werte.CHECKPOINTS_AB_WELLE
	_aktualisiere_zone()
	if Werte.plan_runde(welle) >= Werte.SPRENGER_AB_WELLE:
		for b in zonenbauten:
			if b.art == "schleuder":
				schleuder_umzug(b, true)
	karte.zeige_schwachstelle = Werte.plan_runde(welle) >= Werte.SPRENGER_AB_WELLE
	endkampf = welle == Werte.LETZTE_RUNDE and phantom_modus == "angriff"   # 18.11.: sonst erst nach der Abwehr (siehe _starte_gegenangriff)
	karte.schild = not endkampf
	karte.zeige_angriff = endkampf
	karte.aktualisiere_pfad()


func _welle_geschafft() -> void:
	if phantom_modus == "angriff":
		_angriff_runde_fertig()
		if welle >= phantom_runden():
			_angriff_ende("ende", true)
			return
		_naechste_bauphase()
		_lade_phantom_stand()
		_zeige_laufband()
		return
	# 18.11. (Stufe 2): Spielziele ohne Gegenangriff
	if Werte.ziel() == "checkpoints" and karte.cp_aktiv and not karte.cp_feind.has(false):
		_verloren()   # beide Checkpoints beim Gegner
		return
	if Werte.ziel() in ["ueberleben", "checkpoints"] and welle >= Werte.LETZTE_RUNDE:
		_gewonnen()
		return
	if welle == Werte.LETZTE_RUNDE and not endkampf:
		_starte_gegenangriff()
		return
	var bonus := einkommen(Werte.wellen_bonus(welle))   # 18.11.: „Doppeltes Geld“, Werte-Mod
	# Gehaltene Checkpoints zahlen sich aus
	var gehalten := 0
	if karte.cp_aktiv:
		for feind: bool in karte.cp_feind:
			if not feind:
				gehalten += 1
	var cp_bonus := gehalten * Werte.BONUS_JE_CHECKPOINT if Werte.einkommen_an() else 0   # 20.11.: Szenario ohne Einkommen
	# Zinsen auf das, was am Rundenende noch übrig ist
	var zins := Werte.zinsen(budget) if Werte.einkommen_an() else 0
	if zins >= Werte.zins_stufen() * Werte.ZINS_JE_SCHRITT:   # 19.11.: Zinsdeckel je Anführer
		erfolg("sparfuchs")   # 18.11.
	var erz := erz_ertrag()
	budget += bonus + cp_bonus + zins + erz
	_auftrag_pruefen("ende")   # 20.11.: Pauls Aufträge
	# 18.11.: Abrechnungskarte statt Meldezeile
	_einblendung.abrechnung("RUNDE %d ÜBERSTANDEN" % welle, [["Rundenbonus", bonus], ["Zinsen", zins],
		["Checkpoints %d/%d" % [gehalten, karte.checkpoints.size()], cp_bonus], ["Erzadern", erz]])
	_schliesse_runde("geschafft")
	_naechste_bauphase()


## 18.11. (Stufe 2): Bauzeit-Limit eines Szenarios – nach Ablauf startet die Welle von selbst.
var bauzeit_rest := -1.0   # Sekunden (Echtzeit); < 0 = kein Limit in dieser Bauphase

func _starte_bauzeit() -> void:
	bauzeit_rest = float(Werte.bauzeit()) if Werte.bauzeit() > 0 and szenario_editor == null and tutorial == null else -1.0


func _bauzeit_tick(delta: float) -> void:
	if bauzeit_rest < 0.0 or phase != Phase.BAU or _menue != null or (_hud != null and _hud.pausiert()):
		return
	bauzeit_rest -= delta / maxf(Engine.time_scale, 0.01)
	if bauzeit_rest <= 0.0:
		bauzeit_rest = -1.0
		melde("Die Bauzeit ist um – die Welle kommt.", 3.0)
		starte_welle(true)


## 18.11.: Minenfeld – der erste Gegner am Boden auf einem scharfen Feld löst die Mine aus (einmal je Runde).
var _minen_scharf: Dictionary = {}

func _minen_pruefen() -> void:
	if _minen_scharf.is_empty():
		return
	for g in gegner:
		if not is_instance_valid(g) or g._auf_wall:
			continue
		var z := karte.zelle_bei(g.position)
		if _minen_scharf.has(z):
			_minen_scharf.erase(z)
			effekte.fx("spreng", karte.mitte(z) + Vector2(0, 20), 0.4)
			g.nimm_schaden(Werte.MINE_SCHADEN)


## 18.11. (Etappe 2): Erzadern – jede Fabrik oder jeder Turm auf einer Erzader bringt ERZ_BONUS je Runde.
func erz_ertrag() -> int:
	var n := 0
	for z: Vector2i in karte.boden:
		if karte.boden[z] == "erz" and (karte.inhalt(z) == Karte.FABRIK or karte.ausbau.get(z, Karte.FREI) == Karte.TURM):
			n += 1
	return einkommen(n * Werte.ERZ_BONUS)


## Runde 20, zweiter Teil (18.11.): Die erste Welle ist abgewehrt – Rundenbonus wie sonst, dann fällt der Schild,
## die Truppen (bis auf eine je Fabrik) verlassen die Stellungen, und die Gegner kommen in Schleife (Leben wie früher im Endkampf).
func _starte_gegenangriff() -> void:
	var bonus := einkommen(Werte.wellen_bonus(welle))   # 18.11.: „Doppeltes Geld“, Werte-Mod
	var zins := Werte.zinsen(budget)
	budget += bonus + zins
	endkampf = true
	_welle["leben_faktor"] = Werte.endkampf_leben()
	karte.schild = false
	karte.zeige_angriff = true
	karte.aktualisiere_pfad()
	_nachspiel = 0.0
	_spawn_in = Werte.ENDKAMPF_PAUSE
	# je Fabrik bleibt eine Truppe in ihrer Stellung, die übrigen steigen ab und greifen an
	var bleibt := {}
	for e in einheiten:
		if not is_instance_valid(e) or e.posten_zelle == Karte.KEINE or e.zustand != Einheit.Zustand.AUF_POSTEN:
			continue
		if e.ist_pilot or e.in_batterie() or e.daten.get("pilot", false):
			continue
		if not bleibt.has(e.fabrik_zelle):
			bleibt[e.fabrik_zelle] = e
			continue
		if karte.posten.get(e.posten_zelle) == e:
			karte.posten.erase(e.posten_zelle)
		e.posten_verloren()
	_einblendung.banner("GEGENANGRIFF!", "Der Schild ist gefallen – zerstört das HQ der Myriaden.", _F_ROT)   # 18.11.
	melde("Welle abgewehrt: +%d Budget. Der Schild ist gefallen – GEGENANGRIFF! Zerstört das HQ. Gebt euren Truppen einen Fußweg (blaue Linie)." % (bonus + zins), 12.0)
	Ton.spiele(self, "alert")


## Runde hochzählen und alles für die nächste Bauphase herrichten.
func _naechste_bauphase() -> void:
	welle += 1
	waehle_variante()
	_auftrag_neu()   # 20.11.: Pauls Aufträge
	if welle == Werte.WAELLE_AB_WELLE and not sandbox and phantom_modus != "angriff" and herausforderung in ["", "doppelt"]:
		freie_waelle = Werte.startpaket_waelle()   # 19.11.: je Anführer
		melde("Erdwälle sind frei: Die ersten %d bekommst du geschenkt. Lenke damit den Gegnerweg um – unten rechts siehst du, wie lang er wird." % freie_waelle, 9.0)
	if Werte.plan_runde(welle) >= Werte.CHECKPOINTS_AB_WELLE and not karte.cp_aktiv:   # 20.11.: Szenario-Wellen aus dem Pool zählen nach ihrem Plan
		karte.cp_aktiv = true
		karte.aktualisiere_pfad()
	_aktualisiere_zone()
	# Stein-Schleudern stehen in jeder Runde woanders; der neue Kreis ist in der Bauphase zu sehen
	if Werte.plan_runde(welle) >= Werte.SPRENGER_AB_WELLE:
		for b in zonenbauten:
			if b.art == "schleuder":
				schleuder_umzug(b, true)
	karte.zeige_schwachstelle = Werte.plan_runde(welle) >= Werte.SPRENGER_AB_WELLE
	if welle == Werte.LETZTE_RUNDE:
		if phantom_modus == "angriff":
			endkampf = true
			karte.schild = false
			karte.zeige_angriff = true
			karte.aktualisiere_pfad()
			melde("Letzte Runde: Dein Schild ist gefallen, die Verteidiger greifen dein HQ an. Dein Plan läuft in Schleife – halte so lange wie möglich oder brich durch.", 12.0)
		elif Werte.ziel() != "gegenangriff":
			melde("Letzte Runde: Übersteht ihr diese Welle, ist die Partie gewonnen." if Werte.ziel() == "ueberleben" else "Letzte Runde: Übersteht sie und haltet mindestens einen Checkpoint.", 10.0)
		else:
			# 18.11. (Paul): Runde 20 in zwei Teilen – erst die Welle ganz normal abwehren (alle in Stellung wie in
			# Runde 19), danach fällt der Schild und es geht in den Gegenangriff.
			melde("Letzte Runde: Wehrt zuerst die Welle ab wie gewohnt. Danach fällt der Schild und ihr geht in den Gegenangriff auf das HQ.", 12.0)
	phase = Phase.BAU
	karte.brut_aktualisieren()
	karte.zeige_pfad_kraeftig = true
	for e in einheiten:
		if e != kommandant:
			e.queue_free()
	einheiten.clear()
	for tz: Vector2i in _werkschutz.keys():   # 21.11.: Rundenende – der Werkschutz ist wieder vollzählig im Truppenturm
		if str(karte.turm_art.get(tz, "")) != "truppen":
			_werkschutz.erase(tz)
			karte.werkschutz_zahl.erase(tz)
			continue
		_werkschutz[tz] = {"timer": 0.0, "einheiten": [], "drin": int(karte.turm_wert(tz, "werkschutz", 2)), "ruhe": 0.0, "schuss": 0.0}
		karte.werkschutz_zahl[tz] = int(_werkschutz[tz]["drin"])
	if kommandant != null:
		kommandant.neue_runde()
		einheiten.append(kommandant)
	if klonmaschine != null:
		klonmaschine.queue_free()
		klonmaschine = null
	for z: Vector2i in fabriken:
		(fabriken[z]["einheiten"] as Array).clear()
	_auswahl = null
	karte.posten.clear()
	karte.besatzung.clear()
	karte.fortschritt.clear()
	karte.repariere_alles()
	for i in karte.checkpoints.size():
		karte.cp_einnahme[i] = 0.0
		karte.cp_fortschritt[i] = 0.0
		karte.cp_tempo[i] = 0.0
	effekte.leeren()
	if herausforderung == "mauern_fest":
		setze_kartenmauern(Werte.MAUERN_FEST, true)   # 18.11.: die fertige Mauer steht zu jeder Bauphase wieder (Erdwälle baut man hier nicht)
	_merke_sitzung("Bauphase")   # 19.11.
	_speichere_zwischenstand()
	_starte_bauzeit()   # 18.11.
	if brakk_modus and ego == null and hd != null and kommandant != null:
		_ego_umschalten.call_deferred()   # 18.11.: Brakk-Mode – nach einem Fall geht es in der Bauphase wieder in die Ego-Sicht


# ------------------------------------------------- Rückmeldungen der Figuren

## Felder, die Truppen auf dem Weg zu ihrer Stellung meiden: alles im Gefahrenradius um einen Gegner am Boden.
func gefahrenzellen(radius: float = Werte.GEFAHR_RADIUS) -> Dictionary:
	if _gefahr_stand != Engine.get_physics_frames():   # 9a: je Simulationsschritt neu
		_gefahr_stand = Engine.get_physics_frames()
		_gefahr_je = {}
	if _gefahr_je.has(radius):
		return _gefahr_je[radius]
	var zellen := {}
	var r := int(ceil(radius))
	for g in gegner:
		if g._auf_wall:
			continue
		var mitte := karte.zelle_bei(g.position)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if Vector2(dx, dy).length() <= radius:
					zellen[mitte + Vector2i(dx, dy)] = true
	_gefahr_je[radius] = zellen
	return zellen


## Schutzschild: Gegner in ihrer Zone sind bis zur letzten Runde nicht angreifbar.
func _geschuetzt(g: Gegner) -> bool:
	if order24 != null and g == order24.brakk_ziel:
		return false   # 20.11. (Paul): Befehl 24 – am Myriaden-HQ gibt es keinen Schild, Brakk ist dort nicht sicher
	return not endkampf and karte.zelle_bei(g.position).x < Werte.ZONE_SPALTEN


## Die Spitze des Gegners: wer auf der Hauptlinie am weitesten Richtung Basis vorgerückt ist.
func vorderster_gegner() -> Gegner:
	var bester: Gegner = null
	var kleinster := 1 << 20
	for g in gegner:
		if _geschuetzt(g):
			continue
		var rest := g.rest_weg()
		if rest < kleinster:
			kleinster = rest
			bester = g
	return bester


## Wo fängt diese Bodentruppe einen Gegner ab? Ein Feld auf dem Weg eines Gegners, an dem sie VOR ihm ankommt.
## Sie läuft also entgegen (auch durch ein Tor), nie hinterher. Karte.KEINE = niemand ist abzufangen: stehen bleiben.
func abfangfeld(e: Einheit) -> Vector2i:
	var hier := karte.zelle_bei(e.position)
	var grenze := Werte.ZONE_SPALTEN + (0 if endkampf else Werte.ZONE_ABSTAND)
	for cp: Vector2i in karte.checkpoints:
		grenze = mini(grenze, cp.x)   # ein Checkpoint nah an der Zone wird trotzdem verteidigt
	var e_tempo: float = maxf(float(e.daten["tempo"]), 0.1)
	var kandidaten: Array = []
	for g in gegner:
		if not _geschuetzt(g) and g.rest_weg() < (1 << 20):
			kandidaten.append(g)
	kandidaten.sort_custom(func(x: Gegner, y: Gegner): return x.rest_weg() < y.rest_weg())
	var geprueft := 0
	var gesehen := {}
	for g: Gegner in kandidaten:
		var weg: Array[Vector2i] = g.kommender_weg(Werte.ABFANG_WEIT)
		if weg.is_empty() or gesehen.has(weg[0]):
			continue   # Gegner desselben Trupps laufen denselben Weg: einmal prüfen reicht
		gesehen[weg[0]] = true
		geprueft += 1
		if geprueft > 4:
			break
		# Ein stehender Gegner (nimmt einen Checkpoint ein, kämpft) kommt nicht entgegen: zu ihm hingehen.
		var g_tempo: float = 0.02 if g.steht() else maxf(g.tempo(), 0.1)
		for i in weg.size():
			var z: Vector2i = weg[i]
			if z.x < grenze or not karte.ist_frei(z):
				continue
			if z != hier and _abfaenger_auf(z, e) >= Werte.ABFANG_JE_FELD:
				continue
			var zu_fuss := karte.einheiten_weg(hier, z)
			if zu_fuss.is_empty() and z != hier:
				continue
			# rechtzeitig da? (eine halbe Sekunde Luft)
			if maxi(zu_fuss.size() - 1, 0) / e_tempo <= i / g_tempo + 0.5:
				return z
	return Karte.KEINE


func _abfaenger_auf(z: Vector2i, ausser: Einheit) -> int:
	var n := 0
	for e in einheiten:
		if e != ausser and e.marschziel() == z:
			n += 1
	return n


# ------------------------------------------------------------ Reparatur durch Reservepiloten

var _ausfall_zeit: Dictionary = {}  # von einem Sprenger gesprengte Fabrik -> Sekunden, bis sie von selbst wieder läuft
var _reparaturen: Dictionary = {}   # Gebäude- oder Turmfeld -> Pilot, der es gerade übernimmt

## Das nächste kaputte Ding, das dieser Pilot zu Fuß erreicht: {"z": Feld, "neben": Feld daneben} oder {}.
func reparaturziel(pilot: Einheit) -> Dictionary:
	if order24 != null:
		return order24.reparaturziel(pilot)   # 20.11.: Befehl 24 – nur der eigene Pilot, nur sabotierte Fabriken
	var hier := karte.zelle_bei(pilot.position)
	var kaputt: Array[Vector2i] = []
	for z: Vector2i in karte.ausgefallen:
		kaputt.append(z)
	for z: Vector2i in karte.turm_schaden:
		if karte.turm_lahm(z):
			kaputt.append(z)
	var bestes := {}
	var beste := 1 << 20
	for z in kaputt:
		var wer: Variant = _reparaturen.get(z)
		if is_instance_valid(wer) and wer != pilot and einheiten.has(wer):
			continue
		for n in Karte.NACHBARN:
			var neben: Vector2i = z + n
			if not karte.ist_frei(neben):
				continue
			var weg := karte.einheiten_weg(hier, neben)
			if weg.is_empty() and hier != neben:
				continue
			if weg.size() < beste:
				beste = weg.size()
				bestes = {"z": z, "neben": neben}
	if not bestes.is_empty():
		_reparaturen[bestes["z"]] = pilot
	return bestes


func ist_kaputt(z: Vector2i) -> bool:
	return karte.ausgefallen.has(z) or karte.turm_lahm(z)


func repariere(z: Vector2i, still: bool = false) -> void:
	_reparaturen.erase(z)
	if OS.get_environment("TD_WURF_LOG") != "":
		print("REPARIERT R%d %s (%s)" % [welle, z, "Turm" if karte.turm_lahm(z) else "Gebäude"])
	if karte.turm_lahm(z):
		karte.turm_schaden.erase(z)
		melde("Ein Reservepilot hat einen Turm wieder in Gang gebracht.", 3.0)
	elif karte.ausgefallen.has(z):
		for betroffen: Vector2i in [z, karte.paar.get(z, Karte.KEINE)]:
			if betroffen != Karte.KEINE and karte.feld.has(betroffen):
				karte.ausgefallen.erase(betroffen)
				karte.leben[betroffen] = karte.max_leben(karte.feld[betroffen])
		if not still:
			melde("Ein Reservepilot hat ein ausgefallenes Gebäude repariert.", 3.0)
	karte.queue_redraw()


## Ist im Umkreis von `radius` um `punkt` gerade kein Gegner?
func ist_ruhig(punkt: Vector2, radius: float) -> bool:
	for g in gegner:
		if punkt.distance_to(g.position) <= radius:
			return false
	return true


func naechster_gegner(von: Vector2) -> Gegner:
	var bester: Gegner = null
	var beste := INF
	for g in gegner:
		if _geschuetzt(g):
			continue
		var d := von.distance_squared_to(g.position)
		if d < beste:
			beste = d
			bester = g
	return bester


## Nächster Gegner innerhalb der Reichweite; mit `braucht_sicht` nur, wenn kein Wall dazwischen liegt.
## `von_wall` = Erdwall, auf dem der Schütze steht (Stellung, Turm): Dann gilt die Sichtregel von oben.
## Ziel in Reichweite und Sicht. `modus`: "erste" (am weitesten auf dem Weg – Grundregel), "letzte", "staerkste".
## Provokation: Ein Schildträger in Reichweite und Sicht geht in jedem Modus vor (Brakk übergeht das mit `provokation = false`).
func gegner_in_reichweite(von: Vector2, weite: float, braucht_sicht: bool, von_wall: Vector2i = Karte.KEINE, modus: String = "erste", provokation: bool = true) -> Gegner:
	var bester: Gegner = null
	var beste := INF
	var schildtraeger: Gegner = null
	var bester_schild := INF
	var grenze := weite * weite
	for g in gegner:
		var d := von.distance_squared_to(g.position)
		if d > grenze or _geschuetzt(g):
			continue
		var wert: float
		match modus:
			"letzte":
				wert = -float(g.rest_weg()) + d * 1e-6
			"staerkste":
				wert = -g.leben + d * 1e-6
			_:
				wert = float(g.rest_weg()) + d * 1e-6
		# 9a (Leistung): die teure Sichtprüfung nur, wenn der Gegner überhaupt gewählt würde – das Ergebnis ist dasselbe
		if wert >= beste and not (provokation and g.rolle == "schild" and wert < bester_schild):
			continue
		if von_wall != Karte.KEINE and not karte.sicht_von_wall(von_wall, von, g.position):
			continue
		if braucht_sicht and not karte.sicht_frei(von, g.position):
			continue
		if wert < beste:
			beste = wert
			bester = g
		if provokation and g.rolle == "schild" and wert < bester_schild:
			bester_schild = wert
			schildtraeger = g
	return schildtraeger if schildtraeger != null else bester


## Zielwahl der Truppen einer Fabrik (im Fabrikmenü einstellbar).
func zielmodus(fabrik: Vector2i) -> String:
	return str(fabriken.get(fabrik, {}).get("ziel", "erste"))


func setze_zielmodus(fabrik: Vector2i, modus: String) -> void:
	if not fabriken.has(fabrik):
		return
	fabriken[fabrik]["ziel"] = modus
	_notiere({"a": "ziel", "x": fabrik.x, "y": fabrik.y, "modus": modus})


## Stellungen, die einer Fabrik per Pfeil zugewiesen sind (leer = frei wählen).
func zugewiesen(fabrik: Vector2i) -> Array:
	var liste: Array = []
	for w in fabriken.get(fabrik, {}).get("stellungen", []):
		if karte.ausbau.get(w, Karte.FREI) == Karte.STELLUNG:
			liste.append(w)
	return liste


## Für welche Fabrik ist diese Stellung reserviert? (KEINE = frei für alle)
func reserviert_fuer(stellung: Vector2i) -> Vector2i:
	for f: Vector2i in fabriken:
		if (fabriken[f].get("stellungen", []) as Array).has(stellung):
			return f
	return Karte.KEINE


## Pfeil von der Fabrik auf eine Stellung: zuweisen oder (zweites Mal) wieder lösen.
func schalte_zuweisung(fabrik: Vector2i, stellung: Vector2i) -> void:
	if not fabriken.has(fabrik) or karte.ausbau.get(stellung, Karte.FREI) != Karte.STELLUNG or str(fabriken[fabrik]["typ"]) == "pilot":
		return
	var liste: Array = fabriken[fabrik].get("stellungen", [])
	if liste.has(stellung):
		liste.erase(stellung)
	else:
		# Eine Stellung gehört nur einer Fabrik: bei einer anderen austragen
		for f2: Vector2i in fabriken:
			if f2 != fabrik:
				(fabriken[f2].get("stellungen", []) as Array).erase(stellung)
		liste.append(stellung)
		erfolg("fester_platz")   # 18.11.
		# Sitzt dort eine fremde Truppe, räumt sie den Platz
		var inh: Variant = karte.posten.get(stellung)
		if inh != null and is_instance_valid(inh) and inh.fabrik_zelle != fabrik:
			karte.posten.erase(stellung)
			inh.verdraengt()
	fabriken[fabrik]["stellungen"] = liste
	_notiere({"a": "zuweisung", "x": fabrik.x, "y": fabrik.y, "sx": stellung.x, "sy": stellung.y})
	melde("Stellungen dieser Fabrik: %d zugewiesen%s" % [zugewiesen(fabrik).size(), "" if not zugewiesen(fabrik).is_empty() else " – die Truppen wählen wieder frei"], 3.0)
	karte.queue_redraw()


func naechste_bodeneinheit(von: Vector2, max_abstand: float) -> Einheit:
	var bester: Einheit = null
	var beste := max_abstand * max_abstand
	for e in einheiten:
		if not e.am_boden():
			continue
		var d := von.distance_squared_to(e.position)
		if d <= beste:
			beste = d
			bester = e
	return bester


## Ziel für einen Fernkämpfer: die nächste Einheit – in Stellung, oder am Boden bei freier Sicht.
## Türme sind vorerst unangreifbar.
## `nur`: 0 = Stellungen und sichtbare Bodentruppen, 1 = nur Truppen in Stellungen, 2 = nur sichtbare Bodentruppen
func fernziel(von: Vector2, weite: float, nur: int = 0) -> Einheit:
	var bestes: Einheit = null
	var beste := weite * weite
	for e in einheiten:
		var d := von.distance_squared_to(e.position)
		if d <= beste and e.am_boden() and karte.boden_bei(e.position) == "wald" and d > pow(Werte.WALD_SICHT * Werte.ZELLE, 2.0):
			continue   # 18.11.: im Wald erst aus der Nähe zu sehen
		if d <= beste and ((nur != 2 and e.in_stellung()) or (nur != 1 and e.am_boden() and karte.sicht_frei(von, e.position))):
			beste = d
			bestes = e
	return bestes


## Letzte Runde: Jede Bodentruppe bekommt ihr eigenes Feld in der Zone, in Schussweite zum HQ.
## So treten die Truppen durchs Schild und verteilen sich, statt sich auf einem Feld davor zu stapeln.
var _angriffsfelder: Dictionary = {}   # Zelle -> Einheit

func angriffsfeld(e: Einheit) -> Vector2i:
	for z: Vector2i in _angriffsfelder:
		if _angriffsfelder[z] == e:
			return z
	var belegt := {}
	for z: Vector2i in _angriffsfelder.keys():
		var wer: Variant = _angriffsfelder[z]
		if is_instance_valid(wer) and einheiten.has(wer):
			belegt[z] = true
		else:
			_angriffsfelder.erase(z)
	for b in zonenbauten:
		belegt[b.zelle] = true
	var ziel := hq.position if is_instance_valid(hq) else karte.mitte(Werte.ANGRIFFS_ZELLE)
	var weite: float = (float(e.daten["reichweite"]) - 0.4) * Werte.ZELLE
	var bestes := Karte.KEINE
	var beste := INF
	# die Zone selbst und zwei Spalten davor, falls sie voll ist
	for x in Werte.ZONE_SPALTEN + 2:
		for y in Werte.ZEILEN:
			var z := Vector2i(x, y)
			if belegt.has(z) or not karte.ist_frei(z):
				continue
			# In Schussweite zum HQ so weit hinten wie möglich (die nahen Felder bleiben für Truppen mit kurzer Reichweite);
			# gibt es kein Feld in Schussweite mehr, das nächste zum HQ.
			var d := karte.mitte(z).distance_to(ziel)
			var wertung := -d if d <= weite else 100000.0 + d
			if wertung < beste:
				beste = wertung
				bestes = z
	if bestes == Karte.KEINE:
		return Werte.ANGRIFFS_ZELLE
	_angriffsfelder[bestes] = e
	return bestes


func gib_angriffsfeld_frei(e: Einheit) -> void:
	for z: Vector2i in _angriffsfelder.keys():
		if _angriffsfelder[z] == e:
			_angriffsfelder.erase(z)


## Ziel für Schüsse eigener Truppen in der letzten Runde: das nächste Gebäude in der Zone des Gegners.
func zonenbau_in_reichweite(von: Vector2, weite: float, braucht_sicht: bool, von_wall: Vector2i = Karte.KEINE) -> Zonenbau:
	if not endkampf:
		return null
	var bester: Zonenbau = null
	var beste := weite * weite
	for b in zonenbauten:
		var d := von.distance_squared_to(b.position)
		if d > beste:
			continue
		if von_wall != Karte.KEINE and not karte.sicht_von_wall(von_wall, von, b.position):
			continue
		if not braucht_sicht or karte.sicht_frei(von, b.position):
			beste = d
			bester = b
	return bester


func zonenbau_zerstoert(b: Zonenbau) -> void:
	zonenbauten.erase(b)
	b.queue_free()
	if b == hq and phantom_modus == "angriff":
		_angriff_ende("hq")
	elif b == hq:
		_gewonnen()
	else:
		melde("Schleuder zerstört!", 3.0)


## 18.11.: Partie gewonnen – HQ zerstört oder (Szenario) das Spielziel erreicht.
func _gewonnen() -> void:
	if phase == Phase.ENDE:
		return
	ausgang = "sieg"
	loesche_sitzung()   # 19.11.
	phase = Phase.ENDE
	if not sandbox:
		loesche_zwischenstand()   # 18.11.
	_schliesse_runde("sieg")
	# 18.11.: Erfolge zum Sieg
	if Werte.ziel() == "gegenangriff":
		_phantom_neu = not Profil.phantom_frei()
		erfolg("gegenangriff")
		_phantom_neu = _phantom_neu and Profil.phantom_frei()   # 21.11. (Paul): Hinweis auf dem Siegbild
	if leben >= _leben_vor_runde:
		erfolg("unberuehrt")
	if not _fabrik_gebaut():
		erfolg("ohne_fabrik")
	_erfolge_zum_sieg()   # 19.11.
	var als_phantom := false
	if protokoll_an and not ohne_spuren and not sandbox and not _protokoll.has("sandbox_sprung") and Werte.ist_hauptkarte() and not brakk_modus and herausforderung == "" and Anfuehrer.ranglistenfaehig(Werte.anfuehrer) and not _protokoll.has("code"):   # 18.11.: Phantome nur auf der Hauptkarte, nicht im Brakk-Mode oder in Herausforderungen; 19.11.: nicht mit Paul; 20.11.: nicht per Code
		# Eine gewonnene Partie wird zum Verteidigungs-Phantom für den Phantom-Modus
		var daten := Phantom.aus_partie(_protokoll, _protokoll_datei)
		var vpfad := "" if daten.is_empty() else Phantom.speichere("verteidigung", daten)
		als_phantom = vpfad != ""
		if als_phantom:
			_merke_export(daten, "verteidigung")
			Profil.phantom_erstellt()
			erfolg("spiegelbild")   # 18.11.
			_verteidigung_online.call_deferred(vpfad, daten)
	var besiegt := 0
	for n: int in _profil_kills.values():
		besiegt += n
	var sek := 0.0
	for r: Dictionary in _protokoll.get("runden", []):
		sek += float((r.get("ergebnis", {}) as Dictionary).get("sekunden", 0.0))
	var vw := _partie_ins_profil(true)
	if brakk_modus and ego != null:
		ego.sieg(sek)   # 19.11.: Brakk-Mode – eigener Abspann und Übersicht
		if order24 == null and not sandbox and phantom_modus == "":
			Profil.setze_einstellung("rogue_frei", true)   # 20.11. (Paul): Classic gewonnen – Rogue ist frei …
			ego._sieg_bericht["weiter"] = Werte.anfuehrer == "brakk"   # … und Brakk kann gleich weiterspielen (Befehl 24)
		return
	_zeige_sieg({"welle": welle, "leben": leben, "max_leben": Werte.START_LEBEN, "besiegt": besiegt,
		"sekunden": sek, "phantom": als_phantom, "wertung": vw}, als_phantom)


## Ziel einer Schleuder: die nächste Truppe in einer Stellung, sonst die nächste Fabrik (als Zelle).
func schleuderziel(von: Vector2, weite: float) -> Variant:
	if brakk_modus and kommandant != null and not kommandant.gefallen and Zufall.f() < 0.5 and von.distance_to(kommandant.position) <= weite:
		return kommandant   # 18.11. (Paul): Brakk-Mode – jeder zweite Wurf gilt Brakk, wenn er in Reichweite ist
	var bestes: Variant = null
	var beste := weite * weite
	for e in einheiten:
		if not e.in_stellung() or karte.in_kuppel(e.position):
			continue
		var d := von.distance_squared_to(e.position)
		if d <= beste:
			beste = d
			bestes = e
	if bestes != null:
		return bestes
	# keine Stellung in Reichweite: dann auf den dichtesten Haufen Bodentruppen (Flächentreffer)
	var haufen: Variant = haufen_ziel(von, weite)
	if haufen != null:
		return haufen
	for z: Vector2i in karte.feld:
		if (karte.feld[z] != Karte.FABRIK and karte.feld[z] != Karte.BATTERIE) or karte.ausgefallen.has(z) or karte.in_kuppel(karte.mitte(z)):
			continue
		var d := von.distance_squared_to(karte.mitte(z))
		if d <= beste:
			beste = d
			bestes = z
	return bestes


## Mitte des dichtesten Haufens von Bodentruppen in Reichweite (mindestens Werte.HAUFEN_MIN), sonst null.
func haufen_ziel(von: Vector2, weite: float, ohne_rauch: bool = false) -> Variant:
	var bestes: Variant = null
	var meiste := Werte.HAUFEN_MIN - 1
	var radius := Werte.HAUFEN_RADIUS * Werte.ZELLE
	for e in einheiten:
		if not e.bodentruppe() or von.distance_to(e.position) > weite or (ohne_rauch and effekte.im_rauch(e.position)) or karte.in_kuppel(e.position):
			continue
		var n := 0
		for f in einheiten:
			if f.bodentruppe() and e.position.distance_to(f.position) <= radius:
				n += 1
		if n > meiste:
			meiste = n
			bestes = e.position
	return bestes


## Ein Stein, der unter einer Schildkuppel einschlagen würde, prallt ab.
func _prallt_ab(punkt: Vector2) -> bool:
	if not karte.in_kuppel(punkt):
		return false
	for k: Array in karte.kuppeln:
		if punkt.distance_to(k[0]) <= float(k[1]):
			objekt_zaehle(k[2], "abgewehrt", 1.0)
			erfolg("kuppelschlag")   # 18.11.
			break
	effekte.flaeche(punkt, 18.0, Color(0.6, 0.85, 1.0))
	return true


func _einschlag_haufen(punkt: Vector2) -> void:
	Ton.am_ort(self, "hit-thud", punkt)
	if _prallt_ab(punkt):
		return
	var radius := Werte.HAUFEN_RADIUS * Werte.ZELLE
	effekte.flaeche(punkt, radius, Color("c9a26b"))
	if OS.get_environment("TD_WURF_LOG") != "":
		print("HAUFEN R%d Stein bei %s" % [welle, karte.zelle_bei(punkt)])
	for e in einheiten.duplicate():
		if is_instance_valid(e) and e.bodentruppe() and e.position.distance_to(punkt) <= radius:
			e.nimm_fernschaden(Werte.SCHLEUDER["schaden_haufen"])   # 18.11.: Ruine deckt


## Ein Sprenger ohne lohnenden Erdwall hat eine Fabrik erreicht: Sie fällt für die Runde aus, Bodentruppen daneben werden getroffen.
func sprengung_fabrik(g: Gegner, z: Vector2i) -> void:
	var mitte := karte.mitte(z)
	if Werte.grafik_neu:
		effekte.fx("spreng", mitte + Vector2(0, 20), 0.5)
		Ton.spiele(self, "hit-boom")
	for i in 8:
		effekte.linie(mitte, mitte + Vector2.RIGHT.rotated(TAU * i / 8.0) * 60.0, Color("ffb347"))
	gegner_entfernt(g)
	if karte.beschiesse(z, Werte.SPRENGER_FABRIK_SCHADEN):
		_ausfall_zeit[z] = Werte.SPRENGER_FABRIK_SEK
	if OS.get_environment("TD_WURF_LOG") != "":
		print("SPRENGT FABRIK R%d %s" % [welle, z])
	var radius := Werte.SPRENGER_TRUPP_RADIUS * Werte.ZELLE
	effekte.flaeche(mitte, radius, Color("ffb347"))
	for e in einheiten.duplicate():
		if is_instance_valid(e) and e.bodentruppe() and e.position.distance_to(mitte) <= radius:
			e.nimm_schaden(Werte.SPRENGER_TRUPP_SCHADEN)
	melde("Ein Sprenger hat eine Fabrik gesprengt – sie fällt %d Sekunden aus." % int(Werte.SPRENGER_FABRIK_SEK), 4.0)


func wurf(von: Zonenbau, ziel: Variant) -> void:
	# Eine Einheit kann sterben, während der Stein fliegt: deshalb nur ihre Kennung mitgeben, nicht das Objekt.
	# 16.11.: der Stein bleibt kurz im ausholenden Arm (SCHLEUDER_ABWURF), die Landezeit bleibt gleich
	var arm := Werte.SCHLEUDER_ABWURF
	Ton.am_ort(self, "myr-launch", von.position)
	if ziel is Vector2:
		effekte.wurf(von.position + Vector2(0, -30), ziel, Werte.SCHLEUDER["flugzeit"], _einschlag_haufen.bind(ziel), "stein", "", arm)
	elif ziel is Vector2i:
		effekte.wurf(von.position + Vector2(0, -30), karte.mitte(ziel), Werte.SCHLEUDER["flugzeit"], _einschlag_gebaeude.bind(ziel), "stein", "", arm)
	else:
		var e := ziel as Einheit
		effekte.wurf(von.position + Vector2(0, -30), e.position, Werte.SCHLEUDER["flugzeit"], _einschlag_einheit.bind(e.get_instance_id(), e.position), "stein", "", arm)


func _einschlag_gebaeude(zelle: Vector2i) -> void:
	Ton.am_ort(self, "hit-thud", karte.mitte(zelle))
	if _prallt_ab(karte.mitte(zelle)):
		return
	if karte.inhalt(zelle) == Karte.FABRIK or karte.inhalt(zelle) == Karte.BATTERIE:
		karte.beschiesse(zelle, Werte.SCHLEUDER["schaden_fabrik"])   # fällt für die Runde aus, wird nicht zerstört


func _einschlag_einheit(kennung: int, gezielt: Vector2 = Vector2.INF) -> void:
	if not is_instance_id_valid(kennung):
		return
	var e := instance_from_id(kennung) as Einheit
	if e is Kommandant and brakk_modus:
		# 18.11. (Paul): Brakk-Mode – der Stein fliegt auf einen Punkt; wer rechtzeitig wegspringt (Shift), wird nicht getroffen
		Ton.am_ort(self, "hit-thud", gezielt)
		effekte.flaeche(gezielt, Werte.ZELLE * 0.7, Color("c9a26b"))
		if not _prallt_ab(gezielt) and e.position.distance_to(gezielt) <= Werte.ZELLE * 0.7:
			e.nimm_schaden(Werte.SCHLEUDER["schaden_einheit"])
		return
	if e != null and _prallt_ab(e.position):
		return
	if e != null and einheiten.has(e) and e.in_stellung():
		e.nimm_fernschaden(Werte.SCHLEUDER["schaden_einheit"])   # 18.11.: Ruine deckt


## Mausposition in Weltkoordinaten – in der HD-2D-Ansicht über die 3D-Kamera ermittelt.
## nur_boden: Mauerkronen nicht beachten (beim Wall-Ziehen, sonst "hängt" die Maus auf der gerade gebauten Wand).
func maus_welt(nur_boden: bool = false) -> Vector2:
	if hd != null:
		return hd.maus_welt(nur_boden)
	return get_global_mouse_position()


## Weltpunkt -> Bildschirmpunkt (für Menüs und Hinweise an Feldern; in HD-2D über die 3D-Kamera).
func welt_zu_bild(p: Vector2) -> Vector2:
	if hd != null:
		return hd.welt_zu_bild(p)
	return get_global_transform_with_canvas() * p


func schuss(von: Vector2, nach: Vector2, farbe: Color) -> void:
	if Werte.grafik_neu:
		effekte.neu_schuss(von, nach, farbe)
	else:
		effekte.linie(von, nach, farbe)


## Neue Grafik: für jeden Turm ein TurmBild zwischen den Figuren (so verdeckt er Figuren dahinter richtig).
func _turmbilder_abgleichen() -> void:
	for z: Vector2i in turmbilder.keys():
		if karte.ausbau.get(z, Karte.FREI) != Karte.TURM or karte.inhalt(z) != Karte.WALL:
			(turmbilder[z] as Node).queue_free()
			turmbilder.erase(z)
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.TURM and karte.inhalt(z) == Karte.WALL and not turmbilder.has(z):
			var t := TurmBild.new()
			t.karte = karte
			t.zelle = z
			t.position = karte.mitte(z) + Vector2(0, 24)
			figuren.add_child(t)
			turmbilder[z] = t
	_elitekronen_abgleichen()   # 20.11. (Nachtrag)
	_mg_bilder_abgleichen()   # 20.11. (Nachtrag)
	for z: Vector2i in karte.feld:
		if karte.feld[z] == Karte.BATTERIE:
			karte.batterie_stufe_neu[z] = batterie_stufe(z)


## 20.11. (Paul, Nachtrag): MG-Stellung (Sonde 7) – Lauf mit Munitionsgurt auf jeder Stellung (2D und HD-2D).
var _mg_bilder := {}   # Stellungs-Zelle -> Node2D
const MG_BILD_MASSSTAB := 1.5   # 21.11.: 64er-Bild, etwa so groß wie der PliPlop

func _mg_besetzt_zeigen() -> void:
	for z: Vector2i in _mg_bilder:
		var p := (_mg_bilder[z] as Node).get_node_or_null("Besetzt") as Sprite2D
		if p != null:
			var e: Variant = karte.posten.get(z)
			p.texture = Platzhalter.punkte(1 if e != null and is_instance_valid(e) and (e as Einheit).in_stellung() else 0, 1)


func _mg_bilder_abgleichen() -> void:
	var an := Werte.mg_stellung()
	for z: Vector2i in _mg_bilder.keys():
		if not an or karte.ausbau.get(z, Karte.FREI) != Karte.STELLUNG:
			(_mg_bilder[z] as Node).queue_free()
			_mg_bilder.erase(z)
	if not an:
		return
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.STELLUNG and not _mg_bilder.has(z):
			var k := Node2D.new()
			k.position = karte.mitte(z) + Vector2(0, 14)
			var s := Sprite2D.new()
			s.centered = false
			if ResourceLoader.exists(Werte.NEU + "tuerme/mg_nest.png"):
				# 21.11. (Paul): PixelLab-Bild des MG-Nests – steht vor der Truppe auf der Stellung
				s.texture = load(Werte.NEU + "tuerme/mg_nest.png")
				s.scale = Vector2(MG_BILD_MASSSTAB, MG_BILD_MASSSTAB)
				s.offset = Vector2(-34, -60)
			else:
				s.texture = Platzhalter.mg_aufsatz()
				s.scale = Vector2(2, 2)
				s.offset = Vector2(-14, -16)
			k.add_child(s)
			# 21.11. (Paul): Punkt über dem Nest – besetzt (cyan) oder leer (dunkel), wie die Werkschutz-Punkte am Truppenturm
			var p := Sprite2D.new()
			p.name = "Besetzt"
			p.centered = false
			p.scale = Vector2(3, 3)
			p.offset = Vector2(-3, -34)
			p.texture = Platzhalter.punkte(0, 1)
			k.add_child(p)
			figuren.add_child(k)
			_mg_bilder[z] = k


## 20.11. (Paul, Nachtrag): Elitefabrik (Stufe 4, Sonde 7) – goldene Krone über der Fabrik (2D und HD-2D).
var _elitekronen := {}   # Fabrik-Zelle -> Sprite2D

func _elitekronen_abgleichen() -> void:
	for z: Vector2i in _elitekronen.keys():
		if not fabriken.has(z) or int(fabriken[z].get("stufe", 0)) < 4:
			(_elitekronen[z] as Node).queue_free()
			_elitekronen.erase(z)
	for z: Vector2i in fabriken:
		if int(fabriken[z].get("stufe", 0)) >= 4 and not _elitekronen.has(z):
			var k := Node2D.new()
			k.position = karte.mitte(z) + Vector2(0, 20)
			k.add_child(Platzhalter.kronen_sprite(52.0, 2.0))
			figuren.add_child(k)
			_elitekronen[z] = k


# ------------------------------------------------------------ Schadensliste [Tab]
# Jeder Treffer an einem Gegner wird der Quelle gutgeschrieben, die gerade feuert: eine Fabrik (alle ihre Truppen),
# eine Turmart oder eine Batterie. Gezählt wird nur Schaden, der wirklich Leben nimmt (kein Überschuss beim letzten Treffer).
var schadensquelle := ""
var brakk_quelle := ""   # 19.11.: Brakk-Mode – Unterquelle von Brakks Schaden (pistole, lanze, saeule, ring …), setzt die Ego-Sicht
var brakk_mark_selbst := false   # 19.11.: Zeitlupe mit Zielring – Brakks Markierung gilt auch für seine eigenen Schüsse
var runde_stats: Dictionary = {}    # Quelle -> {"schaden", "kills", "name", "blatt", "zelle", "farbe"}
var gesamt_stats: Dictionary = {}   # dasselbe über die ganze Partie
var runde_stats_welle := 0          # zu welcher Runde runde_stats gehört

## Werte je Turm, Batterie und Generator: Zelle -> {"schaden", "kills", "heilung", "gerettet", "instand", "abgefangen", "abgewehrt", "gebremst"}
var objekt_stats: Dictionary = {}
var schadensobjekt := Karte.KEINE   # welcher Turm gerade Schaden austeilt

## 20.11.: Takt-Faktor eines Turms (Überladen des Irrtürmers im Brakk-Mode); sonst 1.
func turm_takt(z: Vector2i) -> float:
	if turm_ueberladen.is_empty() or not turm_ueberladen.has(z):
		return 1.0
	var e: Array = turm_ueberladen[z]
	if Time.get_ticks_msec() >= int(e[0]):
		turm_ueberladen.erase(z)
		return 1.0
	return float(e[1])

func objekt_zaehle(z: Vector2i, art: String, menge: float) -> void:
	if z == Karte.KEINE or menge <= 0.0:
		return
	if not objekt_stats.has(z):
		objekt_stats[z] = {}
	objekt_stats[z][art] = float(objekt_stats[z].get(art, 0.0)) + menge


## Kuppel eines Generators hat Schaden an einer Truppe abgefangen.
func kuppel_abgefangen(punkt: Vector2, menge: float) -> void:
	for k: Array in karte.kuppeln:
		if punkt.distance_to(k[0]) <= float(k[1]):
			objekt_zaehle(k[2], "abgefangen", menge)
			return


func zaehle_schaden(menge: float, getoetet: bool) -> void:
	if schadensquelle == "" or menge <= 0.0:
		return
	if schadensquelle == "fabrik:-1,-1" and kommandant != null and kommandant.fortschritt != null:
		kommandant.fortschritt.zaehle_quelle(brakk_quelle, menge, getoetet, welle)   # 19.11.
	if getoetet:
		_profil_kill(schadensquelle)
		if schuetze is Einheit and is_instance_valid(schuetze) and schadensquelle.begins_with("fabrik:") \
				and (schuetze as Einheit).in_stellung() and karte.ist_wachposten((schuetze as Einheit).posten_zelle):
			erfolg("einsamer_posten")
	if schadensquelle.begins_with("turm:") and schadensobjekt != Karte.KEINE:
		objekt_zaehle(schadensobjekt, "schaden", menge)
		if getoetet:
			objekt_zaehle(schadensobjekt, "kills", 1.0)
	for tabelle: Dictionary in [runde_stats, gesamt_stats]:
		if not tabelle.has(schadensquelle):
			tabelle[schadensquelle] = {"schaden": 0.0, "kills": 0}
		var e: Dictionary = tabelle[schadensquelle]
		e["schaden"] = float(e["schaden"]) + menge
		if getoetet:
			e["kills"] = int(e["kills"]) + 1
		e.merge(_quelle_info(schadensquelle), true)


## Name und Bild einer Schadensquelle (für die Liste). Eine Fabrik zeigt ihre Truppe, Stufe und Fähigkeit.
func _quelle_info(quelle: String) -> Dictionary:
	var teile := quelle.split(":")
	match teile[0]:
		"fabrik":
			var xy := teile[1].split(",")
			var z := Vector2i(int(xy[0]), int(xy[1]))
			if z == Karte.KEINE:
				return {"name": Werte.KOMMANDANT["name"], "blatt": Werte.KOMMANDANT["blatt"], "zelle": Werte.KOMMANDANT["zelle"]}
			if karte.turm_art.get(z, "") == "truppen":   # 20.11. (Nachtrag): Werkschutz eines Truppenturms
				var tg: Dictionary = Werte.EINHEITEN["technogunner"]
				return {"name": "Werkschutz (Truppenturm)", "blatt": tg["blatt"], "zelle": tg["zelle"]}
			if not fabriken.has(z):
				return {}
			var f: Dictionary = fabriken[z]
			var d: Dictionary = Werte.EINHEITEN[f["typ"]]
			var name: String = d["name"]
			var stufe := int(f.get("stufe", 0))
			if stufe > 0:
				name += " · Stufe %d" % stufe
			var fae := str(f.get("faehigkeit", ""))
			if fae != "" and Werte.STUFE_3.has(f["typ"]) and (Werte.STUFE_3[f["typ"]] as Dictionary).has(fae):
				name += " · " + str(Werte.STUFE_3[f["typ"]][fae]["name"])
			return {"name": name, "blatt": d["blatt"], "zelle": d["zelle"]}
		"turm":
			var art: Dictionary = Werte.TURMARTEN.get(teile[1], Werte.TURMARTEN["geschuetz"])
			return {"name": art["name"] + " (alle)", "farbe": art["farbe"]}
		"batterie":
			return {"name": "Batterie", "blatt": Werte.BATTERIE["blatt"], "zelle": Werte.BATTERIE["zelle"]}
	return {"name": quelle}


func gegner_besiegt(g: Gegner) -> void:
	Ton.am_ort(self, "death-myr", g.position)
	if not g.klon and brakk_modus:
		# 18.11. (Paul): Brakk-Mode – dreimal so viele Gegner, aber dieselbe Wirtschaft: je Gegner ein Drittel der Prämie
		# (Bruchteile werden gesammelt, damit auch 2er-Prämien zählen)
		_brakk_praemie += float(einkommen(Werte.praemie(int(g.daten["praemie"])))) / BRAKK_GEGNER_MAL * (Werte.BRAKK_ELITE_PRAEMIE if g.elite else 1.0)   # 19.11.: Elite; 19.11.: Prämie je Anführer
		var ganz := floori(_brakk_praemie)
		budget += ganz
		_brakk_praemie -= float(ganz)
	elif not g.klon:
		budget += einkommen(Werte.praemie(int(g.daten["praemie"])))   # 18.11.: „Doppeltes Geld“, Werte-Mod; 19.11.: Prämien-Faktor je Anführer
	gegner_entfernt(g)


## Gegner ohne Prämie aus dem Spiel nehmen (gesprengt, leerer Belagerungsturm).
func gegner_entfernt(g: Gegner) -> void:
	g.trupp.erase(g)
	gegner.erase(g)
	g.queue_free()


## Kommandant Brakk aufs Feld stellen (auch beim Laden eines Phantom-Stands und im Replay).
func _setze_kommandant(z: Vector2i) -> void:
	kommandant = Kommandant.new()
	figuren.add_child(kommandant)
	kommandant.einrichten_kommandant(self, karte, z)
	einheiten.append(kommandant)


## WASD steuert Brakk, solange er angeklickt ist und kein Menü oder Fenster die Tastatur braucht (16.11.: sonst handelt er selbst).
func kommandant_steuerbar() -> bool:
	return kommandant_gewaehlt() and _tastatur_frei() and ego == null


## 18.11. (Paul): Brakk-Mode – eigener Modus aus dem Startmenü. Normales Spiel auf PaulLand, für diese Partie in HD-2D
## (die gespeicherte Grafikwahl bleibt), Brakk steht gratis ab Runde 1 vor der Basis, die Ego-Sicht startet gleich.
## Keine Phantome, keine Rangliste. Zwischenstand seit 19.11. (Brakks Fortschritt dabei).
## 20.11. (Schritt 5b): Order 24 – Brakk allein gegen die Technoclan-Verteidigung. Ego-Sicht wie im Brakk-Mode, aber
## ohne Wellen: Order24 baut die Karte, startet nach der Einsatz-Tafel und entscheidet über Sieg und Niederlage.
func _order24_gewaehlt() -> void:
	brakk_modus = true
	_tempo_faktor = Werte.BRAKK_TEMPO
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor
	Werte.setze_grafik("hd")   # nicht gespeichert
	Werte.setze_anfuehrer("brakk")   # 20.11. (Paul): Befehl 24 gilt nur Brakk
	_setze_anfuehrer(Werte.anfuehrer)
	order24 = Order24.new()
	add_child(order24)
	var vorher := budget
	order24.einrichten(self)
	budget = vorher   # der Aufbau der Karte kostet nichts
	_zeige_einfuehrung()
	_menue_weg()
	var z := order24.brakk_start()
	_setze_kommandant(z)
	for i in 3:
		await get_tree().process_frame
	if ego == null and hd != null and kommandant != null:
		_ego_umschalten()


## 20.11. (Paul): Classic gewonnen, „Weiterspielen …?“ – die Partie geht als Befehl 24 weiter: Die eigene Verteidigung
## (Wälle, Türme, Fabriken, Stellungen, Truppen) bleibt stehen und wird zum Gegner, Brakk steht am eigenen HQ, und
## Sonde 7 hintergeht ihn (Verrat-Sequenz mit Schockimpuls: Erfahrung und Ringe weg). Die Myriaden sind fort, ihr HQ
## steht als Zuflucht wieder (Platzhalter: neu aufgestellt).
func befehl24_weiterspielen() -> void:
	if order24 != null or ego == null:
		return
	ego.sieg_aufheben()
	for g in gegner.duplicate():
		if is_instance_valid(g):
			g.queue_free()
	gegner.clear()
	_schlange.clear()
	_pausen.clear()
	_wurf_schlange.clear()
	_wurf_aktiv.clear()
	for b in zonenbauten.duplicate():
		if is_instance_valid(b):
			b.queue_free()
	zonenbauten.clear()
	hq = _neuer_zonenbau("hq", Werte.START_ZELLE)
	endkampf = false
	welle = 1
	phase = Phase.BAU
	werkzeug = Karte.FREI
	_tempo_faktor = Werte.BRAKK_TEMPO
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor
	for i in karte.cp_feind.size():
		karte.cp_feind[i] = false
	Werte.KARTE_REGELN["bauten"] = {"batterie": false, "fabrik": false, "generator": false, "panzer": false, "stellung": false, "tor": false, "turm": false, "wall": false}
	Werte.KARTE_REGELN["brakk_stufe"] = 4
	# Truppen zurück an ihre Fabriken (sie standen im Gegenangriff in der Zone)
	for e in einheiten:
		if not is_instance_valid(e) or e is Kommandant:
			continue
		if e.posten_zelle != Karte.KEINE and karte.posten.get(e.posten_zelle) == e:
			karte.posten.erase(e.posten_zelle)
		e.posten_zelle = Karte.KEINE
		if fabriken.has(e.fabrik_zelle):
			e.position = karte.mitte(e.fabrik_zelle)
		e.zustand = Einheit.Zustand.BODEN
		e._punkte.clear()
	order24 = Order24.new()
	order24.weiter = true
	add_child(order24)
	order24.einrichten(self)
	budget = 300   # 20.11. (Paul): wie das Startgold von Befehl 24 – nicht gleich Ringe kaufen
	if kommandant != null:
		kommandant.position = karte.mitte(order24.brakk_start())
		kommandant.anker = kommandant.position
		kommandant.leben = kommandant.max_leben
	print("BEFEHL24 Weiterspielen nach dem Classic-Sieg")


## 20.11. (Schritt 5b): Ziele für Brakks Waffen in der Ego-Sicht – in Order 24 die Technoclan-Stellvertreter.
func ego_gegner() -> Array:
	return order24.ego_ziele() if order24 != null else gegner


func _brakk_modus_gewaehlt() -> void:
	brakk_modus = true
	# 18.11.: festes Tempo – Brakk selbst läuft in Echtzeit, ein wählbares Tempo würde ihn mal stark, mal schwach machen
	_tempo_faktor = Werte.BRAKK_TEMPO
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor
	Werte.setze_grafik("hd")   # nicht gespeichert
	Werte.setze_anfuehrer(Werte.anfuehrer if Werte.ego_hat(Werte.anfuehrer) else "brakk")   # 19.11.: der Brakk-Mode ist Brakk; 20.11.: oder ein anderer Anführer mit Ego-Kit (Auswahl im Startmenü)
	_normales_spiel()
	_menue_weg()
	var z := _feld_vor_basis()
	if z != Karte.KEINE:
		_setze_kommandant(z)
		_notiere({"a": "bau", "typ": "kommandant", "x": z.x, "y": z.y})
	# die HD-Ansicht entsteht erst im nächsten Bild (_process) – dann in die Ego-Sicht
	for i in 3:
		await get_tree().process_frame
	if ego == null and hd != null and kommandant != null:
		_ego_umschalten()
	BrakkTutorial.anbieten(self)   # 22.11. (Paul): beim ersten Brakk-Mode das Tutorial anbieten


## Freies Feld möglichst nah vor der Basis (Richtung Gegner), für Brakk im Brakk-Mode.
func _feld_vor_basis() -> Vector2i:
	var bestes := Karte.KEINE
	var beste_d := INF
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			if not karte.ist_bebaubar(z):
				continue
			var d := Vector2(z - (karte.basis + Vector2i(-2, 0))).length()
			if d < beste_d:
				beste_d = d
				bestes = z
	return bestes


## [G] Ego-Sicht mit Brakk an/aus (18.11., Prototyp): nur im Brakk-Mode (Paul 18.11.), in HD-2D und wenn Brakk steht.
func _ego_umschalten() -> void:
	if ego != null and brakk_modus:
		return   # 18.11. (Paul): Der Brakk-Mode gibt es nur in der Ego-Sicht – kein Umschalten
	if ego != null:
		ego.beenden()
		return
	if not brakk_modus:
		melde("Die Ego-Sicht gibt es im Brakk-Mode (Startmenü).", 4.0)
		return
	if hd == null:
		melde("Die Ego-Sicht gibt es nur in der Grafik HD-2D.", 4.0)
		return
	if kommandant == null or kommandant.gefallen:
		melde("Stelle zuerst Brakk aufs Feld [8].", 4.0)
		return
	if phantom_modus == "angriff":
		return
	ego = EgoModus.new()
	add_child(ego)
	ego.starten(self)


func kommandant_gewaehlt() -> bool:
	return kommandant != null and _auswahl == kommandant


func _tastatur_frei() -> bool:
	return _menue == null and phase != Phase.ENDE and not (_lexikon != null and _lexikon.visible) and not (_laufband != null and _laufband.visible)


## WASD schwenkt die Kamera, solange Brakk nicht angeklickt ist.
func wasd_kamera() -> bool:
	return not kommandant_gewaehlt() and _tastatur_frei()


func _kommandant_meldung(text: String) -> void:
	if text != "":
		melde(text, 4.0)


## [R]: Klonmaschine auf ein freies Feld setzen (einmal pro Runde, hält bis zum Rundenende).
func stelle_klonmaschine(z: Vector2i) -> String:
	if kommandant == null or kommandant.gefallen:
		return ""
	if kommandant.klon_genutzt:
		return "Die Klonmaschine gibt es nur einmal pro Runde."
	if not karte.ist_begehbar(z) or z.x < Werte.ZONE_SPALTEN or not karte.in_karte(z):
		return "Die Klonmaschine braucht ein freies Feld."
	kommandant.klon_genutzt = true
	klonmaschine = Klonmaschine.new()
	klonmaschine.spiel = self
	klonmaschine.karte = karte
	klonmaschine.zelle = z
	klonmaschine.position = karte.mitte(z)
	figuren.add_child(klonmaschine)
	_notiere({"a": "klon", "x": z.x, "y": z.y})
	if order24 != null:
		order24.brakk_gewohnheit("klon")   # 22.11. (Nemesis Teil 4): Angewohnheiten zählen
	return "Klonmaschine steht: Wer hindurchgeht, wird einmal geklont – deine Truppen, aber auch Gegner."


## Klone aus der Klonmaschine: mit dem aktuellen Leben des Originals.
func klone_gegner(g: Gegner) -> void:
	erfolg("doppelgaenger")   # 18.11.
	var c := _neuer_gegner(g.typ, karte.zelle_bei(g.position), g._ziel)
	c.position = g.position + Vector2(Zufall.von_bis(-8, 8), Zufall.von_bis(-6, 6))
	c.leben = g.leben
	c.klon = true
	c.trupp = g.trupp
	g.trupp.append(c)
	c.plane_neu()


func klone_einheit(e: Einheit) -> void:
	if not fabriken.has(e.fabrik_zelle):
		return
	var f: Dictionary = fabriken[e.fabrik_zelle]
	var c := Einheit.new()
	figuren.add_child(c)
	c.start(self, karte, f["typ"], e.fabrik_zelle, int(f.get("stufe", 0)), str(f.get("faehigkeit", "")))
	c.position = e.position + Vector2(Zufall.von_bis(-8, 8), Zufall.von_bis(-6, 6))
	c.leben = minf(e.leben, c.max_leben)
	c.klon = true
	einheiten.append(c)
	if is_instance_valid(e.folge):
		c.folge_kommandant(e.folge)
		(e.folge as Kommandant).gesammelt.append(c)


## Schwarmgeist gefallen: er zerfällt in Myr-Drohnen, die als eigener Trupp am Boden weiterkämpfen.
func zerfall(g: Gegner) -> void:
	var rudel: Array = []
	var zelle := karte.zelle_bei(g.position)
	if not karte.ist_begehbar(zelle):
		return
	for i in int(g.daten.get("zerfall", 3)):
		var d := _neuer_gegner("enterer", zelle, g._ziel)
		d._auf_wall = false   # Myr-Drohnen aus dem Schwarmgeist kämpfen am Boden
		d._wall_zelle = Karte.KEINE
		d.position = g.position + Vector2(Zufall.von_bis(-14, 14), Zufall.von_bis(-10, 10))
		if karte.zelle_bei(d.position) != zelle:
			d.position = g.position   # 17.11.: nicht in eine Mauer daneben streuen
		d._letzte_frei = zelle
		d.trupp = rudel
		rudel.append(d)
		d.plane_neu()
	effekte.flaeche(g.position, Werte.ZELLE * 0.9, Color("ff7ad9"))


func _neuer_gegner(typ: String, zelle: Vector2i, erstes_ziel: int) -> Gegner:
	var g := Gegner.new()
	figuren.add_child(g)
	g.start(self, karte, typ, _welle["leben_faktor"], zelle, erstes_ziel)
	gegner.append(g)
	if brakk_modus and _trupp_nr == _elite_nr and not _schlange.is_empty():
		g.mache_elite()
		if _trupp.is_empty():
			# 19.11. (Paul): Elite-Trupp mit Ansage (20.11.: nur in Werte.BRAKK_ELITE_RUNDEN)
			_einblendung.banner("ELITE-TRUPP", "Ein verstärkter Trupp greift an – mehr Leben, mehr Schaden, Treffer streifen.", Color("ff8a3a"))
			Ton.spiele(self, "alert")
	if typ == "sprenger":
		melde("Sprenger unterwegs! Sein Ziel blinkt orange.", 4.0)
	return g


## Wurf-Schleuder: Trupps zu vier fliegen über die Mauer. Die nächste bereite Schleuder wirft den nächsten Trupp;
## alle vier landen an derselben Stelle und bleiben als Trupp zusammen.
func _wurf_tick(delta: float) -> void:
	var schleudern: Array = []
	for b in zonenbauten:
		if b.art == "wurf":
			schleudern.append(b)
	if schleudern.is_empty():
		# keine Wurf-Schleuder (mehr): die restlichen Wurf-Trupps laufen zu Fuß
		for eintrag: Dictionary in _wurf_schlange:
			_schlange.append(eintrag["typen"])
			_pausen.append(0.0)
		_wurf_schlange = []
		if not _wurf_aktiv.is_empty():
			_schlange.append(_wurf_aktiv)
			_pausen.append(0.0)
			_wurf_aktiv = []
		return
	if _wurf_aktiv.is_empty():
		if _wurf_schlange.is_empty():
			return
		# Würfe, die auf einen Belagerungsturm warten, obwohl keiner mehr kommt: normal werfen
		var turm_kommt := false
		for typen: Array in _schlange:
			if typen.has("belagerung"):
				turm_kommt = true
		for g in gegner:
			if g.rolle == "belagerung":
				turm_kommt = true
		# der nächste Wurf, der dran ist: sein Auslöser ist erfüllt und genug Lauf-Trupps sind unterwegs
		var dran := -1
		for i in _wurf_schlange.size():
			var e: Dictionary = _wurf_schlange[i]
			if e["wenn"] != "" and not turm_kommt:
				e["wenn"] = ""
			if e["wenn"] == "" and (int(e["nach"]) <= _trupp_nr or _schlange.is_empty()) and _kampf_sek - _durchgang_sek >= float(e.get("zeit", 0.0)):
				dran = i
				break
		if dran < 0:
			return
		var eilt: bool = _wurf_schlange[dran].get("eilt", false)
		if not eilt and not _welle.get("wurf_frei", false) and _kampf_sek < float(Werte.WURF["wartet"]) and not endkampf:
			return   # sie hält sich zurück, bis die eigenen Truppen vorgerückt sind
		_wurf_bau = null
		for b: Zonenbau in schleudern:
			if b.wurfbereit() or (eilt and _wurf_bau == null):
				_wurf_bau = b
				if b.wurfbereit():
					break
		if _wurf_bau == null:
			return
		var eintrag: Dictionary = _wurf_schlange[dran]
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
			ziel = karte.wurf_landefeld(_wurf_bau.zelle, eintrag["meiden"], Werte.WURF_BELAGERUNG_ABSTAND)
		if ziel.is_empty():
			ziel = karte.wurf_landefeld(_wurf_bau.zelle)
		if ziel.is_empty():
			return
		_wurf_landung = ziel["z"]
		# Geworfene stürmen den nächsten Checkpoint, den der Gegner noch nicht hält – nicht die Basis.
		_wurf_ziel = karte.sturmziel_ab(_wurf_landung)
		_wurf_bau.hat_geworfen()
		_wurf_schlange.remove_at(dran)
		_wurf_aktiv = eintrag["typen"]
		if OS.get_environment("TD_WURF_LOG") != "":
			print("WURF R%d t=%.1f  %s -> %s  %s  %s" % [welle, _kampf_sek, _wurf_bau.zelle, _wurf_landung, _wurf_aktiv, "nahe Turm" if eintrag.has("nahe") else ("Zange" if eintrag.has("meiden") else "")])
		_wurf_trupp = []
		_wurf_takt = 0.0
		var dauer: float = Werte.WURF["flugzeit"] + Werte.WURF["abstand"] * _wurf_aktiv.size() + 0.5
		effekte.warnung(karte.mitte(_wurf_landung), dauer)
	if not is_instance_valid(_wurf_bau):
		_schlange.append(_wurf_aktiv)   # Schleuder mitten im Wurf zerstört: der Rest läuft
		_pausen.append(0.0)
		_wurf_aktiv = []
		return
	_wurf_takt -= delta
	if _wurf_takt > 0.0:
		return
	_wurf_takt = Werte.WURF["abstand"]
	var typ: String = _wurf_aktiv.pop_front()
	_im_flug += 1
	_wurf_bau.ruck()
	Ton.am_ort(self, "myr-launch", _wurf_bau.position)
	effekte.wurf(_wurf_bau.position + Vector2(0, -30), karte.mitte(_wurf_landung), Werte.WURF["flugzeit"], _hund_landet.bind(_wurf_landung, _wurf_ziel, _wurf_trupp, typ), "einheit", typ)


## Ein Belagerungsturm hat angedockt: Sieht der Plan dafür einen Wurf vor, fliegt er sofort – weit weg vom Turm (Zange).
func belagerung_dockt(g: Gegner) -> void:
	_loese_wurf_aus("dock", {"meiden": g.position})


## Ein Belagerungsturm hat eine Myr-Drohne abgesetzt. Bei der zweiten fliegt – falls geplant – ein Wurf auf die Verteidiger am Turm.
func turmtruppe_abgesetzt(turm: Gegner) -> void:
	_abgesetzt[turm] = int(_abgesetzt.get(turm, 0)) + 1
	if _abgesetzt[turm] == 2:
		_loese_wurf_aus("drohnen", {"nahe": turm.position})


func _loese_wurf_aus(wenn: String, zusatz: Dictionary) -> void:
	for i in _wurf_schlange.size():
		var e: Dictionary = _wurf_schlange[i]
		if e["wenn"] == wenn:
			e["wenn"] = ""
			e["nach"] = 0
			e["eilt"] = true
			e.merge(zusatz)
			_wurf_schlange.remove_at(i)
			_wurf_schlange.push_front(e)
			return


func _hund_landet(zelle: Vector2i, erstes_ziel: int, rudel: Array, typ: String = "hund") -> void:
	Ton.am_ort(self, "hit-thud", karte.mitte(zelle))
	_im_flug -= 1
	# Wurde inzwischen dort gebaut? Dann daneben landen.
	var feld := zelle if karte.ist_frei(zelle) else karte.freier_nachbar(zelle)
	if feld != Karte.KEINE:
		var g := _neuer_gegner(typ, feld, erstes_ziel)
		g.geworfen = true
		g.aufrappeln()   # 16.11.: landet geduckt und richtet sich auf
		if OS.get_environment("TD_WURF_LOG") != "":
			print("LANDUNG R%d t=%.1f  %s auf %s, Ziel: %s" % [welle, _kampf_sek, typ, feld, "Basis" if erstes_ziel >= karte.checkpoints.size() else "Checkpoint %d" % (erstes_ziel + 1)])
		g.trupp = rudel
		rudel.append(g)


## Eine Stein-Schleuder zieht auf einen anderen freien Platz in der Zone um.
## `sofort` = zwischen den Runden (steht gleich dort), sonst fährt sie während der Runde hin.
func schleuder_umzug(b: Zonenbau, sofort: bool) -> void:
	var frei: Array[Vector2i] = []
	for z in Werte.SCHLEUDER_PLAETZE:
		var besetzt := false
		for anderer in zonenbauten:
			if anderer.zelle == z:
				besetzt = true
		if not besetzt:
			frei.append(z)
	if not frei.is_empty():
		b.versetze(frei[Zufall.ganz(frei.size())], sofort)


## Wallstücke, die schon ein anderer Sprenger anpeilt: jeder nimmt sich ein eigenes vor.
func sprenger_stuecke(ausser: Gegner) -> Array:
	var stuecke: Array = []
	for g in gegner:
		if g != ausser and g.rolle == "sprenger" and g.sprengt() != Karte.KEINE and karte.inhalt(g.sprengt()) == Karte.WALL:
			stuecke.append(karte.stueck_nr(g.sprengt()))
	return stuecke


## Ein Sprenger hat seinen Erdwall erreicht.
func sprengung(g: Gegner, wall: Vector2i) -> void:
	var mitte := karte.mitte(wall)
	if Werte.grafik_neu:
		effekte.fx("spreng", mitte + Vector2(0, 20), 0.5)
		Ton.spiele(self, "hit-boom")
	for i in 8:
		effekte.linie(mitte, mitte + Vector2.RIGHT.rotated(TAU * i / 8.0) * 44.0, Color("ffb347"))
	# Die Sprengung geht in die Tiefe: auch die Erdwälle direkt dahinter fallen (höchstens SPRENGER_TIEFE, ein Turm hält stand).
	if karte.panzer.has(wall):
		# Gepanzert: Die Sprengung reißt nur die Panzerung weg, der Erdwall bleibt stehen.
		gegner_entfernt(g)
		karte.panzer.erase(wall)
		erfolg("doppelt_haelt")   # 18.11.
		brakk_ereignis("panzer_haelt", {"x": wall.x, "y": wall.y})   # 23.11.
		karte.queue_redraw()
		effekte.flaeche(mitte, 30.0, Color("d8dee9"))
		melde("Die Panzerung hat einen Sprenger abgefangen – der Erdwall steht noch.", 3.0)
		return
	var reihe := karte.sprengt_reihe(wall, karte.zelle_bei(g.position))
	gegner_entfernt(g)
	if OS.get_environment("TD_WURF_LOG") != "":
		print("SPRENG R%d t=%.1f  von %s auf %s (%s) + %s" % [welle, _kampf_sek, karte.zelle_bei(g.position), wall, karte.ausbau.get(wall, 0), reihe])
	karte.schade(wall, 100000.0)
	brakk_ereignis("sprengung", {"x": wall.x, "y": wall.y, "tiefe": reihe.size() + 1})   # 23.11.
	for hinter: Vector2i in reihe:
		var m2 := karte.mitte(hinter)
		for i in 8:
			effekte.linie(m2, m2 + Vector2.RIGHT.rotated(TAU * i / 8.0) * 44.0, Color("ffb347"))
		karte.schade(hinter, 100000.0)
	if reihe.is_empty():
		melde("Ein Sprenger hat einen Erdwall gesprengt!", 3.0)
	else:
		melde("Ein Sprenger hat %d Erdwälle hintereinander gesprengt!" % (reihe.size() + 1), 3.0)


## Ein Belagerungsturm setzt eine Myr-Drohne auf den Wall.
func setze_enterer_ab(wall: Vector2i, leben_faktor: float, erstes_ziel: int) -> Gegner:
	var g := Gegner.new()
	figuren.add_child(g)
	g.start(self, karte, "enterer", leben_faktor, wall, erstes_ziel)
	gegner.append(g)
	return g


## Wohin wirft ein Rauchwerfer? Auf die Stellungstruppe in Wurfweite, um die herum die meisten anderen stehen.
func rauchziel(von: Vector2, weite: float) -> Variant:
	var bestes: Variant = null
	var meiste := 0
	var radius := Werte.RAUCH_RADIUS * Werte.ZELLE
	# Läuft ein Sprenger auf einen Wall zu, nebelt der Rauchwerfer zuerst die Stellungen an dieser Sprengstelle ein.
	for g in gegner:
		if g.rolle != "sprenger" or g.sprengt() == Karte.KEINE:
			continue
		var stelle := karte.mitte(g.sprengt())
		var naechste := INF
		for e in einheiten:
			if not e.in_stellung() or von.distance_to(e.position) > weite or effekte.im_rauch(e.position) or karte.in_kuppel(e.position):
				continue
			var d := e.position.distance_to(stelle)
			if d <= 4.0 * Werte.ZELLE and d < naechste:
				naechste = d
				bestes = e.position
		if bestes != null:
			return bestes
	for e in einheiten:
		if not e.in_stellung() or von.distance_to(e.position) > weite or effekte.im_rauch(e.position) or karte.in_kuppel(e.position):
			continue
		var n := 0
		for f in einheiten:
			if f.in_stellung() and e.position.distance_to(f.position) <= radius:
				n += 1
		if n > meiste:
			meiste = n
			bestes = e.position
	if bestes == null:
		bestes = haufen_ziel(von, weite, true)   # keine Stellungen: dann den dichtesten Haufen am Boden einnebeln
	return bestes


func lege_rauch(von: Vector2, punkt: Vector2) -> void:
	if OS.get_environment("TD_WURF_LOG") != "":
		print("RAUCH R%d auf %s" % [welle, karte.zelle_bei(punkt)])
	effekte.wurf(von + Vector2(0, -20), punkt, 0.8, effekte.rauch.bind(punkt, Werte.RAUCH_RADIUS * Werte.ZELLE, Werte.RAUCH_SEK), "granate")


func im_rauch(punkt: Vector2) -> bool:
	return effekte.im_rauch(punkt)


## Ziel eines Lasers: die nächste Bodentruppe in Reichweite mit freier Sicht (Wälle geben Deckung).
func laserziel(von: Vector2, weite: float) -> Einheit:
	var bester: Einheit = null
	var beste := weite * weite
	for e in einheiten:
		if not e.am_boden() or not karte.ist_frei(karte.zelle_bei(e.position)):
			continue
		var d := von.distance_squared_to(e.position)
		if d <= beste and karte.sicht_frei(von, e.position):
			beste = d
			bester = e
	return bester


func gegner_am_ziel(g: Gegner) -> void:
	if order24 != null and order24.gegner_am_ziel(g):
		return   # 20.11.: Befehl 24 – Myriaden des Überläufers greifen das Technoclan-HQ an
	if OS.get_environment("TD_WURF_LOG") != "":
		print("DURCH R%d t=%.1f  %s%s  Checkpoints beim Gegner: %s" % [welle, _kampf_sek, g.typ, " (geworfen)" if g.geworfen else "", karte.cp_feind])
	g.trupp.erase(g)
	gegner.erase(g)
	g.queue_free()
	_durch_typen[g.typ] = int(_durch_typen.get(g.typ, 0)) + 1   # 18.11.: für die Niederlage-Tafel
	leben -= 1
	if ego != null:
		ego.einbruch(g.position)   # 22.11. (Paul): Einbruch in der Ego-Sicht deutlich anzeigen
	if leben <= 0 and phantom_modus == "angriff":
		leben = 0
		_phantom_gefallen()
	elif leben <= 0:
		leben = 0
		_verloren()


## 18.11.: Partie verloren – keine Leben mehr oder (Szenario „Checkpoints halten“) beide Checkpoints beim Gegner.
func _verloren() -> void:
	if phase == Phase.ENDE:
		return
	ausgang = "niederlage"
	loesche_sitzung()   # 19.11.
	phase = Phase.ENDE
	if not sandbox:
		loesche_zwischenstand()   # 18.11.
	_schliesse_runde("niederlage")
	var rekord := Profil.stat("beste_runde")
	var besiegt := 0
	for n: int in _profil_kills.values():
		besiegt += n
	var vw := _partie_ins_profil(false)
	_zeige_niederlage(vw, rekord, besiegt)
	if phantom_modus == "verteidigung":
		_verteidigung_online.call_deferred("", {})


func einheit_gefallen(e: Einheit) -> void:
	if e is Kommandant:
		(e as Kommandant).faellt()
		return
	if order24 != null:
		order24.gefallen(e)   # 20.11.: Befehl 24 – Sprengladung als Drop
	einheiten.erase(e)
	Ton.am_ort(self, "death-tc", e.position)
	if Werte.grafik_neu:
		effekte.fx("v_tod", e.position + Vector2(0, -6), 0.4)
	if e.posten_zelle != Karte.KEINE and karte.posten.get(e.posten_zelle) == e:
		karte.posten.erase(e.posten_zelle)
	if karte.besatzung.has(e.posten_zelle):
		(karte.besatzung[e.posten_zelle] as Array).erase(e)
	if fabriken.has(e.fabrik_zelle):
		(fabriken[e.fabrik_zelle]["einheiten"] as Array).erase(e)
	e.queue_free()


func _bei_ausfall(zelle: Vector2i, typ: int) -> void:
	if endkampf:
		# Letzte Runde: sie hat kein Ende – ausgefallene Gebäude laufen nach kurzer Zeit von selbst wieder an.
		_ausfall_zeit[zelle] = Werte.SPRENGER_FABRIK_SEK
		melde("Eine %s ist ausgefallen – sie läuft in %d Sekunden wieder an." % ["Batterie" if typ == Karte.BATTERIE else "Fabrik", int(Werte.SPRENGER_FABRIK_SEK)], 3.0)
		return
	melde("Eine %s ist ausgefallen – sie arbeitet erst nächste Runde wieder." % ("Batterie" if typ == Karte.BATTERIE else "Fabrik"), 4.0)


func _bei_zerstoert(zelle: Vector2i, typ: int) -> void:
	if _fabrikmenue != null and _fabrikmenue.zelle == zelle:
		_schliesse_fabrikmenue()
	if typ == Karte.FABRIK:
		fabriken.erase(zelle)
		melde("Eine Fabrik wurde zerstört!", 3.0)
	_turm_abkling.erase(zelle)
	if typ == Karte.WALL:
		for t: Vector2i in karte.ausbau:
			if karte.ausbau[t] == Karte.TURM and (karte.stuetzen.get(t, []) as Array).size() < karte.turm_noetig(t):
				melde("Ein Turm hat eine Stütze verloren und schweigt, bis der Erdwall wieder steht.", 4.0)
				break
	for e in einheiten:
		if e.posten_zelle == zelle:
			e.posten_verloren()
	for g in gegner:
		g.plane_neu()


# ------------------------------------------------------------------- Bauen

## Startpaket: so viele Erdwälle sind noch gratis; welche Felder gratis gebaut wurden (geben beim Abriss nichts zurück).
var freie_waelle := 0
var _gratis: Dictionary = {}
var freie_stellungen := 0                 # 19.11. (Paul): Brakk-Mode – so viele Stellungen sind noch gratis (jede Runde eine)
var _gratis_stellung: Dictionary = {}    # Felder mit einer gratis gebauten Stellung (geben beim Abriss nichts zurück)

func kosten(typ: int) -> int:
	match typ:
		Karte.KOMMANDANT:
			return Werte.KOSTEN_KOMMANDANT
		Karte.WALL:
			return 0 if freie_waelle > 0 else Werte.kosten_wall()   # 19.11.: Preis je Anführer
		Karte.STELLUNG:
			return 0 if freie_stellungen > 0 else Werte.kosten_stellung()   # 21.11. (Paul): MG-Stellung (Sonde 7) kostet 50
		Karte.TURM:
			return Werte.KOSTEN_TURM
		Karte.TOR:
			return Werte.KOSTEN_TOR
		Karte.PANZER:
			return Werte.KOSTEN_PANZER
		Karte.SPIEGEL:
			return Werte.KOSTEN_SPIEGEL
		Karte.MAGNET:
			return Werte.KOSTEN_MAGNET
		Karte.GENERATOR:
			return Werte.KOSTEN_GENERATOR
		Karte.BATTERIE:
			return batterie_preis(_batterien())
	if gratis_fabriken > 0:
		return 0   # 20.11. (Paul): Gratis-Fabrik aus einem Auftrag
	# Fabriken werden teurer, je mehr schon stehen (Pilotenfabriken gehören zur Batterie und zählen nicht mit)
	return int(roundf(Werte.kosten_fabrik() * pow(1.0 + fabrik_prozent() / 100.0, _normale_fabriken()) / 5.0)) * 5   # 19.11.: Preis je Anführer


## 17.11.: Jede weitere Batterie kostet KOSTEN_BATTERIE_PROZENT mehr (gegen Batterie-Spam), auf 5 gerundet.
static func batterie_preis(schon: int) -> int:
	return int(roundf(Werte.KOSTEN_BATTERIE * pow(1.0 + Werte.KOSTEN_BATTERIE_PROZENT / 100.0, schon) / 5.0)) * 5


## So viele Batterien stehen (gezählt über ihre Pilotenfabriken).
func _batterien() -> int:
	var n := 0
	for z: Vector2i in fabriken:
		if karte.paar.has(z):
			n += 1
	return n


func _normale_fabriken() -> int:
	var n := 0
	for z: Vector2i in fabriken:
		if not karte.paar.has(z):
			n += 1
	return n


## So viele Truppen hält diese Fabrik am Leben.
## Letzte Runde (17.11., Paul): Je Fabrik bezieht eine Truppe eine Stellung (die nächste freie), alle anderen greifen das HQ an.
func endkampf_stellung_frei(e: Einheit) -> bool:
	var z: Vector2i = e.fabrik_zelle
	if not fabriken.has(z):
		return false
	var normal := 1   # 17.11. (Paul): eine Truppe je Fabrik bleibt in einer Stellung, der Rest greift an
	var besetzt := 0
	for u in einheiten:
		if u != e and is_instance_valid(u) and u.fabrik_zelle == z and u.posten_zelle != Karte.KEINE:
			besetzt += 1
	return besetzt < normal


## 20.11.: Befehl 24 – eigener Produktionszyklus aus dem Regelpaket (order24.gd), sonst Werte.PRODUKTION_SEK.
func produktion_sek() -> float:
	return order24.produktion_sek() if order24 != null else Werte.PRODUKTION_SEK


func truppen_limit(z: Vector2i) -> int:
	if order24 != null and order24.truppen_limit(z) >= 0:
		return order24.truppen_limit(z)   # 20.11.: Befehl 24 – Stellungen plus Streife, im Schild keine
	var stufe := int(fabriken[z].get("stufe", 0)) if fabriken.has(z) else 0
	if fabriken.has(z) and fabriken[z]["typ"] == "pilot":
		# Pilotenfabrik: immer genug für die Batterie, mit Stufe 1 ein Reservepilot dazu
		return int(Werte.BATTERIE["plaetze"]) + (1 if stufe >= 1 else 0)
	if Werte.truppen_fest() > 0:
		return Werte.truppen_fest()   # 20.11.: Sonde 7 – je Fabrik genau eine Truppe, auch spezialisiert
	var n :=(Werte.MAX_JE_FABRIK_ENDKAMPF if endkampf else Werte.MAX_JE_FABRIK) + sandbox_truppen + int(Werte.mod("fabrik_truppen")) + Werte.truppen_je_fabrik()   # 18.11.: Werte-Mod; 19.11.: je Anführer
	n = maxi(n, 1)
	if stufe >= 1 and not brakk_modus:   # 19.11. (Paul): Brakk-Mode – Stufe 1 gibt keine dritte Truppe (dafür +20 % Leben)
		n += Werte.STUFE_1_TRUPPEN
	return n


## Das Feld, auf dem die Pilotenfabrik einer Batterie auf `z` stünde (mit [T] drehbar).
const PAAR_RICHTUNGEN: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var _paar_richtung := 0

func partner_feld(z: Vector2i) -> Vector2i:
	return z + PAAR_RICHTUNGEN[_paar_richtung]


func _ist_ausbau(typ: int) -> bool:
	return typ == Karte.STELLUNG or typ == Karte.TURM or typ == Karte.TOR or typ == Karte.SPIEGEL or typ == Karte.MAGNET


## Mit dem Turm-Werkzeug [4] auf ein freies Feld: dort entsteht ein Schildgenerator (nur in einem Hof).
func bautyp(z: Vector2i, typ: int) -> int:
	if typ == Karte.TURM and turm_wunsch != "":
		return Karte.TURM   # 21.11.: Wunschturm (PliPlop auf freiem Feld bringt seinen Erdwall mit) – kein Generator
	return Karte.GENERATOR if typ == Karte.TURM and karte.inhalt(z) == Karte.FREI else typ


## Leerer Text = Bauen erlaubt, sonst der Grund, warum nicht.
func bau_hindernis(z: Vector2i, typ: int) -> String:
	if typ == Karte.TURM and turm_wunsch != "":
		return wunsch_hindernis(z)   # 21.11. (Paul)
	typ = bautyp(z, typ)
	if phantom_modus == "angriff":
		return "Im Angriff baut der Verteidiger. Du planst die Welle im Taktikplaner [L]."
	if typ == Karte.KOMMANDANT:
		if herausforderung_sperrt(typ) != "":   # 19.11.: Slot [8] je Anführer (und von der Karte gesperrt)
			return herausforderung_sperrt(typ)
		if kommandant != null:
			return "Brakk ist schon im Spiel – es gibt ihn nur einmal."
		if phase != Phase.BAU:
			return "Brakk kommt zwischen den Wellen aufs Feld."
		if not karte.ist_begehbar(z) or not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN:
			return "Brakk braucht ein freies Feld."
		if budget < kosten(typ):
			return "Nicht genug Budget."
		return ""
	if phase == Phase.KAMPF and endkampf and typ != Karte.STELLUNG:
		# Letzte Runde: alles außer Erdwällen darf auch während des Gegenangriffs gebaut werden.
		if typ == Karte.WALL:
			return "In der letzten Runde gibt es keine neuen Erdwälle – sonst wären die Sprenger wertlos."
	elif phase == Phase.KAMPF:
		# Während der Welle gehen nur Stellungen – und nur dort, wo gerade kein Gegner in der Nähe ist.
		if typ != Karte.STELLUNG:
			return "Während der Welle gehen nur Stellungen [3] und das Umstellen von Fabriken."
		if not ist_ruhig(karte.mitte(z), Werte.STELLUNG_BAU_RUHE * Werte.ZELLE):
			return "Zu nah am Gegner für eine neue Stellung."
	elif phase != Phase.BAU:
		return "Gebaut wird zwischen den Wellen."
	if typ != Karte.FABRIK and not alles_frei():
		return "Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
	var sperre := herausforderung_sperrt(typ)   # 18.11.
	if sperre != "":
		return sperre
	if typ == Karte.GENERATOR:
		var hof := karte.hof_von(z)
		if hof.is_empty():
			return "Turm auf freiem Feld = Schildgenerator: nur in einer Zitadelle (2–%d Felder innen, rundum von Erdwällen eingeschlossen)." % Werte.HOF_MAX
		if not karte.ist_frei(z):
			return "Der Generator braucht ein freies Feld in der Zitadelle."
		if Werte.zitadelle_stufe(hof.size()) >= 3 and welle < Werte.ZITADELLE_III_AB_WELLE and not sandbox:
			return "Zitadelle III (mehr als %d Felder innen) erst ab Welle %d." % [Werte.ZITADELLE_STUFEN[1], Werte.ZITADELLE_III_AB_WELLE]
		for c: Vector2i in hof:
			if karte.inhalt(c) == Karte.GENERATOR:
				return "In dieser Zitadelle steht schon ein Schildgenerator."
	elif typ == Karte.PANZER:
		if karte.inhalt(z) != Karte.WALL:
			return "Panzerung geht nur auf einem Erdwall."
		if karte.panzer.has(z):
			return "Dieser Erdwall ist schon gepanzert."
	elif _ist_ausbau(typ):
		var grund := karte.ausbau_hindernis(z, typ)
		if grund != "":
			return grund
	elif not karte.ist_bebaubar(z):
		return "Hier ist kein Platz." if not Werte.BODEN_UNBEBAUBAR.has(str(karte.boden.get(z, ""))) else "Auf %s wird nicht gebaut." % ("einer Brücke" if karte.boden[z] == "bruecke" else ("Sumpf" if karte.boden[z] == "sumpf" else "Waldboden"))
	elif karte.boden.get(z, "") == "ruine" and typ != Karte.WALL:
		return "Auf einer Ruine geht nur ein Erdwall (für %d)." % Werte.RUINE_KOSTEN_WALL
	elif typ == Karte.BATTERIE and not karte.ist_bebaubar(partner_feld(z)):
		return "Kein Platz für die Pilotenfabrik daneben – mit [T] drehen."
	if budget < kosten_bei(z, typ):
		return "Nicht genug Budget."
	return ""


## 18.11.: Preis an einem bestimmten Feld – ein Erdwall auf einer Ruine ist billiger.
func kosten_bei(z: Vector2i, typ: int) -> int:
	var preis := kosten(typ)
	if typ == Karte.TURM and karte.ausbau.get(z, Karte.FREI) != Karte.TURM and karte.turm_form(z) == "pliplop":
		return Werte.KOSTEN_PLIPLOP   # 20.11. (Paul): PliPlop 3cK
	if typ == Karte.WALL and preis > 0 and karte.boden.get(z, "") == "ruine":
		return mini(preis, Werte.RUINE_KOSTEN_WALL)
	return preis


func baue(z: Vector2i, typ: int, still: bool = false) -> bool:
	if typ == Karte.TURM and turm_wunsch != "":
		return _baue_wunschturm(z)   # 21.11. (Paul): Kachel PliPlop / Truppenturm
	typ = bautyp(z, typ)
	var grund := bau_hindernis(z, typ)
	if grund != "":
		if not still:
			melde(grund)
		return false
	var preis := kosten_bei(z, typ)
	if typ == Karte.WALL and freie_waelle > 0:
		freie_waelle -= 1
		_gratis[z] = true
	if typ == Karte.STELLUNG and freie_stellungen > 0:
		freie_stellungen -= 1
		_gratis_stellung[z] = true
	if typ == Karte.FABRIK and gratis_fabriken > 0:
		gratis_fabriken -= 1   # 20.11. (Paul): Gratis-Fabrik aus einem Auftrag (gibt beim Abriss nichts zurück)
		_gratis[z] = true
	_merke_bezahlt(z, "panzer" if typ == Karte.PANZER else ("ausbau" if _ist_ausbau(typ) else "bau"), preis)
	budget -= preis
	if not still:
		Ton.spiele(self, "tf-earth" if typ == Karte.WALL else "tf-stone")
	var eintrag := {"a": "bau", "typ": BAU_NAMEN[typ], "x": z.x, "y": z.y}
	Auftraege.zaehle(auftrag, "bau:" + str(BAU_NAMEN[typ]))   # 20.11.
	if phase == Phase.KAMPF:
		eintrag["t"] = snappedf(_kampf_sek, 0.1)   # während der Welle gebaut
	_notiere(eintrag)
	if brakk_modus and order24 == null and phase == Phase.BAU and not still and typ != Karte.KOMMANDANT and not _ist_ausbau(typ):
		_bau_stapel.append({"z": z, "typ": typ})   # 22.11.: für [Z] in der Ego-Sicht
		while _bau_stapel.size() > BAU_STAPEL_MAX:
			_bau_stapel.pop_front()
	if typ == Karte.KOMMANDANT:
		_setze_kommandant(z)
		werkzeug = Karte.FREI
		if not still and not brakk_modus and not sandbox and not Profil.brakk_modus_frei():
			erfolg("aufgestellt")   # 21.11. (Paul): schaltet den Brakk-Mode im Startmenü frei
			if Profil.brakk_modus_frei():
				Erfolge.einblendung("Brakk-Modus freigeschaltet – im Startmenü", "", "brakk")
		if not still:
			melde("Kommandant Brakk handelt selbst. Anklicken = steuern: [WASD] bewegen · [Q] Sammeln, nochmal [Q] Losschlagen · [E] auf den Wall/herunter · [R] Klonmaschine. [Esc] oder Klick ins Leere lässt ihn los.", 9.0)
		return true
	if typ == Karte.PANZER:
		karte.panzer[z] = true
		karte.queue_redraw()
		return true
	if typ == Karte.GENERATOR:
		karte.generator_paar[z] = z   # ein Feld: Partner ist er selbst
		karte.setze(z, Karte.GENERATOR)
		if _hud:
			_hud.formvorlage = ""   # 17.11.: gebaut – die Vorlage verschwindet wieder
		if not still:
			melde("Schildgenerator: Die Kuppel deckt den ganzen Ring. Truppen darunter nehmen 40 % weniger Schaden, Steine und Rauch prallen ab.", 6.0)
		return true
	if typ == Karte.MAGNET:
		var r := PAAR_RICHTUNGEN[_paar_richtung]
		eintrag["rx"] = r.x
		eintrag["ry"] = r.y
		karte.magnet_richtung[z] = r
	if _ist_ausbau(typ):
		karte.baue_aus(z, typ)
		if typ == Karte.TURM and karte.turm_art.has(z) and not str(karte.turm_art[z]) in ["truppen", "pliplop"] and not sandbox and Profil.merke_form(str(karte.turm_art[z])) >= Werte.FORMTUERME_ZAHL:
			erfolg("formenlehre")   # 18.11.
		if typ == Karte.TURM and karte.turm_art.has(z):
			_pruefe_baumeister(str(karte.turm_art[z]))   # 19.11.
		if typ == Karte.TURM and _hud:
			_hud.formvorlage = ""   # 17.11.: gebaut – die Vorlage verschwindet wieder
		if typ == Karte.TURM and not still:
			var art: Dictionary = Werte.TURMARTEN[karte.turm_art[z]]
			melde("%s (%s): %s" % [art["name"], art["form"], art["text"]], 5.0)
		return true
	karte.setze(z, typ)
	if typ == Karte.FABRIK:
		fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": Werte.FABRIK_EINHEITEN[0], "stufe": 0}
		karte.fabrik_typ[z] = Werte.FABRIK_EINHEITEN[0]
	elif typ == Karte.BATTERIE:
		# Die Batterie bringt ihre Pilotenfabrik mit: zwei Felder, ein Bauwerk.
		var pz := partner_feld(z)
		eintrag["px"] = pz.x
		eintrag["py"] = pz.y
		karte.setze(pz, Karte.FABRIK)
		fabriken[pz] = {"timer": 0.0, "einheiten": [], "typ": "pilot", "stufe": 0}
		karte.fabrik_typ[pz] = "pilot"
		karte.paar[z] = pz
		karte.paar[pz] = z
	return true


func _merke_bezahlt(z: Vector2i, teil: String, betrag: int) -> void:
	Auftraege.zaehle(auftrag, "ausgaben", betrag)   # 20.11.
	if not _bezahlt.has(z):
		_bezahlt[z] = {}
	_bezahlt[z][teil] = int(_bezahlt[z].get(teil, 0)) + betrag
	if teil == "stufen":
		_bezahlt[z]["stufen_n"] = int(_bezahlt[z].get("stufen_n", 0)) + 1


## So viel gibt es für das Abreißen von `z` zurück: Was in dieser Bauphase dort bezahlt wurde, kommt voll zurück –
## für alles Ältere (Bauwerk, Ausbau, Stufen aus früheren Runden) gibt es den Anteil ERSTATTUNG.
func erstattung(z: Vector2i) -> int:
	var war: int = karte.inhalt(z)
	if war == Karte.FREI:
		return 0
	var paar: bool = karte.paar.has(z)
	var haupt: Vector2i = z                  # Batterie: gebaut wird auf dem Batteriefeld ...
	var stufenfeld: Vector2i = z             # ... ausgebaut an der Pilotenfabrik
	if paar:
		var partner: Vector2i = karte.paar[z]
		haupt = partner if fabriken.has(z) else z
		stufenfeld = z if fabriken.has(z) else partner
	var frisch_bau: Dictionary = _bezahlt.get(haupt, {})
	var frisch_stufen: Dictionary = _bezahlt.get(stufenfeld, {})
	var voll := int(frisch_bau.get("bau", 0)) + int(frisch_bau.get("ausbau", 0)) + int(frisch_bau.get("panzer", 0)) + int(frisch_stufen.get("stufen", 0))
	var alt := 0
	if not frisch_bau.has("bau"):
		if paar:
			alt += batterie_preis(maxi(0, _batterien() - 1))   # der Preis der zuletzt gebauten Batterie
		elif (war == Karte.WALL or war == Karte.FABRIK) and _gratis.has(z):
			pass   # aus dem Startpaket bzw. einem Auftrag: gratis gebaut, gibt nichts zurück
		elif war == Karte.FABRIK:
			# der Preis, den die zuletzt gebaute Fabrik gekostet hat
			alt += int(roundf(Werte.kosten_fabrik() * pow(1.0 + fabrik_prozent() / 100.0, maxi(0, _normale_fabriken() - 1)) / 5.0)) * 5
		else:
			alt += kosten_bei(z, war)   # 18.11.: auf der Ruine zählt der billigere Preis
	var ausbau: int = karte.ausbau.get(z, Karte.FREI)
	if ausbau != Karte.FREI and not frisch_bau.has("ausbau") and not (ausbau == Karte.STELLUNG and _gratis_stellung.has(z)):
		alt += Werte.KOSTEN_PLIPLOP if ausbau == Karte.TURM and karte.turm_art.get(z, "") == "pliplop" else kosten(ausbau)   # 20.11. (Paul): PliPlop
	if karte.panzer.has(z) and not frisch_bau.has("panzer"):
		alt += Werte.KOSTEN_PANZER
	if ausbau == Karte.TURM:
		var tp: Array[int] = Werte.kosten_pliplop_stufen() if karte.turm_art.get(z, "") == "pliplop" else Werte.kosten_turm_stufen()   # 20.11. (Paul)
		for i in maxi(0, int(karte.turm_stufe.get(z, 1)) - 1 - int(frisch_stufen.get("stufen_n", 0))):
			alt += tp[i]
	if ausbau == Karte.STELLUNG:
		for i in maxi(0, int(karte.mg_stufe.get(z, 0)) - int(frisch_stufen.get("stufen_n", 0))):
			alt += Werte.KOSTEN_MG_STUFE[i]   # 20.11. (Paul): MG-Stellung
	if fabriken.has(stufenfeld):
		var preise: Array[int] = Werte.KOSTEN_BATTERIE_STUFE if paar else Werte.kosten_stufen()
		var n_alt := maxi(0, int((fabriken[stufenfeld].get("ring_vorher", fabriken[stufenfeld]) as Dictionary).get("stufe", 0)) - int(frisch_stufen.get("stufen_n", 0)))   # 18.11.: Brakk-Ring – nur die bezahlte Stufe
		for i in n_alt:
			alt += preise[i]
		if not paar and Werte.fabrik_direkt_stufe_2() and n_alt >= 2:
			alt += Werte.preis_direkt_stufe_2() - preise[0] - preise[1]   # 20.11. (Paul): Sonde 7 – Stufe 1 und 2 in einem Kauf
	return voll + roundi(alt * Werte.erstattung())   # 19.11.: Anteil je Anführer


## Abreißen in der Bauphase (Wall samt Ausbau). Erstattung siehe erstattung().
func reisse_ab(z: Vector2i) -> bool:
	if phantom_modus == "angriff" or phase != Phase.BAU or karte.inhalt(z) == Karte.FREI or karte.fest.has(z):
		return false
	var zurueck := erstattung(z)
	Auftraege.zaehle(auftrag, "abriss:" + ("turm" if karte.ausbau.get(z, Karte.FREI) == Karte.TURM else str(BAU_NAMEN.get(karte.inhalt(z), ""))))   # 20.11.
	_notiere({"a": "abriss", "x": z.x, "y": z.y})
	_schliesse_fabrikmenue()
	_abriss_merk = Karte.KEINE
	if karte.paar.has(z):
		var partner: Vector2i = karte.paar[z]
		fabriken.erase(z)
		fabriken.erase(partner)
		_bezahlt.erase(partner)
		karte.entferne(partner)
	if karte.generator_paar.has(z):
		var teil: Vector2i = karte.generator_paar[z]
		if teil != z:
			_bezahlt.erase(teil)
			karte.entferne(teil)
	fabriken.erase(z)
	_bezahlt.erase(z)
	_gratis.erase(z)
	karte.entferne(z)
	budget += zurueck
	return true


## 22.11.: Brakk-Mode – warum Abbauen / Zurücknehmen gerade nicht geht ("" = es geht).
func brakk_abbau_grund() -> String:
	if order24 != null:
		return "In Befehl 24 gehören die Bauten dem Feind."
	if phantom_modus == "angriff":
		return "Der Bau gehört dem Phantom."
	if phase != Phase.BAU:
		return "Abbauen nur in der Bauphase."
	return ""


func abbau_name(z: Vector2i) -> String:
	var war: int = karte.inhalt(z)
	if karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
		return "Turm"
	return "Schildgenerator" if war == Karte.GENERATOR else ("Batterie" if karte.paar.has(z) else ("Fabrik" if war == Karte.FABRIK else "Erdwall"))


## 22.11.: Brakk-Mode – Bauwerk abbauen (Menü-Knopf nach Rückfrage, [Entf] gehalten). Erstattung und Regeln wie im
## Normalspiel (reisse_ab / erstattung): in derselben Bauphase voll, sonst nach Anführer.
func brakk_abbauen(z: Vector2i) -> bool:
	var grund := brakk_abbau_grund()
	if grund != "":
		melde(grund, 2.0)
		return false
	if karte.inhalt(z) == Karte.FREI or karte.fest.has(z):
		return false
	var name := abbau_name(z)
	var zurueck := erstattung(z)
	if not reisse_ab(z):
		return false
	melde("Abgebaut: %s (+%d)" % [name, zurueck], 2.5, "geld")
	return true


## 22.11.: Brakk-Mode – [Z] nimmt das zuletzt gesetzte Bauwerk dieser Bauphase zurück (volle Erstattung).
func nimm_bau_zurueck() -> bool:
	var grund := brakk_abbau_grund()
	if grund != "":
		melde(grund.replace("Abbauen", "Zurücknehmen"), 2.0)
		return false
	while not _bau_stapel.is_empty():
		var e: Dictionary = _bau_stapel.pop_back()
		var z: Vector2i = e["z"]
		var typ := int(e["typ"])
		if typ == Karte.PANZER:
			if not karte.panzer.has(z):
				continue   # schon anders weg
			var b := int((_bezahlt.get(z, {}) as Dictionary).get("panzer", 0))
			karte.panzer.erase(z)
			if _bezahlt.has(z):
				(_bezahlt[z] as Dictionary).erase("panzer")
			budget += b
			karte.queue_redraw()
			melde("Zurückgenommen: Panzerung (+%d)" % b, 2.5, "geld")
			return true
		if karte.inhalt(z) != typ:
			continue   # inzwischen abgerissen oder zerstört
		var name := abbau_name(z)
		var zurueck := erstattung(z)
		if _gratis.has(z):
			if typ == Karte.WALL:
				freie_waelle += 1   # der Gratis-Wall wird wieder frei
			elif typ == Karte.FABRIK:
				gratis_fabriken += 1
		if reisse_ab(z):
			melde("Zurückgenommen: %s (+%d)" % [name, zurueck], 2.5, "geld")
			return true
	melde("Nichts zum Zurücknehmen in dieser Bauphase.", 2.0)
	return false


## Rechtsklick auf ein Bauwerk: Erdwälle (auch mit Stellung oder Tor) fallen sofort. Fabrik, Batterie und Turm
## brauchen einen zweiten Rechtsklick – der erste sagt nur, was es zurückgäbe.
func _rechtsklick_abriss(z: Vector2i) -> bool:
	if phantom_modus == "angriff" or phase != Phase.BAU or karte.inhalt(z) == Karte.FREI:
		return false
	if karte.fest.has(z):
		melde("Diese Mauer gehört zur Karte – abreißen geht nicht, ausbauen schon.", 3.0)
		return false
	var war: int = karte.inhalt(z)
	var teuer: bool = war == Karte.FABRIK or war == Karte.BATTERIE or war == Karte.GENERATOR or karte.ausbau.get(z, Karte.FREI) == Karte.TURM
	if teuer and (_abriss_merk != z or Time.get_ticks_msec() - _abriss_ms > ABRISS_FRIST_MS):
		_abriss_merk = z
		_abriss_ms = Time.get_ticks_msec()
		var name := "Turm" if war == Karte.WALL else ("Schildgenerator" if war == Karte.GENERATOR else ("Batterie" if karte.paar.has(z) else "Fabrik"))
		melde("%s abreißen? Nochmal rechts klicken (+%d Budget zurück)." % [name, erstattung(z)], ABRISS_FRIST_MS / 1000.0)
		return true
	return reisse_ab(z)


## Klick ohne Bauwerkzeug: Einheit, Turm oder Batterie auswählen und ihre Reichweite zeigen.
## Ein Klick ins Leere hebt die Auswahl auf. Gibt true zurück, wenn etwas ausgewählt wurde.
func _waehle_aus(maus: Vector2, z: Vector2i) -> bool:
	if is_instance_valid(_auswahl):
		_auswahl.ausgewaehlt = false
		_auswahl.queue_redraw()
	_auswahl = null
	karte.auswahl = Karte.KEINE
	if Werte.mg_stellung() and karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG and phase != Phase.ENDE and phantom_modus != "angriff":
		karte.auswahl = z   # 20.11. (Paul): MG-Stellung – Klick öffnet den Ausbau des Nests (Reichweite wie bei einem Turm)
		_oeffne_fabrikmenue(z)
		return true
	var beste := 34.0
	for e in einheiten:
		var d := maus.distance_to(e.position + Vector2(0, -8))
		if d < beste and not e.in_batterie() and nebel.offen(karte.zelle_bei(e.position), false):
			beste = d
			_auswahl = e
	if _auswahl != null:
		_auswahl.ausgewaehlt = true
		var d: Dictionary = _auswahl.daten
		if _auswahl == kommandant:
			melde("Brakk gesteuert: [WASD] bewegen · [Q] Sammeln/Losschlagen · [E] Klettern · [R] Klonmaschine. [Esc] oder Klick ins Leere: er handelt wieder selbst.", 5.0)
		elif d.has("info"):
			melde(d["info"], 4.0)
		else:
			melde("%s: Reichweite %s%s, Schaden %s alle %s s." % [d["name"], d["reichweite"], " (+%s in der Stellung)" % Werte.stellung_bonus(d), d["schaden"], d["abklingzeit"]], 4.0)
		return true
	if karte.ausbau.has(z) or karte.inhalt(z) == Karte.BATTERIE:
		karte.auswahl = z
		if karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG:
			melde("Stellung: innerer Kreis = Technogunner, äußerer = Scharfschütze. Rot = von hier nicht zu treffen.", 5.0)
		return true
	return false


## Rot schraffierte Felder: was die angeklickte Truppe, der Turm oder die Stellung in Reichweite nicht treffen kann.
func _aktualisiere_sichtanzeige() -> void:
	if is_instance_valid(_auswahl) and not _auswahl.in_batterie() and _auswahl.reichweite_jetzt() > 0.5:
		var wall := _auswahl.posten_zelle if _auswahl.in_stellung() else Karte.KEINE
		karte.zeige_sicht(true, _auswahl.position, wall, _auswahl.reichweite_jetzt())
		return
	var z := karte.auswahl
	var art: int = karte.ausbau.get(z, Karte.FREI)
	if art == Karte.TURM:
		karte.zeige_sicht(true, karte.mitte(z) + Vector2(0, -14), z, float(karte.turm_wert(z, "reichweite")))
	elif art == Karte.STELLUNG:
		var scharf: Dictionary = Werte.EINHEITEN["scharfschuetze"]
		karte.zeige_sicht(true, karte.mitte(z) + Vector2(0, -12), z, scharf["reichweite"] + karte.posten_bonus(z, scharf))
	else:
		karte.zeige_sicht(false)


## Nächste Einheit aus der Liste (für alte Aufzeichnungen und Werkzeuge; im Spiel wählt man im Fabrikmenü).
func wechsle_einheit(z: Vector2i) -> void:
	if not fabriken.has(z):
		return
	var liste := Werte.FABRIK_EINHEITEN
	stelle_um(z, liste[(liste.find(fabriken[z]["typ"]) + 1) % liste.size()])


## Eine Grundfabrik auf eine andere Truppe umstellen. Spezialisierte Fabriken und Pilotenfabriken bleiben, wie sie sind.
func stelle_um(z: Vector2i, neu: String) -> void:
	if phase == Phase.ENDE or not fabriken.has(z) or karte.paar.has(z):
		return
	if int(fabriken[z].get("stufe", 0)) >= 1:
		melde("Diese Fabrik ist spezialisiert und bleibt bei ihrer Truppe.", 3.0)
		return
	if fabriken[z]["typ"] == neu or not Werte.FABRIK_EINHEITEN.has(neu):
		return
	fabriken[z]["typ"] = neu
	karte.fabrik_typ[z] = neu
	var eintrag := {"a": "einheit", "typ": neu, "x": z.x, "y": z.y}
	if phase == Phase.KAMPF:
		eintrag["t"] = snappedf(_kampf_sek, 0.1)
	_notiere(eintrag)
	var d: Dictionary = Werte.EINHEITEN[neu]
	if phase == Phase.KAMPF:
		melde("Umgestellt auf %s. Gilt für die nächste Einheit, die diese Fabrik baut." % d["name"], 4.0)
		return
	if d.has("info"):
		melde("Diese Fabrik bildet jetzt aus: " + d["info"], 5.0)
	else:
		var stoss: int = (d.get("schuss_bilder", [0]) as Array).size()
		melde("Diese Fabrik baut jetzt: %s (Reichweite %s, Schaden %s%s alle %s s)." % [d["name"], d["reichweite"], ("%d × " % stoss) if stoss > 1 else "", d["schaden"], d["abklingzeit"]], 4.0)


## Nächste Ausbaustufe einer Fabrik kaufen (nur in der Bauphase). Für Stufe 3 gehört die gewählte Fähigkeit dazu.
## Gibt true zurück, wenn es geklappt hat.
func werte_auf(z: Vector2i, faehigkeit: String = "") -> bool:
	if ausbau_moeglich() and karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
		return werte_turm_auf(z, faehigkeit)
	if karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG and Werte.mg_stellung():
		return werte_mg_auf(z, faehigkeit)   # 20.11. (Paul): MG-Stellung (Sonde 7)
	if not ausbau_moeglich() or not fabriken.has(z):
		return false
	if karte.paar.has(z):
		return _werte_batterie_auf(z)
	var stufe := int(fabriken[z].get("stufe", 0))
	var preise: Array[int] = Werte.kosten_stufen()   # 19.11.: Preise je Anführer
	if stufe >= preise.size():
		return false
	if brakk_modus:
		return false   # 18.11. (Paul): Brakk-Mode – keine Fabrik-Ausbauten, alles über Brakks Ringe
	if stufe == 2 and not (Werte.STUFE_3[fabriken[z]["typ"]] as Dictionary).has(faehigkeit):
		return false
	# 20.11. (Paul): Sonde 7 – die Spezialisierung entfällt, der erste Ausbau führt gleich auf Stufe 2 (etwas teurer)
	var direkt := stufe == 0 and Werte.fabrik_direkt_stufe_2()
	var preis: int = Werte.preis_direkt_stufe_2() if direkt else preise[stufe]
	if budget < preis:
		melde("Nicht genug Budget.")
		return false
	_merke_bezahlt(z, "stufen", preis)
	if direkt:
		_bezahlt[z]["stufen_n"] = int(_bezahlt[z].get("stufen_n", 0)) + 1   # zählt als zwei Stufen
	budget -= preis
	var neu_stufe := 2 if direkt else stufe + 1
	fabriken[z]["stufe"] = neu_stufe
	karte.fabrik_stufe[z] = neu_stufe
	var eintrag := {"a": "upgrade", "x": z.x, "y": z.y, "stufe": neu_stufe}
	Auftraege.zaehle(auftrag, "upgrade")   # 20.11.
	var d: Dictionary = Werte.EINHEITEN[fabriken[z]["typ"]]
	if stufe == 2:
		fabriken[z]["faehigkeit"] = faehigkeit
		eintrag["faehigkeit"] = faehigkeit
		_notiere(eintrag)
		var f3: Dictionary = Werte.STUFE_3[fabriken[z]["typ"]][faehigkeit]
		melde("%s Stufe 3 – %s: %s" % [d["name"], f3["name"], f3["text"]], 6.0)
		return true
	_notiere(eintrag)
	if stufe == 3:
		melde("%s Stufe 4 – Elite: %s." % [d["name"], Werte.elite_text()], 5.0)   # 20.11.; Nachtrag: Text aus den Werten
	elif direkt:
		melde("%s gleich auf Stufe 2: %s." % [d["name"], Werte.STUFE_2[fabriken[z]["typ"]]["text"]], 5.0)   # 20.11. (Paul): Sonde 7
	elif stufe == 0:
		melde("Spezialisiert auf %s: hält jetzt drei Truppen und bleibt bei dieser Truppe." % d["name"], 4.0)
	else:
		melde("%s Stufe 2: %s." % [d["name"], Werte.STUFE_2[fabriken[z]["typ"]]["text"]], 5.0)
	return true


## Turm aufwerten: Stufe 2 fest, Stufe 3 mit einer Fähigkeit aus Werte.TURM_STUFE_3.
func werte_turm_auf(z: Vector2i, faehigkeit: String = "") -> bool:
	if karte.turm_art.get(z, "") == "pliplop":
		return _werte_pliplop_auf(z, faehigkeit)   # 20.11. (Paul): PliPlop 3cK
	var stufe := int(karte.turm_stufe.get(z, 1))
	if stufe >= Werte.turm_max_stufe():   # 19.11.: höchste Turmstufe je Anführer (Brakk: 3)
		return false
	var art: String = karte.turm_art.get(z, "geschuetz")
	if stufe == 2 and not (Werte.TURM_STUFE_3[art] as Dictionary).has(faehigkeit):
		return false
	var preis: int = Werte.kosten_turm_stufen()[stufe - 1]
	if budget < preis:
		melde("Nicht genug Budget.")
		return false
	_merke_bezahlt(z, "stufen", preis)
	budget -= preis
	karte.turm_stufe[z] = stufe + 1
	var eintrag := {"a": "upgrade", "x": z.x, "y": z.y, "stufe": stufe + 1}
	Auftraege.zaehle(auftrag, "upgrade")   # 20.11.
	var name: String = Werte.TURMARTEN[art]["name"]
	if stufe == 2:
		karte.turm_faehigkeit[z] = faehigkeit
		eintrag["faehigkeit"] = faehigkeit
		var f3: Dictionary = Werte.TURM_STUFE_3[art][faehigkeit]
		melde("%s Stufe 3 – %s: %s" % [name, f3["name"], f3["text"]], 6.0)
	elif stufe == 3:
		melde("%s Stufe 4: %s, hält doppelt so viel aus." % [name, Werte.turm4_text()], 5.0)   # 20.11.; Nachtrag: Text aus den Werten
	else:
		melde("%s Stufe 2: %s" % [name, Werte.TURM_STUFE_2[art]["text"]], 5.0)
	_notiere(eintrag)
	karte.queue_redraw()
	_pruefe_baumeister()   # 19.11.
	return true


## Batterie ausbauen: gekauft wird an ihrer Pilotenfabrik `pz`, die Stufen sind fest (Reservepilot, Schwere Ladung, Energieschild).
func _werte_batterie_auf(pz: Vector2i) -> bool:
	var stufe := int(fabriken[pz].get("stufe", 0))
	if stufe >= Werte.BATTERIE_STUFEN.size():
		return false
	if budget < Werte.KOSTEN_BATTERIE_STUFE[stufe]:
		melde("Nicht genug Budget.")
		return false
	_merke_bezahlt(pz, "stufen", Werte.KOSTEN_BATTERIE_STUFE[stufe])
	budget -= Werte.KOSTEN_BATTERIE_STUFE[stufe]
	fabriken[pz]["stufe"] = stufe + 1
	karte.fabrik_stufe[pz] = stufe + 1
	karte.fabrik_stufe[karte.paar[pz]] = stufe + 1
	_notiere({"a": "upgrade", "x": pz.x, "y": pz.y, "stufe": stufe + 1})
	var s: Dictionary = Werte.BATTERIE_STUFEN[stufe]
	melde("Batterie Stufe %d – %s: %s" % [stufe + 1, s["name"], s["text"]], 6.0)
	if stufe + 1 == 3:
		waehle_schildfeld(pz)
	return true


func batterie_stufe(b: Vector2i) -> int:
	var pz: Vector2i = karte.paar.get(b, Karte.KEINE)
	return int(fabriken[pz].get("stufe", 0)) if fabriken.has(pz) else 0


func batterie_reichweite(b: Vector2i) -> float:
	return (float(Werte.BATTERIE["reichweite"]) + (Werte.BATTERIE_ST2_REICHWEITE if batterie_stufe(b) >= 2 else 0.0)) * Werte.ZELLE


# ------------------------------------------------------------ Energieschild

## Energieschild (16.11. neu): ein Strahl, gerade von einem Erdwall zum nächsten gezogen. Je länger, desto weniger hält er aus.
## Danach ziehen (oder zwei Erdwälle nacheinander anklicken) setzt den Schild der Batterie, zu der die Pilotenfabrik `pz` gehört.
func waehle_schildfeld(pz: Vector2i) -> void:
	if phase != Phase.BAU or not karte.paar.has(pz) or int(fabriken[pz].get("stufe", 0)) < 3:
		return
	_schild_fuer = karte.paar[pz]
	_schild_start = Karte.KEINE
	werkzeug = Karte.FREI
	_schliesse_fabrikmenue()
	melde("Energieschild: Von einem Erdwall gerade zum nächsten ziehen. Je länger, desto schwächer. [Esc] bricht ab.", 6.0)


## Felder zwischen zwei Erdwällen in einer Reihe oder Spalte (ohne die Wälle selbst).
func schild_felder(a: Vector2i, e: Vector2i) -> Array:
	var felder: Array = []
	if a == e or (a.x != e.x and a.y != e.y):
		return felder
	var schritt := Vector2i(signi(e.x - a.x), signi(e.y - a.y))
	var z := a + schritt
	while z != e:
		felder.append(z)
		z += schritt
	return felder


## Prüft einen Schild von `a` nach `e`. Gibt "" zurück, wenn er so stehen darf, sonst den Grund.
func schild_grund(a: Vector2i, e: Vector2i) -> String:
	if not _ist_erdwall(a) or not _ist_erdwall(e):
		return "Der Schild spannt sich von Erdwall zu Erdwall."
	if a.x != e.x and a.y != e.y:
		return "Nur gerade: in einer Reihe oder Spalte."
	var felder := schild_felder(a, e)
	if felder.is_empty():
		return "Zwischen den Erdwällen muss mindestens ein Feld frei sein."
	for z: Vector2i in felder:
		if karte.inhalt(z) == Karte.WALL:
			return "Nur bis zum nächsten Erdwall."
		if karte.inhalt(z) != Karte.FREI or not karte.ist_frei(z):
			return "Dazwischen muss alles frei sein."
		if z.x < Werte.ZONE_SPALTEN:
			return "Nicht in der gegnerischen Zone."
	return ""


func _ist_erdwall(z: Vector2i) -> bool:
	return karte.inhalt(z) == Karte.WALL


## Setzt den Schild der Batterie `b` von Erdwall `a` nach Erdwall `e`. Gibt "" zurück, wenn es geklappt hat, sonst den Grund.
func setze_schild(b: Vector2i, a: Vector2i, e: Vector2i) -> String:
	if batterie_stufe(b) < 3:
		return "Diese Batterie hat keinen Energieschild."
	var grund := schild_grund(a, e)
	if grund != "":
		return grund
	var felder := schild_felder(a, e)
	for anderer: Vector2i in schilde:
		if anderer != b:
			for z: Vector2i in felder:
				if (schilde[anderer]["felder"] as Array).has(z):
					return "Dort steht schon ein Schild."
	_lege_schild(b, a, e)
	_notiere({"a": "schild", "x": a.x, "y": a.y, "x2": e.x, "y2": e.y, "bx": b.x, "by": b.y})
	return ""


func _lege_schild(b: Vector2i, a: Vector2i, e: Vector2i) -> void:
	var felder := schild_felder(a, e)
	var voll := Werte.schild_leben(felder.size())
	schilde[b] = {"a": a, "e": e, "felder": felder, "leben": voll, "max": voll}


func _schild_aktiv(b: Vector2i) -> bool:
	if not schilde.has(b) or karte.inhalt(b) != Karte.BATTERIE:
		return false
	var s: Dictionary = schilde[b]
	return s["leben"] > 0.0 and not karte.ausgefallen.has(b) and _schild_steht(s) \
		and batterie_stufe(b) >= 3 and karte.besatzung_drin(b) >= int(Werte.BATTERIE["plaetze"])


## Stehen beide Erdwälle noch und ist dazwischen alles frei?
func _schild_steht(s: Dictionary) -> bool:
	if not _ist_erdwall(s["a"]) or not _ist_erdwall(s["e"]):
		return false
	for z: Vector2i in s["felder"]:
		if karte.inhalt(z) != Karte.FREI:
			return false
	return true


## Steht ein Gegner an dieser Stelle vor einem aktiven Schild? Gibt die Batterie zurück (oder Karte.KEINE).
func schild_bei(punkt: Vector2) -> Vector2i:
	for b: Vector2i in schilde:
		if _schild_aktiv(b):
			for z: Vector2i in schilde[b]["felder"]:
				if karte.mitte(z).distance_to(punkt) <= Werte.ZELLE * 0.62:
					return b
	return Karte.KEINE


func schade_schild(b: Vector2i, menge: float) -> void:
	if not schilde.has(b):
		return
	objekt_zaehle(b, "abgefangen", minf(menge, maxf(float(schilde[b]["leben"]), 0.0)))
	schilde[b]["leben"] = float(schilde[b]["leben"]) - menge
	if schilde[b]["leben"] <= 0.0:
		melde("Ein Energieschild ist zusammengebrochen – er lädt sich bis zur nächsten Runde wieder auf.", 4.0)


func _pflege_schilde() -> void:
	var liste: Array = []
	for b: Vector2i in schilde.keys():
		if karte.inhalt(b) != Karte.BATTERIE:
			schilde.erase(b)
			continue
		if phase == Phase.BAU:
			schilde[b]["leben"] = schilde[b]["max"]
		var s: Dictionary = schilde[b]
		# In der Bauphase als Vorschau zeigen, in der Welle nur, solange er wirklich steht
		var aktiv := _schild_aktiv(b) if phase == Phase.KAMPF else _schild_steht(s)
		liste.append([karte.mitte(s["a"]), karte.mitte(s["e"]), clampf(float(s["leben"]) / float(s["max"]), 0.0, 1.0), aktiv, float(s["max"])])
	effekte.schilde = liste
	# Vorschau beim Ziehen: vom ersten Erdwall bis zum Feld unter der Maus
	effekte.schild_vorschau = []
	if _schild_fuer != Karte.KEINE:
		var unter := karte.zelle_bei(maus_welt())
		if _schild_start != Karte.KEINE:
			var ok := schild_grund(_schild_start, unter) == ""
			var n := schild_felder(_schild_start, unter).size()
			effekte.schild_vorschau = [karte.mitte(_schild_start), karte.mitte(unter), ok, Werte.schild_leben(n) if ok else 0.0]
		elif _ist_erdwall(unter):
			effekte.schild_vorschau = [karte.mitte(unter), karte.mitte(unter), true, 0.0]


## Darf `typ` gerade während der Welle gebaut werden? Sonst nur Stellungen; in der letzten Runde alles außer Erdwällen.
func darf_in_welle(typ: int) -> bool:
	return typ == Karte.STELLUNG or (endkampf and typ != Karte.WALL)


## Ausbauen (Fabrik-Stufen) geht in der Bauphase – und in der letzten Runde auch während des Gegenangriffs.
func ausbau_moeglich() -> bool:
	return phase == Phase.BAU or (phase == Phase.KAMPF and endkampf)


func waehle(typ: int) -> void:
	if phantom_modus == "angriff":
		return
	if phase == Phase.ENDE or (phase == Phase.KAMPF and not darf_in_welle(typ)):
		return
	if herausforderung_sperrt(typ) != "":   # 18.11.
		melde(herausforderung_sperrt(typ), 4.0)
		return
	if typ != Karte.FABRIK and not alles_frei():
		melde("Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE)
		return
	werkzeug = Karte.FREI if werkzeug == typ and turm_wunsch == "" else typ
	turm_wunsch = ""


## 21.11. (Paul): eigene Kacheln des Irrtürmers – Turm-Werkzeug mit festem Ziel: "pliplop" (Klick auf ein freies Feld
## baut Einzelwall und PliPlop in einem) oder "truppen" (Erdwall mit zwei freien Nachbarwällen).
var turm_wunsch := ""

func waehle_turm(art: String) -> void:
	if phantom_modus == "angriff" or phase == Phase.ENDE or (phase == Phase.KAMPF and not darf_in_welle(Karte.TURM)):
		return
	if herausforderung_sperrt(Karte.TURM) != "":
		melde(herausforderung_sperrt(Karte.TURM), 4.0)
		return
	if not alles_frei():
		melde("Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE)
		return
	if werkzeug == Karte.TURM and turm_wunsch == art:
		werkzeug = Karte.FREI
		turm_wunsch = ""
	else:
		werkzeug = Karte.TURM
		turm_wunsch = art


## Warum der Wunschturm hier nicht geht ("" = geht). `mit_wall`: beim PliPlop auf freiem Feld wird der Erdwall mitgebaut.
func wunsch_hindernis(z: Vector2i) -> String:
	if phantom_modus == "angriff":
		return "Im Angriff baut der Verteidiger."
	if phase != Phase.BAU and not (phase == Phase.KAMPF and endkampf):
		return "Türme baust du zwischen den Wellen."
	if anfuehrer_sperrt(Karte.TURM) != "":
		return anfuehrer_sperrt(Karte.TURM)
	if turm_wunsch == "pliplop":
		if karte.inhalt(z) == Karte.FREI:
			var g := bau_hindernis_ohne_wunsch(z, Karte.WALL)
			if g != "":
				return g
			if karte.wall_nachbarn(z) > 0:
				return "PliPlop steht allein: Hier grenzt schon ein Erdwall an."
			if budget < kosten_bei(z, Karte.WALL) + Werte.KOSTEN_PLIPLOP:
				return "Nicht genug Budget (%d)." % (kosten_bei(z, Karte.WALL) + Werte.KOSTEN_PLIPLOP)
			return ""
		if karte.inhalt(z) != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z):
			return "PliPlop: auf ein freies Feld klicken (der Erdwall kommt mit) oder auf einen einzelnen Erdwall."
		if karte.wall_nachbarn(z) > 0:
			return "PliPlop steht allein: Dieser Erdwall hat Nachbarwälle."
		return "" if budget >= Werte.KOSTEN_PLIPLOP else "Nicht genug Budget (%d)." % Werte.KOSTEN_PLIPLOP
	# Truppenturm
	if karte.inhalt(z) != Karte.WALL:
		return "Truppenturm: auf einen Erdwall mit zwei freien Nachbarwällen setzen."
	if karte.ausbau.has(z):
		return "Dieser Erdwall ist schon ausgebaut."
	if karte.stuetze_von.has(z):
		return "Dieser Erdwall stützt schon einen anderen Turm."
	if karte.freie_stuetzen(z).size() < 2:
		return "Truppenturm braucht zwei freie Nachbarwälle (links/rechts oder über Eck)."
	return "" if budget >= Werte.KOSTEN_TURM else "Nicht genug Budget (%d)." % Werte.KOSTEN_TURM


func _baue_wunschturm(z: Vector2i) -> bool:
	var grund := wunsch_hindernis(z)
	if grund != "":
		melde(grund, 4.0)
		return false
	var wunsch := turm_wunsch
	turm_wunsch = ""   # ab hier der gewöhnliche Bauweg
	if wunsch == "pliplop" and karte.inhalt(z) == Karte.FREI:
		baue(z, Karte.WALL, true)
	karte.turm_wunsch = wunsch if wunsch == "truppen" else ""
	var ok := karte.inhalt(z) == Karte.WALL and baue(z, Karte.TURM)
	karte.turm_wunsch = ""
	turm_wunsch = wunsch
	return ok


func bau_hindernis_ohne_wunsch(z: Vector2i, typ: int) -> String:
	var w := turm_wunsch
	turm_wunsch = ""
	var g := bau_hindernis(z, typ)
	turm_wunsch = w
	return g


func _tempo_umschalten() -> void:
	if brakk_modus:
		melde("Im Brakk-Mode ist das Tempo fest (×%d)." % roundi(Werte.BRAKK_TEMPO), 2.5)   # 18.11.
		return
	_tempo_faktor = _tempo_faktor + 1.0 if _tempo_faktor < 2.5 else 1.0   # ×1 → ×2 → ×3 → ×1
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor


# ----------------------------------------------------------------- Eingabe

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		Werte.setze_vollbild(not Werte.vollbild)   # [F11] Vollbild an/aus (auch im Menü)
		Werte.speichere_einstellungen()
		get_viewport().set_input_as_handled()
		return
	if szenario_editor != null:
		return   # 18.11.: im Szenario-Editor malt der Editor (szenario_editor.gd)
	if _menue != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				waehle(Karte.FABRIK)
			KEY_2:
				waehle(Karte.WALL)
			KEY_3:
				waehle(Karte.STELLUNG)
			KEY_4:
				waehle(Karte.TURM)
			KEY_5:
				waehle(Karte.BATTERIE)
			KEY_6:
				waehle(Karte.TOR)
			KEY_7:
				waehle(Karte.PANZER)
			KEY_8:
				waehle(Karte.KOMMANDANT)
			KEY_9:
				if Werte.pliplop():
					waehle_turm("pliplop")   # 21.11. (Paul): Irrtürmer
			KEY_0:
				if Werte.truppenturm():
					waehle_turm("truppen")
			KEY_Q:
				if kommandant != null:
					_kommandant_meldung(kommandant.taste_q(maus_welt()))
			KEY_E:
				if kommandant != null:
					_kommandant_meldung(kommandant.taste_e(maus_welt()))
			KEY_R:
				if kommandant != null:
					_kommandant_meldung(stelle_klonmaschine(karte.zelle_bei(maus_welt())))
			KEY_G:
				_ego_umschalten()
			KEY_SPACE:
				starte_welle()
			KEY_L:
				if phantom_modus == "angriff" and phase == Phase.BAU and _wurfziel_fuer.is_empty():
					_laufband.visible = not _laufband.visible
			KEY_H:
				_lexikon.visible = false
				_nachschlag.umschalten()
			KEY_I:
				_nachschlag.visible = false
				_lexikon.umschalten()
			KEY_T:
				_paar_richtung = (_paar_richtung + 1) % PAAR_RICHTUNGEN.size()   # Pilotenfabrik der Batterie drehen
			KEY_ESCAPE:
				# nichts gewählt, nichts offen: Esc öffnet das Pausenmenü (16.11.)
				var war_leer := werkzeug == Karte.FREI and not _lexikon.visible and not _nachschlag.visible \
					and not _fabrikmenue.visible and not kommandant_gewaehlt() and _wurfziel_fuer.is_empty() \
					and not _bestaetigung.visible and _schild_fuer == Karte.KEINE and phase != Phase.ENDE
				if war_leer:
					_hud.pause_an()
					return
				if kommandant_gewaehlt():
					_waehle_aus(Vector2(-9999, -9999), Karte.KEINE)   # Brakk loslassen
				if _nachschlag.visible:
					_nachschlag.umschalten()
				_lexikon.visible = false
				_schliesse_fabrikmenue()
				werkzeug = Karte.FREI
				_schild_fuer = Karte.KEINE
				_schild_start = Karte.KEINE
				_bestaetigung.visible = false
				if not _wurfziel_fuer.is_empty():
					_beende_wurfziel()
			KEY_P:
				if OS.has_feature("web"):
					_hud.pause_an()   # 21.11.: Web – Esc gehört dem Browser (Vollbild, Mausfang), [P] öffnet das Pausenmenü
			KEY_F:
				_tempo_umschalten()
			KEY_B:
				_hud.klappe()   # Bauleiste ein-/ausklappen
		return

	var z := karte.zelle_bei(maus_welt())
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_wall_letzte = Karte.KEINE
	if _setze_basis:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if setze_basis(z):
					_setze_basis = false
					basis_art = "klick"
					melde("Basis versetzt.", 3.0)
				else:
					melde("Dort geht es nicht: Das Feld muss frei sein und außerhalb der Zone liegen.", 4.0)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_setze_basis = false
		return
	if not _wurfziel_fuer.is_empty():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_setze_wurfziel(z)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_beende_wurfziel()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _schild_fuer != Karte.KEINE:
				_schild_klick(z)
			elif werkzeug != Karte.FREI:
				baue(z, werkzeug)
				_wall_letzte = z if werkzeug == Karte.WALL else Karte.KEINE
			elif not _waehle_aus(maus_welt(), z):
				if hd != null and not (fabriken.has(z) or karte.inhalt(z) == Karte.BATTERIE or karte.inhalt(z) == Karte.GENERATOR):
					var hinter := hd.bau_unter_maus()   # Fabrik hinter einer Mauer: ihr Bild zählt
					if hinter != Karte.KEINE:
						z = hinter
				if (fabriken.has(z) or karte.inhalt(z) == Karte.BATTERIE or karte.inhalt(z) == Karte.GENERATOR) and phase != Phase.ENDE:
					_oeffne_fabrikmenue(z)
					if fabriken.has(z) and str(fabriken[z]["typ"]) != "pilot" and phantom_modus != "angriff":
						_zieh_von = z   # Maustaste gedrückt halten und auf eine Stellung ziehen = zuweisen
				else:
					_schliesse_fabrikmenue()
			elif (karte.inhalt(z) == Karte.BATTERIE or karte.ausbau.get(z, Karte.FREI) == Karte.TURM or karte.inhalt(z) == Karte.GENERATOR \
					or (Werte.mg_stellung() and karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG)) and phase != Phase.ENDE:   # 21.11. (Paul): auch die MG-Stellung – ihr Fenster ging sonst sofort wieder zu
				_oeffne_fabrikmenue(z)   # Batterie, Turm oder Generator angeklickt: Reichweite zeigen und Ausbau-Menü öffnen
			else:
				_schliesse_fabrikmenue()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not _rechtsklick_abriss(z):
				werkzeug = Karte.FREI
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _schild_fuer != Karte.KEINE:
		if _schild_start != Karte.KEINE and z != _schild_start:
			_schild_klick(z)   # gezogen und losgelassen
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _zieh_von != Karte.KEINE:
		var von := _zieh_von
		_zieh_von = Karte.KEINE
		karte.zuweis_zug = Vector2.INF
		karte.zuweis_einrast = Karte.KEINE
		if z != von and karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG:
			schalte_zuweisung(von, z)
		if not _fabrikmenue.visible:
			_oeffne_fabrikmenue(von)
	elif event is InputEventMouseMotion:
		if _zieh_von != Karte.KEINE and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			karte.zuweis_zug = maus_welt() if z != _zieh_von else Vector2.INF
			if karte.zuweis_zug != Vector2.INF and _fabrikmenue.visible:
				_fabrikmenue.visible = false   # 16.11.: beim Pfeilziehen die Tafel ausblenden, beim Loslassen kommt sie wieder
			karte.zuweis_einrast = z if karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG else Karte.KEINE   # über einer Stellung rastet der Pfeil ein
			karte.queue_redraw()
		# Mit gedrückter Maustaste Wälle "malen" bzw. wieder wegwischen
		if werkzeug == Karte.WALL and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_ziehe_waelle(karte.zelle_bei(maus_welt(true)))
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT and karte.inhalt(z) == Karte.WALL and karte.ausbau.get(z, Karte.FREI) != Karte.TURM:
			reisse_ab(z)   # Wegwischen trifft keine Türme: die brauchen den bewussten Doppelklick


## Energieschild ziehen: erster Klick (oder Drücken) wählt den Start-Erdwall, Loslassen oder zweiter Klick das Ende.
func _schild_klick(z: Vector2i) -> void:
	if _schild_start == Karte.KEINE or z == _schild_start:
		if _ist_erdwall(z):
			_schild_start = z
		else:
			melde("Der Schild beginnt an einem Erdwall.")
		return
	var grund := setze_schild(_schild_fuer, _schild_start, z)
	if grund == "":
		var leben: float = schilde[_schild_fuer]["max"]
		_schild_fuer = Karte.KEINE
		_schild_start = Karte.KEINE
		melde("Energieschild gespannt: hält %d Schaden aus." % roundi(leben), 4.0)
	else:
		melde(grund)
		_schild_start = z if _ist_erdwall(z) else Karte.KEINE


## Wall-Ziehen: alle Felder vom letzten bis zum aktuellen Feld bauen, damit schnelle Mausbewegungen keine Lücken lassen.
## Vierfach verbunden (erst die längere Achse), schräge Züge ergeben so eine geschlossene Treppe.
func _ziehe_waelle(ziel: Vector2i) -> void:
	if _wall_letzte == Karte.KEINE:
		_wall_letzte = ziel
		baue(ziel, Karte.WALL, true)
		return
	var z := _wall_letzte
	var schritte := 0
	while z != ziel and schritte < 64:
		var d := ziel - z
		if absi(d.x) >= absi(d.y):
			z.x += signi(d.x)
		else:
			z.y += signi(d.y)
		baue(z, Karte.WALL, true)
		schritte += 1
	_wall_letzte = ziel


func _oeffne_fabrikmenue(z: Vector2i) -> void:
	# 22.11. (Paul): Brakk-Mode – das Menü einer Fabrik öffnet wieder: Ausbauten gibt es dort nicht (Ringe laufen über
	# Brakk), aber den Knopf „Abbauen“ (fabrikmenue.gd)
	if phantom_modus == "angriff":
		return   # der Bau gehört dem Phantom
	if karte.paar.has(z) and not fabriken.has(z):
		z = karte.paar[z]   # Klick auf die Batterie: ihr Menü hängt an der Pilotenfabrik
	_fabrikmenue.oeffne(z)


func _schliesse_fabrikmenue() -> void:
	if _fabrikmenue != null:
		_fabrikmenue.schliesse()


func _aktualisiere_vorschau() -> void:
	karte.vorschau_richtung = PAAR_RICHTUNGEN[_paar_richtung]
	if phase != Phase.ENDE and werkzeug != Karte.FREI:
		# 18.11.: Leistung – das Feld unter der Maus nur suchen, wenn eine Vorschau gezeigt wird (in der Ego-Sicht ist das
		# ein Sichtstrahl, ~0,2 ms). vorschau_partner wird nur zur Vorschau von Batterie und Generator gelesen.
		var z := karte.zelle_bei(maus_welt())
		karte.vorschau_partner = partner_feld(z) if werkzeug == Karte.BATTERIE else Karte.KEINE
		karte.setze_vorschau(z, bautyp(z, werkzeug), bau_hindernis(z, werkzeug) == "")
	else:
		karte.vorschau_partner = Karte.KEINE
		karte.setze_vorschau(Karte.KEINE, Karte.FREI, false)


# ------------------------------------------------------------------ Anzeige

## 18.11.: `art` färbt die Meldung im HUD ("geld" gold, "ereignis" kupfern); ohne Angabe aus dem Text erraten.
func melde(text: String, dauer: float = 2.5, art: String = "?") -> void:
	_meldung = text
	_meldung_zeit = dauer
	if art == "?":
		art = "geld" if ("Budget" in text or "Zinsen" in text) and not text.begins_with("Nicht genug") else ("ereignis" if text.ends_with("!") or "!" in text.left(40) else "")
	_meldung_art = art


func _noch_offen() -> int:
	var n := _wurf_aktiv.size() + _im_flug
	for typen: Array in _schlange:
		n += typen.size()
	for eintrag: Dictionary in _wurf_schlange:
		n += (eintrag["typen"] as Array).size()
	return n


func _wellen_text(w: Dictionary, mit_wurf: bool = true) -> String:
	var teile: PackedStringArray = []
	for gruppe: Dictionary in w["gruppen"]:
		var g: Dictionary = Werte.GEGNER[gruppe["typ"]]
		teile.append("%d %s" % [gruppe["anzahl"], g["kurz"]])
	var text := " · ".join(teile)
	if not is_equal_approx(w["leben_faktor"], 1.0):
		text += ", Leben ×%.1f" % w["leben_faktor"]
	# Halbe Ankündigung: WAS die Wurf-Schleuder wirft, aber nicht wie viel und nicht wohin
	var wurf_typen: PackedStringArray = []
	for trupp: Array in w.get("wurf", []):
		for typ: String in trupp:
			var kurz: String = Werte.GEGNER[typ]["kurz"]
			if typ != "hund" and not wurf_typen.has(kurz):
				wurf_typen.append(kurz)
	if mit_wurf and not (w.get("wurf", []) as Array).is_empty():
		text += "  |  Wurf: " + (", ".join(wurf_typen) if not wurf_typen.is_empty() else "Hunde")
	return text


func _aktualisiere_hud(delta: float) -> void:
	if sandbox:
		budget = 999999   # Sandbox: unendlich Budget
	# Meldungen laufen in Echtzeit ab, nicht schneller bei Tempo ×2.
	_meldung_zeit -= delta / maxf(Engine.time_scale, 0.01)
	_aktualisiere_weganzeige(delta)
	_hud.aktualisiere(delta)


## Text für die Tafel über der Konsole (neue Oberfläche, 16.11.): Meldung, Warnung oder Erklärung zum Werkzeug
## (Kachel unter der Maus, sonst das gewählte). Allgemeine Tipps ohne Anlass gibt es nicht mehr – das macht das Tutorial.
## Rückgabe: [Text, ist Warnung]
func hinweis_text(unter_maus: int = Karte.FREI) -> Array:
	if _schild_fuer != Karte.KEINE and _schild_start != Karte.KEINE:
		var unter := karte.zelle_bei(maus_welt())
		var grund := schild_grund(_schild_start, unter)
		if unter != _schild_start:
			if grund != "":
				return [grund, true]
			var n := schild_felder(_schild_start, unter).size()
			return ["Energieschild: %d %s · hält %d Schaden aus" % [n, "Feld" if n == 1 else "Felder", roundi(Werte.schild_leben(n))], false]
	if _meldung_zeit > 0.0:
		return [_meldung, false]
	if phase == Phase.KAMPF and not endkampf:
		return [_werkzeug_tipp(unter_maus), false]
	if phantom_modus == "angriff":
		if _laufband.visible or not _wurfziel_fuer.is_empty():
			return ["", false]
		return ["[L] zeigt den Taktikplaner. Leertaste startet deinen Angriff.", false]
	if endkampf and karte.angriffs_pfad.is_empty():
		return ["Kein Fußweg zum HQ! Reiße Erdwälle ab (Rechtsklick), sonst kommen deine Truppen nicht durch.", true]
	if (werkzeug == Karte.WALL or werkzeug == Karte.FABRIK) and not karte.vorschau_pfad.is_empty() and karte.weg_bricht_durch(karte.vorschau_pfad, karte.vorschau_zelle):
		return ["Kein Weg mehr frei: Die Gegner reißen das rot markierte Feld ein.", true]
	if karte.weg_bricht_durch(karte.pfad) and order24 == null:   # 20.11.: Befehl 24 hat keinen Gegnerweg
		return ["Achtung: Der Weg führt durch ein Gebäude (rot). Die Gegner reißen es ein.", true]
	var typ := unter_maus if unter_maus != Karte.FREI else werkzeug
	if typ != Karte.FREI:
		return [_werkzeug_tipp(typ), false]
	if endkampf:
		return ["Blaue Linie = Fußweg deiner Truppen zum HQ. Nur Truppen ohne Stellung greifen an.", false]
	return ["", false]


func _werkzeug_tipp(typ: int) -> String:
	match typ:
		Karte.FABRIK:
			return "Baut Truppen, die die nächste freie Stellung besetzen. Anklicken: Truppe wählen, ausbauen, Ziel wählen."
		Karte.WALL:
			if not alles_frei():
				return "Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
			return "Maustaste halten = ziehen, Rechtsklick = abreißen (in dieser Bauphase Gebautes voll zurück, sonst %d %%)." % roundi(Werte.erstattung() * 100.0)
		Karte.STELLUNG:
			if Werte.mg_stellung():
				return "MG-Nest auf einem Erdwall (%d): Eine Truppe aus einer Fabrik bemannt es, das Nest schießt mit eigenen Werten. Klick auf das Nest = Ausbau." % Werte.KOSTEN_MG_STELLUNG   # 21.11. (Paul)
			return "Ausbau eines Erdwalls. Eine Einheit steht oben, schießt weiter und über Wälle hinweg."
		Karte.TURM:
			if turm_wunsch == "pliplop":
				return "PliPlop 3cK (%d + Erdwall): Klick auf ein freies Feld – der einzelne Erdwall kommt mit. Mehrere erlaubt, aber keiner neben einem anderen Wall." % Werte.KOSTEN_PLIPLOP
			if turm_wunsch == "truppen":
				return "Truppenturm (%d): auf einen Erdwall mit zwei freien Nachbarwällen setzen (in einer Mauer oder an einer Ecke)." % Werte.KOSTEN_TURM
			return "Auf einen Erdwall setzen – die Form der Nachbarwälle bestimmt den Turm. Klick auf eine Form oben legt sie als Vorlage an die Maus (grün = Erdwall steht schon)."
		Karte.BATTERIE:
			return "Mit Pilotenfabrik (zwei Felder, [T] dreht): feuert weit und flächig, sobald %d Piloten darin sitzen." % int(Werte.BATTERIE["plaetze"])
		Karte.TOR:
			return "Ausbau eines Erdwalls: Durchgang nur für eigene Truppen."
		Karte.PANZER:
			return "Verstärkt einen Erdwall: Die erste Sprengung trifft nur den Wallpanzer, der Erdwall bleibt stehen. Stoppt auch die Sprengung in die Tiefe."
		Karte.KOMMANDANT:
			if anfuehrer_sperrt(typ) != "":
				return anfuehrer_sperrt(typ)   # 19.11.: „Figur folgt“
			return "Einmal pro Partie: Klick auf ein freies Feld. Er handelt selbst; anklicken = mit [WASD] steuern, [Q] Sammeln/Losschlagen, [E] Klettern, [R] Klonmaschine."
		Karte.SPIEGEL:
			return "Nur an Wallenden. Bodentruppen schießen über ihn um die Ecke (helle Felder)."
		Karte.MAGNET:
			return "Zieht alle %d s die Gegner in seiner Linie (%d Felder) heran. [T] dreht die Richtung." % [int(Werte.MAGNET["abklingzeit"]), int(Werte.MAGNET["laenge"])]
	return ""


func _baue_hud() -> void:
	# Neue Oberfläche zuerst: Sie liegt auf derselben Ebene wie die Fenster unten und wird vor ihnen gezeichnet,
	# damit Übersicht, Schlussbild und Bestätigung darüber liegen.
	_hud = preload("res://scripts/ui/hud.gd").new()
	_hud.spiel = self
	add_child(_hud)
	_knoepfe = _hud.kacheln        # das Tutorial zeigt auf die Kacheln und den Start-Knopf
	_btn_start = _hud.start
	_btn_tempo = _hud.tempo
	_btn_menue = _hud.menue
	_weg_grund = _hud.weg_grund
	_lbl_weg = _hud.weg_text

	var ebene := CanvasLayer.new()
	add_child(ebene)
	var breite := 1280.0
	var unten_y := 624.0   # Oberkante der Konsole: darüber liegt im Angriff der Taktikplaner

	var liste: Control = preload("res://scripts/schadensliste.gd").new()
	liste.spiel = self
	ebene.add_child(liste)
	_hud.schadensliste = liste
	_fabrikmenue = Fabrikmenue.new()
	_fabrikmenue.spiel = self
	ebene.add_child(_fabrikmenue)
	var leiste: Control = preload("res://scripts/sandboxleiste.gd").new()
	leiste.spiel = self
	ebene.add_child(leiste)
	_sandbox_leiste = leiste
	_laufband = Laufband.new()
	_laufband.spiel = self
	_laufband.position = Vector2(0, unten_y - Laufband.HOEHE)
	_laufband.visible = false
	ebene.add_child(_laufband)
	_nachschlag = Nachschlag.new()
	ebene.add_child(_nachschlag)
	_lexikon = Lexikon.new()
	ebene.add_child(_lexikon)
	_baue_zoomregler(ebene)

	_ende = ColorRect.new()
	(_ende as ColorRect).color = Color(0, 0, 0, 0.75)
	_ende.size = Vector2(breite, 720)
	_ende.visible = false
	ebene.add_child(_ende)
	var text := _label(_ende, Vector2.ZERO, 40, Color("ffe9a8"))
	_ende_text = text
	text.text = "Die Basis ist gefallen."
	_einblendung = Einblendung.new()
	_einblendung.visible = false
	ebene.add_child(_einblendung)
	ebene.move_child(_einblendung, _ende.get_index())   # unter den Endtafeln
	text.size = Vector2(breite, 440)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var reihe := CenterContainer.new()
	reihe.position = Vector2(0, 480)
	reihe.size = Vector2(breite, 80)
	_ende.add_child(reihe)
	_ende_knoepfe = HBoxContainer.new()
	_ende_knoepfe.add_theme_constant_override("separation", 24)
	reihe.add_child(_ende_knoepfe)
	var reihe2 := CenterContainer.new()
	reihe2.position = Vector2(0, 572)
	reihe2.size = Vector2(breite, 50)
	_ende.add_child(reihe2)
	_export_knoepfe = HBoxContainer.new()
	_export_knoepfe.add_theme_constant_override("separation", 16)
	reihe2.add_child(_export_knoepfe)
	_export_hinweis = _label(_ende, Vector2(0, 628), 15, Color("a79fb3"))
	_export_hinweis.size = Vector2(breite, 24)
	_export_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tafel = EndTafel.new()   # 18.11.: Endtafel, unter der Bestätigung zum Angriffsmodus
	ebene.add_child(_tafel)

	# Bestätigung vor dem Wechsel in den Angriffsmodus (18.11.: als Endtafel über der Siegtafel)
	_bestaetigung = EndTafel.new()
	ebene.add_child(_bestaetigung)


func _label(eltern: Control, pos: Vector2, groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	eltern.add_child(l)
	return l


func _knopf(eltern: Control, x: float, breite: float, aktion: Callable, umschalter: bool) -> Button:
	var b := Button.new()
	b.position = Vector2(x, 4)
	b.size = Vector2(breite, 32)
	b.focus_mode = Control.FOCUS_NONE   # sonst löst die Leertaste den zuletzt geklickten Knopf aus
	b.toggle_mode = umschalter
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(aktion)
	eltern.add_child(b)
	return b


# ------------------------------------------------------------------ 20.11. (Paul): MG-Stellung ausbaubar (Sonde 7)
# Das Nest schießt mit seinen eigenen Werten (Werte.MG_NEST, MG_AUSBAU, MG_SONDER); die Truppe darin ist nur Besatzung.

var _mg_schuesse := {}        # Nest -> Schusszähler (Leuchtspur)
var _mg_ladung := {}          # Nest -> Spielzeit des letzten Ladeschusses
var _mg_huelsen: Array = []   # [Position, Restzeit, Nest] – Hülsenregen


func mg_werte(z: Vector2i) -> Dictionary:
	var wahl: Array = karte.mg_wahl.get(z, [])
	return Werte.mg_werte(int(karte.mg_stufe.get(z, 0)), wahl)


func mg_reichweite(z: Vector2i) -> float:
	var w := mg_werte(z)
	return maxf(0.5, float(w["reichweite"]) + (Werte.WACHPOSTEN_BONUS if karte.ist_wachposten(z) else 0.0) + karte.anhoehe_bonus(z) + Werte.mod("truppen_reichweite"))


## Kühlkreislauf: MG-Nester in der Nähe eines Nests mit Kühlkreislauf feuern schneller (Faktor ≥ 1).
func _mg_takt(z: Vector2i) -> float:
	var f := 1.0
	var s: Dictionary = Werte.MG_SONDER["takt+lafette"]["kuehlkreislauf"]
	for n: Vector2i in karte.mg_stufe:
		if n == z or int(karte.mg_stufe[n]) < 3 or karte.ausbau.get(n, Karte.FREI) != Karte.STELLUNG:
			continue
		var w: Array = karte.mg_wahl.get(n, [])
		if w.size() < 3 or str(w[2]) != "kuehlkreislauf" or Vector2(n - z).length() > 1.5:
			continue
		var bonus := float(s["nachbar"]) * (float(s["funk"]) if funk_faktor(n) < 1.0 else 1.0)
		f = maxf(f, 1.0 + bonus)
	return f


## Ein Schuss des MG-Nests auf `z` mit der Truppe `e` als Besatzung. Rückgabe: Pause bis zum nächsten Schuss (0 = kein Schuss).
func mg_feuer(e: Einheit, ziel: Node2D, z: Vector2i) -> float:
	if not is_instance_valid(ziel):
		return 0.0
	var w := mg_werte(z)
	var sonder := str(w["sonder"])
	var s: Dictionary = w["s"]
	var g_ziel: Gegner = ziel as Gegner
	if im_rauch(e.position) and sonder != "ausguck" and not peilung(z) and not (g_ziel != null and g_ziel.markiert > 0.0):
		return 0.0   # im Rauch sieht das Nest nichts – außer mit Ausguck oder Peilsender
	var pause := float(w["abklingzeit"]) / _mg_takt(z) * funk_faktor(z)
	if e.sturm_bis > 0.0:
		pause *= float(Werte.KOMMANDANT["sturm_feuer"])
	var farbe := Color(Werte.MG_NEST["farbe"])
	var von := e.position + Vector2(14 * (-1 if ziel.position.x < e.position.x else 1), -10)
	schadensquelle = "fabrik:%d,%d" % [e.fabrik_zelle.x, e.fabrik_zelle.y]
	schuetze = e
	schuss_herkunft = e.position
	var schaden := float(w["schaden"]) * Werte.mod_faktor("truppen_schaden")
	Ton.am_ort(self, Ton.fuer_truppe(e.daten), e.position)
	if brakk_geschosse != null and brakk_geschosse.ist_brakk(ziel):
		brakk_geschosse.schiesse("laser", von, 0.45, schaden, "technogunner", schadensquelle)
		return pause
	if g_ziel == null:
		schuss(von, ziel.position, farbe)
		ziel.call("nimm_schaden", schaden)
		return pause
	if sonder == "ausguck" and BrakkFortschritt.gross(g_ziel):
		schaden *= float(s["gross"])
	# Railgun-Lauf: durch alle in einer Linie, einmal an einem Erdwall abgeprallt
	if sonder == "railgun":
		_mg_railgun(z, von, g_ziel.position, mg_reichweite(z) * Werte.ZELLE, schaden, farbe, float(s["breite"]) * Werte.ZELLE)
		return pause
	schuss(von, g_ziel.position + Vector2(0, 4), farbe)
	var vorher := g_ziel.leben
	g_ziel.nimm_schaden(schaden)
	objekt_zaehle(z, "schaden", minf(schaden, maxf(0.0, vorher)))
	var ort := g_ziel.position
	var getoetet := g_ziel._tot or g_ziel.leben <= 0.0
	if getoetet:
		objekt_zaehle(z, "kills", 1.0)
	# Streuung: Splitter an alle rund ums Ziel
	var splitter := float(w["splitter"]) * Werte.ZELLE
	if splitter > 0.0:
		for g in gegner.duplicate():
			if not is_instance_valid(g) or g == g_ziel or _geschuetzt(g) or g.position.distance_to(ort) > splitter:
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
			var eigene := _mg_huelsen.filter(func(h: Array) -> bool: return h[2] == z).size()
			if Zufall.f() < float(s["chance"]) and eigene < int(s["hoechst"]):
				var p := ort + Vector2(Zufall.von_bis(-0.25, 0.25), Zufall.von_bis(-0.2, 0.2)) * Werte.ZELLE
				_mg_huelsen.append([p, float(s["sek"]), z])
				effekte.flaeche(p, Werte.ZELLE * 0.18, Color("ffd34d"))
		"leuchtspur":
			var n := int(_mg_schuesse.get(z, 0)) + 1
			_mg_schuesse[z] = n
			if n % int(s["jeder"]) == 0 and not getoetet and is_instance_valid(g_ziel):
				strahl(von, ort, Color(1.0, 0.85, 0.3), 2.0)
				g_ziel.markiert = Werte.MARKIERUNG_SEK
				g_ziel.markier_faktor = Werte.MARKIERUNG_FAKTOR
				g_ziel.markiert_brakk = false
		"splittergurt":
			if getoetet:
				flaechenschaden(ort, float(s["radius"]) * Werte.ZELLE, schaden * float(s["anteil"]), farbe)
		"ladeschuss":
			if spielzeit() - float(_mg_ladung.get(z, -100.0)) >= float(s["sek"]):
				var dicht := _mg_dichteste(e.position, mg_reichweite(z) * Werte.ZELLE, float(s["radius"]) * Werte.ZELLE)
				if dicht != null:
					_mg_ladung[z] = spielzeit()
					var punkt := dicht.position
					effekte.batterie_schuss(von, punkt, float(s["radius"]) * Werte.ZELLE)
					get_tree().create_timer(Effekte.BOLZEN_FLUG, false, true).timeout.connect(
						func() -> void: flaechenschaden(punkt, float(s["radius"]) * Werte.ZELLE, schaden * float(s["mal"]), Color("9be37b")))
	return pause


## Mitte der dichtesten Gegnergruppe in Reichweite (ohne Sichtprüfung: der Mörser geht über die Mauer).
func _mg_dichteste(von: Vector2, weite: float, radius: float) -> Gegner:
	var bestes: Gegner = null
	var meiste := 0
	for g in gegner:
		if _geschuetzt(g) or von.distance_to(g.position) > weite:
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
func _mg_railgun(z: Vector2i, von: Vector2, ziel: Vector2, weite: float, schaden: float, farbe: Color, breite: float) -> void:
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
		strahl(start, ende, farbe, 3.0)
		for g in gegner.duplicate():
			if not is_instance_valid(g) or _geschuetzt(g) or getroffen.has(g):
				continue
			var nah := Geometry2D.get_closest_point_to_segment(g.position, start, ende)
			if nah.distance_to(g.position) <= breite:
				getroffen.append(g)
				var vorher: float = g.leben
				g.nimm_schaden(schaden)
				objekt_zaehle(z, "schaden", minf(schaden, maxf(0.0, vorher)))
				if g._tot:
					objekt_zaehle(z, "kills", 1.0)
		rest -= start.distance_to(ende)
		start = ende
		if not prall or rest <= Werte.ZELLE * 0.3:
			break


## Hülsenregen: wer über liegende Hülsen läuft, rutscht aus (einmal je Hülse).
func _mg_huelsen_wirken(delta: float) -> void:
	if _mg_huelsen.is_empty():
		return
	var s: Dictionary = Werte.MG_SONDER["takt+streuung"]["huelsenregen"]
	var weg: Array = []
	for h: Array in _mg_huelsen:
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
		_mg_huelsen.erase(h)


## Die Hülsen liegen als kleine goldene Punkte am Boden (in der Karte gezeichnet).
func mg_huelsen_punkte() -> Array:
	var aus: Array = []
	for h: Array in _mg_huelsen:
		aus.append(h[0])
	return aus


## MG-Nest ausbauen: Stufe 1 und 2 je eine von zwei Richtungen, Stufe 3 eine Sonderform.
func werte_mg_auf(z: Vector2i, wahl: String) -> bool:
	if not ausbau_moeglich() or not Werte.mg_stellung() or karte.ausbau.get(z, Karte.FREI) != Karte.STELLUNG:
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
	if budget < preis:
		melde("Nicht genug Budget.")
		return false
	_merke_bezahlt(z, "stufen", preis)
	budget -= preis
	var neu: Array = alt.duplicate()
	neu.append(wahl)
	karte.mg_wahl[z] = neu
	karte.mg_stufe[z] = stufe + 1
	# Im Protokoll wie ein Turm-Upgrade: Stufe + 1 und die Wahlen als Kette (so liest es auch Phantom._stand)
	_notiere({"a": "upgrade", "x": z.x, "y": z.y, "stufe": stufe + 2, "faehigkeit": "|".join(PackedStringArray(neu))})
	Auftraege.zaehle(auftrag, "upgrade")
	melde("MG-Stellung Stufe %d – %s: %s" % [stufe + 1, moeglich[wahl]["name"], moeglich[wahl]["text"]], 5.0)
	karte.queue_redraw()
	return true


# ------------------------------------------------------------------ 20.11. (Paul): PliPlop 3cK als Turm (Irrtürmer)

var _pp_nagel := {}   # Turm -> [Gegner, Treffer in Folge] (Nagler)


## Stufe 1 -> 2 wählt den Pfad, Stufe 3 und 4 verstärken ihn.
func _werte_pliplop_auf(z: Vector2i, pfad: String) -> bool:
	var stufe := int(karte.turm_stufe.get(z, 1))
	if stufe >= 4:
		return false
	if stufe == 1 and not Werte.PLIPLOP_TURM.has(pfad):
		return false
	var preis: int = Werte.kosten_pliplop_stufen()[stufe - 1]
	if budget < preis:
		melde("Nicht genug Budget.")
		return false
	_merke_bezahlt(z, "stufen", preis)
	budget -= preis
	karte.turm_stufe[z] = stufe + 1
	var eintrag := {"a": "upgrade", "x": z.x, "y": z.y, "stufe": stufe + 1}
	if stufe == 1:
		karte.turm_faehigkeit[z] = pfad
		eintrag["faehigkeit"] = pfad
	Auftraege.zaehle(auftrag, "upgrade")
	var p: Dictionary = Werte.PLIPLOP_TURM[str(karte.turm_faehigkeit[z])]
	melde("PliPlop 3cK Stufe %d – %s: %s" % [stufe + 1, p["name"], p["stufen"][stufe - 1]["text"]], 5.0)
	_notiere(eintrag)
	karte.queue_redraw()
	return true


func _pliplop_turm(z: Vector2i, delta: float) -> void:
	var rest: float = _turm_abkling.get(z, 0.0) - delta * turm_takt(z)
	if rest > 0.0:
		_turm_abkling[z] = rest
		return
	var pfad := str(karte.turm_faehigkeit.get(z, ""))
	var stufe := int(karte.turm_stufe.get(z, 1))
	var werte: Dictionary = Werte.PLIPLOP_TURM[pfad]["stufen"][clampi(stufe - 2, 0, 2)] if Werte.PLIPLOP_TURM.has(pfad) else {}
	schadensquelle = "turm:pliplop"
	schuetze = null
	schadensobjekt = z
	var weite := float(karte.turm_wert(z, "reichweite")) * Werte.ZELLE
	var von := karte.mitte(z) + Vector2(0, -12)
	schuss_herkunft = von
	var schaden := float(karte.turm_wert(z, "schaden"))
	var farbe := Color(Werte.TURMARTEN["pliplop"]["farbe"])
	var ziel := gegner_in_reichweite(von, weite, false, z)
	if ziel == null:
		_turm_abkling[z] = 0.0
		return
	rest = float(karte.turm_wert(z, "abklingzeit"))
	if turmbilder.has(z):
		(turmbilder[z] as TurmBild).feuert(ziel.position)
	match pfad:
		"flak":
			var radius := float(werte["radius"]) * Werte.ZELLE
			Ton.am_ort(self, "tc-heavy", von)
			schuss(von, ziel.position, farbe)
			flaechenschaden(ziel.position, radius, schaden, Color("ffb070"))
			if werte.has("nachbrand"):
				lege_brand(ziel.position, radius * 0.8, schaden * float(werte["nachbrand"]))
		"schockwelle":
			Ton.am_ort(self, "tc-arc", von)
			effekte.welle(karte.mitte(z), weite, Color("9be37b"), "funk", 0.6)
			for g in gegner.duplicate():
				if not is_instance_valid(g) or _geschuetzt(g) or von.distance_to(g.position) > weite or not karte.sicht_von_wall(z, von, g.position):
					continue
				g.markiert = maxf(g.markiert, float(werte["mark_sek"]))
				g.markier_faktor = Werte.MARKIERUNG_FAKTOR
				g.markiert_brakk = false
				if werte.has("bremse"):
					g.frost_tempo = 0.6 if g.gefroren <= 0.0 else minf(g.frost_tempo, 0.6)
					g.gefroren = maxf(g.gefroren, float(werte["bremse"]))
				if bool(g.daten.get("fernkampf", false)) or BrakkFortschritt.gross(g):
					continue
				_pp_stoss(g, von, float(werte["stoss"]) * Werte.ZELLE)
		"nagler":
			var n := 0
			var alt: Array = _pp_nagel.get(z, [])
			if alt.size() == 2 and alt[0] == ziel:
				n = int(alt[1])
			var bonus := minf(float(werte["hoechst"]), float(werte["je_treffer"]) * n)
			_pp_nagel[z] = [ziel, n + 1]
			Ton.am_ort(self, "tc-heavy", von)
			effekte.leuchtschuss(von, 18.0, ziel.position, 14.0, Color("ff8ad8"), 0.08 + von.distance_to(ziel.position) / 4200.0, 7.0 + 4.0 * bonus)
			ziel.nimm_schaden(schaden * (1.0 + bonus))
		_:
			Ton.am_ort(self, "tc-heavy", von)
			schuss(von, ziel.position, farbe)
			ziel.nimm_schaden(schaden)
	_turm_abkling[z] = rest


## Schockwelle: Gegner vom Turm wegstoßen, höchstens bis vor ein Hindernis.
func _pp_stoss(g: Gegner, von: Vector2, weite: float) -> void:
	var richtung := (g.position - von).normalized()
	if richtung == Vector2.ZERO:
		richtung = Vector2.LEFT
	var ziel := g.position
	var s := 0.0
	while s < weite:
		s = minf(weite, s + 4.0)
		var neu := g.position + richtung * s
		if not karte.ist_begehbar(karte.zelle_bei(neu)):
			break
		ziel = neu
	if ziel != g.position:
		effekte.strahl(g.position, ziel, Color("9be37b"), 2.0)
		g.position = ziel
		g.plane_neu()
