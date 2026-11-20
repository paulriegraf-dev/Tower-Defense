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


## Fähigkeiten-Leiste und Ringleiste (statt Brakks).
func male_leisten(_g: Vector2) -> void:
	pass


## Über allem (Strahlen, Zustandsanzeigen).
func male_oben(_g: Vector2) -> void:
	pass


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
