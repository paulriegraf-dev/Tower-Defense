class_name BefehlZange
extends RefCounted
## Zange der Jagdtrupps in Befehl 24 (23.11.; 27.11. Knoten-Umbau 7e – vorher in order24.gd): Jagdziel, Fächer, Losschicken,
## Wege. Regeln unverändert; die Feldhelfer (_erreichbar_nahe, _freies_feld_bei, _freies_feld_nahe, _truppen) und startfeld
## bleiben in order24.gd, weil Nemesis, Jagdtaktik und Tests sie nutzen. Teil von Befehl 24 (`o24.zangenwerk`).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var o24: Order24


func _init(e: Order24) -> void:
	o24 = e


## Jäger im Modus „jagd“: erst über den eigenen Anmarschweg zum Anmarschpunkt, dort warten, bis die Zange zuschlägt;
## dann aufgefächert auf Brakks letzten Ort – und wer dort nichts sieht, sucht sich ein Schussfeld.
func _jagd_ziel(e: Einheit, t: Dictionary) -> Vector2i:
	var ziel: Vector2i = t.get("ziel_ok", t["zuletzt"])
	var id := e.get_instance_id()
	var hier := o24.karte.zelle_bei(e.position)
	var a: Dictionary = t.get("anflug", {})
	if not a.is_empty() and not bool(t.get("zu", false)):
		o24._ohne_sicht.erase(id)
		o24._schussfeld.erase(id)
		if not bool(a.get("zw_ok", false)):
			var zw: Vector2i = a["zwischen"]
			if zw == Karte.KEINE or (t.get("mitte", e.position) as Vector2).distance_to(o24.karte.mitte(zw)) <= 1.5 * Werte.ZELLE:
				a["zw_ok"] = true
			else:
				return zw
		return _faecher_feld(e, t, a["punkt"], (o24.karte.mitte(a["punkt"]) - o24.karte.mitte(ziel)).normalized(), 0.8)
	# Zuschlagen: Schussfeld (D) geht vor, sonst der eigene Platz im Halbkreis (C)
	var sf: Dictionary = o24._schussfeld.get(id, {})
	if not sf.is_empty():
		if o24.zeit < float(sf["bis"]) and hier != (sf["z"] as Vector2i):
			return sf["z"]
		o24._schussfeld.erase(id)
	var richtung := ((t.get("mitte", e.position) as Vector2) - o24.karte.mitte(ziel))
	var platz := _faecher_feld(e, t, ziel, richtung.normalized() if richtung.length() > 1.0 else Vector2.RIGHT, Order24.FAECHER_RADIUS)
	var punkt := o24.karte.mitte(t["zuletzt"] as Vector2i)
	if e.position.distance_to(o24.karte.mitte(platz)) <= 1.2 * Werte.ZELLE and not o24.karte.sicht_frei(e.position, punkt):
		var seit := float(o24._ohne_sicht.get(id, o24.zeit))
		o24._ohne_sicht[id] = seit
		if o24.zeit - seit >= Order24.SCHUSSFELD_SEK:
			o24._ohne_sicht.erase(id)
			var sz := _schussfeld_suchen(hier, punkt, float(e.daten["reichweite"]))
			if sz != Karte.KEINE:
				o24._schussfeld[id] = {"z": sz, "bis": o24.zeit + 6.0}
				return sz
	else:
		o24._ohne_sicht.erase(id)
	return platz


## Platz des Mitglieds im Halbkreis um `mitte` (zur Seite `richtung`), `radius` Felder weit; erreichbar, sonst `mitte`.
func _faecher_feld(e: Einheit, t: Dictionary, mitte: Vector2i, richtung: Vector2, radius: float) -> Vector2i:
	var glieder: Array = t["mitglieder"]
	var n := glieder.size()
	var nr := maxi(0, glieder.find(e))
	if n <= 1:
		return mitte
	var winkel := lerpf(-1.2, 1.2, float(nr) / float(n - 1))   # gut ±70°
	var p := o24.karte.mitte(mitte) + richtung.rotated(winkel) * radius * Werte.ZELLE
	var z := o24._freies_feld_bei(p, mitte)
	if z == mitte or o24.karte.einheiten_weg(o24.karte.zelle_bei(e.position), z).is_empty():
		return mitte
	return z


## Nächstes erreichbare Feld (bis SCHUSSFELD_WEITE) mit freier Sicht auf `punkt` und in Reichweite.
func _schussfeld_suchen(von: Vector2i, punkt: Vector2, reichweite: float) -> Vector2i:
	var bestes := Karte.KEINE
	var beste := INF
	for dy in range(-Order24.SCHUSSFELD_WEITE, Order24.SCHUSSFELD_WEITE + 1):
		for dx in range(-Order24.SCHUSSFELD_WEITE, Order24.SCHUSSFELD_WEITE + 1):
			var z := von + Vector2i(dx, dy)
			if not o24.karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not o24.karte.ist_begehbar(z) or not o24.karte.ist_frei(z):
				continue
			var m := o24.karte.mitte(z)
			if m.distance_to(punkt) > maxf(2.0, reichweite) * Werte.ZELLE or not o24.karte.sicht_frei(m, punkt):
				continue
			var d := float(absi(dx) + absi(dy))
			if d < beste and not o24.karte.einheiten_weg(von, z).is_empty():
				beste = d
				bestes = z
	return bestes


## Einmal je Bild: Anmarschpunkte verteilen, Bereitschaft prüfen, gemeinsam zuschlagen.
func _zange_pflegen(k: Kommandant) -> void:
	var jagende: Array = o24.trupps.filter(func(x: Dictionary) -> bool: return str(x["modus"]) == "jagd" and not (x["mitglieder"] as Array).is_empty() and str(x.get("taktik", "")) in ["", "zange"])   # 26.11.: Sturm, Feuerschutz, Hinterhalt gehen eigene Wege
	if jagende.is_empty():
		o24._zange = {}
		return
	var ziel: Vector2i = o24.bekannt
	if ziel == Karte.KEINE or o24.zeit - o24.bekannt_zeit > o24.wf("ortung_takt"):
		for t: Dictionary in jagende:
			if str(t.get("taktik", "")) == "zange":
				ziel = t["zuletzt"]   # 26.11.: niemand sieht ihn – die Zange zielt auf die Funkortung
				break
	if ziel == Karte.KEINE:
		return
	if o24._zange.is_empty() or Vector2(ziel - (o24._zange["ziel"] as Vector2i)).length() > Order24.ZANGE_NEU:
		o24._zange = {"ziel": ziel, "erst_bereit": -1.0, "los": false}
		for t: Dictionary in jagende:
			t.erase("anflug")
	if bool(o24._zange["los"]) and o24.zeit - float(o24._zange.get("los_t", o24.zeit)) > 10.0:
		o24._zange["los"] = false   # Nachschub: die nächsten Trupps setzen wieder eine eigene Zange an
		o24._zange["erst_bereit"] = -1.0
	var ziel_p := o24.karte.mitte(ziel)
	var belegt: Array[Vector2i] = []   # Felder der schon geplanten Anmarschwege
	var seiten: Array[float] = []
	for t: Dictionary in jagende:
		if t.has("anflug"):
			seiten.append(float((t["anflug"] as Dictionary)["winkel"]))
			belegt.append_array((t["anflug"] as Dictionary).get("weg", []) as Array)
	for t: Dictionary in jagende:
		if bool(t.get("zu", false)) or t.has("anflug"):
			continue
		var mitte: Vector2 = t.get("mitte", ziel_p)
		if bool(o24._zange["los"]) or mitte.distance_to(ziel_p) <= Order24.ZANGE_AB * Werte.ZELLE:
			t["zu"] = true   # schon nah dran oder die Zange läuft schon: direkt angreifen
			continue
		var start := o24.startfeld(((t["mitglieder"] as Array)[0] as Node2D).position)   # 26.11.: frisch aus der Fabrik: ab ihrem Ausgang
		var a := _anflug_planen(start, ziel, (mitte - ziel_p).angle(), seiten, belegt)
		if a.is_empty():
			t["zu"] = true
			continue
		t["anflug"] = a
		seiten.append(float(a["winkel"]))
		belegt.append_array(a["weg"] as Array)
	# Bereit, wer an seinem Anmarschpunkt steht. Alle bereit – oder die ersten warten schon ZANGE_WARTE – dann los.
	var alle := true
	var irgendwer := false
	for t: Dictionary in jagende:
		if not t.has("anflug") or bool(t.get("zu", false)):
			continue
		var a: Dictionary = t["anflug"]
		if o24.zeit - float(a.get("seit", o24.zeit)) >= Order24.ZANGE_MAX_SEK:
			t["zu"] = true   # zu lange unterwegs: nicht mehr warten
			continue
		var bereit := (t.get("mitte", Vector2.INF) as Vector2).distance_to(o24.karte.mitte(a["punkt"])) <= 1.8 * Werte.ZELLE
		if bereit:
			irgendwer = true
		else:
			alle = false
	if irgendwer and float(o24._zange["erst_bereit"]) < 0.0:
		o24._zange["erst_bereit"] = o24.zeit
	if irgendwer and (alle or o24.zeit - float(o24._zange["erst_bereit"]) >= Order24.ZANGE_WARTE) and not bool(o24._zange["los"]):
		o24._zange["los"] = true
		o24._zange["los_t"] = o24.zeit
		var n := 0
		for t: Dictionary in jagende:
			if t.has("anflug") and not bool(t.get("zu", false)):
				t["zu"] = true
				n += 1
		if n >= 2:
			o24.spiel.melde("Sonde 7: „Zange steht. Zugriff!“", 3.0)
		if o24.spiel.has_method("befehl24_protokoll"):
			o24.spiel.befehl24_protokoll("zange", {"trupps": n, "warten": snappedf(o24.zeit - float(o24._zange["erst_bereit"]), 0.1)})


## Anmarschpunkt auf einer eigenen Seite (möglichst weit weg von den Seiten der anderen Trupps) und ein Zwischenpunkt auf
## einem Weg, der die Felder der anderen meidet. {} = kein erreichbarer Punkt.
func _anflug_planen(start: Vector2i, ziel: Vector2i, grund: float, seiten: Array[float], belegt: Array[Vector2i]) -> Dictionary:
	var kandidaten: Array = []
	for i in 8:
		var wkl := grund + TAU * float(i) / 8.0
		var abstand := PI
		for s: float in seiten:
			abstand = minf(abstand, absf(angle_difference(wkl, s)))
		# Wertung: weit weg von den anderen Seiten zählt viel, nahe der eigenen Herkunft ein wenig (kurzer Anmarsch)
		kandidaten.append([abstand * 2.0 - absf(angle_difference(wkl, grund)) * 0.4 if not seiten.is_empty() else -absf(angle_difference(wkl, grund)), wkl])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var direkt := o24.karte.einheiten_weg(start, o24._erreichbar_nahe(ziel, start)).size()
	var grenze := maxf(float(direkt) * Order24.ZANGE_UMWEG, float(direkt + 12)) if direkt > 0 else INF
	var ersatz := {}
	for k: Array in kandidaten:
		var wkl: float = k[1]
		var p := o24.karte.mitte(ziel) + Vector2.from_angle(wkl) * float(Order24.ZANGE_ABSTAND) * Werte.ZELLE
		var punkt := o24._freies_feld_bei(p, Karte.KEINE)
		if punkt == Karte.KEINE:
			continue
		var weg := _weg_mit_strafe(start, punkt, belegt)
		if weg.is_empty():
			continue
		var zw: Vector2i = weg[int(weg.size() * 0.55)] if weg.size() >= 6 else Karte.KEINE
		var plan := {"punkt": punkt, "winkel": wkl, "zwischen": zw, "zw_ok": false, "weg": weg, "seit": o24.zeit}
		if float(weg.size()) <= grenze:
			return plan
		if ersatz.is_empty():
			ersatz = plan   # zu weiter Umweg: nur, wenn keine Seite näher liegt
	return ersatz


## Weg für Truppen, auf dem schon geplante Felder anderer Trupps teurer sind (danach wieder zurückgesetzt).
func _weg_mit_strafe(von: Vector2i, nach: Vector2i, belegt: Array[Vector2i]) -> Array[Vector2i]:
	var astar: AStarGrid2D = o24.karte._astar_einheiten
	var gesetzt: Array[Vector2i] = []
	for z: Vector2i in belegt:
		if astar.is_in_boundsv(z) and not astar.is_point_solid(z) and astar.get_point_weight_scale(z) == 1.0:
			astar.set_point_weight_scale(z, Order24.WEG_STRAFE)
			gesetzt.append(z)
	var weg := o24.karte.einheiten_weg(von, nach)
	for z: Vector2i in gesetzt:
		astar.set_point_weight_scale(z, 1.0)
	return weg


func _losschicken(e: Einheit) -> void:
	if e.posten_zelle != Karte.KEINE:
		if o24.karte.posten.get(e.posten_zelle) == e:
			o24.karte.posten.erase(e.posten_zelle)
		e.posten_zelle = Karte.KEINE
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._plan_in = 0.0


## Prüfung: Weg jedes Trupps zum letzten bekannten Ort und die Tore/Lücken darauf ins Protokoll.
func _wege_loggen() -> void:
	o24.log_wege.clear()
	for i in o24.trupps.size():
		var t: Dictionary = o24.trupps[i]
		var m: Array = t["mitglieder"]
		if m.is_empty() or not is_instance_valid(m[0]):
			o24.log_wege.append([])
			continue
		var weg := o24.karte.einheiten_weg(o24.karte.zelle_bei((m[0] as Node2D).position), t["zuletzt"] as Vector2i)
		o24.log_wege.append(weg)
		var luecken: Array[Vector2i] = []
		for z: Vector2i in weg:
			var quer := (o24.karte.inhalt(z + Vector2i(1, 0)) == Karte.WALL and o24.karte.inhalt(z - Vector2i(1, 0)) == Karte.WALL) or (o24.karte.inhalt(z + Vector2i(0, 1)) == Karte.WALL and o24.karte.inhalt(z - Vector2i(0, 1)) == Karte.WALL)
			if o24.karte.ist_tor(z) or quer:
				luecken.append(z)
		print("JAGD Trupp %d: %d Jäger · Ziel %s · Weg %d Felder · Tore/Lücken %s" % [i + 1, m.size(), str(t["zuletzt"]), weg.size(), str(luecken)])
