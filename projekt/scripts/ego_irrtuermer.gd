class_name EgoIrrtuermer
extends EgoKit
## 20.11.: Schritt 6b – Kit des Irrtürmers im Brakk-Mode: Mauern und Gefährte. Alle Zahlen in Werte.IRRTUERMER und
## Werte.PLIPLOP_PFADE. Belegung in Werte.ANFUEHRER_EGO (Linksklick Prellbolzen, Rechtsklick halten Hack, Q Überladen,
## X Hierher!, V Ringtausch, R Aufsatz; Shift Rolle, Leertaste Sprung, E Lichttreppe, C Ringfeld wie bei Brakk).
## Ring-Signatur: zwei Ringslots (Hand und PliPlop) und der Verbund – trifft denselben Gegner innerhalb des Fensters je ein
## Effekt beider getragenen Ringe (aus Hand, PliPlop oder Hack), nimmt er mehr Schaden. Eine Regel, keine Paar-Tabelle.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const HACK_FARBE := Color("ffd34d")
const VERBUND_FARBE := Color("fff6c8")

var pp: PliPlop = null
var _bolzen: Array = []          # fliegende Prellbolzen: {p: Vector3, v: Vector3, weg, prall, knoten}
var _hack := false               # Rechtsklick gehalten
var _hack_ziel := {}             # {"art": "turm"/"batterie"/"pliplop", "zelle": Vector2i}
var _hack_takt := 0.0
var _hack_strahl: MeshInstance3D = null
var _ueberladen_rest := 0.0      # Cooldown von [Q]
var _aufsatz_bis := 0            # ms; Aufsatz läuft bis dahin
var _aufsatz_welle := -1         # in dieser Runde schon benutzt
var _welle := -1
var _blitz := 0.0
var _rueck := 0.0
var _tex_werfer: Texture2D
# 20.11. (Nachtrag): Ring-Wirkung je Spell (Werte.RING_SPELLS)
var _hack_seit := 0.0            # so lange wird schon gehackt (Anlauf)
var _echo_ms := 0                # Echo des letzten Hack-Schusses fällig (ms)
var _echo_mal := 0.0
var _durch_an := false           # gerade ein Durchschlag-Treffer (keine Kette)
var _ueb_ende := []              # [bis ms, Punkt, Hitzestoß-Schaden] – Überladen endet
var _hier_angekommen := true
var _hier_ring := ""             # Ring beim Befehl „Hierher“ (wirkt am Haltepunkt)
var _hier_st := 1
var _tausch_bis := 0             # ms: nach dem Ringtausch schneller
var _tausch_mal := 1.0
var _aufsatz_ring := ""          # Ring beim Auslösen des Aufsatzes
var _aufsatz_st := 1


## 20.11. (Nachtrag): Spells färbt der aktive Ring des Helden.
func spell_ring() -> String:
	return hand_ring()


func spell_ring_stufe() -> int:
	return maxi(1, f().satz_aktiv_stufe("held"))


## Wirkung eines beim Auslösen gemerkten Rings (Hierher, Aufsatz wirken länger als der Ring aktiv sein muss).
func _gemerkt_w(spell: String, art: String, ring: String, st: int) -> float:
	var e := Werte.ring_spell("irrtuermer", spell, ring)
	return Werte.ring_spell_wert(e, st) if str(e.get("art", "")) == art else 0.0


func schutz() -> float:
	var s := super()
	if _hack:
		s = maxf(s, spell_w("hack", "schutz") / 100.0)
	if aufsatz_an():
		s = maxf(s, _gemerkt_w("aufsatz", "schutz", _aufsatz_ring, _aufsatz_st) / 100.0)
	return s


## Takt-Faktor nach dem Ringtausch (Takt-Ring).
func _tausch_faktor() -> float:
	return 1.0 / _tausch_mal if Time.get_ticks_msec() < _tausch_bis else 1.0


func _init(p_ego: EgoModus) -> void:
	super(p_ego)
	_tex_werfer = ImageTexture.create_from_image(_male_werfer())
	pp = PliPlop.new()
	ego.spiel.figuren.add_child(pp)
	pp.einrichten(ego.spiel, self, ego._fuss2d() + Vector2(-Werte.ZELLE, Werte.ZELLE * 0.5), ego.brakk.max_leben * float(Werte.IRRTUERMER["pliplop"]["leben"]))


func f() -> BrakkFortschritt:
	return ego.brakk.fortschritt


## Ring in der Hand / am PliPlop ("" = keiner).
func hand_ring() -> String:
	return f().satz_aktiv("held")   # 20.11. (Nachtrag): aktiver Ring des Held-Satzes


func pp_ring() -> String:
	return f().satz_aktiv("pp")


## Pfad des PliPlop (aus seinem Ring).
func pfad() -> Dictionary:
	return Werte.PLIPLOP_PFADE.get(pp_ring(), Werte.PLIPLOP_PFADE[""])


## 20.11. (Nachtrag): "@held" / "@pp" = alle Ringe des Satzes zusammen (BrakkFortschritt.RING_STAPEL), sonst ein Ring.
func ring_wert(ring: String, schluessel: String, std: Variant) -> Variant:
	if ring == "@held":
		return f().satz_wert("held", schluessel, std)
	if ring == "@pp":
		return f().satz_wert("pp", schluessel, std)
	return super(ring, schluessel, std)


func pp_farbe() -> Color:
	return ego._ring_farbe(pp_ring()) if pp_ring() != "" else Color("9fe8ff")


func hand_farbe() -> Color:
	return ego._ring_farbe(hand_ring()) if hand_ring() != "" else Color("ffb070")


func aufsatz_an() -> bool:
	return Time.get_ticks_msec() < _aufsatz_bis


# ------------------------------------------------------------------ Aktionen

func aktion(was: String, gedrueckt: bool) -> bool:
	match was:
		"prellbolzen":
			ego._feuer = gedrueckt
			return true
		"hack":
			if gedrueckt:
				_hack_an()
			else:
				_hack_aus()
			return true
	if not gedrueckt:
		return false
	match was:
		"ueberladen":
			_ueberladen()
		"hierher":
			_hierher()
		"ringtausch":
			_ringtausch()
		"aufsatz":
			_aufsatz()
		_:
			return false
	return true


func _hack_an() -> void:
	if aufsatz_an():
		ego.spiel.melde("Während des Aufsatzes kein Hack.", 1.5)
		return
	var ziel := _hack_ziel_im_blick()
	if ziel.is_empty():
		ego.spiel.melde("Kein Formturm, keine Batterie und kein PliPlop im Blick (höchstens %s Felder)." % BrakkFortschritt._zahl(Werte.IRRTUERMER["hack"]["weite"]), 2.0)
		return
	_hack = true
	_hack_ziel = ziel
	_hack_takt = 0.0
	_hack_seit = 0.0
	ego._feuer = false
	Ton.spiele(ego.spiel, "tc-arc", -8.0)


func _hack_aus() -> void:
	_hack = false
	_hack_ziel = {}
	if _hack_strahl != null:
		_hack_strahl.visible = false


func _ueberladen() -> void:
	if aufsatz_an():
		ego.spiel.melde("Während des Aufsatzes kein Überladen.", 1.5)
		return
	if _ueberladen_rest > 0.0:
		ego.spiel.melde("Überladen wieder in %d s." % ceili(_ueberladen_rest), 1.5)
		return
	var d: Dictionary = Werte.IRRTUERMER["ueberladen"]
	var sek := float(d["sek"]) * (1.0 + spell_w("ueberladen", "dauer") / 100.0)   # 20.11. (Nachtrag): Wirbel-Ring
	var bis := Time.get_ticks_msec() + int(sek * 1000.0)
	var wo := Vector2.INF
	var turm := Karte.KEINE
	if _hack and str(_hack_ziel.get("art", "")) != "pliplop":
		var z: Vector2i = _hack_ziel["zelle"]
		ego.spiel.turm_ueberladen[z] = [bis, float(d["mal"])]
		ego.spiel.effekte.welle(ego.karte.mitte(z), Werte.ZELLE * 0.9, HACK_FARBE, "funk", 0.6)
		ego.spiel.melde("Überladen: der gehackte Turm feuert %s s doppelt so schnell." % BrakkFortschritt._zahl(sek), 2.0)
		wo = ego.karte.mitte(z)
		turm = z
	elif pp.einsatzbereit():
		pp.ueberladen_bis = bis
		ego.spiel.effekte.welle(pp.position, Werte.ZELLE * 0.9, HACK_FARBE, "funk", 0.6)
		ego.spiel.melde("Überladen: PliPlop feuert %s s doppelt so schnell." % BrakkFortschritt._zahl(sek), 2.0)
		wo = pp.position
	else:
		ego.spiel.melde("PliPlop ist nicht da.", 1.5)
		return
	_ueberladen_rest = float(d["abkling"]) * (1.0 - spell_w("ueberladen", "abkling") / 100.0)   # Takt-Ring
	_ueberladen_spell(wo, turm, sek, bis)
	_zaehle("ueberladen")
	Ton.spiele(ego.spiel, "alert", -8.0)


## 20.11. (Nachtrag): Ring-Wirkung an „Überladen“ (Werte.RING_SPELLS) – am überladenen Turm bzw. PliPlop.
func _ueberladen_spell(wo: Vector2, turm: Vector2i, sek: float, bis: int) -> void:
	var w := spell_w("ueberladen", "truppenschild")
	if w > 0.0:
		var ende := Time.get_ticks_msec() + 8000
		for e: Einheit in ego._truppen_um(wo, 2.0):
			e.ring_schild = e.max_leben * w / 100.0
			e.ring_schild_bis = ende
			ego.spiel.effekte.welle(e.position, Werte.ZELLE * 0.55, hand_farbe(), "heil", 0.8)
	w = spell_w("ueberladen", "bremswelle")
	if w > 0.0:
		bremse_umkreis(wo, 2.0, w)
	w = spell_w("ueberladen", "markwelle")
	if w > 0.0:
		var bonus := float(BrakkFortschritt.RINGE["markierung"]["brakk_stufen"][clampi(spell_ring_stufe(), 1, 3) - 1]["mark_bonus"])
		for g: Gegner in _im_umkreis(wo, 2.5 * Werte.ZELLE):
			g.markiert = maxf(g.markiert, w)
			g.markier_faktor = bonus
			g.markiert_brakk = true
		ego.spiel.effekte.welle(wo, 2.5 * Werte.ZELLE, ego._ring_farbe("markierung"), "funk", 0.6)
	w = spell_w("ueberladen", "zweiter_turm")
	if w > 0.0 and turm != Karte.KEINE:
		var bester := Karte.KEINE
		var beste := 3.0 * Werte.ZELLE + 1.0
		for z: Vector2i in ego.karte.turm_art:
			if z != turm and ego.karte.ausbau.get(z, Karte.FREI) == Karte.TURM and ego.karte.mitte(z).distance_to(wo) < beste:
				beste = ego.karte.mitte(z).distance_to(wo)
				bester = z
		if bester != Karte.KEINE:
			ego.spiel.turm_ueberladen[bester] = [Time.get_ticks_msec() + int(sek * w / 100.0 * 1000.0), float(Werte.IRRTUERMER["ueberladen"]["mal"])]
			ego.spiel.effekte.strahl(wo, ego.karte.mitte(bester), HACK_FARBE, 2.0)
	w = spell_w("ueberladen", "hitzestoss")
	if w > 0.0:
		var d: Dictionary = Werte.IRRTUERMER["bolzen"]
		_ueb_ende = [bis, wo, float(d["schaden"]) * f().schaden_faktor() * w / 100.0]


## 20.11. (Nachtrag): laufende Ring-Wirkungen (Ende des Überladens, Ankunft des PliPlop).
func _spells_weiter() -> void:
	if not _ueb_ende.is_empty() and Time.get_ticks_msec() >= int(_ueb_ende[0]):
		hitzestoss(_ueb_ende[1], 1.5, float(_ueb_ende[2]))
		_ueb_ende = []
	if pp.hier != Vector2.INF and not _hier_angekommen and pp.position.distance_to(pp.hier) <= Werte.ZELLE * 0.6:
		_hier_angekommen = true
		var w := _gemerkt_w("hierher", "ankunft_bremse", _hier_ring, _hier_st)
		if w > 0.0:
			bremse_umkreis(pp.position, 1.5, w)
		w = _gemerkt_w("hierher", "ankunft_brand", _hier_ring, _hier_st)
		if w > 0.0:
			brand_bei(pp.position, w, float(Werte.IRRTUERMER["bolzen"]["schaden"]) * f().schaden_faktor() * 0.3)


## Hack hält: Glut-Ring (der Turm selbst feuert schneller), Gel-Ring (der Strahl bremst).
func _hack_spell_weiter() -> void:
	var w := spell_w("hack", "turm_takt")
	if w > 0.0 and str(_hack_ziel.get("art", "")) != "pliplop":
		var z: Vector2i = _hack_ziel["zelle"]
		var alt: Array = ego.spiel.turm_ueberladen.get(z, [])
		if alt.is_empty() or int(alt[0]) < Time.get_ticks_msec() + 200 and float(alt[1]) <= 1.0 + w / 100.0:
			ego.spiel.turm_ueberladen[z] = [Time.get_ticks_msec() + 250, 1.0 + w / 100.0]
	w = spell_w("hack", "gelstrahl")
	if w > 0.0:
		var von := ego._fuss2d()
		var bis := _hack_punkt()
		var lang := von.distance_to(bis)
		for g: Gegner in _in_linie(von, (bis - von).normalized(), lang):
			g.gebremst = maxf(g.gebremst, w)


## Hierher: PliPlop pp-Wirkungen am Haltepunkt (Wall-, Takt-, Ziel-Ring).
func pp_hier_w(art: String) -> float:
	if pp.hier == Vector2.INF:
		return 0.0
	return _gemerkt_w("hierher", art, _hier_ring, _hier_st)


func _hierher() -> void:
	if not pp.einsatzbereit():
		ego.spiel.melde("PliPlop ist nicht da.", 1.5)
		return
	if pp.hier != Vector2.INF:
		pp.hier = Vector2.INF
		ego.spiel.melde("PliPlop folgt wieder.", 1.5)
		return
	var p := ego.ziel_welt(true)
	var z := ego.karte.zelle_bei(p)
	if p.x < -9000.0 or not ego.karte.in_karte(z) or not ego.karte.ist_begehbar(z):
		ego.spiel.melde("Dort kann PliPlop nicht hin.", 1.5)
		return
	pp.hier = p
	# 20.11. (Nachtrag): Ring-Wirkung am Haltepunkt – der Ring beim Befehl zählt, solange PliPlop dort bleibt
	_hier_ring = spell_ring()
	_hier_st = spell_ring_stufe()
	_hier_angekommen = false
	if spell_hat("hierher", "springen"):
		ego.spiel.effekte.strahl(pp.position, p, pp_farbe(), 2.0)
		pp.position = pp._freier_platz(p)
	ego.spiel.effekte.flaeche(p, Werte.ZELLE * 0.5, pp_farbe())
	ego.spiel.melde("PliPlop rollt hin und bleibt dort – [X] nochmal: folgen.", 2.0)


func _ringtausch() -> void:
	if f().ringe.is_empty() and f().pp_ringe.is_empty():
		ego.spiel.melde("Noch kein Ring – am Lichtterminal der Basis kaufen.", 2.0)
		return
	var e := spell_eintrag("ringtausch")   # 20.11. (Nachtrag): Ring des Helden vor dem Tausch
	var w := Werte.ring_spell_wert(e, spell_ring_stufe())
	if not f().tausche():   # 20.11. (Nachtrag): aktiver Ring des Helden ↔ aktiver Ring des PliPlop
		ego.spiel.melde("Kein Platz zum Tauschen.", 1.5)
		return
	match str(e.get("art", "")):
		"tausch_takt":
			_tausch_bis = Time.get_ticks_msec() + 3000
			_tausch_mal = 1.0 + w / 100.0
		"pp_heilen":
			if pp.einsatzbereit():
				pp.leben = minf(pp.max_leben, pp.leben + pp.max_leben * w / 100.0)
				ego.spiel.effekte.plus(pp.position + Vector2(0, -14), Color("7dff9a"))
		"tausch_bremse":
			bremse_umkreis(ego._fuss2d(), 1.5, w)
			if pp.einsatzbereit():
				bremse_umkreis(pp.position, 1.5, w)
	ego._ring_blitz = 0.3
	ego.spiel.melde("Hand: %s · PliPlop: %s (%s)" % [_ring_name(hand_ring()), _ring_name(pp_ring()), str(pfad()["name"])], 2.5)
	Ton.spiele(ego.spiel, "ui-klick", -4.0)


func _aufsatz() -> void:
	if _aufsatz_welle == int(ego.spiel.welle):
		ego.spiel.melde("Der Aufsatz geht einmal je Runde.", 1.5)
		return
	if not pp.einsatzbereit():
		ego.spiel.melde("PliPlop ist nicht da.", 1.5)
		return
	_hack_aus()
	_aufsatz_welle = int(ego.spiel.welle)
	_aufsatz_ring = spell_ring()   # 20.11. (Nachtrag): Ring beim Auslösen
	_aufsatz_st = spell_ring_stufe()
	_aufsatz_bis = Time.get_ticks_msec() + int((float(Werte.IRRTUERMER["aufsatz"]["sek"]) + spell_w("aufsatz", "dauer")) * 1000.0)
	pp.angedockt = true
	pp.visible = false
	pp.ueberladen_bis = 0
	_zaehle("aufsatz")
	ego._trauma = minf(1.0, ego._trauma + 0.2)
	Ton.spiele(ego.spiel, "hit-thud", -4.0)
	ego.spiel.melde("Aufsatz: %s s feuerst du den Pfad des PliPlop (%s)." % [BrakkFortschritt._zahl(Werte.IRRTUERMER["aufsatz"]["sek"]), str(pfad()["name"])], 2.5)


func _aufsatz_ende() -> void:
	_aufsatz_bis = 0
	var w := _gemerkt_w("aufsatz", "hitzestoss", _aufsatz_ring, _aufsatz_st)   # 20.11. (Nachtrag): Glut-Ring
	if w > 0.0:
		hitzestoss(ego._fuss2d(), 2.0, float(Werte.IRRTUERMER["bolzen"]["schaden"]) * f().schaden_faktor() * w / 100.0)
	pp.angedockt = false
	pp.visible = not pp.gefallen
	pp.leer_bis = Time.get_ticks_msec() + int(float(Werte.IRRTUERMER["aufsatz"]["leer"]) * 1000.0)
	pp.position = pp._freier_platz(ego._fuss2d() - _vorne2d() * Werte.ZELLE)


# ------------------------------------------------------------------ Ablauf

func tempo_faktor() -> float:
	if aufsatz_an():
		return float(Werte.IRRTUERMER["aufsatz"]["tempo"])
	if _hack:
		return float(Werte.IRRTUERMER["hack"]["tempo"])
	return 1.0


func weiter(echt: float, frei: bool) -> void:
	if int(ego.spiel.welle) != _welle:
		_welle = int(ego.spiel.welle)
		if not pp.gefallen:
			pp.leben = pp.max_leben   # neue Runde: PliPlop wie der Irrtürmer voll geheilt
	pp.max_leben = ego.brakk.max_leben * float(Werte.IRRTUERMER["pliplop"]["leben"])
	_ueberladen_rest = maxf(0.0, _ueberladen_rest - echt)
	_blitz = maxf(0.0, _blitz - echt)
	_rueck = maxf(0.0, _rueck - echt * 6.0)
	if _aufsatz_bis > 0 and not aufsatz_an():
		_aufsatz_ende()
	var kam := ego._zu2d(ego.hd.kamera.global_position)
	pp.weiter(echt, ego._fuss2d(), _vorne2d(), kam)
	if pp.einsatzbereit() and not pp.leer() and pp.takt <= 0.0:
		_pp_schiesst()
	_bolzen_weiter(echt)
	if _hack:
		if not frei or not _hack_gueltig():
			if frei:
				ego.spiel.melde("Hack abgerissen.", 1.2)
			_hack_aus()
		else:
			_hack_takt -= echt
			_hack_seit += echt
			if _hack_takt <= 0.0:
				_hack_schuss()
				var echo := spell_w("hack", "echo")
				if echo > 0.0:
					_echo_ms = Time.get_ticks_msec() + 200   # Takt-Ring: Echo
					_echo_mal = echo / 100.0
			_hack_spell_weiter()
	if _echo_ms > 0 and Time.get_ticks_msec() >= _echo_ms:
		_echo_ms = 0
		if _hack:
			var t := _hack_takt
			_hack_schuss(_echo_mal)
			_hack_takt = t
	_spells_weiter()
	glut_weiter(echt)
	_hack_strahl_zeigen()


func _vorne2d() -> Vector2:
	return Vector2(ego._vorne().x, ego._vorne().z).normalized()


func gefallen() -> void:
	pp.faellt(true)   # der PliPlop fällt mit
	_hack_aus()
	if aufsatz_an():
		_aufsatz_bis = 0


func wieder_da() -> void:
	if pp.gefallen:
		pp.kommt_zurueck(ego._fuss2d() - _vorne2d() * Werte.ZELLE)


func beenden() -> void:
	for b: Dictionary in _bolzen:
		(b["knoten"] as Node).queue_free()
	_bolzen.clear()
	if _hack_strahl != null:
		_hack_strahl.queue_free()
	if is_instance_valid(pp):
		pp.queue_free()


func _zaehle(was: String) -> void:
	f().zaehler[was] = int(f().zaehler.get(was, 0)) + 1


static func _ring_name(ring: String) -> String:
	return EgoModus.ring_kurz(ring) if ring != "" else "–"


# ------------------------------------------------------------------ Prellbolzen

## Linksklick: ein Bolzen fliegt durchs Fadenkreuz, prallt bis zu „abpraller“ Mal von Mauern ab und platzt am Gegner.
## Während des Aufsatzes feuert die Hand stattdessen den Pfad des PliPlop; beim Hack schießt nur der gehackte Turm
## (außer beim Funkturm: dann fliegen die Bolzen schneller).
func schuss() -> void:
	var d: Dictionary = Werte.IRRTUERMER["bolzen"]
	var takt := float(d["takt"]) * float(ring_wert("@held", "takt", 1.0)) * _tausch_faktor()   # 20.11. (Nachtrag): Takt-Ring am Ringtausch
	if aufsatz_an():
		ego._takt = takt / (1.0 + _gemerkt_w("aufsatz", "aufsatz_takt", _aufsatz_ring, _aufsatz_st) / 100.0)   # 20.11. (Nachtrag): Takt-Ring
		var ziel := _ziel_im_blick(float(d["weite"]))   # aus der Hand so weit wie der Bolzen
		_rueck = 1.0
		_blitz = 0.06
		if ziel != null:
			pfad_feuer(ego._fuss2d(), _hand3d(), ziel, pp_ring(), "aufsatz", "pp")
		else:
			ego._strahl(_hand3d(), ego.hd.kamera.global_position + ego._schuss_blick() * 6.0, pp_farbe())
		return
	if _hack:
		if _hack_art() != "funk":
			return
		takt *= float(Werte.TURMARTEN["funk"]["feuer_faktor"])
	ego._takt = takt
	var r := ego._schuss_blick()
	var knoten := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = 0.07
	kugel.height = 0.14
	knoten.mesh = kugel
	knoten.material_override = ego._leucht(hand_farbe(), 0.95, 3.0)
	ego.hd.add_child(knoten)
	var p := _hand3d()
	knoten.position = p
	_bolzen.append({"p": p, "v": r * float(d["tempo"]), "weg": 0.0, "prall": 0, "knoten": knoten})
	_rueck = 1.0
	_blitz = 0.06
	ego._kick += 0.015
	Ton.spiele(ego.spiel, "brakk-schuss-b", -3.0)


func _bolzen_weiter(dt: float) -> void:
	var d: Dictionary = Werte.IRRTUERMER["bolzen"]
	var noch: Array = []
	for b: Dictionary in _bolzen:
		var weg := (b["v"] as Vector3).length() * dt
		var schritte := maxi(1, ceili(weg / 0.08))
		var platzt := false
		for i in schritte:
			var alt: Vector3 = b["p"]
			var neu: Vector3 = alt + (b["v"] as Vector3) * dt / float(schritte)
			b["weg"] = float(b["weg"]) + weg / float(schritte)
			if neu.y <= 0.02 or float(b["weg"]) >= float(d["weite"]):
				b["p"] = neu
				platzt = true
				break
			if not ego.spiel.endkampf and neu.x < float(Werte.ZONE_SPALTEN):
				b["p"] = neu
				platzt = true   # der Schild vor der Gegnerzone fängt ihn ab
				break
			var z := Vector2i(floori(neu.x), floori(neu.z))
			var za := Vector2i(floori(alt.x), floori(alt.z))
			if z != za and ego.hd.ist_hoch(z) and neu.y <= ego.hd.H and not (ego.brakk.oben and z == ego.karte.zelle_bei(ego._fuss2d())):
				if int(b["prall"]) >= int(d["abpraller"]):
					b["p"] = alt
					platzt = true
					break
				b["prall"] = int(b["prall"]) + 1
				var v: Vector3 = b["v"]
				if z.x != za.x:
					v.x = -v.x
				if z.y != za.y:
					v.z = -v.z
				b["v"] = v
				ego._funke(alt, 0.08)
				Ton.spiele(ego.spiel, "hit-thud", -14.0)
				continue
			b["p"] = neu
			if _gegner_bei(neu) != null:
				platzt = true
				break
		(b["knoten"] as Node3D).position = b["p"]
		if platzt:
			_bolzen_platzt(b["p"])
			(b["knoten"] as Node).queue_free()
		else:
			noch.append(b)
	_bolzen = noch


func _gegner_bei(p: Vector3) -> Gegner:
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
		if c.distance_to(p) <= 0.38:
			return g
	return null


## Platzt: kleiner Flächenschaden; nahe am PliPlop stößt er Nahkämpfer von ihm weg.
func _bolzen_platzt(p3: Vector3) -> void:
	var d: Dictionary = Werte.IRRTUERMER["bolzen"]
	var p := ego._zu2d(p3)
	var radius := float(d["flaeche"]) * Werte.ZELLE
	var schaden := float(d["schaden"]) * f().schaden_faktor() * float(ring_wert("@held", "schaden", 1.0))
	ego.spiel.effekte.flaeche(p, radius, hand_farbe())
	ego._funke(p3, 0.14)
	var kill := false
	var getroffen := 0
	for g: Gegner in ego.spiel.ego_gegner().duplicate():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g) or g.position.distance_to(p) > radius:
			continue
		treffer(g, schaden, "prellbolzen", "hand")
		getroffen += 1
		kill = kill or g._tot
	if getroffen > 0:
		ego._treffer_gefuehl(p3, kill)
	if pp.einsatzbereit() and p.distance_to(pp.position) <= float(d["stoss_naehe"]) * Werte.ZELLE:
		_stoss_vom_pliplop()


## Nahkämpfer um den PliPlop ein Stück wegschieben (nur über begehbare Felder, große Gegner nicht).
func _stoss_vom_pliplop() -> void:
	var d: Dictionary = Werte.IRRTUERMER["bolzen"]
	var r := float(d["stoss_radius"]) * Werte.ZELLE
	var weite := float(d["stoss"]) * Werte.ZELLE
	var n := 0
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or bool(g.daten.get("fernkampf", false)) or BrakkFortschritt.gross(g):
			continue
		if g.position.distance_to(pp.position) > r:
			continue
		var richtung := (g.position - pp.position).normalized()
		if richtung == Vector2.ZERO:
			richtung = Vector2.LEFT
		var ziel := g.position
		var s := 0.0
		while s < weite:
			s = minf(weite, s + 4.0)
			var neu := g.position + richtung * s
			if not ego.karte.ist_begehbar(ego.karte.zelle_bei(neu)):
				break
			ziel = neu
		if ziel != g.position:
			ego.spiel.effekte.strahl(g.position, ziel, hand_farbe(), 2.0)
			g.position = ziel
			g.plane_neu()
			n += 1
	if n > 0:
		ego.spiel.effekte.welle(pp.position, r, hand_farbe(), "funk", 0.5)


# ------------------------------------------------------------------ Treffer, Ring-Effekte, Verbund

## Ein Treffer des Irrtürmers (Hand, PliPlop, Hack, Aufsatz): Schaden mit Quelle, Ring-Effekt des Slots, Verbund.
## slot: "hand" oder "pp" – dessen Ring färbt den Treffer.
func treffer(g: Gegner, schaden: float, quelle: String, slot: String) -> void:
	if not is_instance_valid(g) or g._tot:
		return
	var ring := "@held" if slot == "hand" else "@pp"   # 20.11. (Nachtrag): alle Ringe des Satzes wirken
	var hat_ring := (hand_ring() if slot == "hand" else pp_ring()) != ""
	var verbund := false
	if hat_ring:
		verbund = _stempel(g, slot)
	var sp := ego.spiel
	sp.schadensquelle = "fabrik:-1,-1"
	sp.brakk_quelle = quelle
	sp.schuss_herkunft = ego.brakk.position
	var s := schaden * ego._gel_bonus(g)
	g.nimm_schaden(s)
	ego.treffer_zahl += 1
	if verbund and not g._tot:
		sp.brakk_quelle = "verbund"   # 20.11.: der Zuschlag zählt als eigene Quelle
		g.nimm_schaden(s * (float(Werte.IRRTUERMER["verbund"]["bonus"]) - 1.0))
	if hat_ring:
		ring_effekt(g, s, ring, slot)
	sp.schadensquelle = ""
	sp.brakk_quelle = ""
	sp.schuss_herkunft = Vector2.INF
	if g._tot:
		ego._kill(g)
	# 20.11. (Nachtrag): Durchschlag-Ring an Hack und Aufsatz – der nächste Gegner dahinter
	var durch := spell_w("hack", "durch") if quelle == "hack" else (_gemerkt_w("aufsatz", "durch", _aufsatz_ring, _aufsatz_st) if quelle == "aufsatz" else 0.0)
	if durch > 0.0 and not _durch_an and schaden > 0.0:
		var h := dahinter(g, ego._fuss2d()) if is_instance_valid(g) else null
		if h != null:
			_durch_an = true
			ego._strahl(ego._zu3d(g.position, 0.42), ego._zu3d(h.position, 0.42), hand_farbe())
			treffer(h, schaden * durch / 100.0, quelle, slot)
			_durch_an = false


## Merkt, welcher Slot den Gegner zuletzt mit seinem Ring-Effekt traf. true = Verbund (beide Slots im Fenster).
func _stempel(g: Gegner, slot: String) -> bool:
	if hand_ring() == "" or pp_ring() == "":
		return false
	var jetzt := Time.get_ticks_msec()
	var st: Dictionary = g.get_meta("verbund", {})
	st[slot] = jetzt
	g.set_meta("verbund", st)
	var fenster := int(float(Werte.IRRTUERMER["verbund"]["fenster"]) * 1000.0)
	var an := jetzt - int(st.get("hand", -100000)) <= fenster and jetzt - int(st.get("pp", -100000)) <= fenster
	if an and jetzt - int(g.get_meta("verbund_bild", -100000)) > fenster:
		g.set_meta("verbund_bild", jetzt)
		_verbund_bild(g)
	return an


## Eigenes Treffer-Bild des Verbunds: zwei Ringe in den Farben beider Slots und ein heller Funke.
func _verbund_bild(g: Gegner) -> void:
	var sp := ego.spiel
	sp.effekte.welle(g.position, Werte.ZELLE * 0.9, hand_farbe(), "funk", 0.5)
	sp.effekte.welle(g.position, Werte.ZELLE * 0.6, pp_farbe(), "funk", 0.5)
	sp.effekte.flaeche(g.position, Werte.ZELLE * 0.45, VERBUND_FARBE)
	ego._funke(ego._zu3d(g.position, 0.5), 0.3)
	# in der Ego-Sicht: zwei leuchtende Ringe um den Gegner (Handfarbe außen, PliPlop-Farbe innen)
	for e: Array in [[0.85, hand_farbe(), 0.45], [0.6, pp_farbe(), 0.65]]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = float(e[0]) - 0.09
		t.outer_radius = float(e[0])
		ring.mesh = t
		ring.material_override = ego._leucht(e[1], 0.9, 3.0)
		ego.hd.add_child(ring)
		ring.position = ego._zu3d(g.position, float(e[2]))
		ego._strahlen.append([ring, 0.35])
	_zaehle("verbund")
	Ton.spiele(sp, "ui-klick", -2.0)


# ------------------------------------------------------------------ PliPlop schießt (auch Aufsatz und Hack)

func _pp_schiesst() -> void:
	var p := pfad()
	var weite := (float(p["weite"]) + pp_hier_w("pp_weite")) * Werte.ZELLE   # 20.11. (Nachtrag): Ziel-Ring am Haltepunkt
	var ziel: Gegner = ego.spiel.gegner_in_reichweite(pp.position, weite, true)
	if ziel == null:
		pp.takt = 0.15
		return
	pp.takt = float(p["takt"]) * _tausch_faktor() / (1.0 + pp_hier_w("pp_takt") / 100.0)   # 20.11. (Nachtrag): Takt-Ring
	pp.blick = (ziel.position - pp.position).normalized()
	pfad_feuer(pp.position, ego._zu3d(pp.position, 0.55), ziel, pp_ring(), "pliplop", "pp")


## Einen Pfad-Schuss abfeuern (PliPlop, Aufsatz, Hack auf den PliPlop) – von `von` auf `ziel`.
func pfad_feuer(von: Vector2, von3: Vector3, ziel: Gegner, ring: String, quelle: String, slot: String, mal: float = 1.0) -> void:
	var p: Dictionary = Werte.PLIPLOP_PFADE.get(ring, Werte.PLIPLOP_PFADE[""])
	var st := maxi(1, f().satz_aktiv_stufe("pp")) if ring == pp_ring() else ring_stufe(ring)   # 20.11. (Nachtrag): Stufe des aktiven PliPlop-Rings
	var schaden := float(p["schaden"]) * f().schaden_faktor() * (1.0 + Werte.PLIPLOP_JE_STUFE * float(st - 1)) * mal
	var farbe := ego._ring_farbe(ring) if ring != "" else Color("9fe8ff")
	var sp := ego.spiel
	var ziele: Array = []
	match str(p["art"]):
		"einzel":
			ziele = [ziel]
		"mehr":
			ziele = _naechste(von, float(p["weite"]) * Werte.ZELLE, int(p.get("ziele", 2)))
		"welle":
			ziele = _im_umkreis(von, float(p["weite"]) * Werte.ZELLE)
			sp.effekte.welle(von, float(p["weite"]) * Werte.ZELLE, farbe, "funk", 0.5)
		"flaeche":
			var r := float(p.get("radius", 0.6)) * Werte.ZELLE
			ziele = _im_umkreis(ziel.position, r)
			sp.effekte.flaeche(ziel.position, r, farbe)
			if bool(p.get("brand", false)):
				sp.schadensquelle = "fabrik:-1,-1"
				sp.brakk_quelle = quelle
				sp.lege_brand(ziel.position, r, schaden * 0.4)
				sp.schadensquelle = ""
				sp.brakk_quelle = ""
		"linie":
			ziele = _in_linie(von, (ziel.position - von).normalized(), float(p["weite"]) * Werte.ZELLE)
		"sprung":
			ziele = _kette(ziel, int(p.get("spruenge", 2)))
	var vorher := von3
	for g: Gegner in ziele:
		if not is_instance_valid(g) or g._tot:
			continue
		var c := ego._zu3d(g.position, 0.42)
		ego._strahl(vorher if str(p["art"]) == "sprung" else von3, c, farbe)
		if str(p["art"]) == "sprung":
			vorher = c
		var b := float(p.get("bremse", 0.0))
		if b > 0.0:
			g.gebremst = maxf(g.gebremst, b)
		treffer(g, schaden, quelle, slot)
	Ton.spiele(sp, "brakk-schuss-a", -12.0)


func _im_umkreis(p: Vector2, r: float) -> Array:
	var liste: Array = []
	for g: Gegner in ego.spiel.ego_gegner():
		if is_instance_valid(g) and not g._tot and not ego.spiel._geschuetzt(g) and g.position.distance_to(p) <= r:
			liste.append(g)
	return liste


func _naechste(p: Vector2, r: float, n: int) -> Array:
	var liste := _im_umkreis(p, r)
	liste.sort_custom(func(a: Gegner, b: Gegner) -> bool: return a.position.distance_to(p) < b.position.distance_to(p))
	return liste.slice(0, n)


func _in_linie(von: Vector2, r: Vector2, weite: float) -> Array:
	var liste: Array = []
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g):
			continue
		var d := g.position - von
		var t := d.dot(r)
		if t > 0.0 and t <= weite and (von + r * t).distance_to(g.position) <= Werte.ZELLE * 0.4:
			liste.append(g)
	return liste


func _kette(erstes: Gegner, spruenge: int) -> Array:
	var liste: Array = [erstes]
	var punkt := erstes.position
	for i in spruenge:
		var bester: Gegner = null
		var beste := Werte.ABPRALLER_WEITE * Werte.ZELLE
		for g: Gegner in ego.spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and not liste.has(g) and not ego.spiel._geschuetzt(g) and punkt.distance_to(g.position) < beste:
				beste = punkt.distance_to(g.position)
				bester = g
		if bester == null:
			break
		liste.append(bester)
		punkt = bester.position
	return liste


## Gegner unter dem Fadenkreuz (Blicklinie), sonst der nächste am Zielpunkt.
func _ziel_im_blick(weite_felder: float) -> Gegner:
	if _hack and spell_hat("hack", "zielsuche"):
		# 20.11. (Nachtrag): Ziel-Ring – der stärkste Gegner in Reichweite
		var staerkster: Gegner = null
		for g: Gegner in _im_umkreis(ego._fuss2d(), weite_felder * Werte.ZELLE):
			if staerkster == null or g.leben > staerkster.leben:
				staerkster = g
		if staerkster != null:
			return staerkster
	var von := ego.hd.kamera.global_position
	var r := ego._schuss_blick()
	var bis := ego._strahl_bis(von, r, weite_felder)
	var bester: Gegner = null
	var beste := INF
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g):
			continue
		var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
		var t := (c - von).dot(r)
		if t <= 0.0 or t >= bis + 0.3:
			continue
		var abw := (von + r * t).distance_to(c)
		if abw <= 0.6 and t < beste:
			beste = t
			bester = g
	if bester != null:
		return bester
	var p := ego.ziel_welt(true)
	if p.x < -9000.0:
		return null
	var nah := _naechste(p, Werte.ZELLE * 1.2, 1)
	return nah[0] if not nah.is_empty() else null


# ------------------------------------------------------------------ Hack

## Formturm, Batterie oder PliPlop unter dem Fadenkreuz in Hack-Reichweite ({} = nichts).
func _hack_ziel_im_blick() -> Dictionary:
	var weite := float(Werte.IRRTUERMER["hack"]["weite"])
	var von := ego.hd.kamera.global_position
	var r := ego._blick()
	if pp.einsatzbereit():
		var c := ego._zu3d(pp.position, 0.4)
		var t := (c - von).dot(r)
		if t > 0.0 and t <= weite + 1.0 and (von + r * t).distance_to(c) <= 0.6:
			return {"art": "pliplop", "zelle": Karte.KEINE}
	var t2 := 0.3
	while t2 <= weite + 1.0:
		var p := von + r * t2
		var z := ego.karte.zelle_bei(ego._zu2d(p))
		if ego.karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
			return {"art": "turm", "zelle": z}
		var inh: int = ego.karte.inhalt(z)
		if inh == Karte.BATTERIE:
			return {"art": "batterie", "zelle": z}
		if p.y < -0.05:
			break
		t2 += 0.1
	return {}


func _hack_art() -> String:
	match str(_hack_ziel.get("art", "")):
		"pliplop":
			return "pliplop"
		"batterie":
			return "batterie"
		"turm":
			return str(ego.karte.turm_art.get(_hack_ziel["zelle"], "geschuetz"))
	return ""


func _hack_punkt() -> Vector2:
	if str(_hack_ziel.get("art", "")) == "pliplop":
		return pp.position
	return ego.karte.mitte(_hack_ziel["zelle"])


func _hack_gueltig() -> bool:
	if _hack_ziel.is_empty() or aufsatz_an():
		return false
	var art := str(_hack_ziel["art"])
	if art == "pliplop":
		if not pp.einsatzbereit():
			return false
	elif art == "turm":
		if ego.karte.ausbau.get(_hack_ziel["zelle"], Karte.FREI) != Karte.TURM:
			return false
	elif ego.karte.inhalt(_hack_ziel["zelle"]) != Karte.BATTERIE:
		return false
	return ego._fuss2d().distance_to(_hack_punkt()) <= (float(Werte.IRRTUERMER["hack"]["weite"]) + 1.0) * Werte.ZELLE


## Solange gehalten: der Irrtürmer schießt den Schuss des gehackten Ziels aus der Hand (der Turm feuert weiter).
func _hack_schuss(zusatz: float = 1.0) -> void:
	var art := _hack_art()
	var mal := float(Werte.IRRTUERMER["hack"]["mal"]) * zusatz
	mal *= 1.0 + spell_w("hack", "anlauf") / 100.0 * clampf(_hack_seit / 4.0, 0.0, 1.0)   # 20.11. (Nachtrag): Wirbel-Ring
	var sp := ego.spiel
	match art:
		"pliplop":
			_hack_takt = float(pfad()["takt"]) / (float(Werte.IRRTUERMER["ueberladen"]["mal"]) if pp.ueberladen() else 1.0)
			var ziel := _ziel_im_blick(float(Werte.IRRTUERMER["bolzen"]["weite"]))
			if ziel != null:
				pfad_feuer(ego._fuss2d(), _hand3d(true), ziel, pp_ring(), "hack", "pp", mal)
			return
		"batterie":
			_hack_takt = float(Werte.BATTERIE["abklingzeit"]) / sp.turm_takt(_hack_ziel["zelle"])
			var ziel := _ziel_im_blick(float(Werte.BATTERIE["reichweite"]))
			if ziel != null:
				var r := float(Werte.BATTERIE["flaeche"]) * Werte.ZELLE
				sp.effekte.flaeche(ziel.position, r, HACK_FARBE)
				ego._strahl(_hand3d(true), ego._zu3d(ziel.position, 0.42), HACK_FARBE)
				for g: Gegner in _im_umkreis(ziel.position, r):
					treffer(g, float(Werte.BATTERIE["schaden"]) * mal, "hack", "hand")
				Ton.spiele(sp, "tc-rail", -8.0)
			return
		"funk":
			_hack_takt = 0.5   # der Funkturm schießt nicht – die Bolzen fliegen schneller (schuss())
			return
	var z: Vector2i = _hack_ziel["zelle"]
	var k := ego.karte
	_hack_takt = maxf(0.2, float(k.turm_wert(z, "abklingzeit", 1.0))) / sp.turm_takt(z)
	match art:
		"heil":
			var heil := float(k.turm_wert(z, "heilung", 8.0))
			ego.brakk.leben = minf(ego.brakk.max_leben, ego.brakk.leben + heil)
			if pp.einsatzbereit():
				pp.leben = minf(pp.max_leben, pp.leben + heil)
			sp.effekte.plus(ego.brakk.position + Vector2(0, -18), Color("7dff9a"))
		"frost":
			var p := ego.ziel_welt(true)
			if p.x > -9000.0:
				sp.effekte.welle(p, Werte.ZELLE * 1.2, Color("bfefff"), "frost", 0.5)
				for g: Gegner in _im_umkreis(p, Werte.ZELLE * 1.2):
					g.gebremst = maxf(g.gebremst, float(k.turm_wert(z, "bremse_sek", 1.6)))
					treffer(g, 0.0, "hack", "hand")
		"lanze":
			var ziel := _ziel_im_blick(float(k.turm_wert(z, "reichweite", 6.0)))
			if ziel != null:
				var von := ego._fuss2d()
				var r2 := (ziel.position - von).normalized()
				var ende := von + r2 * float(k.turm_wert(z, "reichweite", 6.0)) * Werte.ZELLE
				ego._strahl(_hand3d(true), ego._zu3d(ende, 0.42), Color("ff8a3d"))
				for g: Gegner in _in_linie(von, r2, float(k.turm_wert(z, "reichweite", 6.0)) * Werte.ZELLE):
					treffer(g, float(k.turm_wert(z, "schaden", 45.0)) * mal, "hack", "hand")
				Ton.spiele(sp, "tc-rail", -8.0)
		_:
			# Geschützturm (auch Rückfall): ein Schuss, mit Doppelschuss zwei Ziele
			var n := int(k.turm_wert(z, "ziele", 1))
			var erstes := _ziel_im_blick(float(k.turm_wert(z, "reichweite", 3.5)) + 3.0)
			if erstes == null:
				return
			var liste: Array = [erstes]
			if n > 1:
				for g: Gegner in _naechste(erstes.position, Werte.ZELLE * 2.0, n):
					if not liste.has(g) and liste.size() < n:
						liste.append(g)
			for g: Gegner in liste:
				ego._strahl(_hand3d(true), ego._zu3d(g.position, 0.42), Color("7fe0ff"))
				treffer(g, float(k.turm_wert(z, "schaden", 16.0)) * mal, "hack", "hand")
			Ton.spiele(sp, "brakk-schuss-a", -6.0)


## Hand (rechts) oder Hack-Handschuh (links) in 3D.
func _hand3d(links: bool = false) -> Vector3:
	return ego.hd.kamera.global_position + ego._blick() * 0.5 + ego._rechts() * (-0.16 if links else 0.16) - Vector3(0, 0.14, 0)


## Hack-Strahl vom Handschuh zum gehackten Ziel (ein Kasten, jedes Bild neu ausgerichtet).
func _hack_strahl_zeigen() -> void:
	if not _hack:
		return
	if _hack_strahl == null:
		_hack_strahl = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, 1.0)
		_hack_strahl.mesh = box
		_hack_strahl.material_override = ego._leucht(HACK_FARBE, 0.8, 3.0)
		ego.hd.add_child(_hack_strahl)
	var a := _hand3d(true)
	var hoehe := 0.45 if str(_hack_ziel.get("art", "")) == "pliplop" else 1.1
	var b := ego._zu3d(_hack_punkt(), hoehe + 0.04 * sin(Time.get_ticks_msec() / 40.0))
	var lang := maxf(0.05, a.distance_to(b))
	_hack_strahl.visible = true
	_hack_strahl.position = (a + b) / 2.0
	_hack_strahl.scale = Vector3(1.0, 1.0, lang)
	_hack_strahl.look_at_from_position(_hack_strahl.position, b, Vector3.UP)


# ------------------------------------------------------------------ Oberfläche

func hinweis() -> String:
	if _hack:
		return "Hack: %s" % _hack_name()
	var z := _hack_ziel_im_blick()
	if not z.is_empty() and not aufsatz_an():
		return "Rechtsklick halten: %s hacken" % ("PliPlop" if str(z["art"]) == "pliplop" else ("Batterie" if str(z["art"]) == "batterie" else str(Werte.TURMARTEN.get(ego.karte.turm_art.get(z["zelle"], "geschuetz"), {}).get("name", "Turm"))))
	return ""


func _hack_name() -> String:
	match _hack_art():
		"pliplop":
			return "PliPlop (%s)" % str(pfad()["name"])
		"batterie":
			return "Batterie"
		"":
			return "–"
	return str(Werte.TURMARTEN.get(_hack_art(), {}).get("name", "Turm"))


func male_waffen(g: Vector2, wpx: float) -> void:
	var bild := ego._bild
	var wipp := Vector2(cos(ego._gang * 0.5) * 3.0, absf(sin(ego._gang * 0.5)) * 4.0) if ego._geht else Vector2.ZERO
	var schwank := (ego._sway + Vector2(0, 7.0 * ego._delle)) * wpx
	if aufsatz_an():
		# Aufsatz: der PliPlop sitzt auf dem rechten Arm (Platzhalter aus Code, von hinten)
		var tex := Platzhalter.pliplop(pp_ring())   # 20.11. (Nachtrag)
		var gr := Vector2(Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE) * wpx * 1.6   # 21.11.: 68er-Bild (vorher 2,7 beim 40er)
		var pos := Vector2(g.x * 0.74 - gr.x * 0.5, g.y - gr.y * 0.92) + wipp + schwank + Vector2(_rueck * 2.0, _rueck * 8.0) * wpx
		bild.draw_texture_rect_region(tex, Rect2(pos.round(), gr), Rect2(0, 2 * Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE), Color.WHITE.lerp(pp_farbe(), 0.25))
		if _blitz > 0.0:
			ego._muendungsblitz(pos + Vector2(gr.x * 0.5, gr.y * 0.2), wpx, pp_farbe())
		var rest := float(_aufsatz_bis - Time.get_ticks_msec()) / 1000.0
		Stil.schreibe_mittig(bild, Vector2(g.x / 2.0, g.y * 0.62), "Aufsatz %d s" % ceili(rest), 18, pp_farbe())
	else:
		# rechte Hand: Prellbolzenwerfer (Platzhalter aus Code), getönt in der Farbe des Handrings
		var ts := Vector2(_tex_werfer.get_size()) * wpx * 1.3
		var pos := Vector2(g.x * 0.80 - ts.x * 0.5, g.y - ts.y + 10.0 * wpx) + wipp + schwank + Vector2(_rueck * 2.0, _rueck * 6.0) * wpx
		bild.draw_texture_rect(_werferbild(), Rect2(pos.round(), ts), false)
		var mund := pos + Vector2(ts.x * 0.5, 4.0 * wpx)
		bild.draw_circle(mund, 3.0 * wpx, Color(hand_farbe(), 0.5 + 0.3 * sin(Time.get_ticks_msec() / 120.0)))
		if _blitz > 0.0:
			ego._muendungsblitz(mund, wpx, hand_farbe())
	# linke Hand: Hack-Handschuh (Brakks Ringhand), beim Hack leuchtet er gelb
	var rs := Vector2(ego._tex_ring.get_size()) * wpx
	var hoch := 0.0 if _hack else 0.55
	var rp := Vector2(g.x * 0.22 - rs.x * 0.5, g.y - rs.y + 4.0 * wpx + rs.y * hoch) + Vector2(-wipp.x, wipp.y) + schwank * 0.8
	bild.draw_texture_rect(ego._tex_ring, Rect2(rp.round(), rs), false, Color(1, 0.92, 0.75))
	var licht := rp + ego._ring_licht * wpx
	if _hack:
		var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 50.0)
		bild.draw_circle(licht, 7.0 * wpx, Color(HACK_FARBE, 0.25 * puls))
		bild.draw_circle(licht, 3.0 * wpx, HACK_FARBE)
	elif hand_ring() != "":
		bild.draw_circle(licht, 2.5 * wpx, Color(hand_farbe(), 0.6))


## 20.11. (Nachtrag): Fähigkeiten-Leiste wie bei Brakk (ego_modus._faehigkeiten) – hier nur Rest, Text darüber, läuft.
func leiste_info(was: String) -> Array:
	var welle := int(ego.spiel.welle)
	match was:
		"hack":
			return [0.0, "", _hack]
		"ueberladen":
			return [_ueberladen_rest / float(Werte.IRRTUERMER["ueberladen"]["abkling"]), "", false]
		"hierher":
			return [0.0, "bleibt" if pp.hier != Vector2.INF else "", pp.hier != Vector2.INF]
		"aufsatz":
			return [1.0 if _aufsatz_welle == welle and not aufsatz_an() else 0.0, "ab R.%d" % (welle + 1) if _aufsatz_welle == welle and not aufsatz_an() else "", aufsatz_an()]
	return [0.0, "", false]


func leiste_farbe() -> Color:
	return HACK_FARBE


## Rechts die beiden Ringsätze und der PliPlop.
func male_leisten(g: Vector2) -> void:
	_slots(g)


## 20.11. (Nachtrag): rechts zwei Sätze zu je vier Ringen – Held und PliPlop, der aktive umrandet.
func _slots(g: Vector2) -> void:
	var bild := ego._bild
	var breite := 236.0
	var x := g.x - breite - 14.0
	var y := roundf(g.y * 0.30)
	var zeile := 24.0
	var block := 22.0 + zeile * float(BrakkFortschritt.SATZ_MAX)
	var hinter := Rect2(x - 6.0, y - 30.0, breite + 12.0, block * 2.0 + 84.0)
	bild.draw_rect(hinter, Color(0.04, 0.05, 0.08, 0.6))
	Stil.schreibe(bild, Vector2(x, y - 14.0), "RINGE", 18, Stil.GOLD)
	for si in 2:
		var satz := "held" if si == 0 else "pp"
		var by := y + si * block
		var liste := f().satz_ringe(satz)
		var titel := "Irrtürmer · Prellbolzen" if si == 0 else "PliPlop · " + str(pfad()["name"])
		Stil.schreibe(bild, Vector2(x, by + 6.0), titel, 14, hand_farbe() if si == 0 else pp_farbe())
		for i in BrakkFortschritt.SATZ_MAX:
			var r := Rect2(x, by + 14.0 + i * zeile, breite, zeile - 3.0)
			var mi := Vector2(r.position.x + 12.0, r.get_center().y)
			if i < liste.size():
				var ring := liste[i]
				var farbe := ego._ring_farbe(ring)
				bild.draw_rect(r, Color(farbe, 0.12))
				if i == f().satz_gewaehlt(satz):
					bild.draw_rect(r, farbe, false, 2.0)
				ego._male_ring(bild, mi, 8.0, ring)
				Stil.schreibe(bild, Vector2(r.position.x + 26.0, r.get_center().y), "%s St.%d" % [EgoModus.ring_kurz(ring), f().satz_stufe(satz, i)], 14, farbe)
			else:
				bild.draw_arc(mi, 6.0, 0.0, TAU, 16, Color(0.3, 0.32, 0.36), 1.0)
	# PliPlop: Leben und Zustand
	var py := y + block * 2.0 + 4.0
	var anteil := clampf(pp.leben / maxf(1.0, pp.max_leben), 0.0, 1.0)
	Stil.schreibe(bild, Vector2(x, py + 6.0), "PliPlop 3cK", 16, pp_farbe())
	var zustand := ""
	if pp.gefallen:
		zustand = "gefallen" + (" – %d s" % ceili(pp.respawn) if pp.respawn != INF else "")
	elif pp.angedockt:
		zustand = "Aufsatz"
	elif pp.leer():
		zustand = "leer %d s" % ceili(float(pp.leer_bis - Time.get_ticks_msec()) / 1000.0)
	elif pp.ueberladen():
		zustand = "überladen"
	elif pp.hier != Vector2.INF:
		zustand = "bleibt dort"
	Stil.schreibe(bild, Vector2(x + breite - Stil.breite(zustand, 14), py + 6.0), zustand, 14, HACK_FARBE if pp.ueberladen() else Stil.TEXT_BLASS)
	var lb := Rect2(x, py + 16.0, breite, 8.0)
	bild.draw_rect(lb.grow(1.0), Color(0, 0, 0, 0.6))
	bild.draw_rect(Rect2(lb.position, Vector2(lb.size.x * (0.0 if pp.gefallen else anteil), lb.size.y)), Color("8fe39a") if anteil > 0.35 else Stil.ROT)
	Stil.schreibe(bild, Vector2(x, py + 40.0), "V tauscht aktive · Mausrad: Ring des Helden", 13, Stil.TEXT_BLASS)


func werte_zeilen() -> Dictionary:
	var d: Dictionary = Werte.IRRTUERMER["bolzen"]
	var schaden := float(d["schaden"]) * f().schaden_faktor() * float(ring_wert("@held", "schaden", 1.0))
	var pro_sek := 1.0 / maxf(0.01, float(d["takt"]) * float(ring_wert("@held", "takt", 1.0)))
	var zusatz: Array = [
		["Hand: " + _ring_name(hand_ring()), hand_farbe()],
		["PliPlop: " + _ring_name(pp_ring()) + " → " + str(pfad()["name"]), pp_farbe()],
		["Hack: " + (_hack_name() if _hack else "aus"), HACK_FARBE if _hack else Stil.TEXT_BLASS],
	]
	var vb := hand_ring() != "" and pp_ring() != ""
	zusatz.append(["Verbund %s" % ("+%d %%" % roundi((float(Werte.IRRTUERMER["verbund"]["bonus"]) - 1.0) * 100.0) if vb else "– zwei Ringe nötig"), VERBUND_FARBE if vb else Stil.TEXT_BLASS])
	return {"zeilen": [
		["schaden", "Bolzen", "%.0f" % schaden, []],
		["takt", "Schüsse/s", ("%.1f" % pro_sek).replace(".", ","), []],
		["dps", "Schaden/s", "%.0f" % (schaden * pro_sek), []],
	], "zusatz": zusatz}


# ------------------------------------------------------------------ Platzhalter-Grafik

var _werfer_je_ring := {}

## 20.11. (Paul): Werfer mit Leuchtadern in der Farbe des Handrings (ohne Ring gelb).
func _werferbild() -> Texture2D:
	var r := hand_ring()
	if r == "":
		return _tex_werfer
	if not _werfer_je_ring.has(r):
		var img := _male_werfer()
		var gelb := Color("ffd34d")
		var ziel := hand_farbe()
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).is_equal_approx(gelb):
					img.set_pixel(x, y, ziel)
		_werfer_je_ring[r] = ImageTexture.create_from_image(img)
	return _werfer_je_ring[r]


## Prellbolzenwerfer (rechte Hand): Brakks gezeichnete Pistole, umgefärbt in Kupfer und Gelb (Irrtürmer-Farbe).
static func _male_werfer() -> Image:
	var img := EgoModus._male_pistole()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c == EgoModus.UMRISS:
				continue
			if c.b > c.r + 0.1 and c.b > 0.5:
				img.set_pixel(x, y, Color("ffd34d"))          # Leuchtadern: gelb statt cyan
			elif c.b > c.g and c.r > 0.25:
				img.set_pixel(x, y, Color(c.r * 1.25, c.g * 0.85, c.b * 0.45))   # Lila → Kupfer
	return img
