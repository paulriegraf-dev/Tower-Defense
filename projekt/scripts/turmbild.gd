class_name TurmBild
extends Node2D
## Neue Grafik (16.11.): ein Turm als Bild im Stil der Truppen (Pixel ×2).
## Steht y-sortiert zwischen den Figuren, damit er Figuren dahinter verdeckt. Position = Fußpunkt des Turms.
## Gefechtsturm: 8 Richtungen, dreht sich zum Ziel und spielt beim Schuss seine Animation; Stufe 2 und 3 mit eigenem Bild.

const GEF_ZEILE := {"S": 0, "E": 1, "N": 2, "W": 3, "SE": 4, "NE": 5, "NW": 6, "SW": 7}
const GEF_SCHUSS_SEK := 0.75
const GEF_STUFE_BILD_SEK := 0.05   # Stufe 2/3: vier Schussbilder (Blitz, Rückstoß, Rauch, Ruhe) je so lang
## Mündung je Blick (Spalte im Blatt, Reihenfolge wie GEF_ZEILE) und Stufenreihe, in Pixeln des 68er-Bilds (16.11.)
const MUENDUNG := [
	[Vector2(32, 26), Vector2(56, 24), Vector2(38, 21), Vector2(12, 24), Vector2(58, 35), Vector2(54, 17), Vector2(14, 17), Vector2(12, 35)],
	[Vector2(34, 25), Vector2(56, 27), Vector2(36, 20), Vector2(12, 27), Vector2(58, 35), Vector2(56, 16), Vector2(12, 16), Vector2(12, 35)],
	[Vector2(33, 26), Vector2(61, 25), Vector2(34, 15), Vector2(7, 25), Vector2(57, 40), Vector2(58, 11), Vector2(10, 11), Vector2(11, 40)],
]
const GEF_ANKER := Vector2(33, 55)
## Bild und Fußpunkt (Pixel im Bild) je Turmart
const BILDER := {
	"lanze": ["tuerme/lanze.png", Vector2(28, 61)],
	"lan_s2": ["tuerme/lan_s2.png", Vector2(28, 61)],
	"lan_durchschlag": ["tuerme/lan_durchschlag.png", Vector2(29, 61)],
	"lan_doppel": ["tuerme/lan_doppel.png", Vector2(29, 61)],
	"frost": ["tuerme/frost.png", Vector2(30, 59)],
	"heil": ["tuerme/heil.png", Vector2(27, 61)],
	"funk": ["tuerme/funk.png", Vector2(31, 61)],
}

## 21.11. (Paul): Bildmaßstab je Turmart (Standard 2) – Truppenturm 70 %, PliPlop 75 %
const MASSSTAB := {"truppen": 1.4, "pliplop": 1.5}

static func massstab(art: String) -> float:
	return float(MASSSTAB.get(art, 2.0))


var karte: Karte
var zelle := Vector2i.ZERO
var blick := 0         # Zeile im Gefechtsturm-Blatt
var schuss := -1.0     # Sekunden seit dem letzten Schuss (< 0 = Ruhe)
var _bild: Sprite2D    # das Turmbild selbst (Sprite, damit die HD-2D-Ansicht es übernehmen kann)
var _krone: Sprite2D = null    # 20.11. (Nachtrag): Stufe 4 – goldene Krone …
var _zusatz: Sprite2D = null   # … und eine Zusatzform je Turmart (Platzhalter.turm4_zusatz)
var _punkte: Sprite2D = null   # 20.11. (Nachtrag): Truppenturm – Werkschutz-Punkte (auch in HD-2D)


## Der Turm schießt auf `ziel` (Weltkoordinaten): zum Ziel drehen und die Schuss-Animation starten.
func feuert(ziel: Vector2) -> void:
	var r := ziel - (position + Vector2(0, -24))
	var w := rad_to_deg(atan2(r.x, r.y))
	var namen := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
	blick = GEF_ZEILE[namen[posmod(roundi(w / 45.0), 8)]]
	schuss = 0.0


func _ready() -> void:
	_bild = Sprite2D.new()
	_bild.centered = false
	_bild.scale = Vector2(2, 2)
	_bild.region_enabled = true
	add_child(_bild)


func _process(delta: float) -> void:
	if schuss >= 0.0:
		schuss += delta
		if schuss >= GEF_SCHUSS_SEK:
			schuss = -1.0
	var b := bild_info(karte, zelle, blick, schuss, 1.0)
	var ms := massstab(str(karte.turm_art.get(zelle, "")))
	_bild.scale = Vector2(ms, ms)
	_bild.texture = b["bild"]
	_bild.region_rect = b["quelle"]
	_bild.offset = -(b["anker"] as Vector2)
	_bild.modulate = b["farbe"]
	_stufe4(b)
	_werkschutz_punkte()
	queue_redraw()


## 20.11. (Paul, Nachtrag): Stufe-4-Formturm (Irrtürmer) – Krone über dem Turm und eine goldene Zusatzform je Turmart.
## Beide sind Sprite2D, also auch in der HD-2D-Ansicht zu sehen; der goldene Rahmen am Boden kommt aus _beiwerk.
func _stufe4(b: Dictionary) -> void:
	var st4 := int(karte.turm_stufe.get(zelle, 1)) >= 4
	if st4 and _krone == null:
		_krone = Platzhalter.kronen_sprite(0.0, 2.0)
		add_child(_krone)
		_zusatz = Sprite2D.new()
		_zusatz.texture = Platzhalter.turm4_zusatz(str(karte.turm_art.get(zelle, "geschuetz")))
		_zusatz.centered = false
		_zusatz.scale = Vector2(2, 2)
		add_child(_zusatz)
	if _krone == null:
		return
	_krone.visible = st4
	_zusatz.visible = st4
	var oben := (b["anker"] as Vector2).y   # Bildpixel vom Fußpunkt bis zur Oberkante (das Bild ist zweifach skaliert)
	_krone.offset = Vector2(-8, -11 - oben - 2.0)
	_zusatz.offset = Vector2(6, -oben * 0.7)


## 20.11. (Paul, Nachtrag): Truppenturm – so viele Punkte über dem Tor, wie Werkschutz-Truppen gerade leben (von höchstens).
func _werkschutz_punkte() -> void:
	if str(karte.turm_art.get(zelle, "")) != "truppen":
		if _punkte != null:
			_punkte.visible = false
		return
	if _punkte == null:
		_punkte = Sprite2D.new()
		_punkte.centered = false
		_punkte.scale = Vector2(2, 2)
		add_child(_punkte)
	var max_n := int(karte.turm_wert(zelle, "werkschutz", 2))
	var n := mini(max_n, int(karte.werkschutz_zahl.get(zelle, max_n)))   # 21.11.: Punkte = Besatzung im Turm (frisch gebaut: voll)
	_punkte.visible = true
	_punkte.texture = Platzhalter.punkte(n, max_n)
	_punkte.offset = Vector2(-float(max_n * 5 + 1) / 2.0, -(61.0 * massstab("truppen") / 2.0 if ResourceLoader.exists(Werte.NEU + "tuerme/truppen.png") else Platzhalter.TT_ANKER.y) - 7.0)


func _draw() -> void:
	_beiwerk(self, karte, zelle, Vector2.ZERO, 1.0, true)


## Mündung des Gefechtsturms (nach `feuert`): [Bodenpunkt in Weltkoordinaten, Höhe über dem Boden in Weltpixeln].
func muendung() -> Array:
	var stufe := int(karte.turm_stufe.get(zelle, 1))
	var r := 0
	if stufe >= 3:
		r = 1 if str(karte.turm_faehigkeit.get(zelle, "")) == "doppelschuss" else 2
	var m: Vector2 = MUENDUNG[r][clampi(blick, 0, 7)]
	return [position + Vector2((m.x - GEF_ANKER.x) * 2.0, 0.0), (GEF_ANKER.y - m.y) * 2.0]


## Bild, Ausschnitt, Fußpunkt im Bild und Färbung des Turms auf `z`.
static func bild_info(k: Karte, z: Vector2i, p_blick: int, p_schuss: float, alpha: float) -> Dictionary:
	var art: String = k.turm_art.get(z, k.turm_form(z))
	if art == "":
		art = "geschuetz"
	var stufe := int(k.turm_stufe.get(z, 1))
	var faehigkeit := str(k.turm_faehigkeit.get(z, ""))
	var aktiv := alpha < 1.0 or k.turm_aktiv(z)
	var b := {"farbe": Color(1, 1, 1, alpha) if aktiv else Color(0.45, 0.45, 0.52, alpha), "quelle": Rect2(0, 0, 64, 64)}
	if art == "truppen":   # 20.11. (Nachtrag): Truppenturm (Irrtürmer), Platzhalter aus Code
		if ResourceLoader.exists(Werte.NEU + "tuerme/truppen.png"):   # 21.11. (Paul): PixelLab-Bild
			b["bild"] = k.neu_bild("tuerme/truppen.png")
			b["anker"] = Vector2(32, 61)
			return b
		b["bild"] = Platzhalter.truppenturm(stufe)
		b["anker"] = Platzhalter.TT_ANKER
		b["quelle"] = Rect2(Vector2.ZERO, Vector2(Platzhalter.TT_GROESSE))
		return b
	if art == "pliplop":   # 20.11. (Paul): PliPlop 3cK als Turm, Platzhalter aus Code, Aufsatz je Pfad, 8 Richtungen
		var ring := str(Werte.PLIPLOP_TURM.get(faehigkeit, {}).get("ring", ""))
		b["bild"] = Platzhalter.pliplop(ring)
		b["anker"] = Platzhalter.PP_ANKER
		b["quelle"] = Rect2(0, clampi(p_blick, 0, 7) * Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE)
		return b
	if art == "lanze":
		var bildname := "lanze"
		if stufe == 2:
			bildname = "lan_s2"
		elif stufe >= 3:
			bildname = "lan_doppel" if faehigkeit == "doppelstrahl" else "lan_durchschlag"
		b["bild"] = k.neu_bild(BILDER[bildname][0])
		b["anker"] = BILDER[bildname][1]
	elif BILDER.has(art):
		b["bild"] = k.neu_bild(BILDER[art][0])
		b["anker"] = BILDER[art][1]
	else:
		# Gefechtsturm (auch als Rückfall für unbekannte Arten)
		b["anker"] = Vector2(33, 55)
		if stufe >= 2:
			var r := 0 if stufe == 2 else (1 if faehigkeit == "doppelschuss" else 2)
			var f := -1 if p_schuss < 0.0 else int(p_schuss / GEF_STUFE_BILD_SEK)
			if f >= 0 and f < 4:
				# 16.11.: Schussbilder mit Mündungsblitz und Rückstoß (assets/neu/tuerme/gef_stufen_schuss.png)
				b["bild"] = k.neu_bild("tuerme/gef_stufen_schuss.png")
				b["quelle"] = Rect2(p_blick * 68, (r * 4 + f) * 68, 68, 68)
			else:
				b["bild"] = k.neu_bild("tuerme/gef_stufen.png")
				b["quelle"] = Rect2(p_blick * 68, r * 68, 68, 68)
		else:
			var f := 0 if p_schuss < 0.0 else mini(8, int(p_schuss / GEF_SCHUSS_SEK * 9.0))
			b["bild"] = k.neu_bild("tuerme/gef_frames.png")
			b["quelle"] = Rect2(f * 68, p_blick * 68, 68, 68)
	return b


## Zeichnet den Turm auf `z` mit Fußpunkt `fuss` (in Koordinaten von `ci`) – für die Bauvorschau der Karte.
static func zeichne(ci: CanvasItem, k: Karte, z: Vector2i, fuss: Vector2, p_blick: int, p_schuss: float, alpha: float) -> void:
	var b := bild_info(k, z, p_blick, p_schuss, alpha)
	_beiwerk(ci, k, z, fuss, alpha, false)
	var q: Rect2 = b["quelle"]
	var ms := massstab(str(k.turm_art.get(z, k.turm_form(z))))
	ci.draw_texture_rect_region(b["bild"], Rect2(fuss - (b["anker"] as Vector2) * ms, q.size * ms), q, b["farbe"])


## Schatten, Stufenpunkte (Türme ohne eigenes Stufenbild) und das rote Kreuz, wenn der Turm außer Betrieb ist.
static func _beiwerk(ci: CanvasItem, k: Karte, z: Vector2i, fuss: Vector2, alpha: float, mit_kreuz: bool) -> void:
	var art: String = k.turm_art.get(z, k.turm_form(z))
	var stufe := int(k.turm_stufe.get(z, 1))
	ci.draw_rect(Rect2(fuss + Vector2(-26, -6), Vector2(52, 10)), Color(0, 0, 0, 0.22 * alpha))
	if art != "geschuetz" and art != "lanze" and art != "":
		for i in stufe - 1:
			ci.draw_rect(Rect2(fuss + Vector2(-11 + i * 12, -2), Vector2(8, 6)), Color("ffd34d") * Color(1, 1, 1, alpha))
	if stufe >= 4:   # 20.11. (Nachtrag): Stufe 4 – goldener Rahmen am Boden
		ci.draw_rect(Rect2(fuss + Vector2(-28, -8), Vector2(56, 14)), Color("ffd34d") * Color(1, 1, 1, alpha), false, 2.0)
	if mit_kreuz and not k.turm_aktiv(z):
		var m := fuss + Vector2(0, -40)
		ci.draw_line(m + Vector2(-14, -14), m + Vector2(14, 14), Color("ff5a64"), 4.0)
		ci.draw_line(m + Vector2(14, -14), m + Vector2(-14, 14), Color("ff5a64"), 4.0)
