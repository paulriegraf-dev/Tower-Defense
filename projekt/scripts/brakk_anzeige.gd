class_name BrakkAnzeige
extends RefCounted
## Anzeige der Ego-Sicht (18./19.11.; 27.11. Knoten-Umbau 7d – vorher in ego_modus.gd): Waffen, Fadenkreuz,
## Minikarte, Fähigkeiten-Leiste, Einsatz-Tafel mit Einflug, Werte-Fenster. Regeln und Aussehen unverändert; Zahlen und
## Mündung/Mündungsblitz (nutzen Kits und Bosse) bleiben in ego_modus.gd. Teil der Ego-Sicht wie EgoKit (`ego.anzeige`,
## angelegt in EgoModus._init).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var ego: EgoModus


func _init(e: EgoModus) -> void:
	ego = e


var _muendung_rechts := Vector2(-1, -1)   # 18.11.: Mündung der rechten Pistole, falls anders (-1 = wie links)
var _waffen_teiler := 150.0         # Bildhöhe / Teiler = Bildschirmpunkte je Waffen-Bildpunkt
var _neigung := EgoModus.NEIGUNG

func _baue_oberflaeche() -> void:
	if ResourceLoader.exists(EgoModus.PISTOLE_BILD):
		ego._tex_pistole = load(EgoModus.PISTOLE_BILD)
		ego._tex_pistole_links = ego._tex_pistole   # 18.11. (Paul): links das Original in Technoclan-Farben
		ego._muendung = Vector2(11, 11)   # leuchtender Emitter oben links
		if ResourceLoader.exists(EgoModus.PISTOLE_RECHTS_BILD):
			ego._tex_pistole = load(EgoModus.PISTOLE_RECHTS_BILD)
			_muendung_rechts = Vector2(44, 43)   # Augen-Linse der Handkanone
		_waffen_teiler = 200.0        # das Bild ist größer (64×96) als der Platzhalter
		_neigung = 0.0                # schon schräg zur Bildmitte gezeichnet
	else:
		ego._tex_pistole = ImageTexture.create_from_image(ego._male_pistole())
		ego._tex_pistole_links = ego._tex_pistole   # 18.11. (Paul): links das Original in Technoclan-Farben
	if ResourceLoader.exists(EgoModus.RINGHAND_BILD):
		ego._tex_ring = load(EgoModus.RINGHAND_BILD)
		ego._ring_licht = Vector2(22, 5)  # Holoscheibe über den Knöcheln
	else:
		ego._tex_ring = ImageTexture.create_from_image(ego._male_ringhand())
	ego._ebene = CanvasLayer.new()
	ego._ebene.layer = 2
	ego.add_child(ego._ebene)
	ego._bild = Control.new()
	ego._bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ego._bild.set_anchors_preset(Control.PRESET_FULL_RECT)
	ego._bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ego._bild.draw.connect(_male_bild)
	ego._ebene.add_child(ego._bild)
	ego._karte_klein = Control.new()
	ego._karte_klein.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ego._karte_klein.set_anchors_preset(Control.PRESET_FULL_RECT)
	ego._karte_klein.draw.connect(_male_minikarte)
	ego._ebene.add_child(ego._karte_klein)


func _male_bild() -> void:
	if ego._sieg_t >= 0.0:
		ego._sieg_bild(ego._bild.get_viewport_rect().size)   # 19.11.
		return
	if ego._hud_aus():
		return   # 18.11. (Paul): Übersicht, Pause, Menüs – nur die Tafel, keine Waffen und Leisten davor
	var g := ego._bild.get_viewport_rect().size
	var px := maxf(2.0, floorf(g.y / 150.0))          # Bildpunkt für Fadenkreuz und Anzeigen
	var wpx := maxf(2.0, floorf(g.y / _waffen_teiler))   # 18.11.: ein Bildpunkt der Waffe in Bildschirmpunkten
	var ts := Vector2(ego._tex_pistole.get_size()) * wpx
	var wipp := Vector2(cos(ego._gang * 0.5) * 3.0, absf(sin(ego._gang * 0.5)) * 4.0) if ego._geht else Vector2.ZERO
	if ego.kit != null:
		ego.kit.male_waffen(g, wpx)   # 20.11.: Waffen des Anführers statt Brakks Pistolen
	else:
		# rechte Pistole
		var r_rueck := float(ego._rueckstoss[1])
		var r_pos := Vector2(g.x * 0.80 - ts.x * 0.5, g.y - ts.y + 12.0 * wpx) + wipp + Vector2(r_rueck * 2.0, r_rueck * 6.0) * wpx + (ego._sway + Vector2(0, 7.0 * ego._delle)) * wpx   # 19.11.: Sway und Landungsdelle
		r_pos.y += ts.y * 1.1 * ego.ringwerk._klinge_auf   # 19.11.: Ringklinge – die rechte Pistole steckt weg
		_waffe(ego._tex_pistole, r_pos, ts, -_neigung, float(ego._blitz[1]) > 0.0, wpx, false, ego._glut(), float(ego._gesperrt[1]) > 0.0)
		# linke Hand: Pistole (gespiegelt) oder Ring – beim Wechsel taucht die eine ab und die andere auf
		var l_rueck := float(ego._rueckstoss[0])
		var ab := clampf(ego._ring * 2.0, 0.0, 1.0)              # Pistole sinkt
		var auf := clampf(ego._ring * 2.0 - 1.0, 0.0, 1.0)       # Ring kommt
		var l_basis := Vector2(g.x * 0.20 - ts.x * 0.5, g.y - ts.y + 12.0 * wpx) + Vector2(-wipp.x, wipp.y) + (ego._sway * 0.8 + Vector2(0, 7.0 * ego._delle)) * wpx
		if ab < 1.0:
			var lp := l_basis + Vector2(-l_rueck * 2.0, l_rueck * 6.0) * wpx + Vector2(0, ab * ts.y)
			_waffe(ego._tex_pistole_links, lp, ts, _neigung, float(ego._blitz[0]) > 0.0, wpx, true, ego._glut(), float(ego._gesperrt[0]) > 0.0)
		if auf > 0.0:
			var rs := Vector2(ego._tex_ring.get_size()) * wpx
			var rp := Vector2(g.x * 0.22 - rs.x * 0.5, g.y - rs.y + 4.0 * wpx) + Vector2(-wipp.x, wipp.y) + Vector2(0, (1.0 - auf) * rs.y)
			if ego.saeule._saeule_ziel != Vector2.INF or ego.saeule._saeule_zielt:
				var tw := Time.get_ticks_msec() / 1000.0 * 9.0
				rp += Vector2(cos(tw), sin(tw)) * 2.0 * wpx   # die Hand kreist mit
			if ego.brakk.fortschritt != null and ego.brakk.fortschritt.wechsel_rest > 0.0:
				# 18.11. (Paul): Ringwechsel – die Hand rüttelt kurz (abklingend), solange schießt nur rechts
				var w := ego.brakk.fortschritt.wechsel_rest / BrakkFortschritt.WECHSEL_SEK
				var tt := Time.get_ticks_msec() / 1000.0
				rp += Vector2(sin(tt * 47.0) * 3.0, cos(tt * 39.0) * 2.0 - 4.0 * w) * wpx * w
			ego._bild.draw_texture_rect(ego._tex_ring, Rect2(rp.round(), rs), false)
			# Ring leuchtet (pulsiert)
			var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
			var mitte := rp + ego._ring_licht * wpx
			ego._bild.draw_circle(mitte, 5.0 * wpx, Color(EgoModus.LICHT, 0.18 * puls * auf))
			ego._bild.draw_circle(mitte, 2.5 * wpx, Color(EgoModus.LICHT, 0.35 * puls * auf))
			ego.ringwerk._ringe_auf_hand(rp, wpx, auf)   # 18.11.
			ego._finger_wirbel(rp, wpx, auf)   # 18.11.: Lichtsäule
	if ego._frei():   # 18.11.: bei offenem Menü kein Fadenkreuz und kein Hinweis darüber
		_fadenkreuz(g, px)
	_rand_an()   # 19.11.: Leisten in die sichere Fläche (iPhone: Notch, Home-Balken) – Fadenkreuz und Waffen nicht
	# 19.11.: Die [Tab]-Liste ist im Brakk-Mode klein und darf offen bleiben – am PC rückt die Bauliste darunter,
	# am Handy (wenig Platz) bleibt sie solange weg.
	var liste_offen: bool = ego.spiel._hud != null and ego.spiel._hud.schadensliste != null and ego.spiel._hud.schadensliste.visible
	if ego.touch == null or (ego.touch.bau_offen and not liste_offen):
		_bauliste(g, liste_offen)
	# Zustandszeile unten in der Mitte
	if ego._klettern >= 0.0:
		Stil.schreibe_mittig(ego._bild, Vector2(g.x / 2.0, g.y * 0.62), "Lichttreppe", 18, EgoModus.LICHT)
	ego._brakk_leiste(g)   # 18.11.: Leben, Stufe, Erfahrung
	_werte_fenster(g)   # 19.11.
	ego._countdown_anzeige(g)   # 18.11.: nächste Welle
	_rand_aus()
	ego.ringwerk._klinge_bild(g, wpx)   # 19.11.: Ringklinge über den Leisten (nur während der Zeitlupe mit Durchschlagring)
	ego._respawn_bild(g)   # 19.11.: Countdown, solange Brakk liegt
	ego.saeule._zeitlupe_bild(g)
	if ego.kit != null:
		ego.kit.male_oben(g)   # 20.11.
	if ego.brakk.fortschritt != null:
		ego._wurf_warnung()   # 18.11.: Steine auf Brakk
		ego._gefahr_bild(g)
	ego._einbruch_bild(g)   # 22.11.
	if ego.touch != null:
		ego.touch.male(ego._bild)   # 18.11.: Handy – Stick und Knöpfe statt Leisten
		return
	_rand_an()
	_faehigkeiten(g)   # 18.11.: Symbole mit Abklingzeit (20.11., Nachtrag: für jeden Anführer dieselbe Leiste)
	if ego.kit != null:
		ego.kit.male_leisten(g)   # 20.11.: Ringe und Zustand des Anführers
	else:
		ego.ringwerk._ringleiste(g)   # 18.11.: getragene Ringe
	_rand_aus()


## 19.11.: Zeichnen in der sicheren Fläche an/aus (am PC Identität). Texte über Stil.ebene mit.
func _rand_an() -> void:
	var t := Transform2D(0.0, Vector2.ONE * SichererRand.faktor(), 0.0, SichererRand.versatz())
	Stil.ebene = t
	ego._bild.draw_set_transform_matrix(t)


func _rand_aus() -> void:
	Stil.ebene = Transform2D.IDENTITY
	ego._bild.draw_set_transform_matrix(Transform2D.IDENTITY)


## Eine Pistole zeichnen: um ihre untere Mitte geneigt, links gespiegelt; Mündungsblitz an der Spitze.
func _waffe(tex: Texture2D, pos: Vector2, ts: Vector2, winkel: float, blitz: bool, px: float, spiegeln: bool, glut: float = 0.0, heiss: bool = false) -> void:
	var mund := ego._muendung if spiegeln or _muendung_rechts.x < 0.0 else _muendung_rechts   # 18.11.: die rechte Handkanone hat ihre Linse woanders
	var dreh := pos.round() + Vector2(ts.x / 2.0, ts.y)
	ego._bild.draw_set_transform(dreh, winkel, Vector2(-1.0 if spiegeln else 1.0, 1.0))
	ego._bild.draw_texture_rect(tex, Rect2(Vector2(-ts.x / 2.0, -ts.y), ts), false)
	if blitz:
		# 18.11.: an der echten Laufmündung des Bilds (Platzhalter: oben Mitte)
		var m := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		ego._muendungsblitz(Vector2(-ts.x / 2.0, -ts.y) + m * px, px, EgoModus.LASER_LINKS if spiegeln else EgoModus.SCHUSS)
	if heiss:
		# 18.11.: überhitzt – Mündung glüht rot, Dampf steigt auf
		var mh := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		var ph := Vector2(-ts.x / 2.0, -ts.y) + mh * px
		var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 70.0)
		ego._bild.draw_circle(ph, 7.0 * px, Color(1.0, 0.2, 0.1, 0.3 * puls))
		ego._bild.draw_circle(ph, 3.0 * px, Color(1.0, 0.45, 0.2, 0.8))
		var t := Time.get_ticks_msec() / 1000.0
		for k in 4:
			var a := fmod(t * 1.3 + k * 0.25, 1.0)
			ego._bild.draw_rect(Rect2(ph + Vector2(sin(t * 3.0 + k) * 3.0, -a * 18.0) * px, Vector2(2, 2) * px), Color(0.85, 0.85, 0.9, 0.5 * (1.0 - a)))
	if glut > 0.0:
		# 18.11.: Ladestrahl lädt – die Mündung glüht an, voll geladen flackert sie weiß
		var mg := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		var p := Vector2(-ts.x / 2.0, -ts.y) + mg * px
		var voll := glut >= 1.0
		ego._bild.draw_circle(p, (3.0 + 6.0 * glut) * px, Color(EgoModus.SCHUSS, 0.25 * glut))
		ego._bild.draw_circle(p, (1.5 + 3.0 * glut) * px, Color.WHITE if voll and Time.get_ticks_msec() % 160 < 80 else Color(EgoModus.SCHUSS, 0.8))
		# 19.11.: Lichtfunken strömen zur Mündung, je voller, desto dichter
		var tt := Time.get_ticks_msec() / 1000.0
		for k in 6:
			var a := fmod(tt * 2.2 + k / 6.0, 1.0)
			var w := k * TAU / 6.0 + tt * 1.5
			var q := p + Vector2(cos(w), sin(w)) * (1.0 - a) * 16.0 * px * (0.4 + 0.6 * glut)
			ego._bild.draw_rect(Rect2(q - Vector2(px, px) * 0.5, Vector2(px, px)), Color(EgoModus.SCHUSS.lightened(0.4), 0.9 * a))
	ego._bild.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Schmale Bauliste am linken Rand (statt der Leiste unten): Taste, Name, Preis; das gewählte Werkzeug leuchtet.
func _bauliste(g: Vector2, unter_liste: bool = false) -> void:
	if ego.spiel.order24 != null:
		return   # 20.11.: Befehl 24 – Brakk baut nicht
	if ego.spiel.phase != 0 and ego.spiel.werkzeug == Karte.FREI:
		return   # im Kampf freie Sicht
	var zeile := 34.0
	var breite := 210.0
	var eintraege: Array = []
	for k: Array in ego.spiel._hud.KACHELN:
		if int(k[0]) != Karte.KOMMANDANT:
			eintraege.append(k)
	var oben := (g.y - zeile * eintraege.size()) / 2.0
	if unter_liste:
		oben = maxf(oben, 282.0)   # unter der [Tab]-Liste (links oben)
	var x := 14.0
	var hinter := Rect2(x - 6.0, oben - 8.0, breite + 12.0, zeile * eintraege.size() + 16.0)
	ego._bild.draw_rect(hinter, Color(0.04, 0.05, 0.08, 0.55))
	var bau: bool = ego.spiel.phase == 0 or ego.spiel.endkampf
	for i in eintraege.size():
		var k: Array = eintraege[i]
		var typ := int(k[0])
		var preis: int = ego.spiel.kosten(typ)
		var geht: bool = (bau or ego.spiel.darf_in_welle(typ)) and (typ == Karte.FABRIK or ego.spiel.alles_frei()) and ego.spiel.herausforderung_sperrt(typ) == ""
		var r := Rect2(x, oben + i * zeile, breite, zeile - 4.0)
		var gewaehlt: bool = ego.spiel.werkzeug == typ
		if gewaehlt:
			ego._bild.draw_rect(r, Color(EgoModus.LICHT, 0.18))
			ego._bild.draw_rect(r, EgoModus.LICHT, false, 2.0)
		var farbe := Color.WHITE if gewaehlt else (Stil.TEXT if geht else Stil.TEXT_BLASS)
		var m := r.get_center().y
		Stil.schreibe(ego._bild, Vector2(r.position.x + 8.0, m), str(k[2]), 18, EgoModus.LICHT if geht else Stil.TEXT_BLASS)
		Stil.schreibe(ego._bild, Vector2(r.position.x + 32.0, m), str(k[3]), 18, farbe)
		var p := "" if typ == Karte.TURM else str(preis)
		if typ == Karte.WALL and ego.spiel.freie_waelle > 0:
			p = "×%d" % ego.spiel.freie_waelle
		if typ == Karte.STELLUNG and ego.spiel.freie_stellungen > 0:
			p = "×%d" % ego.spiel.freie_stellungen   # 19.11.: gratis Stellung
		var pf := Stil.GOLD if ego.spiel.budget >= preis else Stil.WARN
		Stil.schreibe(ego._bild, Vector2(r.end.x - 8.0 - Stil.breite(p, 18), m), p, 18, pf if geht else Stil.TEXT_BLASS)
	Stil.schreibe(ego._bild, Vector2(x, hinter.end.y + 14.0), "Rechtsklick: weglegen" if ego.touch == null else "nochmal tippen: weglegen", 16, Stil.TEXT_BLASS)


func _fadenkreuz(g: Vector2, px: float) -> void:
	var m := (g / 2.0).round()
	# 19.11. (Paul): Ladering um das Fadenkreuz – füllt sich beim Aufladen, voll geladen blitzt er auf und pulsiert weiß
	var ladung := ego._glut()
	if ladung > 0.0:
		var rr := 13.0 * px
		var seit := Time.get_ticks_msec() - ego._lade_voll_ms
		var voll := ladung >= 1.0
		ego._bild.draw_arc(m, rr, 0.0, TAU, 48, Color(1, 1, 1, 0.14), px)
		ego._bild.draw_arc(m, rr, -PI / 2.0, -PI / 2.0 + TAU * ladung, 48, Color.WHITE if voll and Time.get_ticks_msec() % 240 < 120 else EgoModus.SCHUSS, 1.5 * px)
		if voll and seit < 300:
			ego._bild.draw_arc(m, rr + seit / 300.0 * 12.0 * px, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - seit / 300.0), px)
		if voll:
			Stil.schreibe_mittig(ego._bild, m - Vector2(0, rr + 6.0 * px), "loslassen", 16, Color.WHITE)
	if ego.ringwerk._feld_zielt and ego.brakk.fortschritt != null and not ego.brakk.fortschritt.ringe.is_empty():
		var fr := ego.brakk.fortschritt.ringe[clampi(ego.brakk.fortschritt.gewaehlt, 0, ego.brakk.fortschritt.ringe.size() - 1)]
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 26.0 * px), ("%s-Feld: %d/4 Fabriken · „Setzen“ tippen · „Abbruch“" if ego.touch != null else "%s-Feld: %d/4 Fabriken · [C] / Linksklick setzen · Rechtsklick / Esc abbrechen") % [str(BrakkFortschritt.RINGE[fr]["name"]), ego.ringwerk._feld_fabriken(ego.ringwerk._feld_ecke).size()], 18, ego._ring_farbe(fr))   # 19.11.
	if ego.saeule._saeule_zielt:
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 26.0 * px), "Linksklick: Lichtsäule setzen · [X] / Rechtsklick: abbrechen", 18, ego.saeule._saeule_farbe)   # 18.11.
	if ego.spiel.werkzeug != Karte.FREI:
		var ziel := ego.ziel_welt()
		var nah := ziel.x > -9000.0 and ego._in_reichweite(ego.karte.zelle_bei(ziel))
		var f := EgoModus.LICHT if nah else Color("ff5a6e")
		var s := 6.0 * px
		ego._bild.draw_rect(Rect2(m - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), f, false, px * 0.5)
		if not nah:
			Stil.schreibe_mittig(ego._bild, m + Vector2(0, s + 10.0 * px), "zu weit", 18, f)
		return
	if ego.kit == null:
		ego._hitze_anzeige(m, px)   # 18.11.; 20.11.: andere Anführer zeigen ihre eigene Hitze
	var treppe_an := ego.hat_aktion("treppe")   # 20.11.: nur wer die Lichttreppe hat
	var gb := ego.gebaeude_im_blick()   # 18.11.: Hinweis zum Ausbauen
	if gb != Karte.KEINE:
		var gb_text := "[F] %s ausbauen" % ego._gebaeude_name(gb)
		if ego.spiel.brakk_modus and ego.spiel.order24 == null:
			gb_text = "[F] %s · [Entf] halten: abbauen · [Z] zurück" % ego._gebaeude_name(gb)   # 22.11.
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego._t(gb_text), 18, EgoModus.LICHT)
		if ego._abbau_t > 0.0:
			ego._bild.draw_arc(m, 11.0 * px, -PI / 2.0, -PI / 2.0 + TAU * clampf(ego._abbau_t / EgoModus.ABBAU_HALTEN, 0.0, 1.0), 32, Stil.WARN, 2.0 * px)   # Fortschrittsring
	elif treppe_an and not ego.brakk.oben and ego._klettern < 0.0 and ego.brakk.e_rest <= 0.0 and not ego.lichtwerk._treppe_ziel().is_empty():
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego._t("[E] Lichttreppe"), 18, EgoModus.LICHT)   # 18.11.
	elif treppe_an and ego.brakk.oben and ego._klettern < 0.0 and ego.lichtwerk._bruecke == null and not ego.lichtwerk._bruecke_ziel().is_empty():
		var bt := "[E] Lichtbrücke" if ego.lichtwerk._bruecke_cd <= 0.0 else "Lichtbrücke in %.0f s" % ceilf(ego.lichtwerk._bruecke_cd)
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego._t(bt), 18, EgoModus.LICHT if ego.lichtwerk._bruecke_cd <= 0.0 else Stil.TEXT_BLASS)   # 18.11.
	elif treppe_an and ego.brakk.oben and ego._klettern < 0.0 and ego.lichtwerk._bruecke == null and ego.brakk.e_rest <= 0.0:
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego._t("[E] Lichttreppe hinunter"), 18, EgoModus.LICHT)   # 19.11.: statt der Vorschau-Bahn nur der Hinweis
	elif ego.kit != null and ego.kit.hinweis() != "":
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego.kit.hinweis(), 18, EgoModus.LICHT)   # 20.11.
	elif ego.ringwerk._am_terminal():
		Stil.schreibe_mittig(ego._bild, m + Vector2(0, 12.0 * px), ego._t("[F] Lichtterminal – Ringe kaufen"), 18, EgoModus.LICHT)
	var l := 3.0 * px
	var lucke := 2.0 * px
	var d := px * 0.6
	var farbe := Color(EgoModus.LICHT, 0.9)
	ego._bild.draw_rect(Rect2(m.x - lucke - l, m.y - d / 2.0, l, d), farbe)
	ego._bild.draw_rect(Rect2(m.x + lucke, m.y - d / 2.0, l, d), farbe)
	ego._bild.draw_rect(Rect2(m.x - d / 2.0, m.y - lucke - l, d, l), farbe)
	ego._bild.draw_rect(Rect2(m.x - d / 2.0, m.y + lucke, d, l), farbe)
	# 18.11.: Trefferkreuz – weiß bei Treffer, rot und größer beim Kill
	if ego._kreuz > 0.0:
		var kf := Color("ff4a5a") if ego._kreuz_kill else Color.WHITE
		kf.a = clampf(ego._kreuz / 0.12, 0.0, 1.0)
		var a := (4.0 if ego._kreuz_kill else 3.0) * px
		var b := a + (4.0 if ego._kreuz_kill else 3.0) * px
		for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			ego._bild.draw_line(m + s * a, m + s * b, kf, px * (0.9 if ego._kreuz_kill else 0.7))


func _male_minikarte() -> void:
	if ego._hud_aus() or ego._sieg_t >= 0.0:
		return
	var g := ego._karte_klein.get_viewport_rect().size
	var zelle := floorf(minf(g.x * 0.16 / Werte.SPALTEN, 7.0))
	zelle = maxf(zelle, 3.0)
	var gross := Vector2(Werte.SPALTEN, Werte.ZEILEN) * zelle
	var o := Vector2(g.x - gross.x - 16.0, 64.0).round()
	var ci := ego._karte_klein
	ci.draw_rect(Rect2(o - Vector2(4, 4), gross + Vector2(8, 8)), Color(0.04, 0.05, 0.08, 0.95))
	ci.draw_rect(Rect2(o - Vector2(4, 4), gross + Vector2(8, 8)), Color(EgoModus.LICHT, 0.35), false, 1.0)
	for z: Vector2i in ego.karte.feld:
		var typ: int = ego.karte.feld[z]
		var f := Color("8b95a3")
		if typ == Karte.FABRIK:
			f = Color("e08a4f")
		elif typ != Karte.WALL:
			f = Color("5d6573")
		if ego.karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
			f = Color("c9a6ff")
		ci.draw_rect(Rect2(o + Vector2(z) * zelle, Vector2(zelle, zelle)), f)
	if ego.karte.basis != Karte.KEINE:
		ci.draw_rect(Rect2(o + Vector2(ego.karte.basis) * zelle, Vector2(zelle, zelle)), EgoModus.LICHT)
	if ego.spiel.order24 != null:
		ego.spiel.order24.minikarte(ci, o, zelle)   # E4 (26.11.): Felsen und Zufluchten
	var k := zelle / float(Werte.ZELLE)
	for gg: Gegner in ego.spiel.ego_gegner():
		if is_instance_valid(gg) and not gg._tot:
			var p := o + Vector2(gg.position.x, gg.position.y - Werte.KARTE_OBEN) * k
			ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color("ff5a6e"))
	# Brakk: Pfeil in Blickrichtung, beim Bauen der Reichweitenkreis
	var b := o + Vector2(ego._fuss2d().x, ego._fuss2d().y - Werte.KARTE_OBEN) * k
	if ego.spiel.werkzeug != Karte.FREI:
		ci.draw_arc(b, EgoModus.BAU_REICHWEITE * zelle, 0.0, TAU, 40, Color(EgoModus.LICHT, 0.5), 1.0)
	var v := Vector2(ego._vorne().x, ego._vorne().z)
	var q := Vector2(-v.y, v.x)
	ci.draw_colored_polygon(PackedVector2Array([b + v * 6.0, b - v * 3.0 + q * 3.5, b - v * 3.0 - q * 3.5]), EgoModus.LICHT)
	# Brakks Leben unter der Karte
	var anteil := clampf(ego.brakk.leben / maxf(1.0, ego.brakk.max_leben), 0.0, 1.0)
	var bal := Rect2(o + Vector2(0, gross.y + 10.0), Vector2(gross.x, 5.0))
	ci.draw_rect(bal, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(bal.position, Vector2(bal.size.x * anteil, bal.size.y)), Color("8fe39a") if anteil > 0.35 else Color("ff5a6e"))
	if ego.brakk.e_rest > 0.0:
		var t := "Treppe %.0f s" % ceilf(ego.brakk.e_rest)
		ci.draw_string(ThemeDB.fallback_font, o + Vector2(0, gross.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(EgoModus.LICHT, 0.8))


func _glyphe(art: String, mitte: Vector2, px: float, farbe: Color) -> void:
	if not EgoModus.GLYPHEN.has(art):
		return
	var b: Array = EgoModus.GLYPHEN[art]
	var o := (mitte - Vector2((b[0] as String).length(), b.size()) * px / 2.0).round()
	for y in b.size():
		var z: String = b[y]
		for x in z.length():
			if z[x] != ".":
				ego._bild.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), farbe if z[x] == "#" else farbe.darkened(0.4))


## Über der Lebensleiste: je Fähigkeit ein Kästchen mit Taste; Abklingzeit als dunkle Füllung, gesperrt grau mit Stufe.
## 20.11. (Nachtrag): bei Irrtürmer und Sonde 7 liefert das Kit je Aktion [Rest 0..1, Text darüber, läuft gerade].
func _faehigkeiten(g: Vector2) -> void:
	var f := ego.brakk.fortschritt
	if f == null:
		return
	var liste: Array = []
	if ego.kit == null:
		liste = [
			["tumble", "Shift", ego._tumble_rest / EgoModus.TUMBLE_ABKLING, "", false],
			["anker", "Q", ego.lichtwerk._anker_rest / (EgoModus.ANKER_ABKLING * ego.lichtwerk._mobil()), "", false],
			["lanze", "RMB", ego._lanze_rest / EgoModus.LANZE_ABKLING, "", false],
			["ulti", "R", _ulti_rest(), "", false],
			["saeule", "X", ego.saeule._saeule_rest / EgoModus.SAEULE_ABKLING, "", false],
			["zeitlupe", "V", ego.saeule._zeitlupe_rest / EgoModus.ZEITLUPE_ABKLING, "", false],
			["treppe", "E", ego.brakk.e_rest / maxf(1.0, float(ego.brakk.daten["kletter_abklingzeit"])), "", false],
		]
	else:
		var tasten: Dictionary = Werte.ANFUEHRER_EGO[ego.anfuehrer()]["tasten"]
		for t: String in EgoModus.LEISTE_TASTEN:
			var was := str(tasten.get(t, ""))
			if was == "":
				continue
			var info := ego.kit.leiste_info(was) if was != "treppe" else [ego.brakk.e_rest / maxf(1.0, float(ego.brakk.daten["kletter_abklingzeit"])), "", false]
			if was == "tumble":
				info = [ego._tumble_rest / EgoModus.TUMBLE_ABKLING, "", false]
			liste.append([was, str(EgoModus.LEISTE_NAME.get(t, t)), info[0], info[1], info[2]])
	var flucht: bool = ego.spiel.order24 != null and ego.spiel.order24.flucht_sperre()   # 21.11.: Befehl 24 – Q/E/R gesperrt bis zum Myriaden-HQ
	var s := 46.0
	var abst := 10.0
	var breite := liste.size() * s + (liste.size() - 1) * abst
	var y := roundf(g.y * 0.86) - 34.0 - 16.0 - s
	var x := roundf((g.x - breite) / 2.0)
	var an_farbe := ego.kit.leiste_farbe() if ego.kit != null else EgoModus.LICHT
	for i in liste.size():
		var e: Array = liste[i]
		var art: String = e[0]
		var r := Rect2(x + i * (s + abst), y, s, s)
		var offen := art == "treppe" or f.frei(art)
		var rest := clampf(float(e[2]), 0.0, 1.0)
		var an := bool(e[4]) and offen
		ego._bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.75))
		var farbe := EgoModus.LICHT if offen and rest <= 0.0 else (Stil.TEXT_BLASS if offen else Color(0.35, 0.37, 0.42))
		if art == "ulti" and offen and rest <= 0.0:
			farbe = Color("c9a6ff")
		if an:
			farbe = an_farbe
			ego._bild.draw_rect(r, Color(an_farbe, 0.18))
		_glyphe(art, r.get_center() - Vector2(0, 4), 4.0, farbe)
		if offen and rest > 0.0:
			ego._bild.draw_rect(Rect2(r.position + Vector2(0, s * (1.0 - rest)), Vector2(s, s * rest)), Color(0, 0, 0, 0.55))
		ego._bild.draw_rect(r, farbe if offen else Color(0.3, 0.32, 0.36), false, 2.0)
		if art == "ulti" and offen and rest > 0.0:
			var txt := "%d/%d" % [f.ulti_ladung, BrakkFortschritt.ULTI_KILLS] if ego.spiel.welle >= f.ulti_ab_welle else "ab R.%d" % f.ulti_ab_welle
			Stil.schreibe_mittig(ego._bild, Vector2(r.get_center().x, r.position.y - 9.0), txt, 14, Color("c9a6ff"))
		elif offen and str(e[3]) != "":
			Stil.schreibe_mittig(ego._bild, Vector2(r.get_center().x, r.position.y - 9.0), str(e[3]), 14, an_farbe if an else Stil.TEXT_BLASS)
		if offen:
			Stil.schreibe_mittig(ego._bild, Vector2(r.get_center().x, r.end.y - 7.0), str(e[1]), 14, Color.WHITE)
		else:
			Stil.schreibe_mittig(ego._bild, Vector2(r.get_center().x, r.end.y - 7.0), "St.%d" % int(BrakkFortschritt.ab_tabelle(f.anfuehrer)[art]), 14, Stil.TEXT_BLASS)
		if flucht and str(e[1]) in Order24.FLUCHT_GESPERRT:
			ego._bild.draw_rect(r, Color(0.02, 0.02, 0.04, 0.7))   # 21.11.: in der Flucht gedimmt
	if flucht:
		Stil.schreibe_mittig(ego._bild, Vector2(g.x / 2.0, y - 26.0), "Weg hier!", 18, Color("ff8a6a"))


## Ulti [R]: Anteil, der noch fehlt (0 = bereit).
func _ulti_rest() -> float:
	if ego.brakk.fortschritt == null:
		return 0.0 if not ego.brakk.klon_genutzt else 1.0
	return ego.brakk.fortschritt.ulti_rest(ego.spiel.welle)


## [R] im Brakk-Mode: die Klonmaschine ist die Ulti – ab Stufe 7, geladen durch eigene Kills, danach eine Runde Pause.
func _ulti() -> void:
	var f := ego.brakk.fortschritt
	var grund := f.ulti_grund(ego.spiel.welle)
	if grund != "":
		ego.spiel.melde(grund, 2.5)
		return
	var text: String = ego.spiel.stelle_klonmaschine(ego.karte.zelle_bei(ego.ziel_welt(true)))
	ego.spiel._kommandant_meldung(text)
	if ego.spiel.klonmaschine != null and ego.brakk.klon_genutzt:
		f.ulti_benutzt(ego.spiel.welle)
		ego._trauma = minf(1.0, ego._trauma + 0.3)
		Ton.spiele(ego.spiel, "alert")


var _briefing: Control = null
var _einflug := -1.0             # läuft: Sekunden seit „Los“ (-1 = nein)
var _los_knopf := Rect2()


func _briefing_zeigen() -> void:
	_briefing = Control.new()
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_briefing.draw.connect(_male_briefing)
	_briefing.gui_input.connect(_briefing_klick)
	ego._ebene.add_child(_briefing)


func _briefing_offen() -> bool:
	return _briefing != null and _briefing.visible and _einflug < 0.0


func _briefing_klick(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _los_knopf.has_point((event as InputEventMouseButton).position):
			_briefing_los()


func _briefing_los() -> void:
	if not _briefing_offen():
		return
	_einflug = 0.0
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ton.spiele(ego.spiel, "ui-klick")
	Ton.spiele(ego.spiel, "tc-arc", -8.0)


## Läuft jedes Bild (Echtzeit): Einflug weiterzählen, am Ende die Tafel weg.
func _einflug_weiter(echt: float) -> void:
	if _einflug < 0.0:
		return
	_einflug += echt
	_briefing.queue_redraw()
	if _einflug >= EgoModus.EINFLUG_SEK:
		_einflug = -1.0
		_briefing.visible = false
		ego._trauma = minf(1.0, ego._trauma + 0.2)   # Brakk landet
		ego._rueckstoss[0] = 0.8
		ego._rueckstoss[1] = 0.8


## Kamera während des Einflugs: von oben hinten herab, mit Blick nach unten, weich in Brakks Augen.
func _einflug_kamera(k: Camera3D) -> void:
	var t := 1.0 if _einflug < 0.0 else clampf(_einflug / EgoModus.EINFLUG_SEK, 0.0, 1.0)
	if _briefing_offen():
		t = 0.0
	if t >= 1.0:
		return
	var e := 1.0 - pow(1.0 - t, 3.0)   # Ease-out
	var rest := 1.0 - e
	k.position += Vector3(0, 9.0 * rest, 0) - ego._vorne() * 7.0 * rest
	k.rotation.x -= 0.75 * rest


var _briefing_t0 := -1
var _sonde_bild: Texture2D = null


func _male_briefing() -> void:
	var ci := _briefing
	var g := ci.get_viewport_rect().size
	if _einflug >= 0.0:
		# Aufblenden aus dem Schwarzen
		var a := clampf(1.0 - _einflug / (EgoModus.EINFLUG_SEK * 0.6), 0.0, 1.0)
		ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0, 0, 0, a))
		return
	if _briefing_t0 < 0:
		_briefing_t0 = Time.get_ticks_msec()
	var zeit := (Time.get_ticks_msec() - _briefing_t0) / 1000.0
	ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0.02, 0.03, 0.05, 0.97))
	for sy in range(0, int(g.y), 4):   # feine Bildzeilen
		ci.draw_rect(Rect2(0, sy, g.x, 1), Color(EgoModus.LICHT, 0.025))
	var w := minf(1040.0, g.x - 40.0)
	var h := minf(580.0, g.y - 40.0)
	var o := ((g - Vector2(w, h)) / 2.0).round()
	var ein := 1.0 - pow(1.0 - clampf(zeit / 0.35, 0.0, 1.0), 3.0)
	o.y += roundf(14.0 * (1.0 - ein))
	Stil.platte(ci, Rect2(o, Vector2(w, h)), 12.0, Color(0.04, 0.05, 0.08, 0.98), EgoModus.LICHT.darkened(0.35))
	# Kopf: Titel, Unterzeile, Warnstreifen rechts, Trennlinie mit hellem Anfang
	Stil.schreibe(ci, o + Vector2(32, 42), "BRAKK-MODE", 40, EgoModus.LICHT)
	Stil.schreibe(ci, o + Vector2(32, 76), "Kommandant Brakk hält die Front – diesmal bist du Brakk.", 18, Stil.TEXT_BLASS)
	for i in 7:
		var sx := o.x + w - 60.0 - i * 18.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, o.y + 26), Vector2(sx + 9, o.y + 26), Vector2(sx + 1, o.y + 50), Vector2(sx - 8, o.y + 50)]),
			Color(Stil.GOLD, 0.55 - i * 0.07))
	Stil.schreibe(ci, Vector2(o.x + w - 186.0 - Stil.breite("EINSATZ", 16), o.y + 38), "EINSATZ", 16, Color(Stil.GOLD, 0.8))
	ci.draw_rect(Rect2(o.x + 32, o.y + 100, w - 64, 1), Color(EgoModus.LICHT, 0.3))
	ci.draw_rect(Rect2(o.x + 32, o.y + 99, 120, 3), EgoModus.LICHT)
	# Steuerung als Tastenkappen in zwei Spalten
	var touch_an := Touch.ohne_maus()
	var tasten: Array = [
		[["W", "A", "S", "D"], "laufen"],
		[["Maus", "Klick"], "zielen, schießen – Pistolen im Wechsel"],
		[["Shift", "Leer"], "Rolle · Sprung"],
		[["E"], "Lichttreppe, oben Lichtbrücke"],
		[["1–7"], "bauen (5 Felder Reichweite)"],
		[["F"], "ausbauen · an der Basis: Lichtterminal"],
		[["Rad"], "aktiver Ring"],
		[["C"], "Ringfeld: Fabriken bauen seine Truppe"],
	]
	if touch_an:
		tasten = [
			[["links"], "laufen"],
			[["rechts"], "wischen zum Zielen – Brakk schießt selbst"],
			[["tippen"], "Fähigkeiten auslösen"],
			[["halten"], "und ziehen: Fähigkeit zielen"],
			[["Rand"], "bauen, ausbauen, Ringe"],
		]
	Stil.schreibe(ci, o + Vector2(32, 126), "STEUERUNG", 18, Stil.GOLD)
	var spalte := (w - 64.0) / 2.0
	for i in tasten.size():
		var reihe: Array = tasten[i]
		var p := o + Vector2(32.0 + (i % 2) * spalte, 162.0 + (i / 2) * 44.0)
		var sichtbar := clampf((zeit - 0.15 - i * 0.05) / 0.25, 0.0, 1.0)
		if sichtbar <= 0.0:
			continue
		var x := p.x
		for t: String in reihe[0]:
			x += _briefing_taste(ci, Vector2(x, p.y), t, true, sichtbar) + 4.0
		Stil.schreibe(ci, Vector2(x + 8.0, p.y), str(reihe[1]), 18, Color(Stil.TEXT, sichtbar))
	# Freischaltbar mit den Stufen: gedimmte Kappen mit Namen
	if not touch_an:
		var y := o.y + 162.0 + 4 * 44.0 + 4.0
		Stil.schreibe(ci, Vector2(o.x + 32, y), "MIT DEN STUFEN", 16, Stil.TEXT_BLASS)
		var x := o.x + 32.0 + Stil.breite("MIT DEN STUFEN", 16) + 16.0
		for f: Array in [["Q", "Anker"], ["RK", "Ladestrahl"], ["X", "Lichtsäule"], ["R", "Klon"], ["V", "Zeitlupe"]]:
			x += _briefing_taste(ci, Vector2(x, y), str(f[0]), false, 1.0) + 6.0
			Stil.schreibe(ci, Vector2(x, y), str(f[1]), 16, Stil.TEXT_BLASS)
			x += Stil.breite(str(f[1]), 16) + 18.0
	# Funkfenster: Sonde 7 tippt den Ablauf
	var funk := Rect2(o.x + 32, o.y + 386, w - 64, 112)
	Stil.platte(ci, funk, 6.0, Color(0.03, 0.10, 0.16, 0.92), EgoModus.BRIEFING_HOLO.darkened(0.25))
	if _sonde_bild == null:
		_sonde_bild = load(EgoModus.BRIEFING_SONDE)
	var bild := Rect2(funk.position + Vector2(8, 8), Vector2(96, 96))
	ci.draw_rect(bild, Color(0.01, 0.04, 0.07))
	if _sonde_bild != null:
		ci.draw_texture_rect(_sonde_bild, bild, false)
	var text := EgoModus.BRIEFING_FUNK_TOUCH if touch_an else EgoModus.BRIEFING_FUNK
	var gezeigt := int(maxf(zeit - 0.5, 0.0) * EgoModus.BRIEFING_TIPPEN)
	var spricht := gezeigt < text.length()
	for l: Array in EgoModus.BRIEFING_LICHTER:
		var staerke := (0.35 + 0.65 * absf(sin(zeit * 11.0 + float(l[0])))) if spricht else 0.25
		var lp := bild.position + Vector2(float(l[0]), float(l[1]))
		ci.draw_circle(lp, float(l[2]) * 1.6, Color(l[3], 0.22 * staerke))
		ci.draw_circle(lp, float(l[2]) * 0.8, Color(l[3], 0.55 * staerke))
	ci.draw_rect(bild, EgoModus.BRIEFING_HOLO.darkened(0.3), false, 1.0)
	var tx := bild.end.x + 16.0
	Stil.schreibe(ci, Vector2(tx, funk.position.y + 18.0), "SONDE 7 · LEITSTELLE", 16, EgoModus.BRIEFING_HOLO)
	if spricht and fmod(zeit, 0.5) < 0.25:
		ci.draw_circle(Vector2(tx + Stil.breite("SONDE 7 · LEITSTELLE", 16) + 10.0, funk.position.y + 18.0), 3.0, Stil.ROT)
	Stil.absatz(ci, Vector2(tx, funk.position.y + 30.0), text.left(gezeigt), funk.end.x - tx - 14.0, 18, EgoModus.BRIEFING_HOLO_TEXT)
	# Los-Knopf mit abgeschrägten Ecken
	_los_knopf = Rect2(Vector2(o.x + w / 2.0 - 140.0, o.y + h - 66.0), Vector2(280, 44))
	var puls := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	Stil.platte(ci, _los_knopf, 8.0, Color(EgoModus.LICHT.darkened(0.6), 0.6 + 0.3 * puls), EgoModus.LICHT)
	Stil.schreibe_mittig(ci, _los_knopf.get_center(), "Los geht's" + ("" if touch_an else "  [Enter]"), 22, Color.WHITE)


## Eine Tastenkappe mit linker Mitte `p`; gibt ihre Breite zurück. `aktiv = false`: gedimmt (noch gesperrt).
func _briefing_taste(ci: CanvasItem, p: Vector2, t: String, aktiv: bool, a: float) -> float:
	var groesse := 18 if aktiv else 16
	var bw := maxf(28.0 if aktiv else 24.0, Stil.breite(t, groesse) + 14.0)
	var hh := 28.0 if aktiv else 22.0
	var r := Rect2(p.x, p.y - hh / 2.0, bw, hh)
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.5 * a))   # Kappe steht etwas hoch
	Stil.platte(ci, r, 3.0, Color(Stil.METALL_TIEF, a), Color(EgoModus.LICHT if aktiv else Stil.RAHMEN, a))
	Stil.schreibe_mittig(ci, r.get_center(), t, groesse, Color(Color.WHITE if aktiv else Stil.TEXT_BLASS, a))
	return bw


var _werte_alt := {}
var _werte_blink := {}


func _prozent(faktor: float) -> String:
	return "%+d %%" % roundi((faktor - 1.0) * 100.0)


## {"zeilen": [[Schlüssel, Name, Zahl, [[Bonus, Farbe], …]], …], "zusatz": [[Text, Farbe], …]}
func _werte_zeilen() -> Dictionary:
	if ego.kit != null:
		return ego.kit.werte_zeilen()   # 20.11.: Werte-Fenster des Anführers
	var f := ego.brakk.fortschritt
	var schuss := EgoModus.SCHUSS_SCHADEN * f.schuss_schaden()
	var her: Array = []
	var takt_her: Array = []
	var zusatz: Array = []
	for r: String in f.ringe:
		var d: Dictionary = BrakkFortschritt.RINGE[r]["brakk_stufen"][clampi(f.ring_stufe(r), 1, 3) - 1]
		var farbe := ego._ring_farbe(r)
		if d.has("schaden"):
			zusatz.append(["Schaden " + _prozent(float(d["schaden"])), farbe])
		if d.has("takt"):
			zusatz.append(["Tempo " + _prozent(1.0 / float(d["takt"])), farbe])
		if d.has("anlauf"):
			zusatz.append(["Anlauf bis " + _prozent(float(d["anlauf"])), farbe])
		if d.has("weitere"):
			zusatz.append(["Durchschlag %d" % (d["weitere"] as Array).size(), farbe])
		if d.has("mark_bonus"):
			zusatz.append(["Ziel %s" % _prozent(float(d["mark_bonus"])), farbe])
		if d.has("gel_bonus"):
			zusatz.append(["Gebremste " + _prozent(float(d["gel_bonus"])), farbe])
		if d.has("brand_takt"):
			zusatz.append(["Brand je %s s" % str(d["brand_takt"]).replace(".", ","), farbe])
		if d.has("spruenge"):
			zusatz.append(["Sprung %d× %d %%" % [int(d["spruenge"]), roundi(float(d["sprung_anteil"]) * 100.0)], farbe])
		if d.has("schutz"):
			zusatz.append(["Schutz %d %%" % roundi(float(d["schutz"]) * 100.0), farbe])
	var pro_sek := 1.0 / maxf(0.01, EgoModus.SCHUSS_TAKT * ego._takt_faktor())
	return {"zeilen": [
		["schaden", "Schaden", "%.0f" % schuss, her],
		["takt", "Schüsse/s", ("%.1f" % pro_sek).replace(".", ","), takt_her],
		["dps", "Schaden/s", "%.0f" % (schuss * pro_sek), []],
	], "zusatz": zusatz}


func _werte_fenster(g: Vector2) -> void:
	var f := ego.brakk.fortschritt
	if f == null:
		return
	var werte := _werte_zeilen()
	var zeilen: Array = werte["zeilen"]
	var zusatz: Array = werte["zusatz"]
	var jetzt := Time.get_ticks_msec()
	for z: Array in zeilen:
		var k: String = z[0]
		if _werte_alt.has(k) and _werte_alt[k] != z[2]:
			_werte_blink[k] = jetzt + EgoModus.WERTE_BLINK_MS
		_werte_alt[k] = z[2]
	var gruen := Color("7dffa0")
	if ego.touch != null:
		# Handy: eine Zeile über der Lebensleiste (unten links liegt der Stick)
		var breite := clampf(g.x * 0.26, 260.0, 460.0)
		var bx := (g.x - breite) / 2.0
		var by := roundf(g.y * 0.86) - 34.0
		var text := "Schaden %s · %s/s · %s Schaden/s" % [zeilen[0][2], zeilen[1][2], zeilen[2][2]]
		var tw := Stil.breite(text, 16) + 16.0
		var o2 := Vector2(bx, by - 12.0 - 24.0)
		ego._bild.draw_rect(Rect2(o2, Vector2(tw, 24.0)), Color(0.04, 0.05, 0.08, 0.62))
		var blinkt := false
		for z: Array in zeilen:
			blinkt = blinkt or int(_werte_blink.get(z[0], 0)) > jetzt
		Stil.schreibe(ego._bild, o2 + Vector2(8.0, 12.0), text, 16, gruen if blinkt else Stil.TEXT)
		return
	var w := 146.0   # die linke Waffe beginnt bei etwa 160
	var zh := 23.0
	var kh := 16.0
	var n := mini(zusatz.size(), 5)
	var h := 6.0 + zh * zeilen.size() + (5.0 + kh * n if n > 0 else 0.0) + 4.0
	var o := Vector2(10.0, g.y - 10.0 - h)
	ego._bild.draw_rect(Rect2(o, Vector2(w, h)), Color(0.04, 0.05, 0.08, 0.72))
	ego._bild.draw_rect(Rect2(o, Vector2(w, h)), Color(1, 1, 1, 0.14), false, 1.0)
	ego._bild.draw_rect(Rect2(o, Vector2(2.0, h)), Color(Stil.GOLD, 0.8))
	for i in zeilen.size():
		var z: Array = zeilen[i]
		var my := o.y + 6.0 + zh * (i + 0.5)
		if i > 0:
			ego._bild.draw_rect(Rect2(o.x + 8.0, o.y + 6.0 + zh * i, w - 16.0, 1.0), Color(1, 1, 1, 0.07))
		var x := o.x + 11.0
		x += Stil.schreibe(ego._bild, Vector2(x, my), str(z[1]), 16, Stil.TEXT_BLASS) + 7.0
		for b: Array in (z[3] as Array):
			x += Stil.schreibe(ego._bild, Vector2(x, my), str(b[0]), 13, b[1]) + 5.0
		var blink := int(_werte_blink.get(z[0], 0)) > jetzt
		var zahl := str(z[2])
		Stil.schreibe(ego._bild, Vector2(o.x + w - 9.0 - Stil.breite(zahl, 20), my), zahl, 20, gruen if blink else Stil.GOLD)
	if n > 0:
		var y0 := o.y + 6.0 + zh * zeilen.size() + 3.0
		ego._bild.draw_rect(Rect2(o.x + 8.0, y0 - 2.0, w - 16.0, 1.0), Color(1, 1, 1, 0.14))
		for i in n:
			var e: Array = zusatz[i]
			var my2 := y0 + 2.0 + kh * (i + 0.5)
			ego._bild.draw_rect(Rect2(o.x + 11.0, my2 - 3.0, 6.0, 6.0), e[1])
			var t := str(e[0]) if i < 4 or zusatz.size() <= 5 else "+ %d weitere" % (zusatz.size() - 4)
			Stil.schreibe(ego._bild, Vector2(o.x + 23.0, my2), t, 14, Stil.TEXT)
