class_name Fabrikmenue
extends Control
## Ankerfenster an Fabrik, Turm, Batterie oder Schildgenerator (16.11.2026, neuer Stil): sitzt neben dem Gebäude,
## eine Haltelinie zeigt darauf, und es weicht der Reichweite aus. Inhalt wie zuvor: Truppe wählen (Stufe 0),
## Zielwahl, Werte über die Partie, Ausbaupfad als Kette, nächste Stufe als Karte, auf Stufe 3 die zwei
## Fähigkeiten nebeneinander. Gezeichnet im UI-Raster (zweifach skaliert) mit ui_stil.gd.
## Tasten: Q / W / E = Truppe (Stufe 0) oder Fähigkeit (Stufe 3), U = Upgrade, Esc schließt.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const BREITE_NORMAL := 168.0
const BREITE_DREI := 216.0     # breiter, wenn Stufe 3 drei Fähigkeiten zur Wahl hat
var BREITE := BREITE_NORMAL
const PAD := 6.0
const ABSTAND := 4.0

var spiel: Node
var zelle := Karte.KEINE

var _stand := ""                  # woraus das Fenster zuletzt gebaut wurde – neu bauen nur, wenn sich etwas ändert
var _truppen_knoepfe: Array[Button] = []
var _upgrade_knopf: Button
var _texte: Array = []            # [Position, Text, Größe, Farbe, Weite]
var _stats_y := 0.0               # Zeile mit den Werten über die Partie (ändert sich laufend)
var _stats := ""
var _anker := Vector2.ZERO        # Gebäude in lokalen Koordinaten (für die Haltelinie)


## Knopf, der sich selbst zeichnet (Chips, Karten).
class Feld extends Button:
	var malen: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)


func _ready() -> void:
	visible = false
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP   # solange die Maus darauf ist, wird nicht gebaut


func oeffne(z: Vector2i) -> void:
	if not spiel.fabriken.has(z) and not _ist_turm(z) and not _ist_generator(z) and not _ist_mg(z):
		return
	zelle = z
	_stand = ""
	visible = true
	_baue()


func schliesse() -> void:
	visible = false
	zelle = Karte.KEINE


func _ist_turm(z: Vector2i) -> bool:
	return spiel.karte.ausbau.get(z, Karte.FREI) == Karte.TURM


func _ist_generator(z: Vector2i) -> bool:
	return spiel.karte.inhalt(z) == Karte.GENERATOR


## 20.11. (Paul): MG-Stellung (Sonde 7) – das Nest hat einen eigenen Ausbau.
func _ist_mg(z: Vector2i) -> bool:
	return Werte.mg_stellung() and spiel.karte.ausbau.get(z, Karte.FREI) == Karte.STELLUNG


func taste(code: int) -> void:
	if not visible:
		return
	var index := [KEY_Q, KEY_W, KEY_E].find(code)
	if index >= 0 and index < _truppen_knoepfe.size() and not _truppen_knoepfe[index].disabled:
		_truppen_knoepfe[index].pressed.emit()
	elif code == KEY_U and _upgrade_knopf != null and not _upgrade_knopf.disabled:
		_upgrade_knopf.pressed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not spiel.fabriken.has(zelle) and not _ist_turm(zelle) and not _ist_generator(zelle) and not _ist_mg(zelle):
		schliesse()
		return
	_baue()
	var neu := _stats_text()
	if neu != _stats:
		_stats = neu
	_setze_ort()
	queue_redraw()
	for k in get_children():
		(k as Control).queue_redraw()


# ------------------------------------------------------------------ Werte über die Partie

func _quelle() -> String:
	if spiel.karte.paar.has(zelle):
		var b: Vector2i = spiel.karte.paar[zelle]
		return "batterie:%d,%d" % [b.x, b.y]
	return "fabrik:%d,%d" % [zelle.x, zelle.y]


## Werte eines Turms, einer Batterie oder eines Generators über die ganze Partie (wie bei Bloons).
func _objekt_text(z: Vector2i) -> String:
	var s: Dictionary = spiel.objekt_stats.get(z, {})
	var teile: Array = []
	if float(s.get("schaden", 0.0)) > 0.0 or float(s.get("kills", 0.0)) > 0.0:
		teile.append("%d Schaden · %d Kills" % [roundi(float(s.get("schaden", 0.0))), int(s.get("kills", 0.0))])
	if s.has("gebremst"):
		teile.append("%d gebremst" % int(s["gebremst"]))
	if s.has("heilung"):
		teile.append("%d geheilt" % roundi(float(s["heilung"])))
	if s.has("gerettet"):
		teile.append("%d gerettet" % int(s["gerettet"]))
	if s.has("instand"):
		teile.append("%d instandgesetzt" % int(s["instand"]))
	if s.has("abgefangen"):
		teile.append("%d abgefangen" % roundi(float(s["abgefangen"])))
	if s.has("abgewehrt"):
		teile.append("%d Steine abgewehrt" % int(s["abgewehrt"]))
	return "Gesamt: " + (" · ".join(teile) if not teile.is_empty() else "noch nichts")


func _stats_text() -> String:
	if _ist_turm(zelle) or _ist_generator(zelle) or _ist_mg(zelle):
		return _objekt_text(zelle)
	var g: Dictionary = spiel.gesamt_stats.get(_quelle(), {})
	var text := "%d Truppen · %d Schaden · %d Kills" % [spiel.truppen_limit(zelle), roundi(float(g.get("schaden", 0.0))), int(g.get("kills", 0))]
	if spiel.karte.paar.has(zelle):
		var ab := float(spiel.objekt_stats.get(spiel.karte.paar[zelle], {}).get("abgefangen", 0.0))
		if ab > 0.0:
			text += " · Schild %d" % roundi(ab)
	return text


# ------------------------------------------------------------------ Aufbau

var _y := 0.0

func _leeren() -> void:
	for k in get_children():
		remove_child(k)
		k.queue_free()
	_truppen_knoepfe = []
	_upgrade_knopf = null
	_texte = []
	_y = PAD
	BREITE = BREITE_NORMAL


func _zeile(text: String, groesse: int, farbe: Color, weite: float = BREITE - 2.0 * PAD) -> void:
	if text == "":
		return
	var g := Stil.absatz_groesse(text, weite, groesse)
	_texte.append([Vector2(PAD, _y), text, groesse, farbe, weite])
	_y += ceilf(g.y) + 2.0


func _kopf(titel: String, stufe_text: String) -> void:
	_texte.append([Vector2(PAD, _y), titel, Stil.NORMAL, Color("ffe9a8"), BREITE])
	if stufe_text != "":
		_texte.append([Vector2(BREITE - PAD - Stil.breite(stufe_text, Stil.KLEIN), _y), stufe_text, Stil.KLEIN, Stil.LEUCHT, BREITE])
	_y += 12.0


func _stats_zeile() -> void:
	_stats_y = _y
	_stats = _stats_text()
	_y += 10.0


func _fertig() -> void:
	size = Vector2(BREITE, _y + PAD - 2.0)
	_setze_ort()
	queue_redraw()


## Reihe kleiner Schalter (Zielwahl, Truppenwahl). eintraege: [[Text, aktiv, Aktion, gesperrt]]
func _chips(titel: String, eintraege: Array, merken: bool = false) -> void:
	var x := PAD
	if titel != "":
		_texte.append([Vector2(PAD, _y + 1.0), titel, Stil.KLEIN, Stil.TEXT_BLASS, BREITE])
		x += Stil.breite(titel, Stil.KLEIN) + 4.0
	for e: Array in eintraege:
		var text: String = e[0]
		var aktiv: bool = e[1]
		var w := ceilf(Stil.breite(text, Stil.KLEIN)) + 8.0
		if x + w > BREITE - PAD:
			x = PAD
			_y += 14.0
		var b := Feld.new()
		Stil.leerer_knopf(b)
		b.position = Vector2(x, _y)
		b.size = Vector2(w, 12)
		b.disabled = e.size() > 3 and bool(e[3])
		if e[2] != null:
			b.pressed.connect(e[2])
		b.malen = func(ci: Button):
			var dr := ci.is_hovered() and not ci.disabled
			var rand := Stil.LEUCHT if aktiv else (Stil.RAHMEN_HELL if dr else Stil.RAHMEN)
			Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 2.0, Stil.METALL if (aktiv or dr) else Stil.METALL_DUNKEL, rand)
			var f := Stil.LEUCHT if aktiv else (Stil.TEXT if not ci.disabled else Stil.TEXT_BLASS.darkened(0.3))
			Stil.schreibe_mittig(ci, ci.size / 2.0, text, Stil.KLEIN, f)
		add_child(b)
		if merken:
			_truppen_knoepfe.append(b)
		x += w + 3.0
	_y += 15.0


## Ausbaupfad als Kette: erledigte Stufen cyan, die nächste hell, spätere blass.
func _pfad(namen: Array, erreicht: int) -> void:
	var x := PAD
	var y := _y
	for i in namen.size():
		var text: String = namen[i]
		var w := ceilf(Stil.breite(text, Stil.KLEIN)) + 6.0
		if x + w > BREITE - PAD:
			x = PAD
			y += 13.0
			_y += 13.0
		var r := Rect2(Vector2(x, y), Vector2(w, 10))
		var farbe := Stil.TEXT_BLASS.darkened(0.25)
		var rand := Stil.RAHMEN.darkened(0.2)
		if i < erreicht:
			farbe = Stil.LEUCHT
			rand = Stil.LEUCHT.darkened(0.35)
		elif i == erreicht:
			farbe = Stil.TEXT
			rand = Stil.RAHMEN_HELL
		_texte.append(["pfad", r, text, farbe, rand])
		x += w
		if i < namen.size() - 1:
			_texte.append([Vector2(x + 1.0, y + 0.5), "›", Stil.KLEIN, Stil.TEXT_BLASS, BREITE])
			x += 7.0
	_y += 14.0


## Karte für eine Ausbaustufe: Titel, Preis, Wirkung, ggf. Stärke/Schwäche. Ganze Karte = Knopf.
func _karte(rect: Rect2, titel: String, preis: int, text: String, stark: String, schwach: String,
		aktion: Variant, zahlbar: bool, gesperrt: bool, gewaehlt: bool = false) -> Button:
	stark = ""     # Stärken und Schwächen stehen künftig in der Übersicht [I] (Paul 16.11.: im Fenster zu viel)
	schwach = ""
	var b := Feld.new()
	Stil.leerer_knopf(b)
	b.position = rect.position
	b.size = rect.size
	b.disabled = gesperrt or aktion == null
	if aktion != null:
		b.pressed.connect(aktion)
	var innen := rect.size.x - 8.0
	b.malen = func(ci: Button):
		var dr := ci.is_hovered() and not ci.disabled
		var rand := Stil.RAHMEN
		if gewaehlt:
			rand = Stil.LEUCHT
		elif dr:
			rand = Stil.LEUCHT
		elif not ci.disabled and zahlbar:
			rand = Stil.GOLD.darkened(0.25)
		Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 3.0, Stil.METALL if dr else Stil.METALL_DUNKEL, rand)
		var y := 3.0
		Stil.schreibe(ci, Vector2(4, y + 4.0), titel, Stil.KLEIN, Stil.LEUCHT if (gewaehlt or dr) else Stil.TEXT)
		if preis > 0 and not gewaehlt:
			var p := str(preis)
			Stil.preisschild(ci, Vector2(ci.size.x - 4.0 - (Stil.breite(p, Stil.KLEIN) + 6.0) / 2.0, y + 4.0), p, Stil.GOLD if zahlbar else Stil.WARN)
		y += 10.0
		Stil.absatz(ci, Vector2(4, y), text, innen, Stil.KLEIN, Stil.TEXT if not ci.disabled or gewaehlt else Stil.TEXT_BLASS)
		y += ceilf(Stil.absatz_groesse(text, innen, Stil.KLEIN).y) + 1.0
		if stark != "":
			Stil.absatz(ci, Vector2(4, y), "+ " + stark, innen, Stil.KLEIN, Color("9be37b"))
			y += ceilf(Stil.absatz_groesse("+ " + stark, innen, Stil.KLEIN).y)
		if schwach != "":
			Stil.absatz(ci, Vector2(4, y), "– " + schwach, innen, Stil.KLEIN, Stil.WARN)
	add_child(b)
	return b


func _karten_hoehe(text: String, stark: String, schwach: String, w: float) -> float:
	stark = ""
	schwach = ""
	var innen := w - 8.0
	var h := 13.0 + ceilf(Stil.absatz_groesse(text, innen, Stil.KLEIN).y) + 1.0
	if stark != "":
		h += ceilf(Stil.absatz_groesse("+ " + stark, innen, Stil.KLEIN).y)
	if schwach != "":
		h += ceilf(Stil.absatz_groesse("– " + schwach, innen, Stil.KLEIN).y)
	return h + 4.0


## Eine Karte über die ganze Breite.
func _karte_breit(titel: String, preis: int, text: String, aktion: Variant, zahlbar: bool, gesperrt: bool, gewaehlt: bool = false,
		stark: String = "", schwach: String = "") -> Button:
	var w := BREITE - 2.0 * PAD
	var h := _karten_hoehe(text, stark, schwach, w)
	var b := _karte(Rect2(Vector2(PAD, _y), Vector2(w, h)), titel, preis, text, stark, schwach, aktion, zahlbar, gesperrt, gewaehlt)
	_y += h + ABSTAND
	return b


## Stufe 3: die Fähigkeiten nebeneinander (zwei oder drei). wahl: {kennung: {name, text, stark, schwach}}
func _faehigkeiten(wahl: Dictionary, preis: int, aktion: Callable, zahlbar: bool, gesperrt: bool) -> void:
	var n := wahl.size()
	var w := floorf((BREITE - 2.0 * PAD - ABSTAND * (n - 1)) / float(n))
	var h := 0.0
	for kennung: String in wahl:
		var e: Dictionary = wahl[kennung]
		h = maxf(h, _karten_hoehe(e["text"], e["stark"], e["schwach"], w))
	var x := PAD
	for kennung: String in wahl:
		var e: Dictionary = wahl[kennung]
		var b := _karte(Rect2(Vector2(x, _y), Vector2(w, h)), e["name"], preis, e["text"], e["stark"], e["schwach"],
			aktion.bind(zelle, kennung), zahlbar, gesperrt)
		_truppen_knoepfe.append(b)
		x += w + ABSTAND
	_y += h + ABSTAND


func _baue() -> void:
	if _ist_mg(zelle):
		_baue_mg()
	elif _ist_turm(zelle) and str(spiel.karte.turm_art.get(zelle, "")) == "pliplop":
		_baue_pliplop()
	elif _ist_turm(zelle):
		_baue_turm()
	elif _ist_generator(zelle):
		_baue_generator()
	elif spiel.fabriken.has(zelle):
		_baue_fabrik()


func _baue_generator() -> void:
	var offen: bool = spiel.karte.kuppeln.filter(func(k): return k[2] == zelle).is_empty()
	var hof: Array = spiel.karte.hof_von(zelle)
	var stufe := Werte.zitadelle_stufe(hof.size()) if not hof.is_empty() else 0
	var stand := "generator|%s|%d" % [offen, stufe]
	if stand == _stand:
		return
	_stand = stand
	_leeren()
	_kopf("Schildgenerator", "Zitadelle " + ["", "I", "II", "III"][stufe] if stufe > 0 else "")
	_stats_zeile()
	_zeile("Kuppel über der Zitadelle: Truppen darunter nehmen %d %% weniger Schaden, Steine prallen ab." % roundi(Werte.KUPPEL_SCHUTZ * 100), Stil.KLEIN, Stil.TEXT)
	if offen:
		_zeile("Kuppel aus: Der Ring ist offen.", Stil.KLEIN, Stil.WARN)
	elif stufe < 3:
		_zeile("Ausbauen: Ring eine Kachel weiter nach außen ziehen, alten Ring abreißen – die Kuppel wächst mit (Stufe III ab Welle %d)." % Werte.ZITADELLE_III_AB_WELLE, Stil.KLEIN, Stil.TEXT_BLASS)
	_fertig()


func _baue_fabrik() -> void:
	var f: Dictionary = spiel.fabriken[zelle]
	var stufe := int(f.get("stufe", 0))
	var bauphase: bool = spiel.ausbau_moeglich()   # Bauphase – oder die letzte Runde, dort geht Ausbauen auch während des Angriffs
	var preise: Array[int] = Werte.KOSTEN_BATTERIE_STUFE if f["typ"] == "pilot" else Werte.kosten_stufen()   # 19.11.: je Anführer
	var naechste := stufe < preise.size()
	var kann_zahlen: bool = naechste and spiel.budget >= preise[stufe]
	var stand := "%s|%d|%s|%s|%s|%s|%d|%d" % [f["typ"], stufe, bauphase, kann_zahlen, spiel.schilde.size(), f.get("ziel", "erste"), spiel.zugewiesen(zelle).size(), spiel.budget / 25]
	if stand == _stand:
		return
	_stand = stand
	_leeren()
	if stufe == 2 and f["typ"] != "pilot" and (Werte.STUFE_3[f["typ"]] as Dictionary).size() > 2:
		BREITE = BREITE_DREI
	if f["typ"] == "pilot":
		_baue_batterie(stufe, bauphase, naechste, kann_zahlen)
		_fertig()
		return
	var d: Dictionary = Werte.EINHEITEN[f["typ"]]
	_kopf("%s-Fabrik" % d["name"], "Stufe %d" % stufe)
	_stats_zeile()
	var ziel := str(f.get("ziel", "erste"))
	var zw: Array = []
	for m: Array in [["erste", "Erste"], ["letzte", "Letzte"], ["staerkste", "Stärkste"]]:
		zw.append([m[1], ziel == m[0], spiel.setze_zielmodus.bind(zelle, m[0])])
	_chips("Ziel", zw)
	var n_zu: int = spiel.zugewiesen(zelle).size()
	_zeile("Stellungen: frei (ziehen = zuweisen)" if n_zu == 0 else "Stellungen: %d zugewiesen" % n_zu, Stil.KLEIN, Stil.TEXT_BLASS)
	if stufe == 0:
		var tw: Array = []
		for typ: String in Werte.FABRIK_EINHEITEN:
			tw.append([str(Werte.EINHEITEN[typ]["name"]), typ == f["typ"], spiel.stelle_um.bind(zelle, typ), typ == f["typ"]])
		_chips("", tw, true)   # ohne Überschrift: passen so in eine Zeile
		if not bauphase:
			_zeile("In der Welle gilt das Umstellen für die nächste Truppe.", Stil.KLEIN, Stil.TEXT_BLASS)
	if Werte.fabrik_direkt_stufe_2():   # 20.11. (Paul): Sonde 7 – ohne Spezialisierung
		_pfad(["Grund", "Stufe 2", "Fähigkeit"] + (["Elite"] if Werte.fabrik_max_stufe() >= 4 else []), maxi(1, stufe))
	else:
		_pfad(["Grund", "Spezial", "Stufe 2", "Fähigkeit"] + (["Elite"] if Werte.fabrik_max_stufe() >= 4 else []), stufe + 1)   # 20.11.: Stufe 4
	if spiel.brakk_modus:
		# 18.11. (Paul): im Brakk-Mode keine Ausbauten – Truppe und Stufe kommen über Brakks Ringfelder
		var ring := str(f.get("ring", ""))
		_zeile("Im Feld des Rings: baut %s auf Stufe %d." % [d["name"], stufe] if ring != "" else "Brakk-Mode: keine Ausbauten. Ein Ringfeld (Lichtterminal an der Basis, [C] in der Bauphase) gibt Fabriken Truppe und Stufe.", Stil.KLEIN, Stil.LEUCHT)
	elif stufe == 0 and Werte.fabrik_direkt_stufe_2():
		# 20.11. (Paul): Sonde 7 – ohne Spezialisierung gleich auf Stufe 2
		var pd := Werte.preis_direkt_stufe_2()
		var zahlbar_d: bool = spiel.budget >= pd
		_upgrade_knopf = _karte_breit("Stufe 2", pd, "Bleibt bei %s. %s" % [d["name"], Werte.STUFE_2[f["typ"]]["text"]],
			spiel.werte_auf.bind(zelle), zahlbar_d, not bauphase or not zahlbar_d)
	elif stufe == 0:
		var spezial_text := "Bleibt bei %s und hält drei statt zwei Truppen. Umstellen geht danach nicht mehr."
		_upgrade_knopf = _karte_breit("Spezialisieren", preise[0], spezial_text % d["name"],
			spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
	elif stufe == 1:
		_upgrade_knopf = _karte_breit("Stufe 2", preise[1], Werte.STUFE_2[f["typ"]]["text"], spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
	elif stufe == 2:
		_faehigkeiten(Werte.STUFE_3[f["typ"]], preise[2], spiel.werte_auf, kann_zahlen, not bauphase or not kann_zahlen)
	else:
		var w3: Dictionary = Werte.STUFE_3[f["typ"]][str(f.get("faehigkeit", ""))]
		_karte_breit(w3["name"], 0, w3["text"], null, true, true, true, w3["stark"], w3["schwach"])
		if stufe == 3 and naechste:   # 20.11.: Stufe 4 – Elite (Sonde 7)
			_upgrade_knopf = _karte_breit("Elite", preise[3], "Die Truppe wird zur Elite: " + Werte.elite_text() + ", größer, golden.", spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
		elif stufe >= 4:
			_zeile("Elite: " + Werte.elite_text() + ".", Stil.KLEIN, Stil.GOLD)
	if naechste and not bauphase:
		_zeile("Ausbauen geht nur zwischen den Wellen.", Stil.KLEIN, Stil.TEXT_BLASS)
	_fertig()


## Turm: Stufe 2 fest, Stufe 3 eine von zwei Fähigkeiten (wie bei den Fabriken).
func _baue_turm() -> void:
	var k: Karte = spiel.karte
	var art: String = k.turm_art.get(zelle, "geschuetz")
	var stufe := int(k.turm_stufe.get(zelle, 1))
	var bauphase: bool = spiel.ausbau_moeglich()
	var preise: Array[int] = Werte.kosten_turm_stufen()   # 19.11.: Preise und höchste Stufe je Anführer
	var naechste := stufe < Werte.turm_max_stufe()
	var kann_zahlen: bool = naechste and spiel.budget >= preise[stufe - 1]
	var stand := "turm|%s|%d|%s|%s|%s" % [art, stufe, bauphase, kann_zahlen, k.turm_aktiv(zelle)]
	if stand == _stand:
		return
	_stand = stand
	_leeren()
	if stufe == 2 and (Werte.TURM_STUFE_3[art] as Dictionary).size() > 2:
		BREITE = BREITE_DREI
	var d: Dictionary = Werte.TURMARTEN[art]
	_kopf(str(d["name"]), "Stufe %d" % stufe)
	_zeile(d["text"], Stil.KLEIN, Stil.TEXT_BLASS)
	_stats_zeile()
	if not k.turm_aktiv(zelle):
		_zeile("Schweigt gerade: Stütze fehlt oder lahmgelegt.", Stil.KLEIN, Stil.WARN)
	_pfad(["Stufe 1", "Stufe 2", "Fähigkeit"] + (["Stufe 4"] if Werte.turm_max_stufe() >= 4 else []), stufe)   # 20.11.: Stufe 4
	if stufe == 1 and naechste:
		_upgrade_knopf = _karte_breit("Stufe 2", preise[0], Werte.TURM_STUFE_2[art]["text"], spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
	elif stufe == 2 and naechste:
		_zeile("Stufe 2: " + str(Werte.TURM_STUFE_2[art]["text"]), Stil.KLEIN, Stil.LEUCHT)
		_faehigkeiten(Werte.TURM_STUFE_3[art], preise[1], spiel.werte_auf, kann_zahlen, not bauphase or not kann_zahlen)
	elif stufe >= 2:
		_zeile("Stufe 2: " + str(Werte.TURM_STUFE_2[art]["text"]), Stil.KLEIN, Stil.LEUCHT)
		var w3: Dictionary = Werte.TURM_STUFE_3[art].get(str(k.turm_faehigkeit.get(zelle, "")), {})
		if not w3.is_empty():
			_karte_breit(w3["name"], 0, w3["text"], null, true, true, true, w3["stark"], w3["schwach"])
		if stufe == 3 and naechste:   # 20.11.: Stufe 4 – großes Wertepaket (Irrtürmer)
			_upgrade_knopf = _karte_breit("Stufe 4", preise[2], Werte.turm4_text() + ", hält doppelt so viel gegen Drohnen aus.", spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
		elif stufe >= 4:
			_zeile("Stufe 4: " + Werte.turm4_text() + ".", Stil.KLEIN, Stil.GOLD)
	if naechste and not bauphase:
		_zeile("Ausbauen geht nur zwischen den Wellen.", Stil.KLEIN, Stil.TEXT_BLASS)
	_fertig()


## 20.11. (Paul): MG-Stellung (Sonde 7) – Ausbau am Nest. Stufe 1 und 2 je eine von zwei Richtungen, Stufe 3 die
## Sonderform, die aus beiden folgt. Die Truppe darin ist nur Besatzung.
func _baue_mg() -> void:
	var k: Karte = spiel.karte
	var stufe := int(k.mg_stufe.get(zelle, 0))
	var wahl: Array = k.mg_wahl.get(zelle, [])
	var bauphase: bool = spiel.ausbau_moeglich()
	var naechste := stufe < 3
	var preis: int = Werte.KOSTEN_MG_STUFE[stufe] if naechste else 0
	var kann_zahlen: bool = naechste and spiel.budget >= preis
	var besetzt: bool = k.posten.has(zelle)
	var stand := "mg|%d|%s|%s|%s|%s" % [stufe, "|".join(PackedStringArray(wahl)), bauphase, kann_zahlen, besetzt]
	if stand == _stand:
		return
	_stand = stand
	_leeren()
	var w := Werte.mg_werte(stufe, wahl)
	_kopf("MG-Stellung", "Stufe %d" % stufe)
	_zeile("Schaden %s alle %s s · Reichweite %s. Die Werte hängen am Nest – jede Truppe darin schießt so." % [
		str(snappedf(float(w["schaden"]), 0.1)).replace(".", ","), str(snappedf(float(w["abklingzeit"]), 0.01)).replace(".", ","),
		str(snappedf(float(spiel.mg_reichweite(zelle)), 0.1)).replace(".", ",")], Stil.KLEIN, Stil.TEXT_BLASS)
	if not besetzt:
		_zeile("Unbesetzt: Eine Truppe aus einer Fabrik muss hinauf.", Stil.KLEIN, Stil.WARN)
	_stats_zeile()
	var namen: Array = ["Nest"]
	for i in 3:
		var n := "Stufe %d" % (i + 1) if i < 2 else "Sonder"
		if i < wahl.size():
			var quelle: Dictionary = Werte.MG_AUSBAU[i] if i < 2 else Werte.mg_sonder_wahl(wahl)
			n = str(quelle.get(str(wahl[i]), {}).get("name", n)).split(" ")[0]
		namen.append(n)
	_pfad(namen, stufe + 1)
	for i in wahl.size():
		var q: Dictionary = Werte.MG_AUSBAU[i] if i < 2 else Werte.mg_sonder_wahl(wahl)
		var e: Dictionary = q.get(str(wahl[i]), {})
		if not e.is_empty():
			_zeile("%s: %s" % [e["name"], e["text"]], Stil.KLEIN, Stil.GOLD if i == 2 else Stil.LEUCHT)
	if naechste:
		var auswahl: Dictionary = Werte.MG_AUSBAU[stufe] if stufe < 2 else Werte.mg_sonder_wahl(wahl)
		_faehigkeiten(auswahl, preis, spiel.werte_auf, kann_zahlen, not bauphase or not kann_zahlen)
		if not bauphase:
			_zeile("Ausbauen geht nur zwischen den Wellen.", Stil.KLEIN, Stil.TEXT_BLASS)
	_fertig()


## 20.11. (Paul): PliPlop 3cK (Irrtürmer) – Stufe 2 wählt den Pfad (Flak, Schockwelle, Nagler), Stufe 3 und 4 verstärken ihn.
func _baue_pliplop() -> void:
	var k: Karte = spiel.karte
	var stufe := int(k.turm_stufe.get(zelle, 1))
	var pfad := str(k.turm_faehigkeit.get(zelle, ""))
	var bauphase: bool = spiel.ausbau_moeglich()
	var preise: Array[int] = Werte.kosten_pliplop_stufen()
	var naechste := stufe < 4
	var kann_zahlen: bool = naechste and spiel.budget >= preise[stufe - 1]
	var stand := "pp|%d|%s|%s|%s|%s" % [stufe, pfad, bauphase, kann_zahlen, k.turm_aktiv(zelle)]
	if stand == _stand:
		return
	_stand = stand
	_leeren()
	if stufe == 1:
		BREITE = BREITE_DREI
	var d: Dictionary = Werte.TURMARTEN["pliplop"]
	_kopf(str(d["name"]), "Stufe %d" % stufe)
	_zeile("Schaden %s alle %s s · Reichweite %s" % [str(snappedf(float(k.turm_wert(zelle, "schaden")), 0.1)).replace(".", ","),
		str(snappedf(float(k.turm_wert(zelle, "abklingzeit")), 0.01)).replace(".", ","), str(snappedf(float(k.turm_wert(zelle, "reichweite")), 0.1)).replace(".", ",")] \
		if pfad != "schockwelle" else "Kein Schaden · alle %s s · Reichweite %s" % [str(snappedf(float(k.turm_wert(zelle, "abklingzeit")), 0.01)).replace(".", ","),
		str(snappedf(float(k.turm_wert(zelle, "reichweite")), 0.1)).replace(".", ",")], Stil.KLEIN, Stil.TEXT_BLASS)
	_stats_zeile()
	if not k.turm_aktiv(zelle):
		_zeile("Schweigt gerade: lahmgelegt.", Stil.KLEIN, Stil.WARN)
	var p: Dictionary = Werte.PLIPLOP_TURM.get(pfad, {})
	_pfad(["Grund", str(p.get("name", "Pfad")), "Stufe 3", "Stufe 4"], stufe)
	if stufe == 1:
		var wahl := {}
		for name: String in Werte.PLIPLOP_TURM:
			var e: Dictionary = Werte.PLIPLOP_TURM[name]
			wahl[name] = {"name": e["name"], "text": "%s %s" % [e["text"], e["stufen"][0]["text"]], "stark": e["stark"], "schwach": e["schwach"]}
		_faehigkeiten(wahl, preise[0], spiel.werte_auf, kann_zahlen, not bauphase or not kann_zahlen)
	else:
		_zeile("%s: %s" % [p["name"], p["text"]], Stil.KLEIN, Stil.LEUCHT)
		_zeile("Jetzt: " + str(p["stufen"][stufe - 2]["text"]), Stil.KLEIN, Stil.GOLD if stufe >= 4 else Stil.LEUCHT)
		if naechste:
			_upgrade_knopf = _karte_breit("Stufe %d" % (stufe + 1), preise[stufe - 1], str(p["stufen"][stufe - 1]["text"]),
				spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
	if naechste and not bauphase:
		_zeile("Ausbauen geht nur zwischen den Wellen.", Stil.KLEIN, Stil.TEXT_BLASS)
	_fertig()


## Batterie mit Pilotenfabrik: feste Stufen statt Truppenwahl.
func _baue_batterie(stufe: int, bauphase: bool, naechste: bool, kann_zahlen: bool) -> void:
	_kopf("Batterie", "Stufe %d" % stufe)
	_zeile("%d Piloten, %d bemannen sie" % [spiel.truppen_limit(zelle), int(Werte.BATTERIE["plaetze"])], Stil.KLEIN, Stil.TEXT_BLASS)
	_stats_zeile()
	var ziel := str(spiel.fabriken.get(zelle, {}).get("ziel", "dichteste"))
	var zw: Array = []
	for m: Array in [["dichteste", "Gruppe"], ["erste", "Erste"], ["letzte", "Letzte"], ["staerkste", "Stärkste"]]:
		zw.append([m[1], ziel == m[0], spiel.setze_zielmodus.bind(zelle, m[0])])
	_chips("Ziel", zw)
	var namen: Array = ["Basis"]
	for s: Dictionary in Werte.BATTERIE_STUFEN:
		namen.append(str(s["name"]).split(" ")[-1])
	_pfad(namen, stufe + 1)
	if naechste:
		var s: Dictionary = Werte.BATTERIE_STUFEN[stufe]
		_upgrade_knopf = _karte_breit("Stufe %d: %s" % [stufe + 1, s["name"]], Werte.KOSTEN_BATTERIE_STUFE[stufe], s["text"],
			spiel.werte_auf.bind(zelle), kann_zahlen, not bauphase or not kann_zahlen)
		if not bauphase:
			_zeile("Ausbauen geht nur zwischen den Wellen.", Stil.KLEIN, Stil.TEXT_BLASS)
	else:
		var hat: bool = spiel.schilde.has(spiel.karte.paar[zelle])
		var b := _karte_breit("Schild %s" % ("neu ziehen" if hat else "ziehen"), 0,
			"Von Erdwall zu Erdwall, gerade. Steht nur, solange die Batterie voll bemannt und nicht ausgefallen ist.",
			spiel.waehle_schildfeld.bind(zelle), true, not bauphase)
		_truppen_knoepfe.append(b)


# ------------------------------------------------------------------ Lage und Zeichnen

## Reichweite des Gebäudes in Feldern (für den Abstand; 0 = keine).
func _reichweite() -> float:
	if _ist_mg(zelle):
		return float(spiel.mg_reichweite(zelle))
	if _ist_turm(zelle):
		return float(spiel.karte.turm_wert(zelle, "reichweite"))
	if spiel.karte.paar.has(zelle):
		return float(Werte.BATTERIE["reichweite"])
	return 0.0


## Neben das Gebäude setzen – außerhalb seiner Reichweite, wenn es passt, sonst daneben; nie aus dem Bild.
func _setze_ort() -> void:
	if zelle == Karte.KEINE:
		return
	var sk := scale.x
	var mitte_welt: Vector2 = spiel.karte.mitte(zelle)
	var m: Vector2 = spiel.welt_zu_bild(mitte_welt)            # Spielfenster-Koordinaten (1280×720)
	var r_welt := maxf(_reichweite(), 0.6) * Werte.ZELLE
	var r: float = absf((spiel.welt_zu_bild(mitte_welt + Vector2(r_welt, 0)) as Vector2).x - m.x)
	var w := size.x * sk
	var h := size.y * sk
	var oben := 80.0      # unter den Inseln oben
	var unten := 620.0    # über der Konsole
	var y := clampf(m.y - h * 0.35, oben, unten - h)
	var ort := Vector2.ZERO
	var rechts := m.x + r + 16.0
	var links := m.x - r - 16.0 - w
	var rand_r := 1226.0   # rechts bleibt der Zoomregler frei
	if rechts + w <= rand_r:
		ort = Vector2(rechts, y)
	elif links >= 10.0:
		ort = Vector2(links, y)
	else:
		# passt nicht neben die Reichweite: dicht daneben auf der Seite mit mehr Platz
		ort = Vector2(m.x + 40.0, y) if m.x < 640.0 else Vector2(m.x - 40.0 - w, y)
	ort.x = clampf(ort.x, 10.0, rand_r - w)
	position = ort.round()
	_anker = (m - position) / sk


func _draw() -> void:
	if size.x < 10.0:
		return
	# Haltelinie zum Gebäude (von der nächsten Kante der Tafel)
	var kante := Vector2(clampf(_anker.x, 0.0, size.x), clampf(_anker.y, 6.0, size.y - 6.0))
	if _anker.x < 0.0 or _anker.x > size.x:
		var punkte := PackedVector2Array([kante, Vector2(lerpf(kante.x, _anker.x, 0.5), kante.y), _anker])
		draw_polyline(punkte, Color(Stil.LEUCHT, 0.7), 1.0)
		draw_rect(Rect2(_anker - Vector2(1.5, 1.5), Vector2(3, 3)), Stil.LEUCHT)
	Stil.platte(self, Rect2(Vector2.ZERO, size), 5.0)
	draw_rect(Rect2(Vector2(8, 2), Vector2(size.x - 16.0, 1)), Stil.LEUCHT)
	for t: Array in _texte:
		if t[0] is String and t[0] == "pfad":
			var r: Rect2 = t[1]
			Stil.platte(self, r, 2.0, Stil.METALL_DUNKEL, t[4])
			Stil.schreibe_mittig(self, r.get_center(), t[2], Stil.KLEIN, t[3])
		elif t[2] == Stil.NORMAL and t[4] == BREITE:
			Stil.schreibe(self, t[0] + Vector2(0, 5), t[1], t[2], t[3])
		else:
			Stil.absatz(self, t[0], t[1], t[4], t[2], t[3])
	if _stats != "":
		Stil.absatz(self, Vector2(PAD, _stats_y), _stats, BREITE - 2.0 * PAD, Stil.KLEIN, Stil.GOLD)
