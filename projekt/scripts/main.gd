extends Node2D
## Spielablauf: Bauphase -> Welle -> Bauphase ... sowie Eingabe und Anzeige.

enum Phase { BAU, KAMPF, ENDE }

var phase := Phase.BAU
var werkzeug: int = Karte.FREI      # Karte.FREI = nichts gewählt, sonst WALL / FABRIK / STELLUNG / TURM
var budget: int = Werte.START_BUDGET
var leben: int = Werte.START_LEBEN
var welle: int = 1

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
var _wurf_salve := 0                # so viele Hunde wirft die Wurf-Schleuder in diesem Rudel noch
var _wurf_bau: Zonenbau
var _wurf_landung := Karte.KEINE
var _wurf_ziel := 0
var _wurf_trupp: Array = []
# Bauprotokoll: was in welcher Runde gebaut wurde und wie die Runde ausging (für das Nachspielen und Auswerten)
var protokoll_an := true
var _protokoll: Dictionary = {}
var _protokoll_datei := ""
var _runde_start_ms := 0
var _leben_vor_runde := 0
var _cp_verloren := 0
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


# -------------------------------------------------------------- Bauprotokoll

const BAU_NAMEN := {Karte.WALL: "wall", Karte.FABRIK: "fabrik", Karte.STELLUNG: "stellung", Karte.TURM: "turm", Karte.BATTERIE: "batterie"}


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
func _aktualisiere_zone() -> bool:
	var neu := false
	if hq == null:
		hq = _neuer_zonenbau("hq", Werte.START_ZELLE)
	for s: Dictionary in Werte.ZONENBAUTEN:
		if welle < int(s["ab_welle"]):
			continue
		var da := false
		for b in zonenbauten:
			if b.zelle == s["zelle"]:
				da = true
		if not da:
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
	if phase != Phase.KAMPF:
		return

	if endkampf and _schlange.is_empty():
		# letzte Runde: nach kurzer Pause beginnt dieselbe Reihe Trupps von vorn
		_schlange = (_welle["trupps"] as Array).duplicate(true)
		_spawn_in = Werte.ENDKAMPF_PAUSE
	if not _schlange.is_empty():
		_spawn_in -= delta
		if _spawn_in <= 0.0:
			var typen: Array = _schlange[0]
			var typ: String = typen.pop_front()
			var geworfen := _wirf_statt_laufen(typ)
			if not geworfen:
				var g := _neuer_gegner(typ, _spawn_zelle(), _erstes_ziel)
				g.trupp = _trupp
				_trupp.append(g)
			if typen.is_empty():
				# Trupp vollständig: nach einer Pause kommt der nächste
				_schlange.pop_front()
				_trupp = []
				_wurf_salve = 0
				_spawn_in += Werte.ENDKAMPF_TRUPP_PAUSE if endkampf else Werte.TRUPP_PAUSE
			else:
				_spawn_in += Werte.WURF["abstand"] if geworfen else _welle["abstand"]

	for z: Vector2i in fabriken:
		var f: Dictionary = fabriken[z]
		if (f["einheiten"] as Array).size() >= (Werte.MAX_JE_FABRIK_ENDKAMPF if endkampf else Werte.MAX_JE_FABRIK):
			f["timer"] = 0.0
			karte.fortschritt[z] = 1.0
			continue
		f["timer"] += delta
		karte.fortschritt[z] = f["timer"] / Werte.PRODUKTION_SEK
		if f["timer"] >= Werte.PRODUKTION_SEK:
			f["timer"] = 0.0
			var e := Einheit.new()
			figuren.add_child(e)
			e.start(self, karte, f["typ"], z)
			einheiten.append(e)
			(f["einheiten"] as Array).append(e)

	_tuerme_feuern(delta)
	_batterien_feuern(delta)
	_checkpoints_halten(delta)

	if not endkampf and _schlange.is_empty() and gegner.is_empty() and _im_flug == 0 and phase == Phase.KAMPF:
		_welle_geschafft()


## Bodentruppen auf einem verlorenen Checkpoint holen ihn nach einigen Sekunden zurück.
func _checkpoints_halten(delta: float) -> void:
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
		if karte.ausbau[z] != Karte.TURM:
			continue
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
	var weite: float = Werte.BATTERIE["reichweite"] * Werte.ZELLE
	var radius: float = Werte.BATTERIE["flaeche"] * Werte.ZELLE
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.BATTERIE:
			continue
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
				flaechenschaden(bestes.position, radius, Werte.BATTERIE["schaden"], Color("7fe0ff"))
		_turm_abkling[z] = maxf(rest, 0.0) if rest <= 0.0 else rest


## Schaden an allen Gegnern im Umkreis, mit einem kurzen Ring als Zeichen.
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
	phase = Phase.KAMPF
	werkzeug = Karte.FREI
	_runde_start_ms = Time.get_ticks_msec()
	_leben_vor_runde = leben
	_cp_verloren = 0
	karte.zeige_pfad_kraeftig = false
	_welle = Werte.welle(Werte.ENDKAMPF_WIE_WELLE if endkampf else welle)
	_schlange = (_welle["trupps"] as Array).duplicate(true)
	_trupp = []
	_im_flug = 0
	_spawn_in = 1.0
	_start_zelle = karte.start_zelle()
	_erstes_ziel = karte.erstes_ziel()
	_turm_abkling.clear()
	for z: Vector2i in fabriken:
		fabriken[z]["timer"] = Werte.PRODUKTION_SEK - 0.5   # erste Einheit kommt sofort


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
func fernziel(von: Vector2, weite: float) -> Einheit:
	var bestes: Einheit = null
	var beste := weite * weite
	for e in einheiten:
		var d := von.distance_squared_to(e.position)
		if d <= beste and (e.in_stellung() or (e.am_boden() and karte.sicht_frei(von, e.position))):
			beste = d
			bestes = e
	return bestes


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
		if karte.feld[z] != Karte.FABRIK and karte.feld[z] != Karte.BATTERIE:
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
		karte.schade(zelle, Werte.SCHLEUDER["schaden_fabrik"])


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
	return g


## Wurf-Schleuder: Ist eine bereit, fliegt ein ganzes Rudel Hunde kurz hintereinander über die ersten Wälle,
## statt aus der Zone zu laufen. Das Rudel landet an derselben Stelle und bleibt als Trupp zusammen.
func _wirf_statt_laufen(typ: String) -> bool:
	if typ != "hund" or _start_zelle != Werte.START_ZELLE:
		_wurf_salve = 0
		return false
	if _wurf_salve <= 0 or not is_instance_valid(_wurf_bau):
		# neues Rudel: eine bereite Wurf-Schleuder und ein Landefeld suchen
		_wurf_bau = null
		for b in zonenbauten:
			if b.wurfbereit():
				_wurf_bau = b
				break
		if _wurf_bau == null:
			return false
		_wurf_landung = karte.landefeld(_wurf_bau.zelle, Werte.WURF["reichweite"])
		if _wurf_landung == Karte.KEINE:
			return false
		_wurf_ziel = karte.bestes_ziel_ab(_wurf_landung, _erstes_ziel)
		_wurf_bau.hat_geworfen()
		_wurf_salve = int(Werte.WURF["rudel"])
		_wurf_trupp = []
	_wurf_salve -= 1
	_im_flug += 1
	effekte.wurf(_wurf_bau.position + Vector2(0, -30), karte.mitte(_wurf_landung), Werte.WURF["flugzeit"], _hund_landet.bind(_wurf_landung, _wurf_ziel, _wurf_trupp))
	return true


func _hund_landet(zelle: Vector2i, erstes_ziel: int, rudel: Array) -> void:
	_im_flug -= 1
	# Wurde inzwischen dort gebaut? Dann daneben landen.
	var feld := zelle if karte.ist_frei(zelle) else karte.freier_nachbar(zelle)
	if feld != Karte.KEINE:
		var g := _neuer_gegner("hund", feld, erstes_ziel)
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


## Ein Sprenger hat seinen Erdwall erreicht.
func sprengung(g: Gegner, wall: Vector2i) -> void:
	var mitte := karte.mitte(wall)
	for i in 8:
		effekte.linie(mitte, mitte + Vector2.RIGHT.rotated(TAU * i / 8.0) * 44.0, Color("ffb347"))
	gegner_entfernt(g)
	karte.schade(wall, 100000.0)
	melde("Ein Sprenger hat einen Erdwall gesprengt!", 3.0)


## Ein Belagerungsturm setzt eine Turmtruppe auf den Wall.
func setze_enterer_ab(wall: Vector2i, leben_faktor: float, erstes_ziel: int) -> void:
	var g := Gegner.new()
	figuren.add_child(g)
	g.start(self, karte, "enterer", leben_faktor, wall, erstes_ziel)
	gegner.append(g)


## Wohin wirft ein Rauchwerfer? Auf die Stellungstruppe in Wurfweite, um die herum die meisten anderen stehen.
func rauchziel(von: Vector2, weite: float) -> Variant:
	var bestes: Variant = null
	var meiste := 0
	var radius := Werte.RAUCH_RADIUS * Werte.ZELLE
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


func _bei_zerstoert(zelle: Vector2i, typ: int) -> void:
	if typ == Karte.FABRIK:
		fabriken.erase(zelle)
		melde("Eine Fabrik wurde zerstört!", 3.0)
	_turm_abkling.erase(zelle)
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
		Karte.BATTERIE:
			return Werte.KOSTEN_BATTERIE
	# Fabriken werden teurer, je mehr schon stehen
	return Werte.KOSTEN_FABRIK + Werte.KOSTEN_FABRIK_ZUWACHS * fabriken.size()


func _ist_ausbau(typ: int) -> bool:
	return typ == Karte.STELLUNG or typ == Karte.TURM


## Leerer Text = Bauen erlaubt, sonst der Grund, warum nicht.
func bau_hindernis(z: Vector2i, typ: int) -> String:
	if phase != Phase.BAU:
		return "Gebaut wird zwischen den Wellen."
	if typ != Karte.FABRIK and welle < Werte.WAELLE_AB_WELLE:
		return "Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
	if _ist_ausbau(typ):
		var grund := karte.ausbau_hindernis(z, typ)
		if grund != "":
			return grund
	elif not karte.ist_bebaubar(z):
		return "Hier ist kein Platz."
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
	_notiere({"a": "bau", "typ": BAU_NAMEN[typ], "x": z.x, "y": z.y})
	if _ist_ausbau(typ):
		karte.baue_aus(z, typ)
		return true
	karte.setze(z, typ)
	if typ == Karte.FABRIK:
		fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": Werte.FABRIK_EINHEITEN[0]}
		karte.fabrik_typ[z] = Werte.FABRIK_EINHEITEN[0]
	return true


## Abreißen in der Bauphase erstattet einen Teil des Preises (Wall samt Ausbau).
func reisse_ab(z: Vector2i) -> bool:
	if phase != Phase.BAU or karte.inhalt(z) == Karte.FREI:
		return false
	var ausbau: int = karte.ausbau.get(z, Karte.FREI)
	var war: int = karte.inhalt(z)
	_notiere({"a": "abriss", "x": z.x, "y": z.y})
	fabriken.erase(z)
	karte.entferne(z)
	# Erstattet wird ein Anteil des Preises; bei einer Fabrik der Preis, den die zuletzt gebaute gekostet hat.
	var wert := kosten(war)
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


## Klick auf eine Fabrik (ohne Bauwerkzeug): nächste Einheit aus der Liste wählen.
func wechsle_einheit(z: Vector2i) -> void:
	if phase != Phase.BAU or not fabriken.has(z):
		return
	var liste := Werte.FABRIK_EINHEITEN
	var neu: String = liste[(liste.find(fabriken[z]["typ"]) + 1) % liste.size()]
	fabriken[z]["typ"] = neu
	karte.fabrik_typ[z] = neu
	_notiere({"a": "einheit", "typ": neu, "x": z.x, "y": z.y})
	var d: Dictionary = Werte.EINHEITEN[neu]
	if d.has("info"):
		melde("Diese Fabrik bildet jetzt aus: " + d["info"], 5.0)
	else:
		melde("Diese Fabrik baut jetzt: %s (Reichweite %s, Schaden %s alle %s s)." % [d["name"], d["reichweite"], d["schaden"], d["abklingzeit"]], 4.0)


func waehle(typ: int) -> void:
	if phase != Phase.BAU:
		return
	if typ != Karte.FABRIK and welle < Werte.WAELLE_AB_WELLE:
		melde("Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE)
		return
	werkzeug = Karte.FREI if werkzeug == typ else typ


func _tempo_umschalten() -> void:
	_tempo_faktor = 1.0 if _tempo_faktor > 1.5 else 2.0
	Engine.time_scale = Werte.SPIELTEMPO * _tempo_faktor


# ----------------------------------------------------------------- Eingabe

func _unhandled_input(event: InputEvent) -> void:
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
			KEY_SPACE:
				starte_welle()
			KEY_ESCAPE:
				werkzeug = Karte.FREI
			KEY_F:
				_tempo_umschalten()
			KEY_R:
				if phase == Phase.ENDE:
					get_tree().reload_current_scene()
		return

	var z := karte.zelle_bei(get_global_mouse_position())
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if werkzeug != Karte.FREI:
				baue(z, werkzeug)
			elif not _waehle_aus(get_global_mouse_position(), z):
				wechsle_einheit(z)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not reisse_ab(z):
				werkzeug = Karte.FREI
	elif event is InputEventMouseMotion:
		# Mit gedrückter Maustaste Wälle "malen" bzw. wieder wegwischen
		if werkzeug == Karte.WALL and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			baue(z, Karte.WALL, true)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT and karte.inhalt(z) == Karte.WALL:
			reisse_ab(z)


func _aktualisiere_vorschau() -> void:
	var z := karte.zelle_bei(get_global_mouse_position())
	if phase == Phase.BAU and werkzeug != Karte.FREI:
		karte.setze_vorschau(z, werkzeug, bau_hindernis(z, werkzeug) == "")
	else:
		karte.setze_vorschau(Karte.KEINE, Karte.FREI, false)


# ------------------------------------------------------------------ Anzeige

func melde(text: String, dauer: float = 2.5) -> void:
	_meldung = text
	_meldung_zeit = dauer


func _noch_offen() -> int:
	var n := 0
	for typen: Array in _schlange:
		n += typen.size()
	return n


func _wellen_text(w: Dictionary) -> String:
	var teile: PackedStringArray = []
	for gruppe: Dictionary in w["gruppen"]:
		var g: Dictionary = Werte.GEGNER[gruppe["typ"]]
		teile.append("%d %s" % [gruppe["anzahl"], g["kurz"]])
	var text := " · ".join(teile)
	if not is_equal_approx(w["leben_faktor"], 1.0):
		text += ", Leben ×%.1f" % w["leben_faktor"]
	return text


func _aktualisiere_hud(delta: float) -> void:
	_lbl_status.text = "Runde %d/%d    Budget %d    Leben %d" % [welle, Werte.LETZTE_RUNDE, budget, leben]
	if endkampf:
		_lbl_vorschau.text = "Letzte Runde: Zerstöre das HQ (%d/%d). Gegner kommen ohne Ende." % [ceili(hq.leben) if is_instance_valid(hq) else 0, int(Werte.HQ_LEBEN)]
	elif phase == Phase.KAMPF:
		_lbl_vorschau.text = "Läuft: %s – noch %d" % [_wellen_text(_welle), _noch_offen() + gegner.size()]
	else:
		_lbl_vorschau.text = "Nächste: %s" % _wellen_text(Werte.welle(welle))

	var ab_welle_2 := welle >= Werte.WAELLE_AB_WELLE
	for typ: int in _knoepfe:
		var b: Button = _knoepfe[typ]
		b.button_pressed = werkzeug == typ
		b.disabled = phase != Phase.BAU or (typ != Karte.FABRIK and not ab_welle_2)
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
		text = "Kein lohnender Umweg mehr: Die Gegner reißen das rot markierte Feld ein."
	elif karte.weg_bricht_durch(karte.pfad):
		text = "Achtung: Der Weg führt durch ein Gebäude (rot). Die Gegner reißen es ein."
	elif not ab_welle_2:
		text = "Runde 1: Fabriken setzen, dann Leertaste. Erdwälle gibt es ab Welle %d." % Werte.WAELLE_AB_WELLE
	elif werkzeug == Karte.STELLUNG:
		text = "Stellung: Ausbau eines Erdwalls. Eine Einheit steht oben, schießt weiter und über Wälle hinweg."
	elif werkzeug == Karte.TURM:
		text = "Turm: nur auf Erdwällen mit %d angrenzenden Erdwällen (leuchtende Punkte)." % Werte.TURM_NACHBARN
	elif werkzeug == Karte.BATTERIE:
		text = "Batterie: feuert weit und flächig, aber erst mit %d Piloten darin. Piloten bildet eine Fabrik aus (Fabrik anklicken)." % int(Werte.BATTERIE["plaetze"])
	elif werkzeug == Karte.WALL:
		text = "Maustaste halten = ziehen, Rechtsklick = abreißen (%d %% zurück)." % roundi(Werte.ERSTATTUNG * 100.0)
	elif karte.start_index() >= 0:
		text = "Die Welle startet am pinken Checkpoint. Truppen ohne Stellung holen ihn zurück (%d s halten, nur während der Welle)." % int(Werte.RUECKEROBERUNG_SEK)
	elif werkzeug == Karte.FREI:
		text = "Klick auf eine Fabrik wechselt ihre Einheit. Truppen besetzen die nächste freie Stellung."
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

	var unten := ColorRect.new()
	unten.color = Color("1b1722")
	unten.position = Vector2(0, unten_y)
	unten.size = Vector2(breite, 720.0 - unten_y)
	ebene.add_child(unten)
	var x := 8.0
	for eintrag: Array in [
		[Karte.FABRIK, "[1] Fabrik  %d" % Werte.KOSTEN_FABRIK, 130],
		[Karte.WALL, "[2] Erdwall  %d" % Werte.KOSTEN_WALL, 130],
		[Karte.STELLUNG, "[3] Stellung  %d" % Werte.KOSTEN_STELLUNG, 140],
		[Karte.TURM, "[4] Turm  %d" % Werte.KOSTEN_TURM, 120],
		[Karte.BATTERIE, "[5] Batterie  %d" % Werte.KOSTEN_BATTERIE, 150],
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
