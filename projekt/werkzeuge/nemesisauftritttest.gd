extends SceneTree
## 25.11. (Paul): „Nemesis lesbar machen“ im laufenden Befehl 24 – Auftritt, Beförderung, Vertreibung.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/nemesisauftritttest.gd
##
## Punkt 1: je Benanntem im Elitetrupp eine Tafel, nacheinander (2,5 s + 1 s Pause), „Elitetrupp“ kurz in der
## Phasenzeile; Namenlose bekommen keine Tafel und keinen Look. Am Ende „TEST NEMESISAUFTRITT OK“ oder die Fehler.

var spiel: Node
var o: Order24
var n: Nemesis
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_auftritt_test.json"
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	r["geheim_ab"] = 0
	r["welle_takt"] = 9999   # Wellen nur, wenn der Test sie auslöst
	r["elite_jede"] = 1
	r["flucht_sek"] = 0
	r["jagd_start"] = 0
	r["vorstoss"] = false
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _weiter() -> void:
	schritt += 1
	merk["t"] = o.zeit


func _seit() -> float:
	return o.zeit - float(merk.get("t", o.zeit))


func _tafeln(art: String) -> Array:
	return o.tafeln.protokoll.filter(func(t: Dictionary) -> bool: return str(t["art"]) == art)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	if not o.laeuft and schritt < 7:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	n = o.nemesis
	var k: Kommandant = spiel.kommandant
	if k != null:
		k.leben = k.max_leben
	match schritt:
		0:
			if o.zeit > 2.0:
				o.tafeln.leeren()
				o.tafeln.protokoll.clear()
				_weiter()
		1:
			_punkt1_start()
			_weiter()
		2:
			if _seit() > 1.0 and not merk.has("phase1"):
				merk["phase1"] = o.phase_text()
			if o.tafeln.aktuell.is_empty() and o.tafeln.warten.is_empty() and _seit() > 7.0:
				_punkt1_ende()
				_weiter()
		3:
			_punkt2_start()
			_weiter()
		4:
			if _seit() > 0.2 and not merk.has("tempo"):
				merk["tempo"] = Engine.time_scale
				merk["sonde_frueh"] = _sonde_gemeldet()
			if o.tafeln.aktuell.is_empty() and _seit() > Werte.NEMESIS_BEFOERDERUNG_SEK + 0.3:
				_punkt2_ende()
				_weiter()
		5:
			_punkt3_start()
			_weiter()
		6:
			_punkt3_laeuft()
			if _seit() > Werte.NEMESIS_BERGUNG_SEK + 0.4:
				_punkt3_ende()
				_weiter()
		7:
			_punkt7_start()
			schritt = 8
			merk["bilder"] = 0
		8:
			merk["bilder"] = int(merk["bilder"]) + 1
			if int(merk["bilder"]) > 20:
				_punkt7_ende()
				return _fertig()
	if o.vorbei and schritt < 7:
		pruefe(false, "Lauf vorzeitig vorbei")
		return _fertig()
	return false


func _punkt1_start() -> void:
	var benannte := n.benannte()
	merk["benannte"] = benannte.size()
	o.wellen = 1
	o._jagdwelle()
	var namenlos: Einheit = null
	var benannt: Einheit = null
	for id: int in n._person_von:
		var e: Variant = instance_from_id(id)
		if e is Einheit:
			if Nemesis.benannt(n._person_von[id] as Dictionary):
				benannt = e
			elif bool((e as Einheit).daten.get("elite", false)):
				namenlos = e
	pruefe(benannt != null and benannt._sprite.has_meta("nemesis_look"), "Benannte Elite trägt ihren Look")
	var rein := o._neue_truppe("technogunner", o.fabrik_hp.keys()[0], 4)
	n.einkleiden(rein, n.neue_person("technogunner"))
	pruefe(not rein._sprite.has_meta("nemesis_look"), "Namenlose Elite hat keinen Look")


func _punkt1_ende() -> void:
	var t := _tafeln("elite")
	pruefe(t.size() == int(merk["benannte"]) and t.size() >= 2, "eine Tafel je Benanntem (%d Tafeln, %d Benannte)" % [t.size(), int(merk["benannte"])])
	var abstaende := PackedStringArray()
	var gut := true
	for i in range(1, t.size()):
		var d := float(t[i]["bei"]) - float(t[i - 1]["bei"])
		abstaende.append("%.2f" % d)
		gut = gut and absf(d - (Werte.NEMESIS_TAFEL_SEK + Werte.NEMESIS_TAFEL_PAUSE)) < 0.15
	pruefe(gut, "nacheinander: 2,5 s Tafel + 1 s Pause (Abstände %s)" % ", ".join(abstaende))
	pruefe(t.all(func(x: Dictionary) -> bool: return str(x["titel"]).contains("‚")), "Tafeltitel: Dienstgrad, Name, Beiname – z. B. %s" % (str(t[0]["titel"]) if not t.is_empty() else "–"))
	pruefe(str(merk.get("phase1", "")).contains("Elitetrupp"), "Phasenzeile beim Auftritt: %s" % str(merk.get("phase1", "")))
	pruefe(not o.phase_text().contains("Elitetrupp"), "Phasenzeile danach wieder normal: %s" % o.phase_text())


func _fertig() -> bool:
	Nemesis.zuruecksetzen()
	if fehler.is_empty():
		print("TEST NEMESISAUFTRITT OK")
	else:
		print("TEST NEMESISAUFTRITT FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


# ------------------------------------------------------------------ Punkt 2: Feldbeförderung sichtbar

func _sonde_gemeldet() -> bool:
	var text := str(spiel.get("_meldung"))
	return text.contains("Sonde 7") and text.contains(str(merk.get("befoerdert", "?")))


func _punkt2_start() -> void:
	var k: Kommandant = spiel.kommandant
	var blick := Vector2(-sin(spiel.ego.gier), -cos(spiel.ego.gier))
	var e := o._neue_truppe("technogunner", o.fabrik_hp.keys()[0], 1)
	e.position = k.position + blick * 3.0 * Werte.ZELLE
	e._punkte.clear()
	merk["einheit"] = e
	merk["tempo_vorher"] = Engine.time_scale
	merk.erase("tempo")
	n.feld_n = 0
	var ok := n.befoerdern(e, "sprengung")
	var p := n.person_von(e)
	merk["befoerdert"] = Nemesis.voller_name(p)
	pruefe(ok and e._sprite.has_meta("nemesis_look") and e.get_node_or_null("Rang") != null, "befördert: %s mit Look und Rangwinkel" % str(merk["befoerdert"]))


func _punkt2_ende() -> void:
	var t := _tafeln("befoerderung")
	pruefe(t.size() == 1 and str(t[0]["titel"]) == "Feldbeförderung: %s" % str(merk["befoerdert"]), "Tafel: %s" % (str(t[0]["titel"]) if not t.is_empty() else "keine"))
	var p := n.person_von(merk["einheit"] as Einheit)
	pruefe(Nemesis.tat_satz(str(p["name"]), "sprengung") == "%s hat Brakks Sprengladung überlebt." % str(p["name"]), "die Tat als Satz")
	pruefe(float(merk.get("tempo", 99.0)) < float(merk["tempo_vorher"]) * 0.6, "Zeitlupe: Spieltempo %.2f statt %.2f" % [float(merk.get("tempo", 99.0)), float(merk["tempo_vorher"])])
	pruefe(absf(Engine.time_scale - float(merk["tempo_vorher"])) < 0.01, "danach wieder normal (%.2f)" % Engine.time_scale)
	pruefe(not bool(merk.get("sonde_frueh", true)), "Sonde 7 meldet sich nicht während der Tafel")
	pruefe(_sonde_gemeldet(), "… sondern danach")
	var karte := Nemesis.lexikon_karte()
	var zeilen: Array = (karte["abschnitte"] as Array)[0][2]
	pruefe(zeilen.size() == 7 and str(zeilen[3]).contains("Med-Kit") and str(zeilen[3]).contains("Sprengladung") and str(zeilen[3]).contains("Sabotieren"), "Lexikon: sieben Auslöser")
	for grund: String in Nemesis.TAT_TEXT:
		if grund != "garantie" and not str(zeilen).contains(str(Nemesis.TAT_TEXT[grund])):
			pruefe(false, "Lexikon: Auslöser „%s“ fehlt" % grund)


# ------------------------------------------------------------------ Punkt 3: Vertreibung, Bergung, Versetzung

func _punkt3_start() -> void:
	var k: Kommandant = spiel.kommandant
	var blick := Vector2(-sin(spiel.ego.gier), -cos(spiel.ego.gier))
	var e := o._neue_truppe("scharfschuetze", o.fabrik_hp.keys()[0], 4)
	e.position = k.position + blick * 5.0 * Werte.ZELLE
	e._punkte.clear()
	n.einkleiden(e, n.neue_person("scharfschuetze", 2, "Quill", "Falkenauge"))
	o.tafeln.leeren()
	merk["bergung"] = e
	merk["id"] = e.get_instance_id()
	merk["rauch"] = n.rauchreste
	merk["groesse"] = 1.0
	merk["hub"] = 0.0
	merk["saeule"] = 0.0
	merk["hinweis"] = false
	e.nimm_schaden(999999.0)
	var hinweise := n.bergung_hinweise()
	merk["hinweis"] = hinweise.size() == 1 and str(hinweise[0]["name"]).contains("Quill")


func _punkt3_laeuft() -> void:
	var x: Variant = instance_from_id(int(merk["id"]))
	if x is Einheit and is_instance_valid(x):
		var e := x as Einheit
		var groesse: float = e._sprite.scale.x
		if not merk.has("voll"):
			merk["voll"] = groesse
		merk["groesse"] = minf(float(merk["groesse"]) if float(merk["groesse"]) != 1.0 else groesse, groesse)
		merk["hub"] = maxf(float(merk["hub"]), float(e.get_meta("hebt_ab", 0.0)))
	var s: Variant = n._beam_bilder.get(int(merk["id"]))
	if s != null and is_instance_valid(s):
		merk["saeule"] = maxf(float(merk["saeule"]), (s as MeshInstance3D).scale.y)


func _punkt3_ende() -> void:
	var t := _tafeln("vertrieben")
	pruefe(t.size() >= 1 and str(t.back()["titel"]).ends_with("vertrieben (1.)") and str(t.back()["titel"]).contains("Quill"), "Tafel: %s" % (str(t.back()["titel"]) if not t.is_empty() else "keine"))
	pruefe(bool(merk["hinweis"]), "Ausschalten-Hinweis für den entfernten Benannten")
	pruefe(float(merk["hub"]) > Werte.NEMESIS_BEAM_HUB * 0.8, "Figur hebt ab (%.2f Felder)" % float(merk["hub"]))
	pruefe(float(merk["groesse"]) < float(merk.get("voll", 1.0)) * 0.65, "Figur schrumpft (%.2f → %.2f)" % [float(merk.get("voll", 0.0)), float(merk["groesse"])])
	if spiel.hd != null:
		pruefe(float(merk["saeule"]) > 3.0, "Lichtsäule wächst von unten (bis %.1f Felder)" % float(merk["saeule"]))
		pruefe(n.rauchreste == int(merk["rauch"]) + 1, "danach ein Rauchrest")
	pruefe(not is_instance_id_valid(int(merk["id"])) and not n._beam_bilder.has(int(merk["id"])), "geborgen, Säule weg")
	# Versetzung: volle Liste, ein Neuer rückt nach
	n.personen = []
	for i in Werte.NEMESIS_LISTE_MAX:
		var alt := n.neue_person("technogunner", 2, "Alt%d" % i, "der Rest")
		(alt["bilanz"] as Dictionary)["er"] = i + 1
	var neu := n.neue_person("plasmawerfer", 1, "Frisch", "der Neue")
	(neu["lauf"] as Dictionary)["neu"] = true
	n.versetzt = []
	n._verdraengen()
	var zeile: Array = []
	for z: Array in n.lauf_liste():
		if str(z[1]) == "versetzt":
			zeile = z
	pruefe(n.versetzt.size() == 1 and not zeile.is_empty() and str(zeile[2]).contains("Frisch"), "versetzt mit Nachfolger")
	if not zeile.is_empty():
		var satz := Nemesis.versetzt_satz(str(zeile[0]), str(zeile[2]))
		pruefe(satz == "Hauptgefreiter Alt0 ‚der Rest‘ versetzt – Gefreiter Frisch ‚der Neue‘ nimmt seinen Platz in der Liste", satz)


# ------------------------------------------------------------------ Punkt 7: der Bericht erklärt sich

func _punkt7_start() -> void:
	o._ende(false)
	var tafel: BrakkSieg = null
	for k: Node in _alle(root):
		if k is BrakkSieg:
			tafel = k
	if tafel == null:   # die Ego-Sicht zeigt ihn selbst – dann bauen wir die Tafel wie order24
		tafel = BrakkSieg.new()
		tafel.spiel = spiel
		tafel.bericht = o.bericht(false)
		root.add_child(tafel)
	tafel._tod_gesehen = true
	tafel.queue_redraw()
	merk["tafel"] = tafel


func _alle(n_: Node) -> Array:
	var aus: Array = [n_]
	for k: Node in n_.get_children():
		aus.append_array(_alle(k))
	return aus


func _punkt7_ende() -> void:
	var tafel: BrakkSieg = merk["tafel"]
	var namen: Array = tafel.knoepfe().map(func(k: Array) -> String: return str(k[1]))
	pruefe(namen == ["Nochmal", "Zum Hangar", "Hauptmenü"], "Knöpfe: %s" % ", ".join(PackedStringArray(namen)))
	var zeilen: Array = tafel.bericht.get("nemesis", [])
	pruefe(not zeilen.is_empty() and not tafel._marken.is_empty(), "Zeilen bei „Eliten dieses Laufs“ sind wählbar (%d von %d gezeigt)" % [tafel._marken.size(), zeilen.size()])
	for art: String in ["befoerdert", "vertrieben", "ausgeschaltet", "versetzt"]:
		var e := BrakkSieg.erklaerung(["Gefreiter Test", art, "hat Brakk am Med-Kit erwischt" if art == "befoerdert" else ""])
		pruefe(str(e[1]).to_lower().begins_with({"befoerdert": "befördert", "vertrieben": "vertrieben", "ausgeschaltet": "ausgeschaltet", "versetzt": "versetzt"}[art]), "Erklärung %s: %s" % [art, str(e[1])])
	if not tafel._marken.is_empty():
		var klick := InputEventMouseButton.new()
		klick.button_index = MOUSE_BUTTON_LEFT
		klick.pressed = true
		klick.position = ((tafel._marken[0] as Array)[0] as Rect2).get_center()
		tafel._gui_input(klick)
		pruefe(tafel._zeile == 0, "Antippen wählt die Zeile")
		klick.position = (tafel.knoepfe()[1][0] as Rect2).get_center()
		tafel._gui_input(klick)
		var hangar: Hangar = null
		for k: Node in tafel.get_children():
			if k is Hangar:
				hangar = k
		pruefe(hangar != null and not hangar.figuren.is_empty(), "„Zum Hangar“ öffnet den Hangar (%d Figuren)" % (hangar.figuren.size() if hangar != null else 0))
