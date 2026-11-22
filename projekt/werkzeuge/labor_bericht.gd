extends SceneTree
## Schritt 9b: Bericht aus einem UCB-Lauf (labor/laeufe/ucb-<name>.jsonl).
##   godot --headless --path . -s werkzeuge/labor_bericht.gd -- <name> [ziel_beste=60-85] [ziel_mitte=20-50] [ziel_zufall_vor=10]
## Schreibt labor/berichte/<datum>-bauweisen.md und die Tabellen als CSV daneben. Nur Befunde und, getrennt davon,
## Vorschläge – keine Werte im Spiel werden geändert.

var partien: Array = []
var ziel_beste := Vector2(60, 85)
var ziel_mitte := Vector2(20, 50)
var ziel_zufall_vor := 10
var md: PackedStringArray = []
var ordner := ""
var datum := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Aufruf: ... -- <name des UCB-Laufs>")
		quit(1)
		return
	var name := args[0]
	for a in args:
		if a.begins_with("ziel_beste="):
			ziel_beste = Vector2(float(a.get_slice("=", 1).get_slice("-", 0)), float(a.get_slice("=", 1).get_slice("-", 1)))
		elif a.begins_with("ziel_mitte="):
			ziel_mitte = Vector2(float(a.get_slice("=", 1).get_slice("-", 0)), float(a.get_slice("=", 1).get_slice("-", 1)))
		elif a.begins_with("ziel_zufall_vor="):
			ziel_zufall_vor = int(a.get_slice("=", 1))
	var datei := ProjectSettings.globalize_path("res://labor/laeufe/ucb-%s.jsonl" % name)
	for zeile in FileAccess.get_file_as_string(datei).split("\n", false):
		var p: Variant = JSON.parse_string(zeile)
		if p is Dictionary:
			partien.append(p)
	ordner = ProjectSettings.globalize_path("res://labor/berichte")
	DirAccess.make_dir_recursive_absolute(ordner)
	datum = Time.get_date_string_from_system()
	_bericht(name)
	var ziel := ordner.path_join("%s-bauweisen.md" % datum)
	var f := FileAccess.open(ziel, FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()
	print("Bericht: ", ziel, " (", partien.size(), " Partien)")
	quit()


# ------------------------------------------------------------------ Hilfen

static func _mittel(werte: Array) -> float:
	if werte.is_empty():
		return 0.0
	var s := 0.0
	for w in werte:
		s += float(w)
	return s / werte.size()


static func _streuung(werte: Array) -> float:
	if werte.size() < 2:
		return 0.0
	var m := _mittel(werte)
	var s := 0.0
	for w in werte:
		s += (float(w) - m) * (float(w) - m)
	return sqrt(s / (werte.size() - 1))


func _csv(name: String, kopf: Array, zeilen: Array) -> void:
	var f := FileAccess.open(ordner.path_join("%s-%s.csv" % [datum, name]), FileAccess.WRITE)
	f.store_line(";".join(PackedStringArray(kopf)))
	for z: Array in zeilen:
		var teile: PackedStringArray = []
		for x in z:
			teile.append(str(x).replace(".", ",") if (x is float) else str(x))
		f.store_line(";".join(teile))
	f.close()


func _anf(p: Dictionary) -> String:
	return str(p.get("arm", "?")).get_slice("|", 0)


func _bw(p: Dictionary) -> String:
	var arm := str(p.get("arm", "?"))
	return arm.get_slice("|", 1) + ":" + arm.get_slice("|", 2)


func _sieg(p: Dictionary) -> bool:
	return str(p.get("ergebnis", "")) == "sieg"


func _restleben(p: Dictionary) -> float:
	return float(p.get("leben", 0)) if _sieg(p) else 0.0


# ------------------------------------------------------------------ Bericht

func _bericht(name: String) -> void:
	var wf: Dictionary = Bauweise.lade_json("wallformen.json")
	var kp: Dictionary = Bauweise.lade_json("kaufplaene.json")
	md.append("# Balance-Labor: Bauweisen (%s)" % datum)
	md.append("")
	md.append("Lauf `ucb-%s`, %d Partien. Zielbereich (Stellschraube, legt Paul fest): beste Bauweisen %d–%d %% Sieg, mittlere %d–%d %%, Zufalls-Käufer scheitert vor Runde %d." % [name, partien.size(), ziel_beste.x, ziel_beste.y, ziel_mitte.x, ziel_mitte.y, ziel_zufall_vor])
	md.append("")
	md.append("Wert einer Partie = erreichte Runde / 20, bei Sieg dazu Restleben / Startleben. Abwandlung der Wallform und Stufe-3-Wahl sind je Partie gewürfelt (Zuschnitt B) und unten getrennt ausgewertet.")
	md.append("")
	# --- je Arm
	var arme := {}
	for p: Dictionary in partien:
		var arm := str(p.get("arm", "?"))
		if not arme.has(arm):
			arme[arm] = []
		arme[arm].append(p)
	var tabelle: Array = []   # [anf, bw, n, sieg%, runde, sd_runde, rest, wert]
	for arm: String in arme:
		var liste: Array = arme[arm]
		var runden: Array = liste.map(func(p): return int(p.get("runde", 0)))
		var siege := liste.filter(func(p): return _sieg(p)).size()
		var rest: Array = liste.map(func(p): return _restleben(p))
		var werte: Array = liste.map(func(p): return float(p.get("wert", 0.0)))
		tabelle.append([arm.get_slice("|", 0), arm.get_slice("|", 1) + ":" + arm.get_slice("|", 2), liste.size(), 100.0 * siege / liste.size(), _mittel(runden), _streuung(runden), _mittel(rest), _mittel(werte), siege])
	tabelle.sort_custom(func(a: Array, b: Array) -> bool: return a[7] > b[7])
	_csv("anfuehrer-bauweise", ["Anführer", "Bauweise", "Partien", "Siegquote %", "Runde Mittel", "Runde Streuung", "Restleben Mittel", "Wert Mittel", "Siege"],
		tabelle.map(func(t): return [t[0], t[1], t[2], snappedf(t[3], 0.1), snappedf(t[4], 0.01), snappedf(t[5], 0.01), snappedf(t[6], 0.01), snappedf(t[7], 0.001), t[8]]))
	md.append("## 1. Anführer × Bauweise")
	md.append("")
	md.append("Vollständig in `%s-anfuehrer-bauweise.csv`. Hier je Anführer die fünf besten und die drei schwächsten Bauweisen (Bauweise = Wallform:Kaufplan, Namen unten)." % datum)
	md.append("")
	var anfuehrer: Array = []
	for t: Array in tabelle:
		if not anfuehrer.has(t[0]):
			anfuehrer.append(t[0])
	anfuehrer.sort()
	for a: String in anfuehrer:
		var eigene: Array = tabelle.filter(func(t): return t[0] == a)
		md.append("**%s** (%d Bauweisen, %d Partien)" % [a, eigene.size(), eigene.reduce(func(s, t): return s + int(t[2]), 0)])
		md.append("")
		md.append("| Bauweise | Partien | Sieg % | Runde (±) | Restleben |")
		md.append("|---|---:|---:|---:|---:|")
		var zeigen: Array = eigene.slice(0, 5) + (eigene.slice(maxi(5, eigene.size() - 3)) if eigene.size() > 5 else [])
		for t: Array in zeigen:
			md.append("| %s | %d | %.0f | %.1f (±%.1f) | %.1f |" % [_bw_name(t[1], wf, kp), t[2], t[3], t[4], t[5], t[6]])
		md.append("")
	# --- 2. Schwierigkeitskurve
	md.append("## 2. Schwierigkeitskurve")
	md.append("")
	var reihe := tabelle.filter(func(t): return not str(t[1]).ends_with(":Z"))
	var viertel := maxi(1, reihe.size() / 4)
	var beste := {}
	var mitte := {}
	for i in reihe.size():
		var key := "%s|%s" % [reihe[i][0], str(reihe[i][1]).replace(":", "|")]
		if i < viertel:
			beste[key] = true
		elif i >= viertel and i < reihe.size() - viertel:
			mitte[key] = true
	var gruppen := {"bestes Viertel": func(p): return beste.has(str(p["arm"])), "Mitte": func(p): return mitte.has(str(p["arm"])), "Zufalls-Käufer": func(p): return str(p["arm"]).ends_with("|Z")}
	var kurve_zeilen: Array = []
	md.append("Je Runde: mittlerer Lebensverlust / mittlere verlorene Checkpoints, nur Partien, die die Runde erreicht haben. ⚠ = Sprung (Verlust mehr als doppelt so hoch wie in der Runde davor und mindestens 0,5).")
	md.append("")
	md.append("| Runde | bestes Viertel | Mitte | Zufalls-Käufer |")
	md.append("|---:|---|---|---|")
	var vorher := {}
	for r in range(1, 21):
		var spalten: PackedStringArray = []
		var csvz: Array = [r]
		for g: String in gruppen:
			var verlust: Array = []
			var cp: Array = []
			for p: Dictionary in partien:
				if not gruppen[g].call(p):
					continue
				for rd: Dictionary in p.get("runden", []):
					if int(rd.get("runde", 0)) == r:
						verlust.append(int(rd.get("leben_vorher", 0)) - int(rd.get("leben_nachher", 0)))
						cp.append(int(rd.get("checkpoints_verloren", 0)))
			var v := _mittel(verlust)
			var sprung := v >= 0.5 and v > 2.0 * float(vorher.get(g, 0.0))
			vorher[g] = v
			spalten.append("%.2f / %.2f%s (n=%d)" % [v, _mittel(cp), " ⚠" if sprung else "", verlust.size()])
			csvz.append_array([snappedf(v, 0.01), snappedf(_mittel(cp), 0.01), verlust.size()])
		md.append("| %s | %s |" % [("**%d**" % r) if r in [6, 19, 20] else str(r), " | ".join(spalten)])
		kurve_zeilen.append(csvz)
	_csv("kurve", ["Runde", "Beste Verlust", "Beste CP", "Beste n", "Mitte Verlust", "Mitte CP", "Mitte n", "Zufall Verlust", "Zufall CP", "Zufall n"], kurve_zeilen)
	md.append("")
	# --- 3. Ausreißer
	md.append("## 3. Ausreißer")
	md.append("")
	var hoch := tabelle.filter(func(t): return int(t[2]) >= 10 and float(t[3]) > 90.0)
	var tief := tabelle.filter(func(t): return int(t[2]) >= 10 and float(t[3]) < 5.0 and not str(t[1]).ends_with(":Z"))
	md.append("- Über 90 %% Sieg (ab 10 Partien): %s" % (", ".join(PackedStringArray(hoch.map(func(t): return "%s %s (%.0f %%)" % [t[0], _bw_name(t[1], wf, kp), t[3]]))) if not hoch.is_empty() else "keine"))
	md.append("- Unter 5 %% Sieg (ab 10 Partien, ohne Zufall): %d Arme, z. B. %s" % [tief.size(), ", ".join(PackedStringArray(tief.slice(0, 8).map(func(t): return "%s %s" % [t[0], _bw_name(t[1], wf, kp)])))])
	md.append("")
	# Käufe in starken vs. schwachen Armen
	var kauf_stark := {}
	var kauf_schwach := {}
	var n_stark := 0
	var n_schwach := 0
	for p: Dictionary in partien:
		var stark := beste.has(str(p["arm"]))
		var schwach := not stark and not mitte.has(str(p["arm"])) and not str(p["arm"]).ends_with("|Z")
		if not stark and not schwach:
			continue
		var gesehen := {}
		for rd: Dictionary in p.get("runden", []):
			for k: String in (rd.get("ausgaben", {}) as Dictionary):
				gesehen[k.get_slice(":", 0) + (":" + k.get_slice(":", 1) if k.get_slice_count(":") > 1 else "")] = true
		var t := kauf_stark if stark else kauf_schwach
		for k in gesehen:
			t[k] = int(t.get(k, 0)) + 1
		if stark:
			n_stark += 1
		else:
			n_schwach += 1
	var kauf_zeilen: Array = []
	var alle_k := {}
	for k in kauf_stark:
		alle_k[k] = true
	for k in kauf_schwach:
		alle_k[k] = true
	for k: String in alle_k:
		var a := 100.0 * int(kauf_stark.get(k, 0)) / maxf(n_stark, 1)
		var b := 100.0 * int(kauf_schwach.get(k, 0)) / maxf(n_schwach, 1)
		kauf_zeilen.append([k, snappedf(a, 0.1), snappedf(b, 0.1)])
	kauf_zeilen.sort_custom(func(a: Array, b: Array) -> bool: return a[1] - a[2] > b[1] - b[2])
	_csv("kaeufe-stark-schwach", ["Kauf", "in starken Partien %", "in schwachen Partien %"], kauf_zeilen)
	md.append("**Was starke Bauweisen (bestes Viertel) kaufen, schwache (unteres Viertel) nicht** – Anteil der Partien mit diesem Kauf:")
	md.append("")
	md.append("| Kauf | stark | schwach |")
	md.append("|---|---:|---:|")
	for z: Array in kauf_zeilen.slice(0, 8) + kauf_zeilen.slice(maxi(8, kauf_zeilen.size() - 5)):
		md.append("| %s | %.0f %% | %.0f %% |" % z)
	md.append("")
	# Stufe-3-Wahl A/B und Abwandlung
	md.append("**Stufe-3-Wahl und Abwandlung** (über alle Arme gemittelt, Wert-Differenz zum Armmittel):")
	md.append("")
	var arm_mittel := {}
	for t: Array in tabelle:
		arm_mittel["%s|%s" % [t[0], str(t[1]).replace(":", "|")]] = float(t[7])
	for feld: String in ["wahl", "variante"]:
		var abw := {}
		for p: Dictionary in partien:
			if not p.has(feld):
				continue
			var k := str(p[feld])
			if not abw.has(k):
				abw[k] = []
			abw[k].append(float(p.get("wert", 0.0)) - float(arm_mittel.get(str(p["arm"]), 0.0)))
		var teile: PackedStringArray = []
		var keys := abw.keys()
		keys.sort()
		for k in keys:
			teile.append("%s: %+.3f (n=%d)" % [k, _mittel(abw[k]), (abw[k] as Array).size()])
		md.append("- %s: %s" % ["Stufe-3-Wahl" if feld == "wahl" else "Abwandlung", ", ".join(teile)])
	md.append("")
	# Schaden je Geld je Bauwerksart
	var schaden := {}
	var geld := {}
	for p: Dictionary in partien:
		for rd: Dictionary in p.get("runden", []):
			for q: String in (rd.get("quellen", {}) as Dictionary):
				# Batterien kommen je Feld ("batterie:12,3"), Brakk als "brakk" (gekauft als "kommandant")
				var art := "batterie" if q.begins_with("batterie") else ("kommandant" if q == "brakk" else q)
				if art == "?":
					continue
				schaden[art] = float(schaden.get(art, 0.0)) + float(rd["quellen"][q].get("schaden", 0.0))
			for k: String in (rd.get("ausgaben", {}) as Dictionary):
				var art := k
				if k.begins_with("stufe:"):
					art = k.trim_prefix("stufe:")
				geld[art] = float(geld.get(art, 0.0)) + float(rd["ausgaben"][k])
	# Fabrik-Ausgaben gelten für alle Fabriken (beim Bau ist die Truppe noch nicht festgelegt)
	var fabrik_geld := float(geld.get("fabrik", 0.0))
	var fabrik_schaden := 0.0
	for art in schaden:
		if str(art).begins_with("fabrik:"):
			fabrik_schaden += float(schaden[art])
	var sg_zeilen: Array = []
	for art: String in schaden:
		var g := float(geld.get(art, 0.0))
		if art.begins_with("fabrik:"):
			g += fabrik_geld * float(schaden[art]) / maxf(fabrik_schaden, 1.0)   # Bauanteil nach Schadensanteil verteilt
		sg_zeilen.append([art, snappedf(float(schaden[art]), 1.0), snappedf(g, 1.0), snappedf(float(schaden[art]) / maxf(g, 1.0), 0.01)])
	sg_zeilen.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	_csv("schaden-je-geld", ["Bauwerksart", "Schaden", "Geld", "Schaden je Geld"], sg_zeilen)
	md.append("**Schaden je ausgegebenem Geld je Bauwerksart** (Fabrikbau anteilig nach Schaden verteilt; Wälle ohne eigenen Schaden fehlen):")
	md.append("")
	md.append("| Bauwerksart | Schaden je Geld |")
	md.append("|---|---:|")
	for z: Array in sg_zeilen:
		md.append("| %s | %.2f |" % [z[0], z[3]])
	md.append("")
	# --- 4. Anführer-Vergleich
	md.append("## 4. Anführer-Vergleich")
	md.append("")
	md.append("| Anführer | Bauweisen im Zielbereich (%d–%d %%) | beste Bauweise | Sieg %% | Zufalls-Käufer: mittlere Runde |" % [ziel_beste.x, ziel_beste.y])
	md.append("|---|---:|---|---:|---:|")
	for a: String in anfuehrer:
		var eigene: Array = tabelle.filter(func(t): return t[0] == a and not str(t[1]).ends_with(":Z") and int(t[2]) >= 10)
		var im_ziel := eigene.filter(func(t): return float(t[3]) >= ziel_beste.x and float(t[3]) <= ziel_beste.y).size()
		var z := tabelle.filter(func(t): return t[0] == a and str(t[1]).ends_with(":Z"))
		var b: Array = eigene[0] if not eigene.is_empty() else ["", "–", 0, 0.0]
		md.append("| %s | %d | %s | %.0f | %s |" % [a, im_ziel, _bw_name(b[1], wf, kp), b[3], ("%.1f" % z[0][4]) if not z.is_empty() else "–"])
	md.append("")
	# --- 5. Wege
	md.append("## 5. Wege")
	md.append("")
	var wl: Array = []
	var ww: Array = []
	for p: Dictionary in partien:
		var rr: Array = p.get("runden", [])
		if rr.size() >= 5:
			wl.append(float(rr[4]["bau"].get("weglaenge", 0)))
			ww.append(float(p.get("wert", 0.0)))
	md.append("- Zusammenhang Weglänge der Gegner (Runde 5) ↔ Wert der Partie: Korrelation %.2f (n=%d). Nur ein Zusammenhang, kein Beweis." % [_korrelation(wl, ww), wl.size()])
	var nb := {}
	var nb_n := {}
	for p: Dictionary in partien:
		var w := str(p.get("wallform", "-"))
		var plan: Dictionary = p.get("plan", {})
		nb[w] = int(nb.get(w, 0)) + int(plan.get("nicht_baubar", 0))
		nb_n[w] = int(nb_n.get(w, 0)) + int(plan.get("plan_felder", 0))
	var teile: PackedStringArray = []
	for w: String in nb:
		if int(nb_n[w]) > 0:
			teile.append("%s %s: %.1f %% der Plan-Felder nicht baubar" % [w, str((wf.get(w, {}) as Dictionary).get("name", "")), 100.0 * int(nb[w]) / int(nb_n[w])])
	md.append("- Nicht baubare Wall-Felder je Wallform (Kartenlage, Weg wäre zu, Gelände): " + "; ".join(teile))
	md.append("")
	# --- 6. Grenzen
	md.append("## 6. Was der Bot nicht kann")
	md.append("")
	md.append("- Keine Eingriffe mitten in der Welle (Zielwahl, Pfeile, Stellungen nachbauen) – außer Nachkaufen im Gegenangriff von Runde 20.")
	md.append("- Keine Figur gesteuert: Brakk steht nach dem Kauf auf seinem Feld und handelt selbst; die Ego-Fähigkeiten der Anführer nutzt der Bot nicht.")
	md.append("- Feste Regellisten statt Planung: keine Reaktion auf die angekündigte Welle, keine Aufträge (Paul), Wallformen nach Schema statt nach Gefühl.")
	md.append("- Abriss nutzt der Bot nicht; Wälle, die eine Form blockieren, bleiben stehen.")
	md.append("- Darum fallen die Zahlen eher **zu schwer** aus: Ein guter Spieler sollte über den besten Bot-Bauweisen liegen.")
	md.append("")
	md.append("## Vorschläge (getrennt von den Befunden – Balance entscheidet Paul)")
	md.append("")
	md.append("_Werden nach Durchsicht der Befunde ergänzt._")


func _bw_name(bw: String, wf: Dictionary, kp: Dictionary) -> String:
	var w := bw.get_slice(":", 0)
	var k := bw.get_slice(":", 1)
	var wn := str((wf.get(w, {}) as Dictionary).get("name", "–"))
	var kn := str((kp.get(k, {}) as Dictionary).get("name", k))
	return "%s %s / %s" % [bw, wn, kn] if w != "-" else "Zufalls-Käufer"


static func _korrelation(x: Array, y: Array) -> float:
	if x.size() < 3:
		return 0.0
	var mx := _mittel(x)
	var my := _mittel(y)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in x.size():
		sxy += (float(x[i]) - mx) * (float(y[i]) - my)
		sxx += (float(x[i]) - mx) * (float(x[i]) - mx)
		syy += (float(y[i]) - my) * (float(y[i]) - my)
	return sxy / sqrt(maxf(sxx * syy, 1e-9))
