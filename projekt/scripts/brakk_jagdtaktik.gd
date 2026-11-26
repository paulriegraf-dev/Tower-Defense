class_name BrakkJagdtaktik
extends RefCounted
## 26.11. (Paul): Befehl 24 – Angriffstaktiken der Jagdwellen. Jede normale Welle kennt Brakks ungefähren Ort
## (Funkortung, ortung_ungenau Felder daneben, alle ortung_takt s neu – wer ihn sieht, nimmt die echte Stelle) und
## greift mit einer von vier Taktiken an. Die Namen sind die der Nemesis-Taktiken (Werte.NEMESIS_TAKTIKEN):
##   Sturm (direkt)        – lockere Linie auf ihn zu, schießt im Gehen, kein Rückzug.
##   Zange (flanke)        – teilt sich in 2 (ab 10 Mann 3) Trupps, getrennte Anmarschseiten, gemeinsamer Zugriff.
##   Feuerschutz (sperrfeuer) – Fernkämpfer beziehen ein Schussfeld so weit weg wie ihre Reichweite erlaubt, der Rest
##                          rückt in Sprüngen vor; geht Brakk auf die Feuergruppe los oder fällt sie, stürmen alle.
##   Hinterhalt (hinterhalt) – wartet außer Sicht auf Brakks wahrscheinlichem Weg, eröffnet ab hinterhalt_abstand
##                          Feldern; nach hinterhalt_warten s ohne Kontakt wird Sturm daraus.
## Wahl: gewichteter Zufall (Paul: Sturm bevorzugt), Zange/Feuerschutz/Hinterhalt nie zweimal hintereinander; fehlt die
## Mindestgröße, wird Sturm daraus. Elitetrupps, Lagerbesatzungen und der Überläufer-Verlauf bleiben beim alten
## Verhalten. Sonde 7 sagt nichts an (Paul); die Phasenzeile nennt die Taktik, über dem Truppführer steht 3 s ein Zeichen.

const TAKTIKEN: Array[String] = ["sturm", "zange", "feuerschutz", "hinterhalt"]
const NEMESIS := {"sturm": "direkt", "zange": "flanke", "feuerschutz": "sperrfeuer", "hinterhalt": "hinterhalt"}
const NAMEN := {"sturm": "Sturm", "zange": "Zange", "feuerschutz": "Feuerschutz", "hinterhalt": "Hinterhalt"}
const FERNKAMPF := ["scharfschuetze", "plasmawerfer"]
const ZEICHEN_SEK := 3.0
const ZEILE_SEK := 6.0
const HIMMEL := ["Osten", "Südosten", "Süden", "Südwesten", "Westen", "Nordwesten", "Norden", "Nordosten"]

var o24: Order24
var letzte := ""
var protokoll: Array = []        # Prüfung: {"was", …}
var zeile := ""                  # für die Phasenzeile …
var zeile_bis := -1.0            # … so lange
var _gruppe := 0
var erzwingen := ""             # Prüfung: die nächste Welle bekommt diese Taktik


func _init(p: Order24) -> void:
	o24 = p


## Gilt das neue Verhalten gerade? (Regel taktik_an, nicht im Überläufer-Verlauf)
func an() -> bool:
	return bool(o24.w("taktik_an")) and not o24.geheim


static func nemesis_name(taktik: String) -> String:
	return str(NEMESIS.get(taktik, "direkt"))


# ------------------------------------------------------------------ Wahl und Start

## Gewichteter Zufall; Sturm darf sich wiederholen, die anderen nicht. Mindestgrößen: Zange 6, Feuerschutz 4 mit zwei
## Fernkämpfern – sonst Sturm.
func waehle(n: int, fern: int, zufall: float = -1.0) -> String:
	var gewichte := {}
	var summe := 0.0
	for t: String in TAKTIKEN:
		if t != "sturm" and t == letzte:
			continue
		if t == "zange" and n < int(o24.w("zange_min")):
			continue
		if t == "feuerschutz" and (n < int(o24.w("feuerschutz_min")) or fern < 2):
			continue
		var g := maxf(0.0, o24.wf("taktik_gewicht_" + t))
		if g > 0.0:
			gewichte[t] = g
			summe += g
	if summe <= 0.0:
		return "sturm"
	var z := (randf() if zufall < 0.0 else zufall) * summe
	for t: String in gewichte:
		z -= float(gewichte[t])
		if z <= 0.0:
			return t
	return str(gewichte.keys().back())


## Eine normale Welle zieht los: Taktik wählen, aufteilen, Funkortung. Gibt die Zahl der Trupps zurück.
func welle(neu: Array, welle_nr: int, taktik: String = "") -> int:
	var k: Kommandant = o24.spiel.kommandant
	var fern := neu.filter(func(e: Variant) -> bool: return Nemesis.art_von(e as Einheit) in FERNKAMPF).size()
	if taktik == "" and erzwingen != "":
		taktik = erzwingen
		erzwingen = ""
	if taktik == "":
		taktik = waehle(neu.size(), fern)
	letzte = taktik
	_gruppe += 1
	var teile: Array = []
	match taktik:
		"zange":
			var anzahl := 3 if neu.size() >= 10 else 2
			for i in anzahl:
				teile.append([])
			for i in neu.size():
				(teile[i % anzahl] as Array).append(neu[i])
		"sturm":
			teile = o24._aufteilen(neu)   # mehrere kleine Trupps, alle stürmen
		_:
			teile = [neu]
	var ziel := ungenau(o24.karte.zelle_bei(k.position))
	var trupps: Array = []
	for teil: Array in teile:
		var t: Dictionary = o24._neuer_trupp(teil, "jagd")
		t["taktik"] = taktik
		t["verhalten"] = taktik
		t["gruppe"] = _gruppe
		t["welle"] = welle_nr
		t["start"] = o24.zeit
		t["ids"] = teil.map(func(e: Variant) -> int: return (e as Node).get_instance_id())
		t["zuletzt"] = ziel
		t["gesehen"] = o24.zeit
		t["ortung_naechst"] = o24.zeit + o24.wf("ortung_takt")
		t["kontakt"] = false
		t["ende"] = false
		if taktik != "zange":
			t["zu"] = true   # die Zange plant ihre Anmarschwege; alle anderen gehen direkt
		trupps.append(t)
	match taktik:
		"feuerschutz":
			_rollen(trupps[0] as Dictionary)
		"hinterhalt":
			_hinterhalt_planen(trupps[0] as Dictionary)
	var text := str(NAMEN[taktik])
	if taktik == "zange":
		text += " von " + " und ".join(PackedStringArray(_seiten(trupps, ziel)))
	if taktik != "hinterhalt" and not trupps.is_empty() and str((trupps[0] as Dictionary)["verhalten"]) == taktik:
		_ansage(tr("Jagdtrupp: %s") % text, trupps[0] as Dictionary)
	protokoll.append({"was": "welle", "taktik": taktik, "n": neu.size(), "trupps": trupps.size(), "bei": o24.zeit})
	return trupps.size()


## Brakks Feld, um bis zu ortung_ungenau Felder verschoben (ein freies, begehbares Feld).
func ungenau(z: Vector2i) -> Vector2i:
	var r := int(o24.w("ortung_ungenau"))
	var karte: Karte = o24.karte
	for i in 10:
		var c := z + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if karte.in_karte(c) and c.x >= Werte.ZONE_SPALTEN and karte.ist_begehbar(c) and karte.ist_frei(c):
			return c
	return z


## Woher die Teile der Zange kommen (Himmelsrichtung vom Ziel aus).
func _seiten(trupps: Array, ziel: Vector2i) -> Array:
	var aus: Array = []
	var p := o24.karte.mitte(ziel)
	for t: Dictionary in trupps:
		var m: Array = t["mitglieder"]
		if m.is_empty():
			continue
		var r := ((m[0] as Node2D).position - p)
		var i := posmod(roundi(r.angle() / (TAU / 8.0)), 8)
		var s: String = HIMMEL[i]
		if not aus.has(s):
			aus.append(s)
	if aus.size() == 1:
		aus.append("der Seite")
	return aus


# ------------------------------------------------------------------ Je Sekunde (Order24._trupps_lenken)

## Funkortung, Auslöser und Übergänge eines Taktik-Trupps; `sieht` = ein Mitglied sieht Brakk.
func lenken(t: Dictionary, sieht: bool, k: Kommandant) -> void:
	var zeit := o24.zeit
	var bz := o24.karte.zelle_bei(k.position)
	t["modus"] = "jagd"   # Taktik-Trupps verlieren ihn nicht: die Ortung kommt ja wieder
	if sieht:
		t["zuletzt"] = bz
		t["gesehen"] = zeit
	elif zeit >= float(t["ortung_naechst"]):
		t["zuletzt"] = ungenau(bz)
		t["ortung_naechst"] = zeit + o24.wf("ortung_takt")
	if not bool(t["kontakt"]):
		for id: int in t["ids"]:
			if o24.nemesis != null and o24.nemesis._begegnung.has(id):
				t["kontakt"] = true
				_log("kontakt", {"welle": t["welle"], "taktik": t["taktik"], "trupp_groesse": (t["mitglieder"] as Array).size(),
					"sekunden_bis_kontakt": snappedf(zeit - float(t["start"]), 0.1)})
				protokoll.append({"was": "kontakt", "taktik": t["taktik"], "nach": zeit - float(t["start"]), "trupp": t})
				break
	match str(t["verhalten"]):
		"zange":
			if bool(t.get("zu", false)):
				t["verhalten"] = "sturm"   # nach dem Zugriff wie Sturm
			elif sieht and (t.get("mitte", Vector2.INF) as Vector2).distance_to(k.position) <= Order24.ZANGE_NAH * Werte.ZELLE:
				t["zu"] = true
		"feuerschutz":
			var feuer := _gruppe_von(t, "feuer")
			var vorher: Vector2 = t.get("brakk_vorher", k.position)
			if feuer.is_empty():
				_stuermen(t, "die Feuergruppe ist gefallen")
			else:
				for e: Einheit in feuer:
					# nur wer schon steht (Schussfeld oder Brakk in Reichweite): wer auf dem Weg nah vorbeikommt, zählt nicht
					var steht := e._punkte.size() <= 1 or (e.position.distance_to(k.position) <= e.reichweite_jetzt() * Werte.ZELLE and o24.karte.sicht_frei(e.position, k.position))
					if steht and e.position.distance_to(k.position) <= o24.wf("feuerschutz_nah") * Werte.ZELLE and e.position.distance_to(vorher) - e.position.distance_to(k.position) >= 0.3 * Werte.ZELLE:   # Brakk kommt auf sie zu
						_stuermen(t, "Brakk greift die Feuergruppe an")
						break
			t["brakk_vorher"] = k.position
		"hinterhalt":
			var mitte: Vector2 = t.get("mitte", Vector2.INF)
			var a: Dictionary = t.get("hinterhalt", {})
			var liegt := not a.is_empty() and mitte.distance_to(o24.karte.mitte(a["punkt"] as Vector2i)) <= 1.5 * Werte.ZELLE
			if liegt and not bool(t.get("liegt", false)):
				t["liegt"] = true
				t["liegt_seit"] = zeit
			# bei Beschuss oder wenn er herankommt (im Versteck 6 Felder, unterwegs erst ganz nah)
			var nah := o24.wf("hinterhalt_abstand") * (1.0 if bool(t.get("liegt", false)) else 0.6)
			if mitte.distance_to(k.position) <= nah * Werte.ZELLE or bool(t["kontakt"]):
				_ansage(tr("Hinterhalt!"), t, "hinterhalt")
				_stuermen(t, "ausgelöst: " + ("Kontakt" if bool(t["kontakt"]) else "nah"))
			elif zeit - float(t.get("liegt_seit", t["start"])) >= o24.wf("hinterhalt_warten") or zeit - float(t["start"]) >= 2.5 * o24.wf("hinterhalt_warten"):   # 25 s im Versteck (der Weg dorthin zählt nicht ganz mit)
				_stuermen(t, "keine Begegnung")


func _stuermen(t: Dictionary, grund: String) -> void:
	if str(t["verhalten"]) == "sturm":
		return
	protokoll.append({"was": "sturm", "von": t["verhalten"], "grund": grund, "bei": o24.zeit, "trupp": t})
	t["verhalten"] = "sturm"
	t["zu"] = true


## Trupp aufgelöst (alle gefallen): Bilanz ins Protokoll. Am Laufende auch für die, die noch stehen.
func ende(t: Dictionary) -> void:
	if not t.has("taktik") or bool(t["ende"]):
		return
	t["ende"] = true
	var schaden := 0.0
	var leben := 0
	for id: int in t["ids"]:
		var l: Dictionary = o24.nemesis._lauf.get(id, {}) if o24.nemesis != null else {}
		schaden += float(l.get("schaden", 0.0))
		if Nemesis.lebt(instance_from_id(id)):
			leben += 1
	var daten := {"welle": t["welle"], "taktik": t["taktik"], "schaden_an_brakk": snappedf(schaden, 0.1),
		"verluste": (t["ids"] as Array).size() - leben, "ueberlebende": leben}
	_log("trupp_ende", daten)
	daten["was"] = "trupp_ende"
	daten["kontakt_nach"] = -1.0
	protokoll.append(daten)


# ------------------------------------------------------------------ Ziele (Order24._trupp_ziel)

## Marschziel nach Taktik; KEINE = wie gewohnt (_jagd_ziel: Anmarsch der Zange bzw. auffächern).
func ziel(e: Einheit, t: Dictionary) -> Vector2i:
	match str(t["verhalten"]):
		"feuerschutz":
			return _feuerschutz_ziel(e, t)
		"hinterhalt":
			var a: Dictionary = t.get("hinterhalt", {})
			if a.is_empty():
				return Karte.KEINE
			var punkt: Vector2i = a["punkt"]
			var blick := (o24.karte.mitte(t["zuletzt"] as Vector2i) - o24.karte.mitte(punkt))
			return o24._faecher_feld(e, t, punkt, -blick.normalized() if blick.length() > 1.0 else Vector2.RIGHT, 1.0)   # verteilt, mit dem Rücken zur Deckung
	return Karte.KEINE


## Schießt die Einheit im Gehen? (Sturm, Zange nach dem Zugriff, gestürmter Feuerschutz und Hinterhalt)
func drueckt(e: Einheit) -> bool:
	var t := trupp_von(e)
	if t.is_empty() or not an():
		return false
	var v := str(t["verhalten"])
	return v == "sturm" or (v == "feuerschutz" and str((t.get("rollen", {}) as Dictionary).get(e.get_instance_id(), "")) == "sturm")


## Im Gehen streut die Waffe etwas mehr (nemesis.genau).
func streuung(e: Einheit) -> float:
	return o24.wf("sturm_streuung") / 100.0 if drueckt(e) and not e._punkte.is_empty() else 1.0


func trupp_von(e: Einheit) -> Dictionary:
	var nr := int(o24.jaeger.get(e.get_instance_id(), -1))
	if nr < 0 or nr >= o24.trupps.size():
		return {}
	var t: Dictionary = o24.trupps[nr]
	return t if t.has("taktik") else {}


# --- Feuerschutz

func _rollen(t: Dictionary) -> void:
	var rollen := {}
	var glieder: Array = t["mitglieder"]
	var hoechstens := maxi(1, glieder.size() / 2)
	var feuer := 0
	# erst die Scharfschützen (weiteste Reichweite), dann Plasmawerfer
	for art: String in ["scharfschuetze", "plasmawerfer"]:
		for e: Variant in glieder:
			if feuer < hoechstens and not rollen.has((e as Node).get_instance_id()) and Nemesis.art_von(e as Einheit) == art:
				rollen[(e as Node).get_instance_id()] = "feuer"
				feuer += 1
	for e: Variant in glieder:
		if not rollen.has((e as Node).get_instance_id()):
			rollen[(e as Node).get_instance_id()] = "sturm"
	t["rollen"] = rollen
	t["feuerfeld"] = {}
	t["sprung"] = {}
	if feuer < 2:
		t["verhalten"] = "sturm"


func _gruppe_von(t: Dictionary, rolle: String) -> Array:
	var aus: Array = []
	var rollen: Dictionary = t.get("rollen", {})
	for e: Variant in t["mitglieder"]:
		if Nemesis.lebt(e) and str(rollen.get((e as Node).get_instance_id(), "")) == rolle:
			aus.append(e)
	return aus


## Feuergruppe: ein Feld mit freier Sicht auf Brakk, so weit weg wie die eigene Reichweite erlaubt (höchstens
## feuerschutz_abstand_max Felder). Sturmgruppe: in Sprüngen vor, solange die Feuergruppe schießt.
func _feuerschutz_ziel(e: Einheit, t: Dictionary) -> Vector2i:
	var id := e.get_instance_id()
	var ziel_z: Vector2i = t.get("ziel_ok", t["zuletzt"])
	var hier := o24.karte.zelle_bei(e.position)
	if str((t["rollen"] as Dictionary).get(id, "sturm")) == "feuer":
		var f: Dictionary = (t["feuerfeld"] as Dictionary).get(id, {})
		if f.is_empty() or o24.zeit >= float(f["bis"]) or Vector2(ziel_z - (f["fuer"] as Vector2i)).length() > 2.5:
			var z := feuerfeld(e, t["zuletzt"] as Vector2i)
			f = {"z": z if z != Karte.KEINE else ziel_z, "bis": o24.zeit + 4.0, "fuer": ziel_z}
			(t["feuerfeld"] as Dictionary)[id] = f
		return f["z"]
	# Sturmgruppe: laufen – halten – laufen
	var feuert := false
	for x: Variant in _gruppe_von(t, "feuer"):
		var ff: Dictionary = (t["feuerfeld"] as Dictionary).get((x as Node).get_instance_id(), {})
		var u := x as Einheit
		var bp: Vector2 = (o24.spiel.kommandant as Kommandant).position
		var am_feld := not ff.is_empty() and u.position.distance_to(o24.karte.mitte(ff["z"] as Vector2i)) <= 1.2 * Werte.ZELLE
		if am_feld or (u.position.distance_to(bp) <= u.reichweite_jetzt() * Werte.ZELLE and o24.karte.sicht_frei(u.position, bp)):
			feuert = true   # am Schussfeld – oder sie sieht ihn schon in Reichweite und bleibt stehen, um zu schießen
	var s: Dictionary = (t["sprung"] as Dictionary).get(id, {"ziel": Karte.KEINE, "halten_bis": -1.0})
	(t["sprung"] as Dictionary)[id] = s
	if not feuert:
		return hier if s["ziel"] == Karte.KEINE else s["ziel"]   # warten, bis die Feuergruppe steht
	if o24.zeit < float(s["halten_bis"]):
		return hier
	if s["ziel"] != Karte.KEINE and e.position.distance_to(o24.karte.mitte(s["ziel"] as Vector2i)) <= 0.7 * Werte.ZELLE:
		s["ziel"] = Karte.KEINE
		s["halten_bis"] = o24.zeit + o24.wf("feuerschutz_halten")
		protokoll.append({"was": "sprung", "bei": o24.zeit, "id": id})
		return hier
	if s["ziel"] == Karte.KEINE:
		var weg := o24.karte.einheiten_weg(hier, ziel_z)
		if weg.is_empty():
			return ziel_z
		s["ziel"] = weg[mini(weg.size() - 1, maxi(0, roundi(o24.wf("feuerschutz_sprung")) - 1))]
	return s["ziel"]


## Bestes Schussfeld: freie Sicht auf `punkt`, Abstand zwischen min(abstand_min, Reichweite − 1) und
## min(abstand_max, Reichweite), erreichbar, möglichst nah an der Einheit.
func feuerfeld(e: Einheit, punkt: Vector2i) -> Vector2i:
	var karte: Karte = o24.karte
	var rw := e.reichweite_jetzt()
	var hi := minf(o24.wf("feuerschutz_abstand_max"), rw - 0.2)
	var lo := minf(o24.wf("feuerschutz_abstand_min"), maxf(1.0, hi - 1.2))
	lo = minf(hi - 0.1, maxf(lo, o24.wf("feuerschutz_nah") + 0.5))   # nicht in der Zone, in der sie losstürmen würden
	var p := karte.mitte(punkt)
	var kand: Array = []
	var r := ceili(hi)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy).length()
			if d < lo or d > hi:
				continue
			var z := punkt + Vector2i(dx, dy)
			if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var m := karte.mitte(z)
			if karte.sicht_frei(m, p):
				kand.append([m.distance_to(e.position) - d * 4.0, z])   # lieber weit weg von Brakk, dann nah an der Einheit
	kand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var hier := karte.zelle_bei(e.position)
	for i in mini(6, kand.size()):
		var z: Vector2i = kand[i][1]
		if z == hier or not karte.einheiten_weg(hier, z).is_empty():
			return z
	return Karte.KEINE


# --- Hinterhalt

## Wo er wahrscheinlich hin will: steht er an einem Lager oder sabotiert er, zur Zuflucht am Myriaden-HQ; sonst zum
## nächsten Lager. Auf diesem Weg ein Feld 6–10 Felder vor ihm, das er nicht sieht – möglichst an einem Erdwall.
func _hinterhalt_planen(t: Dictionary) -> void:
	var karte: Karte = o24.karte
	var von: Vector2i = t["zuletzt"]
	var p := karte.mitte(von)
	var am_lager := not o24.sabo.is_empty()
	var naechstes := Karte.KEINE
	var nd := INF
	for f: Vector2i in o24.fabrik_hp:
		var d := karte.mitte(f).distance_to(p) / Werte.ZELLE
		if d < 5.0:
			am_lager = true
		elif d < nd:
			nd = d
			naechstes = f
	var nach: Vector2i = Werte.ANGRIFFS_ZELLE if am_lager or naechstes == Karte.KEINE else naechstes
	var weg := karte.einheiten_weg(o24._erreichbar_nahe(von, von), o24._erreichbar_nahe(nach, von))
	var start := o24.startfeld(((t["mitglieder"] as Array)[0] as Node2D).position)
	var zu_trupp := (karte.mitte(start) - p).normalized()
	var kand := {}
	for z: Vector2i in weg:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c := z + Vector2i(dx, dy)
				if not karte.in_karte(c) or c.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(c) or not karte.ist_frei(c):
					continue
				var m := karte.mitte(c)
				var d := m.distance_to(p) / Werte.ZELLE
				if d < o24.wf("hinterhalt_abstand") or d > o24.wf("hinterhalt_abstand") + 4.0 or karte.sicht_frei(m, p):
					continue
				var waende := 0
				for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if karte.in_karte(c + n) and karte.inhalt(c + n) == Karte.WALL:
						waende += 1
				var w := float(waende) - absf(d - 8.0) * 0.3 - 0.5 * float(absi(dx) + absi(dy)) + 2.0 * zu_trupp.dot((m - p).normalized())   # lieber auf der eigenen Seite
				kand[c] = maxf(float(kand.get(c, -INF)), w)
	var liste: Array = kand.keys()
	liste.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(kand[a]) > float(kand[b]))
	var beste := Karte.KEINE
	for i in mini(8, liste.size()):
		if _anmarsch_verdeckt(start, liste[i], p):
			beste = liste[i]
			break
	if beste == Karte.KEINE:
		beste = _versteck_im_ring(p, start)   # kein Versteck auf seinem Weg: irgendwo 6–10 Felder um ihn, außer Sicht
	if beste == Karte.KEINE:
		t["verhalten"] = "sturm"   # kein Versteck auf seinem Weg
		protokoll.append({"was": "sturm", "von": "hinterhalt", "grund": "kein Versteck", "bei": o24.zeit, "trupp": t})
		return
	t["hinterhalt"] = {"punkt": beste, "nach": nach}
	protokoll.append({"was": "hinterhalt", "punkt": beste, "bei": o24.zeit})


## Ein Feld im Ring hinterhalt_abstand … +4 Felder um `p`, das Brakk nicht sieht und der Trupp erreicht – möglichst auf der
## Seite, von der der Trupp kommt, und an einem Erdwall.
func _versteck_im_ring(p: Vector2, start: Vector2i) -> Vector2i:
	var karte: Karte = o24.karte
	var mitte := karte.zelle_bei(p)
	var zu_trupp := (karte.mitte(start) - p).normalized()
	var lo := o24.wf("hinterhalt_abstand")
	var kand: Array = []
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var c := mitte + Vector2i(dx, dy)
			var d := Vector2(dx, dy).length()
			if d < lo or d > lo + 4.0 or not karte.in_karte(c) or c.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(c) or not karte.ist_frei(c):
				continue
			var m := karte.mitte(c)
			if karte.sicht_frei(m, p):
				continue
			var waende := 0
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if karte.in_karte(c + n) and karte.inhalt(c + n) == Karte.WALL:
					waende += 1
			kand.append([zu_trupp.dot((m - p).normalized()) * 2.0 + float(waende) * 0.5 - absf(d - 8.0) * 0.2, c])
	kand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in mini(8, kand.size()):
		if _anmarsch_verdeckt(start, kand[i][1], p):
			return kand[i][1]
	return Karte.KEINE


## Erreicht der Trupp das Versteck, ohne Brakk unterwegs näher als hinterhalt_abstand mit freier Sicht zu kommen?
## (Sonst läuft er an ihm vorbei, schießt – und der Hinterhalt ist verraten, bevor er liegt.)
func _anmarsch_verdeckt(start: Vector2i, ziel_feld: Vector2i, p: Vector2) -> bool:
	var weg := o24.karte.einheiten_weg(start, ziel_feld)
	if weg.is_empty() and start != ziel_feld:
		return false
	var abstand := o24.wf("hinterhalt_abstand") * Werte.ZELLE
	for z: Vector2i in weg:
		var m := o24.karte.mitte(z)
		var d := m.distance_to(p)
		if d <= abstand * 0.6 + 0.5 * Werte.ZELLE or (d < abstand and o24.karte.sicht_frei(m, p)):   # 0,6: so nah löst er auch unterwegs aus
			return false
	return true


# ------------------------------------------------------------------ Anzeige und Protokoll

func _ansage(text: String, t: Dictionary, zeichen: String = "") -> void:
	zeile = text
	zeile_bis = o24.zeit + ZEILE_SEK
	var m: Array = t["mitglieder"]
	if not m.is_empty() and Nemesis.lebt(m[0]):
		_zeichen(m[0] as Einheit, zeichen if zeichen != "" else str(t["taktik"]))


## Kleines Zeichen über dem Truppführer (Platzhalter aus Code): Pfeil, Klammer, Fadenkreuz, Auge.
func _zeichen(e: Einheit, taktik: String) -> void:
	var alt := e.get_node_or_null("TaktikZeichen")
	if alt != null:
		alt.free()
	var s := Sprite2D.new()
	s.name = "TaktikZeichen"
	s.texture = zeichen_bild(taktik)
	s.centered = false
	var hoehe := float(e._sprite.get("_zelle")) * e._sprite.scale.y * 0.8 + 30.0
	var gross := 3.0 if o24.spiel.get("ego") != null else 1.0   # in Brakks Sicht wären 12 Bildpunkte im Trupp kaum zu sehen
	s.scale = Vector2(gross, gross)
	s.offset = Vector2(-6, -float(s.texture.get_height()) - hoehe / gross)
	e.add_child(s)
	var tw := s.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(ZEICHEN_SEK)
	tw.tween_callback(s.queue_free)


static var _bilder := {}

static func zeichen_bild(taktik: String) -> Texture2D:
	if _bilder.has(taktik):
		return _bilder[taktik]
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var c := Color("ff5a4a")
	var punkte: Array = []
	match taktik:
		"sturm":   # Pfeil nach vorn
			for i in 10:
				punkte.append(Vector2i(i + 1, 6))
			for i in 4:
				punkte.append_array([Vector2i(10 - i, 6 - i), Vector2i(10 - i, 6 + i)])
		"zange":   # zwei Klammern
			c = Color("ffb84d")
			for y in range(2, 11):
				punkte.append_array([Vector2i(2, y), Vector2i(9, y)])
			for x in [3, 4]:
				punkte.append_array([Vector2i(x, 2), Vector2i(x, 10), Vector2i(11 - x, 2), Vector2i(11 - x, 10)])
		"feuerschutz":   # Fadenkreuz
			c = Color("ff9a3d")
			for i in 12:
				var w := TAU * i / 12.0
				punkte.append(Vector2i(roundi(5.5 + cos(w) * 4.5), roundi(5.5 + sin(w) * 4.5)))
			for i in range(0, 12):
				if i < 4 or i > 7:
					punkte.append_array([Vector2i(i, 6), Vector2i(6, i)])
		_:   # Auge
			c = Color("c9a2ff")
			for x in range(1, 11):
				var h := roundi(sin(PI * (x - 0.5) / 10.0) * 3.0)
				punkte.append_array([Vector2i(x, 6 - h), Vector2i(x, 6 + h)])
			punkte.append_array([Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6), Vector2i(5, 7), Vector2i(6, 7)])
	for q: Vector2i in punkte:
		if q.x >= 0 and q.y >= 0 and q.x < 12 and q.y < 12:
			img.set_pixel(q.x, q.y, c)
	_bilder[taktik] = ImageTexture.create_from_image(img)
	return _bilder[taktik]


func _log(art: String, daten: Dictionary) -> void:
	if o24.spiel.has_method("befehl24_protokoll"):
		o24.spiel.befehl24_protokoll(art, daten)
