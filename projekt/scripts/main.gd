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
var sandbox_gegner: Dictionary = {} # Sandbox: Typ -> Anzahl in der nächsten Welle (leer = Welle wie im Spiel)
var sandbox_truppen := 0            # Sandbox: so viele Truppen je Fabrik mehr (oder weniger)
var schilde: Dictionary = {}        # Batterie-Zelle -> {"z": Feld des Energieschilds, "leben": Rest}
var _schild_fuer := Karte.KEINE     # diese Batterie wartet auf den Klick für ihr Schildfeld
var _rauch_abkling: Dictionary = {}

var karte: Karte
var effekte: Effekte
var figuren: Node2D
var gegner: Array[Gegner] = []
var einheiten: Array[Einheit] = []
var endkampf := false               # letzte Runde: Gegner ohne Ende, Sieg durch Zerstören des HQ
var zonenbauten: Array[Zonenbau] = []   # HQ und Schleudern in der Zone des Gegners
var hq: Zonenbau
var fabriken: Dictionary = {}       # Zelle -> {"timer": float, "einheiten": Array, "typ": String}

var _welle: Dictionary = {}
var _schlange: Array = []           # Trupps, die in dieser Welle noch kommen (je eine Liste von Gegnertypen)
var _trupp: Array = []              # Mitglieder des Trupps, der gerade herauskommt
var _start_zelle := Werte.START_ZELLE   # Startfeld der laufenden Welle
var _erstes_ziel := 0               # erstes Routenziel der laufenden Welle
var _gefahr: Dictionary = {}        # Felder nahe an Gegnern (Zwischenspeicher für einen Frame)
var _gefahr_stand := -1
var _zins_felder: Array[ColorRect] = []
var _lbl_zins: Label
var _wurf_schlange: Array = []      # Trupps zu vier, die die Wurf-Schleuder in dieser Welle noch wirft
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
var _runde_start_ms := 0
var _leben_vor_runde := 0
var _cp_verloren := 0
var _spielzeit := 0.0                # läuft nur im Kampf (für Feuerteam und Brandfelder)
var _nachschlag: Nachschlag          # Nachschlagekarte mit Formationen [H]
var _fabrikmenue: Fabrikmenue        # Tafel an der angeklickten Fabrik: Truppe wählen, Upgrades kaufen
var _nachspiel := 0.0               # Sekunden, die nach dem letzten Gegner noch für die Rückeroberung liefen
var _kampf_sek := 0.0               # Spielzeit seit Rundenbeginn
var _im_flug := 0                   # geworfene Hunde, die noch in der Luft sind
var _tempo_faktor := 1.0            # 1 oder 2 (Taste F), wird mit Werte.SPIELTEMPO multipliziert
var _spawn_in := 0.0
var _turm_abkling: Dictionary = {}  # Turm-Zelle -> Sekunden bis zum nächsten Schuss
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
var _auswahl: Einheit               # angeklickte Einheit (zeigt ihre Reichweite)
var _ende: Control
var _ende_text: Label


func _ready() -> void:
	karte = Karte.new()
	add_child(karte)
	karte.zerstoert.connect(_bei_zerstoert)
	karte.ausgefallen_ist.connect(_bei_ausfall)
	figuren = Node2D.new()
	figuren.y_sort_enabled = true
	add_child(figuren)
	effekte = Effekte.new()
	add_child(effekte)
	Engine.time_scale = Werte.SPIELTEMPO
	_aktualisiere_zone()
	karte.cp_aktiv = welle >= Werte.CHECKPOINTS_AB_WELLE
	karte.zeige_schwachstelle = welle >= Werte.SPRENGER_AB_WELLE
	karte.aktualisiere_pfad()
	_beginne_protokoll()
	_baue_hud()
	if DisplayServer.get_name() != "headless" and OS.get_environment("TD_OHNE_MENUE") == "":
		_menue = Startmenue.new()
		add_child(_menue)
		_menue.gewaehlt.connect(_menue_gewaehlt)


func _menue_gewaehlt(mit_sandbox: bool) -> void:
	sandbox = mit_sandbox
	if sandbox:
		budget = 999999
		_protokoll["sandbox"] = true
		melde("Sandbox: unendlich Budget, alle Bauwerke freigeschaltet.", 5.0)
	_menue.queue_free()
	_menue = null


# -------------------------------------------------------------- Bauprotokoll

const BAU_NAMEN := {Karte.WALL: "wall", Karte.FABRIK: "fabrik", Karte.STELLUNG: "stellung", Karte.TURM: "turm", Karte.BATTERIE: "batterie", Karte.TOR: "tor"}


func _beginne_protokoll() -> void:
	var cps: Array = []
	for z in karte.checkpoints:
		cps.append([z.x, z.y])
	_protokoll = {"version": 1, "begonnen": Time.get_datetime_string_from_system(), "checkpoints": cps, "runden": []}
	_protokoll_datei = "partie-%s.json" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")


## Eintrag der laufenden Bauphase (wird bei Bedarf angelegt).
func _runden_eintrag() -> Dictionary:
	var runden: Array = _protokoll["runden"]
	if runden.is_empty() or (runden[runden.size() - 1] as Dictionary).has("ergebnis"):
		runden.append({"runde": welle, "budget_vorher": budget, "aktionen": []})
	return runden[runden.size() - 1]


func _notiere(aktion: Dictionary) -> void:
	if protokoll_an and not _protokoll.is_empty():
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
	_speichere_protokoll()


## Im Editor landet die Datei im Projektordner unter partien/, sonst im Benutzerordner des Spiels.
func _speichere_protokoll() -> void:
	var text := JSON.stringify(_protokoll, "\t")
	for ordner: String in ["res://partien", "user://partien"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ordner))
		var datei := FileAccess.open(ordner + "/" + _protokoll_datei, FileAccess.WRITE)
		if datei != null:
			datei.store_string(text)
			datei.close()
			return


## Für das Nachspielen: Checkpoints auf die Felder der aufgezeichneten Partie setzen.
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
		if welle < int(s["ab_welle"]) or _zone_gebaut.has(nr):
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
	if _start_zelle != Werte.START_ZELLE:
		return _start_zelle
	return Vector2i(randi() % Werte.ZONE_SPALTEN, randi() % Werte.ZEILEN)


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	_aktualisiere_vorschau()
	_aktualisiere_sichtanzeige()
	_aktualisiere_hud(delta)
	_pflege_schilde()
	if phase != Phase.KAMPF:
		return

	if endkampf and _schlange.is_empty():
		# letzte Runde: nach kurzer Pause beginnt dieselbe Reihe Trupps von vorn
		_schlange = (_welle["trupps"] as Array).duplicate(true)
		_wurf_schlange.append_array((_welle["wurf"] as Array).duplicate(true))
		_spawn_in = Werte.ENDKAMPF_PAUSE
	if not _schlange.is_empty():
		_spawn_in -= delta
		if _spawn_in <= 0.0:
			var typen: Array = _schlange[0]
			var typ: String = typen.pop_front()
			var g := _neuer_gegner(typ, _spawn_zelle(), _erstes_ziel)
			g.trupp = _trupp
			_trupp.append(g)
			if typen.is_empty():
				# Trupp vollständig: nach einer Pause kommt der nächste
				_schlange.pop_front()
				_trupp = []
				_spawn_in += Werte.ENDKAMPF_TRUPP_PAUSE if endkampf else Werte.TRUPP_PAUSE
			else:
				_spawn_in += _welle["abstand"]
	_wurf_tick(delta)

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
		karte.fortschritt[z] = f["timer"] / Werte.PRODUKTION_SEK
		if f["timer"] >= Werte.PRODUKTION_SEK:
			f["timer"] = 0.0
			var e := Einheit.new()
			figuren.add_child(e)
			e.start(self, karte, f["typ"], z, int(f.get("stufe", 0)), str(f.get("faehigkeit", "")))
			einheiten.append(e)
			(f["einheiten"] as Array).append(e)

	_kampf_sek += delta
	_braende_wirken(delta)
	_tuerme_feuern(delta)
	_batterien_feuern(delta)
	_checkpoints_halten(delta)

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
		_welle_geschafft()


## Gibt es einen vom Gegner gehaltenen Checkpoint, zu dem eine freie Bodentruppe einen Weg hat?
func _truppe_kann_checkpoint_holen() -> bool:
	if not karte.cp_aktiv:
		return false
	for i in karte.checkpoints.size():
		if not karte.cp_feind[i]:
			continue
		for e in einheiten:
			if e.zustand != Einheit.Zustand.BODEN or e.daten.get("pilot", false):
				continue
			var hier := karte.zelle_bei(e.position)
			if hier == karte.checkpoints[i] or not karte.einheiten_weg(hier, karte.checkpoints[i]).is_empty():
				return true
	return false


## Pro verlorenem Checkpoint geht nur eine Truppe zurückholen (die nächste Bodentruppe); die anderen kämpfen weiter.
var _cp_einnehmer: Dictionary = {}   # Checkpoint-Index -> Einheit

func darf_checkpoint_holen(e: Einheit, cp: Vector2i) -> bool:
	var i := karte.checkpoints.find(cp)
	if i < 0:
		return false
	var amt = _cp_einnehmer.get(i)
	if amt != null and is_instance_valid(amt) and einheiten.has(amt) and amt.am_boden():
		return amt == e
	var bester: Einheit = null
	var beste_weite := INF
	for u in einheiten:
		# Auch wer gerade zu einer Stellung unterwegs ist, kommt in Frage: der Checkpoint geht vor.
		if not u.am_boden() or u.daten.get("pilot", false):
			continue
		var hier := karte.zelle_bei(u.position)
		if hier != cp and karte.einheiten_weg(hier, cp).is_empty():
			continue
		var w := u.position.distance_to(karte.mitte(cp))
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
		for e in einheiten:
			if e.zustand == Einheit.Zustand.BODEN and karte.zelle_bei(e.position) == karte.checkpoints[i]:
				besetzt = true
				break
		if not besetzt:
			karte.cp_fortschritt[i] = maxf(0.0, karte.cp_fortschritt[i] - delta)
			continue
		karte.cp_fortschritt[i] += delta
		if karte.cp_fortschritt[i] >= Werte.RUECKEROBERUNG_SEK:
			karte.cp_feind[i] = false
			karte.cp_fortschritt[i] = 0.0
			karte.aktualisiere_pfad()
			melde("Checkpoint %d zurückerobert." % (i + 1), 4.0)


## Die Gegner haben Checkpoint `i` lange genug gehalten.
func checkpoint_erreicht(i: int) -> void:
	if karte.cp_feind[i]:
		return
	karte.cp_feind[i] = true
	_cp_verloren += 1
	karte.cp_fortschritt[i] = 0.0
	karte.cp_einnahme[i] = 0.0
	karte.aktualisiere_pfad()
	melde("Checkpoint %d verloren! Die nächste Welle startet dort." % (i + 1), 4.0)


func _tuerme_feuern(delta: float) -> void:
	var weite: float = Werte.TURM["reichweite"] * Werte.ZELLE
	for z: Vector2i in karte.ausbau:
		if not karte.turm_aktiv(z):
			continue   # kein Turm, lahmgelegt oder ohne Stützen
		var rest: float = _turm_abkling.get(z, 0.0) - delta
		if rest <= 0.0:
			var von := karte.mitte(z) + Vector2(0, -14)
			var ziel := gegner_in_reichweite(von, weite, false, z)   # Türme folgen derselben Sichtregel wie Stellungen
			if ziel != null:
				rest = Werte.TURM["abklingzeit"]
				schuss(von, ziel.position, Color("7fe0ff"))
				ziel.nimm_schaden(Werte.TURM["schaden"])
		_turm_abkling[z] = rest


## Voll bemannte Batterien feuern auf die dichteste Gegnergruppe in Reichweite – über Wälle hinweg.
func _batterien_feuern(delta: float) -> void:
	var radius: float = Werte.BATTERIE["flaeche"] * Werte.ZELLE
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.BATTERIE or karte.ausgefallen.has(z):
			continue
		var stufe := batterie_stufe(z)
		var weite := batterie_reichweite(z)
		if stufe >= 2 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			# Schwere Ladung: nebenbei Rauch in Reichweite wegblasen
			_rauch_abkling[z] = float(_rauch_abkling.get(z, 0.0)) - delta
			if _rauch_abkling[z] <= 0.0:
				var wolke: Variant = effekte.blase_rauch_weg(karte.mitte(z), weite)
				if wolke != null:
					_rauch_abkling[z] = Werte.BATTERIE_RAUCH_SEK
					schuss(karte.mitte(z) + Vector2(0, -20), wolke, Color("d8f6ff"))
		var rest: float = _turm_abkling.get(z, Werte.BATTERIE["abklingzeit"] * 0.5) - delta
		if rest <= 0.0 and karte.besatzung_drin(z) >= int(Werte.BATTERIE["plaetze"]):
			var von := karte.mitte(z) + Vector2(0, -20)
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
			if bestes != null:
				rest = Werte.BATTERIE["abklingzeit"]
				schuss(von, bestes.position, Color("7fe0ff"))
				flaechenschaden(bestes.position, radius, float(Werte.BATTERIE["schaden"]) * (Werte.BATTERIE_ST2_SCHADEN if stufe >= 2 else 1.0), Color("7fe0ff"))
		_turm_abkling[z] = maxf(rest, 0.0) if rest <= 0.0 else rest


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


## Feuerteam: Wie viele andere Feuerteam-Schützen haben in der letzten Sekunde auf dasselbe Ziel geschossen?
func mitschuetzen(wer: Einheit, ziel: Node2D) -> int:
	var n := 0
	for e in einheiten:
		if e != wer and e.faehigkeit == "feuerteam" and e.letztes_ziel == ziel and _spielzeit - e.letzter_schuss <= 1.0:
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
	_braende.append([mitte, radius, Werte.BRANDFELD_SEK, schaden_je_sek])
	effekte.brand(mitte, radius, Werte.BRANDFELD_SEK)


func _braende_wirken(delta: float) -> void:
	_spielzeit += delta
	for b: Array in _braende:
		b[2] -= delta
		for g in gegner.duplicate():
			if not _geschuetzt(g) and (b[0] as Vector2).distance_to(g.position) <= float(b[1]):
				g.nimm_schaden(float(b[3]) * delta)
	_braende = _braende.filter(func(b): return b[2] > 0.0)


## Plasmagel: wenig Schaden, aber alle im Feld werden verlangsamt.
func gelschuss(mitte: Vector2, radius: float, schaden: float) -> void:
	effekte.gel(mitte, radius, Werte.PLASMAGEL_SEK)
	for g in gegner.duplicate():
		if not _geschuetzt(g) and mitte.distance_to(g.position) <= radius:
			g.gebremst = Werte.PLASMAGEL_SEK
			g.nimm_schaden(schaden)


func flaechenschaden(mitte: Vector2, radius: float, schaden: float, farbe: Color) -> void:
	for i in 12:
		var a := Vector2.RIGHT.rotated(TAU * i / 12.0) * radius
		var b := Vector2.RIGHT.rotated(TAU * (i + 1) / 12.0) * radius
		effekte.linie(mitte + a, mitte + b, farbe)
	for g in gegner.duplicate():
		if not _geschuetzt(g) and mitte.distance_to(g.position) <= radius:
			g.nimm_schaden(schaden)


func starte_welle() -> void:
	if phase != Phase.BAU:
		return
	if fabriken.is_empty():
		melde("Erst eine Fabrik bauen [1].")
		return
	_schild_fuer = Karte.KEINE
	phase = Phase.KAMPF
	werkzeug = Karte.FREI
	_runde_start_ms = Time.get_ticks_msec()
	_leben_vor_runde = leben
	_cp_verloren = 0
	_nachspiel = 0.0
	_kampf_sek = 0.0
	_braende.clear()
	karte.zeige_pfad_kraeftig = false
	_welle = naechste_welle()
	_schlange = (_welle["trupps"] as Array).duplicate(true)
	_trupp = []
	_im_flug = 0
	_wurf_schlange = (_welle["wurf"] as Array).duplicate(true)
	_wurf_aktiv = []
	_wurf_sofort = false
	_wurf_meiden = Vector2.INF
	if not _wurf_schlange.is_empty():
		# Wer sich hinter einer dicken Mauer verschanzt, bekommt ein Rudel Hunde zusätzlich über die Mauer geworfen.
		for b in zonenbauten:
			if b.art == "wurf" and karte.wurf_mauer(b.zelle) >= Werte.WURF_MAUER_EXTRA:
				_wurf_schlange.append(["hund", "hund", "hund", "hund"])
				melde("Die Wurf-Schleuder nimmt eure Mauer ins Visier.", 4.0)
				break
	if variante > 0 or welle >= Werte.WELLEN_VARIANTEN_AB:
		_runden_eintrag()["variante"] = variante
	_spawn_in = 1.0
	_start_zelle = karte.start_zelle()
	_erstes_ziel = karte.erstes_ziel()
	_turm_abkling.clear()
	for z: Vector2i in fabriken:
		fabriken[z]["timer"] = Werte.PRODUKTION_SEK - 0.5   # erste Einheit kommt sofort


## Die Welle, die als Nächstes kommt – in der Sandbox mit den dort eingestellten Gegnerzahlen.
func naechste_welle() -> Dictionary:
	var w := Werte.welle(Werte.ENDKAMPF_WIE_WELLE if endkampf else welle, variante, Werte.LETZTE_RUNDE if endkampf else -1)
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
	for typ: String in ["sprenger", "hund", "fahne", "sphaere", "rauch", "belagerung"]:
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
	return w


func sandbox_aendere_gegner(typ: String, um: int) -> void:
	var jetzt := 0
	for g: Dictionary in naechste_welle()["gruppen"]:
		if g["typ"] == typ:
			jetzt = g["anzahl"]
	sandbox_gegner[typ] = clampi(jetzt + um, 0, 200)


## Neue Bauphase: welche der zwei Varianten kommt? (vorher nur eine)
func waehle_variante() -> void:
	variante = randi() % 2 if welle >= Werte.WELLEN_VARIANTEN_AB else 0


## Sandbox: direkt zu einer Runde springen (nur in der Bauphase). Gebautes bleibt stehen.
func sandbox_springe(nr: int) -> void:
	nr = clampi(nr, 1, Werte.LETZTE_RUNDE)
	if not sandbox or phase != Phase.BAU or nr == welle:
		return
	welle = nr
	waehle_variante()
	_protokoll["sandbox_sprung"] = true
	karte.cp_aktiv = welle >= Werte.CHECKPOINTS_AB_WELLE
	_aktualisiere_zone()
	if welle >= Werte.SPRENGER_AB_WELLE:
		for b in zonenbauten:
			if b.art == "schleuder":
				schleuder_umzug(b, true)
	karte.zeige_schwachstelle = welle >= Werte.SPRENGER_AB_WELLE
	endkampf = welle == Werte.LETZTE_RUNDE
	karte.schild = not endkampf
	karte.zeige_angriff = endkampf
	karte.aktualisiere_pfad()


func _welle_geschafft() -> void:
	var bonus := Werte.wellen_bonus(welle)
	# Gehaltene Checkpoints zahlen sich aus
	var gehalten := 0
	if karte.cp_aktiv:
		for feind: bool in karte.cp_feind:
			if not feind:
				gehalten += 1
	var cp_bonus := gehalten * Werte.BONUS_JE_CHECKPOINT
	# Zinsen auf das, was am Rundenende noch übrig ist
	var zins := Werte.zinsen(budget)
	budget += bonus + cp_bonus + zins
	var text := "Runde %d überstanden: +%d Budget" % [welle, bonus]
	if zins > 0:
		text += ", +%d Zinsen" % zins
	if cp_bonus > 0:
		text += ", +%d für gehaltene Checkpoints (%d von %d)" % [cp_bonus, gehalten, karte.checkpoints.size()]
	melde(text + ".", 5.0)
	_schliesse_runde("geschafft")
	welle += 1
	waehle_variante()
	if welle == Werte.CHECKPOINTS_AB_WELLE:
		karte.cp_aktiv = true
		karte.aktualisiere_pfad()
	_aktualisiere_zone()
	# Stein-Schleudern stehen in jeder Runde woanders; der neue Kreis ist in der Bauphase zu sehen
	if welle >= Werte.SPRENGER_AB_WELLE:
		for b in zonenbauten:
			if b.art == "schleuder":
				schleuder_umzug(b, true)
	karte.zeige_schwachstelle = welle >= Werte.SPRENGER_AB_WELLE
	if welle == Werte.LETZTE_RUNDE:
		endkampf = true
		karte.schild = false
		karte.zeige_angriff = true
		karte.aktualisiere_pfad()
		melde("Letzte Runde: Der Schild ist gefallen! Truppen ohne Stellung marschieren zum HQ. Gib ihnen einen Fußweg (blaue Linie).", 10.0)
	phase = Phase.BAU
	karte.zeige_pfad_kraeftig = true
	for e in einheiten:
		e.queue_free()
	einheiten.clear()
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


# ------------------------------------------------- Rückmeldungen der Figuren

## Felder, die Truppen auf dem Weg zu ihrer Stellung meiden: alles im Gefahrenradius um einen Gegner am Boden.
func gefahrenzellen() -> Dictionary:
	if _gefahr_stand == Engine.get_process_frames():
		return _gefahr
	_gefahr_stand = Engine.get_process_frames()
	_gefahr = {}
	var r := int(ceil(Werte.GEFAHR_RADIUS))
	for g in gegner:
		if g._auf_wall:
			continue
		var mitte := karte.zelle_bei(g.position)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if Vector2(dx, dy).length() <= Werte.GEFAHR_RADIUS:
					_gefahr[mitte + Vector2i(dx, dy)] = true
	return _gefahr


## Schutzschild: Gegner in ihrer Zone sind bis zur letzten Runde nicht angreifbar.
func _geschuetzt(g: Gegner) -> bool:
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
func gegner_in_reichweite(von: Vector2, weite: float, braucht_sicht: bool, von_wall: Vector2i = Karte.KEINE) -> Gegner:
	var bester: Gegner = null
	var beste := weite * weite
	for g in gegner:
		if _geschuetzt(g):
			continue
		var d := von.distance_squared_to(g.position)
		if d > beste:
			continue
		if von_wall != Karte.KEINE and not karte.sicht_von_wall(von_wall, von, g.position):
			continue
		if not braucht_sicht or karte.sicht_frei(von, g.position):
			beste = d
			bester = g
	return bester


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
	if b == hq:
		phase = Phase.ENDE
		_schliesse_runde("sieg")
		_ende_text.text = "Sieg! Das gegnerische HQ ist zerstört.\n[R] Neustart"
		_ende.visible = true
	else:
		melde("Schleuder zerstört!", 3.0)


## Ziel einer Schleuder: die nächste Truppe in einer Stellung, sonst die nächste Fabrik (als Zelle).
func schleuderziel(von: Vector2, weite: float) -> Variant:
	var bestes: Variant = null
	var beste := weite * weite
	for e in einheiten:
		if not e.in_stellung():
			continue
		var d := von.distance_squared_to(e.position)
		if d <= beste:
			beste = d
			bestes = e
	if bestes != null:
		return bestes
	for z: Vector2i in karte.feld:
		if (karte.feld[z] != Karte.FABRIK and karte.feld[z] != Karte.BATTERIE) or karte.ausgefallen.has(z):
			continue
		var d := von.distance_squared_to(karte.mitte(z))
		if d <= beste:
			beste = d
			bestes = z
	return bestes


func wurf(von: Zonenbau, ziel: Variant) -> void:
	# Eine Einheit kann sterben, während der Stein fliegt: deshalb nur ihre Kennung mitgeben, nicht das Objekt.
	if ziel is Vector2i:
		effekte.wurf(von.position + Vector2(0, -30), karte.mitte(ziel), Werte.SCHLEUDER["flugzeit"], _einschlag_gebaeude.bind(ziel))
	else:
		var e := ziel as Einheit
		effekte.wurf(von.position + Vector2(0, -30), e.position, Werte.SCHLEUDER["flugzeit"], _einschlag_einheit.bind(e.get_instance_id()))


func _einschlag_gebaeude(zelle: Vector2i) -> void:
	if karte.inhalt(zelle) == Karte.FABRIK or karte.inhalt(zelle) == Karte.BATTERIE:
		karte.beschiesse(zelle, Werte.SCHLEUDER["schaden_fabrik"])   # fällt für die Runde aus, wird nicht zerstört


func _einschlag_einheit(kennung: int) -> void:
	if not is_instance_id_valid(kennung):
		return
	var e := instance_from_id(kennung) as Einheit
	if e != null and einheiten.has(e) and e.in_stellung():
		e.nimm_schaden(Werte.SCHLEUDER["schaden_einheit"])


func schuss(von: Vector2, nach: Vector2, farbe: Color) -> void:
	effekte.linie(von, nach, farbe)


func gegner_besiegt(g: Gegner) -> void:
	budget += int(g.daten["praemie"])
	gegner_entfernt(g)


## Gegner ohne Prämie aus dem Spiel nehmen (gesprengt, leerer Belagerungsturm).
func gegner_entfernt(g: Gegner) -> void:
	g.trupp.erase(g)
	gegner.erase(g)
	g.queue_free()


func _neuer_gegner(typ: String, zelle: Vector2i, erstes_ziel: int) -> Gegner:
	var g := Gegner.new()
	figuren.add_child(g)
	g.start(self, karte, typ, _welle["leben_faktor"], zelle, erstes_ziel)
	gegner.append(g)
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
		if not _wurf_schlange.is_empty():
			_schlange.append_array(_wurf_schlange)
			_wurf_schlange = []
		if not _wurf_aktiv.is_empty():
			_schlange.append(_wurf_aktiv)
			_wurf_aktiv = []
		return
	if _wurf_aktiv.is_empty():
		if _wurf_schlange.is_empty():
			if not _wurf_sofort:
				return
			_wurf_schlange.append(["hund", "hund", "hund", "hund"])   # Belagerung: ein Rudel als Zange obendrauf
		if not _wurf_sofort and _kampf_sek < float(Werte.WURF["wartet"]) and not endkampf:
			return   # sie hält sich zurück, bis die eigenen Truppen vorgerückt sind
		_wurf_bau = null
		for b: Zonenbau in schleudern:
			if b.wurfbereit() or (_wurf_sofort and _wurf_bau == null):
				_wurf_bau = b
				if b.wurfbereit():
					break
		if _wurf_bau == null:
			return
		var ziel := karte.wurf_landefeld(_wurf_bau.zelle, _wurf_meiden, Werte.WURF_BELAGERUNG_ABSTAND)
		if ziel.is_empty():
			ziel = karte.wurf_landefeld(_wurf_bau.zelle)
		_wurf_sofort = false
		_wurf_meiden = Vector2.INF
		if ziel.is_empty():
			return
		_wurf_landung = ziel["z"]
		# Geworfene stürmen den nächsten Checkpoint, den der Gegner noch nicht hält – nicht die Basis.
		_wurf_ziel = karte.sturmziel_ab(_wurf_landung)
		_wurf_bau.hat_geworfen()
		_wurf_aktiv = _wurf_schlange.pop_front()
		if OS.get_environment("TD_WURF_LOG") != "":
			print("WURF R%d v%d t=%.1f  %s -> %s  Umweg %.0f  %s" % [welle, variante, _kampf_sek, _wurf_bau.zelle, _wurf_landung, ziel["mauer"], _wurf_aktiv])
		_wurf_trupp = []
		_wurf_takt = 0.0
		var dauer: float = Werte.WURF["flugzeit"] + Werte.WURF["abstand"] * _wurf_aktiv.size() + 0.5
		effekte.warnung(karte.mitte(_wurf_landung), dauer)
	if not is_instance_valid(_wurf_bau):
		_schlange.append(_wurf_aktiv)   # Schleuder mitten im Wurf zerstört: der Rest läuft
		_wurf_aktiv = []
		return
	_wurf_takt -= delta
	if _wurf_takt > 0.0:
		return
	_wurf_takt = Werte.WURF["abstand"]
	var typ: String = _wurf_aktiv.pop_front()
	_im_flug += 1
	effekte.wurf(_wurf_bau.position + Vector2(0, -30), karte.mitte(_wurf_landung), Werte.WURF["flugzeit"], _hund_landet.bind(_wurf_landung, _wurf_ziel, _wurf_trupp, typ))


## Ein Belagerungsturm hat angedockt: Die Wurf-Schleuder wirft sofort – und zwar weit weg von ihm, die Verteidiger sitzen in der Zange.
func belagerung_dockt(g: Gegner) -> void:
	_wurf_sofort = true
	_wurf_meiden = g.position


func _hund_landet(zelle: Vector2i, erstes_ziel: int, rudel: Array, typ: String = "hund") -> void:
	_im_flug -= 1
	# Wurde inzwischen dort gebaut? Dann daneben landen.
	var feld := zelle if karte.ist_frei(zelle) else karte.freier_nachbar(zelle)
	if feld != Karte.KEINE:
		var g := _neuer_gegner(typ, feld, erstes_ziel)
		g.geworfen = true
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
		b.versetze(frei[randi() % frei.size()], sofort)


## Wallstücke, die schon ein anderer Sprenger anpeilt: jeder nimmt sich ein eigenes vor.
func sprenger_stuecke(ausser: Gegner) -> Array:
	var stuecke: Array = []
	for g in gegner:
		if g != ausser and g.rolle == "sprenger" and g.sprengt() != Karte.KEINE:
			stuecke.append(karte.stueck_nr(g.sprengt()))
	return stuecke


## Ein Sprenger hat seinen Erdwall erreicht.
func sprengung(g: Gegner, wall: Vector2i) -> void:
	var mitte := karte.mitte(wall)
	for i in 8:
		effekte.linie(mitte, mitte + Vector2.RIGHT.rotated(TAU * i / 8.0) * 44.0, Color("ffb347"))
	# Die Sprengung reicht zwei Felder tief: auch der Erdwall direkt dahinter fällt (ein Turm hält stand).
	var hinter := karte.sprengt_mit(wall, karte.zelle_bei(g.position))
	gegner_entfernt(g)
	karte.schade(wall, 100000.0)
	if hinter != Karte.KEINE:
		var m2 := karte.mitte(hinter)
		for i in 8:
			effekte.linie(m2, m2 + Vector2.RIGHT.rotated(TAU * i / 8.0) * 44.0, Color("ffb347"))
		karte.schade(hinter, 100000.0)
		melde("Ein Sprenger hat zwei Erdwälle hintereinander gesprengt!", 3.0)
	else:
		melde("Ein Sprenger hat einen Erdwall gesprengt!", 3.0)


## Ein Belagerungsturm setzt eine Turmtruppe auf den Wall.
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
			if not e.in_stellung() or von.distance_to(e.position) > weite or effekte.im_rauch(e.position):
				continue
			var d := e.position.distance_to(stelle)
			if d <= 4.0 * Werte.ZELLE and d < naechste:
				naechste = d
				bestes = e.position
		if bestes != null:
			return bestes
	for e in einheiten:
		if not e.in_stellung() or von.distance_to(e.position) > weite or effekte.im_rauch(e.position):
			continue
		var n := 0
		for f in einheiten:
			if f.in_stellung() and e.position.distance_to(f.position) <= radius:
				n += 1
		if n > meiste:
			meiste = n
			bestes = e.position
	return bestes


func lege_rauch(von: Vector2, punkt: Vector2) -> void:
	effekte.wurf(von + Vector2(0, -20), punkt, 0.8, effekte.rauch.bind(punkt, Werte.RAUCH_RADIUS * Werte.ZELLE, Werte.RAUCH_SEK))


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
	g.trupp.erase(g)
	gegner.erase(g)
	g.queue_free()
	leben -= 1
	if leben <= 0:
		leben = 0
		phase = Phase.ENDE
		_schliesse_runde("niederlage")
		_ende.visible = true


func einheit_gefallen(e: Einheit) -> void:
	einheiten.erase(e)
	if e.posten_zelle != Karte.KEINE and karte.posten.get(e.posten_zelle) == e:
		karte.posten.erase(e.posten_zelle)
	if karte.besatzung.has(e.posten_zelle):
		(karte.besatzung[e.posten_zelle] as Array).erase(e)
	if fabriken.has(e.fabrik_zelle):
		(fabriken[e.fabrik_zelle]["einheiten"] as Array).erase(e)
	e.queue_free()


func _bei_ausfall(_zelle: Vector2i, typ: int) -> void:
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
			if karte.ausbau[t] == Karte.TURM and (karte.stuetzen.get(t, []) as Array).size() < Werte.TURM_NACHBARN:
				melde("Ein Turm hat eine Stütze verloren und schweigt, bis der Erdwall wieder steht.", 4.0)
				break
	for e in einheiten:
		if e.posten_zelle == zelle:
			e.posten_verloren()
	for g in gegner:
		g.plane_neu()


# ------------------------------------------------------------------- Bauen

func kosten(typ: int) -> int:
	match typ:
		Karte.WALL:
			return Werte.KOSTEN_WALL
		Karte.STELLUNG:
			return Werte.KOSTEN_STELLUNG
		Karte.TURM:
			return Werte.KOSTEN_TURM
		Karte.TOR:
			return Werte.KOSTEN_TOR
		Karte.BATTERIE:
			return Werte.KOSTEN_BATTERIE
	# Fabriken werden teurer, je mehr schon stehen (Pilotenfabriken gehören zur Batterie und zählen nicht mit)
	return Werte.KOSTEN_FABRIK + Werte.KOSTEN_FABRIK_ZUWACHS * _normale_fabriken()


func _normale_fabriken() -> int:
	var n := 0
	for z: Vector2i in fabriken:
		if not karte.paar.has(z):
			n += 1
	return n


## So viele Truppen hält diese Fabrik am Leben.
func truppen_limit(z: Vector2i) -> int:
	var n := (Werte.MAX_JE_FABRIK_ENDKAMPF if endkampf else Werte.MAX_JE_FABRIK) + sandbox_truppen
	n = maxi(n, 1)
	if fabriken.has(z) and int(fabriken[z].get("stufe", 0)) >= 1:
		n += Werte.STUFE_1_TRUPPEN
	return n


## Das Feld, auf dem die Pilotenfabrik einer Batterie auf `z` stünde (mit [T] drehbar).
const PAAR_RICHTUNGEN: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var _paar_richtung := 0

func partner_feld(z: Vector2i) -> Vector2i:
	return z + PAAR_RICHTUNGEN[_paar_richtung]


func _ist_ausbau(typ: int) -> bool:
	return typ == Karte.STELLUNG or typ == Karte.TURM or typ == Karte.TOR


## Leerer Text = Bauen erlaubt, sonst der Grund, warum nicht.
func bau_hindernis(z: Vector2i, typ: int) -> String:
	if phase == Phase.KAMPF:
		# Während der Welle gehen nur Stellungen – und nur dort, wo gerade kein Gegner in der Nähe ist.
		if typ != Karte.STELLUNG:
			return "Während der Welle gehen nur Stellungen [3] und das Umstellen von Fabriken."
		if not ist_ruhig(karte.mitte(z), Werte.STELLUNG_BAU_RUHE * Werte.ZELLE):
			return "Zu nah am Gegner für eine neue Stellung."
	elif phase != Phase.BAU:
		return "Gebaut wird zwischen den Wellen."
	if typ != Karte.FABRIK and welle < Werte.WAELLE_AB_WELLE and not sandbox:
		return "Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
	if _ist_ausbau(typ):
		var grund := karte.ausbau_hindernis(z, typ)
		if grund != "":
			return grund
	elif not karte.ist_bebaubar(z):
		return "Hier ist kein Platz."
	elif typ == Karte.BATTERIE and not karte.ist_bebaubar(partner_feld(z)):
		return "Kein Platz für die Pilotenfabrik daneben – mit [T] drehen."
	if budget < kosten(typ):
		return "Nicht genug Budget."
	return ""


func baue(z: Vector2i, typ: int, still: bool = false) -> bool:
	var grund := bau_hindernis(z, typ)
	if grund != "":
		if not still:
			melde(grund)
		return false
	budget -= kosten(typ)
	var eintrag := {"a": "bau", "typ": BAU_NAMEN[typ], "x": z.x, "y": z.y}
	if phase == Phase.KAMPF:
		eintrag["t"] = snappedf(_kampf_sek, 0.1)   # während der Welle gebaut
	_notiere(eintrag)
	if _ist_ausbau(typ):
		karte.baue_aus(z, typ)
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


## Abreißen in der Bauphase erstattet einen Teil des Preises (Wall samt Ausbau).
func reisse_ab(z: Vector2i) -> bool:
	if phase != Phase.BAU or karte.inhalt(z) == Karte.FREI:
		return false
	var ausbau: int = karte.ausbau.get(z, Karte.FREI)
	var war: int = karte.inhalt(z)
	_notiere({"a": "abriss", "x": z.x, "y": z.y})
	_schliesse_fabrikmenue()
	if karte.paar.has(z):
		# Batterie und Pilotenfabrik gehören zusammen: beide fallen, erstattet wird der Paarpreis.
		var partner: Vector2i = karte.paar[z]
		fabriken.erase(z)
		fabriken.erase(partner)
		karte.entferne(partner)
		karte.entferne(z)
		budget += roundi(Werte.KOSTEN_BATTERIE * Werte.ERSTATTUNG)
		return true
	var stufen_wert := 0
	if fabriken.has(z):
		for i in int(fabriken[z].get("stufe", 0)):
			stufen_wert += Werte.KOSTEN_STUFE[i]
	fabriken.erase(z)
	karte.entferne(z)
	# Erstattet wird ein Anteil des Preises; bei einer Fabrik der Preis, den die zuletzt gebaute gekostet hat – samt Upgrades.
	var wert := kosten(war) + stufen_wert
	if ausbau != Karte.FREI:
		wert += kosten(ausbau)
	budget += roundi(wert * Werte.ERSTATTUNG)
	return true


## Klick ohne Bauwerkzeug: Einheit, Turm oder Batterie auswählen und ihre Reichweite zeigen.
## Ein Klick ins Leere hebt die Auswahl auf. Gibt true zurück, wenn etwas ausgewählt wurde.
func _waehle_aus(maus: Vector2, z: Vector2i) -> bool:
	if is_instance_valid(_auswahl):
		_auswahl.ausgewaehlt = false
		_auswahl.queue_redraw()
	_auswahl = null
	karte.auswahl = Karte.KEINE
	var beste := 34.0
	for e in einheiten:
		var d := maus.distance_to(e.position + Vector2(0, -8))
		if d < beste and not e.in_batterie():
			beste = d
			_auswahl = e
	if _auswahl != null:
		_auswahl.ausgewaehlt = true
		var d: Dictionary = _auswahl.daten
		if d.has("info"):
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
		karte.zeige_sicht(true, karte.mitte(z) + Vector2(0, -14), z, Werte.TURM["reichweite"])
	elif art == Karte.STELLUNG:
		var scharf: Dictionary = Werte.EINHEITEN["scharfschuetze"]
		karte.zeige_sicht(true, karte.mitte(z) + Vector2(0, -12), z, scharf["reichweite"] + Werte.stellung_bonus(scharf))
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
		melde("Diese Fabrik baut jetzt: %s (Reichweite %s, Schaden %s alle %s s)." % [d["name"], d["reichweite"], d["schaden"], d["abklingzeit"]], 4.0)


## Nächste Ausbaustufe einer Fabrik kaufen (nur in der Bauphase). Für Stufe 3 gehört die gewählte Fähigkeit dazu.
## Gibt true zurück, wenn es geklappt hat.
func werte_auf(z: Vector2i, faehigkeit: String = "") -> bool:
	if phase != Phase.BAU or not fabriken.has(z):
		return false
	if karte.paar.has(z):
		return _werte_batterie_auf(z)
	var stufe := int(fabriken[z].get("stufe", 0))
	if stufe >= Werte.KOSTEN_STUFE.size():
		return false
	if stufe == 2 and not (Werte.STUFE_3[fabriken[z]["typ"]] as Dictionary).has(faehigkeit):
		return false
	if budget < Werte.KOSTEN_STUFE[stufe]:
		melde("Nicht genug Budget.")
		return false
	budget -= Werte.KOSTEN_STUFE[stufe]
	fabriken[z]["stufe"] = stufe + 1
	karte.fabrik_stufe[z] = stufe + 1
	var eintrag := {"a": "upgrade", "x": z.x, "y": z.y, "stufe": stufe + 1}
	var d: Dictionary = Werte.EINHEITEN[fabriken[z]["typ"]]
	if stufe == 2:
		fabriken[z]["faehigkeit"] = faehigkeit
		eintrag["faehigkeit"] = faehigkeit
		_notiere(eintrag)
		var f3: Dictionary = Werte.STUFE_3[fabriken[z]["typ"]][faehigkeit]
		melde("%s Stufe 3 – %s: %s" % [d["name"], f3["name"], f3["text"]], 6.0)
		return true
	_notiere(eintrag)
	if stufe == 0:
		melde("Spezialisiert auf %s: hält jetzt eine Truppe mehr und bleibt bei dieser Truppe." % d["name"], 4.0)
	else:
		melde("%s Stufe 2: %s." % [d["name"], Werte.STUFE_2[fabriken[z]["typ"]]["text"]], 5.0)
	return true


## Batterie ausbauen: gekauft wird an ihrer Pilotenfabrik `pz`, die Stufen sind fest (Reservepilot, Schwere Ladung, Energieschild).
func _werte_batterie_auf(pz: Vector2i) -> bool:
	var stufe := int(fabriken[pz].get("stufe", 0))
	if stufe >= Werte.BATTERIE_STUFEN.size():
		return false
	if budget < Werte.KOSTEN_STUFE[stufe]:
		melde("Nicht genug Budget.")
		return false
	budget -= Werte.KOSTEN_STUFE[stufe]
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

## Der nächste Linksklick setzt das Schildfeld der Batterie, zu der die Pilotenfabrik `pz` gehört.
func waehle_schildfeld(pz: Vector2i) -> void:
	if phase != Phase.BAU or not karte.paar.has(pz) or int(fabriken[pz].get("stufe", 0)) < 3:
		return
	_schild_fuer = karte.paar[pz]
	werkzeug = Karte.FREI
	_schliesse_fabrikmenue()
	melde("Energieschild: Klick auf ein freies Wegfeld in Reichweite der Batterie. [Esc] bricht ab.", 6.0)


## Setzt das Schildfeld. Gibt "" zurück, wenn es geklappt hat, sonst den Grund.
func setze_schild(b: Vector2i, z: Vector2i) -> String:
	if batterie_stufe(b) < 3:
		return "Diese Batterie hat keinen Energieschild."
	if karte.inhalt(z) != Karte.FREI or not karte.ist_frei(z):
		return "Der Schild braucht ein freies Feld."
	if z.x < Werte.ZONE_SPALTEN:
		return "Nicht in der gegnerischen Zone."
	if karte.checkpoints.has(z) or z == karte.ziel_zelle(karte.checkpoints.size()):
		return "Nicht auf Checkpoint oder Basis."
	if karte.mitte(b).distance_to(karte.mitte(z)) > batterie_reichweite(b):
		return "Zu weit von der Batterie entfernt."
	for anderer: Vector2i in schilde:
		if anderer != b and schilde[anderer]["z"] == z:
			return "Dort steht schon ein Schild."
	schilde[b] = {"z": z, "leben": Werte.SCHILD_LEBEN}
	_notiere({"a": "schild", "x": z.x, "y": z.y, "bx": b.x, "by": b.y})
	return ""


func _schild_aktiv(b: Vector2i) -> bool:
	if not schilde.has(b) or karte.inhalt(b) != Karte.BATTERIE:
		return false
	var s: Dictionary = schilde[b]
	return s["leben"] > 0.0 and not karte.ausgefallen.has(b) and karte.inhalt(s["z"]) == Karte.FREI \
		and batterie_stufe(b) >= 3 and karte.besatzung_drin(b) >= int(Werte.BATTERIE["plaetze"])


## Steht ein Gegner an dieser Stelle vor einem aktiven Schild? Gibt die Batterie zurück (oder Karte.KEINE).
func schild_bei(punkt: Vector2) -> Vector2i:
	for b: Vector2i in schilde:
		if _schild_aktiv(b) and karte.mitte(schilde[b]["z"]).distance_to(punkt) <= Werte.ZELLE * 0.62:
			return b
	return Karte.KEINE


func schade_schild(b: Vector2i, menge: float) -> void:
	if not schilde.has(b):
		return
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
			schilde[b]["leben"] = Werte.SCHILD_LEBEN
		var s: Dictionary = schilde[b]
		# In der Bauphase als Vorschau zeigen, in der Welle nur, solange er wirklich steht
		var aktiv := _schild_aktiv(b) if phase == Phase.KAMPF else karte.inhalt(s["z"]) == Karte.FREI
		liste.append([karte.mitte(s["z"]), clampf(float(s["leben"]) / Werte.SCHILD_LEBEN, 0.0, 1.0), aktiv])
	effekte.schilde = liste


func waehle(typ: int) -> void:
	if phase == Phase.ENDE or (phase == Phase.KAMPF and typ != Karte.STELLUNG):
		return
	if typ != Karte.FABRIK and welle < Werte.WAELLE_AB_WELLE and not sandbox:
		melde("Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE)
		return
	werkzeug = Karte.FREI if werkzeug == typ else typ


func _tempo_umschalten() -> void:
	_tempo_faktor = 1.0 if _tempo_faktor > 1.5 else 2.0
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor


# ----------------------------------------------------------------- Eingabe

func _unhandled_input(event: InputEvent) -> void:
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
			KEY_SPACE:
				starte_welle()
			KEY_H:
				_nachschlag.umschalten()
			KEY_T:
				_paar_richtung = (_paar_richtung + 1) % PAAR_RICHTUNGEN.size()   # Pilotenfabrik der Batterie drehen
			KEY_Q, KEY_W, KEY_E, KEY_U:
				_fabrikmenue.taste(event.keycode)
			KEY_ESCAPE:
				if _nachschlag.visible:
					_nachschlag.umschalten()
				_schliesse_fabrikmenue()
				werkzeug = Karte.FREI
				_schild_fuer = Karte.KEINE
			KEY_F:
				_tempo_umschalten()
			KEY_R:
				if phase == Phase.ENDE:
					get_tree().reload_current_scene()
		return

	var z := karte.zelle_bei(get_global_mouse_position())
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _schild_fuer != Karte.KEINE:
				var grund := setze_schild(_schild_fuer, z)
				if grund == "":
					_schild_fuer = Karte.KEINE
					melde("Energieschild gesetzt.", 3.0)
				else:
					melde(grund)
			elif werkzeug != Karte.FREI:
				baue(z, werkzeug)
			elif not _waehle_aus(get_global_mouse_position(), z):
				if (fabriken.has(z) or karte.inhalt(z) == Karte.BATTERIE) and phase != Phase.ENDE:
					_oeffne_fabrikmenue(z)
				else:
					_schliesse_fabrikmenue()
			elif karte.inhalt(z) == Karte.BATTERIE and phase != Phase.ENDE:
				_oeffne_fabrikmenue(z)   # Batterie angeklickt: Reichweite zeigen und Ausbau-Menü öffnen
			else:
				_schliesse_fabrikmenue()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not reisse_ab(z):
				werkzeug = Karte.FREI
	elif event is InputEventMouseMotion:
		# Mit gedrückter Maustaste Wälle "malen" bzw. wieder wegwischen
		if werkzeug == Karte.WALL and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			baue(z, Karte.WALL, true)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT and karte.inhalt(z) == Karte.WALL:
			reisse_ab(z)


func _oeffne_fabrikmenue(z: Vector2i) -> void:
	if karte.paar.has(z) and not fabriken.has(z):
		z = karte.paar[z]   # Klick auf die Batterie: ihr Menü hängt an der Pilotenfabrik
	_fabrikmenue.oeffne(z)


func _schliesse_fabrikmenue() -> void:
	if _fabrikmenue != null:
		_fabrikmenue.schliesse()


func _aktualisiere_vorschau() -> void:
	var z := karte.zelle_bei(get_global_mouse_position())
	karte.vorschau_partner = partner_feld(z) if werkzeug == Karte.BATTERIE else Karte.KEINE
	if phase != Phase.ENDE and werkzeug != Karte.FREI:
		karte.setze_vorschau(z, werkzeug, bau_hindernis(z, werkzeug) == "")
	else:
		karte.setze_vorschau(Karte.KEINE, Karte.FREI, false)


# ------------------------------------------------------------------ Anzeige

func melde(text: String, dauer: float = 2.5) -> void:
	_meldung = text
	_meldung_zeit = dauer


func _noch_offen() -> int:
	var n := _wurf_aktiv.size() + _im_flug
	for typen: Array in _schlange:
		n += typen.size()
	for typen: Array in _wurf_schlange:
		n += typen.size()
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
	_lbl_status.text = "Runde %d/%d    Budget %s    Leben %d" % [welle, Werte.LETZTE_RUNDE, "∞" if sandbox else str(budget), leben]
	if endkampf:
		_lbl_vorschau.text = "Letzte Runde: Zerstöre das HQ (%d/%d). Gegner kommen ohne Ende." % [ceili(hq.leben) if is_instance_valid(hq) else 0, int(Werte.HQ_LEBEN)]
	elif phase == Phase.KAMPF:
		_lbl_vorschau.text = "Läuft: %s – noch %d" % [_wellen_text(_welle, false), _noch_offen() + gegner.size()]
	else:
		_lbl_vorschau.text = "Nächste: %s" % _wellen_text(naechste_welle())

	# lange Ansagen etwas kleiner, damit sie nicht in "[H] Formationen" laufen
	_lbl_vorschau.add_theme_font_size_override("font_size", 16 if _lbl_vorschau.text.length() <= 72 else (14 if _lbl_vorschau.text.length() <= 84 else 12))
	var ab_welle_2 := welle >= Werte.WAELLE_AB_WELLE or sandbox
	for typ: int in _knoepfe:
		var b: Button = _knoepfe[typ]
		b.button_pressed = werkzeug == typ
		b.disabled = (phase != Phase.BAU and not (phase == Phase.KAMPF and typ == Karte.STELLUNG)) or (typ != Karte.FABRIK and not ab_welle_2)
	_btn_start.disabled = phase != Phase.BAU
	_btn_tempo.text = "[F] Tempo ×%d" % roundi(_tempo_faktor)
	var zins := Werte.zinsen(budget)
	for i in _zins_felder.size():
		_zins_felder[i].color = Color("ffd34d") if (i + 1) * Werte.ZINS_JE_SCHRITT <= zins else Color("1b1722")
	_lbl_zins.text = "+%d" % zins
	(_knoepfe[Karte.FABRIK] as Button).text = "[1] Fabrik  %d" % kosten(Karte.FABRIK)

	# Hinweiszeile: kurze Meldung hat Vorrang, sonst ein Tipp passend zur Lage.
	# Meldungen laufen in Echtzeit ab, nicht schneller bei Tempo ×2.
	_meldung_zeit -= delta / maxf(Engine.time_scale, 0.01)
	var text := ""
	if _meldung_zeit > 0.0:
		text = _meldung
	elif phase == Phase.KAMPF:
		text = ""
	elif endkampf and karte.angriffs_pfad.is_empty():
		text = "Kein Fußweg zum HQ! Reiße Erdwälle ab (Rechtsklick), sonst kommen deine Truppen nicht durch."
	elif endkampf and werkzeug == Karte.FREI:
		text = "Blaue Linie = Fußweg deiner Truppen zum HQ. Nur Truppen ohne Stellung greifen an."
	elif (werkzeug == Karte.WALL or werkzeug == Karte.FABRIK) and not karte.vorschau_pfad.is_empty() and karte.weg_bricht_durch(karte.vorschau_pfad, karte.vorschau_zelle):
		text = "Kein Weg mehr frei: Die Gegner reißen das rot markierte Feld ein."
	elif karte.weg_bricht_durch(karte.pfad):
		text = "Achtung: Der Weg führt durch ein Gebäude (rot). Die Gegner reißen es ein."
	elif not ab_welle_2:
		text = "Runde 1: Fabriken setzen, dann Leertaste. Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
	elif werkzeug == Karte.STELLUNG:
		text = "Stellung: Ausbau eines Erdwalls. Eine Einheit steht oben, schießt weiter und über Wälle hinweg."
	elif werkzeug == Karte.TURM:
		text = "Turm: nur auf Erdwällen mit %d angrenzenden Erdwällen (leuchtende Punkte)." % Werte.TURM_NACHBARN
	elif werkzeug == Karte.BATTERIE:
		text = "Batterie mit Pilotenfabrik (zwei Felder, [T] dreht): feuert weit und flächig, sobald %d Piloten darin sitzen." % int(Werte.BATTERIE["plaetze"])
	elif werkzeug == Karte.WALL:
		text = "Maustaste halten = ziehen, Rechtsklick = abreißen (%d %% zurück)." % roundi(Werte.ERSTATTUNG * 100.0)
	elif karte.start_index() >= 0:
		text = "Die Welle startet am pinken Checkpoint. Truppen ohne Stellung holen ihn zurück (%d s halten, nur während der Welle)." % int(Werte.RUECKEROBERUNG_SEK)
	elif werkzeug == Karte.FREI:
		text = "Klick auf eine Fabrik: Truppe wählen und ausbauen. Truppen besetzen die nächste freie Stellung."
	# Ansage neuer Gegner oder Gebäude: bleibt die ganze Bauphase stehen
	var ansage: String = Werte.NEUHEITEN.get(welle, "") if phase == Phase.BAU else ""
	_neu_grund.visible = ansage != ""
	_lbl_neu.text = ansage
	_lbl_hinweis.text = text
	_hinweis_grund.visible = text != ""
	_hinweis_grund.size.x = _lbl_hinweis.get_minimum_size().x + 24.0


func _baue_hud() -> void:
	var ebene := CanvasLayer.new()
	add_child(ebene)
	var breite := 1280.0
	var unten_y := float(Werte.KARTE_OBEN + Werte.ZEILEN * Werte.ZELLE)

	var oben := ColorRect.new()
	oben.color = Color("1b1722")
	oben.size = Vector2(breite, Werte.KARTE_OBEN)
	ebene.add_child(oben)
	_lbl_status = _label(oben, Vector2(16, 7), 20, Color("ffe9a8"))
	_lbl_vorschau = _label(oben, Vector2(400, 10), 16, Color("d8cfe6"))
	_lbl_vorschau.clip_text = true
	_lbl_vorschau.size = Vector2(700, 24)

	var unten := ColorRect.new()
	unten.color = Color("1b1722")
	unten.position = Vector2(0, unten_y)
	unten.size = Vector2(breite, 720.0 - unten_y)
	ebene.add_child(unten)
	var x := 8.0
	for eintrag: Array in [
		[Karte.FABRIK, "[1] Fabrik  %d" % Werte.KOSTEN_FABRIK, 112],
		[Karte.WALL, "[2] Erdwall  %d" % Werte.KOSTEN_WALL, 112],
		[Karte.STELLUNG, "[3] Stellung  %d" % Werte.KOSTEN_STELLUNG, 122],
		[Karte.TURM, "[4] Turm  %d" % Werte.KOSTEN_TURM, 100],
		[Karte.BATTERIE, "[5] Batterie  %d" % Werte.KOSTEN_BATTERIE, 132],
		[Karte.TOR, "[6] Tor  %d" % Werte.KOSTEN_TOR, 92],
	]:
		var typ: int = eintrag[0]
		var b := _knopf(unten, x, eintrag[2], waehle.bind(typ), true)
		b.text = eintrag[1]
		_knoepfe[typ] = b
		x += eintrag[2] + 6.0
	_btn_tempo = _knopf(unten, breite - 138, 130, _tempo_umschalten, false)
	_btn_start = _knopf(unten, breite - 364, 220, starte_welle, false)
	_btn_start.text = "[Leertaste] Welle starten"

	# Zinsanzeige wie in Teamfight Tactics: ein Feld je Zinsschritt, gefüllt = schon erreicht
	_label(unten, Vector2(x + 8, 10), 15, Color("d8cfe6")).text = "Zinsen"
	for i in Werte.ZINS_STUFEN:
		var rahmen := ColorRect.new()
		rahmen.color = Color("3a3344")
		rahmen.position = Vector2(x + 66 + i * 20, 12)
		rahmen.size = Vector2(16, 16)
		rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unten.add_child(rahmen)
		var feld := ColorRect.new()
		feld.position = Vector2(2, 2)
		feld.size = Vector2(12, 12)
		feld.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rahmen.add_child(feld)
		_zins_felder.append(feld)
	_lbl_zins = _label(unten, Vector2(x + 66 + Werte.ZINS_STUFEN * 20 + 4, 10), 15, Color("ffd34d"))

	# Hinweiszeile liegt halb durchsichtig am unteren Rand der Karte
	_hinweis_grund = ColorRect.new()
	_hinweis_grund.color = Color(0.07, 0.06, 0.09, 0.8)
	_hinweis_grund.position = Vector2(0, unten_y - 28)
	_hinweis_grund.size = Vector2(400, 28)
	_hinweis_grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ebene.add_child(_hinweis_grund)
	_lbl_hinweis = _label(_hinweis_grund, Vector2(12, 3), 15, Color("ece6f5"))

	_neu_grund = ColorRect.new()
	_neu_grund.color = Color(0.07, 0.06, 0.09, 0.85)
	_neu_grund.position = Vector2(200, Werte.KARTE_OBEN)
	_neu_grund.size = Vector2(breite - 200, 52)
	_neu_grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ebene.add_child(_neu_grund)
	_lbl_neu = _label(_neu_grund, Vector2(12, 4), 15, Color("ffe9a8"))
	_lbl_neu.size = Vector2(breite - 224, 46)
	_lbl_neu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_label(oben, Vector2(breite - 158, 11), 15, Color("a79fb3")).text = "[H] Formationen"
	_fabrikmenue = Fabrikmenue.new()
	_fabrikmenue.spiel = self
	ebene.add_child(_fabrikmenue)
	var leiste: Control = preload("res://scripts/sandboxleiste.gd").new()
	leiste.spiel = self
	ebene.add_child(leiste)
	_nachschlag = Nachschlag.new()
	ebene.add_child(_nachschlag)

	_ende = ColorRect.new()
	(_ende as ColorRect).color = Color(0, 0, 0, 0.75)
	_ende.size = Vector2(breite, 720)
	_ende.visible = false
	ebene.add_child(_ende)
	var text := _label(_ende, Vector2.ZERO, 40, Color("ffe9a8"))
	_ende_text = text
	text.text = "Die Basis ist gefallen.\n[R] Neustart"
	text.size = Vector2(breite, 720)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
