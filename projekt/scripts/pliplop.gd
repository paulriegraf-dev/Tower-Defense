class_name PliPlop
extends Node2D
## 20.11.: Schritt 6b – PliPlop 3cK, der rollende Begleitturm des Irrtürmers im Brakk-Mode. Ab Runde 1 gratis dabei,
## rollt von selbst hinter dem Irrtürmer her (Abstand Werte.IRRTUERMER.pliplop.abstand) oder bleibt nach [X] an einem Punkt.
## Er schießt den Pfad des Rings, den er trägt (Werte.PLIPLOP_PFADE); die Schüsse selbst feuert das Kit (EgoIrrtuermer).
## Eigenes Leben (Anteil vom Irrtürmer). Nahkämpfer neben ihm schaden ihm; fällt er, steht er nach „respawn“ Sekunden
## neben dem Irrtürmer wieder. Fällt der Irrtürmer, fällt er mit und kommt mit ihm zurück.
## Bild (Platzhalter aus Code, 20.11. Nachtrag): Kugel auf Rad mit kurzem Lauf, je Pfad eigener Aufsatz (Platzhalter.pliplop),
## 8 Blickrichtungen, leicht in der Ringfarbe getönt.
## Läuft im Takt des Kits (Echtzeit), nicht in eigenem _process. Die HD-Ansicht zeigt das Sprite2D wie jede Figur.


const BILD_ZELLE := Platzhalter.PP_ZELLE
const ANKER := Platzhalter.PP_ANKER
const MASSSTAB := 1.6
const ZEILE := Platzhalter.PP_ZEILE
const RICHTUNGEN := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]   # gegen den Uhrzeigersinn ab „zur Kamera“

var spiel: Node
var kit: EgoIrrtuermer
var leben := 100.0
var max_leben := 100.0
var gefallen := false
var respawn := 0.0               # Restzeit bis zum Wiederkommen (INF = kommt mit dem Irrtürmer)
var hier := Vector2.INF          # [X] Hierher!: dort bleibt er (INF = folgen)
var takt := 0.0                  # bis zum nächsten Schuss
var leer_bis := 0                # nach dem Aufsatz: bis dahin (ms) schießt er nicht
var angedockt := false           # Aufsatz läuft: sitzt am Arm, unsichtbar
var ueberladen_bis := 0          # [Q] Überladen: bis dahin (ms) doppelt so schnell
var blick := Vector2.DOWN        # Blickrichtung (2D)
var _sprite: Sprite2D


func einrichten(p_spiel: Node, p_kit: EgoIrrtuermer, p: Vector2, p_max_leben: float) -> void:
	spiel = p_spiel
	kit = p_kit
	position = p
	max_leben = p_max_leben
	leben = max_leben
	_sprite = Sprite2D.new()
	_sprite.texture = Platzhalter.pliplop("")
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, BILD_ZELLE, BILD_ZELLE)
	_sprite.centered = false
	_sprite.offset = -ANKER
	_sprite.scale = Vector2.ONE * MASSSTAB
	add_child(_sprite)


func leer() -> bool:
	return Time.get_ticks_msec() < leer_bis


func ueberladen() -> bool:
	return Time.get_ticks_msec() < ueberladen_bis


func einsatzbereit() -> bool:
	return not gefallen and not angedockt


## Fällt (eigenes Leben leer oder der Irrtürmer fällt mit `mit_anfuehrer`).
func faellt(mit_anfuehrer: bool) -> void:
	if gefallen:
		if mit_anfuehrer:
			respawn = INF
		return
	gefallen = true
	visible = false
	respawn = INF if mit_anfuehrer else float(Werte.IRRTUERMER["pliplop"]["respawn"])
	hier = Vector2.INF
	spiel.effekte.flaeche(position, Werte.ZELLE * 0.6, Color("ff7a5a"))


## Neben `p` wieder aufstellen, voll geheilt.
func kommt_zurueck(p: Vector2) -> void:
	gefallen = false
	angedockt = false
	visible = true
	leben = max_leben
	position = _freier_platz(p)
	spiel.effekte.flaeche(position, Werte.ZELLE * 0.6, Color("7fe0ff"))


func nimm_schaden(menge: float) -> void:
	if gefallen or angedockt:
		return
	var schutz := float(kit.pfad().get("schutz", 0.0)) + kit.pp_hier_w("pp_schutz") / 100.0   # Prellschild (Wallring); 20.11. (Nachtrag): eingegraben am Haltepunkt
	leben -= menge * (1.0 - schutz)
	if leben <= 0.0:
		faellt(false)
		spiel.melde("PliPlop ist gefallen – in %d s wieder da." % int(Werte.IRRTUERMER["pliplop"]["respawn"]), 2.5)


## Jedes Bild (Echtzeit): Wiederkommen, Rollen, Nahkampfschaden nehmen, Bild wählen. `anfuehrer` = Fußpunkt des Irrtürmers.
func weiter(dt: float, anfuehrer: Vector2, vorne: Vector2, kamera: Vector2) -> void:
	if gefallen:
		if respawn != INF:
			respawn -= dt
		if respawn <= 0.0 or respawn == INF:
			kommt_zurueck(anfuehrer - vorne * Werte.ZELLE)
		return
	if angedockt:
		position = anfuehrer
		return
	takt -= dt * (float(Werte.IRRTUERMER["ueberladen"]["mal"]) if ueberladen() else 1.0)
	_rollen(dt, anfuehrer, vorne)
	_nahkampf(dt)
	_bild_waehlen(kamera)


func _rollen(dt: float, anfuehrer: Vector2, vorne: Vector2) -> void:
	var d: Dictionary = Werte.IRRTUERMER["pliplop"]
	var ziel := hier
	if ziel == Vector2.INF:
		var seite := Vector2(-vorne.y, vorne.x)
		ziel = anfuehrer - (vorne * 0.9 + seite * 0.5).normalized() * float(d["abstand"]) * Werte.ZELLE
	var weg := ziel - position
	if weg.length() < Werte.ZELLE * 0.25:
		return
	var schritt := weg.limit_length(float(d["tempo"]) * Werte.ZELLE * dt)
	var vorher := position
	_versuche(Vector2(schritt.x, 0.0))
	_versuche(Vector2(0.0, schritt.y))
	if position != vorher:
		blick = (position - vorher).normalized()
	# hängt er weit weg fest (Mauer dazwischen), springt er zum Irrtürmer
	if hier == Vector2.INF and position == vorher and position.distance_to(anfuehrer) > 5.0 * Werte.ZELLE:
		position = _freier_platz(anfuehrer)


func _versuche(s: Vector2) -> void:
	if s == Vector2.ZERO:
		return
	var neu := position + s
	var z: Vector2i = spiel.karte.zelle_bei(neu)
	if spiel.karte.in_karte(z) and spiel.karte.ist_begehbar(z):
		position = neu


## Nächstes begehbares Feld bei `p` (Mitte), sonst `p`.
func _freier_platz(p: Vector2) -> Vector2:
	var k: Karte = spiel.karte
	var z0 := k.zelle_bei(p)
	if k.in_karte(z0) and k.ist_begehbar(z0):
		return p
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var z := z0 + Vector2i(dx, dy)
				if k.in_karte(z) and k.ist_begehbar(z):
					return k.mitte(z)
	return p


## Nahkämpfer, die neben ihm stehen, schaden ihm (Fernkämpfer zielen weiter auf Truppen).
func _nahkampf(dt: float) -> void:
	var mal := float(Werte.IRRTUERMER["pliplop"]["nah_schaden"])
	var summe := 0.0
	for g: Gegner in spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or bool(g.daten.get("fernkampf", false)):
			continue
		var reich := maxf(0.7, float(g.daten.get("reichweite", 0.0))) * Werte.ZELLE
		if g.position.distance_to(position) <= reich:
			summe += float(g.daten.get("schaden", 0.0)) / maxf(0.3, float(g.daten.get("abklingzeit", 1.0)))
	if summe > 0.0:
		nimm_schaden(summe * mal * dt * Engine.time_scale)   # Gegner schlagen in Spielzeit zu


## Blickrichtung relativ zur Kamera → Zeile im Bild (S = schaut zur Kamera). Getönt in der Farbe seines Pfads.
func _bild_waehlen(kamera: Vector2) -> void:
	var zur_kamera := kamera - position
	if zur_kamera.length() < 1.0:
		return
	var w := wrapf(zur_kamera.angle_to(blick), 0.0, TAU)
	var i := roundi(w / (TAU / 8.0)) % 8
	var zeile := int(ZEILE[RICHTUNGEN[i]])
	_sprite.region_rect = Rect2(0, zeile * BILD_ZELLE, BILD_ZELLE, BILD_ZELLE)
	var tex := Platzhalter.pliplop(kit.pp_ring())   # 20.11. (Nachtrag): Aufsatz je Pfad
	if _sprite.texture != tex:
		_sprite.texture = tex
	var farbe: Color = kit.pp_farbe()
	_sprite.modulate = Color.WHITE.lerp(farbe, 0.25) if not leer() else Color(0.5, 0.5, 0.55)
	if ueberladen():
		_sprite.modulate = _sprite.modulate.lightened(0.3 + 0.2 * sin(Time.get_ticks_msec() / 60.0))
