class_name NemesisBoss
extends RefCounted
## C2 (26.11., Paul): Befehl 24 – Grundlage der Bosstypen nach Truppenart. Der Herausforderer (nemesis_herausforderer.gd)
## behält Gerüst und Rhythmus (Ansage ≥ 0,5 s, sichtbare Geschosse, verwundbares Fenster, nie dreimal dasselbe, unter
## 50 % kürzere Fenster und die Angewohnheiten) und fragt seinen Typ, welche Angriffe er hat und wie er sich bewegt.
## Diese Grundklasse ändert nichts: Salve, Schwere Kugel und Sturm wie in Version 76.
##  - nemesis_boss_scharf.gd: Scharfschütze – Distanz, Wallkronen per Anker, Laservisier, Zielmarkierung
##  - nemesis_boss_gunner.gd: Technogunner – agil, Ringsalve, Ankerwurf, Minigun, Bunker
##  - nemesis_boss_plasma.gd: Plasmawerfer – zäh, Mörser, Gel, Abpraller, Brandfächer

var h: NemesisHerausforderer
var o24: Order24
var spiel: Node
var bg: BrakkGeschosse


static func fuer(art: String, p_h: NemesisHerausforderer) -> NemesisBoss:
	match art:
		"scharfschuetze":
			return NemesisBossScharf.new(p_h)
		"technogunner":
			return NemesisBossGunner.new(p_h)
		"plasmawerfer":
			return NemesisBossPlasma.new(p_h)
		"sonde":
			return NemesisBossSonde.new(p_h)
	return NemesisBoss.new(p_h)


func _init(p_h: NemesisHerausforderer) -> void:
	h = p_h
	o24 = h.o24
	spiel = h.spiel
	bg = spiel.brakk_geschosse


# ------------------------------------------------------------------ Werte und Bewegung

func leben_mal() -> float:
	return 1.0


func tempo_mal() -> float:
	return 1.0


## Lieblingsabstand (Felder) aus dem, was Brakk spielt.
func abstand(grund: float) -> float:
	return grund


## Sekunden zwischen zwei Sprüngen/Tumble aus Brakks Takt.
func takt(grund: float) -> float:
	return grund


func sprung_anteil(grund: float) -> float:
	return grund


## false: statt Tumble ein langsamer Seitschritt.
func tumble_ok() -> bool:
	return true


## So lange bis zur nächsten Wallkrone; INF = er bleibt am Boden.
func wall_abkling() -> float:
	return 9.0


## F5 (26.11., Paul): Muss er von einer Krone erst einen Angriff ausführen, bevor er wieder herunter darf?
func krone_mit_angriff() -> bool:
	return false


## Der Weg auf die Krone (eine Aktion des Herausforderers): ein Sprung.
func weg_auf_krone(von: Vector2, nach: Vector2) -> Dictionary:
	return {"art": "sprung", "t": 0.0, "sek": Werte.HERAUSFORDERER_SPRUNG_SEK, "von": von, "nach": nach}


## C3: Die Figur ist da (Sonde 7: ihr Bild statt des Truppenblatts).
func einrichten_figur(_e: Einheit) -> void:
	pass


## C3: so hoch schwebt er über dem Boden (Felder; Sprünge kommen dazu).
func schwebe() -> float:
	return 0.0


## C3: true – er steht (Sonde 7 am Boden: ihr Fenster), keine Bewegung und kein neuer Angriff.
func steht() -> bool:
	return false


## C3: Schaden, der bei ihm ankommt (Sonde 7: Heil-Impuls brechen, geborgen statt gefallen).
func vor_treffer(menge: float) -> float:
	return menge


## C3: Dürfen die Bodentruppen jetzt auf Brakk schießen? (Verstärkungsruf)
func feuer_frei() -> bool:
	return false


## Darf er beim Laufen auf dieses Feld? (Phase 2 des Technogunners: nur das hintere Drittel)
func feld_ok(_z: Vector2i) -> bool:
	return true


# ------------------------------------------------------------------ Angriffe

## Gewichte der Angriffe (leer: Salve, Kugel, Sturm wie in Version 76). G2: nur noch Rückfall, wenn kein Schritt der
## Abfolge ausführbar ist.
func gewichte(_abstand: float, _letzte: Array) -> Dictionary:
	return {}


## G2 (27.11., Paul): Feste Abfolge der Phase (läuft im Kreis, Start an zufälliger Stelle). Je Schritt:
##   "a": Angriff, oder "wahl": [zwei Angriffe] (Zufall); "fenster": verwundbar danach (s); "bewegung": danach bis zum
##   nächsten Angriff (s); optional "dann": gekoppelter Angriff gleich danach (mit "dann_sek"), "krone": vorher auf eine
##   Wallkrone, "druck": Teil einer Druckphase (G2-3). Leer = Gewichte wie bisher.
func abfolge(_phase2: bool) -> Array:
	return []


## G2: Schritte, die zu Beginn der Phase einmal vor der Abfolge laufen (z. B. die Zielmarkierung).
func eroeffnung(_phase2: bool) -> Array:
	return []


## G2: Ist der Angriff jetzt ausführbar (Reichweite, einmalig schon genutzt)? Sonst kommt der nächste Schritt.
func kann(_art: String, _abstand: float) -> bool:
	return true


## G2-3: Erzwingt seine Druckphase den Anker? Dann brennt der Boden im Platz, sicher ist nur eine Krone.
func anker_zwang() -> bool:
	return false


## G2: Ein Angriff, der allem vorgeht ("" = keiner), z. B. Sonde 7s Sturzfeuer direkt nach dem Schrotstoß.
func erzwungen() -> String:
	return ""


## G2: Ein Schritt der Abfolge (Kurzform für die Tabellen).
static func s(art: Variant, fenster: float, bewegung: float, mehr: Dictionary = {}) -> Dictionary:
	var d := {"fenster": fenster, "bewegung": bewegung}
	if art is Array:
		d["wahl"] = art
	else:
		d["a"] = str(art)
	d.merge(mehr)
	return d


## Vergeltung mit einem Ring, der an `art` hängt („salve“, „kugel“): welcher eigene Angriff trägt ihn ("" = keiner).
func ring_angriff(art: String) -> String:
	return art


## Beginnt einen eigenen Angriff (true = übernommen). Mit „teil“ = „ansage“ und „um“ folgt nach der Ansage feuer().
func beginne(_art: String) -> bool:
	return false


## Nach der Ansage (true = übernommen). Setzt er angriff["teil"] = "typ", führt er selbst weiter und ruft h.fenster().
func feuer(_art: String, _k: Kommandant) -> bool:
	return false


## Teil „typ“ eines eigenen Angriffs, je Schritt.
func weiter_angriff(_dt: float, _k: Kommandant) -> void:
	pass


## Faktor auf das verwundbare Fenster nach `art`.
func fenster_mal(_art: String) -> float:
	return 1.0


## Jeden Schritt des Duells (auch zwischen den Angriffen): Stellungen, Gelflächen, Ausweichen.
func immer(_dt: float, _k: Kommandant) -> void:
	pass


## Unter halbem Leben: Phase 2 beginnt.
func wut() -> void:
	pass


## Brakk springt, tumbelt oder setzt eine Lichtsäule („sprung“, „tumble“, „saeule“).
func brakk_aktion(_art: String) -> void:
	pass


## Eine Warnzeile fürs HUD ("" = keine), z. B. „Im Gel – zweimal springen!“
func hud_zeile() -> String:
	return ""


## Brakks Lauftempo (Gel).
func bremse() -> float:
	return 1.0


## Duell vorbei: was er hinterlassen hat, verschwindet.
func ende() -> void:
	pass


# ------------------------------------------------------------------ Hilfen für die Typen

func _bg(echt: float) -> float:
	return NemesisHerausforderer._bg(echt)


func _brakk() -> Kommandant:
	return spiel.kommandant


## Brakks Lage für die Treffer: Bodenpunkt und ob er gerade springt (Höhe über dem Boden in Feldern).
func _brakk_sprung() -> float:
	var ego: EgoModus = spiel.ego
	return (ego.hoehe - ego._boden()) if ego != null else 0.0


## Ein Treffer an Brakk (Anteil `anteil` eines vollen Treffers), wie die übrigen seiner Treffer (Wallring, Statistik).
func _treffe(anteil: float, von: Vector2, blitz: bool = true) -> void:
	bg._treffe_brakk(h.schaden() * anteil, "herausforderer", h.quelle(), von, blitz)


## Ein Ring am Boden um `mitte` (Felder), so lange `echt` Sekunden.
func _ring(mitte: Vector2, radius: float, farbe: Color, echt: float) -> void:
	bg._ring(bg._zu3d(mitte, 0.05), radius, farbe, _bg(echt))


func _protokoll(was: String, mehr: Dictionary = {}) -> void:
	var e := {"was": was, "bei": o24.zeit}
	e.merge(mehr)
	h.protokoll.append(e)
