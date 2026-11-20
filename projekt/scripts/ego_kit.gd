class_name EgoKit
extends RefCounted
## 20.11.: Schritt 6b – Grundgerüst für das Kit eines Anführers im Brakk-Mode (außer Brakk, der bleibt in ego_modus.gd).
## Die Steuerung liest ego_modus.gd; über die Tastenbelegung (Werte.ANFUEHRER_EGO) kommen hier nur Aktionen an.
## Bewegung, Leben, Stufen, Ringe, Respawn und Oberfläche gehören weiter der Ego-Sicht – das Kit hängt sich ein.

var ego: EgoModus


func _init(p_ego: EgoModus) -> void:
	ego = p_ego


## Eine Aktion aus der Tastenbelegung (gedrückt / losgelassen). true = erledigt, sonst versucht es die Ego-Sicht
## (gemeinsame Bewegungen wie Rolle, Sprung, Treppe, Ringfeld).
func aktion(_was: String, _gedrueckt: bool) -> bool:
	return false


## Jedes Bild (Echtzeit), nach der Bewegung.
func weiter(_echt: float, _frei: bool) -> void:
	pass


## Vor Schwere und Landung (z. B. Schweben). true = das Kit hat die Höhe selbst gesetzt.
func vor_fallen(_echt: float) -> bool:
	return false


## Linke Maustaste gehalten und der Takt ist um.
func schuss() -> void:
	pass


## Faktor aufs Lauftempo (z. B. langsamer beim Halten).
func tempo_faktor() -> float:
	return 1.0


## Waffen und Hände unten im Bild (statt Brakks Pistolen).
func male_waffen(_g: Vector2, _wpx: float) -> void:
	pass


## Ringleiste und Zustände (die Fähigkeiten-Leiste zeichnet ego_modus.gd über leiste_info).
func male_leisten(_g: Vector2) -> void:
	pass


## Über allem (Strahlen, Zustandsanzeigen).
func male_oben(_g: Vector2) -> void:
	pass


## 20.11. (Nachtrag): Fähigkeiten-Leiste (ego_modus._faehigkeiten) – je Aktion [Rest 0..1, Text darüber, läuft gerade].
func leiste_info(_was: String) -> Array:
	return [0.0, "", false]


## Farbe für „läuft gerade“ in der Leiste.
func leiste_farbe() -> Color:
	return EgoModus.LICHT


## Hinweis unter dem Fadenkreuz ("" = keiner).
func hinweis() -> String:
	return ""


## Werte-Fenster: wie EgoModus._werte_zeilen.
func werte_zeilen() -> Dictionary:
	return {"zeilen": [], "zusatz": []}


## Stufe eines getragenen Rings (1–3; ohne Ring 1).
func ring_stufe(ring: String) -> int:
	return clampi(ego.brakk.fortschritt.ring_stufe(ring), 1, 3) if ring != "" else 1


## Wert aus der Brakk-Tabelle des Rings auf seiner Stufe (Schaden, Takt, Markierung …), sonst `std`.
func ring_wert(ring: String, schluessel: String, std: Variant) -> Variant:
	if ring == "":
		return std
	return (BrakkFortschritt.RINGE[ring]["brakk_stufen"][ring_stufe(ring) - 1] as Dictionary).get(schluessel, std)


var _brand_ab := {}               # Schlüssel -> ab dieser Zeit (ms) darf das nächste Brandfeld


## Ring-Effekt bei einem Treffer: Markierung, Bremse, Brand, Sprung – je nach Ring auf seiner Stufe (wie Brakks Ringe).
## `schluessel` trennt die Brand-Takte (z. B. je Slot).
func ring_effekt(g: Gegner, schaden: float, ring: String, schluessel: String = "") -> void:
	if ring == "" or not is_instance_valid(g):
		return
	var mark_sek := float(ring_wert(ring, "mark_sek", 0.0))
	if mark_sek > 0.0 and not g._tot and (g.markiert <= 0.0 or g.markiert_brakk):
		g.markiert = maxf(g.markiert, mark_sek)
		g.markier_faktor = float(ring_wert(ring, "mark_bonus", 1.0))
		g.markiert_brakk = true
	var bremse := float(ring_wert(ring, "bremse", 0.0))
	if bremse > 0.0 and not g._tot:
		g.gebremst = maxf(g.gebremst, bremse)
	var sp := ego.spiel
	var vorher: String = sp.brakk_quelle
	sp.brakk_quelle = "ring"
	var brand_takt := float(ring_wert(ring, "brand_takt", 0.0))
	if brand_takt > 0.0 and Time.get_ticks_msec() >= int(_brand_ab.get(schluessel, 0)):
		_brand_ab[schluessel] = Time.get_ticks_msec() + int(brand_takt * 1000.0)
		sp.lege_brand(g.position, Werte.ZELLE * 0.5, schaden * 0.3)
	var spruenge := int(ring_wert(ring, "spruenge", 0))
	if spruenge > 0:
		ego._brakk_sprung(g, spruenge, schaden * float(ring_wert(ring, "sprung_anteil", 0.6)))
	sp.brakk_quelle = vorher


## Ein Treffer des Anführers mit Quelle (Schaden nach Quelle), optional mit Ring-Effekt; ein Kill gibt Erfahrung.
func trifft(g: Gegner, schaden: float, quelle: String, ring: String = "") -> void:
	if not is_instance_valid(g) or g._tot:
		return
	var sp := ego.spiel
	sp.schadensquelle = "fabrik:-1,-1"
	sp.brakk_quelle = quelle
	sp.schuss_herkunft = ego.brakk.position
	var s := schaden * ego._gel_bonus(g)
	g.nimm_schaden(s)
	ego.treffer_zahl += 1
	ring_effekt(g, s, ring, quelle)
	sp.schadensquelle = ""
	sp.brakk_quelle = ""
	sp.schuss_herkunft = Vector2.INF
	if g._tot:
		ego._kill(g)


func gefallen() -> void:
	pass


func wieder_da() -> void:
	pass


func neue_runde() -> void:
	pass


func beenden() -> void:
	pass


# ------------------------------------------------------------------ Ring-Wirkung je Spell (20.11., Nachtrag)

var _glut: Array = []             # [Gegner, Schaden je Sekunde, Rest-Sekunden]
var _schutz_bis := 0              # ms: bis dahin „schutz_nach“
var _schutz_nach := 0.0


## Ring, der die Spells färbt (Irrtürmer: aktiver Ring des Helden, Sonde 7: aktiver Ring).
func spell_ring() -> String:
	return ""


## Stufe dieses Rings.
func spell_ring_stufe() -> int:
	return ring_stufe(spell_ring())


## Wirkung des aktiven Rings an diesem Spell ({} = keine) – Werte.RING_SPELLS.
func spell_eintrag(spell: String) -> Dictionary:
	var ring := spell_ring()
	if ring == "":
		return {}
	return Werte.ring_spell(ego.anfuehrer(), spell, ring)


func spell_hat(spell: String, art: String) -> bool:
	return str(spell_eintrag(spell).get("art", "")) == art


## Stärke der Wirkung `art` an `spell` auf der Ringstufe (0 = keine).
func spell_w(spell: String, art: String) -> float:
	var e := spell_eintrag(spell)
	if str(e.get("art", "")) != art:
		return 0.0
	return Werte.ring_spell_wert(e, spell_ring_stufe())


## Weniger Schaden für den Anführer (0..1) – Kommandant.nimm_schaden fragt das ab.
func schutz() -> float:
	return _schutz_nach if Time.get_ticks_msec() < _schutz_bis else 0.0


func schutz_fuer(sek: float, anteil: float) -> void:
	_schutz_bis = Time.get_ticks_msec() + int(sek * 1000.0)
	_schutz_nach = anteil


## Gegner im Umkreis (Felder) um p bremsen.
func bremse_umkreis(p: Vector2, radius_felder: float, sek: float) -> void:
	ego.spiel.effekte.welle(p, radius_felder * Werte.ZELLE, Color("9fe8ff"), "frost", 0.5)
	for g: Gegner in ego.spiel.ego_gegner():
		if is_instance_valid(g) and not g._tot and g.position.distance_to(p) <= radius_felder * Werte.ZELLE:
			g.gebremst = maxf(g.gebremst, sek)


## Hitzestoß: Schaden im Umkreis (Quelle „ring“).
func hitzestoss(p: Vector2, radius_felder: float, schaden: float) -> void:
	ego.spiel.effekte.welle(p, radius_felder * Werte.ZELLE, Color("ff8a3d"), "funk", 0.6)
	ego.spiel.effekte.flaeche(p, radius_felder * Werte.ZELLE, Color("ff8a3d"))
	for g: Gegner in ego.spiel.ego_gegner().duplicate():
		if is_instance_valid(g) and not g._tot and not ego.spiel._geschuetzt(g) and g.position.distance_to(p) <= radius_felder * Werte.ZELLE:
			trifft(g, schaden, "ring")
	Ton.spiele(ego.spiel, "hit-boom", -8.0)


## Brandfeld (Quelle „ring“).
func brand_bei(p: Vector2, radius_felder: float, schaden_je_sek: float) -> void:
	var sp := ego.spiel
	sp.schadensquelle = "fabrik:-1,-1"
	sp.brakk_quelle = "ring"
	sp.lege_brand(p, radius_felder * Werte.ZELLE, schaden_je_sek)
	sp.schadensquelle = ""
	sp.brakk_quelle = ""


## Nachglühen: `gesamt` Schaden über `sek` (Quelle „ring“).
func glut(g: Gegner, gesamt: float, sek: float) -> void:
	if is_instance_valid(g) and not g._tot and gesamt > 0.0:
		_glut.append([g, gesamt / sek, sek])


func glut_weiter(echt: float) -> void:
	var noch: Array = []
	for e: Array in _glut:
		var g: Gegner = e[0]
		if not is_instance_valid(g) or g._tot:
			continue
		var dt := minf(echt, float(e[2]))
		trifft(g, float(e[1]) * dt, "ring")
		e[2] = float(e[2]) - dt
		if float(e[2]) > 0.0:
			noch.append(e)
	_glut = noch


## Nächster Gegner hinter `g` in Schussrichtung (von `von` aus), höchstens 2 Felder weiter (null = keiner).
func dahinter(g: Gegner, von: Vector2) -> Gegner:
	var r := (g.position - von).normalized()
	var bester: Gegner = null
	var beste := 2.0 * Werte.ZELLE
	for h: Gegner in ego.spiel.ego_gegner():
		if h == g or not is_instance_valid(h) or h._tot or ego.spiel._geschuetzt(h):
			continue
		var d := h.position - g.position
		var t := d.dot(r)
		if t > 0.0 and t < beste and (g.position + r * t).distance_to(h.position) <= Werte.ZELLE * 0.6:
			beste = t
			bester = h
	return bester


## Blitz springt von `g` auf `n` weitere Gegner (Quelle „ring“, zählt als Schaden des Anführers).
func kette(g: Gegner, n: int, schaden: float) -> void:
	if not is_instance_valid(g) or n <= 0:
		return
	var sp := ego.spiel
	sp.schadensquelle = "fabrik:-1,-1"
	sp.brakk_quelle = "ring"
	ego._brakk_sprung(g, n, schaden)
	sp.schadensquelle = ""
	sp.brakk_quelle = ""
