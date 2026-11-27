class_name BefehlUeberlaeufer
extends RefCounted
## Überläufer – der geheime Verlauf von Befehl 24 (20.11.; 27.11. Knoten-Umbau 7e – vorher in order24.gd): Myriaden-HQ
## besetzen, Checkpoints für Brakk, Technoclan-HQ angreifen, Lichtmenü. Regeln unverändert; Zustand und Funktionen, die
## Ringe, Gegner, main und Tests nutzen (myr_fabriken, tc_hq_leben, gegner_am_ziel …), bleiben in order24.gd.
## Teil von Befehl 24 (`o24.ueberlaeufer`).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var o24: Order24


func _init(e: Order24) -> void:
	o24 = e


## Hält Brakk das Myriaden-HQ bis geheim_ab (der Vorstoß darauf ist nicht angesagt – Brakk ahnt es nur), meldet Sonde 7,
## dass er übergelaufen ist. Dann baut er mit [1] Myriaden-Fabriken in der Zone des HQ (eine Sorte, myr_fabrik_preis) und
## wirft mit [C] Ringfelder darüber: Der Ring bestimmt die Einheit (MYR_RING), ihr Preis die Zahl je Zyklus. Je
## Wellenzyklus kostet die Produktion myr_kosten_anteil % der Einheiten. Alle myr_takt Sekunden
## laufen die Myriaden los – über die Checkpoints zur Technoclan-Basis. Hält Brakk beide Checkpoints geheim_cp_sek lang,
## fällt der Schild des Technoclan-HQ; Brakks Waffen und Myriaden an der Basis zerstören es → geheimes Ende.
## Das Myriaden-HQ kann weiter fallen (die Fabriken stehen dann still) und von Brakk zurückerobert werden.

var myr_hq_besetzt := false
var _myr_rueck := 0.0
var _myr_uhr := 0.0
var cp_gehalten := 0.0
var _cp_brakk: Array[float] = [0.0, 0.0]
var _cp_f := false                # 26.11. (Paul): [F] am Checkpoint gehalten
var _cp_takt := 0.0


func geheim_text() -> String:
	if myr_hq_besetzt:
		return "Myriaden-HQ besetzt – zurückerobern!"
	if o24.hq_schild_aus:
		return "Technoclan-HQ %d %%" % roundi(100.0 * o24.tc_hq_leben / maxf(1.0, o24.wf("geheim_hq_leben")))
	var n := o24.karte.cp_feind.count(true)
	return "Checkpoints %d/%d%s" % [n, o24.karte.cp_feind.size(), " · Schild fällt in %d s" % ceili(o24.wf("geheim_cp_sek") - cp_gehalten) if n == o24.karte.cp_feind.size() and n > 0 else ""]


## Funkspruch im Spiel (Steuerung bleibt frei): Zeilen wie in der Verrat-Sequenz.
func funken(zeilen: Array, danach: Callable = Callable()) -> void:
	if o24.spiel.ego == null:
		if danach.is_valid():
			danach.call()
		return
	if o24.funk != null:
		o24.funk.queue_free()
	o24.funk = Verrat24.new()
	o24.funk.zeilen = zeilen
	o24.funk.sperrt = false
	o24.add_child(o24.funk)
	o24.funk.fertig.connect(func() -> void:
		if o24.funk != null:
			o24.funk.queue_free()
		o24.funk = null
		if danach.is_valid():
			danach.call())


func _geheim_starten() -> void:
	o24.geheim = true
	o24.karte.cp_aktiv = true
	o24.karte.cp_route = true
	for i in o24.karte.cp_feind.size():
		o24.karte.cp_feind[i] = false
	o24.karte.aktualisiere_pfad()
	o24.tc_hq_leben = o24.wf("geheim_hq_leben")
	_myr_uhr = 0.0
	o24.spiel._einblendung.banner("ÜBERLÄUFER", "Brakk führt jetzt die Myriaden", Order24.MYR_FARBE)
	Ton.spiele(o24.spiel, "alert")
	# 20.11. (Paul): Der Schwarm meldet sich – Brakk versteht, was möglich ist; danach das Lichtmenü mit dem Neuen
	funken([
		["MYRIADEN-SCHWARM", "1110000 100 010010 1000 1011101010110 01 001", ""],
		["MYRIADEN-SCHWARM", "0110 1 0011100 10 111 · 1000110 0 1101", ""],
		["BRAKK", "Ich verstehe kein Wort – und doch alles. Der Feind meines Feindes …", ""],
		["BRAKK", "Gut. Ihr habt mich zum Verräter erklärt, Rat. Dann kämpfe ich eben mit denen, die ihr fürchtet.", ""],
		["SONDE 7 · FUNK", "An alle Einheiten: Kommandant Brakk hat sich mit dem Schwarm verbündet. Vernichten.", ""],
	], func() -> void: o24._lichtmenue_bis = o24.zeit + 25.0)
	print("ORDER24 Überläufer bei %.0f s" % o24.zeit)


func _geheim_pflegen(k: Kommandant, echt: float) -> void:
	# Wellenzyklus der Myriaden
	_myr_uhr += echt
	if _myr_uhr >= o24.wf("myr_takt"):
		_myr_uhr = 0.0
		o24.spiel.budget += o24.gold(int(o24.w("geheim_einkommen")))   # F4: gold_faktor
		if not myr_hq_besetzt:
			_myr_welle()
	# Brakk nimmt Checkpoints ein (er gehört jetzt zu den Myriaden) – 26.11. (Paul): [F] am Checkpoint CP_HALTEN_SEK halten
	if _cp_f and o24.cp_vor_brakk(k) < 0:
		_cp_f = false   # weggegangen
	for i in o24.karte.checkpoints.size():
		var cp: Vector2i = o24.karte.checkpoints[i]
		if o24.karte.cp_feind[i]:
			_cp_brakk[i] = 0.0
			continue
		if _cp_f and o24.karte.zelle_bei(k.position).distance_to(cp) <= 1.0 and not _technoclan_nah(o24.karte.mitte(cp), 2.0):
			_cp_brakk[i] += echt
			if _cp_brakk[i] >= Order24.CP_HALTEN_SEK:
				_cp_brakk[i] = 0.0
				_cp_f = false
				o24.spiel.checkpoint_erreicht(i)   # wird orange und wirkt wie ein Myriaden-Checkpoint im Normalspiel
				o24.spiel._einblendung.banner(tr("CHECKPOINT %d") % (i + 1), tr("Checkpoint für die Myriaden"), Order24.CP_FARBE)
		else:
			_cp_brakk[i] = 0.0 if not _cp_f else maxf(0.0, _cp_brakk[i] - echt)
	# Der Technoclan holt verlorene Checkpoints zurück: die nächsten Truppen am Boden laufen hin
	_cp_takt -= echt
	if _cp_takt <= 0.0:
		_cp_takt = 3.0
		for i in o24.karte.checkpoints.size():
			if o24.karte.cp_feind[i]:
				_rueckholer(o24.karte.checkpoints[i])
	# Beide gehalten → Schild fällt; verliert Brakk beide wieder, kommt er zurück
	var n := o24.karte.cp_feind.count(true)
	if n == o24.karte.cp_feind.size() and n > 0:
		cp_gehalten += echt
		if cp_gehalten >= o24.wf("geheim_cp_sek") and not o24.hq_schild_aus:
			o24.hq_schild_aus = true
			o24.spiel._einblendung.banner("SCHILD GEFALLEN", "Das Technoclan-HQ ist verwundbar", Order24.MYR_FARBE)
			Ton.spiele(o24.spiel, "alert")
			print("ORDER24 Schild des Technoclan-HQ gefallen bei %.0f s" % o24.zeit)
	else:
		cp_gehalten = maxf(0.0, cp_gehalten - echt)
		if n == 0 and o24.hq_schild_aus:
			o24.hq_schild_aus = false
			o24.spiel.melde("Der Technoclan hat beide Checkpoints zurück – der Schild steht wieder.", 4.0)
	# Besetztes Myriaden-HQ zurückerobern
	if myr_hq_besetzt:
		var hq := o24.karte.mitte(Werte.ANGRIFFS_ZELLE)
		if k.position.distance_to(hq) <= 2.0 * Werte.ZELLE and not _technoclan_nah(hq, 3.0):
			_myr_rueck += echt
			if _myr_rueck >= o24.wf("myr_rueck_sek"):
				myr_hq_besetzt = false
				_myr_rueck = 0.0
				o24.vorstoss_anteil = 0.0
				o24.spiel.melde("Myriaden-HQ zurückerobert – die Fabriken laufen wieder.", 4.0)
		else:
			_myr_rueck = maxf(0.0, _myr_rueck - echt)


func _technoclan_nah(p: Vector2, felder: float) -> bool:
	for e in o24._truppen():
		if (e as Node2D).position.distance_to(p) <= felder * Werte.ZELLE:
			return true
	return false


## Bis zu drei Truppen am Boden (keine Verteidiger der Basis) laufen zu einem verlorenen Checkpoint.
func _rueckholer(cp: Vector2i) -> void:
	var p := o24.karte.mitte(cp)
	var liste: Array = o24._truppen().filter(func(x: Variant) -> bool: return (x as Einheit).zustand == Einheit.Zustand.BODEN and not o24._ist_innen(x as Einheit) and x != o24.pilot and not o24.eskorte.has(x))
	liste.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_squared_to(p) < b.position.distance_squared_to(p))
	for e: Variant in liste.slice(0, 3):
		o24.alarm[(e as Node).get_instance_id()] = {"ziel": cp, "bis": o24.zeit + 15.0}


## 20.11. (Paul): Ring, in dessen Feld die Myriaden-Fabrik `z` steht ("" = keins; das zuletzt gesetzte Feld gewinnt).
func myr_ring(z: Vector2i) -> String:
	var k: Kommandant = o24.spiel.kommandant
	if k == null or k.fortschritt == null:
		return ""
	var ring := ""
	for r: String in k.fortschritt.felder:
		if BrakkFortschritt.im_feld(z, k.fortschritt.felder[r] as Vector2i):
			ring = r
	return ring


## Was die Fabrik `z` gerade baut: die Einheit des Rings, ohne Feld Hunde.
func myr_typ(z: Vector2i) -> String:
	return str(Order24.MYR_RING.get(myr_ring(z), "hund"))


## Wert, den die Fabrik `z` je Zyklus verbaut: myr_wert, ohne Ringfeld nur ein Teil, je Ringstufe mehr.
func myr_wert_von(z: Vector2i) -> float:
	var ring := myr_ring(z)
	if ring == "":
		return o24.wf("myr_wert") * o24.wf("myr_ohne_ring") / 100.0
	var st: int = o24.spiel.kommandant.fortschritt.ring_stufe(ring)
	return o24.wf("myr_wert") * (1.0 + o24.wf("myr_ring_stufe") / 100.0 * float(maxi(0, st - 1)))


## Ein Wellenzyklus: jede Myriaden-Fabrik bekommt ihren Wert gutgeschrieben und schickt so viele Einheiten los, wie das
## Guthaben hergibt (der Rest bleibt stehen) – so zählt ein Fahnenträger nicht wie ein Hund. Die Produktion kostet Gold.
func _myr_welle() -> void:
	var los := 0
	for z: Vector2i in o24.myr_fabriken:
		var fab: Dictionary = o24.myr_fabriken[z]
		var typ := myr_typ(z)
		if str(fab.get("typ", "")) != typ:
			fab["typ"] = typ
			fab["guthaben"] = 0.0   # umgestellt: von vorn
		var preis := maxi(1, Phantom.preis(typ))
		fab["guthaben"] = float(fab.get("guthaben", 0.0)) + myr_wert_von(z)
		var n := int(floorf(float(fab["guthaben"]) / float(preis) + 0.001))
		if n <= 0:
			continue
		var kosten := roundi(float(n * preis) * o24.wf("myr_kosten_anteil") / 100.0)
		if o24.spiel.budget < kosten:
			o24.spiel.melde("Zu wenig Gold für die Myriaden-Fabrik (%s): %d nötig." % [str(Werte.GEGNER[typ]["name"]), kosten], 3.0)
			fab["guthaben"] = minf(float(fab["guthaben"]), float(preis))   # nicht endlos ansparen
			continue
		o24.spiel.budget -= kosten
		fab["guthaben"] = float(fab["guthaben"]) - float(n * preis)
		for i in n:
			var g: Gegner = o24.spiel._neuer_gegner(typ, z, 0)
			g.position += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		los += n
	if los > 0:
		print("ORDER24 Myriaden-Welle bei %.0f s: %d Einheiten" % [o24.zeit, los])


func myr_preis(_typ: String = "") -> int:
	return int(o24.w("myr_fabrik_preis"))   # 20.11. (Paul): eine Fabrik, ein Preis


func _tc_hq_treffer(menge: float) -> void:
	if not o24.hq_schild_aus or o24.vorbei:
		return
	o24.tc_hq_leben -= menge
	if o24.tc_hq_leben <= 0.0:
		o24.tc_hq_leben = 0.0
		o24.geheim_sieg = true
		o24.spiel.erfolg("ueberlaeufer")   # 20.11. (Paul): Erfolg – geheimes Ende
		print("ORDER24 Technoclan-HQ zerstört bei %.0f s – geheimes Ende" % o24.zeit)
		o24._ende(true)


## Kasten in Myriaden-Farbe mit dem Bild der Einheit darüber (Platzhalter).
func _myr_3d(hd: HdAnsicht) -> void:
	for z: Vector2i in o24.myr_fabriken:
		var f: Dictionary = o24.myr_fabriken[z]
		var typ_jetzt := myr_typ(z)
		if f["knoten"] != null and str(f.get("gezeigt", typ_jetzt)) == typ_jetzt:
			continue
		if f["knoten"] != null:
			# 20.11. (Paul): das Ringfeld hat die Fabrik umgestellt – Platzhalter mit der neuen Einheit
			o24._knoten3d.erase(f["knoten"])
			(f["knoten"] as Node3D).queue_free()
		f["gezeigt"] = typ_jetzt
		var ring_jetzt := myr_ring(z)
		var kn := Node3D.new()
		hd.add_child(kn)
		kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
		o24._kasten3d(kn, Vector3(0.85, 0.6, 0.85), Color("5a2350"), Vector3(0, 0.3, 0))
		o24._kasten3d(kn, Vector3(0.6, 0.12, 0.6), Einheit.ABZEICHEN.get(ring_jetzt, Order24.MYR_FARBE) if ring_jetzt != "" else Order24.MYR_FARBE, Vector3(0, 0.66, 0))   # Deckel in Ringfarbe
		var d: Dictionary = Werte.grafik_daten(Werte.GEGNER[typ_jetzt])
		if d.has("blatt") and d.has("zelle"):
			var bild := AtlasTexture.new()
			bild.atlas = load(str(d["blatt"]))
			bild.region = Rect2(0, 0, float(d["zelle"]), float(d["zelle"]))
			var s := Sprite3D.new()
			s.texture = bild
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.pixel_size = 0.7 / float(d["zelle"])
			s.position = Vector3(0, 1.25, 0)
			kn.add_child(s)
		f["knoten"] = kn
		o24._knoten3d.append(kn)
