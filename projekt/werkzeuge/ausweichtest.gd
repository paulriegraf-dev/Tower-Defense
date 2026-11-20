extends SceneTree
## 20.11.: Schritt 6c – Trefferquoten der Geschosse auf Brakk (brakk_geschosse.gd), ohne Spiel und Bild.
##
##   godot --headless --path . -s werkzeuge/ausweichtest.gd -- [Schüsse je Fall] [Abstand in Feldern]
##
## Je Art 100 Schüsse auf einen stehenden und einen seitlich laufenden Brakk (3 Felder/s, wie in der Ego-Sicht).
## Erwartung: stehend ~90 % (Laser), laufend deutlich darunter. Dazu Tumble und Sprung (Bodengeschosse).

const DT := 1.0 / 60.0
var n := 100
var abstand := 3.0
var lage := {}          # was ziel_fn liefert
var treffer := 0
var schaden := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		n = int(a[0])
	if a.size() > 1:
		abstand = float(a[1])
	print("AUSWEICHTEST  %d Schüsse je Fall, Abstand %.1f Felder, Rumpf %.2f, Streuung ±%.2f" % [n, abstand, Werte.BRAKK_RUMPF, Werte.BRAKK_STREUUNG])
	for art: String in ["laser", "sph", "plasma", "scharf", "geschuetz", "lanze"]:
		var stehend := _fall(art, 0.0, false, 0.0)
		var laufend := _fall(art, 3.0, false, 0.0)
		var zeile := "  %-10s stehend %3d %%   laufend %3d %%" % [art, roundi(stehend * 100.0), roundi(laufend * 100.0)]
		if art in ["laser", "sph", "plasma"]:
			for vh: float in [0.5, 1.0]:
				zeile += "   (Vorhalt %d %%: laufend %3d %%)" % [roundi(vh * 100.0), roundi(_fall(art, 3.0, false, 0.0, vh) * 100.0)]
		print(zeile)
	print("  Tumble (Laser, stehend, durchlässig):  %3d %%" % roundi(_fall("laser", 0.0, true, 0.0) * 100.0))
	print("  Sprung am Scheitel (Plasma, stehend):  %3d %%" % roundi(_fall("plasma", 0.0, false, 0.6) * 100.0))
	print("  Sprung am Scheitel (Laser, stehend):   %3d %%" % roundi(_fall("laser", 0.0, false, 0.6) * 100.0))
	quit(0)


## Ein Fall: n Schüsse, je Schuss ein frischer Brakk im Abstand `abstand`, der mit `tempo` Feldern/s quer zur Schusslinie läuft.
func _fall(art: String, tempo: float, durchlass: bool, sprung: float, vorhalt: float = Werte.BRAKK_VORHALT) -> float:
	var bg := BrakkGeschosse.new()
	bg.zufall.seed = 24
	bg.vorhalt = vorhalt
	bg.ziel_fn = func() -> Dictionary: return lage
	bg.treffer_fn = func(menge: float, _typ: String) -> void:
		treffer += 1
		schaden += menge
	var von := Vector2.ZERO
	var getroffen := 0
	for i in n:
		var pos := Vector2(abstand * Werte.ZELLE, 0.0)
		var richtung := 1.0 if i % 2 == 0 else -1.0
		lage = {"pos": pos, "sprung": sprung, "fuss": sprung, "durchlass": durchlass, "v": Vector2(0.0, richtung * tempo * Werte.ZELLE)}
		treffer = 0
		match art:
			"scharf":
				bg.scharf(null, von, 0.45, (abstand + 2.0) * Werte.ZELLE, 38.0, "test")
			"geschuetz", "lanze":
				bg.turm(Vector2i.ZERO, von, art, 16.0, (abstand + 1.0) * Werte.ZELLE, (0.25 if art == "lanze" else Werte.BRAKK_TURM_BREITE) * Werte.ZELLE, 1, "test")
			_:
				bg.schiesse(art, von, 0.45, 10.0, art, "test")
		var t := 0.0
		while (not bg.geschosse.is_empty() or not bg.zielstrahlen.is_empty() or not bg.gluehen.is_empty()) and t < 5.0:
			pos.y += richtung * tempo * Werte.ZELLE * DT
			lage["pos"] = pos
			bg.weiter(DT)
			t += DT
		bg.braende.clear()   # Brandfläche zählt hier nicht mit (nur der Einschlag)
		if treffer > 0:
			getroffen += 1
	bg.free()
	return float(getroffen) / float(n)
