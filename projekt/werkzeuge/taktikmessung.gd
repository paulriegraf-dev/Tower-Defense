extends SceneTree
## 26.11. (Paul): Befehl 24 – wie stark ist jede Angriffstaktik? Headless-Schnelllauf.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/taktikmessung.gd -- [Minuten] [Samen]
##
## Ein Bot-Brakk steht an wechselnden Orten (alle 60 s ein neuer, erreichbarer Platz), wird jedes Bild geheilt und schießt
## mit BRAKK_DPS auf die nächste Truppe, die er sieht (5 Felder). Herausforderer und Überläufer sind aus. Am Ende je Taktik:
## Trupps, Sekunden bis Kontakt, Schaden an Brakk je Trupp, Verluste je Trupp – und ob eine Taktik mehr als doppelt so viel
## Schaden macht wie Sturm. Schreibt nur user://nemesis_messung.json.

const BRAKK_DPS := 110.0
const PLATZ_SEK := 60.0

var spiel: Node
var o: Order24
var warte := 10
var minuten := 15.0
var platz_ab := -999.0
var platz := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		minuten = float(args[0])
	if args.size() > 1:
		seed(int(args[1]))
	Nemesis.datei = "user://nemesis_messung.json"
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["geheim_ab"] = 0
	r["herausforderer"] = false
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func _process(delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	var k: Kommandant = spiel.kommandant
	if o.zeit - platz_ab >= PLATZ_SEK:
		platz_ab = o.zeit
		platz = o.karte.mitte(_platz(k))
	k.position = platz
	k.oben = false
	k.leben = k.max_leben
	# zurückschießen: die nächste sichtbare Truppe in 5 Feldern
	var bester: Einheit = null
	var nah := 5.0 * Werte.ZELLE
	for x: Variant in o._truppen():
		var e := x as Einheit
		if Nemesis.lebt(e) and e.position.distance_to(k.position) < nah and o.karte.sicht_frei(e.position, k.position):
			nah = e.position.distance_to(k.position)
			bester = e
	if bester != null:
		bester.nimm_schaden(BRAKK_DPS * delta / maxf(Engine.time_scale, 0.01))
	if o.zeit >= minuten * 60.0 or o.vorbei:
		_auswerten()
		Nemesis.zuruecksetzen()
		quit(0)
		return true
	return false


## Ein offener Platz, den Brakk vom jetzigen Ort aus erreicht, 8–20 Felder entfernt.
func _platz(k: Kommandant) -> Vector2i:
	var von := o.karte.zelle_bei(k.position)
	for versuch in 200:
		var z := von + Vector2i(randi_range(-20, 20), randi_range(-14, 14))
		if not o.karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not o.karte.ist_begehbar(z) or not o.karte.ist_frei(z):
			continue
		var d := Vector2(z - von).length()
		if d < 8.0 or o.karte.einheiten_weg(von, z).is_empty():
			continue
		return z
	return von


func _auswerten() -> void:
	for t: Dictionary in o.trupps:
		o.taktik.ende(t)
	var je := {}
	for x: Dictionary in o.taktik.protokoll:
		match str(x["was"]):
			"welle":
				var s: Dictionary = je.get(x["taktik"], {"wellen": 0, "kontakt": [], "schaden": [], "verluste": [], "trupps": 0, "mann": 0, "schaden_ges": 0.0})
				s["wellen"] = int(s["wellen"]) + 1
				je[x["taktik"]] = s
			"kontakt":
				var s: Dictionary = je.get(x["taktik"], {"wellen": 0, "kontakt": [], "schaden": [], "verluste": [], "trupps": 0, "mann": 0, "schaden_ges": 0.0})
				(s["kontakt"] as Array).append(float(x["nach"]))
				je[x["taktik"]] = s
			"trupp_ende":
				var s: Dictionary = je.get(x["taktik"], {"wellen": 0, "kontakt": [], "schaden": [], "verluste": [], "trupps": 0, "mann": 0, "schaden_ges": 0.0})
				(s["schaden"] as Array).append(float(x["schaden_an_brakk"]))
				s["mann"] = int(s["mann"]) + int(x["verluste"]) + int(x["ueberlebende"])
				s["schaden_ges"] = float(s["schaden_ges"]) + float(x["schaden_an_brakk"])
				(s["verluste"] as Array).append(int(x["verluste"]))
				s["trupps"] = int(s["trupps"]) + 1
				je[x["taktik"]] = s
	print("MESSUNG %.0f min · %d Wellen · Kills %d" % [o.zeit / 60.0, o.wellen, o.kills])
	print("%-12s %6s %6s %6s %12s %14s %12s %12s" % ["Taktik", "Wellen", "Trupps", "Mann", "s bis Kontakt", "Schaden/Trupp", "Schaden/Mann", "Verluste/Tr."])
	var sturm := -1.0
	var werte := {}
	for t: String in BrakkJagdtaktik.TAKTIKEN:
		var s: Dictionary = je.get(t, {"wellen": 0, "kontakt": [], "schaden": [], "verluste": [], "trupps": 0, "mann": 0, "schaden_ges": 0.0})
		var k := _schnitt(s["kontakt"])
		var sch := _schnitt(s["schaden"])
		var v := _schnitt(s["verluste"])
		var je_mann := float(s["schaden_ges"]) / float(s["mann"]) if int(s["mann"]) > 0 else -1.0
		werte[t] = je_mann   # verglichen wird je Mann: Sturm teilt sich in kleine Trupps, Feuerschutz ist einer
		if t == "sturm":
			sturm = je_mann
		print("%-12s %6d %6d %6d %12s %14s %12s %12s" % [BrakkJagdtaktik.NAMEN[t], int(s["wellen"]), int(s["trupps"]), int(s["mann"]), "–" if k < 0 else "%.1f" % k, "–" if sch < 0 else "%.0f" % sch, "–" if je_mann < 0 else "%.0f" % je_mann, "–" if v < 0 else "%.1f" % v])
	for t: String in werte:
		if t != "sturm" and sturm > 0.0 and float(werte[t]) > 2.0 * sturm:
			print("ZU STARK %s: %.0f je Mann gegen Sturm %.0f" % [t, float(werte[t]), sturm])
	print("MESSUNG FERTIG")


static func _schnitt(l: Array) -> float:
	if l.is_empty():
		return -1.0
	var s := 0.0
	for v: Variant in l:
		s += float(v)
	return s / float(l.size())
