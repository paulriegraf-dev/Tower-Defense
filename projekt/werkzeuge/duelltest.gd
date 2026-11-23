extends SceneTree
## 23.11.: Phantom.duell_ergebnis – Reihenfolge der Ergebnisse (Elo im Phantom-Modus).
##   godot --headless --path . -s werkzeuge/duelltest.gd
var fehler: Array[String] = []

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _initialize() -> void:
	var L := Werte.START_LEBEN
	var r1 := Phantom.duell_ergebnis(L, true, 1)
	var r14 := Phantom.duell_ergebnis(L, true, 14)
	var r19 := Phantom.duell_ergebnis(L, true, 19)
	var r20 := Phantom.duell_ergebnis(L, true, 20)
	var fast := Phantom.duell_ergebnis(L - 1, false)
	var halb := Phantom.duell_ergebnis(L / 2, false)
	var null_ := Phantom.duell_ergebnis(0, false)
	var ersatz6 := Phantom.duell_ergebnis(2, false, 0, 6)
	var ersatz20 := Phantom.duell_ergebnis(2, false, 0, 20)
	print("R1 %.3f · R14 %.3f · R19 %.3f · R20 %.3f · %d/%d Leben %.3f · halb %.3f · 0 %.3f · Ersatz 6 Runden 2 Leben %.3f (voll %.3f)" % [r1, r14, r19, r20, L - 1, L, fast, halb, null_, ersatz6, ersatz20])
	pruefe(is_equal_approx(r1, 1.0), "früh geknackt = 1,0")
	pruefe(r1 > r14 and r14 > r19 and r19 > r20, "später geknackt zählt weniger")
	pruefe(is_equal_approx(r20, 0.75), "Runde 20 = 0,75")
	pruefe(r20 > fast and fast > halb and halb > null_, "nicht geknackt liegt darunter, nach Leben")
	pruefe(fast < Phantom.DUELL_SIEG_AB and r20 >= Phantom.DUELL_SIEG_AB, "Sieg-Grenze trennt geknackt / gehalten")
	pruefe(ersatz6 > ersatz20 and ersatz6 < 0.5, "Ersatz-Phantom mit wenigen Runden: gedämpft, aber noch gehalten")
	print("TEST DUELL OK" if fehler.is_empty() else "TEST DUELL FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
