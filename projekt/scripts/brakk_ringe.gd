class_name BrakkRinge
extends RefCounted
## Ringe im Brakk-Mode (18./19.11.; 27.11. Knoten-Umbau 7b – vorher in ego_modus.gd): Ringe tragen und wählen
## (Mausrad), Lichtterminal an der Basis (kaufen, aufwerten), Ringfelder [C] (zielen, werfen, wirken), Zeitlupe je Ring
## und Ringklinge. Regeln unverändert. Teil der Ego-Sicht wie EgoKit (`ego.ringwerk`, angelegt in EgoModus._init).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var ego: EgoModus


func _init(e: EgoModus) -> void:
	ego = e


## Rechter Rand, unter der Minikarte: je Finger ein Platz – Ring mit Namen, frei oder gesperrt (ab Stufe).
func _ringleiste(g: Vector2) -> void:
	var f := ego.brakk.fortschritt
	if f == null:
		return
	var zeile := 40.0
	var breite := 220.0
	var x := g.x - breite - 14.0
	var y := roundf(g.y * 0.36)
	var hinter := Rect2(x - 6.0, y - 30.0, breite + 12.0, zeile * 5.0 + 36.0)
	ego._bild.draw_rect(hinter, Color(0.04, 0.05, 0.08, 0.6))
	Stil.schreibe(ego._bild, Vector2(x, y - 14.0), "RINGE", 18, Stil.GOLD)
	for i in 5:
		var r := Rect2(x, y + i * zeile, breite, zeile - 4.0)
		var mi := Vector2(r.position.x + 20.0, r.get_center().y)
		if i < f.ringe.size():
			var ring := f.ringe[i]
			var farbe := ego._ring_farbe(ring)
			ego._bild.draw_rect(r, Color(farbe, 0.12))
			if i == f.gewaehlt:
				ego._bild.draw_rect(r, farbe, false, 2.0)   # aktiv: wirkt auf Brakks Pistolen, [C] setzt sein Feld
			var zusatz := "St.%d" % f.ring_stufe(ring) + (" · Feld" if f.felder.has(ring) else "")
			Stil.schreibe(ego._bild, Vector2(r.end.x - 8.0 - Stil.breite(zusatz, 14), r.get_center().y), zusatz, 14, farbe)
			ego._male_ring(ego._bild, mi, 13.0, ring)
			Stil.schreibe(ego._bild, Vector2(r.position.x + 40.0, r.get_center().y), str(BrakkFortschritt.RINGE[ring]["name"]), 18, farbe)
		elif i < f.finger():
			ego._bild.draw_arc(mi, 9.0, 0.0, TAU, 20, Stil.TEXT_BLASS, 1.5)
			Stil.schreibe(ego._bild, Vector2(r.position.x + 40.0, r.get_center().y), "frei – Terminal", 16, Stil.TEXT_BLASS)
		else:
			ego._bild.draw_arc(mi, 9.0, 0.0, TAU, 20, Color(0.3, 0.32, 0.36), 1.5)
			Stil.schreibe(ego._bild, Vector2(r.position.x + 40.0, r.get_center().y), "ab Stufe %d" % int(BrakkFortschritt.FINGER_AB[i]), 16, Color(0.4, 0.42, 0.47))
	if not f.ringe.is_empty():
		Stil.schreibe(ego._bild, Vector2(x, hinter.end.y + 12.0), "Mausrad: aktiver Ring" if ego.spiel.order24 != null else "Mausrad: aktiver Ring · [C] Feld (Bauphase)", 14, Stil.TEXT_BLASS)


## Steht Brakk in der Bauphase an der Basis? Dann öffnet [F] das Lichtterminal.
func _am_terminal() -> bool:
	if ego.spiel.order24 != null:
		return ego.brakk.fortschritt != null and not ego.brakk.oben and ego.spiel.order24.am_terminal(ego._fuss2d())   # 20.11.: Ringterminal in Order 24, auch im Kampf
	if ego.brakk.fortschritt == null or ego.spiel.phase != 0 or ego.karte.basis == Karte.KEINE or ego.brakk.oben:
		return false
	return ego._fuss2d().distance_to(ego.karte.mitte(ego.karte.basis)) <= 2.5 * Werte.ZELLE


func _terminal_auf() -> void:
	if ego._terminal == null:
		ego._terminal = Control.new()
		ego._terminal.set_anchors_preset(Control.PRESET_FULL_RECT)
		ego._terminal.mouse_filter = Control.MOUSE_FILTER_STOP
		ego._terminal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ego._terminal.draw.connect(_male_terminal)
		ego._terminal.gui_input.connect(_terminal_klick)
		ego._ebene.add_child(ego._terminal)
	ego._terminal.visible = true
	ego._terminal.queue_redraw()
	ego._feuer = false
	ego._lanze = -1.0
	Ton.spiele(ego.spiel, "ui-klick")


func _terminal_klick(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var b := event as InputEventMouseButton
	if not b.pressed or b.button_index != MOUSE_BUTTON_LEFT:
		return
	for k: Array in ego._knoepfe:
		if (k[0] as Rect2).has_point(b.position):
			(k[1] as Callable).call()
			Ton.spiele(ego.spiel, "ui-klick")
			ego._terminal.queue_redraw()
			return


func _kaufe(ring: String) -> void:
	var grund := ego.brakk.fortschritt.kaufe(ring, ego.spiel)
	if grund != "":
		ego.spiel.melde(grund, 2.5)
	else:
		var st := ego.brakk.fortschritt.ring_stufe(ring)
		ego.spiel.melde(("%s angesteckt." if st == 1 else "%s auf Stufe " + str(st) + ".") % str(BrakkFortschritt.RINGE[ring]["name"]), 2.5)

## 20.11. (Nachtrag): Irrtürmer – Kauf in den gewählten Satz (Held oder PliPlop), Ausbau und Verkauf je Stelle.
var _kauf_satz := "held"


func _kaufe_satz(ring: String) -> void:
	var grund := ego.brakk.fortschritt.kaufe_in(_kauf_satz, ring, ego.spiel)
	ego.spiel.melde(grund if grund != "" else "%s für %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), "den Irrtürmer" if _kauf_satz == "held" else "PliPlop"], 2.5)


func _baue_satz_aus(satz: String, i: int) -> void:
	var grund := ego.brakk.fortschritt.baue_aus(satz, i, ego.spiel)
	if grund != "":
		ego.spiel.melde(grund, 2.5)


func _verkaufe_satz(satz: String, i: int) -> void:
	ego.brakk.fortschritt.verkaufe_in(satz, i, ego.spiel)


func _waehle_satz(satz: String, i: int) -> void:
	if satz == "pp":
		ego.brakk.fortschritt.waehle_pp(i)
	else:
		ego.brakk.fortschritt.gewaehlt = i
		ego.brakk.fortschritt.wechsel_rest = BrakkFortschritt.WECHSEL_SEK


func _verkaufe(ring: String) -> void:
	ego.brakk.fortschritt.verkaufe(ring, ego.spiel)


func _terminal_zu() -> void:
	ego._terminal.visible = false


## Tafel in der Mitte: links Brakks Finger (Verkaufen), rechts alle Ringe (Kaufen).
func _male_terminal() -> void:
	var f := ego.brakk.fortschritt
	var ci := ego._terminal
	var g := ci.get_viewport_rect().size
	ego._knoepfe.clear()
	var w := minf(980.0, g.x - 60.0)
	var h := minf(560.0, g.y - 90.0)
	var o := ((g - Vector2(w, h)) / 2.0).round()
	ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0, 0, 0, 0.45))
	ci.draw_rect(Rect2(o, Vector2(w, h)), Color(0.05, 0.06, 0.1, 0.96))
	ci.draw_rect(Rect2(o, Vector2(w, h)), EgoModus.LICHT, false, 2.0)
	Stil.schreibe(ci, o + Vector2(18, 24), "LICHTTERMINAL", 26, EgoModus.LICHT)
	var irr := f.anfuehrer == "irrtuermer"   # 20.11.
	Stil.schreibe(ci, o + Vector2(230, 24), "Ringe für Hand und PliPlop" if irr else ("Ringe für die Hand von " + Anfuehrer.name(f.anfuehrer) if f.anfuehrer != "brakk" else "Ringe für Brakks linke Hand"), 18, Stil.TEXT_BLASS)
	var bud := "Budget %d" % int(ego.spiel.budget)
	Stil.schreibe(ci, o + Vector2(w - 18.0 - Stil.breite(bud, 22), 24), bud, 22, Stil.GOLD)
	var zu := Rect2(o + Vector2(w - 150.0, h - 44.0), Vector2(132, 30))
	ci.draw_rect(zu, EgoModus.LICHT, false, 1.5)
	Stil.schreibe_mittig(ci, zu.get_center(), "Schließen [F]", 16, EgoModus.LICHT)
	ego._knoepfe.append([zu, _terminal_zu])
	# links: Finger
	var lx := o.x + 18.0
	var ly := o.y + 58.0
	if irr:
		_terminal_saetze(ci, lx, ly)   # 20.11. (Nachtrag): zwei Sätze zu je vier Ringen
	else:
		Stil.schreibe(ci, Vector2(lx, ly), "Brakks Finger (Stufe %d)" % f.stufe, 18, Stil.GOLD)
	for i in (0 if irr else 5):
		var r := Rect2(lx, ly + 18.0 + i * 62.0, 270.0, 56.0)
		ci.draw_rect(r, Color(1, 1, 1, 0.04))
		var mi := Vector2(r.position.x + 28.0, r.get_center().y)
		if i < f.ringe.size():
			var ring := f.ringe[i]
			var farbe := ego._ring_farbe(ring)
			ci.draw_rect(r, Color(farbe, 0.6), false, 1.5)
			ego._male_ring(ci, mi, 20.0, ring)
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.position.y + 16.0), str(BrakkFortschritt.RINGE[ring]["name"]), 18, farbe)
			var vk := Rect2(r.position.x + 56.0, r.position.y + 30.0, 150.0, 22.0)
			ci.draw_rect(vk, Stil.TEXT_BLASS, false, 1.0)
			Stil.schreibe_mittig(ci, vk.get_center(), "Verkaufen +%d" % f.erstattung(ring, int(ego.spiel.welle)), 14, Stil.TEXT)
			ego._knoepfe.append([vk, _verkaufe.bind(ring)])
		elif i < f.finger():
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.get_center().y), "frei", 18, Stil.TEXT_BLASS)
		else:
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.get_center().y), "ab Stufe %d" % int(BrakkFortschritt.FINGER_AB[i]), 18, Color(0.4, 0.42, 0.47))
	var erklaerung := "Alle getragenen Ringe stärken Brakks Pistolen. Der aktive Ring (Mausrad) bestimmt die Fähigkeiten; [C] setzt in der Bauphase sein Feld (2×2) – Fabriken darin bauen seine Truppe."
	if irr:
		erklaerung = "Je 4 Ringe für Irrtürmer und PliPlop, derselbe Ring auch mehrfach (wirkt mehrfach). Alle Ringe eines Satzes wirken; der aktive des PliPlop wählt seinen Pfad. Klick auf einen Ring: aktiv. [V] tauscht die aktiven, [C] setzt das Feld des Helden."   # 20.11. (Nachtrag)
	elif f.anfuehrer == "sonde7":
		erklaerung = "Der aktive Ring (Mausrad) färbt Farblaser und Energiebündel und die Treffer der Zielerfassung; gerufene Waffen bekommen nur sein Geschossbild. [C] setzt in der Bauphase sein Feld (2×2)."   # 20.11.
	Stil.absatz(ci, Vector2(lx, ly + (392.0 if irr else 340.0)), erklaerung, 270.0, 14, Stil.TEXT_BLASS)
	if irr:
		# 20.11. (Nachtrag): Kauf für welchen Satz?
		for k in 2:
			var satz := "held" if k == 0 else "pp"
			var kr := Rect2(o.x + w - 470.0 + k * 128.0, o.y + 10.0, 120.0, 28.0)
			var an := _kauf_satz == satz
			ci.draw_rect(kr, Color(Stil.GOLD, 0.2) if an else Color(0, 0, 0, 0.2))
			ci.draw_rect(kr, Stil.GOLD if an else Stil.TEXT_BLASS, false, 2.0 if an else 1.0)
			Stil.schreibe_mittig(ci, kr.get_center(), ("für Irrtürmer" if k == 0 else "für PliPlop"), 15, Stil.GOLD if an else Stil.TEXT_BLASS)
			ego._knoepfe.append([kr, func() -> void: _kauf_satz = satz])
	# rechts: alle Ringe
	var rx := o.x + 310.0
	var rw := w - 330.0
	var zh := minf(62.0, (h - 120.0) / float(BrakkFortschritt.RINGE.size()))
	var i2 := 0
	for ring: String in BrakkFortschritt.RINGE:
		var d: Dictionary = BrakkFortschritt.RINGE[ring]
		var farbe := ego._ring_farbe(ring)
		var r := Rect2(rx, ly + i2 * zh, rw, zh - 6.0)
		ci.draw_rect(r, Color(farbe, 0.07))
		ego._male_ring(ci, Vector2(r.position.x + 26.0, r.get_center().y), minf(20.0, zh * 0.34), ring)
		Stil.schreibe(ci, Vector2(r.position.x + 52.0, r.position.y + zh * 0.22), str(d["name"]), 18, farbe)
		var st := f.ring_stufe(ring)
		# 19.11. (Paul): zeigt die Stufe, die man als Nächstes bekommt (gekauft: die nächste, auf Stufe 3 diese) – Brakk UND Feld
		var zeig := 1 if irr else mini(3, st + 1)   # 20.11. (Nachtrag): Irrtürmer kauft immer Stufe 1
		var vorsatz := ("St. %d – " % zeig) if st < 3 or irr else ""
		Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.22), vorsatz + ("Held: " if irr else "Brakk: ") + BrakkFortschritt.brakk_text(ring, zeig), 14, Stil.TEXT)
		if ego.spiel.order24 == null:   # 20.11. (Paul): in Befehl 24 gibt es kein Ringfeld (Brakk baut nichts)
			Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.58), "Feld: " + ego._ring_fabrik_text(ring, zeig), 14, Stil.TEXT_BLASS)
		elif _myr_feld():   # … außer im Überläufer-Verlauf: dort bestimmt der Ring die Myriaden-Einheit
			var o24: Order24 = ego.spiel.order24
			Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.58), "Feld: " + o24.myr_takt_text(str(Order24.MYR_RING.get(ring, "hund")),
				o24.wf("myr_wert") * (1.0 + o24.wf("myr_ring_stufe") / 100.0 * float(zeig - 1))), 14, Stil.TEXT_BLASS)
		var kb := Rect2(r.end.x - 130.0, r.get_center().y - 13.0, 122.0, 26.0)
		if irr:
			# 20.11. (Nachtrag): jeder Kauf ist ein neuer Ring (Stufe 1) im gewählten Satz; ausgebaut wird links
			var preis1 := int(BrakkFortschritt.RING_PREISE[0])
			var geht1 := int(ego.spiel.budget) >= preis1 and f.satz_ringe(_kauf_satz).size() < BrakkFortschritt.SATZ_MAX
			ci.draw_rect(kb, Color(Stil.GOLD, 0.15) if geht1 else Color(0, 0, 0, 0.2))
			ci.draw_rect(kb, Stil.GOLD if geht1 else Stil.TEXT_BLASS, false, 1.5)
			Stil.schreibe_mittig(ci, kb.get_center(), "Kaufen %d" % preis1, 16, Stil.GOLD if geht1 else Stil.TEXT_BLASS)
			ego._knoepfe.append([kb, _kaufe_satz.bind(ring)])
		elif st >= BrakkFortschritt.RING_PREISE.size():
			Stil.schreibe_mittig(ci, kb.get_center(), "Stufe 3", 16, farbe)
		else:
			var preis := int(BrakkFortschritt.RING_PREISE[st])
			var geht := int(ego.spiel.budget) >= preis and (st > 0 or f.ringe.size() < f.finger())
			ci.draw_rect(kb, Color(Stil.GOLD, 0.15) if geht else Color(0, 0, 0, 0.2))
			ci.draw_rect(kb, Stil.GOLD if geht else Stil.TEXT_BLASS, false, 1.5)
			var knopf := "Kaufen %d" % preis if st == 0 else "Stufe %d: %d" % [st + 1, preis]
			Stil.schreibe_mittig(ci, kb.get_center(), knopf, 16, Stil.GOLD if geht else Stil.TEXT_BLASS)
			ego._knoepfe.append([kb, _kaufe.bind(ring)])
		if st > 0 and not irr:
			Stil.schreibe(ci, Vector2(r.position.x + 52.0, r.position.y + zh * 0.6), "St. %d" % st, 14, farbe)
		i2 += 1


## 20.11. (Nachtrag): linke Spalte des Terminals beim Irrtürmer – zwei Sätze zu je vier Ringen. Je Ring: Ausbau, Verkaufen,
## Klick auf den Namen macht ihn aktiv.
func _terminal_saetze(ci: Control, lx: float, ly: float) -> void:
	var f := ego.brakk.fortschritt
	var zh := 40.0
	for si in 2:
		var satz := "held" if si == 0 else "pp"
		var y0 := ly + si * (zh * float(BrakkFortschritt.SATZ_MAX) + 30.0)
		var liste := f.satz_ringe(satz)
		Stil.schreibe(ci, Vector2(lx, y0), ("Irrtürmer (%d/%d)" if si == 0 else "PliPlop (%d/%d)") % [liste.size(), BrakkFortschritt.SATZ_MAX], 18, Stil.GOLD)
		for i in BrakkFortschritt.SATZ_MAX:
			var r := Rect2(lx, y0 + 12.0 + i * zh, 270.0, zh - 4.0)
			ci.draw_rect(r, Color(1, 1, 1, 0.04))
			if i >= liste.size():
				Stil.schreibe(ci, Vector2(r.position.x + 40.0, r.get_center().y), "frei", 15, Stil.TEXT_BLASS)
				continue
			var ring := liste[i]
			var farbe := ego._ring_farbe(ring)
			var st := f.satz_stufe(satz, i)
			if i == f.satz_gewaehlt(satz):
				ci.draw_rect(r, farbe, false, 2.0)
			ego._male_ring(ci, Vector2(r.position.x + 18.0, r.get_center().y), 12.0, ring)
			var nr := Rect2(r.position.x + 34.0, r.position.y, 100.0, r.size.y)
			Stil.schreibe(ci, Vector2(nr.position.x, r.get_center().y - 6.0), EgoModus.ring_kurz(ring), 15, farbe)
			Stil.schreibe(ci, Vector2(nr.position.x, r.get_center().y + 8.0), "St. %d" % st + (" · aktiv" if i == f.satz_gewaehlt(satz) else ""), 13, Stil.TEXT_BLASS)
			ego._knoepfe.append([nr, _waehle_satz.bind(satz, i)])
			var ab := Rect2(r.position.x + 136.0, r.position.y + 6.0, 62.0, r.size.y - 12.0)
			if st < BrakkFortschritt.RING_PREISE.size():
				var preis := int(BrakkFortschritt.RING_PREISE[st])
				var geht := int(ego.spiel.budget) >= preis
				ci.draw_rect(ab, Stil.GOLD if geht else Stil.TEXT_BLASS, false, 1.0)
				Stil.schreibe_mittig(ci, ab.get_center(), "St%d %d" % [st + 1, preis], 13, Stil.GOLD if geht else Stil.TEXT_BLASS)
				ego._knoepfe.append([ab, _baue_satz_aus.bind(satz, i)])
			var vk := Rect2(r.position.x + 202.0, r.position.y + 6.0, 64.0, r.size.y - 12.0)
			ci.draw_rect(vk, Stil.TEXT_BLASS, false, 1.0)
			Stil.schreibe_mittig(ci, vk.get_center(), "Verk. %d" % f.satz_erstattung(satz, i, int(ego.spiel.welle)), 13, Stil.TEXT)
			ego._knoepfe.append([vk, _verkaufe_satz.bind(satz, i)])


# ------------------------------------------------------------------ Brakk-Mode: Ringfelder (18.11.)


## Mausrad: nächster / vorheriger Ring; die Hand hebt sich und zeigt ihn.
## 18.11.: Mausrad und Touchpad – Anteile sammeln, eine volle Raste wechselt den Ring (Maus: jede Raste).
func _rad(richtung: int, anteil: float) -> void:
	var jetzt := Time.get_ticks_msec() / 1000.0
	if jetzt - ego._rad_zuletzt < EgoModus.RAD_PAUSE:
		ego._rad_summe = 0.0
		return
	if signf(ego._rad_summe) != float(richtung):
		ego._rad_summe = 0.0
	ego._rad_summe += anteil * richtung
	if absf(ego._rad_summe) >= 1.0:
		ego._rad_summe = 0.0
		ego._rad_zuletzt = jetzt
		_ring_waehlen(richtung)


func _ring_waehlen(schritt: int) -> void:
	var f := ego.brakk.fortschritt
	if f == null or f.ringe.is_empty():
		if f != null:
			ego.spiel.melde("Noch kein Ring – am Lichtterminal der Basis kaufen ([F] an der Basis in der Bauphase).", 2.5)
		return
	f.gewaehlt = posmod(f.gewaehlt + schritt, f.ringe.size())
	f.wechsel_rest = BrakkFortschritt.WECHSEL_SEK   # 18.11. (Paul): kurz schütteln, erst dann wirkt der neue Ring
	ego._hand_zeigen = 1.6
	ego._ring_blitz = 0.3
	Ton.spiele(ego.spiel, "ui-klick", -6.0)


## 19.11. (Paul): [C] in der Bauphase – das Ringfeld ist ein festes 2×2-Felder-Rechteck (höchstens 4 Fabriken).
## Erstes [C]: Vorschau rastet auf das Feldraster ein, betroffene Fabriken leuchten, Anzeige „3/4 Fabriken“.
## Zweites [C] oder Linksklick bestätigt, Rechtsklick oder Esc bricht ab. Solange wird nicht geschossen.
var _feld_zielt := false
var _feld_ecke := Vector2i.ZERO
var _feld_marken: Array = []     # leuchtende Kästen über den betroffenen Fabriken (Vorschau)


func _wirf_feld() -> void:
	if _feld_zielt:
		_feld_bestaetigen()
		return
	var f := ego.brakk.fortschritt
	if f == null:
		return
	if f.ringe.is_empty():
		ego.spiel.melde("Noch kein Ring – am Lichtterminal der Basis kaufen ([F] an der Basis in der Bauphase).", 2.5)
		return
	if ego.spiel.phase != 0 and not _myr_feld():
		ego.spiel.melde("Ringfelder setzt du in der Bauphase – in der Welle liegen sie fest.", 2.0)
		return
	f.gewaehlt = clampi(f.gewaehlt, 0, f.ringe.size() - 1)
	_feld_zielt = true
	ego._feuer = false
	Ton.spiele(ego.spiel, "ui-klick", -4.0)


## 20.11. (Paul): Befehl 24, Überläufer – das Ringfeld gilt den Myriaden-Fabriken und lässt sich jederzeit werfen.
func _myr_feld() -> bool:
	return ego.spiel.order24 != null and ego.spiel.order24.geheim


func _feld_abbrechen() -> void:
	_feld_zielt = false
	if ego._vorschau != null:
		ego._vorschau.visible = false
	for m: Node3D in _feld_marken:
		m.visible = false


## Linke obere Zelle des 2×2-Rechtecks, dessen Mitte (eine Rasterecke) dem Fadenkreuz am nächsten liegt.
func _feld_ecke_im_blick() -> Vector2i:
	var p := ego.ziel_welt(true)
	if p.x < -9000.0:
		return Vector2i(-99, -99)
	var gx := p.x / Werte.ZELLE
	var gy := (p.y - Werte.KARTE_OBEN) / Werte.ZELLE
	var halb := float(BrakkFortschritt.FELD_GROESSE) / 2.0
	return Vector2i(roundi(gx - halb), roundi(gy - halb))


func _feld_mitte(ecke: Vector2i) -> Vector2:
	var halb := float(BrakkFortschritt.FELD_GROESSE) / 2.0
	return Vector2((float(ecke.x) + halb) * Werte.ZELLE, (float(ecke.y) + halb) * Werte.ZELLE + Werte.KARTE_OBEN)


func _feld_fabriken(ecke: Vector2i) -> Array:
	var liste: Array = []
	if _myr_feld():
		for z: Vector2i in ego.spiel.order24.myr_fabriken:
			if BrakkFortschritt.im_feld(z, ecke):
				liste.append(z)
		return liste
	for z: Vector2i in ego.spiel.fabriken:
		if not ego.karte.paar.has(z) and BrakkFortschritt.im_feld(z, ecke):
			liste.append(z)
	return liste


func _feld_bestaetigen() -> void:
	var f := ego.brakk.fortschritt
	if f == null or f.ringe.is_empty() or (ego.spiel.phase != 0 and not _myr_feld()):
		_feld_abbrechen()
		return
	var ecke := _feld_ecke_im_blick()
	if ecke.x < -90 or _feld_mitte(ecke).distance_to(ego._fuss2d()) > EgoModus.FELD_WEITE * Werte.ZELLE:
		ego.spiel.melde("Zu weit – das Ringfeld reicht höchstens %d Felder weit." % int(EgoModus.FELD_WEITE), 2.0)
		return
	var ring := f.ringe[clampi(f.gewaehlt, 0, f.ringe.size() - 1)]
	f.setze_feld(ring, ecke)
	_feld_abbrechen()
	ego._hand_zeigen = 1.0
	ego._trauma = minf(1.0, ego._trauma + 0.12)
	ego.spiel.effekte.flaeche(_feld_mitte(ecke), Werte.ZELLE * 1.1, ego._ring_farbe(ring))
	Ton.spiele(ego.spiel, "tc-arc", -4.0)
	if _myr_feld():
		var o: Order24 = ego.spiel.order24
		var typ := str(Order24.MYR_RING.get(ring, "hund"))
		var wert: float = o.wf("myr_wert") * (1.0 + o.wf("myr_ring_stufe") / 100.0 * float(maxi(0, f.ring_stufe(ring) - 1)))
		ego.spiel.melde("%s: %d/4 Myriaden-Fabriken im Feld – jede baut %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), _feld_fabriken(ecke).size(), o.myr_takt_text(typ, wert)], 4.0)
		return
	ego.spiel.melde("%s: %d/4 Fabriken im Feld bauen %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), _feld_fabriken(ecke).size(), ego._ring_fabrik_text(ring, f.ring_stufe(ring))], 3.0)


func _leucht_mat(farbe: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(farbe, alpha)
	m.emission_enabled = true
	m.emission = farbe
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kasten(groesse: Vector3, mat: StandardMaterial3D, pos: Vector3, eltern: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	m.mesh = box
	m.material_override = mat
	m.position = pos
	eltern.add_child(m)
	return m


## Ringfeld in 3D: leuchtender Rand eines 2×2-Rechtecks, zarte Fläche, dunkler Plattformrand; darüber (gesetzt)
## der Holo-Bogen mit dem Ring.
func _baue_feld(ring: String, farbe: Color, vorschau: bool) -> Node3D:
	var k := Node3D.new()
	var s := float(BrakkFortschritt.FELD_GROESSE)
	var rand := _leucht_mat(farbe, 0.45 if vorschau else 0.9)
	var h := s / 2.0
	for seite: Array in [[Vector3(s, 0.04, 0.07), Vector3(0, 0.04, -h)], [Vector3(s, 0.04, 0.07), Vector3(0, 0.04, h)],
			[Vector3(0.07, 0.04, s), Vector3(-h, 0.04, 0)], [Vector3(0.07, 0.04, s), Vector3(h, 0.04, 0)]]:
		_kasten(seite[0], rand, seite[1], k)
	_kasten(Vector3(s, 0.01, s), _leucht_mat(farbe, 0.08 if vorschau else 0.16), Vector3(0, 0.03, 0), k)
	if not vorschau:
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color("23262e")
		for seite: Array in [[Vector3(s + 0.24, 0.05, 0.12), Vector3(0, 0.025, -h - 0.1)], [Vector3(s + 0.24, 0.05, 0.12), Vector3(0, 0.025, h + 0.1)],
				[Vector3(0.12, 0.05, s), Vector3(-h - 0.1, 0.025, 0)], [Vector3(0.12, 0.05, s), Vector3(h + 0.1, 0.025, 0)]]:
			_kasten(seite[0], pm, seite[1], k)
		var schwebe := Node3D.new()
		schwebe.name = "Ring"
		schwebe.position.y = 0.2
		k.add_child(schwebe)
		var bogen := 0.95
		var segmente := 16
		for i in segmente:
			if i % 4 == 3:
				continue   # Lücken im Bogen
			var w := PI * 1.25 * (float(i) + 0.5) / float(segmente) - PI * 0.125
			var seg := _kasten(Vector3(0.16, 0.05, 0.07), _leucht_mat(farbe, 0.85), Vector3(cos(w) * bogen, 0.9 + sin(w) * bogen, 0.0), schwebe)
			seg.rotation.z = w + PI / 2.0
		var bild := Sprite3D.new()
		bild.texture = RingBilder.bild(ring, farbe)
		bild.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bild.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		bild.pixel_size = 0.045
		bild.shaded = false
		bild.position.y = 0.95
		schwebe.add_child(bild)
	ego.hd.add_child(k)
	return k


## Jedes Bild: 3D-Felder mit den gesetzten Feldern abgleichen, Ringe drehen; beim Zielen die Vorschau mit leuchtenden Fabriken.
func _felder_weiter(dt: float) -> void:
	var f := ego.brakk.fortschritt
	if f == null:
		return
	for ring: String in ego._feld_knoten.keys():
		if not f.felder.has(ring):
			(ego._feld_knoten[ring] as Node3D).queue_free()
			ego._feld_knoten.erase(ring)
	for ring: String in f.felder:
		var k: Node3D = ego._feld_knoten.get(ring)
		if k == null:
			k = _baue_feld(ring, ego._ring_farbe(ring), false)
			ego._feld_knoten[ring] = k
		k.position = ego._zu3d(_feld_mitte(f.felder[ring] as Vector2i), 0.0)
		var s := k.get_node_or_null("Ring") as Node3D
		if s != null:
			s.rotation.y += dt * 0.8
			s.position.y = 0.2 + 0.06 * sin(Time.get_ticks_msec() / 400.0)
	if _feld_zielt and ((ego.spiel.phase != 0 and not _myr_feld()) or f.ringe.is_empty()):
		_feld_abbrechen()
	if not _feld_zielt or not ego._frei():
		if ego._vorschau != null:
			ego._vorschau.visible = false
		for m: Node3D in _feld_marken:
			m.visible = false
		return
	ego._hand_zeigen = maxf(ego._hand_zeigen, 0.3)
	var ring := f.ringe[clampi(f.gewaehlt, 0, f.ringe.size() - 1)]
	var farbe := ego._ring_farbe(ring)
	if ego._vorschau == null or ego._vorschau.get_meta("ring", "") != ring:
		if ego._vorschau != null:
			ego._vorschau.queue_free()
		ego._vorschau = _baue_feld(ring, farbe, true)
		ego._vorschau.set_meta("ring", ring)
	_feld_ecke = _feld_ecke_im_blick()
	ego._vorschau.visible = _feld_ecke.x > -90
	if not ego._vorschau.visible:
		return
	ego._vorschau.position = ego._zu3d(_feld_mitte(_feld_ecke), 0.0)
	var fabriken := _feld_fabriken(_feld_ecke)
	while _feld_marken.size() < 4:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.96, 1.3, 0.96)
		m.mesh = box
		m.material_override = _leucht_mat(farbe, 0.22)
		ego.hd.add_child(m)
		_feld_marken.append(m)
	var puls := 0.15 + 0.12 * sin(Time.get_ticks_msec() / 160.0)
	for i in 4:
		var m: MeshInstance3D = _feld_marken[i]
		m.visible = i < fabriken.size()
		if m.visible:
			m.position = ego._zu3d(ego.karte.mitte(fabriken[i] as Vector2i), 0.65)
			var mm := m.material_override as StandardMaterial3D
			mm.albedo_color = Color(farbe, puls)
			mm.emission = farbe


## 18.11. (Paul): Ringplätze auf der Ringhand (ringhand.png, 48×72, Faust mit erhobenem Zeigefinger), in Bildpunkten:
## [links, rechts, oben] eines 3 Bildpunkte hohen Bands quer über das Fingerglied – in der Reihenfolge, in der die
## Finger frei werden: Mittelfinger, Ringfinger, Zeigefinger (über dem Projektorring), kleiner Finger, Daumen.
const FINGER_BAENDER := [[18, 24, 23], [11, 17, 25], [32, 38, 15], [4, 9, 28], [39, 45, 41]]
## Material des Bands je Ring (wie in ring_bilder.gd): Silber, Schwarz, Gold, dunkles Metall.
const BAND_FARBE := {"durchschuss": "8a93a6", "laser": "2b2830", "feuerteam": "c4ccd8", "minigun": "4a505e", "markierung": "8a93a6", "bollwerk": "4a505e",
	"abpraller": "4a505e", "brandfeld": "c9952e", "plasmagel": "8a93a6"}


## Die getragenen Ringe sitzen als Bänder auf ihren Fingern, mit dem Stein in der Ringfarbe; der gewählte leuchtet.
func _ringe_auf_hand(rp: Vector2, wpx: float, auf: float) -> void:
	var f := ego.brakk.fortschritt
	if f == null:
		return
	var o := rp.round()
	var umriss := Color(EgoModus.UMRISS, auf)
	for i in mini(f.ringe.size(), FINGER_BAENDER.size()):
		var ring := f.ringe[i]
		var farbe := ego._ring_farbe(ring)
		var b: Array = FINGER_BAENDER[i]
		var x0 := float(b[0])
		var x1 := float(b[1])
		var y := float(b[2])
		var breite := x1 - x0 + 1.0
		var metall := Color(str(BAND_FARBE.get(ring, "8a93a6")))
		var gew := i == f.gewaehlt and ego._hand_zeigen > 0.0
		var px := func(x: float, yy: float, w: float, h: float, c: Color) -> void:
			ego._bild.draw_rect(Rect2(o + Vector2(x, yy) * wpx, Vector2(w, h) * wpx), c)
		if gew:
			# 18.11. (Paul): der gewählte Ring leuchtet kräftig – Schein in drei Stufen, beim Wechsel ein weißer Blitz
			var puls := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
			var mitte := o + Vector2((x0 + x1 + 1.0) / 2.0, y + 1.5) * wpx
			ego._bild.draw_circle(mitte, 12.0 * wpx, Color(farbe, 0.12 * puls * auf))
			ego._bild.draw_circle(mitte, 7.0 * wpx, Color(farbe, 0.28 * puls * auf))
			ego._bild.draw_circle(mitte, 4.0 * wpx, Color(farbe.lightened(0.4), 0.45 * puls * auf))
			if ego._ring_blitz > 0.0:
				ego._bild.draw_circle(mitte, (4.0 + 10.0 * (0.3 - ego._ring_blitz)) * wpx, Color(1, 1, 1, ego._ring_blitz * 2.0 * auf))
		# Band: Umriss oben und unten, drei Zeilen Metall (hell, mittel, dunkel)
		px.call(x0, y - 1.0, breite, 1.0, umriss)
		px.call(x0, y + 3.0, breite, 1.0, umriss)
		px.call(x0, y, breite, 1.0, Color(metall.lightened(0.35), auf))
		px.call(x0, y + 1.0, breite, 1.0, Color(metall, auf))
		px.call(x0, y + 2.0, breite, 1.0, Color(metall.darkened(0.35), auf))
		# Stein in der Mitte (2×3), beim gewählten heller
		var mx := floorf((x0 + x1) / 2.0)
		px.call(mx - 1.0, y - 1.0, 4.0, 5.0, umriss)
		var stein := farbe.lightened(0.25) if gew else farbe
		if ring == "durchschuss":
			px.call(mx, y, 2.0, 3.0, Color(Color("f2f2f2"), auf))   # Auge: weiß mit farbiger Mitte
			px.call(mx, y + 1.0, 2.0, 1.0, Color(stein, auf))
		else:
			px.call(mx, y, 2.0, 3.0, Color(stein, auf))
			px.call(mx, y, 1.0, 1.0, Color(stein.lightened(0.6), auf))


## 19.11. (Paul): Die Zeitlupe [V] bekommt je aktivem Ring einen Zusatz, beim Auslösen festgelegt. Die Lichtsäule deckt
## Schaden und Bremsen ab – die Zeitlupe stützt Truppen, macht Brakk beweglich oder kontert Gegner-Tricks.
## Werte in BrakkFortschritt.ZEITLUPE_RING.
var _zl_ring := ""               # Ring, mit dem die laufende (oder letzte) Zeitlupe ausgelöst wurde
var _zl_nach_bis := 0            # Zielring: Bonus noch bis dahin (ms)
var _zl_heil_takt := 0.0


func _zl_wert(ring: String, schluessel: String) -> float:
	return float((BrakkFortschritt.ZEITLUPE_RING.get(ring, {}) as Dictionary).get(schluessel, 0.0))


func _zl_aktiv(ring: String) -> bool:
	return ego.saeule._zeitlupe > 0.0 and _zl_ring == ring


func _truppen_um(p: Vector2, radius_felder: float) -> Array:
	var liste: Array = []
	for e: Variant in ego.spiel.einheiten:
		if is_instance_valid(e) and e is Einheit and not (e is Kommandant) and not (e as Einheit).ist_pilot and (e as Einheit).leben > 0.0 \
				and (e as Einheit).position.distance_to(p) <= radius_felder * Werte.ZELLE:
			liste.append(e)
	return liste


func _zl_beginn() -> void:
	_zl_ring = ego.brakk.fortschritt.aktiv() if ego.brakk.fortschritt != null else ""
	var farbe := ego._licht_farbe()
	match _zl_ring:
		"abpraller":
			_zl_bereit()
			ego.spiel.melde("Zeitlupe · Sprungring: Anker, Rolle und Treppe ohne Cooldown.", 2.5)
		"brandfeld":
			# Rauch im Umkreis löst sich auf, Gegner darin können eine Weile nicht geheilt werden
			var r := _zl_wert("brandfeld", "radius") * Werte.ZELLE
			var weg := 0
			while ego.spiel.effekte.blase_rauch_weg(ego._fuss2d(), r) != null and weg < 20:
				weg += 1
			var bis := Time.get_ticks_msec() + int(_zl_wert("brandfeld", "sperre") * 1000.0)
			for g: Gegner in ego.spiel.ego_gegner():
				if is_instance_valid(g) and not g._tot and g.position.distance_to(ego._fuss2d()) <= r:
					g.heilsperre_bis = bis
			ego.spiel.effekte.welle(ego._fuss2d(), r, farbe, "funk", 0.9)
			ego.spiel.melde("Zeitlupe · Brandring: Rauch weg, Gegner %s s nicht heilbar." % BrakkFortschritt._zahl(_zl_wert("brandfeld", "sperre")), 2.5)
		"feuerteam":
			ego.spiel.melde("Zeitlupe · Taktring: Fabriken im Feld ersetzen sofort ihre Truppen.", 2.5)
		"laser":
			ego.spiel.melde("Zeitlupe · Glutstrahlring: keine Überhitzung." if ego.touch == null else "Zeitlupe · Glutstrahlring: schnellere Schüsse.", 2.5)
		"durchschuss":
			_klinge_schlag_t = -1.0
			Ton.spiele(ego.spiel, "tc-arc", -2.0)
			ego.spiel.melde("Zeitlupe · Durchschlagring: Ringklinge – Nahkampf!", 2.5)


func _zl_weiter(dt: float) -> void:
	ego.spiel.brakk_mark_selbst = _zl_aktiv("markierung") or Time.get_ticks_msec() < _zl_nach_bis
	# Klinge auf- und abbauen
	_klinge_auf = move_toward(_klinge_auf, 1.0 if _klinge_aktiv() else 0.0, dt * (3.5 if _klinge_aktiv() else 5.0))
	if _klinge_schlag_t >= 0.0:
		_klinge_schlag_t += dt
		if _klinge_schlag_t > KLINGE_SCHLAG_SEK:
			_klinge_schlag_t = -1.0
	if ego.saeule._zeitlupe <= 0.0:
		return
	match _zl_ring:
		"abpraller":
			_zl_bereit()
		"plasmagel":
			_zl_heil_takt += dt
			if _zl_heil_takt >= 0.25:
				var anteil := _zl_wert("plasmagel", "heilung") * _zl_heil_takt
				_zl_heil_takt = 0.0
				for e: Einheit in _truppen_um(ego._fuss2d(), _zl_wert("plasmagel", "radius")):
					if e.leben < e.max_leben:
						e.leben = minf(e.max_leben, e.leben + e.max_leben * anteil)
						ego.spiel.effekte.plus(e.position + Vector2(0, -18), Color("7dff9a"))
		"feuerteam":
			var f := ego.brakk.fortschritt
			if f != null and f.felder.has("feuerteam"):
				for z: Vector2i in ego.spiel.fabriken:
					if BrakkFortschritt.im_feld(z, f.felder["feuerteam"] as Vector2i):
						ego.spiel.fabriken[z]["timer"] = Werte.PRODUKTION_SEK   # fehlt eine Truppe, kommt sie im nächsten Bild
		"durchschuss":
			if ego.touch != null and ego._takt <= 0.0 and ego._frei() and not _klinge_ziele().is_empty():
				_klinge_schlag()   # am Handy schlägt Brakk von selbst zu


func _zl_ende() -> void:
	match _zl_ring:
		"bollwerk":
			var bis := Time.get_ticks_msec() + int(_zl_wert("bollwerk", "sek") * 1000.0)
			var n := 0
			for e: Einheit in _truppen_um(ego._fuss2d(), _zl_wert("bollwerk", "radius")):
				e.ring_schild = e.max_leben * _zl_wert("bollwerk", "schild")
				e.ring_schild_bis = bis
				ego.spiel.effekte.welle(e.position, Werte.ZELLE * 0.55, ego._licht_farbe(), "heil", 0.8)
				n += 1
			if n > 0:
				ego.spiel.melde("Wallring: %d Truppen mit Schild." % n, 2.0)
		"minigun":
			_zl_sog()
		"markierung":
			_zl_nach_bis = Time.get_ticks_msec() + int(_zl_wert("markierung", "nach") * 1000.0)


## Sprungring: Anker, Rolle und Treppe (und Brücke) bereit.
func _zl_bereit() -> void:
	ego.lichtwerk._anker_rest = 0.0
	ego._tumble_rest = 0.0
	ego.brakk.e_rest = 0.0
	ego.lichtwerk._bruecke_cd = 0.0


## Wirbelring am Ende: Gegner um den Punkt unter dem Fadenkreuz zusammenziehen – Schritt für Schritt, nur über begehbare
## Felder (nicht durch Mauern), große Gegner nicht.
func _zl_sog() -> void:
	var p := ego.ziel_welt(true)
	if p.x < -9000.0:
		return
	var r := _zl_wert("minigun", "radius") * Werte.ZELLE
	var zug := _zl_wert("minigun", "zug") * Werte.ZELLE
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or BrakkFortschritt.gross(g) or g.position.distance_to(p) > r:
			continue
		if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)):
			continue   # oben auf einem Wall bleibt er
		var weg := minf(zug, g.position.distance_to(p))
		var richtung := (p - g.position).normalized()
		var bisher := g.position
		var s := 0.0
		while s < weg:
			s = minf(weg, s + 4.0)
			var neu := g.position + richtung * s
			if not ego.karte.ist_begehbar(ego.karte.zelle_bei(neu)):
				break
			bisher = neu
		if bisher != g.position:
			ego.spiel.effekte.strahl(g.position, bisher, ego._licht_farbe(), 2.0)
			g.position = bisher
			g.plane_neu()
	ego.spiel.effekte.welle(p, r, ego._licht_farbe(), "funk", 0.8)
	ego._trauma = minf(1.0, ego._trauma + 0.3)
	Ton.spiele(ego.spiel, "hit-boom", -6.0)


# ------------------------------------------------------------------ Ringklinge (Zeitlupe mit Durchschlagring)

## 19.11. (Paul): Nahkampf – eine Lichtklinge an der rechten Hand aus denselben sechseckigen Lichtplatten wie Lichttreppe
## und Lichtplattform, in der Farbe des aktiven Rings (wechselt mit). Aufbau (Platten springen nacheinander auf), zwei
## Schlagbilder (links, rechts) mit Leuchtspur. Aus Code gezeichnet; ein PixelLab-Bild kann sie später ersetzen.
const KLINGE_SCHLAG_SEK := 0.22
const KLINGE_PLATTEN := 7
var _klinge_auf := 0.0           # 0 = weggesteckt, 1 = ganz aufgebaut
var _klinge_schlag_t := -1.0     # Sekunden seit dem Schlag (-1 = keiner)
var _klinge_seite := 1           # 1 = von rechts nach links, -1 = umgekehrt


func _klinge_aktiv() -> bool:
	return _zl_aktiv("durchschuss")


## Gegner im Bogen vor Brakk in Reichweite.
func _klinge_ziele() -> Array:
	var liste: Array = []
	var weite := _zl_wert("durchschuss", "weite") * Werte.ZELLE
	var halb := deg_to_rad(_zl_wert("durchschuss", "bogen") / 2.0)
	var vorne := Vector2(ego._vorne().x, ego._vorne().z)
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g):
			continue
		var d := g.position - ego._fuss2d()
		if d.length() <= weite and (d.length() < 8.0 or absf(vorne.angle_to(d)) <= halb):
			liste.append(g)
	return liste


func _klinge_schlag() -> void:
	if ego._takt > 0.0 or _klinge_auf < 0.6:
		return
	ego._takt = _zl_wert("durchschuss", "takt")
	_klinge_schlag_t = 0.0
	_klinge_seite = -_klinge_seite
	var ziele := _klinge_ziele()
	Ton.spiele(ego.spiel, "tc-arc", -4.0)
	ego._kick += 0.02
	if ziele.is_empty():
		return
	var schaden := EgoModus.SCHUSS_SCHADEN * ego._schaden_faktor() * _zl_wert("durchschuss", "mal")
	var summe := 0.0
	var kill := false
	ego.spiel.schadensquelle = "fabrik:-1,-1"
	ego.spiel.brakk_quelle = "klinge"
	ego.spiel.schuss_herkunft = ego.brakk.position
	for g: Gegner in ziele:
		if not is_instance_valid(g) or g._tot:
			continue
		var vorher := g.leben
		g.nimm_schaden(schaden * ego._gel_bonus(g))
		summe += maxf(0.0, vorher - maxf(g.leben, 0.0))
		if g._tot:
			kill = true
			ego._kill(g)
	ego.spiel.schadensquelle = ""
	ego.spiel.brakk_quelle = ""
	ego.spiel.schuss_herkunft = Vector2.INF
	ego.brakk.leben = minf(ego.brakk.max_leben, ego.brakk.leben + summe * _zl_wert("durchschuss", "heilung"))   # Schaden heilt Brakk
	ego._treffer_gefuehl(ego._zu3d(ego._fuss2d() + Vector2(ego._vorne().x, ego._vorne().z) * Werte.ZELLE, 0.5), kill)


## Sechseck (Lichtplatte) in 2D.
func _sechseck(mitte: Vector2, r: float, winkel: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 6:
		var w := winkel + TAU * float(i) / 6.0
		p.append(mitte + Vector2(cos(w), sin(w)) * r)
	return p


func _klinge_bild(g: Vector2, wpx: float) -> void:
	if _klinge_auf <= 0.01:
		return
	var farbe := ego._licht_farbe()
	var hand := Vector2(g.x * 0.8, g.y * 1.02)
	# Grundwinkel: die Klinge zeigt schräg nach oben links zum Fadenkreuz; beim Schlag schwingt sie durch
	var w0 := -PI * 0.64
	var schwung := 0.0
	if _klinge_schlag_t >= 0.0:
		var x := clampf(_klinge_schlag_t / KLINGE_SCHLAG_SEK, 0.0, 1.0)
		schwung = (1.0 - pow(1.0 - x, 3.0)) * 1.3 - 0.65   # schnell, dann aus
		schwung *= float(_klinge_seite)
	var winkel := w0 + schwung
	var laenge := g.y * 0.6
	# Leuchtspur beim Schlag: blasse Platten auf den vorigen Winkeln
	if _klinge_schlag_t >= 0.0:
		for s in 5:
			var ws := winkel - float(_klinge_seite) * 0.12 * float(s + 1)
			var a := 0.22 * (1.0 - float(s) / 5.0) * (1.0 - _klinge_schlag_t / KLINGE_SCHLAG_SEK)
			for i in KLINGE_PLATTEN:
				var t := float(i + 1) / float(KLINGE_PLATTEN)
				var m := hand + Vector2(cos(ws), sin(ws)) * laenge * t
				ego._bild.draw_colored_polygon(_sechseck(m, wpx * (10.0 - 5.0 * t), ws), Color(farbe, a))
	# Platten vom Griff zur Spitze, beim Aufbau springen sie nacheinander mit Überschwung auf
	for i in KLINGE_PLATTEN:
		var t := float(i + 1) / float(KLINGE_PLATTEN)
		var auf := clampf(_klinge_auf * float(KLINGE_PLATTEN) - float(i), 0.0, 1.0)
		if auf <= 0.0:
			continue
		var pop := 1.0 + 2.70158 * pow(auf - 1.0, 3) + 1.70158 * pow(auf - 1.0, 2)   # Ease-out-back
		var m := hand + Vector2(cos(winkel), sin(winkel)) * laenge * t
		var r := wpx * (11.0 - 6.0 * t) * pop
		ego._bild.draw_colored_polygon(_sechseck(m, r * 1.35, winkel), Color(farbe, 0.25))
		ego._bild.draw_colored_polygon(_sechseck(m, r, winkel), Color(farbe, 0.85))
		ego._bild.draw_polyline(_sechseck(m, r, winkel) + PackedVector2Array([_sechseck(m, r, winkel)[0]]), farbe.lightened(0.6), maxf(1.0, wpx * 0.5))
	# Griff: ein Ring um die Hand
	ego._bild.draw_arc(hand, wpx * 7.0, 0.0, TAU, 24, Color(farbe.lightened(0.4), 0.9 * _klinge_auf), wpx * 1.5)
