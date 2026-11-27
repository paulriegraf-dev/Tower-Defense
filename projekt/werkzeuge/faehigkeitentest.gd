extends SceneTree
## 22.11. (Paul, Nemesis Teil 3): Fähigkeiten der Benannten headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/faehigkeitentest.gd -- [Versuche je Fall]
##
## Brakks Lage steuert der Test (BrakkGeschosse.ziel_fn wie im Ausweichtest), Treffer zählt treffer_fn. Je Fähigkeit:
## löst aus · kündigt sich an (erster Schaden frühestens nach der Ankündigung) · Trefferquote stehend gegen Konter
## (Tumble, Sprung, Stellungswechsel, Ladestrahl). Dazu: Brakk im Kegel langsamer, Markierung macht ihn bekannt,
## Abklingzeit sinkt mit dem Rang, ab Rang 3 beide Fähigkeiten, „bereit“-Regeln (Sicht, ein Wall dazwischen).
## Am Ende „TEST FAEHIGKEITEN OK“ oder die Fehler. Schreibt wie das Spiel in user:// – vorher sichern.

const DT := 1.0 / 60.0
var spiel: Node
var o: Order24
var n: Nemesis
var fa: NemesisFaehigkeiten
var bg: BrakkGeschosse
var warte := 10
var fertig := false
var fehler: Array[String] = []
var lage := {}
var treffer := 0
var erster_treffer := -1.0
var versuche := 10
var uhr := 0.0
var offen := Vector2i(-1, -1)    # 10 freie Felder in einer Zeile
var wall := Vector2i(-1, -1)     # Erdwall mit je 3 freien Feldern links und rechts


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		versuche = int(a[0])
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	r["ueberleben_sek"] = 0
	r["geheim_ab"] = 0
	r["welle_takt"] = 9999
	r["flucht_sek"] = 0
	r["jagd_start"] = 9999
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


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.anzeige.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	if fertig:
		return true
	n = o.nemesis
	fa = n.faehigkeiten
	bg = spiel.brakk_geschosse
	fa.auto = false
	bg.ziel_fn = func() -> Dictionary: return lage
	bg.treffer_fn = func(_menge: float, _typ: String) -> void:
		treffer += 1
		if erster_treffer < 0.0:
			erster_treffer = uhr
	_orte_suchen()
	_regeln()
	_unterdrueckung()
	_sturmlauf()
	_markierung()
	_durchschuss()
	_sperrbrand()
	_ausraeuchern()
	bg.ziel_fn = Callable()
	bg.treffer_fn = Callable()
	for f: String in fehler:
		print("FEHLER: " + f)
	print("TEST FAEHIGKEITEN OK" if fehler.is_empty() else "TEST FAEHIGKEITEN FEHLER (%d)" % fehler.size())
	fertig = true
	return true


func _frei(z: Vector2i) -> bool:
	var k := o.karte
	return k.in_karte(z) and z.x >= Werte.ZONE_SPALTEN and k.ist_begehbar(z) and k.ist_frei(z) and k.inhalt(z) != Karte.WALL and not o._im_schild(k.mitte(z))


func _orte_suchen() -> void:
	for y in range(2, Werte.ZEILEN - 2):
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN - 10):
			if offen.x < 0:
				var ok := true
				for i in 10:
					ok = ok and _frei(Vector2i(x + i, y))
				if ok:
					offen = Vector2i(x, y)
			if wall.x < 0 and o.karte.inhalt(Vector2i(x + 3, y)) == Karte.WALL:
				var ok2 := true
				for i: int in [0, 1, 2, 4, 5, 6]:
					ok2 = ok2 and _frei(Vector2i(x + i, y))
				if ok2:
					wall = Vector2i(x + 3, y)
	pruefe(offen.x >= 0 and wall.x >= 0, "Testorte gefunden: freie Zeile ab %s, Erdwall %s" % [str(offen), str(wall)])


## Einheit mit Person und Fähigkeit `f` an `zelle`.
func schuetze(art: String, f: String, zelle: Vector2i, rang: int = 1) -> Einheit:
	var e := o._neue_truppe(art, o.fabrik_hp.keys()[0], 1)
	e.position = o.karte.mitte(zelle)
	e._punkte.clear()
	var p := n.neue_person(art, rang, "Test", "Prüfling")
	p["faehigkeit"] = f
	n.einkleiden(e, p)
	return e


func weg(e: Einheit) -> void:
	if is_instance_valid(e):
		n._wegbeamen(e)


func brakk(p: Vector2, v: Vector2 = Vector2.ZERO, durchlass: bool = false, sprung: float = 0.0) -> void:
	lage = {"pos": p, "sprung": sprung, "fuss": sprung, "durchlass": durchlass, "v": v}


## Ein Versuch: auslösen und laufen lassen; `bewegen(t)` verändert Brakks Lage. Gibt {"treffer", "erster", "abgefeuert", "getroffen"} zurück.
func versuch(e: Einheit, f: String, dauer: float, bewegen: Callable) -> Dictionary:
	treffer = 0
	erster_treffer = -1.0
	uhr = 0.0
	var ab := bg.abgefeuert
	var gt := bg.getroffen
	fa.ausloesen(e, f)
	while uhr < dauer:
		bewegen.call(uhr)
		fa.weiter(DT)
		bg.weiter(DT)
		uhr += DT
	var aus := {"treffer": treffer, "erster": erster_treffer, "abgefeuert": bg.abgefeuert - ab, "getroffen": bg.getroffen - gt}
	bg.leeren()
	return aus


## n Versuche je Fall; `ein_fall(steh: bool) -> Dictionary` führt einen Versuch aus. Quote = Anteil mit Treffer.
func quoten(f: String, ein_fall: Callable, ank: float, konter: String) -> Array:
	var q := [0.0, 0.0]
	var ank_ok := true
	for k in 2:
		var mit := 0
		for i in versuche:
			var r: Dictionary = ein_fall.call(k == 0)
			if int(r["treffer"]) > 0:
				mit += 1
				if float(r["erster"]) < ank - 0.02:
					ank_ok = false
		q[k] = float(mit) / versuche
	print("     %-20s stehend %3d %%   %-34s %3d %%" % [NemesisFaehigkeiten.name_von(f), roundi(q[0] * 100.0), konter, roundi(q[1] * 100.0)])
	pruefe(ank_ok, "%s: erster Schaden erst nach der Ankündigung (%.1f s)" % [NemesisFaehigkeiten.name_von(f), ank])
	return q


func _hat_log(f: String, was: String) -> bool:
	for l: Dictionary in fa.log:
		if str(l["f"]) == f and str(l["was"]) == was:
			return true
	return false


# ------------------------------------------------------------------ Regeln

func _regeln() -> void:
	var p := n.neue_person("technogunner", 1, "Regel", "Test")
	p["faehigkeit"] = "sturmlauf"
	pruefe(NemesisFaehigkeiten.von_person(p) == ["sturmlauf"], "Rang 1: eine Fähigkeit")
	var cd1 := fa.cd_von("sturmlauf", p)
	p["rang"] = 3
	pruefe(NemesisFaehigkeiten.von_person(p).size() == 2, "Rang 3: beide Fähigkeiten (%s)" % ", ".join(PackedStringArray(NemesisFaehigkeiten.von_person(p))))
	var cd3 := fa.cd_von("sturmlauf", p)
	pruefe(absf(cd1 - 14.0 * 0.9) < 0.01 and absf(cd3 - 14.0 * 0.7) < 0.01, "Abklingzeit Sturmlauf: Rang 1 %.1f s, Rang 3 %.1f s (−10 %% je Rang)" % [cd1, cd3])
	pruefe(NemesisFaehigkeiten.ziehen("scharfschuetze", "", true) == "durchschuss" and NemesisFaehigkeiten.ziehen("plasmawerfer", "hinterhalt", false) == "ausraeuchern",
		"Vergabe: aus der Deckung geholt → Deckungsbrecher (Durchschuss, Ausräuchern)")
	n.personen.erase(p)
	# bereit: Durchschuss und Ausräuchern durch genau einen Wall
	var s := schuetze("scharfschuetze", "durchschuss", wall - Vector2i(3, 0))
	brakk(o.karte.mitte(wall + Vector2i(3, 0)))
	o.bekannt_zeit = o.zeit
	pruefe(fa.waende(s.position, lage["pos"] as Vector2) == 1 and not o.karte.sicht_frei(s.position, lage["pos"] as Vector2) and fa._bereit(s, "durchschuss", lage),
		"Durchschuss bereit: Brakk hinter genau einem Wall, keine Sicht")
	var pw := schuetze("plasmawerfer", "ausraeuchern", wall - Vector2i(2, 0))
	pruefe(fa._bereit(pw, "ausraeuchern", lage), "Ausräuchern bereit: Brakk in Deckung hinter dem Wall")
	weg(s)
	weg(pw)


# ------------------------------------------------------------------ die sechs Fähigkeiten
# (Lambdas fangen Zahlen nur als Kopie – was sie verändern, liegt darum in `merk`.)

var merk := {}


func _unterdrueckung() -> void:
	var e := schuetze("technogunner", "unterdrueckung", offen)
	var start := o.karte.mitte(offen + Vector2i(4, 0))
	merk["bremse"] = 1.0
	var q := [0.0, 0.0]
	for k in 2:
		var ab := 0
		var gt := 0
		for i in versuche:
			brakk(start)
			merk["steh"] = k == 0
			var bewegen := func(t: float) -> void:
				if not bool(merk["steh"]) and t > 0.6:
					brakk(start + Vector2(0, 3.0 * Werte.ZELLE * (t - 0.6)))   # Stellungswechsel quer zum Kegel
				merk["bremse"] = minf(float(merk["bremse"]), fa.tempo_faktor())
			var r := versuch(e, "unterdrueckung", 4.0, bewegen)
			ab += int(r["abgefeuert"])
			gt += int(r["getroffen"])
			if float(r["erster"]) >= 0.0 and float(r["erster"]) < 0.58:
				pruefe(false, "Unterdrückungsfeuer trifft vor dem Anlegen")
		q[k] = float(gt) / maxf(1.0, float(ab))
	print("     %-20s stehend %3d %%   %-34s %3d %%   (Anteil der Schüsse)" % ["Unterdrückungsfeuer", roundi(q[0] * 100.0), "seitlich aus dem Kegel", roundi(q[1] * 100.0)])
	pruefe(_hat_log("unterdrueckung", "an") and _hat_log("unterdrueckung", "wirkt"), "Unterdrückungsfeuer: angelegt (Kegel) und gefeuert")
	pruefe(q[0] >= 0.4 and q[1] <= q[0] * 0.5, "Unterdrückungsfeuer: Konter wirkt (%d %% → %d %%)" % [roundi(q[0] * 100.0), roundi(q[1] * 100.0)])
	pruefe(absf(float(merk["bremse"]) - 0.7) < 0.01, "Unterdrückungsfeuer: Brakk im Kegel %d %% langsamer" % roundi((1.0 - float(merk["bremse"])) * 100.0))
	weg(e)


func _sturmlauf() -> void:
	var bp := o.karte.mitte(offen + Vector2i(7, 0))
	var fall := func(steh: bool) -> Dictionary:
		var e := schuetze("technogunner", "sturmlauf", offen)
		brakk(bp)
		var bewegen := func(_t: float) -> void:
			# Konter: im letzten Moment tumblen (kurz bevor er nah genug für die Salve ist)
			var nah := is_instance_valid(e) and e.position.distance_to(bp) < (fa.w("sturmlauf", "nah") + 0.8) * Werte.ZELLE
			brakk(bp, Vector2.ZERO, not steh and nah)
		var r := versuch(e, "sturmlauf", 3.5, bewegen)
		weg(e)
		return r
	var q := quoten("sturmlauf", fall, 0.5, "Tumble im letzten Moment")
	pruefe(_hat_log("sturmlauf", "salve"), "Sturmlauf: Ruf, Lauf und Salve aus nächster Nähe")
	pruefe(q[0] >= 0.6 and q[1] <= 0.3, "Sturmlauf: Tumble kontert (%d %% → %d %%)" % [roundi(q[0] * 100.0), roundi(q[1] * 100.0)])
	# Ladestrahl unterbricht: kein Schuss, er taumelt
	var e2 := schuetze("technogunner", "sturmlauf", offen)
	brakk(bp)
	merk["gestoppt"] = false
	var stoppen := func(t: float) -> void:
		if t > 0.7 and not bool(merk["gestoppt"]):
			merk["gestoppt"] = true
			fa.von_brakk(e2, true)
	var r2 := versuch(e2, "sturmlauf", 3.5, stoppen)
	pruefe(int(r2["treffer"]) == 0 and _hat_log("sturmlauf", "unterbrochen"), "Sturmlauf: der Ladestrahl stoppt ihn – keine Salve, er taumelt")
	weg(e2)


func _markierung() -> void:
	var e := schuetze("scharfschuetze", "markierung", offen)
	var bp := o.karte.mitte(offen + Vector2i(5, 0))
	merk["markiert"] = [0, 0]
	var fall := func(steh: bool) -> Dictionary:
		o.markiert_bis = -1.0
		brakk(bp)
		var bewegen := func(t: float) -> void:
			if not steh:
				brakk(bp + Vector2(0, 3.0 * Werte.ZELLE * t))
		var r := versuch(e, "markierung", 1.0, bewegen)
		if o.markiert_bis > o.zeit:
			(merk["markiert"] as Array)[0 if steh else 1] += 1
		return r
	quoten("markierung", fall, Werte.BRAKK_SCHARF_ZIEL_SEK, "dem orangen Strahl ausgewichen")
	var m: Array = merk["markiert"]
	pruefe(int(m[0]) >= versuche * 0.8 and int(m[1]) <= versuche * 0.2, "Markierung: nach Treffer markiert (%d×), ausgewichen nicht (%d×)" % [int(m[0]), int(m[1])])
	pruefe(fa.umstellen.has(e.get_instance_id()), "Markierung: Schütze wechselt danach die Stellung")
	weg(e)


func _durchschuss() -> void:
	var e := schuetze("scharfschuetze", "durchschuss", wall - Vector2i(3, 0))
	var bp := o.karte.mitte(wall + Vector2i(3, 0))
	var fall := func(steh: bool) -> Dictionary:
		brakk(bp)
		var bewegen := func(t: float) -> void:
			if not steh and t > 0.3:
				brakk(bp + Vector2(0, 3.0 * Werte.ZELLE * (t - 0.3)))
		return versuch(e, "durchschuss", 1.6, bewegen)
	var q := quoten("durchschuss", fall, fa.w("durchschuss", "laden"), "hellen Strahl verlassen")
	pruefe(q[0] >= 0.8 and q[1] <= 0.2, "Durchschuss: trifft durch den Wall, Stellungswechsel kontert (%d %% → %d %%)" % [roundi(q[0] * 100.0), roundi(q[1] * 100.0)])
	weg(e)


func _sperrbrand() -> void:
	var e := schuetze("plasmawerfer", "sperrbrand", offen)
	var start := o.karte.mitte(offen + Vector2i(3, 0)) + Vector2(0, -2.0 * Werte.ZELLE)
	var tempo := 3.0 * Werte.ZELLE
	var fall := func(steh: bool) -> Dictionary:
		brakk(start, Vector2(0, tempo))
		var bewegen := func(t: float) -> void:
			if steh:
				brakk(start + Vector2(0, tempo * t), Vector2(0, tempo))   # läuft weiter in den Kreis
			else:
				brakk(start + Vector2(0, tempo * minf(t, 0.25)) - Vector2(0, tempo * maxf(0.0, t - 0.25)), Vector2(0, -tempo))   # kehrt um
		return versuch(e, "sperrbrand", 2.2, bewegen)
	var q := quoten("sperrbrand", fall, fa.w("sperrbrand", "warnung"), "Richtung gewechselt")
	pruefe(q[0] >= 0.8 and q[1] <= 0.2, "Sperrbrand: liegt auf dem Laufweg, Umkehren kontert (%d %% → %d %%)" % [roundi(q[0] * 100.0), roundi(q[1] * 100.0)])
	weg(e)


func _ausraeuchern() -> void:
	var e := schuetze("plasmawerfer", "ausraeuchern", wall - Vector2i(3, 0))
	var bp := o.karte.mitte(wall + Vector2i(2, 0))
	var fall := func(steh: bool) -> Dictionary:
		brakk(bp)
		var bewegen := func(t: float) -> void:
			if not steh and t > 0.4:
				brakk(bp + Vector2(0, 3.0 * Werte.ZELLE * (t - 0.4)))
		return versuch(e, "ausraeuchern", 2.6, bewegen)
	var q := quoten("ausraeuchern", fall, fa.w("ausraeuchern", "flug"), "Deckung gewechselt (Schatten)")
	pruefe(q[0] >= 0.8 and q[1] <= 0.2, "Ausräuchern: trifft hinter dem Wall, Deckungswechsel kontert (%d %% → %d %%)" % [roundi(q[0] * 100.0), roundi(q[1] * 100.0)])
	weg(e)
