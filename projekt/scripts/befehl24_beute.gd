class_name BefehlBeute
extends RefCounted
## Beute aus zerstörten Fabriken in Befehl 24 (25.11.; 27.11. Knoten-Umbau 7e – vorher in order24.gd): Beutearten,
## Pflege, Sabotage und Einnahme mit 3D-Marken, Kopfgeld und Prämie. Regeln unverändert; beute_legen, gold usw. (von
## außen genutzt) bleiben in order24.gd. Teil von Befehl 24 (`o24.beutewerk`, angelegt in Order24._init).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var o24: Order24


func _init(e: Order24) -> void:
	o24 = e


func _beute_waehlen(b: Dictionary) -> void:
	var f: BrakkFortschritt = o24.spiel.kommandant.fortschritt if o24.spiel.kommandant != null else null
	b["stufe"] = false
	b["ring"] = ""
	if f == null:
		return
	var arten := o24.beute_arten()
	if f.ringe.size() >= BrakkFortschritt.FINGER_AB.size() or arten.is_empty():
		var hoeher: Array = f.ringe.filter(func(r: String) -> bool: return f.ring_stufe(r) < BrakkFortschritt.RING_PREISE.size())
		if not hoeher.is_empty():
			b["ring"] = str(hoeher.pick_random())
			b["stufe"] = true
		return
	b["ring"] = str(arten.pick_random())


## Aufheben durch Drüberlaufen. Ohne freien Finger bleibt der Ring liegen.
func _beute_pflegen(k: Kommandant) -> void:
	var f := k.fortschritt
	for b: Dictionary in o24.beute_boden.duplicate():
		var ring := str(b["ring"])
		if bool(b.get("herausforderer", false)) and f != null and ((bool(b["stufe"]) and (ring == "" or f.ring_stufe(ring) == 0 or f.ring_stufe(ring) >= BrakkFortschritt.RING_PREISE.size())) or (not bool(b["stufe"]) and ring != "" and (f.ring_stufe(ring) > 0 or f.ringe.size() >= BrakkFortschritt.FINGER_AB.size()))):
			_beute_waehlen(b)   # am Terminal verändert: neu bestimmen
			ring = str(b["ring"])
			_beute_bild_weg(b)
		elif not bool(b.get("herausforderer", false)) and ring != "" and f != null and f.ring_stufe(ring) > 0:
			# inzwischen am Terminal gekauft: eine andere neue Art (sonst gäbe das Aufheben eine Stufe)
			b["ring"] = ""
			var arten := o24.beute_arten()
			ring = str(arten.pick_random()) if not arten.is_empty() else ""
			b["ring"] = ring
			_beute_bild_weg(b)
		if k.gefallen or k.position.distance_to(b["pos"] as Vector2) > Order24.BEUTE_NAH * Werte.ZELLE:
			continue
		if ring == "":
			var geborgen := o24.gold(int(o24.wf("praemie_fabrik") * Order24.BEUTE_GOLD_ANTEIL))   # F4: gold_faktor
			o24.spiel.budget += geborgen
			o24.sabotage["geld"] = int(o24.sabotage["geld"]) + geborgen
			o24.spiel.melde("Gold geborgen: +%d" % geborgen, 3.0)
		elif bool(b.get("stufe", false)):
			if f == null or f.schenke_stufe(ring, o24.spiel) != "":
				continue
			o24.spiel.melde("Ring geborgen: %s – jetzt Stufe %d" % [str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring)), f.ring_stufe(ring)], 4.0)
		else:
			if f == null:
				continue
			if f.ringe.size() >= f.finger():
				if o24.zeit - float(b["hinweis"]) > 4.0:
					b["hinweis"] = o24.zeit
					o24.spiel.melde("Kein Finger frei – der Ring bleibt liegen.", 2.5)
				continue
			if f.schenke(ring, o24.spiel) != "":
				continue
			o24.spiel.melde("Ring geborgen: %s" % str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring)), 4.0)
		Ton.spiele(o24.spiel, "tc-arc", -2.0)
		_beute_bild_weg(b)
		o24.beute_boden.erase(b)


func _beute_bild_weg(b: Dictionary) -> void:
	if b["knoten"] != null and is_instance_valid(b["knoten"]):
		(b["knoten"] as Node).queue_free()
	b["knoten"] = null


## 25.11. (Paul): Eine sabotierte Fabrik sieht man an: Rauchsäule aus dem Dach, die Leuchtleiste am Sockel ist aus
## (abgedunkelt ist ihr Bild schon durch HdAnsicht, ein laufendes Förderband hat es nicht) – bis zur Reparatur.
func _sabotage_3d(hd: HdAnsicht) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for z: Vector2i in o24._rauch3d.keys():
		if not o24.lahm.has(z) or not o24.fabrik_hp.has(z):
			(o24._rauch3d[z] as Node).queue_free()
			o24._rauch3d.erase(z)
	for z: Vector2i in o24.lahm:
		if not o24.fabrik_hp.has(z):
			continue
		if not o24._rauch3d.has(z):
			var kn := Node3D.new()
			hd.add_child(kn)
			kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
			o24._kasten3d(kn, Vector3(0.6, 0.036, 0.018), Color("14161b"), Vector3(0, 0.065, 0.468))   # über der Leuchtleiste (_fabrik_block)
			for i in 9:
				var m := MeshInstance3D.new()
				var kugel := SphereMesh.new()
				kugel.radius = 0.24
				kugel.height = 0.48
				kugel.radial_segments = 10
				kugel.rings = 5
				m.mesh = kugel
				m.material_override = o24._leucht(Color("7a7a86"), 0.9)
				m.name = "Qualm%d" % i
				kn.add_child(m)
			o24._rauch3d[z] = kn
		for i in 9:
			var q := (o24._rauch3d[z] as Node3D).get_node("Qualm%d" % i) as MeshInstance3D
			var a := fmod(t * 0.3 + float(i) / 9.0, 1.0)
			q.position = Vector3(0.12 + 0.35 * a + 0.07 * sin(t * 1.7 + float(i) * 2.1), 1.15 + 2.1 * a, 0.0)
			q.scale = Vector3.ONE * (0.45 + 0.9 * a)
			(q.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - 0.8 * a)


## 26.11. (Paul): Einnahme-Ring über dem Myriaden-HQ – Billboard in Technoclan-Lila, füllt sich im Uhrzeigersinn
## (von oben). Das Bild wird nur neu gemalt, wenn sich der Prozentwert ändert.
func _einnahme_3d(hd: HdAnsicht) -> void:
	var zeigen := o24.einnahme_sichtbar()
	if o24._ring3d == null:
		if not zeigen:
			return
		o24._ring3d = Sprite3D.new()
		o24._ring3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		o24._ring3d.shaded = false
		o24._ring3d.no_depth_test = true   # auch hinter dem HQ-Dach sichtbar
		o24._ring3d.pixel_size = 0.9 / float(Order24.RING_BILD)   # knapp ein Feld groß (1,6 verdeckte von nah die Phasenzeile)
		var p := o24.karte.mitte(Werte.ANGRIFFS_ZELLE)
		o24._ring3d.position = Vector3(p.x / Werte.ZELLE, Order24.VORSTOSS_RING_HOEHE, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		hd.add_child(o24._ring3d)
	o24._ring3d.visible = zeigen
	var pz := floori(100.0 * o24.vorstoss_anteil)
	if zeigen and pz != o24._ring_prozent:
		o24._ring_prozent = pz
		o24._ring3d.texture = ImageTexture.create_from_image(o24.ring_bild(o24.vorstoss_anteil))


## Darstellung: Lichtsäule und Bodenscheibe in der Ringfarbe, darüber schwebt der Ring (Gold: ein goldener Würfel).
func _beute_3d(hd: HdAnsicht) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for b: Dictionary in o24.beute_boden:
		var ring := str(b["ring"])
		var farbe: Color = Order24.BEUTE_GOLD_FARBE if ring == "" else Einheit.ABZEICHEN.get(ring, Order24.BEUTE_GOLD_FARBE)
		if b["knoten"] == null:
			var kn := Node3D.new()
			hd.add_child(kn)
			var p: Vector2 = b["pos"]
			kn.position = Vector3(p.x / Werte.ZELLE, 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
			for teil: Array in [[0.12, 3.0, 0.4, 1.5], [0.28, 3.0, 0.16, 1.5], [0.45, 0.03, 0.55, 0.3]]:
				var m := MeshInstance3D.new()
				var zyl := CylinderMesh.new()
				zyl.top_radius = float(teil[0])
				zyl.bottom_radius = float(teil[0])
				zyl.height = float(teil[1])
				m.mesh = zyl
				m.material_override = o24._leucht(farbe, float(teil[2]))
				m.position = Vector3(0, float(teil[3]), 0)
				kn.add_child(m)
			var oben: Node3D
			if ring == "":
				oben = o24._kasten3d(kn, Vector3(0.28, 0.28, 0.28), farbe, Vector3(0, 0.75, 0))
			else:
				var s := Sprite3D.new()
				s.texture = RingBilder.bild(ring, farbe)
				s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				s.shaded = false
				s.pixel_size = 0.55 / 16.0
				kn.add_child(s)
				oben = s
			oben.name = "Oben"
			b["knoten"] = kn
		var schwebt := (b["knoten"] as Node3D).get_node("Oben") as Node3D
		schwebt.position.y = 0.75 + 0.09 * sin(t * 3.0)
		if ring == "":
			schwebt.rotation.y = t * 1.8


var _kopfgeld_merk := {}   # Ort ("s:<Stellung>" / "f:<Fabrik>") -> [Kills in Folge, Zeit des letzten Kills]

## 20.11. (Paul): Kopfgeld je Kill. An derselben Stellung (am Boden: Truppen derselben Fabrik) sinkt es je kill_stufe Kills
## um 1; nach kill_frist Sekunden ohne Kill dort ist es wieder voll.
func _kopfgeld(ort: String, mal: int = 1) -> void:
	var voll := int(o24.w("praemie_kill"))
	if voll <= 0:
		return
	var m: Array = _kopfgeld_merk.get(ort, [0, -999.0])
	var n := int(m[0]) if o24.zeit - float(m[1]) < o24.wf("kill_frist") else 0
	if ort.begins_with("f:"):
		n = 0   # 20.11. (Paul): Truppen am Boden bringen immer das volle Kopfgeld – nur Stellungen nutzen sich ab
	var betrag := o24.gold(maxi(0, voll - int(n / maxf(1.0, o24.wf("kill_stufe")))) * mal)   # F4: gold_faktor
	_kopfgeld_merk[ort] = [n + 1, o24.zeit]
	if betrag > 0:
		o24.sabotage["geld"] = int(o24.sabotage["geld"]) + betrag
		o24.spiel.budget += betrag   # ohne Meldung: sie würde wichtigere Zeilen verdrängen – das Budget oben zählt mit


var _gold_rest := 0.0


func _praemie(was: String, betrag: int, text: String, xp: int = 0) -> void:
	betrag = o24.gold(betrag)   # F4 (26.11., Paul): gold_faktor
	o24.sabotage[was] = int(o24.sabotage[was]) + 1
	o24.sabotage["geld"] = int(o24.sabotage["geld"]) + betrag
	o24.spiel.budget += betrag
	var k: Kommandant = o24.spiel.kommandant
	if xp > 0 and k != null and k.fortschritt != null:
		k.fortschritt.gib(xp, k)   # 20.11. (Paul): eher Erfahrung als Geld
	var teile: PackedStringArray = []
	if betrag > 0:
		teile.append("+%d" % betrag)
	if xp > 0:
		teile.append("+%d Erfahrung" % xp)
	o24.spiel.melde(text + (": " + " · ".join(teile) if not teile.is_empty() else ""), 2.0)
