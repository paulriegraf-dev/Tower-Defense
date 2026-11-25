class_name EloAnzeige
extends RefCounted
## Elo-Anzeige fürs Endbild (23.11.): Die Zahl zählt von „vorher“ nach „nachher“, daneben springt die Änderung auf
## (grün + Pfeil hoch / rot + Pfeil runter), bei Gewinn steigen Funken auf. Wartet die Antwort der Datenbank noch,
## pulsieren drei Punkte. ALLES GEZEICHNET AN EINER STELLE: Am 30.11. werden hier Sprites, Rahmen und Funken
## ausgetauscht – die Werte (Dictionary unten) bleiben gleich.
## d: {label, vorher (int), nachher (int, -1 = wartet), hinweis (Text darunter), t0 (Sekunde, ab der gezählt wird),
##     vorlaeufig (bool: „?“ hinter der Zahl)}

const Stil := preload("res://scripts/ui/ui_stil.gd")
const HOEHE := 44.0
const ZAEHL_SEK := 1.3
const GEWINN := Color("8fe39a")
const VERLUST := Color("ff7a8a")


static func _aus(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func male(ci: CanvasItem, mitte_x: float, y: float, d: Dictionary, t: float, a: float = 1.0) -> void:
	var vorher := int(d.get("vorher", 1000))
	var nachher := int(d.get("nachher", -1))
	var breite := 188.0
	var r := Rect2(mitte_x - breite / 2.0, y, breite, HOEHE - 4.0)
	Stil.platte(ci, r, 3.0, Color(Stil.METALL_TIEF, a), Color(Stil.RAHMEN, a))
	Stil.schreibe_mittig(ci, Vector2(mitte_x, y + 8.0), str(d.get("label", "ELO")), Stil.KLEIN, Color(Stil.TEXT_BLASS, a))
	var cy := y + 24.0
	if nachher < 0:
		var n := int(fmod(t * 3.0, 4.0))
		Stil.schreibe_mittig(ci, Vector2(mitte_x, cy), "%d  %s" % [vorher, ".".repeat(n)], Stil.GROSS, Color(Stil.TEXT, a))
		return
	var lauf := _aus((t - float(d.get("t0", 0.0))) / ZAEHL_SEK)
	var wert := roundi(lerpf(float(vorher), float(nachher), lauf))
	var delta := nachher - vorher
	var farbe: Color = GEWINN if delta > 0 else (VERLUST if delta < 0 else Stil.TEXT)
	# Zahl: im Zählen leuchtet sie in der Farbe der Änderung, danach ruht sie
	var glut := 1.0 - lauf
	var zahl_farbe := Stil.TEXT.lerp(farbe, 0.4 + 0.6 * glut)
	var zahl := str(wert) + ("?" if d.get("vorlaeufig", false) else "")   # 25.11.: vorläufige Elo
	Stil.schreibe_mittig(ci, Vector2(mitte_x - 22.0, cy), zahl, Stil.GROSS, Color(zahl_farbe, a))
	# Änderung: federt auf, sobald die Zahl zu zählen beginnt
	var pop := clampf((t - float(d.get("t0", 0.0))) / 0.35, 0.0, 1.0)
	var feder := 1.0 + 0.35 * sin(pop * PI) * (1.0 - pop)
	var dx := mitte_x + 30.0
	var text := ("%+d" % delta) if delta != 0 else "±0"
	if pop > 0.0:
		# Pfeil
		if delta != 0:
			var up := delta > 0
			var p := Vector2(dx - 14.0, cy + (1.0 if up else -1.0))
			var s := 4.0 * feder
			var pts := PackedVector2Array([p + Vector2(0, -s if up else s), p + Vector2(-s, 0 if up else 0), p + Vector2(s, 0)])
			ci.draw_colored_polygon(pts, Color(farbe, a * pop))
		Stil.schreibe_mittig(ci, Vector2(dx + 6.0, cy), text, Stil.GROSS, Color(farbe, a * pop))
	# Funken bei Gewinn
	if delta > 0 and lauf < 1.0 or (delta > 0 and t - float(d.get("t0", 0.0)) < ZAEHL_SEK + 0.8):
		var s0 := t - float(d.get("t0", 0.0))
		for i in 9:
			var p := fmod(s0 * 0.9 + float(i) * 0.37, 1.0)
			var px := mitte_x - 40.0 + float(i) * 10.0 + sin(s0 * 4.0 + i) * 3.0
			var py := cy + 6.0 - p * 22.0
			ci.draw_rect(Rect2(Vector2(px, py).round(), Vector2.ONE * (2.0 if i % 3 == 0 else 1.0)), Color(GEWINN, a * sin(p * PI) * 0.8))
	if str(d.get("hinweis", "")) != "":
		Stil.schreibe_mittig(ci, Vector2(mitte_x, y + HOEHE + 5.0), str(d["hinweis"]), Stil.KLEIN, Color(Stil.GOLD, a * _aus((t - float(d.get("t0", 0.0)) - 0.6) / 0.4)))
